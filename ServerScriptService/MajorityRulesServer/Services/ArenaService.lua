--!nonstrict
--[[
	ArenaService — the arena controller, and the ONLY module that touches arena geometry.

	Modifiers talk to this through `ctx.Arena`. They never see a part, a folder or a path.
	That barrier is what lets the map team rebuild every arena without touching a single line
	of game logic, and lets an AI write a modifier without knowing what an arena looks like.

	Capabilities exposed to modifiers (see docs/02-MODIFIER-API.md):
		Center FloorY Bounds GroupNames GroupParts GetGroupParts
		ScaleGroup MoveGroup SetGroupHidden SetGroupPhysics SetGroupMaterial
		SetGravity SetGravityScale TweenLighting
		SetHazardEnabled HazardParts
		SetDriftOffset SetNameplate
		ShowVariant ClearVariant

	Everything a transform changes is snapshotted on load and restored between rounds, so no
	round can inherit residue from the last one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)
local Tween = require(Shared.Util.Tween)
local Pick = require(Shared.Util.Pick)

local ArenaService = {}

local RUNTIME_NAME = "Arena"
local VARIANTS = "Variants"
local GEOMETRY = "Geometry"

local function arenaIdOf(arena: Instance): string
	return Tags.attr(arena, Tags.Attr.ArenaId, arena.Name)
end

local function countKeys(map: { [any]: any }): number
	local count = 0
	for _ in map do
		count += 1
	end
	return count
end

local state = {
	model = nil,
	source = nil,
	pivot = nil,
	groups = {},
	originals = {},
	hazardsByType = {},
	activeHazards = {},
	spawnParts = {},
	lootPoints = {},
	lighting = nil,
	gravity = workspace.Gravity,
	variantActive = nil,
	variantHidden = {},
	drift = Vector3.zero,
}

ArenaService.State = state
ArenaService.ActiveHazards = state.activeHazards

-- ---------------------------------------------------------------------------------------
-- Snapshot / restore
-- ---------------------------------------------------------------------------------------

local function snapshot(part: BasePart)
	return {
		CFrame = part.CFrame,
		Size = part.Size,
		Transparency = part.Transparency,
		CanCollide = part.CanCollide,
		CanQuery = part.CanQuery,
		Material = part.Material,
		Physics = part.CustomPhysicalProperties,
		AnchorState = part:GetAttribute(Tags.Attr.AnchorState),
	}
end

local function applyAnchorState(part: BasePart)
	local anchorState = part:GetAttribute(Tags.Attr.AnchorState)
	if anchorState == "Hidden" then
		part.Transparency = 1
		part.CanCollide = false
		-- CanQuery matters as much as CanCollide here. CombatService and BotService both reach
		-- their targets with Workspace:Raycast, and a hidden part still blocks a ray. The arena
		-- opens with the entire colonnade hidden, so without this every bot is blind on round 1
		-- and every shot stops in mid-air on cover the player cannot see.
		part.CanQuery = false
	elseif anchorState == "Shown" then
		part.CanQuery = true
	end
end

local function index(arena: Model)
	state.groups = {}
	state.originals = {}
	state.hazardsByType = {}
	state.activeHazards = {}
	state.spawnParts = {}
	state.lootPoints = {}
	state.pivot = arena:GetPivot()

	for _, descendant in arena:GetDescendants() do
		if descendant:IsA("BasePart") then
			state.originals[descendant] = snapshot(descendant)
			applyAnchorState(descendant)

			for group in Tags.groupsOf(descendant) do
				state.groups[group] = state.groups[group] or {}
				table.insert(state.groups[group], descendant)
			end
		end
	end

	for _, spawn in CollectionService:GetTagged(Tags.Spawn) do
		if spawn:IsDescendantOf(arena) then
			table.insert(state.spawnParts, spawn)
		end
	end
	table.sort(state.spawnParts, function(a, b)
		local left = Tags.attr(a, Tags.Attr.SpawnIndex, 0)
		local right = Tags.attr(b, Tags.Attr.SpawnIndex, 0)
		return left < right
	end)

	for _, point in CollectionService:GetTagged(Tags.LootPoint) do
		if point:IsDescendantOf(arena) then
			table.insert(state.lootPoints, point)
		end
	end

	for _, hazard in CollectionService:GetTagged(Tags.Hazard) do
		if hazard:IsDescendantOf(arena) then
			local hazardType = Tags.attr(hazard, Tags.Attr.HazardType, "Lava")
			state.hazardsByType[hazardType] = state.hazardsByType[hazardType] or {}
			table.insert(state.hazardsByType[hazardType], hazard)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------------------

function ArenaService.container(): Folder?
	local folder = ServerStorage:FindFirstChild("Arenas")
	return folder and folder:IsA("Folder") and folder or nil
end

function ArenaService.availableArenas(): { Model }
	local folder = ArenaService.container()
	local out = {}
	if not folder then
		return out
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and CollectionService:HasTag(child, Tags.Arena) then
			table.insert(out, child)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

function ArenaService.get(arenaId: string): Model?
	for _, arena in ArenaService.availableArenas() do
		if Tags.attr(arena, Tags.Attr.ArenaId, arena.Name) == arenaId then
			return arena
		end
	end
	return nil
end

function ArenaService.getModel(): Model?
	return state.model
end

--! Weighted arena choice for a match, filtered by the arena's own minimum player count.
--! Deterministic from the match seed, so a reported match can be reproduced exactly.
function ArenaService.pick(rng: Random, playerCount: number): Model?
	local candidates = {}
	for _, arena in ArenaService.availableArenas() do
		local minimum = Tags.attr(arena, Tags.Attr.MinPlayers, 1)
		if playerCount >= minimum then
			table.insert(candidates, arena)
		end
	end
	if #candidates == 0 then
		Log.warn("No arena satisfies a %d player match; falling back to any arena", playerCount)
		candidates = ArenaService.availableArenas()
	end
	if #candidates == 0 then
		return nil
	end

	local chosen = Pick.weighted(candidates, function(arena)
		return Tags.attr(arena, Tags.Attr.Weight, 10)
	end, rng)
	return chosen or candidates[1]
end

--! Does this arena carry a hand-authored variant for a modifier? If so, the variant replaces
--! that modifier's procedural geometry steps (see docs/01-ARENA-CONTRACT.md).
function ArenaService.hasVariant(modifierId: string): boolean
	if not state.model then
		return false
	end
	local variants = Tags.folder(state.model, VARIANTS)
	if not variants then
		return false
	end
	return variants:FindFirstChild(modifierId) ~= nil
end

function ArenaService.isLoaded(): boolean
	return state.model ~= nil and state.model.Parent ~= nil
end

function ArenaService.load(arena: Model): boolean
	ArenaService.unload()

	local clone = arena:Clone()
	clone.Name = RUNTIME_NAME
	clone:SetAttribute(Tags.Attr.Label, "active")
	-- Stream the arena as a single unit so pieces can never pop in mid-transform.
	pcall(function()
		clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)

	local existing = workspace:FindFirstChild(RUNTIME_NAME)
	if existing then
		existing:Destroy()
	end
	clone.Parent = workspace

	state.model = clone
	state.source = arena
	state.drift = Vector3.zero
	state.variantActive = nil
	state.variantHidden = {}
	table.clear(state.activeHazards)

	index(clone)

	if not state.lighting then
		state.lighting = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			ClockTime = Lighting.ClockTime,
			FogColor = Lighting.FogColor,
			FogStart = Lighting.FogStart,
			FogEnd = Lighting.FogEnd,
			EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
			EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		}
	end
	state.gravity = workspace.Gravity

	Log.info(
		"Arena loaded: %s (%d instances, %d groups, %d spawns, %d loot points)",
		arenaIdOf(clone),
		#clone:GetDescendants(),
		countKeys(state.groups),
		#state.spawnParts,
		#state.lootPoints
	)

	return true
end

function ArenaService.unload()
	if state.model then
		state.model:Destroy()
	end
	state.model = nil
	state.source = nil
	state.groups = {}
	state.originals = {}
	state.activeHazards = {}
	state.hazardsByType = {}
	state.spawnParts = {}
	state.lootPoints = {}
	state.variantActive = nil
	state.variantHidden = {}
	state.drift = Vector3.zero
	table.clear(state.activeHazards)
end

-- ---------------------------------------------------------------------------------------
-- Reset
-- ---------------------------------------------------------------------------------------

--! Restore every transformed part, the lighting, the gravity, drift and variant state.
function ArenaService.reset()
	for part, original in state.originals do
		if part.Parent then
			part.Size = original.Size
			part.CFrame = original.CFrame
			part.Transparency = original.Transparency
			part.CanCollide = original.CanCollide
			part.CanQuery = original.CanQuery
			part.Material = original.Material
			if original.Physics then
				part.CustomPhysicalProperties = original.Physics
			end
			applyAnchorState(part)
		end
	end

	if state.lighting then
		for property, value in state.lighting do
			(Lighting :: any)[property] = value
		end
	end

	workspace.Gravity = state.gravity

	ArenaService.ClearVariant()

	if state.model then
		local pivot = state.model:GetPivot()
		if state.drift.Magnitude > 0 then
			state.model:PivotTo(pivot - state.drift)
			state.drift = Vector3.zero
		end
	end

	table.clear(state.activeHazards)
	for _hazardType, parts in state.hazardsByType do
		for _, hazard in parts do
			if hazard.Parent then
				hazard.Transparency = 1
				hazard.CanCollide = false
			end
		end
	end

	ArenaService.SetEmitters({})
end

-- ---------------------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------------------

function ArenaService.Center(): Vector3
	if state.model then
		return state.model:GetPivot().Position
	end
	return Vector3.zero
end

function ArenaService.FloorY(): number
	if state.model then
		return Tags.attr(state.model, Tags.Attr.FloorY, state.model:GetPivot().Position.Y)
	end
	return 0
end

function ArenaService.Bounds()
	if not state.model then
		return { Center = Vector3.zero, Size = Vector3.zero }
	end
	local cf, size = state.model:GetBoundingBox()
	return { Center = cf.Position, Size = size }
end

function ArenaService.GroupNames(): { string }
	local names = {}
	for name in state.groups do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ArenaService.GroupParts(group: string): { BasePart }
	return state.groups[group] or {}
end

function ArenaService.HazardParts(hazardType: string): { BasePart }
	return state.hazardsByType[hazardType] or {}
end

function ArenaService.GetSpawnParts(): { BasePart }
	if state.variantActive then
		local variant = state.variantActive.model
		local spawns = Tags.folder(variant, "Spawns")
		if spawns then
			local out = {}
			for _, inst in spawns:GetChildren() do
				if inst:IsA("BasePart") then
					table.insert(out, inst)
				end
			end
			if #out > 0 then
				table.sort(out, function(a, b)
					return Tags.attr(a, Tags.Attr.SpawnIndex, 0) < Tags.attr(b, Tags.Attr.SpawnIndex, 0)
				end)
				return out
			end
		end
	end
	return state.spawnParts
end

function ArenaService.GetLootPoints(): { BasePart }
	if state.variantActive then
		local variant = state.variantActive.model
		local points = Tags.folder(variant, "LootPoints")
		if points then
			local out = {}
			for _, inst in points:GetChildren() do
				if inst:IsA("BasePart") then
					table.insert(out, inst)
				end
			end
			if #out > 0 then
				return out
			end
		end
	end
	return state.lootPoints
end

function ArenaService.features(): { [string]: boolean }
	if state.model then
		return Tags.featuresOf(state.model)
	end
	return {}
end

-- ---------------------------------------------------------------------------------------
-- Transforms
-- ---------------------------------------------------------------------------------------

--! Scale a transform group around the arena centre. Uses LIVE size and position, so repeated
--! calls accumulate (which is what ShrinkingArena depends on).
function ArenaService.ScaleGroup(group: string, factor: number, duration: number, axes: Vector3?): { any }
	local parts = state.groups[group]
	if not parts or #parts == 0 then
		Log.warn("ScaleGroup: no parts in group '%s'", group)
		return {}
	end

	local axis = axes or Vector3.new(1, 0, 1)
	local center = ArenaService.Center()
	local out = {}

	for _, part in parts do
		if part.Parent then
			local scale = Vector3.new(
				1 + (factor - 1) * axis.X,
				1 + (factor - 1) * axis.Y,
				1 + (factor - 1) * axis.Z
			)
			local newSize = Vector3.new(part.Size.X * scale.X, part.Size.Y * scale.Y, part.Size.Z * scale.Z)
			local delta = part.Position - center

			local newPosition
			if axis.X == 0 and axis.Z == 0 and axis.Y ~= 0 then
				-- Vertical-only scaling pins the bottom face, so a wall grows upward.
				newPosition = part.Position + Vector3.new(0, (newSize.Y - part.Size.Y) / 2, 0)
			else
				newPosition = center
					+ Vector3.new(delta.X * scale.X, delta.Y * scale.Y, delta.Z * scale.Z)
			end

			local newCFrame = part.CFrame + (newPosition - part.Position)
			local tween = Tween.go(part, duration, { Size = newSize, CFrame = newCFrame })
			if tween then
				table.insert(out, tween)
			end
		end
	end

	return out
end

function ArenaService.MoveGroup(group: string, offset: Vector3, duration: number): { any }
	local parts = state.groups[group]
	if not parts or #parts == 0 then
		Log.warn("MoveGroup: no parts in group '%s'", group)
		return {}
	end

	local out = {}
	for _, part in parts do
		if part.Parent then
			local tween = Tween.go(part, duration, { CFrame = part.CFrame + offset })
			if tween then
				table.insert(out, tween)
			end
		end
	end
	return out
end

function ArenaService.SetGroupHidden(group: string, hidden: boolean, duration: number?): { any }
	local parts = state.groups[group]
	if not parts or #parts == 0 then
		Log.warn("SetGroupHidden: no parts in group '%s'", group)
		return {}
	end

	local out = {}
	for _, part in parts do
		if part.Parent then
			-- Collision changes immediately: physics must never be mid-tween.
			part.CanCollide = not hidden
			local tween = Tween.go(part, duration or 0, { Transparency = hidden and 1 or 0 })
			if tween then
				table.insert(out, tween)
			end
		end
	end
	return out
end

function ArenaService.SetGroupPhysics(group: string, props: { Friction: number?, Elasticity: number?, Density: number? })
	local parts = state.groups[group] or {}
	for _, part in parts do
		if part.Parent then
			local ok = pcall(function()
				part.CustomPhysicalProperties = PhysicalProperties.new(
					props.Density or 0.7,
					props.Friction or 0.3,
					props.Elasticity or 0,
					1,
					1
				)
			end)
			if not ok then
				Log.warn("SetGroupPhysics failed on %s", part:GetFullName())
			end
		end
	end
end

function ArenaService.SetGroupMaterial(group: string, material: Enum.Material)
	local parts = state.groups[group] or {}
	for _, part in parts do
		if part.Parent then
			part.Material = material
		end
	end
end

--! Toggles the arena's authored VFX/audio emitters by modifier id.
--! This is the contract's neatest trick: the map team authors the *presentation* of a modifier
--! (fog banks, dust, sparks, a music bed) as emitters tagged MREmitter with an OnModifier
--! list, and the engine only has to switch them on. Adding atmosphere to a modifier is then a
--! map-side job that needs no script change at all.
function ArenaService.SetEmitters(activeIds: { [string]: boolean })
	if not state.model then
		return
	end

	local function apply(instance: Instance, enabled: boolean)
		if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
			instance.Enabled = enabled
		elseif instance:IsA("Sound") then
			if enabled then
				if not instance.Playing then
					instance:Play()
				end
			else
				instance:Stop()
			end
		end
	end

	for _, tagged in CollectionService:GetTagged(Tags.Emitter) do
		if tagged:IsDescendantOf(state.model) then
			local enabled = Tags.emitterMatches(tagged, activeIds)
			-- Emitters may be tagged directly, or live inside a tagged container part.
			if tagged:IsA("BasePart") then
				for _, descendant in tagged:GetDescendants() do
					apply(descendant, enabled)
				end
			else
				apply(tagged, enabled)
			end
		end
	end
end

function ArenaService.SetGravity(value: number)
	workspace.Gravity = value
end

function ArenaService.SetGravityScale(scale: number)
	workspace.Gravity = state.gravity * scale
end

function ArenaService.TweenLighting(props: { [string]: any }, duration: number): any?
	return Tween.go(Lighting, duration, props)
end

function ArenaService.SetHazardEnabled(hazardType: string, enabled: boolean, duration: number?): { any }
	local parts = state.hazardsByType[hazardType]
	local out = {}
	if not parts then
		Log.warn("SetHazardEnabled: arena has no '%s' hazard", hazardType)
		return out
	end

	for _, hazard in parts do
		if hazard.Parent then
			hazard.CanCollide = false -- hazards are volumes; they damage, they do not block
			if enabled then
				state.activeHazards[hazard] = hazardType
			else
				state.activeHazards[hazard] = nil
			end
			local tween = Tween.go(hazard, duration or 0, { Transparency = enabled and 0.35 or 1 })
			if tween then
				table.insert(out, tween)
			end
		end
	end

	return out
end

--! Moves the whole anchored arena. PERF: this touches every part, so MovingArena steps it at
--! a fixed low rate rather than every frame.
function ArenaService.SetDriftOffset(offset: Vector3)
	if not state.model then
		return
	end
	local delta = offset - state.drift
	if delta.Magnitude < 0.001 then
		return
	end
	state.model:PivotTo(state.model:GetPivot() + delta)
	state.drift = offset
end

function ArenaService.SetNameplate(text: string)
	if not state.model then
		return
	end
	for _, plate in CollectionService:GetTagged(Tags.VoteNameplate) do
		if plate:IsDescendantOf(state.model) then
			plate:SetAttribute(Tags.Attr.Text, text)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Hand-authored variants
-- ---------------------------------------------------------------------------------------

--! If the arena contains `Variants/<ModifierId>`, that model replaces the procedural
--! transform for that modifier. Map builders upgrade a modifier by shipping a variant; no
--! script changes are involved.
function ArenaService.ShowVariant(modifierId: string): boolean
	if not state.model then
		return false
	end
	local variants = Tags.folder(state.model, VARIANTS)
	if not variants then
		return false
	end
	local variant = variants:FindFirstChild(modifierId)
	if not variant then
		return false
	end

	local hidden = {}
	local geometry = Tags.folder(state.model, GEOMETRY)
	if geometry then
		for _, inst in geometry:GetDescendants() do
			if inst:IsA("BasePart") then
				hidden[inst] = true
				inst.CanCollide = false
				inst.Transparency = 1
			end
		end
	end

	for _, inst in variant:GetDescendants() do
		if inst:IsA("BasePart") then
			local anchorState = inst:GetAttribute(Tags.Attr.AnchorState)
			inst.Transparency = anchorState == "Hidden" and 1 or 0
			inst.CanCollide = anchorState ~= "Hidden"
		end
	end

	state.variantActive = { id = modifierId, model = variant }
	state.variantHidden = hidden
	Log.info("Arena variant active: %s", modifierId)
	return true
end

function ArenaService.ClearVariant()
	if state.variantActive then
		for _, inst in state.variantActive.model:GetDescendants() do
			if inst:IsA("BasePart") then
				inst.Transparency = 1
				inst.CanCollide = false
			end
		end
		state.variantActive = nil
	end

	for part in state.variantHidden do
		if part.Parent then
			local original = state.originals[part]
			part.Transparency = original and original.Transparency or 0
			part.CanCollide = original == nil or original.CanCollide
		end
	end
	state.variantHidden = {}
end

return ArenaService
