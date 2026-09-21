--!nonstrict
--[[
	Sluggish — wading through it. Positioning becomes the whole game.
]]

return {
	Id = "Sluggish",
	DisplayName = "SLUGGISH",
	Blurb = "Everyone is slow. Positioning is everything.",
	Tier = 1,
	Weight = 9,
	Tags = { "Mobility" },
	Conflicts = { "SpeedBoost" },
	Effects = { "SlowWalk" },

	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 10,
				Label = "Sluggish",
				Run = function()
					ctx.Gameplay:SetWalkSpeed(11)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:SetWalkSpeed(11, player)
	end,
}
