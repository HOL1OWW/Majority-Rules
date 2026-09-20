--!nonstrict
--[[
	Ricochet — bullets bounce once. Corners are now dangerous.

	CombatService reads the flag, so the bounce is validated and simulated on the server. A
	client cannot opt itself into ricochet.
]]

return {
	Id = "Ricochet",
	DisplayName = "RICOCHET",
	Blurb = "Bullets bounce once. Corners are lethal.",
	Tier = 3,
	Weight = 9,
	Tags = { "Combat", "Chaos" },
	Conflicts = { "MeleeOnly" },
	Effects = { "Ricochet" },

	Steps = function(ctx)
		return {
			{
				Channel = "combat",
				Phase = "Commit",
				Priority = 30,
				Label = "Ricochet flag",
				Run = function()
					ctx.Gameplay:Flag("Ricochet", true)
				end,
			},
		}
	end,

	OnRoundStart = function(ctx)
		ctx.Gameplay:Flag("Ricochet", true)
	end,
}
