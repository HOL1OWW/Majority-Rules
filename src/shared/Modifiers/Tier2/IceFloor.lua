--!nonstrict
--[[
	Ice Floor — frictionless. Momentum is now a weapon.

	Conflicts are declared explicitly against the modifiers that combine with it into an
	unplayable round (no jump + no friction = you cannot stop and you cannot leave the
	ground). ModifierSim also flags this rule generically, but declaring it here means the
	ballot never even offers the combination.
]]

return {
	Id = "IceFloor",
	DisplayName = "ICE FLOOR",
	Blurb = "Slippery. You cannot stop, only steer.",
	Tier = 2,
	Weight = 9,
	Tags = { "Spatial" },
	Conflicts = { "NoJump", "Sluggish", "Shrink" },
	Requires = { "FlatFloor" },
	Effects = { "ZeroFriction" },

	Steps = function(ctx)
		return {
			{
				Channel = "floorGeometry",
				Phase = "Commit",
				Priority = 20,
				Label = "Ice physics",
				Run = function()
					ctx.Arena:SetGroupPhysics("Floor", {
						Friction = 0.02,
						Elasticity = 0.05,
					})
					ctx.Arena:SetGroupMaterial("Floor", Enum.Material.Ice)
				end,
			},
			{
				Channel = "lighting",
				Phase = "Before",
				Priority = 10,
				Label = "Ice tint",
				Run = function()
					return ctx.Arena:TweenLighting({
						FogColor = Color3.fromRGB(178, 214, 236),
						FogStart = 30,
						FogEnd = 320,
						OutdoorAmbient = Color3.fromRGB(150, 182, 205),
					}, 1.6)
				end,
			},
		}
	end,
}
