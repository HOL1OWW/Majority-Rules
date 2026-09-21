--!nonstrict
--[[
	Collapsing Floor — tiles drop away from under the players, in batches, on a timer.

	Requires an arena with tiled floors: the map team splits the floor into parts whose
	`TransformGroup` attribute lists `Tile_1`, `Tile_2` and so on (they can also all list
	`Floor`, so that Small Map still scales the whole thing as one surface).

	It deliberately stops at 60% of the tiles. Removing the entire floor does not create a
	better fight, it creates a swimming pool.

	PACE IS THE MODIFIER'S, NOT THE ARENA'S. It promises "most of the floor gone within a
	round", and the batch size is derived from the tile count so that promise holds on any
	arena — see TARGET_SECONDS below. An arena with more tiles must not get a slower collapse.
]]

local Log = require(script.Parent.Parent.Parent.Util.Log)

local COLLAPSE_INTERVAL = 3.5
local MAX_FRACTION = 0.6
-- The modifier promises a *fraction of the floor gone within a round*, so the step size has to
-- scale with the tile count. Removing one tile per interval made the pace a property of the
-- arena: on a 16-tile floor that is 9 tiles over 31.5s, but on a 64-tile floor the same 60%
-- would take 133 seconds and the round ends with the floor barely touched. TARGET_SECONDS keeps
-- the collapse a fixed length of time on any arena, and on a 16-tile arena it works out to
-- exactly the one-tile-per-step it has always been, so nothing that is already tuned moves.
local TARGET_SECONDS = 32

local function planPacing(tileCount: number): (number, number)
	local limit = math.floor(tileCount * MAX_FRACTION)
	local budget = math.max(1, math.floor(TARGET_SECONDS / COLLAPSE_INTERVAL))
	local batch = math.max(1, math.ceil(limit / budget))
	-- The step count reported is what the integer batch size actually needs, not the budget: a
	-- batch of 5 cannot fill a limit of 38 in 9 steps, it takes 8. Reporting the budget would make
	-- the log claim a step that never happens.
	return batch, math.ceil(limit / batch)
end

return {
	Id = "CollapsingFloor",
	DisplayName = "COLLAPSING FLOOR",
	Blurb = "The floor is leaving. Do not be standing on it.",
	Tier = 3,
	Weight = 10,
	Tags = { "Spatial", "Chaos" },
	Conflicts = { "Shrink", "IceFloor" },
	Requires = { "Tiles" },
	Effects = { "Collapse" },

	Prepare = function(ctx)
		local tiles = {}
		for _, name in ctx.Arena:GroupNames() do
			if string.sub(name, 1, 5) == "Tile_" then
				table.insert(tiles, name)
			end
		end
		table.sort(tiles, function(a, b)
			-- numeric order, not lexicographic: Tile_10 must come after Tile_9
			local left = tonumber(string.match(a, "%d+")) or 0
			local right = tonumber(string.match(b, "%d+")) or 0
			return left < right
		end)

		ctx.Round.Flags.Tiles = tiles
		ctx.Round.Flags.TileIndex = 0
		ctx.Round.Flags.TileTimer = 0
		ctx.Round.Flags.TileSteps = 0
		ctx.Round.Flags.TileFirstDrop = nil
		local batch, steps = planPacing(#tiles)
		ctx.Round.Flags.TilesPerStep = batch
		ctx.Round.Flags.TileStepsPlanned = steps
	end,

	OnRoundStart = function(ctx)
		local flags = ctx.Round.Flags
		flags.Tiles = flags.Tiles or {}
		flags.TileIndex = flags.TileIndex or 0
		flags.TileTimer = 0
		-- OnRoundStart can run without Prepare (a reloaded round, a variant swap), and a missing
		-- step size would silently fall back to one tile per interval — the slow behaviour this
		-- exists to prevent.
		if not flags.TilesPerStep then
			local batch, steps = planPacing(#flags.Tiles)
			flags.TilesPerStep = batch
			flags.TileStepsPlanned = steps
		end
	end,

	Tick = function(ctx, dt)
		local flags = ctx.Round.Flags
		local tiles = flags.Tiles
		if not tiles or #tiles == 0 then
			return
		end

		flags.TileTimer = (flags.TileTimer or 0) + dt
		if flags.TileTimer < COLLAPSE_INTERVAL then
			return
		end
		flags.TileTimer = 0

		local limit = math.floor(#tiles * MAX_FRACTION)
		local batch = flags.TilesPerStep or 1
		local hidden = 0
		for _ = 1, batch do
			if flags.TileIndex >= limit then
				break
			end
			flags.TileIndex += 1
			hidden += 1
			ctx.Arena:SetGroupHidden(tiles[flags.TileIndex], true, 0.35)
		end

		-- Studio-only. The pace is the whole point of this modifier and it is otherwise invisible:
		-- nothing in the log says how much floor has gone or how long it took, so tuning the batch
		-- size meant sampling the arena from outside the game.
		if hidden > 0 then
			flags.TileSteps = (flags.TileSteps or 0) + 1
			flags.TileFirstDrop = flags.TileFirstDrop or os.clock()
			Log.debug(
				"CollapsingFloor: %d/%d tiles gone, step %d of %d planned, %.1fs since the first tile dropped",
				flags.TileIndex,
				limit,
				flags.TileSteps,
				flags.TileStepsPlanned or -1,
				os.clock() - flags.TileFirstDrop
			)
		end
	end,
}
