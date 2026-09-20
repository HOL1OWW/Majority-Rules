--!nonstrict
--[[
	Moving Arena — the entire arena drifts side to side while the round runs.

	PERFORMANCE NOTE: this moves every anchored part of the arena model, so it is the most
	expensive modifier in the catalogue. The drift is stepped at a fixed rate rather than every
	frame, and the amplitude is deliberately small. If Profiler shows this dominating frame
	time on mobile, cut the update rate before cutting the modifier.
]]

local DRIFT_AMPLITUDE = 18
local DRIFT_SPEED = 0.55
local UPDATE_INTERVAL = 1 / 20

return {
	Id = "MovingArena",
	DisplayName = "MOVING ARENA",
	Blurb = "The whole arena is drifting. Compensate.",
	Tier = 3,
	Weight = 8,
	Tags = { "Spatial", "Chaos" },
	Conflicts = {},
	Effects = { "Drift" },

	OnRoundStart = function(ctx)
		ctx.Round.Flags.DriftTime = 0
		ctx.Round.Flags.DriftAccumulator = 0
	end,

	Tick = function(ctx, dt)
		local flags = ctx.Round.Flags
		flags.DriftTime = (flags.DriftTime or 0) + dt
		flags.DriftAccumulator = (flags.DriftAccumulator or 0) + dt

		if flags.DriftAccumulator < UPDATE_INTERVAL then
			return
		end
		flags.DriftAccumulator = 0

		local offset = math.sin(flags.DriftTime * DRIFT_SPEED) * DRIFT_AMPLITUDE
		ctx.Arena:SetDriftOffset(Vector3.new(0, 0, offset))
	end,

	OnRoundEnd = function(ctx)
		ctx.Arena:SetDriftOffset(Vector3.new(0, 0, 0))
	end,
}
