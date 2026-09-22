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
local CollectionService = game:GetService("CollectionService")
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
local GameplayService = require(Services.GameplayService)
local PlayerService = require(Services.PlayerService)
local RoundService = require(Services.RoundService)
local StatsService = require(Services.StatsService)

Log.info("MAJORITY RULES — server booting")

-- 0. every remote exists before any client asks for one: a RemoteEvent that is only created on
-- first use does not exist while clients are booting, and the client would wait out its timeout.
Net.materialize()

-- 0b. sprint is a server-side state machine; the client only sends a boolean.
GameplayService.setup()
Net.event(Net.Events.SprintInput).OnServerEvent:Connect(function(player, wants)
	GameplayService.requestSprint(player, wants)
end)

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

-- 3. an arena must exist, and in Studio it must be one this source describes
local arenas = ArenaService.availableArenas()

-- 3a. Adoption: a hand-built arena that reached the place through a path that drops tags
-- (Save to File, copy/paste) is healthy geometry with no contract stamps — the game cannot
-- see it, and a Team Test cloud server has no builder fallback to recover with, so boot dies.
-- Validate before adopting: the stamps are only added when the geometry itself is real
-- (tagged spawns exist), so a stray empty model can never masquerade as a playable arena.
-- Adoption freezes the arena as hand-authored: a human built it, so no generator may rebuild it.
if #arenas == 0 then
	local folder = ArenaService.container()
	if folder then
		for _, candidate in folder:GetChildren() do
			--! D-056: the arena root must be a Model, but moving an arena between a file and
			--! the place can re-root it as a Folder. A Folder with tagged spawns is a healthy
			--! arena in the wrong shape: convert it, or it is invisible to every code path
			--! (availableArenas filters IsA("Model")) and boot falls back to the outline.
			if candidate:IsA("Folder") then
				local hasSpawns = false
				for _, d in candidate:GetDescendants() do
					if d:IsA("BasePart") and CollectionService:HasTag(d, Tags.Spawn) then
						hasSpawns = true
						break
					end
				end
				if hasSpawns then
					local model = Instance.new("Model")
					model.Name = candidate.Name
					for _, child in candidate:GetChildren() do
						child.Parent = model
					end
					model.Parent = folder
					candidate:Destroy()
					candidate = model
					Log.warn("Arena '%s' was a Folder (re-rooted by a save or paste); converted it to a Model", model.Name)
				end
			end
			if candidate:IsA("Model") and not CollectionService:HasTag(candidate, Tags.Arena) then
				local spawnCount = 0
				for _, descendant in candidate:GetDescendants() do
					if descendant:IsA("BasePart") and CollectionService:HasTag(descendant, Tags.Spawn) then
						spawnCount += 1
					end
				end
				if spawnCount > 0 then
					candidate:SetAttribute(Tags.Attr.ArenaId, candidate.Name)
					candidate:SetAttribute(Tags.Attr.MaxPlayers, 8)
					candidate:SetAttribute(Tags.Attr.FloorY, 0)
					candidate:SetAttribute("HandAuthored", true)
					CollectionService:AddTag(candidate, Tags.Arena)
					table.insert(arenas, candidate)
					Log.warn(
						"Arena '%s' had no MRArena tag (its stamps were lost in a Save to File or paste); adopted it: %d spawn(s), frozen as hand-authored. Run ArenaValidator to confirm it fully.",
						candidate.Name,
						spawnCount
					)
				end
			end
		end
	end
end

if RunService:IsStudio() then
	-- The reference arena is *generated*, so the copy sitting in the place is a build artifact that
	-- can silently be several revisions old: the game plays the old hall while the source says
	-- otherwise, and no check can see it because there is no file to differ from. Compare the
	-- stamp every build writes and rebuild on a mismatch, so pressing Play always tests this source.
	-- Exception: an arena stamped HandAuthored belongs to a human. It is never rebuilt, and its
	-- hand edits survive every Play — that is what the attribute promises.
	local builders = {
		Arena = require(script.Parent.Dev.BuildOutline),
	}
	local staleReported = false
	for _, arena in arenas do
		if arena:GetAttribute("HandAuthored") == true then
			Log.info("Arena '%s' is hand-authored: leaving it untouched (hand edits persist)", arena.Name)
			continue
		end
		local builder = builders[arena.Name]
		local revision = arena:GetAttribute("GeneratorRevision")
		if builder and revision ~= builder.Revision then
			if not staleReported then
				Log.warn(
					"Arena '%s' was generated by revision %s; this source is revision %d. Rebuilding in Studio.",
					arena.Name,
					tostring(revision),
					builder.Revision
				)
				staleReported = true
			end
			arena:Destroy()
		end
	end
	if staleReported then
		arenas = ArenaService.availableArenas()
	end
	if #arenas == 0 then
		builders.Arena.build()
		arenas = ArenaService.availableArenas()
		Log.info("No arena found: built the outline arena")
	end
end
if #arenas == 0 then
	--! D-055: the fallback builder must run everywhere, not just in Studio. A Team Test
	--! server boots the published place in the cloud, reports IsStudio() == false, and used
	--! to die here whenever that published copy was missing its arena (e.g. saved while the
	--! Arenas folder was temporarily out in Workspace). Building the outline in the cloud is
	--! always better than not booting; the next real publish replaces it.
	local ok, BuildOutline = pcall(require, script.Parent.Dev.BuildOutline)
	if ok then
		BuildOutline.build()
		arenas = ArenaService.availableArenas()
		Log.warn("No arena found: built the outline arena as a fallback (%s)", RunService:IsStudio() and "Studio" or "cloud/server")
	else
		Log.warn("No arena found and the fallback builder failed to load")
	end
end
if #arenas == 0 then
	Log.error("No arena in ServerStorage.Arenas. The game cannot run without one.")
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

		-- 3c. measure the geometry itself. The validator answers "does this arena obey the contract",
		-- which is not the same question as "is it built the way this source says", and every real
		-- bug in this arena has been on the wrong side of that gap. Studio only, and it costs a
		-- second of load time for the clone it measures.
		local probeOk, ArenaProbe = pcall(require, script.Parent.Dev.ArenaProbe)
		if probeOk and ArenaProbe then
			for _, arena in ArenaService.availableArenas() do
				ArenaProbe.logReport(arena)
			end
		else
			Log.warn("ArenaProbe did not load: %s", tostring(ArenaProbe))
		end
	end)
end

-- 4. combat, then the show. BotService connects its tick here and stays inert until a round asks
-- it for bots (DevConfig BotCount), so this is harmless in a live server.
CombatService.start()
BotService.setup()
StatsService.start()
RoundService.start()

Log.info("Boot complete")
