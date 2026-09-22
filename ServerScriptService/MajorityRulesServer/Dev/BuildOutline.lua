--!nonstrict
--[[
	BuildOutline — the arena, as a blank canvas.

	2026-09-22 reset (D-048): the Foundry and the Colosseum are deleted, generator and geometry
	both. What remains is a *massive simple outline*: a 500-stud floor, a boundary, twelve spawn
	pads, five weapon-crate points, six vote cameras, one nameplate. Nothing else. Every part is
	tagged per the arena contract, so the game is fully playable the moment this exists — and the
	human team builds everything the outline does not provide, by hand, with parts.

	What the game needs from any arena, and where this outline provides it:
	  floor + boundary  — provided (playable, ugly, deliberate)
	  spawns            — 12 pads on a r=200 ring (>= MaxPlayers 8)
	  loot points       — 5 pads (centre + 4 diagonals), tagged MRLootPoint with ClearanceRadius
	  vote showcase     — 6 MRVoteCamera markers + 1 MRVoteNameplate
	  shrinking         — the boundary is group "Wall": SmallMap / ShrinkingArena pull it inward
	  cover / tiles / hazards / verticality — NOT provided. The ballot simply excludes modifiers
	                      that need them until the map grows them and the FeatureTags say so.

	The vote auto-filters: `Modifiers.candidatePool` matches each modifier's `Requires` against the
	arena's FeatureTags, so an empty-looking arena never gets an empty-looking round.

	Building on it: docs/14-BEGINNERS-MAP-GUIDE.md. When a hand edit is live, the arena carries
	HandAuthored = true and Bootstrap leaves it alone (D-045).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)

local BuildOutline = {}

BuildOutline.Revision = 1

--! Half-extent of the square floor. 500 studs across: at WalkSpeed 22 (sprint 33) a corner-to-
--! centre run is ~16 s — big enough for 8 sprinting players to never feel crowded.
local HALF = 250
local WALL_HEIGHT = 24
local SPAWN_RADIUS = 200
local SPAWN_COUNT = 12

local CONCRETE = Color3.fromRGB(200, 200, 200)
local CONCRETE_DARK = Color3.fromRGB(150, 150, 155)

local function part(spec, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = spec.Name
	p.Size = spec.Size
	p.CFrame = spec.CFrame
	p.Color = spec.Color or CONCRETE
	p.Material = spec.Material or Enum.Material.Concrete
	p.Anchored = true
	if spec.CanCollide ~= nil then
		p.CanCollide = spec.CanCollide
	else
		p.CanCollide = true
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if spec.Transparency then
		p.Transparency = spec.Transparency
	end
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

local function applyLighting()
	-- Neutral daylight: the canvas should show colours as they are. Any previous arena's mood
	-- (the Foundry's dusk, the Colosseum's haze) is deliberately undone.
	Lighting.ClockTime = 14
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(70, 70, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 130, 140)
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 10000
	Lighting.FogStart = 0

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere:Destroy()
	end
end

function BuildOutline.build(): Model
	local container = ServerStorage:FindFirstChild("Arenas")
	if not container then
		container = Instance.new("Folder")
		container.Name = "Arenas"
		container.Parent = ServerStorage
	end

	local existing = container:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = "Arena"
	arena:SetAttribute(Tags.Attr.ArenaId, "Arena")
	arena:SetAttribute(Tags.Attr.DisplayName, "THE ARENA")
	arena:SetAttribute(Tags.Attr.MinPlayers, 2)
	arena:SetAttribute(Tags.Attr.MaxPlayers, 8)
	arena:SetAttribute(Tags.Attr.SizeClass, "Huge")
	arena:SetAttribute(Tags.Attr.FeatureTags, "FlatFloor")
	arena:SetAttribute(Tags.Attr.FloorY, 0)
	arena:SetAttribute("GeneratorRevision", BuildOutline.Revision)

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = arena

	-- ---------------------------------------------------------------- floor + boundary
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(HALF * 2, 2, HALF * 2),
		CFrame = CFrame.new(0, -1, 0),
		Color = CONCRETE,
		Material = Enum.Material.Concrete,
		Tags = { Tags.Static },
	}, geometry)
	arena.PrimaryPart = floor

	-- Group "Wall": the one transform surface this outline ships. The shrinking modifiers scale
	-- everything in this group toward the arena centre, so the boundary closes in cleanly. If the
	-- human team replaces the boundary with their own walls, tag those parts TransformGroup "Wall".
	local wallSpecs = {
		{ Size = Vector3.new(HALF * 2 + 8, WALL_HEIGHT, 4), Position = Vector3.new(0, WALL_HEIGHT / 2, -HALF - 2) },
		{ Size = Vector3.new(HALF * 2 + 8, WALL_HEIGHT, 4), Position = Vector3.new(0, WALL_HEIGHT / 2, HALF + 2) },
		{ Size = Vector3.new(4, WALL_HEIGHT, HALF * 2 + 8), Position = Vector3.new(-HALF - 2, WALL_HEIGHT / 2, 0) },
		{ Size = Vector3.new(4, WALL_HEIGHT, HALF * 2 + 8), Position = Vector3.new(HALF + 2, WALL_HEIGHT / 2, 0) },
	}
	for index, spec in wallSpecs do
		part({
			Name = "Boundary_" .. index,
			Size = spec.Size,
			CFrame = CFrame.new(spec.Position),
			Color = CONCRETE_DARK,
			Attributes = {
				[Tags.Attr.TransformGroup] = "Wall",
				[Tags.Attr.CanScale] = true,
				[Tags.Attr.CanHide] = false,
				[Tags.Attr.AnchorState] = "Shown",
			},
			Tags = { Tags.Transformable },
		}, geometry)
	end

	-- ---------------------------------------------------------------- spawns
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = geometry
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

	-- ---------------------------------------------------------------- loot points
	local loot = Instance.new("Folder")
	loot.Name = "LootPoints"
	loot.Parent = geometry
	local lootSpecs = {
		{ Position = Vector3.new(0, 1, 0), Weight = 3, Clearance = 12 },
		{ Position = Vector3.new(100, 1, 100), Weight = 2, Clearance = 10 },
		{ Position = Vector3.new(-100, 1, 100), Weight = 2, Clearance = 10 },
		{ Position = Vector3.new(100, 1, -100), Weight = 2, Clearance = 10 },
		{ Position = Vector3.new(-100, 1, -100), Weight = 2, Clearance = 10 },
	}
	for i, spec in lootSpecs do
		part({
			Name = "LootPad_" .. string.format("%02d", i),
			Size = Vector3.new(4, 0.4, 4),
			CFrame = CFrame.new(spec.Position),
			Color = Color3.fromRGB(230, 190, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
			Attributes = {
				[Tags.Attr.LootWeight] = spec.Weight,
				[Tags.Attr.ClearanceRadius] = spec.Clearance,
			},
			Tags = { Tags.LootPoint },
		}, loot)
	end

	-- ---------------------------------------------------------------- vote showcase
	local showcase = Instance.new("Folder")
	showcase.Name = "VoteShowcase"
	showcase.Parent = geometry
	for i = 1, 6 do
		local angle = (i - 1) * (2 * math.pi / 6)
		local position = Vector3.new(math.cos(angle) * 280, 80, math.sin(angle) * 280)
		part({
			Name = "VoteCamera_" .. i,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.lookAt(position, Vector3.new(0, 40, 0)),
			Transparency = 1,
			CanCollide = false,
			Attributes = { [Tags.Attr.Order] = i },
			Tags = { Tags.VoteCamera },
		}, showcase)
	end

	part({
		Name = "VoteNameplate",
		Size = Vector3.new(30, 7, 1),
		CFrame = CFrame.lookAt(Vector3.new(0, 60, -HALF + 40), Vector3.new(0, 55, 0)),
		Color = Color3.fromRGB(30, 30, 36),
		Material = Enum.Material.Metal,
		Tags = { Tags.VoteNameplate, Tags.Static },
	}, geometry)

	applyLighting()

	local count = 0
	for _ in arena:GetDescendants() do
		count += 1
	end
	Log.info("Outline arena built in ServerStorage.Arenas (%d instances) — the blank canvas", count)

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

return BuildOutline
