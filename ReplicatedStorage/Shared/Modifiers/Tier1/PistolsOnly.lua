--!nonstrict
--[[
	Pistols Only — fast, low damage, every shot matters.
]]

local PISTOLS = { "Pistol", "RapidPistol" }

return {
	Id = "PistolsOnly",
	DisplayName = "PISTOLS ONLY",
	Blurb = "Small guns. Big nerves.",
	Tier = 1,
	Weight = 11,
	Tags = { "Combat", "Loadout" },
	Conflicts = { "Loadout" },
	Effects = { "LoadoutOverride" },

	Steps = function(ctx)
		return {
			{
				Channel = "loot",
				Phase = "Commit",
				Priority = 20,
				Label = "PistolsOnly pool",
				Run = function()
					ctx.Loot:RestrictPoolTo(PISTOLS)
					ctx.Gameplay:SetDefaultLoadout(PISTOLS)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:ForceLoadout(player, PISTOLS)
	end,
}
