--!nonstrict
--[[
	Rising Lava — the floor becomes a clock.

	The hazard volume is authored by the map team as a part in the `Lava` transform group,
	hidden below the arena. This modifier raises it and switches it on; damage itself lives in
	CombatService, so every hazard in the game hurts the same way.

	Conflicts with the other shrinking modifiers on purpose: lava plus collapsing walls is two
	clocks ticking in the same round, which reads as noise rather than escalation.
]]

local RISE_PER_SECOND = 0.34

return {
	Id = "RisingLava",
	DisplayName = "RISING LAVA",
	Blurb = "The floor is lava. It is climbing.",
	Tier = 3,
	Weight = 10,
	Tags = { "Environment", "Chaos" },
	Conflicts = { "Shrink", "CollapsingFloor" },
	Requires = { "Hazard", "Lava" },
	Effects = { "Hazard", "Lava" },

	Steps = function(ctx)
		return {
			{
				Channel = "hazard",
				Phase = "Before",
				Priority = 40,
				Label = "Lava rise",
				Run = function()
					ctx.Arena:SetHazardEnabled("Lava", true, 1)
					return ctx.Arena:MoveGroup("Lava", Vector3.new(0, 12, 0), 2.5)
				end,
			},
		}
	end,

	OnRoundStart = function(ctx)
		ctx.Arena:SetHazardEnabled("Lava", true, 0.5)
	end,

	Tick = function(ctx, dt)
		ctx.Arena:MoveGroup("Lava", Vector3.new(0, RISE_PER_SECOND * dt, 0), 0)
	end,
}
