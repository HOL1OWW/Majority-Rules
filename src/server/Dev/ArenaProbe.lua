--!nonstrict
--[[
	ArenaProbe — measures the geometry the validator cannot see.

	ArenaValidator answers "does this arena obey the contract?". It cannot answer "is this arena
	built the way the source says", and the difference is where every real bug in this arena has
	lived: a staircase that ran through the colonnade, buttresses half buried in the shell, 51
	invisible markers eating every bullet, a collapsed tile that was a two-stud step, furniture
	built inside other furniture. None of those broke a contract rule. All of them were found by
	cloning the arena into Workspace and asking the engine, which is what this does.

	It is a Studio instrument, not a gate: it never errors and it never blocks a round. It prints a
	report, and a human reads it.

	Why it lives in the repository rather than in a chat message: it was written four times by hand
	before this, and every time it was thrown away afterwards. The numbers in docs/13-ARENA-DESIGN.md
	come from this file, so re-measuring them is one Play button.

	Checks:
	  1. budget       — parts, transformables, and the share of the budget used
	  2. overlaps     — pairs of props built inside each other, which no contract rule forbids
	  3. markers      — a transparent, non-colliding part that still blocks a ray (D-031)
	  4. spawns       — geometry standing inside a spawn volume
	  5. sightlines   — how exposed the floor is, cover hidden (round start) versus raised
	  6. the hole     — that a collapsed tile opens onto the underside rather than a step
]]--

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)

local ArenaProbe = {}

local SIGHTLINE_SAMPLES = 9 -- per side: 81 floor points, 3240 pairs, twice
local SIGHTLINE_HEIGHT = 3 -- chest height. A player is 5 tall, so this is the honest aim line.
local OVERLAP_TOLERANCE = 0.25 -- studs of shared volume before a pair is worth reporting
local MAX_LISTED = 30

-- ------------------------------------------------------------------------------------------ helpers

local function partsIn(root: Instance): { BasePart }
	local out = {}
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(out, descendant)
		end
	end
	return out
end

--! Parts in one family are meant to touch: a capital sits on a column, a curtain hangs inside its
--! booth, a slat is embedded in the wall it decorates. Reporting those would bury the real findings.
--! The family is the name before the first underscore, and a name that *begins* with another's stem
--! joins it — `WallSlat_3_4` belongs to `Wall_3`, `PlanterCanopyTop_1` to `PlanterCanopy_1`.
--! The risk is the other direction: two unrelated structures that happen to share a prefix stop
--! being reported. Nothing shares a prefix with anything it should not in this arena.
local function sameFamily(a: string, b: string): boolean
	-- The leading CamelCase word first: `LampRod` is a child of `Lamp3`, `PlanterTrunk_1` of
	-- `PlanterCanopy_1`, `FanMount` of `FanBoss`, and the underscore rule alone split every one of
	-- those into a reported pair.
	local wordA = string.match(a, "^([A-Z][a-z]+)") or a
	local wordB = string.match(b, "^([A-Z][a-z]+)") or b
	if wordA == wordB then
		return true
	end
	local stemA = string.match(a, "^([^_]+)") or a
	local stemB = string.match(b, "^([^_]+)") or b
	if stemA == stemB then
		return true
	end
	return string.sub(stemB, 1, #stemA) == stemA or string.sub(stemA, 1, #stemB) == stemB
end

--! Overlap depth of two boxes in world space, as an axis-aligned approximation. Rotated props are
--! approximated rather than solved exactly, which can over-report a near miss by a fraction of a
--! stud; the tolerance exists for that reason, and the cost of a false positive here is one line a
--! human reads and dismisses.
local function overlapDepth(a: BasePart, b: BasePart): number
	local amin, amax = a.Position - a.Size / 2, a.Position + a.Size / 2
	local bmin, bmax = b.Position - b.Size / 2, b.Position + b.Size / 2
	local depth = math.huge
	for _, axis in { "X", "Y", "Z" } do
		local overlap = math.min(amax[axis], bmax[axis]) - math.max(amin[axis], bmin[axis])
		if overlap < depth then
			depth = overlap
		end
	end
	return depth
end

--! A *marker* is invisible **and** non-colliding: contract geometry that must not interact with the
--! world at all. A *decor* part is any non-colliding part, and some of those are visible — lane
--! lines, the grout substrate, neon sign letters — so they may sit inside whatever they are stuck to
--! and are excluded from the overlap question without being markers.
--!
--! Conflating the two cost this probe its credibility once: the first version called anything
--! non-colliding a marker and reported fourteen "markers that block rays", which were one substrate
--! plate two studs under the floor and four sign letters thirty-four studs up. A false alarm about
--! D-031 hides a real one.
local function isMarker(part: BasePart): boolean
	return part.Transparency >= 0.9 and not part.CanCollide
end

local function isDecor(part: BasePart): boolean
	return part.Transparency >= 0.9 or not part.CanCollide
end

local function boxAround(position: Vector3, size: Vector3): Part
	local box = Instance.new("Part")
	box.Size = size
	box.CFrame = CFrame.new(position)
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.Transparency = 1
	return box
end

-- -------------------------------------------------------------------------------------- the checks

local function reportBudget(clone: Model): string
	local parts, transformables, instances = 0, 0, 0
	for _, descendant in clone:GetDescendants() do
		instances += 1
		if descendant:IsA("BasePart") then
			parts += 1
			if descendant:GetAttribute(Tags.Attr.TransformGroup) then
				transformables += 1
			end
		end
	end
	-- Mirrors ArenaValidator's PART_BUDGET. Kept as a literal rather than required from the validator
	-- because the probe must keep working when the validator itself is the thing that is broken.
	local budget = 2500
	return string.format(
		"  parts %d / %d (%.0f%%), transformables %d, instances %d",
		parts,
		budget,
		parts / budget * 100,
		transformables,
		instances
	)
end

local function reportOverlaps(clone: Model): string
	local candidates = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") and not isDecor(descendant) then
			table.insert(candidates, descendant)
		end
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { clone }
	params.MaxParts = 20

	local found, seen = {}, {}
	for _, part in candidates do
		for _, other in Workspace:GetPartsInPart(part, params) do
			if other ~= part and other:IsA("BasePart") and not isDecor(other) then
				local key = part.Name .. "|" .. other.Name
				local reverse = other.Name .. "|" .. part.Name
				if not seen[key] and not seen[reverse] and not sameFamily(part.Name, other.Name) then
					seen[key] = true
					local depth = overlapDepth(part, other)
					if depth > OVERLAP_TOLERANCE then
						table.insert(found, { depth = depth, text = string.format("%s into %s by %.2f", part.Name, other.Name, depth) })
					end
				end
			end
		end
	end

	table.sort(found, function(a, b)
		return a.depth > b.depth
	end)

	local lines = { string.format("  %d pair(s) over %.2f studs", #found, OVERLAP_TOLERANCE) }
	for index, entry in found do
		if index > MAX_LISTED then
			table.insert(lines, string.format("  ... and %d more", #found - MAX_LISTED))
			break
		end
		table.insert(lines, "  " .. entry.text)
	end
	return table.concat(lines, "\n")
end

local function reportMarkers(clone: Model): string
	-- D-031: an invisible, non-colliding part is a marker, and a marker that still answers raycasts
	-- eats bullets and blinds bots. Six 64x64 emitter plates once did exactly that.
	local bad, total, visible = {}, 0, {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			if isMarker(descendant) then
				total += 1
				if descendant.CanQuery then
					table.insert(bad, descendant.Name)
				end
			elseif not descendant.CanCollide and descendant.CanQuery then
				-- Visible and non-colliding, so a bullet or a bot's line of sight stops on it. Legal — it
				-- is geometry a player can see — but worth naming, because it is the difference between a
				-- sign and a wall that is not there.
				table.insert(visible, descendant.Name)
			end
		end
	end

	local function nameList(names: { string }, limit: number): string
		local unique, seen = {}, {}
		for _, name in names do
			if not seen[name] then
				seen[name] = true
				table.insert(unique, name)
			end
		end
		table.sort(unique)
		local shown = table.concat(unique, ", ")
		if #unique > limit then
			shown = table.concat({ table.unpack(unique, 1, limit) }, ", ") .. string.format(" ... and %d more", #unique - limit)
		end
		return shown
	end

	local lines = {}
	if #bad == 0 then
		table.insert(lines, string.format("  all %d marker(s) have CanQuery = false", total))
	else
		table.insert(lines, string.format("  %d of %d marker(s) STILL BLOCK RAYS: %s", #bad, total, nameList(bad, 10)))
	end
	if #visible > 0 then
		table.insert(
			lines,
			string.format(
				"  %d visible non-colliding part(s) block rays (intended for decor, listed so a wall that is not there cannot hide here): %s",
				#visible,
				nameList(visible, 6)
			)
		)
	end
	return table.concat(lines, "\n")
end

local function reportSpawns(clone: Model): string
	local spawns = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute(Tags.Attr.SpawnIndex) then
			table.insert(spawns, descendant)
		end
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { clone }
	params.MaxParts = 20

	local blocked = 0
	local lines = {}
	for _, spawn in spawns do
		-- A standing player's volume: 4x6x4 above the spawn.
		local volume = boxAround(spawn.Position + Vector3.new(0, 3, 0), Vector3.new(4, 6, 4))
		volume.Parent = Workspace
		local hits = {}
		for _, hit in Workspace:GetPartsInPart(volume, params) do
			if hit ~= spawn and not isDecor(hit) then
				table.insert(hits, hit.Name)
			end
		end
		volume:Destroy()
		if #hits > 0 then
			blocked += 1
			table.insert(lines, string.format("  %s has %d part(s) in its volume: %s", spawn.Name, #hits, table.concat(hits, ", ")))
		end
	end

	-- Spawn-to-cover distance is deliberately *not* repeated here: ArenaValidator measures it with
	-- exact point-to-box maths and prints it, and a second, looser number for the same fact is how
	-- two reports end up disagreeing. This check is only about the thing the validator cannot see:
	-- geometry standing in the volume a player occupies when they spawn.
	local header = string.format("  %d spawns, %d with something in a standing player's volume", #spawns, blocked)
	return table.concat({ header, table.unpack(lines) }, "\n")
end

local function samplePoints(clone: Model, solid: { BasePart }): ({ Vector3 }, number)
	local floorY = clone:GetAttribute(Tags.Attr.FloorY) or 0
	local pivot = clone.PrimaryPart
	local centre = pivot and pivot.Position or Vector3.zero
	-- Half-extent from the floor folder rather than a constant: the probe should follow the arena.
	local half = 0
	local floor = clone:FindFirstChild("Transforms") and clone.Transforms:FindFirstChild("Floor")
	if floor then
		for _, tile in floor:GetChildren() do
			if tile:IsA("BasePart") then
				half = math.max(half, math.abs(tile.Position.X - centre.X) + tile.Size.X / 2)
			end
		end
	end
	if half == 0 then
		half = 48
	end

	-- Inset and filtered. The samples used to run to `half - 2`, which is the *outer edge of the outer
	-- tiles*: the corner samples stood inside the partitions, the filing banks and the records counter,
	-- so every one of their rays was blocked at a range of zero and the arena read as 74% blind at
	-- chest height when it is nothing of the kind. A sample has to be somewhere a player can stand.
	local inset = 8
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { solid }

	local points, skipped = {}, 0
	local step = (half - inset) * 2 / (SIGHTLINE_SAMPLES - 1)
	for row = 0, SIGHTLINE_SAMPLES - 1 do
		for column = 0, SIGHTLINE_SAMPLES - 1 do
			local x = centre.X - (half - inset) + column * step
			local z = centre.Z - (half - inset) + row * step
			local point = Vector3.new(x, floorY + SIGHTLINE_HEIGHT, z)
			-- "Somewhere a player can stand": a sample inside a prop is not a sightline, it is a wall.
			local crowded = false
			for _, part in Workspace:GetPartBoundsInRadius(point, 1.5, params) do
				crowded = true
				break
			end
			if crowded then
				skipped += 1
			else
				table.insert(points, point)
			end
		end
	end
	return points, skipped
end

local function countVisible(points: { Vector3 }, filter: { Instance }): (number, number, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	local blocked, pairs, totalDistance = 0, 0, 0
	for index = 1, #points do
		for other = index + 1, #points do
			pairs += 1
			local from, to = points[index], points[other]
			local result = Workspace:Raycast(from, to - from, params)
			if result then
				blocked += 1
			else
				totalDistance += (to - from).Magnitude
			end
		end
	end
	return blocked, pairs, totalDistance
end

local function reportSightlines(clone: Model): string
	local cover = {}
	local geometry = {}
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			local group = descendant:GetAttribute(Tags.Attr.TransformGroup)
			if group == "Cover" then
				table.insert(cover, descendant)
			elseif not isDecor(descendant) then
				table.insert(geometry, descendant)
			end
		end
	end
	local points, skipped = samplePoints(clone, geometry)

	-- "Hidden" is the round's opening state: every cover piece is switched off until the transform
	-- raises the ones the vote asked for. Geometry is always there.
	local hiddenParams = RaycastParams.new()
	hiddenParams.FilterType = Enum.RaycastFilterType.Include
	hiddenParams.FilterDescendantsInstances = geometry

	local hiddenBlocked, hiddenPairs = 0, 0
	for index = 1, #points do
		for other = index + 1, #points do
			hiddenPairs += 1
			if Workspace:Raycast(points[index], points[other] - points[index], hiddenParams) then
				hiddenBlocked += 1
			end
		end
	end

	local withCover = {}
	for _, part in geometry do
		table.insert(withCover, part)
	end
	for _, part in cover do
		table.insert(withCover, part)
	end
	local coverBlocked, coverPairs = countVisible(points, withCover)

	return string.format(
		"  %d floor samples at y=%d, chest height (%d of %d grid points were inside a prop and skipped)\n  cover hidden (round start): %d/%d pairs blocked (%.0f%%)\n  cover raised: %d/%d pairs blocked (%.0f%%), so %.2fx more of the floor is hidden once cover exists",
		#points,
		SIGHTLINE_HEIGHT,
		skipped,
		SIGHTLINE_SAMPLES * SIGHTLINE_SAMPLES,
		hiddenBlocked,
		hiddenPairs,
		hiddenBlocked / hiddenPairs * 100,
		coverBlocked,
		coverPairs,
		coverBlocked / coverPairs * 100,
		coverPairs > 0 and coverBlocked / math.max(hiddenBlocked, 1) or 0
	)
end

local function reportHole(clone: Model): string
	-- A collapsed tile must be a hole, not a step: concrete under the tiles would make Collapsing
	-- Floor pure decoration. Cast straight down from a tile with the tile itself excluded, asking
	-- only for collidable parts, so the answer is what a falling player actually lands on.
	local floor = clone:FindFirstChild("Transforms") and clone.Transforms:FindFirstChild("Floor")
	local tile = floor and floor:FindFirstChild("Tile_1")
	if not tile then
		return "  no Tile_1 to cast from — Collapsing Floor names tiles by index"
	end

	-- Below the tile, not above it. Casting from `tile.Position + Size.Y` puts the origin above the
	-- tile's *top* face, so the first thing the ray hits is the tile it was asked about and the check
	-- reported "a collapsed tile is a two-stud step" about an arena whose floor is a frame.
	local origin = tile.Position - Vector3.new(0, tile.Size.Y / 2 + 0.1, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { clone }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
	local floorY = clone:GetAttribute(Tags.Attr.FloorY) or 0
	if not hit then
		return string.format("  from Tile_1 down: nothing collidable at all below y = %.1f", origin.Y)
	end
	return string.format(
		"  from Tile_1 down: first collidable part is %s at y = %.1f (%.1f below the floor) — a fall, not a step",
		hit.Instance.Name,
		hit.Position.Y,
		floorY - hit.Position.Y
	)
end

-- ------------------------------------------------------------------------------------------ entry

--! Logs the report one line at a time. Studio's output log truncates a single long entry — the
--! first version of this probe printed all of it through one `Log.info` and the findings were cut
--! off mid-sentence, which is worse than no report at all because it looks complete.
function ArenaProbe.logReport(arena: Model?)
	for _, line in string.split(ArenaProbe.report(arena), "\n") do
		Log.info("%s", line)
	end
end

--! Returns the report as text. Never raises: a broken probe must not stop a Play session.
function ArenaProbe.report(arena: Model?): string
	if not arena then
		return "ArenaProbe: no arena to probe"
	end

	-- The engine's spatial queries only see the Workspace, so the arena has to be cloned into it.
	-- A clone copies tags, and a tagged clone is a second arena as far as the rest of the game is
	-- concerned: `ArenaService.availableArenas` could hand it to a match starting this same frame,
	-- and a modifier collecting transformables would find its 369 parts. Strip every contract tag
	-- before it is parented — the probe must be invisible to the systems it measures.
	local clone = arena:Clone()
	clone.Name = "ArenaProbe_clone"
	for _, tag in Tags.List do
		CollectionService:RemoveTag(clone, tag)
		for _, descendant in clone:GetDescendants() do
			CollectionService:RemoveTag(descendant, tag)
		end
	end
	clone.Parent = Workspace

	local runOk, result = pcall(function()
		local lines = {
			"--- ArenaProbe: " .. arena.Name .. " ---",
			"budget", reportBudget(clone),
			"overlaps", reportOverlaps(clone),
			"markers", reportMarkers(clone),
			"spawns", reportSpawns(clone),
			"sightlines", reportSightlines(clone),
			"the hole", reportHole(clone),
		}
		return table.concat(lines, "\n")
	end)

	clone:Destroy()

	if not runOk then
		return "ArenaProbe FAILED: " .. tostring(result)
	end
	return result :: string
end

return ArenaProbe
