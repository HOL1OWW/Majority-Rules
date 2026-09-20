--!nonstrict
--[[
	Low Gravity — everyone floats, fights get vertical.
]]

return {
	Id = "LowGravity",
	DisplayName = "LOW GRAVITY",
	Blurb = "Everyone floats. Fights go vertical.",
	Tier = 1,
	Weight = 12,
	Tags = { "Gravity" },
	Conflicts = { "Gravity" }, -- any other gravity modifier, including High Gravity
	Effects = { "GravityDown", "AirTime" },

	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 20,
				Label = "LowGravity gravity",
				Run = function()
					ctx.Arena:SetGravityScale(0.35)
				end,
			},
			{
				Channel = "lighting",
				Phase = "Before",
				Priority = 5,
				Label = "LowGravity tint",
				Run = function()
					return ctx.Arena:TweenLighting({
						Ambient = Color3.fromRGB(26, 24, 42),
						OutdoorAmbient = Color3.fromRGB(70, 64, 110),
					}, 1.4)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		-- A little extra lift so the modifier reads as "floaty" rather than "slow".
		ctx.Gameplay:SetJumpPower(62, player)
	end,
}
