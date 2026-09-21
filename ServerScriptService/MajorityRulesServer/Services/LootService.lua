--!nonstrict
--[[
	LootService — weapon crates, and the weapon pool the round is allowed to use.

	`ctx.Loot` for modifiers. A modifier that changes the loadout restricts the pool here and
	CombatService applies the loadout; the two are separate so a modifier can change what the
	arena hands out without necessarily changing what players start with.

	Crates are server-owned and prompts are server-validated: a client cannot open a crate it
	is not standing next to, and weapon ids are chosen here, never by the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Weapons.WeaponRegistry)
local Combat = require(Shared.Config.Combat)
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)

local ArenaService = require(script.Parent.ArenaService)
local MatchState = require(script.Parent.MatchState)

local LootService = {}

local activePool: { string } = table.clone(Weapons.CratePool)
local crates = {} -- [Model] = { Point = BasePart, WeaponId = string }
local halted = false

-- ---------------------------------------------------------------------------------------
-- Pool
-- ---------------------------------------------------------------------------------------

local function sanitise(ids: { string }): { string }
	local out = {}
	for _, id in ids do
		if Weapons.exists(id) then
			table.insert(out, id)
		else
			Log.warn("LootService: unknown weapon '%s' ignored", id)
		end
	end
	return out
end

function LootService.SetWeaponPool(ids: { string })
	activePool = sanitise(ids)
	if #activePool == 0 then
		activePool = table.clone(Weapons.CratePool)
		Log.warn("LootService: empty pool requested, falling back to the full crate pool")
	end
end

function LootService.RestrictPoolTo(ids: { string })
	LootService.SetWeaponPool(ids)
end

function LootService.AddWeaponPool(ids: { string })
	local merged = table.clone(activePool)
	for _, id in sanitise(ids) do
		if not table.find(merged, id) then
			table.insert(merged, id)
		end
	end
	activePool = merged
end

function LootService.CurrentPool(): { string }
	return table.clone(activePool)
end

--! Used by loadout modifiers that promise no ranged weapons at all.
function LootService.HaltCrates()
	halted = true
	LootService.ClearAll()
end

-- ---------------------------------------------------------------------------------------
-- Crates
-- ---------------------------------------------------------------------------------------

local function buildCrate(weaponId: string): Model
	local crate = Instance.new("Model")
	crate.Name = "Crate"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 3, 3)
	body.Color = Color3.fromRGB(214, 255, 63) -- brand accent: crates are the only bright thing
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body:SetAttribute("WeaponId", weaponId)
	body.Parent = crate

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = string.format("TAKE %s", string.upper(weaponId))
	prompt.ObjectText = "CRATE"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = Combat.CrateOpenRadius
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	crate.PrimaryPart = body
	CollectionService:AddTag(crate, Tags.Crate)
	return crate
end

local function openCrate(crate: Model, player: Player)
	local record = crates[crate]
	if not record then
		return
	end

	if not MatchState.Alive[player] then
		return
	end

	local CombatService = require(script.Parent.CombatService)
	CombatService.GrantWeapon(player, record.WeaponId)
	crates[crate] = nil
	crate:Destroy()

	local point = record.Point
	task.delay(Combat.CrateRespawnSeconds, function()
		if not halted and point.Parent then
			LootService.SpawnAt(point)
		end
	end)
end

--! Spawns a crate at one loot point. Weapon choice is deterministic from the round seed when
--! an rng is supplied, so a bug report reproduces exactly.
function LootService.SpawnAt(point: BasePart, rng: Random?): Model?
	if halted or not point.Parent then
		return nil
	end
	for existing, record in crates do
		if record.Point == point then
			return existing
		end
	end

	local random = rng or Random.new()
	local weaponId = activePool[random:NextInteger(1, #activePool)]
	local crate = buildCrate(weaponId)
	crate:PivotTo(point.CFrame + Vector3.new(0, 2.5, 0))
	crate.Parent = workspace
	crates[crate] = { Point = point, WeaponId = weaponId }

	local body = crate.PrimaryPart
	if body then
		body:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(player)
			openCrate(crate, player)
		end)
	end

	return crate
end

function LootService.SpawnAll(rng: Random?): number
	LootService.ClearAll()
	if halted then
		return 0
	end

	local random = rng or Random.new()
	local points = ArenaService.GetLootPoints()
	local spawned = 0
	for _, point in points do
		if LootService.SpawnAt(point, random) then
			spawned += 1
		end
	end
	return spawned
end

function LootService.ClearAll()
	for crate in crates do
		if crate.Parent then
			crate:Destroy()
		end
	end
	table.clear(crates)
end

function LootService.reset()
	halted = false
	activePool = table.clone(Weapons.CratePool)
	LootService.ClearAll()
end

function LootService.crateCount(): number
	local count = 0
	for _ in crates do
		count += 1
	end
	return count
end

return LootService
