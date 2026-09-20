--!nonstrict
--[[
	CombatService — every source of damage, kills, ammo and hazards.

	Design rules:
	  * Damage is decided entirely on the server. The client only says "I fired", with a muzzle
	    position and a direction; the server applies spread, range, pellets and ricochet
	    itself, so none of those are things a client can lie about.
	  * Tools carry no scripts. A weapon is data; this service owns the firing path for all of
	    them, which means a new weapon can never introduce a new exploit surface.
	  * Round flags from modifiers ("InfiniteAmmo", "Ricochet", "Lifesteal") are read from
	    MatchState, so a modifier influences combat without owning any combat code.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Weapons.WeaponRegistry)
local Combat = require(Shared.Config.Combat)
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)

local ArenaService = require(script.Parent.ArenaService)
local MatchState = require(script.Parent.MatchState)

local CombatService = {}

local lastFireAt = {} -- [Player] = os.clock()
local lastDamageBy = {} -- [Humanoid] = { Player = Player, At = number }
local boundPlayers = {}
local hazardLoopStarted = false

local defaultLoadout = table.clone(Combat.DefaultLoadout)

local KILL_CREDIT_WINDOW = 6

-- ---------------------------------------------------------------------------------------
-- Loadouts
-- ---------------------------------------------------------------------------------------

function CombatService.SetDefaultLoadout(weaponIds: { string })
	defaultLoadout = table.clone(weaponIds)
	for _, player in Players:GetPlayers() do
		if MatchState.Alive[player] then
			CombatService.ApplyLoadout(player, defaultLoadout)
		end
	end
end

function CombatService.currentLoadout(): { string }
	return defaultLoadout
end

function CombatService.clearTools(player: Player)
	local containers = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end

	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				child:Destroy()
			end
		end
	end
end

--! Replaces a player's entire loadout. Called on spawn and by loadout modifiers.
function CombatService.ApplyLoadout(player: Player, weaponIds: { string })
	CombatService.clearTools(player)
	for _, weaponId in weaponIds do
		CombatService.GrantWeapon(player, weaponId)
	end
	player:SetAttribute("Loadout", table.concat(weaponIds, ","))
end

function CombatService.GrantWeapon(player: Player, weaponId: string): Tool?
	local profile = Weapons.get(weaponId)
	if not profile then
		Log.warn("GrantWeapon: unknown weapon '%s'", weaponId)
		return nil
	end

	local existing = 0
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:GetAttribute("WeaponId") == weaponId then
				existing += 1
			end
		end
	end
	if existing >= Combat.MaxReserveWeapons and #defaultLoadout > 1 then
		return nil
	end

	if not backpack then
		backpack = player:WaitForChild("Backpack", 5)
	end
	if not backpack then
		Log.warn("GrantWeapon: %s has no backpack yet", player.Name)
		return nil
	end

	local tool = Weapons.buildTool(weaponId)
	if not tool then
		return nil
	end
	tool.Parent = backpack
	return tool
end

-- ---------------------------------------------------------------------------------------
-- Damage
-- ---------------------------------------------------------------------------------------

local function protectionActive(player: Player?): boolean
	if not player then
		return false
	end
	local until_ = MatchState.Protection[player]
	if not until_ then
		return false
	end
	if os.clock() < until_ then
		return true
	end
	MatchState.Protection[player] = nil
	return false
end

local function applyDamage(attacker: Player, victimHumanoid: Humanoid, amount: number)
	if not victimHumanoid.Parent or victimHumanoid.Health <= 0 then
		return
	end

	local victimPlayer = Players:GetPlayerFromCharacter(victimHumanoid.Parent)
	if victimPlayer and protectionActive(victimPlayer) then
		return
	end
	if victimPlayer and MatchState.Alive[victimPlayer] == false then
		return -- already eliminated this round
	end

	lastDamageBy[victimHumanoid] = { Player = attacker, At = os.clock() }

	local lifesteal = MatchState.getFlag("Lifesteal", 0)
	if lifesteal and lifesteal > 0 and attacker.Character then
		local healer = attacker.Character:FindFirstChildOfClass("Humanoid")
		if healer and healer.Health > 0 then
			healer.Health = math.min(healer.MaxHealth, healer.Health + amount * lifesteal)
		end
	end

	victimHumanoid:TakeDamage(amount)
end

local function traceDirections(origin: Vector3, direction: Vector3, profile, rng: Random): { Vector3 }
	local out = {}
	if profile.SpreadDegrees <= 0 then
		table.insert(out, direction)
		return out
	end

	for _ = 1, profile.Pellets do
		local yaw = math.rad((rng:NextNumber() - 0.5) * 2 * profile.SpreadDegrees)
		local pitch = math.rad((rng:NextNumber() - 0.5) * 2 * profile.SpreadDegrees)
		table.insert(out, (CFrame.fromEulerAnglesYXZ(pitch, yaw, 0) * direction).Unit)
	end
	return out
end

local function findVictim(origin: Vector3, direction: Vector3, range: number, params: RaycastParams)
	local result = Workspace:Raycast(origin, direction * range, params)
	if not result then
		return nil
	end

	local humanoid = result.Instance:FindFirstAncestorOfClass("Humanoid")
	if humanoid then
		return humanoid
	end

	if MatchState.getFlag("Ricochet", false) then
		local reflected = direction - 2 * direction:Dot(result.Normal) * result.Normal
		local second = Workspace:Raycast(result.Position + reflected * 0.1, reflected * range, params)
		if second then
			return second.Instance:FindFirstAncestorOfClass("Humanoid")
		end
	end

	return nil
end

local function reloadTool(tool: Tool, profile)
	local weaponId = tool:GetAttribute("WeaponId")
	task.delay(profile.ReloadTime or 1.5, function()
		-- The tool may have been destroyed (death, round end, loadout swap) while reloading.
		if tool.Parent and tool:GetAttribute("WeaponId") == weaponId then
			tool:SetAttribute("Ammo", profile.Ammo)
		end
	end)
end

local function handleFire(player: Player, tool: Instance, origin: Vector3, direction: Vector3)
	if MatchState.State ~= "Live" then
		return
	end
	if not MatchState.Alive[player] then
		return
	end
	if protectionActive(player) then
		return
	end

	local character = player.Character
	if not character or not tool:IsDescendantOf(character) then
		return
	end

	local weaponId = tool:GetAttribute("WeaponId")
	local profile = Weapons.get(weaponId)
	if not profile then
		return
	end

	local now = os.clock()
	local last = lastFireAt[player] or 0
	if now - last < profile.FireRate - Combat.CooldownGraceSeconds then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head or (origin - head.Position).Magnitude > Combat.MaxFireOriginOffsetStuds then
		return
	end

	local infiniteWeapon = (profile.Ammo or 0) < 0
	local infiniteRound = MatchState.getFlag("InfiniteAmmo", false) == true
	if not infiniteWeapon and not infiniteRound then
		local ammo = tool:GetAttribute("Ammo") or 0
		if ammo <= 0 then
			return
		end
		tool:SetAttribute("Ammo", ammo - 1)
		if ammo - 1 <= 0 then
			reloadTool(tool, profile)
		end
	end

	lastFireAt[player] = now

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local rng = Random.new(os.clock() * 100000 % 2147483647)
	local hits = {}
	local victimCount = 0

	for _, pelletDirection in traceDirections(origin, direction, profile, rng) do
		local humanoid = findVictim(origin, pelletDirection, profile.Range, params)
		if humanoid and humanoid.Parent then
			local victimPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
			if victimPlayer ~= player then
				hits[humanoid] = (hits[humanoid] or 0) + profile.Damage
				victimCount += 1
			end
		end
	end

	for humanoid, damage in hits do
		applyDamage(player, humanoid, damage)
	end

	-- Replication for tracers and hit confirmation. Purely cosmetic on the client.
	Net.broadcast("WeaponTracer", player, origin, origin + direction * profile.Range, victimCount > 0)
end

-- ---------------------------------------------------------------------------------------
-- Death
-- ---------------------------------------------------------------------------------------

local function onHumanoidDied(player: Player, humanoid: Humanoid)
	if MatchState.Alive[player] == false then
		return
	end

	MatchState.Alive[player] = false
	MatchState.Eliminated[player] = true
	MatchState.Protection[player] = nil

	local stats = MatchState.Stats[player]
	if stats then
		stats.Deaths += 1
	end

	local attribution = lastDamageBy[humanoid]
	local killer: Player? = nil
	if attribution and attribution.Player ~= player and (os.clock() - attribution.At) < KILL_CREDIT_WINDOW then
		killer = attribution.Player
		MatchState.Points[killer] = (MatchState.Points[killer] or 0) + Combat.KillPoints
		local killerStats = MatchState.Stats[killer]
		if killerStats then
			killerStats.Kills += 1
		end
		Net.trySend(killer, Net.Events.Notify, { Text = "KILL", Kind = "kill" })
	end

	lastDamageBy[humanoid] = nil
	MatchState.Signals.PlayerDied:Fire(player, killer)
end

function CombatService.bindCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		onHumanoidDied(player, humanoid)
	end)
end

function CombatService.bindPlayer(player: Player)
	if boundPlayers[player] then
		return
	end
	boundPlayers[player] = true

	player.CharacterAdded:Connect(function(character)
		CombatService.bindCharacter(player, character)
	end)
	if player.Character then
		CombatService.bindCharacter(player, player.Character)
	end
end

-- ---------------------------------------------------------------------------------------
-- Hazards
-- ---------------------------------------------------------------------------------------

local function characterInsideHazard(character: Model, hazard: BasePart): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local localPoint = hazard.CFrame:PointToObjectSpace(root.Position)
	local half = hazard.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y + 3
		and math.abs(localPoint.Z) <= half.Z
end

local function startHazardLoop()
	if hazardLoopStarted then
		return
	end
	hazardLoopStarted = true

	task.spawn(function()
		while true do
			local dt = task.wait(Combat.HazardTickSeconds)
			local hazardCount = 0
			for _ in ArenaService.ActiveHazards do
				hazardCount += 1
			end

			if hazardCount > 0 and MatchState.State == "Live" then
				for hazard, _hazardType in ArenaService.ActiveHazards do
					if hazard.Parent then
						for _, player in Players:GetPlayers() do
							if MatchState.Alive[player] and player.Character and not protectionActive(player) then
								if characterInsideHazard(player.Character, hazard) then
									local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
									if humanoid and humanoid.Health > 0 then
										humanoid:TakeDamage(Combat.HazardDamagePerSecond * dt)
									end
								end
							end
						end
					end
				end
			end
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- Wire-up
-- ---------------------------------------------------------------------------------------

function CombatService.start()
	Net.event(Net.Events.WeaponFire).OnServerEvent:Connect(function(player, tool, origin, direction)
		if typeof(tool) ~= "Instance" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return
		end
		if direction.Magnitude < 0.001 then
			return
		end
		local ok, err = pcall(handleFire, player, tool, origin, direction.Unit)
		if not ok then
			Log.warn("Fire handling failed for %s: %s", player.Name, tostring(err))
		end
	end)

	startHazardLoop()
end

function CombatService.resetRound()
	lastFireAt = {}
	lastDamageBy = {}
end

function CombatService.forgetPlayer(player: Player)
	lastFireAt[player] = nil
	boundPlayers[player] = nil
end

return CombatService
