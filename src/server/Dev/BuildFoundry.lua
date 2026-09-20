--!nonstrict
--[[
	BuildFoundry — the reference arena, built to the contract.

	This exists for one reason: so the game is playable the moment you press Play, without
	waiting for hand-authored art. It is also the working example that the map team and every
	map-building AI copies, and it is intentionally gray-box and ugly so nobody mistakes it for
	final art.

	When a real `assets/arenas/Foundry.rbxmx` exists it simply replaces this — ArenaService
	only ever looks for a Model tagged MRArena in ServerStorage.Arenas, and the game does not
	care who built it.

	Contract reference: docs/01-ARENA-CONTRACT.md
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)

local BuildFoundry = {}

local TILE_SIZE = 20
local TILE_COUNT = 4 -- 4x4 tiles, 80 x 80 studs
local HALF = (TILE_SIZE * TILE_COUNT) / 2
local TILE_THICKNESS = 2
local WALL_HEIGHT = 24
local WALL_THICKNESS = 2

local GREY = Color3.fromRGB(58, 60, 68)
local GREY_DARK = Color3.fromRGB(34, 36, 42)
local GREY_LIGHT = Color3.fromRGB(78, 81, 92)
local ACCENT = Color3.fromRGB(214, 255, 63)

local function folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local container = Instance.new("Folder")
	container.Name = name
	container.Parent = parent
	return container
end

local function part(props: { [string]: any }, parent: Instance): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key == "Attributes" then
			for attributeName, attributeValue in value do
				instance:SetAttribute(attributeName, attributeValue)
			end
		elseif key == "Tags" then
			for _, tag in value do
				CollectionService:AddTag(instance, tag)
			end
		else
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

function BuildFoundry.build(): Model
	local container = ServerStorage:FindFirstChild("Arenas")
	if not container or not container:IsA("Folder") then
		container = Instance.new("Folder")
		container.Name = "Arenas"
		container.Parent = ServerStorage
	end

	local existing = container:FindFirstChild("Foundry")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "Foundry"

	-- ------------------------------------------------------------------ root attributes
	arena:SetAttribute(Tags.Attr.ArenaId, "Foundry")
	arena:SetAttribute(Tags.Attr.DisplayName, "THE FOUNDRY")
	arena:SetAttribute(Tags.Attr.MinPlayers, 1)
	arena:SetAttribute(Tags.Attr.MaxPlayers, 8)
	arena:SetAttribute(Tags.Attr.SizeClass, "Medium")
	arena:SetAttribute(Tags.Attr.FeatureTags, "Cover,FlatFloor,Tiles,Hazard,Lava,Vertical")
	arena:SetAttribute(Tags.Attr.FloorY, 0)
	arena:SetAttribute(Tags.Attr.Weight, 10)

	-- ------------------------------------------------------------------ geometry (static)
	local geometry = folder("Geometry", arena)

	local base = part({
		Name = "Base",
		Size = Vector3.new(HALF * 2 + 24, 4, HALF * 2 + 24),
		Position = Vector3.new(0, -TILE_THICKNESS - 3, 0),
		Color = GREY_DARK,
		Material = Enum.Material.Slate,
		Tags = { Tags.Static },
	}, geometry)

	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		part({
			Name = "Pillar",
			Size = Vector3.new(8, 70, 8),
			Position = Vector3.new(corner.X * (HALF + 14), 35, corner.Z * (HALF + 14)),
			Color = GREY,
			Material = Enum.Material.Concrete,
			Tags = { Tags.Static },
		}, geometry)
	end

	part({
		Name = "Emblem",
		Size = Vector3.new(12, 0.4, 12),
		Position = Vector3.new(0, 0.2, 0),
		Color = ACCENT,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Tags = { Tags.Static },
	}, geometry)

	-- ------------------------------------------------------------------ transforms
	local transforms = folder("Transforms", arena)

	local floor = folder("Floor", transforms)
	local tileIndex = 0
	for row = 0, TILE_COUNT - 1 do
		for column = 0, TILE_COUNT - 1 do
			tileIndex += 1
			local x = (column - (TILE_COUNT - 1) / 2) * TILE_SIZE
			local z = (row - (TILE_COUNT - 1) / 2) * TILE_SIZE
			part({
				Name = string.format("Tile_%02d", tileIndex),
				Size = Vector3.new(TILE_SIZE, TILE_THICKNESS, TILE_SIZE),
				Position = Vector3.new(x, -TILE_THICKNESS / 2, z),
				Color = (tileIndex % 2 == 0) and GREY_LIGHT or GREY,
				Material = Enum.Material.Concrete,
				Attributes = {
					[Tags.Attr.TransformGroup] = "Floor,Tile_" .. tileIndex,
					[Tags.Attr.CanScale] = true,
					[Tags.Attr.CanHide] = true,
					[Tags.Attr.CanMorph] = true,
					[Tags.Attr.AnchorState] = "Shown",
				},
				Tags = { Tags.Transformable },
			}, floor)
		end
	end

	local walls = folder("Walls", transforms)
	local wallSpecs = {
		{ Size = Vector3.new(HALF * 2 + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS), Position = Vector3.new(0, WALL_HEIGHT / 2, -HALF) },
		{ Size = Vector3.new(HALF * 2 + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS), Position = Vector3.new(0, WALL_HEIGHT / 2, HALF) },
		{ Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, HALF * 2), Position = Vector3.new(-HALF, WALL_HEIGHT / 2, 0) },
		{ Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, HALF * 2), Position = Vector3.new(HALF, WALL_HEIGHT / 2, 0) },
	}
	for index, spec in wallSpecs do
		part({
			Name = "Wall_" .. index,
			Size = spec.Size,
			Position = spec.Position,
			Color = GREY,
			Material = Enum.Material.Concrete,
			Transparency = 0.25,
			Attributes = {
				[Tags.Attr.TransformGroup] = "Wall",
				[Tags.Attr.CanScale] = true,
				[Tags.Attr.CanHide] = false,
				[Tags.Attr.AnchorState] = "Shown",
			},
			Tags = { Tags.Transformable },
		}, walls)
	end

	-- Cover starts hidden and rises when the CoverDrops modifier wins.
	local cover = folder("Cover", transforms)
	local coverPositions = {
		Vector3.new(-26, 0, -26), Vector3.new(26, 0, -26), Vector3.new(-26, 0, 26), Vector3.new(26, 0, 26),
		Vector3.new(0, 0, -30), Vector3.new(0, 0, 30), Vector3.new(-30, 0, 0), Vector3.new(30, 0, 0),
	}
	for index, position in coverPositions do
		part({
			Name = "Cover_" .. index,
			Size = Vector3.new(7, 6, 7),
			Position = position + Vector3.new(0, 3, 0),
			Color = GREY_LIGHT,
			Material = Enum.Material.WoodPlanks,
			Attributes = {
				[Tags.Attr.TransformGroup] = "Cover",
				[Tags.Attr.CanHide] = true,
				[Tags.Attr.AnchorState] = "Hidden",
			},
			Tags = { Tags.Transformable },
		}, cover)
	end

	-- The lava volume lives below the floor and is revealed by the RisingLava modifier.
	local hazards = folder("Hazards", arena)
	part({
		Name = "Lava",
		Size = Vector3.new(HALF * 2 + 8, 2, HALF * 2 + 8),
		Position = Vector3.new(0, -16, 0),
		Color = Color3.fromRGB(255, 92, 32),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		Attributes = {
			[Tags.Attr.TransformGroup] = "Lava",
			[Tags.Attr.HazardType] = "Lava",
		},
		Tags = { Tags.Transformable, Tags.Hazard },
	}, hazards)

	-- ------------------------------------------------------------------ spawns
	local spawns = folder("Spawns", arena)
	for index = 1, 8 do
		local angle = (index - 1) / 8 * math.pi * 2
		local radius = HALF - 12
		part({
			Name = "Spawn_" .. index,
			Size = Vector3.new(4, 1, 4),
			Position = Vector3.new(math.cos(angle) * radius, 0.6, math.sin(angle) * radius),
			Color = ACCENT,
			Transparency = 1,
			CanCollide = false,
			Attributes = {
				[Tags.Attr.SpawnIndex] = index,
				[Tags.Attr.Zone] = "Ring",
			},
			Tags = { Tags.Spawn },
		}, spawns)
	end

	-- ------------------------------------------------------------------ loot points
	local loot = folder("LootPoints", arena)
	local lootPositions = {
		Vector3.new(-32, 0, 0), Vector3.new(32, 0, 0), Vector3.new(0, 0, -32),
		Vector3.new(0, 0, 32), Vector3.new(-18, 0, 18), Vector3.new(18, 0, -18),
	}
	for index, position in lootPositions do
		part({
			Name = "Loot_" .. index,
			Size = Vector3.new(4, 1, 4),
			Position = position + Vector3.new(0, 1, 0),
			Transparency = 1,
			CanCollide = false,
			Attributes = {
				[Tags.Attr.LootWeight] = 10,
				[Tags.Attr.ClearanceRadius] = 8,
				[Tags.Attr.Zone] = "Ring",
			},
			Tags = { Tags.LootPoint },
		}, loot)
	end

	-- ------------------------------------------------------------------ vote showcase
	local showcase = folder("VoteShowcase", arena)
	local cameraShots = {
		{ Order = 1, Position = Vector3.new(0, 46, -86) },
		{ Order = 2, Position = Vector3.new(78, 38, 20) },
		{ Order = 3, Position = Vector3.new(-70, 54, 46) },
		{ Order = 4, Position = Vector3.new(30, 70, 70) },
	}
	for _, shot in cameraShots do
		local marker = part({
			Name = "VoteCamera_" .. shot.Order,
			Size = Vector3.new(2, 2, 2),
			Position = shot.Position,
			Transparency = 1,
			CanCollide = false,
			Attributes = { [Tags.Attr.Order] = shot.Order },
			Tags = { Tags.VoteCamera },
		}, showcase)
		marker.CFrame = CFrame.lookAt(shot.Position, Vector3.new(0, 6, 0))
	end

	local nameplate = part({
		Name = "Nameplate",
		Size = Vector3.new(64, 14, 1),
		Position = Vector3.new(0, 52, -HALF - 10),
		Transparency = 1,
		CanCollide = false,
		Tags = { Tags.VoteNameplate },
	}, showcase)
	nameplate.CFrame = CFrame.lookAt(nameplate.Position, Vector3.new(0, 20, 0))

	-- ------------------------------------------------------------------ emitters
	-- The map team authors the *presentation* of a modifier; the script only toggles a tag.
	local vfx = folder("VFX", arena)
	local fogVolume = part({
		Name = "FogBank",
		Size = Vector3.new(HALF * 2, 1, HALF * 2),
		Position = Vector3.new(0, 18, 0),
		Transparency = 1,
		CanCollide = false,
		Tags = { Tags.Emitter },
	}, vfx)
	fogVolume:SetAttribute(Tags.Attr.OnModifier, "Fog,Blackout")
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Mist"
	emitter.Enabled = false
	emitter.Rate = 24
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 26),
		NumberSequenceKeypoint.new(1, 30),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 194, 204))
	emitter.Parent = fogVolume

	folder("Audio", arena)

	-- Variants are hand-authored overrides. An empty folder is the correct starting state.
	folder("Variants", arena)

	arena.PrimaryPart = base
	arena.Parent = container
	CollectionService:AddTag(arena, Tags.Arena)

	Log.info("Foundry arena built in ServerStorage.Arenas")
	return arena
end

-- Bootstrap requires this module when no arena exists in ServerStorage.Arenas, and `require` on a
-- module that returns nothing fails with "Module code did not return exactly one value" — so the
-- no-arena fallback used to crash instead of building one. Always return the table.
return BuildFoundry
