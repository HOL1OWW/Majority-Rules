--!nonstrict
--[[
	Small Map — the arena physically closes in before the round starts.

	This is the clearest demonstration of the game's core promise: the vote does not change a
	number in a config file, it moves the floor you are standing on.
]]

return {
	Id = "SmallMap",
	DisplayName = "SMALL MAP",
	Blurb = "The arena shrinks. Contact is immediate.",
	Tier = 2,
	Weight = 10,
	Tags = { "Spatial", "Shrink" },
	Conflicts = { "Shrink" },
	Requires = { "FlatFloor" },
	Effects = { "Shrink" },

	Steps = function(ctx)
		local axes = Vector3.new(1, 0, 1)
		return {
			{
				Channel = "floorGeometry",
				Phase = "Before",
				Priority = 30,
				Label = "SmallMap floor",
				Run = function()
					return ctx.Arena:ScaleGroup("Floor", 0.62, 2.4, axes)
				end,
			},
			{
				Channel = "walls",
				Phase = "Before",
				Priority = 30,
				Label = "SmallMap walls",
				Run = function()
					return ctx.Arena:ScaleGroup("Wall", 0.62, 2.4, axes)
				end,
			},
		}
	end,
}
