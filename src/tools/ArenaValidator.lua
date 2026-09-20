--!nonstrict
--[[
	ArenaValidator — the gate every arena must pass, human or AI authored.

	Three humans and several map-building AIs will produce arenas for this game. The contract in
	docs/01-ARENA-CONTRACT.md is what keeps them compatible with the systems, but prose is not a
	gate. This is: run it, read the report, fix what it says, then merge.

	It is deliberately strict about things that would produce silent failures at runtime:
	  * an arena with fewer spawns than its own MaxPlayers
	  * a transformable part with no group (a modifier would simply never find it)
	  * unanchored geometry (the physics cost, and the transform pipeline fights it)
	  * a missing vote camera set (the cinematic would fall back to a generated ring)
	  * scripts inside an arena model (the contract's hardest rule)

	Usage in Studio's command bar, or through the Roblox Studio connector:

		local Validator = require(game.ServerStorage.Tools.ArenaValidator)
		print(Validator.reportAll())
]]

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Modifiers = require(Shared.Modifiers)

local ArenaValidator = {}

local PART_BUDGET = 2500
local TRIANGLE_BUDGET = 250000
local MIN_SPAWN_SPACING = 8
local MIN_VOTE_CAMERAS = 3
local VALID_ANCHOR_STATES = { Shown = true, Hidden = true }
local VALID_HAZARDS = { Lava = true, Void = true, Trampoline = true, Conveyor = true }
local VALID_SIZES = { Tiny = true, Small = true, Medium = true, Large = true, Huge = true }

local function descendantsOfClass(root: Instance, className: string)
	local out = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA(className) then
			table.insert(out, descendant)
		end
	end
	return out
end

function ArenaValidator.validate(arena: Instance)
	local errors = {}
	local warnings = {}
	local info = {}

	local function error(message: string)
		table.insert(errors, message)
	end
	local function warn(message: string)
		table.insert(warnings, message)
	end

	if not arena:IsA("Model") then
		return { ok = false, errors = { "arena is not a Model" }, warnings = {}, info = {} }
	end
	if not CollectionService:HasTag(arena, Tags.Arena) then
		error("arena root is missing the " .. Tags.Arena .. " tag")
	end

	-- ---------------------------------------------------------------- root attributes
	local arenaId = arena:GetAttribute(Tags.Attr.ArenaId)
	if type(arenaId) ~= "string" or #arenaId == 0 then
		error("missing ArenaId attribute")
	end

	local maxPlayers = arena:GetAttribute(Tags.Attr.MaxPlayers)
	if type(maxPlayers) ~= "number" or maxPlayers < 1 or maxPlayers > 8 then
		error("MaxPlayers must be a number between 1 and 8 (got " .. tostring(maxPlayers) .. ")")
	end

	if arena:GetAttribute(Tags.Attr.FloorY) == nil then
		warn("no FloorY attribute: falling back to the model pivot")
	end

	local sizeClass = arena:GetAttribute(Tags.Attr.SizeClass)
	if sizeClass ~= nil and not VALID_SIZES[sizeClass] then
		warn("SizeClass '" .. tostring(sizeClass) .. "' is not one of Tiny/Small/Medium/Large")
	end

	local features = Tags.featuresOf(arena)
	for feature in features do
		if not Modifiers.KnownFeatures[feature] then
			warn("unknown feature tag '" .. feature .. "': modifiers cannot filter on it")
		end
	end

	-- ---------------------------------------------------------------- no scripts, anchored
	for _, script in descendantsOfClass(arena, "LuaSourceContainer") do
		error("arena contains a script (" .. script:GetFullName() .. "); arenas are geometry only")
	end

	for _, part in descendantsOfClass(arena, "BasePart") do
		if not part.Anchored then
			error("unanchored part " .. part.Name .. "; all arena geometry must be anchored")
		end
	end

	-- ---------------------------------------------------------------- transforms
	local transformables = {}
	for _, instance in CollectionService:GetTagged(Tags.Transformable) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			table.insert(transformables, instance)
		end
	end
	if #transformables == 0 then
		warn("no " .. Tags.Transformable .. " parts: no modifier can change this arena's geometry")
	end

	local groupNames = {}
	for _, part in transformables do
		local groups = Tags.groupsOf(part)
		local count = 0
		for name in groups do
			count += 1
			groupNames[name] = (groupNames[name] or 0) + 1
		end
		if count == 0 then
			error("transformable part " .. part.Name .. " declares no TransformGroup")
		end
		local anchorState = part:GetAttribute(Tags.Attr.AnchorState)
		if anchorState ~= nil and not VALID_ANCHOR_STATES[anchorState] then
			error("part " .. part.Name .. " has invalid AnchorState '" .. tostring(anchorState) .. "'")
		end
	end

	if features.Cover and not groupNames.Cover then
		error("arena declares the Cover feature but has no parts in the 'Cover' group")
	end
	if features.Tiles and not groupNames.Tile_1 then
		error("arena declares the Tiles feature but has no 'Tile_1' group")
	end
	if features.Lava and not groupNames.Lava then
		error("arena declares the Lava feature but has no parts in the 'Lava' group")
	end

	-- ---------------------------------------------------------------- spawns
	local spawns = {}
	for _, instance in CollectionService:GetTagged(Tags.Spawn) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			table.insert(spawns, instance)
		end
	end
	if type(maxPlayers) == "number" and #spawns < maxPlayers then
		error(string.format("%d spawn points but MaxPlayers is %d", #spawns, maxPlayers))
	end
	for index = 1, #spawns do
		for other = index + 1, #spawns do
			local distance = (spawns[index].Position - spawns[other].Position).Magnitude
			if distance < MIN_SPAWN_SPACING then
				error(
					string.format(
						"spawns %s and %s are only %.1f studs apart (minimum %d)",
						spawns[index].Name,
						spawns[other].Name,
						distance,
						MIN_SPAWN_SPACING
					)
				)
			end
		end
	end
	for _, spawn in spawns do
		if spawn.Position.Y < (arena:GetAttribute(Tags.Attr.FloorY) or -math.huge) then
			warn("spawn " .. spawn.Name .. " sits below the arena floor")
		end
	end

	-- ---------------------------------------------------------------- loot points
	local lootPoints = 0
	for _, instance in CollectionService:GetTagged(Tags.LootPoint) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			lootPoints += 1
		end
	end
	if lootPoints == 0 then
		error("no loot points: weapon crates would have nowhere to spawn")
	end
	if lootPoints > 12 then
		warn(lootPoints .. " loot points: consider fewer, more contested points")
	end

	-- ---------------------------------------------------------------- hazards
	for _, instance in CollectionService:GetTagged(Tags.Hazard) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			local hazardType = instance:GetAttribute(Tags.Attr.HazardType)
			if hazardType == nil or not VALID_HAZARDS[hazardType] then
				error("hazard " .. instance.Name .. " has an invalid HazardType")
			end
			if instance.CanCollide then
				warn("hazard " .. instance.Name .. " has CanCollide on; hazards are volumes")
			end
		end
	end

	-- ---------------------------------------------------------------- vote showcase
	local cameras = {}
	for _, instance in CollectionService:GetTagged(Tags.VoteCamera) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			table.insert(cameras, instance)
		end
	end
	if #cameras < MIN_VOTE_CAMERAS then
		error(string.format("%d vote cameras, at least %d required for the cinematic", #cameras, MIN_VOTE_CAMERAS))
	end
	local seenOrders = {}
	for _, camera in cameras do
		local order = camera:GetAttribute(Tags.Attr.Order)
		if order == nil then
			error("vote camera " .. camera.Name .. " is missing its Order attribute")
		elseif seenOrders[order] then
			error("two vote cameras share Order " .. tostring(order))
		else
			seenOrders[order] = true
		end
	end

	local nameplates = 0
	for _, instance in CollectionService:GetTagged(Tags.VoteNameplate) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			nameplates += 1
		end
	end
	if nameplates ~= 1 then
		warn(string.format("%d vote nameplates; exactly 1 is expected", nameplates))
	end

	-- ---------------------------------------------------------------- variants
	local variants = Tags.folder(arena, "Variants")
	if variants then
		for _, variant in variants:GetChildren() do
			if not Modifiers.get(variant.Name) then
				warn("variant '" .. variant.Name .. "' does not match any registered modifier id")
			end
		end
	end

	-- ---------------------------------------------------------------- budgets
	local parts = descendantsOfClass(arena, "BasePart")
	info.parts = #parts
	info.groups = 0
	for _ in groupNames do
		info.groups += 1
	end
	info.spawns = #spawns
	info.lootPoints = lootPoints
	info.voteCameras = #cameras
	info.transformables = #transformables

	if #parts > PART_BUDGET then
		warn(string.format("%d parts exceeds the %d budget", #parts, PART_BUDGET))
	end

	if arena.PrimaryPart == nil then
		warn("no PrimaryPart set: the drift modifier will move the bounding-box centre instead")
	end

	-- 6 x 6 = 60 x 60 studs is a good Medium arena; flag anything extreme so the ballot filters
	-- can be trusted with SizeClass.
	local _, size = arena:GetBoundingBox()
	info.size = size
	if size.X > 400 or size.Z > 400 then
		warn(string.format("arena bounding box is %.0f x %.0f studs, which is very large for 8 players", size.X, size.Z))
	end

	return {
		ok = #errors == 0,
		errors = errors,
		warnings = warnings,
		info = info,
		arenaName = arena.Name,
	}
end

function ArenaValidator.report(arena: Instance): string
	local result = ArenaValidator.validate(arena)
	local lines = {}
	local function add(text: string)
		table.insert(lines, text)
	end

	add(string.format("=== %s (%s) ===", result.arenaName, result.ok and "PASS" or "FAIL"))
	if result.info then
		add(
			string.format(
				"parts=%s transformables=%s groups=%s spawns=%s loot=%s cameras=%s",
				tostring(result.info.parts),
				tostring(result.info.transformables),
				tostring(result.info.groups),
				tostring(result.info.spawns),
				tostring(result.info.lootPoints),
				tostring(result.info.voteCameras)
			)
		)
	end
	for _, message in result.errors do
		add("  ERROR   " .. message)
	end
	for _, message in result.warnings do
		add("  warning " .. message)
	end
	return table.concat(lines, "\n")
end

function ArenaValidator.arenas(): { Model }
	local container = ServerStorage:FindFirstChild("Arenas")
	local out = {}
	if not container then
		return out
	end
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			table.insert(out, child)
		end
	end
	return out
end

function ArenaValidator.validateAll()
	local results = {}
	for _, arena in ArenaValidator.arenas() do
		table.insert(results, ArenaValidator.validate(arena))
	end
	return results
end

function ArenaValidator.reportAll(): string
	local lines = {}
	local failed = 0
	for _, arena in ArenaValidator.arenas() do
		table.insert(lines, ArenaValidator.report(arena))
		local result = ArenaValidator.validate(arena)
		if not result.ok then
			failed += 1
		end
	end
	table.insert(lines, string.format("=== %d arena(s), %d failing ===", #ArenaValidator.arenas(), failed))
	return table.concat(lines, "\n")
end

return ArenaValidator
