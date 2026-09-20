--!nonstrict
--[[
	Cover Crates Drop — cover pieces rise out of the floor.

	The map team authors these as parts in the `Cover` transform group with AnchorState =
	Hidden. The modifier only reveals them, which means the art is entirely a map-side job and
	needs no script changes to improve.
]]

return {
	Id = "CoverCrates",
	DisplayName = "COVER DROPS",
	Blurb = "Cover slams up out of the floor.",
	Tier = 2,
	Weight = 11,
	Tags = { "Spatial" },
	Conflicts = {},
	Requires = { "Cover" },
	Effects = { "Cover" },

	Steps = function(ctx)
		return {
			{
				Channel = "cover",
				Phase = "Before",
				Priority = 40,
				Label = "Cover rise",
				Run = function()
					return ctx.Arena:SetGroupHidden("Cover", false, 0.9)
				end,
			},
		}
	end,
}
