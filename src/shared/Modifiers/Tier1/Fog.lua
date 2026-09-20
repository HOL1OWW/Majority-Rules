--!nonstrict
--[[
	Fog — the arena closes in visually. Nobody sees the other end of the map.

	This is intentionally one of the first modifiers a new player ever votes on: it is
	instantly legible, changes how you play (listen, close distance, hold angles) and costs
	nothing to run.
]]

return {
	Id = "Fog",
	DisplayName = "FOG",
	Blurb = "Thick fog. You will hear them before you see them.",
	Tier = 1,
	Weight = 12,
	Tags = { "Environment", "Vision" },
	Conflicts = { "Vision" },
	Effects = { "VisionLimited" },

	Steps = function(ctx)
		return {
			{
				Channel = "lighting",
				Phase = "Before",
				Priority = 30,
				Label = "Fog banks",
				Run = function()
					return ctx.Arena:TweenLighting({
						FogColor = Color3.fromRGB(142, 146, 156),
						FogStart = 6,
						FogEnd = 68,
						Ambient = Color3.fromRGB(96, 99, 108),
						OutdoorAmbient = Color3.fromRGB(132, 136, 146),
						Brightness = 1.6,
					}, 1.8)
				end,
			},
		}
	end,
}
