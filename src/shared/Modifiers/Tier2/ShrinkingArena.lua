--!nonstrict
--[[
	Shrinking Arena — the walls close in while you are still fighting.

	Unlike Small Map this happens *during* the round, so it is a timer disguised as geometry.
	It stops at 45% of the original footprint: if the arena ever reached zero the round would
	end as a coin flip rather than a fight.
]]

local SHRINK_INTERVAL = 5
local SHRINK_FACTOR = 0.94
local MIN_SCALE = 0.45

return {
	Id = "ShrinkingArena",
	DisplayName = "COLLAPSING WALLS",
	Blurb = "The walls creep in. The round has a clock now.",
	Tier = 2,
	Weight = 9,
	Tags = { "Spatial", "Shrink" },
	Conflicts = { "Shrink" },
	Requires = { "FlatFloor" },
	Effects = { "Shrink" },

	OnRoundStart = function(ctx)
		ctx.Round.Flags.ShrinkScale = 1
		ctx.Round.Flags.ShrinkTimer = 0
	end,

	Tick = function(ctx, dt)
		local flags = ctx.Round.Flags
		flags.ShrinkTimer = (flags.ShrinkTimer or 0) + dt
		local scale = flags.ShrinkScale or 1

		if flags.ShrinkTimer < SHRINK_INTERVAL or scale <= MIN_SCALE then
			return
		end

		flags.ShrinkTimer = 0
		flags.ShrinkScale = math.max(scale * SHRINK_FACTOR, MIN_SCALE)
		ctx.Arena:ScaleGroup("Wall", SHRINK_FACTOR, 1, Vector3.new(1, 0, 1))
	end,
}
