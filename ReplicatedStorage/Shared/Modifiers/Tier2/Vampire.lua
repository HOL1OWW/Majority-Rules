--!nonstrict
--[[
	Vampire — landing a hit heals you. Aggression is the only strategy.

	The lifesteal fraction is read by CombatService from the round flags, so there is exactly
	one place that heals anyone.
]]

return {
	Id = "Vampire",
	DisplayName = "VAMPIRE",
	Blurb = "Damage you deal heals you. Get closer.",
	Tier = 2,
	Weight = 9,
	Tags = { "Combat" },
	Conflicts = {},
	Effects = { "Lifesteal" },

	Steps = function(ctx)
		return {
			{
				Channel = "combat",
				Phase = "Commit",
				Priority = 20,
				Label = "Vampire lifesteal",
				Run = function()
					ctx.Gameplay:SetLifesteal(0.35)
				end,
			},
			{
				Channel = "lighting",
				Phase = "Before",
				Priority = 10,
				Label = "Vampire tint",
				Run = function()
					return ctx.Arena:TweenLighting({
						Ambient = Color3.fromRGB(44, 12, 18),
						OutdoorAmbient = Color3.fromRGB(96, 26, 34),
					}, 1.5)
				end,
			},
		}
	end,
}
