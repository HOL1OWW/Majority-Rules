--!nonstrict
--[[
	RoundService — the state machine, and the closest thing this game has to a director.

	One round looks like this:

		VoteOpen (20s) -> VoteLock (2s) -> [TieBreak (5s, only on a tie)] -> Reveal (2.5s)
		-> Transform (<=4.5s, players frozen) -> Countdown (3s) -> Live (50-75s)
		-> RoundEnd (8s)

	and a match is 6 of those (3 in a Skirmish), ending in a 15s MatchEnd.

	Everything is server-authoritative and driven from this one coroutine, so there is exactly
	one place where the game's state can change. Clients render UI as a pure function of the
	state they are told about; they never decide anything.

	This service is also where the modifier lifecycle is orchestrated, in this order:

		resolve winners -> Prepare each winner -> collect + schedule steps -> OnRoundStart
		-> per-character hooks on every spawn -> Tick during Live -> OnRoundEnd -> Revert
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modifiers = require(Shared.Modifiers)
local Escalation = require(Shared.Config.Escalation)
local Combat = require(Shared.Config.Combat)
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)
local SeededRandom = require(Shared.Util.SeededRandom)

local AnalyticsService = require(script.Parent.AnalyticsService)
local ArenaService = require(script.Parent.ArenaService)
local AudioService = require(script.Parent.AudioService)
local CombatService = require(script.Parent.CombatService)
local DevService = require(script.Parent.DevService)
local GameplayService = require(script.Parent.GameplayService)
local LootService = require(script.Parent.LootService)
local MatchState = require(script.Parent.MatchState)
local PlayerService = require(script.Parent.PlayerService)
local TransformScheduler = require(script.Parent.TransformScheduler)
local VoteService = require(script.Parent.VoteService)

local RoundService = {}

local activeDefs = {} -- modifier definitions applied to the current round
local activeCtx = nil -- the capability bag handed to those modifiers
local tickConnection = nil
local voteBuckets = {} -- rate limiting for vote remotes
local ranFirstMatch = false -- used for the "first match of the day" hook in Phase 5

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ---------------------------------------------------------------------------------------
-- Replication
-- ---------------------------------------------------------------------------------------

local function pointsPayload()
	local out = {}
	for player, points in MatchState.Points do
		out[tostring(player.UserId)] = points
	end
	return out
end

local function namePayload()
	local out = {}
	for _, player in Players:GetPlayers() do
		out[tostring(player.UserId)] = player.DisplayName
	end
	return out
end

local function snapshot()
	return {
		State = MatchState.State,
		Round = MatchState.Round,
		Total = MatchState.TotalRounds,
		Label = MatchState.Label,
		Format = MatchState.Format,
		Alive = #MatchState.alivePlayers(),
		PlayerCount = #Players:GetPlayers(),
		Points = pointsPayload(),
		Names = namePayload(),
		Modifiers = MatchState.ActiveModifiers,
		Flags = MatchState.Flags,
		ServerNow = now(),
	}
end

function RoundService.snapshotFor(_player: Player)
	return snapshot()
end

--! Publish a state change to every client and to interested server code.
local function publish(state: string, payload: { [string]: any }?)
	MatchState.State = state
	local base = snapshot()
	if payload then
		for key, value in payload do
			base[key] = value
		end
	end
	Net.broadcast(Net.Events.RoundState, base)
	MatchState.Signals.StateChanged:Fire(state, base)
	AnalyticsService.roundState(state)
end

-- ---------------------------------------------------------------------------------------
-- Waiting helpers
-- ---------------------------------------------------------------------------------------

local function waitForVotes(seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if VoteService.everyoneVoted() then
			return
		end
		task.wait(0.2)
	end
end

local function waitForRoundEnd(length: number)
	local deadline = os.clock() + length
	while os.clock() < deadline do
		if #MatchState.alivePlayers() <= Combat.MinAliveToContinue then
			local survivors = MatchState.alivePlayers()
			return { winner = survivors[1], reason = "elimination", elapsed = length - (deadline - os.clock()) }
		end
		task.wait(0.25)
	end

	-- Time ran out: the healthiest survivor takes it, which rewards the fight that happened
	-- rather than the fight that did not.
	local best, bestFraction = nil, -1
	for _, player in MatchState.alivePlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local fraction = humanoid.Health / math.max(humanoid.MaxHealth, 1)
			if fraction > bestFraction then
				best, bestFraction = player, fraction
			end
		end
	end
	return { winner = best, reason = "timeout", elapsed = length }
end

-- ---------------------------------------------------------------------------------------
-- Modifier orchestration
-- ---------------------------------------------------------------------------------------

local function buildCtx(roundNumber: number, appliedIds: { string }, rng: Random, length: number)
	local label = table.concat(appliedIds, "+")
	return {
		Round = {
			Number = roundNumber,
			Total = MatchState.TotalRounds,
			Format = MatchState.Format,
			Seed = MatchState.Seed,
			Label = MatchState.Label,
			Length = length,
			Flags = MatchState.Flags,
		},
		ModifierIds = appliedIds,
		Rng = rng,
		Arena = ArenaService,
		Gameplay = GameplayService,
		Loot = LootService,
		Players = PlayerService,
		Audio = AudioService,
		Log = function(fmt: string, ...)
			Log.debug("[" .. label .. "] " .. tostring(fmt), ...)
		end,
	}
end

local function defsFor(appliedIds: { string })
	local out = {}
	for _, id in appliedIds do
		local def = Modifiers.get(id)
		if def then
			table.insert(out, def)
		end
	end
	return out
end

--! Gamble is a pseudo-candidate: if it wins, the machine picks a real modifier in its place.
local function expandGamble(winners: { string }, rng: Random): { string }
	local applied = {}
	for _, id in winners do
		if id == Modifiers.GambleId then
			-- A Gamble draw is a single modifier, so modifiers that cannot stack are fair game
			-- here even in a round that applies three.
			local drawn = Modifiers.draw({
				Count = 1,
				MaxStacked = 1,
				Tiers = { 1, 2, 3 },
				Round = MatchState.Round,
				Features = MatchState.ArenaFeatures,
				Chosen = applied,
			}, rng)
			if drawn[1] then
				table.insert(applied, drawn[1].Id)
			end
		else
			table.insert(applied, id)
		end
	end
	return applied
end

--! Merge every active modifier's steps into ONE timeline. A hand-authored arena variant, if
--! the map team shipped one for this modifier, replaces that modifier's procedural geometry
--! steps (see docs/01-ARENA-CONTRACT.md).
local function runTransform(defs)
	local collected = {}
	local variantOf = {}

	for _, def in defs do
		if ArenaService.hasVariant(def.Id) then
			variantOf[def.Id] = true
			table.insert(collected, {
				ModifierId = def.Id,
				Step = {
					Channel = "arenaVariant",
					Phase = "Before",
					Priority = 100,
					Label = "variant:" .. def.Id,
					Run = function()
						ArenaService.ShowVariant(def.Id)
					end,
				},
			})
		end
	end

	for _, def in defs do
		if def.Steps then
			local ok, steps = pcall(def.Steps, activeCtx)
			if not ok then
				Log.warn("Steps failed for %s: %s", def.Id, tostring(steps))
			elseif type(steps) == "table" then
				for _, step in steps do
					local channel = step.Channel or "misc"
					local isGeometry = channel == "floorGeometry" or channel == "walls" or channel == "cover"
					if variantOf[def.Id] and isGeometry then
						Log.debug("Variant %s replaces procedural %s step", def.Id, channel)
					else
						table.insert(collected, { ModifierId = def.Id, Step = step })
					end
				end
			end
		end
	end

	return TransformScheduler.run(activeCtx, collected, Escalation.TransformCeiling)
end

local function runHook(hookName: string, ...)
	for _, def in activeDefs do
		local fn = (def :: any)[hookName]
		if fn then
			local ok, err = pcall(fn, activeCtx, ...)
			if not ok then
				Log.warn("%s.%s failed: %s", def.Id, hookName, tostring(err))
			end
		end
	end
end

local function startTicks()
	if tickConnection then
		return
	end
	tickConnection = RunService.Heartbeat:Connect(function(dt)
		if MatchState.State ~= "Live" or #activeDefs == 0 then
			return
		end
		for _, def in activeDefs do
			if def.Tick then
				local ok, err = pcall(def.Tick, activeCtx, dt)
				if not ok then
					Log.warn("%s.Tick failed: %s", def.Id, tostring(err))
					def.Tick = nil -- do not spam the log sixty times a second
				end
			end
		end
	end)
end

local function stopTicks()
	if tickConnection then
		tickConnection:Disconnect()
		tickConnection = nil
	end
end

--! Re-apply the round's rules to every character, including anyone who just joined.
function RoundService.applyToPlayer(player: Player)
	if not MatchState.Active or not player.Character then
		return
	end
	GameplayService.applyBaseline(player)
	runHook("OnCharacterSpawn", player)
end

local function applyToEveryone()
	for _, player in Players:GetPlayers() do
		RoundService.applyToPlayer(player)
	end
end

-- ---------------------------------------------------------------------------------------
-- The round
-- ---------------------------------------------------------------------------------------

local function runRound(roundNumber: number, rng: Random)
	local cfg = Escalation.forRound(MatchState.Format, roundNumber)
	MatchState.Round = roundNumber
	MatchState.Label = cfg.Label

	local roundSeconds = DevService.get("RoundSeconds", cfg.Length)
	local voteSeconds = DevService.get("VoteSeconds", Escalation.voteSeconds(MatchState.Format))

	-- Reset the world out of the previous round's shape. Order matters: geometry first, then
	-- gameplay rules, then anything that lives in the world (crates), then the players.
	ArenaService.reset()
	GameplayService.reset()
	LootService.reset()
	CombatService.resetRound()
	PlayerService.resetRound()
	VoteService.reset()
	activeDefs = {}
	activeCtx = nil

	-- Everyone stands in the plain arena to watch the vote and the transformation.
	PlayerService.despawnAll()
	PlayerService.respawnAll()

	publish("VoteOpen", { EndsAt = now() + voteSeconds })

	local forced = DevService.forcedModifiers()
	local skipVote = DevService.get("SkipVote", false) == true and forced ~= nil

	if not skipVote then
		VoteService.open({
			Round = roundNumber,
			Count = cfg.Cands,
			Tiers = cfg.Tiers,
			GuaranteeTier = cfg.GuaranteeTier,
			MaxStacked = cfg.MaxStacked,
			Gamble = cfg.Gamble,
			Features = MatchState.ArenaFeatures,
			Seconds = voteSeconds,
			Rng = rng,
		})

		waitForVotes(voteSeconds)
		VoteService.lock()
		publish("VoteLock", {})
		task.wait(Escalation.LockSeconds)
	end

	-- Resolve, with sudden-death revotes on a genuine tie.
	local result
	local appliedIds
	local winnerNames = {}

	if forced then
		appliedIds = forced
		result = { ranking = {}, voteMap = {}, voted = 0, defaulted = true }
	else
		result = VoteService.resolve(cfg.MaxStacked, rng, true)
		local tieRounds = 0
		while result.tieBreak and tieRounds < 2 do
			tieRounds += 1
			publish("TieBreak", { Tied = result.tieBreak, EndsAt = now() + Escalation.TieBreakSeconds })
			VoteService.open({
				Round = roundNumber,
				TieBreak = result.tieBreak,
				MaxStacked = cfg.MaxStacked,
				Seconds = Escalation.TieBreakSeconds,
				Rng = rng,
			})
			waitForVotes(Escalation.TieBreakSeconds)
			VoteService.lock()
			publish("VoteLock", {})
			task.wait(1)
			result = VoteService.resolve(cfg.MaxStacked, rng, true)
		end
		if result.tieBreak then
			-- Two revotes could not separate them. Flip the coin in front of everyone.
			result = VoteService.resolve(cfg.MaxStacked, rng, false)
		end

		appliedIds = expandGamble(result.winners, rng)
		for _, id in appliedIds do
			local def = Modifiers.get(id)
			table.insert(winnerNames, def and def.DisplayName or id)
		end
	end

	if #appliedIds == 0 then
		-- Nothing could be applied (an empty registry or a forced id that does not exist).
		Log.warn("Round %d resolved no modifiers; running a plain round", roundNumber)
	end

	MatchState.ActiveModifiers = appliedIds

	publish("Reveal", {
		Winners = appliedIds,
		WinnerNames = winnerNames,
		Ranking = result.ranking,
		Defaulted = result.defaulted == true,
		Voted = result.voted or 0,
	})

	-- Vote accuracy is the long-term hook of the vote itself.
	for player in result.voteMap do
		if player.Parent then
			AnalyticsService.voteResult(player, VoteService.wasCorrect(player, appliedIds))
		end
	end

	task.wait(Escalation.RevealSeconds)

	-- ---------------------------------------------------------------------------------
	-- THE TRANSFORM
	-- ---------------------------------------------------------------------------------
	PlayerService.freezeAll(true)
	activeDefs = defsFor(appliedIds)
	activeCtx = buildCtx(roundNumber, appliedIds, rng, roundSeconds)

	publish("Transform", { EndsAt = now() + Escalation.TransformCeiling, Modifiers = appliedIds })
	Net.broadcast(Net.Events.TransformFx, {
		ModifierIds = appliedIds,
		WinnerNames = winnerNames,
		Duration = Escalation.TransformCeiling,
		Round = roundNumber,
		Total = MatchState.TotalRounds,
		Cinematic = cfg.Cinematic == true,
	})
	AudioService.PlayCue("Rumble")

	runHook("Prepare")
	local report = runTransform(activeDefs)

	-- The map team authors a modifier's atmosphere as tagged emitters; the engine only
	-- switches them on. See ArenaService.SetEmitters.
	local activeSet = {}
	for _, id in appliedIds do
		activeSet[id] = true
	end
	ArenaService.SetEmitters(activeSet)

	runHook("OnRoundStart")

	ArenaService.SetNameplate(table.concat(winnerNames, "  +  "))
	PlayerService.freezeAll(false)
	applyToEveryone()

	if #report.failures > 0 then
		Log.warn("Transform finished with %d failed step(s) in round %d", #report.failures, roundNumber)
	end

	publish("Countdown", { EndsAt = now() + Escalation.CountdownSeconds, Modifiers = appliedIds })
	AudioService.PlayCue("Gavel")
	task.wait(Escalation.CountdownSeconds)

	-- ---------------------------------------------------------------------------------
	-- THE ROUND
	-- ---------------------------------------------------------------------------------
	publish("Live", { EndsAt = now() + roundSeconds, Modifiers = appliedIds })
	LootService.SpawnAll(rng)
	startTicks()

	local endInfo = waitForRoundEnd(roundSeconds)
	stopTicks()

	-- Freeze the world for the results screen: no more damage, no more ticks.
	MatchState.State = "RoundEnd"
	runHook("OnRoundEnd")

	local winner: Player? = endInfo.winner
	if winner and winner.Parent then
		MatchState.Points[winner] = (MatchState.Points[winner] or 0) + Combat.RoundWinPoints
		local stats = MatchState.Stats[winner]
		if stats then
			stats.RoundWins += 1
		end
	end

	publish("RoundEnd", {
		RoundWinner = winner and winner.DisplayName or nil,
		RoundWinnerId = winner and winner.UserId or nil,
		Reason = endInfo.reason,
		Modifiers = appliedIds,
	})

	local ranked = MatchState.rankedPlayers()
	Net.broadcast(Net.Events.RoundResult, {
		Round = roundNumber,
		Total = MatchState.TotalRounds,
		Winner = winner and winner.DisplayName or "NOBODY",
		WinnerId = winner and winner.UserId or nil,
		Reason = endInfo.reason,
		Modifiers = appliedIds,
		WinnerNames = winnerNames,
		Points = pointsPayload(),
		Names = namePayload(),
		Eliminated = (function()
			local count = 0
			for _, player in Players:GetPlayers() do
				if MatchState.Eliminated[player] then
					count += 1
				end
			end
			return count
		end)(),
		Ranking = (function()
			local out = {}
			for index, player in ranked do
				table.insert(out, { UserId = player.UserId, Points = MatchState.Points[player] or 0, Rank = index })
			end
			return out
		end)(),
	})

	AnalyticsService.roundModifiers(roundNumber, appliedIds, endInfo.elapsed)
	for _, player in Players:GetPlayers() do
		AnalyticsService.roundCompleted(player, player == winner, MatchState.Points[player] or 0)
	end

	task.wait(Escalation.RoundEndSeconds)

	runHook("Revert")
	activeDefs = {}
	activeCtx = nil
	MatchState.State = "Idle"
end

-- ---------------------------------------------------------------------------------------
-- The match
-- ---------------------------------------------------------------------------------------

local function endMatch()
	local ranked = MatchState.rankedPlayers()
	local winner = ranked[1]

	Net.broadcast(Net.Events.MatchResult, {
		Winner = winner and winner.DisplayName or "NOBODY",
		WinnerId = winner and winner.UserId or nil,
		Standings = (function()
			local out = {}
			for index, player in ranked do
				local stats = MatchState.Stats[player] or { Kills = 0, Deaths = 0, RoundWins = 0 }
				table.insert(out, {
					UserId = player.UserId,
					Points = MatchState.Points[player] or 0,
					Rank = index,
					Kills = stats.Kills,
					Deaths = stats.Deaths,
					RoundWins = stats.RoundWins,
				})
			end
			return out
		end)(),
	})

	publish("MatchEnd", { Winner = winner and winner.DisplayName or nil })

	for index, player in ranked do
		AnalyticsService.matchCompleted(player, index, MatchState.Points[player] or 0)
	end

	ranFirstMatch = true
end

local function runMatch()
	MatchState.resetMatch()
	MatchState.Active = true

	local playerCount = #Players:GetPlayers()
	local formatId = Escalation.formatForPlayerCount(playerCount)
	MatchState.Format = formatId
	MatchState.TotalRounds = DevService.get("TotalRounds", Escalation.totalRounds(formatId))
	MatchState.Seed = SeededRandom.matchSeed()

	local rng = SeededRandom.new(MatchState.Seed)
	local format = Escalation.Formats[formatId]
	MatchState.Label = format.DisplayName

	local forcedArenaId = DevService.get("ArenaId", nil)
	local arena = forcedArenaId and ArenaService.get(forcedArenaId) or ArenaService.pick(rng, playerCount)
	if not arena then
		Log.error("No arena found in ServerStorage.Arenas. Run the arena builder, then restart.")
		MatchState.Active = false
		return
	end

	ArenaService.load(arena)
	MatchState.setArena(arena)
	Log.info("Match start: format=%s rounds=%d seed=%d arena=%s", formatId, MatchState.TotalRounds, MatchState.Seed, arena.Name)

	local startingRound = DevService.get("StartingRound", 1)
	for roundNumber = startingRound, MatchState.TotalRounds do
		if #Players:GetPlayers() == 0 then
			break
		end
		local ok, err = pcall(runRound, roundNumber, rng)
		if not ok then
			Log.warn("Round %d aborted: %s", roundNumber, tostring(err))
		end
	end

	endMatch()

	MatchState.Active = false
	PlayerService.despawnAll()
	ArenaService.unload()
end

-- ---------------------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	MatchState.ensurePlayer(player)
	AnalyticsService.event(player, "Joined")

	Net.trySend(player, Net.Events.RoundState, snapshot())
	if VoteService.isOpen() then
		Net.trySend(player, Net.Events.VoteState, VoteService.payloadFor(player))
	end

	-- Join in progress: a player arriving mid-round is dropped straight into the fight,
	-- because making someone wait a full round is how you lose them in the first 60 seconds.
	if MatchState.Active and MatchState.State ~= "Idle" and MatchState.State ~= "MatchEnd" then
		task.spawn(function()
			task.wait(0.5) -- let the character exist before we move it
			if PlayerService.spawn(player) then
				RoundService.applyToPlayer(player)
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	MatchState.forgetPlayer(player)
	CombatService.forgetPlayer(player)
	voteBuckets[player] = nil
end

function RoundService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Net.event(Net.Events.VoteCast).OnServerEvent:Connect(function(player, modifierId)
		if not Net.rateLimit(voteBuckets, player, 0.15) then
			return
		end
		local ok, accepted = pcall(VoteService.cast, player, modifierId)
		if ok and accepted then
			AnalyticsService.voteCast(player, tostring(modifierId))
		end
	end)

	Net.event(Net.Events.Objection).OnServerEvent:Connect(function(player)
		if not Net.rateLimit(voteBuckets, player, 0.5) then
			return
		end
		pcall(VoteService.objection, player)
	end)

	Net.func(Net.Events.RoundInfo).OnServerInvoke = function(player)
		return snapshot()
	end

	task.spawn(function()
		while true do
			if #Players:GetPlayers() == 0 then
				task.wait(1)
			else
				local ok, err = pcall(runMatch)
				if not ok then
					Log.error("Match loop failed: %s", tostring(err))
					task.wait(5)
				end
				task.wait(Escalation.MatchEndSeconds)
			end
		end
	end)
end

function RoundService.activeModifiers(): { string }
	return MatchState.ActiveModifiers
end

function RoundService.firstMatchRan(): boolean
	return ranFirstMatch
end

return RoundService
