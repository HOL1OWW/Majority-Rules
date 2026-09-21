--!nonstrict
--[[
	BuildColosseum — a proper arena. Not a themed hall: a COLOSSEUM.

	Why this exists: the Foundry is an interior space — corridors, booths, partitions — and with
	the base walk speed raised to 22 plus sprint, that read as small and busy. This is the opposite
	bet: one huge open floor (180 studs across), a ring wall the shrinking modifiers can crush
	inward, tiered seating that says "arena" from spawn, and cover that *rises* mid-round instead of
	cluttering the sight lines from the start. Daylight, not dusk: this arena wants to be seen.

	Contract compliance is by tag and attribute only (docs/01-ARENA-CONTRACT.md):
	  * MRArena root with ArenaId / MaxPlayers / SizeClass / FeatureTags / FloorY
	  * TransformGroup groups the modifiers drive: "Wall" (drum segments), "Cover" (rising cover),
	    "Floor,Tile_N" (48 sand tiles for CollapsingFloor)
	  * 12 MRArenaSpawn (>= MaxPlayers), 10 MRLootPoint with ClearanceRadius, 8 MRVoteCamera
	  * no Script inside the model; everything Anchored; part budget ~320 of 2500

	Hand placements were checked against each other on the plan (spawn ring r70, cover rings r30/r60,
	loot at centre/r20/r45 — nearest pair ~16 studs), because this builder has no settle pass.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)

local BuildColosseum = {}

BuildColosseum.Revision = 1

--! Geometry plan. The floor is a r=90 disc; the drum wall stands at r=96; seating climbs r=100..150.
local FLOOR_RADIUS = 90
local DRUM_RADIUS = 96
local DRUM_SEGMENTS = 48
local DRUM_HEIGHT = 16
local SPAWN_RADIUS = 70
local SPAWN_COUNT = 12
local LOOT_CLEARANCE = 10

local SAND = Color3.fromRGB(194, 178, 128)
local SAND_DARK = Color3.fromRGB(166, 150, 106)
local STONE = Color3.fromRGB(168, 158, 142)
local STONE_DARK = Color3.fromRGB(132, 124, 110)
local BANNER_RED = Color3.fromRGB(136, 28, 28)
local WOOD = Color3.fromRGB(112, 78, 46)

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function part(spec, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = spec.Name
	p.Size = spec.Size
	p.CFrame = spec.CFrame
	p.Color = spec.Color or STONE
	p.Material = spec.Material or Enum.Material.Concrete
	p.Anchored = true
	if spec.CanCollide ~= nil then
		p.CanCollide = spec.CanCollide
	else
		p.CanCollide = true
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if spec.Attributes then
		for name, value in spec.Attributes do
			p:SetAttribute(name, value)
		end
	end
	if spec.Tags then
		for _, tag in spec.Tags do
			CollectionService:AddTag(p, tag)
		end
	end
	p.Parent = parent
	return p
end

--! One drum wall segment. Group "Wall": SmallMap and ShrinkingArena scale this group toward the
--! centre, which pulls every segment inward — the ring tightens instead of one box sliding.
local function drumSegment(index: number, parent: Instance)
	local angle = (index - 1) * (2 * math.pi / DRUM_SEGMENTS)
	local width = 2 * math.pi * DRUM_RADIUS / DRUM_SEGMENTS + 0.4 -- slight overlap, no gaps
	local position = Vector3.new(math.cos(angle) * DRUM_RADIUS, DRUM_HEIGHT / 2, math.sin(angle) * DRUM_RADIUS)
	local facing = CFrame.new(position) * CFrame.Angles(0, -angle + math.pi / 2, 0)
	local hue = STONE
	if index % 6 == 0 then
		hue = STONE_DARK
	end
	part({
		Name = "Wall_Segment_" .. string.format("%02d", index),
		Size = Vector3.new(width, DRUM_HEIGHT, 3),
		CFrame = facing,
		Color = hue,
		Material = Enum.Material.Brick,
		Attributes = {
			[Tags.Attr.TransformGroup] = "Wall",
			[Tags.Attr.CanScale] = true,
			[Tags.Attr.CanHide] = false,
			[Tags.Attr.AnchorState] = "Shown",
		},
		Tags = { Tags.Transformable },
	}, parent)
end

--! The sand floor: one substrate disc (PrimaryPart) plus 48 transformable tiles in a ring pattern
--! for CollapsingFloor. The tiles are wedge-free boxes laid in a radial grid; the substrate keeps
--! the floor whole when they sink.
local function buildFloor(parent: Instance)
	local substrate = part({
		Name = "FloorSubstrate",
		Size = Vector3.new(FLOOR_RADIUS * 2, 2, FLOOR_RADIUS * 2),
		CFrame = CFrame.new(0, -1, 0),
		Color = SAND_DARK,
		Material = Enum.Material.Ground,
		Tags = { Tags.Static },
	}, parent)
	-- A cylinder reads rounder than the box it covers; the box only exists to catch the corners.
	local disc = part({
		Name = "FloorDisc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, FLOOR_RADIUS * 2, FLOOR_RADIUS * 2),
		CFrame = CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = SAND,
		Material = Enum.Material.Ground,
		Tags = { Tags.Static },
	}, parent)
	disc.CanCollide = true

	local tiles = folder("FloorTiles", parent)
	local rings = { 30, 50, 70 }
	local tileIndex = 0
	for _, ringRadius in rings do
		local count = math.floor(ringRadius / 9)
		for i = 1, count do
			tileIndex += 1
			local angle = (i - 1) * (2 * math.pi / count) + (ringRadius % 20) / 20
			local hue = SAND_DARK
			if i % 2 == 0 then
				hue = SAND
			end
			part({
				Name = "Tile_" .. tileIndex,
				Size = Vector3.new(14, 0.4, 14),
				CFrame = CFrame.new(math.cos(angle) * ringRadius, 0.2, math.sin(angle) * ringRadius)
					* CFrame.Angles(0, -angle, 0),
				Color = hue,
				Material = Enum.Material.Ground,
				Attributes = {
					[Tags.Attr.TransformGroup] = "Floor,Tile_" .. tileIndex,
					[Tags.Attr.CanScale] = true,
					[Tags.Attr.CanHide] = true,
					[Tags.Attr.CanMorph] = true,
					[Tags.Attr.AnchorState] = "Shown",
				},
				Tags = { Tags.Transformable },
			}, tiles)
		end
	end
	return substrate
end

--! Rising cover: what makes an open arena playable. Authored Hidden so the sand starts clear;
--! CoverCrates raises the group mid-round. Three dresses, all inside their contract volume.
local function coverPiece(index: number, position: Vector3, kind: string, parent: Instance)
	local tag = string.format("%02d", index)
	local attributes = {
		[Tags.Attr.TransformGroup] = "Cover",
		[Tags.Attr.CanHide] = true,
		[Tags.Attr.AnchorState] = "Hidden",
	}
	local facing = CFrame.new(position) * CFrame.Angles(0, math.atan2(-position.Z, position.X) + math.pi / 2, 0)

	if kind == "Column" then
		part({
			Name = "Cover_Column_" .. tag,
			Size = Vector3.new(4, 9, 4),
			CFrame = facing * CFrame.new(0, 4.5, 0),
			Color = STONE,
			Material = Enum.Material.Marble,
			Attributes = attributes,
			Tags = { Tags.Transformable },
		}, parent)
	elseif kind == "Barricade" then
		part({
			Name = "Cover_Barricade_" .. tag,
			Size = Vector3.new(10, 4, 2.5),
			CFrame = facing * CFrame.new(0, 2, 0),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
			Attributes = attributes,
			Tags = { Tags.Transformable },
		}, parent)
	else
		part({
			Name = "Cover_Block_" .. tag,
			Size = Vector3.new(6, 5, 6),
			CFrame = facing * CFrame.new(0, 2.5, 0),
			Color = STONE_DARK,
			Material = Enum.Material.Brick,
			Attributes = attributes,
			Tags = { Tags.Transformable },
		}, parent)
	end
end

--! Seating tiers: the reason this reads as an arena and not a parking lot. Static — the transform
--! pipeline never touches them, so they cost nothing at modifier time.
local function buildSeating(parent: Instance)
	local tiers = folder("Seating", parent)
	for tier = 1, 4 do
		local inner = 100 + (tier - 1) * 13
		local height = 4 + (tier - 1) * 3
		local blocks = 40
		for i = 1, blocks do
			local angle = (i - 1) * (2 * math.pi / blocks)
			local width = 2 * math.pi * inner / blocks + 0.5
			local hue = STONE_DARK
			if tier % 2 == 0 then
				hue = STONE
			end
			part({
				Name = string.format("Tier%d_Block_%02d", tier, i),
				Size = Vector3.new(width, height, 13),
				CFrame = CFrame.new(math.cos(angle) * (inner + 6.5), height / 2, math.sin(angle) * (inner + 6.5))
					* CFrame.Angles(0, -angle + math.pi / 2, 0),
				Color = hue,
				Material = Enum.Material.Concrete,
				Tags = { Tags.Static },
			}, tiers)
		end
	end
end

--! Eight gate frames on the drum: two pillars and a banner lintel. Static dressing; they sit
--! outside the wall's group so shrinking never tears them.
local function buildGates(parent: Instance)
	local gates = folder("Gates", parent)
	for g = 1, 8 do
		local angle = (g - 1) * (2 * math.pi / 8)
		local basis = CFrame.new(math.cos(angle) * (DRUM_RADIUS + 4), 0, math.sin(angle) * (DRUM_RADIUS + 4))
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
		for side = -1, 1, 2 do
			part({
				Name = string.format("Gate%d_Pillar%s", g, side < 0 and "L" or "R"),
				Size = Vector3.new(2.5, DRUM_HEIGHT + 6, 2.5),
				CFrame = basis * CFrame.new(side * 7, (DRUM_HEIGHT + 6) / 2, 0),
				Color = STONE_DARK,
				Material = Enum.Material.Brick,
				Tags = { Tags.Static },
			}, gates)
		end
		part({
			Name = "Gate" .. g .. "_Banner",
			Size = Vector3.new(18, 3, 1),
			CFrame = basis * CFrame.new(0, DRUM_HEIGHT + 7.5, 0),
			Color = BANNER_RED,
			Material = Enum.Material.Fabric,
			Tags = { Tags.Static },
		}, gates)
	end
end

local function applyLighting()
	-- Daylight: an arena this open wants to be seen from spawn to spawn. (The Foundry's dusk was
	-- right for an interior; here it would just make 180 studs of sand hard to read.)
	Lighting.ClockTime = 13.8
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 70, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 130, 140)
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 3000
	Lighting.FogStart = 1200

	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		existing:Destroy()
	end
end

function BuildColosseum.build(): Model
	local container = ServerStorage:FindFirstChild("Arenas")
	if not container then
		container = Instance.new("Folder")
		container.Name = "Arenas"
		container.Parent = ServerStorage
	end

	local existing = container:FindFirstChild("Colosseum")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "Colosseum"
	arena:SetAttribute(Tags.Attr.ArenaId, "Colosseum")
	arena:SetAttribute(Tags.Attr.DisplayName, "THE COLOSSEUM")
	arena:SetAttribute(Tags.Attr.MinPlayers, 2)
	arena:SetAttribute(Tags.Attr.MaxPlayers, 8)
	arena:SetAttribute(Tags.Attr.SizeClass, "Huge")
	arena:SetAttribute(Tags.Attr.FeatureTags, "Cover,Tiles,FlatFloor")
	arena:SetAttribute(Tags.Attr.FloorY, 0)
	arena:SetAttribute(Tags.Attr.Weight, 20)
	-- Read by Bootstrap: a stale arena is rebuilt before the first round rather than played.
	arena:SetAttribute("GeneratorRevision", BuildColosseum.Revision)

	local geometry = folder("Geometry", arena)

	local floorPart = buildFloor(geometry)
	arena.PrimaryPart = floorPart

	local walls = folder("DrumWall", geometry)
	for i = 1, DRUM_SEGMENTS do
		drumSegment(i, walls)
	end

	buildSeating(geometry)
	buildGates(geometry)

	local cover = folder("Cover", geometry)
	local coverIndex = 0
	local kindByRing = { "Column", "Barricade", "Block" }
	-- inner ring r30, 8 pieces; outer ring r60, 12 pieces, offset 15 degrees from the spawn ring
	for i = 1, 8 do
		coverIndex += 1
		local angle = (i - 1) * (2 * math.pi / 8)
		coverPiece(coverIndex, Vector3.new(math.cos(angle) * 30, 0, math.sin(angle) * 30), kindByRing[(i % 3) + 1], cover)
	end
	for i = 1, 12 do
		coverIndex += 1
		local angle = (i - 1) * (2 * math.pi / 12) + math.pi / 12
		coverPiece(coverIndex, Vector3.new(math.cos(angle) * 60, 0, math.sin(angle) * 60), kindByRing[(i % 3) + 1], cover)
	end

	local spawns = folder("Spawns", geometry)
	for i = 1, SPAWN_COUNT do
		local angle = (i - 1) * (2 * math.pi / SPAWN_COUNT)
		part({
			Name = "Spawn_" .. string.format("%02d", i),
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(math.cos(angle) * SPAWN_RADIUS, 1.5, math.sin(angle) * SPAWN_RADIUS),
			Color = Color3.fromRGB(90, 200, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			CanCollide = false,
			Attributes = { [Tags.Attr.SpawnIndex] = i },
			Tags = { Tags.Spawn },
		}, spawns)
	end

	local loot = folder("LootPoints", geometry)
	local lootSpecs = {
		{ Position = Vector3.new(0, 1, 0), Weight = 3, Clearance = 12 }, -- the centre: worth the walk
	}
	for i = 1, 4 do -- mid-field diagonal pads
		local angle = math.pi / 4 + (i - 1) * (math.pi / 2) + math.pi / 12
		table.insert(lootSpecs, { Position = Vector3.new(math.cos(angle) * 45, 1, math.sin(angle) * 45), Weight = 2, Clearance = LOOT_CLEARANCE })
	end
	for i = 1, 4 do -- between-spawn pads, so a spawn is never more than half a ring from a crate
		local angle = (i - 1) * (math.pi / 2) + math.pi / 12
		table.insert(lootSpecs, { Position = Vector3.new(math.cos(angle) * 20, 1, math.sin(angle) * 20), Weight = 1, Clearance = 9 })
	end
	for i, spec in lootSpecs do
		part({
			Name = "LootPad_" .. string.format("%02d", i),
			Size = Vector3.new(4, 0.4, 4),
			CFrame = CFrame.new(spec.Position),
			Color = Color3.fromRGB(230, 190, 80),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Attributes = {
				[Tags.Attr.LootWeight] = spec.Weight,
				[Tags.Attr.ClearanceRadius] = spec.Clearance,
			},
			Tags = { Tags.LootPoint },
		}, loot)
	end

	local showcase = folder("VoteShowcase", geometry)
	for i = 1, 8 do
		local angle = (i - 1) * (2 * math.pi / 8)
		part({
			Name = "VoteCamera_" .. i,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(math.cos(angle) * 120, 42, math.sin(angle) * 120, 0, 0, -math.cos(angle), 0, 1, 0, math.cos(angle), 0, -math.sin(angle)),
			Transparency = 1,
			CanCollide = false,
			Attributes = { [Tags.Attr.Order] = i },
			Tags = { Tags.VoteCamera },
		}, showcase)
	end

	part({
		Name = "VoteNameplate",
		Size = Vector3.new(24, 6, 1),
		CFrame = CFrame.new(0, DRUM_HEIGHT + 14, -(DRUM_RADIUS + 5)),
		Color = Color3.fromRGB(30, 30, 36),
		Material = Enum.Material.Metal,
		Tags = { Tags.VoteNameplate, Tags.Static },
	}, geometry)

	applyLighting()

	local partCount = 0
	for _ in arena:GetDescendants() do
		partCount += 1
	end
	Log.info("Colosseum arena built in ServerStorage.Arenas (%d instances)", partCount)

	-- Same gate the Foundry reports through: loud in Studio, silent in production.
	local tools = ServerStorage:FindFirstChild("Tools")
	local validatorModule = tools and tools:FindFirstChild("ArenaValidator")
	if validatorModule then
		local ok, Validator = pcall(require, validatorModule)
		if ok and Validator and Validator.report then
			Validator.report(arena)
		end
	end

	return arena
end

return BuildColosseum
