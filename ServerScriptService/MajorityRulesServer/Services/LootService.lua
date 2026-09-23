--!nonstrict
--[[
	LootService — weapon crates, and the weapon pool the round is allowed to use.

	`ctx.Loot` for modifiers. A modifier that changes the loadout restricts the pool here and
	CombatService applies the loadout; the two are separate so a modifier can change what the
	arena hands out without necessarily changing what players start with.

	Crates are server-owned and prompts are server-validated: a client cannot open a crate it
	is not standing next to, and weapon ids are chosen here, never by the client.

	A crate's look comes from `CrateVisuals`, keyed by the weapon's `Class` — a sidearm arrives in
	its flat case, everything else in the standard bright block. Crate size therefore varies, so the
	spawn height is measured off the crate that was actually built, and the mesh path is guarded: a
	crate's look must never be able to abort the round that spawns it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared.Weapons.WeaponRegistry)
local CrateVisuals = require(Shared.Weapons.CrateVisuals)
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

--! The block every crate has always been: a Part, which collides as its own box.
local function buildBlock(material): BasePart
	local part = Instance.new("Part")
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

--! A meshed crate is a `Part` carrying a `SpecialMesh`, NOT a `MeshPart`.
--!
--! Writing `MeshPart.MeshId` at runtime is refused — "The current thread cannot write 'MeshId'
--! (lacking capability NotAccessible)" — from a probe and from the round loop alike. Since
--! `SpawnAll` runs inline in the round, that throw aborted the round it happened in. `MeshId` and
--! `TextureId` on a `SpecialMesh` are not gated, and a Part keeps the box collision a crate wants.
local function buildMeshed(visual): BasePart
	local part = buildBlock(Enum.Material.Plastic)
	part.Size = visual.Size
	part.Color = visual.Color

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshId = visual.MeshId
	mesh.TextureId = visual.TextureId
	mesh.Scale = CrateVisuals.meshScale(visual)
	mesh.Parent = part
	return part
end

local function buildCrate(weaponId: string, visual): Model
	local crate = Instance.new("Model")
	crate.Name = "Crate"

	--! A crate's LOOK must never be able to break a round. Guarded, and it falls back to the
	--! standard block rather than leaving a round with no loot at all.
	local body
	if visual.MeshId then
		local ok, built = pcall(buildMeshed, visual)
		if ok then
			body = built
		else
			Log.warn("Crate visual %s failed to build (%s); using the default crate", visual.MeshId, tostring(built))
		end
	end
	if not body then
		visual = CrateVisuals.Default
		body = buildBlock(visual.Material)
		body.Size = visual.Size
		body.Color = visual.Color
	end

	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = true
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
	local visual = CrateVisuals.forWeapon(weaponId)
	local crate = buildCrate(weaponId, visual)
	--! Measured off the crate that was actually built, so a visual that fell back to the block
	--! still lands exactly on the floor.
	local body = crate.PrimaryPart
	crate:PivotTo(point.CFrame + CrateVisuals.spawnOffset(body and body.Size or visual.Size))
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
