--!nonstrict
--[[
	Blackout — lights out. The arena becomes outlines and muzzle flash.

	Pairs badly (and therefore conflicts) with Fog: two vision modifiers stacked is not a
	game, it is a screensaver.
]]

return {
	Id = "Blackout",
	DisplayName = "BLACKOUT",
	Blurb = "Lights out. Fight by muzzle flash.",
	Tier = 1,
	Weight = 9,
	Tags = { "Environment", "Vision" },
	Conflicts = { "Vision" },
	Effects = { "VisionLimited", "Darkness" },

	Steps = function(ctx)
		return {
			{
				Channel = "lighting",
				Phase = "Before",
				Priority = 30,
				Label = "Blackout",
				Run = function()
					return ctx.Arena:TweenLighting({
						Brightness = 0,
						ClockTime = 0,
						Ambient = Color3.fromRGB(10, 10, 14),
						OutdoorAmbient = Color3.fromRGB(14, 14, 20),
						FogColor = Color3.fromRGB(6, 6, 9),
						FogStart = 40,
						FogEnd = 240,
					}, 2)
				end,
			},
		}
	end,
}
