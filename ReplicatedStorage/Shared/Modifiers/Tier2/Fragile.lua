--!nonstrict
--[[
	Fragile — everyone is made of paper. Fights last a heartbeat.
]]

return {
	Id = "Fragile",
	DisplayName = "FRAGILE",
	Blurb = "One good shot is all it takes.",
	Tier = 2,
	Weight = 10,
	Tags = { "Combat" },
	Conflicts = {},
	Effects = { "LowHealth" },

	Steps = function(ctx)
		return {
			{
				Channel = "combat",
				Phase = "Commit",
				Priority = 20,
				Label = "Fragile health",
				Run = function()
					ctx.Gameplay:SetMaxHealth(45)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:SetMaxHealth(45, player)
	end,
}
