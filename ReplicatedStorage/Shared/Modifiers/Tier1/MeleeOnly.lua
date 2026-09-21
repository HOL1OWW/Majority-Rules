--!nonstrict
--[[
	Melee Only — nobody has a gun. Crates are removed entirely so the promise holds.
]]

local MELEE = { "Sword" }

return {
	Id = "MeleeOnly",
	DisplayName = "MELEE ONLY",
	Blurb = "No guns. Just judgement.",
	Tier = 1,
	Weight = 9,
	Tags = { "Combat", "Loadout" },
	Conflicts = { "Loadout" },
	Effects = { "LoadoutOverride", "NoRanged" },

	Steps = function(ctx)
		return {
			{
				Channel = "loot",
				Phase = "Commit",
				Priority = 25,
				Label = "MeleeOnly pool",
				Run = function()
					ctx.Loot:RestrictPoolTo(MELEE)
					ctx.Loot:HaltCrates()
					ctx.Gameplay:SetDefaultLoadout(MELEE)
				end,
			},
		}
	end,

	OnCharacterSpawn = function(ctx, player)
		ctx.Gameplay:ForceLoadout(player, MELEE)
	end,
}
