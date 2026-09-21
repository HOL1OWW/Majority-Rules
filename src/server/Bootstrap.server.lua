--!nonstrict
--[[
	Server bootstrap. This is the only script in the game.

	Boot order matters and is deliberate:

	  1. player service first, so CharacterAutoLoads is off before anyone can spawn
	  2. validate the modifier registry and say so loudly, because a broken modifier is
	     silent at runtime and someone has to be told
	  3. make sure an arena exists (in Studio, build the gray-box Foundry if the folder is
	     empty, so pressing Play always gives you a game)
	  4. start combat, then start the match loop
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modifiers = require(Shared.Modifiers)
local Net = require(Shared.Net)
local Tags = require(Shared.Tags)
local Log = require(Shared.Util.Log)

local Services = script.Parent:WaitForChild("Services")
local ArenaService = require(Services.ArenaService)
local BotService = require(Services.BotService)
local CombatService = require(Services.CombatService)
local PlayerService = require(Services.PlayerService)
local RoundService = require(Services.RoundService)

Log.info("MAJORITY RULES — server booting")

-- 0. every remote exists before any client asks for one: a RemoteEvent that is only created on
-- first use does not exist while clients are booting, and the client would wait out its timeout.
Net.materialize()

-- 1. no default respawning: this is an elimination game and the engine owns spawn timing
PlayerService.setup()

-- 2. the modifier registry is the product; validate it before it can hurt anyone
local report = Modifiers.validate()
if report.ok then
	Log.info("Modifier registry OK: %d modifiers loaded", report.count)
else
	Log.warn("Modifier registry has %d problem(s):", #report.problems)
	for _, problem in report.problems do
		Log.warn("  - %s", problem)
	end
end

-- 3. an arena must exist
local arenas = ArenaService.availableArenas()
if #arenas == 0 then
	if RunService:IsStudio() then
		local BuildFoundry = require(script.Parent.Dev.BuildFoundry)
		BuildFoundry.build()
		arenas = ArenaService.availableArenas()
		Log.info("No arena found: built the gray-box Foundry reference arena")
	else
		Log.error("No arena in ServerStorage.Arenas. The game cannot run without one.")
	end
end
if #arenas > 0 then
	local names = {}
	for _, arena in arenas do
		table.insert(names, arena.Name)
	end
	Log.info("Arenas available: %s", table.concat(names, ", "))
end

-- 3b. in Studio, run the contract checks and print them. A broken arena or an unplayable
-- modifier combination should be loud during development and silent in production.
if RunService:IsStudio() then
	task.spawn(function()
		local tools = ServerStorage:FindFirstChild("Tools")
		if not tools then
			return
		end

		local validatorOk, Validator = pcall(require, tools:FindFirstChild("ArenaValidator"))
		if validatorOk and Validator then
			Log.info("\n%s", Validator.reportAll())
		end

		local simOk, ModifierSim = pcall(require, tools:FindFirstChild("ModifierSim"))
		if simOk and ModifierSim then
			local featureSets = {}
			for _, arena in ArenaService.availableArenas() do
				table.insert(featureSets, Tags.featuresOf(arena))
			end
			Log.info("\n%s", ModifierSim.report({ arenaFeatures = featureSets }))
		end
	end)
end

-- 4. combat, then the show. BotService connects its tick here and stays inert until a round asks
-- it for bots (DevConfig BotCount), so this is harmless in a live server.
CombatService.start()
BotService.setup()
RoundService.start()

Log.info("Boot complete")
