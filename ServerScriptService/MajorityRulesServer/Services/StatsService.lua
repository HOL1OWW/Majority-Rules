--!nonstrict
--[[
	StatsService — the leaderboard system.

	Three layers, one owner:

	1. leaderstats — the Roblox player-list. Kills / Points / Streak update live during a
	   match, so the engine's own player list is already a scoreboard.
	2. live boards — Net.Events.ScoreboardLive broadcasts carry full standings every few
	   seconds while a match runs; the client's Tab board and match podium render from them.
	3. career stats — DataStore-backed lifetime Kills / Rounds / RoundWins / MatchWins,
	   saved at match end and on leave. Studio has no DataStores, so persistence silently
	   no-ops there (careerStore stays nil).

	Bots appear on the board without any BotService knowledge: CombatService.creditKill
	already keys bot kills into MatchState.Points by their character Model, so any Points
	entry keyed by an Instance is a combatant with no Player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)

local MatchState = require(script.Parent.MatchState)

local StatsService = {}

local BOARD_INTERVAL = 3 -- seconds between live board broadcasts during a match
local STREAK_SECONDS = 12 -- window in which the next kill extends the streak

--! In Studio, or when game API access is off, this stays nil and every Store call no-ops.
local careerStore
do
	local ok, result = pcall(function()
		return game:GetService("DataStoreService"):GetDataStore("MRCareerStats_v1")
	end)
	if ok then
		careerStore = result
	end
end

local sessions = {} -- [Player] = { Streak, LastKillAt, Career }
local boardThread: thread? = nil

-- ---------------------------------------------------------------------------------------
-- Career stats (layer 3)
-- ---------------------------------------------------------------------------------------

local function emptyCareer()
	return { Kills = 0, Deaths = 0, Rounds = 0, RoundWins = 0, Matches = 0, MatchWins = 0 }
end

local function loadCareer(player: Player)
	if not careerStore then
		return emptyCareer()
	end
	local key = "p_" .. tostring(player.UserId)
	local ok, data = pcall(function()
		return careerStore:GetAsync(key)
	end)
	if not ok then
		Log.warn("StatsService: career load failed for %s (will save-on-leave only)", player.Name)
		return emptyCareer()
	end
	if type(data) ~= "table" then
		return emptyCareer()
	end
	local career = emptyCareer()
	for field, value in pairs(data) do
		if type(value) == "number" then
			career[field] = value
		end
	end
	return career
end

local function saveCareer(player: Player)
	local session = sessions[player]
	if not careerStore or not session or not session.Career then
		return
	end
	local ok, err = pcall(function()
		return careerStore:SetAsync("p_" .. tostring(player.UserId), session.Career)
	end)
	if not ok then
		Log.warn("StatsService: career save failed for %s: %s", player.Name, tostring(err))
	end
end

--! Commit the finished match into each present player's career, then persist.
local function onMatchEnded(payload)
	for _, player in Players:GetPlayers() do
		local session = sessions[player]
		if session and session.Career then
			local stats = MatchState.Stats[player]
			session.Career.Rounds += 1
			if stats then
				session.Career.Kills += stats.Kills
				session.Career.Deaths += stats.Deaths
				session.Career.RoundWins += stats.RoundWins
			end
			session.Career.Matches += 1
			for _, row in (payload and payload.Standings) or {} do
				if row.UserId == player.UserId and row.Rank == 1 then
					session.Career.MatchWins += 1
					break
				end
			end
			saveCareer(player)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- leaderstats (layer 1)
-- ---------------------------------------------------------------------------------------

local function ensureLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return player.leaderstats
	end
	local board = Instance.new("Folder")
	board.Name = "leaderstats"
	for _, statName in { "Kills", "Points", "Streak" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Value = 0
		value.Parent = board
	end
	board.Parent = player
	return board
end

local function refreshLeaderstats(player: Player)
	local board = player:FindFirstChild("leaderstats")
	if not board then
		return
	end
	local stats = MatchState.Stats[player]
	local session = sessions[player]
	board.Kills.Value = stats and stats.Kills or 0
	board.Points.Value = MatchState.Points[player] or 0
	board.Streak.Value = session and session.Streak or 0
end

-- ---------------------------------------------------------------------------------------
-- Payload builders (layer 2)
-- ---------------------------------------------------------------------------------------

local function buildStandings()
	local rows = {}
	for _, player in Players:GetPlayers() do
		local stats = MatchState.Stats[player]
		local session = sessions[player]
		table.insert(rows, {
			Name = player.DisplayName,
			UserId = player.UserId,
			Points = MatchState.Points[player] or 0,
			Kills = stats and stats.Kills or 0,
			Deaths = stats and stats.Deaths or 0,
			RoundWins = stats and stats.RoundWins or 0,
			Streak = session and session.Streak or 0,
			IsBot = false,
			IsLocal = false, -- client fills this in
		})
	end
	--! Any Points entry keyed by an Instance (not a Player) is a bot character that earned
	--! kills through CombatService.creditKill. This is the whole bot-integration surface.
	for killer, points in MatchState.Points do
		if typeof(killer) == "Instance" and killer:IsA("Model") then
			table.insert(rows, {
				Name = "[BOT] " .. killer.Name,
				Points = points,
				Kills = math.floor(points / 1), -- bots earn 1 point per kill
				Deaths = 0,
				RoundWins = 0,
				Streak = 0,
				IsBot = true,
				IsLocal = false,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		return a.Name < b.Name
	end)
	for index, row in rows do
		row.Rank = index
	end
	return rows
end

local function buildBoardPayload()
	return {
		Active = MatchState.Active,
		Round = MatchState.Round,
		Total = MatchState.TotalRounds,
		Standings = buildStandings(),
		ServerNow = os.clock(),
	}
end

-- ---------------------------------------------------------------------------------------
-- The board loop
-- ---------------------------------------------------------------------------------------

local function boardLoop()
	while true do
		if MatchState.Active then
			for _, player in Players:GetPlayers() do
				refreshLeaderstats(player)
			end
			Net.broadcast(Net.Events.ScoreboardLive, buildBoardPayload())
		end
		task.wait(BOARD_INTERVAL)
	end
end

-- ---------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------

local function onPlayerRemoving(player: Player)
	saveCareer(player)
	sessions[player] = nil
end

local function onPlayerDied(player: Player, killer)
	--! The kill feed is broadcast by CombatService (Net.Events.KillFeed) so bot kills and
	--! bot victims get the same theatre; this handler only owns player streaks.
	if killer and killer:IsA("Player") then
		local session = sessions[killer]
		if session then
			if os.clock() - (session.LastKillAt or 0) <= STREAK_SECONDS then
				session.Streak += 1
			else
				session.Streak = 1
			end
			session.LastKillAt = os.clock()
			if session.Streak >= 3 then
				Net.trySend(killer, Net.Events.Notify, {
					Text = string.format("%s KILL STREAK", session.Streak),
					Kind = "kill",
				})
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------------------

--! Called when PlayerService admits a player (per match join). Builds leaderstats and
--! starts the async career load; the session exists immediately, career fills in later.
function StatsService.onPlayerEnsured(player: Player)
	if not sessions[player] then
		sessions[player] = { Streak = 0, LastKillAt = 0, Career = emptyCareer() }
		ensureLeaderstats(player)
		task.spawn(function()
			local career = loadCareer(player)
			local session = sessions[player]
			if session and player.Parent then
				session.Career = career
			end
		end)
	end
end

function StatsService.start()
	MatchState.Signals.PlayerDied:Connect(onPlayerDied)
	MatchState.Signals.MatchEnded:Connect(onMatchEnded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	boardThread = task.spawn(boardLoop)
	Log.info("StatsService: leaderboard live (career store %s)", careerStore and "connected" or "OFF")
end

return StatsService
