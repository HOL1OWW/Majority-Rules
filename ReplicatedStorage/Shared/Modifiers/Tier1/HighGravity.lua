--!nonstrict
--[[
	High Gravity — everything slams. Movement is a commitment.
]]

return {
	Id = "HighGravity",
	DisplayName = "HEAVY GRAVITY",
	Blurb = "You are heavy now. Good luck jumping.",
	Tier = 1,
	Weight = 10,
	Tags = { "Gravity" },
	Conflicts = { "Gravity" },
	Effects = { "GravityUp" },

	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 20,
				Label = "HighGravity gravity",
				Run = function()
					ctx.Arena:SetGravityScale(1.85)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:SetJumpPower(44, player)
	end,
}
