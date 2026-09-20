--!nonstrict
--[[
	_TEMPLATE — copy me into Tier1/, Tier2/ or Tier3/ and rename the file to your Id.

	Read docs/02-MODIFIER-API.md for the full capability list. The short version:

	  * You never touch Workspace. You get `ctx` and you call capabilities.
	  * Prefer declarative `Steps` over `Tick`. Steps are merged with every other active
	    modifier into ONE timeline with ONE synchronised commit frame, so two modifiers that
	    both move the floor cannot race each other.
	  * Channels: gravity, lighting, floorGeometry, walls, cover, loot, audio, camera, hazard
	  * Phases: Before (visuals start) -> Commit (gameplay values, one frame) -> After
	  * Declare `Effects` even if nothing reads them yet: the combo simulator uses them to
	    catch unwinnable modifier combinations before players ever see them.
]]

local Template = {
	Id = "Template",
	DisplayName = "Template",
	Blurb = "One line a 9 year old reads in under a second.",

	Tier = 1, -- 1 warm up | 2 spice | 3 chaos
	Weight = 10, -- relative chance of appearing on a ballot
	Tags = { "Gravity" }, -- Gravity | Spatial | Combat | Environment | Chaos
	Conflicts = {}, -- modifier ids ("LowGravity") or category tags ("Gravity")
	Requires = {}, -- arena feature tags that must be present
	Bans = {}, -- arena feature tags that must be absent
	Effects = { "Example" }, -- declarative, consumed by ModifierSim

	-- Optional. Runs on the server before the reveal, while players are still voting.
	Prepare = function(ctx)
		ctx.Log("%s prepare", "Template")
	end,

	-- The arena change itself. Return steps; the scheduler runs them.
	Steps = function(ctx)
		return {
			{
				Channel = "gravity",
				Phase = "Commit",
				Priority = 10,
				Label = "Template gravity",
				Run = function()
					ctx.Arena:SetGravityScale(0.5)
				end,
			},
		}
	end,

	-- Optional lifecycle hooks.
	OnRoundStart = function(ctx) end,
	OnCharacterSpawn = function(ctx, player) end,
	OnPlayerDied = function(ctx, player, killer) end,
	Tick = function(ctx, dt) end,
	OnRoundEnd = function(ctx) end,
	Revert = function(ctx) end,
}

return Template
