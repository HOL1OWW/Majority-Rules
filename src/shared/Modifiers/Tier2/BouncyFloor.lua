--!nonstrict
--[[
	Bouncy Floor — the ground pushes back.
]]

return {
	Id = "BouncyFloor",
	DisplayName = "BOUNCY FLOOR",
	Blurb = "The floor bounces. Aim while airborne.",
	Tier = 2,
	Weight = 9,
	Tags = { "Spatial" },
	Conflicts = {},
	Requires = { "FlatFloor" },
	Effects = { "Bouncy" },

	Steps = function(ctx)
		return {
			{
				Channel = "floorGeometry",
				Phase = "Commit",
				Priority = 20,
				Label = "Bouncy physics",
				Run = function()
					ctx.Arena:SetGroupPhysics("Floor", {
						Elasticity = 0.85,
						Friction = 1.1,
					})
					ctx.Arena:SetGroupMaterial("Floor", Enum.Material.Trampoline) -- placeholder until art lands
				end,
			},
		}
	end,
}
