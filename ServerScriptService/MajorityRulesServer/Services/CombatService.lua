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

--! `attacker` is nil when a bot fired: bots have no Player, so they can neither steal kill credit
--! nor heal from lifesteal. Everything else is identical to a player's shot.
local function applyDamage(attacker: Player?, victimHumanoid: Humanoid, amount: number)
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

	-- Only a player's damage claims the kill. A bot's hit leaves attribution alone, so a player who
	-- softened the target first keeps the credit.
	if attacker then
		lastDamageBy[victimHumanoid] = { Player = attacker, At = os.clock() }
	end

	local lifesteal = MatchState.getFlag("Lifesteal", 0)
	if attacker and lifesteal and lifesteal > 0 and attacker.Character then
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

--! The Humanoid a raycast hit belongs to. A character's parts are SIBLINGS of its Humanoid — the
--! Humanoid is a child of the character Model — so `hit:FindFirstAncestorOfClass("Humanoid")` is
--! always nil, for a player and for a bot alike. Verified in the engine against a live character:
--!
--!     hit = Workspace.<player>.HumanoidRootPart
--!     FindFirstAncestorOfClass("Humanoid") = nil      <- what this used to ask
--!     FindFirstAncestorOfClass("Model")    = <character>, whose Humanoid child exists
--!
--! So walking up until a node *has* a Humanoid child is what resolves a victim. Every shot this
--! service has ever resolved returned nil, which is why damage has never been observed in play.
local function humanoidOfHit(instance: Instance): Humanoid?
	local node: Instance? = instance
	while node do
		local humanoid = node:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		node = node.Parent
	end
	return nil
end

local function findVictim(origin: Vector3, direction: Vector3, range: number, params: RaycastParams)
	local result = Workspace:Raycast(origin, direction * range, params)
	if not result then
		return nil
	end

	local humanoid = humanoidOfHit(result.Instance)
	if humanoid then
		return humanoid
	end

	if MatchState.getFlag("Ricochet", false) then
		local reflected = direction - 2 * direction:Dot(result.Normal) * result.Normal
		local second = Workspace:Raycast(result.Position + reflected * 0.1, reflected * range, params)
		if second then
			return humanoidOfHit(second.Instance)
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

--! Resolves one shot — spread, pellets, ricochet, damage — and applies it. Shared by player fire
--! and bot fire so a bot can never do anything a player's weapon could not: same range, same
--! pellet count, same ricochet flag, same protection and elimination rules.
--! Returns how many pellets connected, which is all the tracer needs to know.
local function resolveShot(
	shooter: Player?,
	shooterCharacter: Model,
	origin: Vector3,
	direction: Vector3,
	profile
): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooterCharacter }
	params.IgnoreWater = true

	local ownHumanoid = shooterCharacter:FindFirstChildOfClass("Humanoid")
	local rng = Random.new(os.clock() * 100000 % 2147483647)
	local hits = {}
	local victimCount = 0

	for _, pelletDirection in traceDirections(origin, direction, profile, rng) do
		local humanoid = findVictim(origin, pelletDirection, profile.Range, params)
		if humanoid and humanoid.Parent and humanoid ~= ownHumanoid then
			local victimPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
			-- A player's shot may hit anything humanoid. A bot's shot only counts against players, so
			-- two bots do not grind each other down while the human is the point of the test.
			if shooter ~= nil or victimPlayer ~= nil then
				hits[humanoid] = (hits[humanoid] or 0) + profile.Damage
				victimCount += 1
			end
		end
	end

	for humanoid, damage in hits do
		applyDamage(shooter, humanoid, damage)
	end

	return victimCount
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

	local victimCount = resolveShot(player, character, origin, direction, profile)

	-- Replication for tracers and hit confirmation. Purely cosmetic on the client.
	Net.broadcast("WeaponTracer", player, origin, origin + direction * profile.Range, victimCount > 0)
end

--! Fires a bot's weapon. Bots carry no Tool and no Player: BotService supplies the aim and the
--! weapon profile (from the round's loadout, so "shotguns only" applies to bots too), and this is
--! the same `resolveShot` a player's trigger pull goes through.
function CombatService.botFire(character: Model, origin: Vector3, direction: Vector3, profile): boolean
	if MatchState.State ~= "Live" then
		return false
	end
	if not character.Parent or direction.Magnitude < 0.001 then
		return false
	end

	local victimCount = resolveShot(nil, character, origin, direction.Unit, profile)

	-- The client ignores the shooter argument and draws from the two positions, so a nil shooter is
	-- a tracer the player can see and dodge — which is the whole point of a bot that shoots back.
	Net.broadcast("WeaponTracer", nil, origin, origin + direction.Unit * profile.Range, victimCount > 0)
	return true
end

-- ---------------------------------------------------------------------------------------
-- Death
-- ---------------------------------------------------------------------------------------

--! Points, stats and the on-screen notice for whoever last damaged this Humanoid. Shared by player
--! deaths and bot deaths, so dropping a bot is worth exactly what dropping a player is worth.
--! `victimPlayer` is nil for a bot victim.
function CombatService.creditKill(victimPlayer: Player?, victimHumanoid: Humanoid): Player?
	local attribution = lastDamageBy[victimHumanoid]
	lastDamageBy[victimHumanoid] = nil
	if not attribution then
		return nil
	end

	local killer = attribution.Player
	if not killer or killer == victimPlayer then
		return nil
	end
	if os.clock() - attribution.At >= KILL_CREDIT_WINDOW then
		return nil
	end

	MatchState.Points[killer] = (MatchState.Points[killer] or 0) + Combat.KillPoints
	local killerStats = MatchState.Stats[killer]
	if killerStats then
		killerStats.Kills += 1
	end
	Net.trySend(killer, Net.Events.Notify, { Text = "KILL", Kind = "kill" })
	return killer
end

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

	local killer = CombatService.creditKill(player, humanoid)
	MatchState.Signals.PlayerDied:Fire(player, killer)
end

--! A bot has no Player and no CharacterAdded signal, so nothing binds its Humanoid until BotService
--! asks. `onDied` is how BotService retires a bot without this service needing to know what a bot is.
function CombatService.bindBot(character: Model, onDied: (() -> ())?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		Log.warn("bindBot: %s has no Humanoid to bind", character.Name)
		return
	end

	humanoid.Died:Connect(function()
		CombatService.creditKill(nil, humanoid)
		if onDied then
			onDied()
		end
	end)
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
	-- Bind every player's Humanoid. Nothing called `bindPlayer`, so `Humanoid.Died` was never
	-- connected: a death set no `Alive` flag, no `Eliminated` flag, awarded no kill, and could not end
	-- a round early. That stayed invisible for as long as no shot could resolve a victim (see
	-- `humanoidOfHit`), and it is the first thing a live fight exposes — a player shot to zero health
	-- and the round ran on with three bots firing at the body.
	Players.PlayerAdded:Connect(function(player)
		CombatService.bindPlayer(player)
	end)
	for _, player in Players:GetPlayers() do
		CombatService.bindPlayer(player)
	end

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
	-- The loadout is a per-round effect, exactly like the crate pool (LootService.reset) and the
	-- gameplay baseline (GameplayService.reset), and this is the only one of the three with nothing
	-- restoring it. So a loadout modifier's list outlived its own round: after a PistolsOnly round,
	-- every later round handed out pistols instead of the default, because SetDefaultLoadout had
	-- overwritten the default that respawns read. Caught by ServerScriptService/MajorityRulesServer/Dev/LoadoutCheck.lua, which
	-- failed loudly on four consecutive Fog rounds. See docs/DECISIONS.md D-027.
	defaultLoadout = table.clone(Combat.DefaultLoadout)
end

function CombatService.forgetPlayer(player: Player)
	lastFireAt[player] = nil
	boundPlayers[player] = nil
end

return CombatService
