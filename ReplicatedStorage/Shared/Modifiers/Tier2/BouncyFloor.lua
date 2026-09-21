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
					-- The bounce itself is the Elasticity above; this is look only. Rubber is the one
					-- material that reads as bouncy, and unlike a made-up name it exists in the enum.
					ctx.Arena:SetGroupMaterial("Floor", Enum.Material.Rubber)
				end,
			},
		}
	end,
}
