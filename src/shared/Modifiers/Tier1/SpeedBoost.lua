--!nonstrict
--[[
	Speed Boost — everything is faster, including the mistakes.
]]

return {
	Id = "SpeedBoost",
	DisplayName = "EVERYONE IS FAST",
	Blurb = "Everyone gets faster. Aiming gets harder.",
	Tier = 1,
	Weight = 11,
	Tags = { "Mobility" },
	Conflicts = { "SlowSpeed" },
	Effects = { "FastWalk" },

	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 10,
				Label = "SpeedBoost",
				Run = function()
					ctx.Gameplay:SetWalkSpeed(23)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:SetWalkSpeed(23, player)
	end,
}
