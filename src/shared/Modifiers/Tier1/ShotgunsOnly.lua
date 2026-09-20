--!nonstrict
--[[
	Shotguns Only — the loadout override, and the template for every other weapon modifier.

	Note the pattern: restrict the crate pool AND force the loadout, and re-apply on every
	character spawn, because a player who dies and respawns must still be holding a shotgun.
]]

local SHOTGUNS = { "Shotgun", "SawnOff" }

return {
	Id = "ShotgunsOnly",
	DisplayName = "SHOTGUNS ONLY",
	Blurb = "Close range. Every fight is a decision.",
	Tier = 1,
	Weight = 12,
	Tags = { "Combat", "Loadout" },
	Conflicts = { "Loadout" },
	Effects = { "LoadoutOverride" },

	Steps = function(ctx)
		return {
			{
				Channel = "loot",
				Phase = "Commit",
				Priority = 20,
				Label = "ShotgunsOnly pool",
				Run = function()
					ctx.Loot:RestrictPoolTo(SHOTGUNS)
					ctx.Gameplay:SetDefaultLoadout(SHOTGUNS)
				end,
			},
		}
	end,

	OnRoundStart = function(ctx)
		ctx.Loot:RestrictPoolTo(SHOTGUNS)
		ctx.Gameplay:SetDefaultLoadout(SHOTGUNS)
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:ForceLoadout(player, SHOTGUNS)
	end,
}
