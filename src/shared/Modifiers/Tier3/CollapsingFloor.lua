--!nonstrict
--[[
	Collapsing Floor — tiles drop away from under the players, one group at a time.

	Requires an arena with tiled floors: the map team splits the floor into parts whose
	`TransformGroup` attribute lists `Tile_1`, `Tile_2` and so on (they can also all list
	`Floor`, so that Small Map still scales the whole thing as one surface).

	It deliberately stops at 60% of the tiles. Removing the entire floor does not create a
	better fight, it creates a swimming pool.
]]

local COLLAPSE_INTERVAL = 3.5
local MAX_FRACTION = 0.6

return {
	Id = "CollapsingFloor",
	DisplayName = "COLLAPSING FLOOR",
	Blurb = "The floor is leaving. Do not be standing on it.",
	Tier = 3,
	Weight = 10,
	Tags = { "Spatial", "Chaos" },
	Conflicts = { "Shrink", "ZeroFriction" },
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
	end,

	OnRoundStart = function(ctx)
		ctx.Round.Flags.Tiles = ctx.Round.Flags.Tiles or {}
		ctx.Round.Flags.TileIndex = ctx.Round.Flags.TileIndex or 0
		ctx.Round.Flags.TileTimer = 0
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
		if flags.TileIndex >= limit then
			return
		end

		flags.TileIndex += 1
		ctx.Arena:SetGroupHidden(tiles[flags.TileIndex], true, 0.35)
	end,
}
