--!nonstrict
--[[
	Double Jump — an extra jump in mid-air.

	Character movement is client-authoritative in Roblox, so the honest implementation is a
	round flag the client reads plus a slightly raised jump power. The flag is replicated in
	the round state, so the client can never enable something the server did not vote for.
]]

return {
	Id = "DoubleJump",
	DisplayName = "DOUBLE JUMP",
	Blurb = "Jump again in mid-air.",
	Tier = 2,
	Weight = 11,
	Tags = { "Mobility" },
	Conflicts = { "NoJump" },
	Effects = { "AirJump" },

	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 12,
				Label = "DoubleJump",
				Run = function()
					ctx.Gameplay:Flag("DoubleJump", true)
					ctx.Gameplay:SetJumpPower(56)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:SetJumpPower(56, player)
	end,
}
