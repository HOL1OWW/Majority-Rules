--!nonstrict
--[[
	No Jump — grounded. Every route is a walk, and cover becomes the only answer.

	Declares the "NoJump" effect so ModifierSim can catch it combining with a frictionless
	floor into an unplayable combination.
]]

return {
	Id = "NoJump",
	DisplayName = "NO JUMPING",
	Blurb = "Grounded. You walk everywhere now.",
	Tier = 1,
	Weight = 10,
	Tags = { "Mobility" },
	Conflicts = {},
	Effects = { "NoJump" },

	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 15,
				Label = "NoJump",
				Run = function()
					ctx.Gameplay:SetJumpEnabled(false)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:SetJumpEnabled(false, player)
	end,
}
