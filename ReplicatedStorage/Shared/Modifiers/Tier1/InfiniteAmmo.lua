--!nonstrict
--[[
	Infinite Ammo — no reloading, no downtime, no excuses.

	This modifier's entire behaviour is a round flag read by CombatService. That is the
	point: a modifier should be able to express itself as data when it can.
]]

return {
	Id = "InfiniteAmmo",
	DisplayName = "INFINITE AMMO",
	Blurb = "Never reload again.",
	Tier = 1,
	Weight = 10,
	Tags = { "Combat" },
	Conflicts = {},
	Effects = { "InfiniteAmmo" },

	Steps = function(ctx)
		return {
			{
				Channel = "loot",
				Phase = "Commit",
				Priority = 5,
				Label = "InfiniteAmmo",
				Run = function()
					ctx.Gameplay:Flag("InfiniteAmmo", true)
				end,
			},
		}
	end,

	OnRoundStart = function(ctx)
		ctx.Gameplay:Flag("InfiniteAmmo", true)
	end,
}
