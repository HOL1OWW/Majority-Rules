--!nonstrict
--[[
	Scoreboard — the full live board on hold-Tab and the end-of-match podium.

	Data in:
	  * Net.Events.ScoreboardLive broadcasts from StatsService while a match runs.
	  * State.matchResult (Net.Events.MatchResult) for the podium, so the podium works
	    even when the client booted mid-match and never saw a live broadcast.

	Leaderstats remain the always-visible small board; this is the one you call up.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Scoreboard = {}

local state
local boardGui -- hold-Tab board
local podiumGui -- match end
local rows = {}
local feedLabels = {}
local podiumRows = {}
local localFeed = {} -- client-side kill-feed buffer, newest last

local HEADER_HEIGHT = 30
local ROW_HEIGHT = 22

local function pushFeed(text: string)
	table.insert(localFeed, text)
	while #localFeed > 5 do
		table.remove(localFeed, 1)
	end
end

local function renderFeed()
	for index = 1, #localFeed do
		local label = feedLabels[index]
		if not label and boardGui then
			label = Theme.label({
				Size = UDim2.new(1, 0, 0, 18),
				Text = "",
				TextSize = 13,
				Font = Theme.Font.Mono,
				TextColor3 = Theme.Color.PaperDim,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, boardGui.Feed)
			feedLabels[index] = label
		end
		if label then
			label.Visible = true
			label.Text = localFeed[index]
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Hold-Tab board
-- ---------------------------------------------------------------------------------------

local function buildBoard(playerGui: Instance)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MRScoreboard"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 40
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local frame = Theme.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 560, 0, 380),
		BackgroundColor3 = Theme.Color.Graphite,
		BackgroundTransparency = 0.08,
	}, screenGui)
	Theme.corner(12, frame)
	Theme.stroke(Theme.Color.GraphiteLine, 2, frame)
	Theme.padding(14, frame)

	local title = Theme.label({
		Size = UDim2.new(1, 0, 0, 28),
		Text = "  THE VOTE  \u{00B7}  STANDINGS",
		TextSize = 20,
		Font = Theme.Font.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Color.Accent,
	}, frame)

	local roundLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 200, 0, 28),
		Text = "",
		TextSize = 14,
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.PaperDim,
	}, frame)

	-- column header
	local header = Theme.frame({
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
	}, frame)
	-- Header cells mirror the row layout below exactly: rank right-aligned at 34, name at 40,
	-- then K / D / PTS anchored from the right edge so numbers stay columnar at any width.
	Theme.label({
		Size = UDim2.new(0, 34, 1, 0),
		Text = "#",
		TextSize = 12,
		Font = Theme.Font.Mono,
		TextColor3 = Theme.Color.GraphiteLine,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, header)
	Theme.label({
		Position = UDim2.new(0, 40, 0, 0),
		Size = UDim2.new(1, -40 - 66 - 56 - 56, 1, 0),
		Text = "PLAYER",
		TextSize = 12,
		Font = Theme.Font.Mono,
		TextColor3 = Theme.Color.GraphiteLine,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -66 - 56, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
		Text = "K",
		TextSize = 12,
		Font = Theme.Font.Mono,
		TextColor3 = Theme.Color.GraphiteLine,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, header)
	Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -66, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
		Text = "D",
		TextSize = 12,
		Font = Theme.Font.Mono,
		TextColor3 = Theme.Color.GraphiteLine,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, header)
	Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 66, 1, 0),
		Text = "PTS",
		TextSize = 12,
		Font = Theme.Font.Mono,
		TextColor3 = Theme.Color.GraphiteLine,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, header)

	-- rows
	local listHolder = Theme.frame({
		Position = UDim2.new(0, 0, 0, 32 + HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -(32 + HEADER_HEIGHT + 110)),
		BackgroundTransparency = 1,
	}, frame)
	Theme.listLayout(listHolder, Enum.FillDirection.Vertical, 2)

	-- kill feed
	local feed = Theme.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundTransparency = 1,
	}, frame)
	Theme.listLayout(feed, Enum.FillDirection.Vertical, 1)

	return {
		ScreenGui = screenGui,
		Frame = frame,
		Round = roundLabel,
		List = listHolder,
		Feed = feed,
	}
end

local function getRow(index: number)
	if rows[index] then
		return rows[index]
	end
	local frame = Theme.frame({
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
	}, boardGui.List)
	local rank = Theme.label({
		Size = UDim2.new(0, 34, 1, 0),
		Text = "",
		TextSize = 13,
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.PaperDim,
	}, frame)
	local name = Theme.label({
		Position = UDim2.new(0, 40, 0, 0),
		Size = UDim2.new(1, -40 - 66 - 56 - 56, 1, 0),
		Text = "",
		TextSize = 14,
		Font = Theme.Font.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Color.Paper,
	}, frame)
	local kills = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -66 - 56, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
		Text = "",
		TextSize = 14,
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.PaperDim,
	}, frame)
	local deaths = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -66, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
		Text = "",
		TextSize = 14,
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.PaperDim,
	}, frame)
	local points = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 66, 1, 0),
		Text = "",
		TextSize = 14,
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.Paper,
	}, frame)
	local stroke = Theme.stroke(Theme.Color.Accent, 1, frame)
	stroke.Transparency = 1

	rows[index] = { Frame = frame, Rank = rank, Name = name, Kills = kills, Deaths = deaths, Points = points, Stroke = stroke }
	return rows[index]
end

local function renderStandings(standings)
	local localPlayer = Players.LocalPlayer
	local count = 0
	for _, row in standings or {} do
		count += 1
		local entry = getRow(count)
		entry.Frame.Visible = true
		entry.Rank.Text = tostring(row.Rank or count)
		entry.Name.Text = row.IsLocal and (row.Name .. "  (you)") or row.Name
		entry.Kills.Text = tostring(row.Kills or 0)
		entry.Deaths.Text = tostring(row.Deaths or 0)
		entry.Points.Text = Theme.formatPoints(row.Points)
		local isLocal = localPlayer and row.UserId == localPlayer.UserId
		local accent = isLocal and Theme.Color.Accent or (row.IsBot and Theme.Color.GraphiteLine or Theme.Color.Paper)
		entry.Name.TextColor3 = accent
		entry.Points.TextColor3 = accent
		entry.Stroke.Transparency = isLocal and 0.4 or 1
	end
	for index = count + 1, #rows do
		rows[index].Frame.Visible = false
	end
end

local function renderLive(payload)
	if not boardGui then
		return
	end
	boardGui.Round.Text = payload.Round and payload.Total
		and string.format("ROUND %d / %d", payload.Round, payload.Total)
		or "STANDINGS"
	renderStandings(payload.Standings)
end

-- ---------------------------------------------------------------------------------------
-- Podium
-- ---------------------------------------------------------------------------------------

local function buildPodium(playerGui: Instance)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MRPodium"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 50
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local frame = Theme.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 520, 0, 420),
		BackgroundColor3 = Theme.Color.Graphite,
		BackgroundTransparency = 0.06,
	}, screenGui)
	Theme.corner(14, frame)
	Theme.stroke(Theme.Color.Accent, 2, frame)
	Theme.padding(18, frame)

	local title = Theme.label({
		Size = UDim2.new(1, 0, 0, 46),
		Text = "MATCH OVER",
		TextSize = 30,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Accent,
	}, frame)

	local winner = Theme.label({
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		TextSize = 24,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Paper,
	}, frame)

	local list = Theme.frame({
		Position = UDim2.new(0, 0, 0, 100),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
	}, frame)
	Theme.listLayout(list, Enum.FillDirection.Vertical, 4)

	return { ScreenGui = screenGui, Winner = winner, List = list }
end

local function getPodiumRow(index: number)
	if podiumRows[index] then
		return podiumRows[index]
	end
	local frame = Theme.frame({
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, podiumGui.List)
	local rank = Theme.label({
		Size = UDim2.new(0, 44, 1, 0),
		Text = "",
		TextSize = 18,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.PaperDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	local name = Theme.label({
		Position = UDim2.new(0, 48, 0, 0),
		Size = UDim2.new(1, -48 - 90, 1, 0),
		Text = "",
		TextSize = 16,
		Font = Theme.Font.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Color.Paper,
	}, frame)
	local line = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 90, 1, 0),
		Text = "",
		TextSize = 13,
		Font = Theme.Font.Mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Color.PaperDim,
	}, frame)
	podiumRows[index] = { Frame = frame, Rank = rank, Name = name, Line = line }
	return podiumRows[index]
end

--! MatchResult standings carry UserId but no display name (RoundService builds them from
--! rankedPlayers), so the podium resolves names itself and never concatenates nil.
local function displayNameFor(row)
	if type(row.Name) == "string" then
		return row.Name
	end
	local player = Players:GetPlayerByUserId(row.UserId)
	if player then
		return player.DisplayName
	end
	return "Player " .. tostring(row.UserId)
end

local function renderPodium(payload)
	if not podiumGui then
		return
	end
	local standings = payload.Standings or {}
	podiumGui.Winner.Text = standings[1]
		and (displayNameFor(standings[1]) .. " TAKES THE MATCH")
		or "NOBODY TAKES THE MATCH"
	for index = 1, math.min(#standings, 8) do
		local row = standings[index]
		local entry = getPodiumRow(index)
		entry.Frame.Visible = true
		local medal = ({ "\u{1F947} ", "\u{1F948} ", "\u{1F949} " })[index] or (tostring(index) .. ".")
		entry.Rank.Text = medal
		entry.Name.Text = displayNameFor(row) .. (row.UserId == Players.LocalPlayer.UserId and "  (you)" or "")
		entry.Line.Text = string.format("%dK  %dD  %d pts", row.Kills or 0, row.Deaths or 0, row.Points or 0)
		entry.Name.TextColor3 = index == 1 and Theme.Color.Accent or Theme.Color.Paper
	end
	for index = math.min(#standings, 8) + 1, #podiumRows do
		podiumRows[index].Frame.Visible = false
	end
end

-- ---------------------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------------------

local fading = false

function Scoreboard.init(options)
	state = options.state

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	boardGui = buildBoard(playerGui)
	podiumGui = buildPodium(playerGui)

	-- Hold-Tab shows the board; release hides it. Opening re-renders the feed so a kill
	-- while the board was hidden still appears.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab then
			renderFeed()
			boardGui.ScreenGui.Enabled = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab then
			boardGui.ScreenGui.Enabled = false
		end
	end)

	-- The live broadcast is the single source; anything cached just re-renders it.
	state.Signals.Round:Connect(function()
		-- RoundState payloads also refresh the podium's dismissal implicitly; live board
		-- data arrives on ScoreboardLive.
	end)

	fading = false
end

--! The Bootstrap wires Net.event(Net.Events.ScoreboardLive).OnClientEvent to this.
function Scoreboard.onLive(payload)
	renderLive(payload)
end

--! The Bootstrap wires Net.event(Net.Events.KillFeed).OnClientEvent to this.
function Scoreboard.onKillFeed(payload)
	pushFeed(">	" .. payload.KillerName .. "  \u{2192}  " .. payload.VictimName)
	if boardGui and boardGui.ScreenGui.Enabled then
		renderFeed()
	end
end

--! The Bootstrap wires State.Signals.MatchResult to this.
function Scoreboard.onMatchResult(payload)
	if not podiumGui then
		return
	end
	renderPodium(payload)
	podiumGui.ScreenGui.Enabled = true
	podiumGui.Frame.Position = UDim2.new(0.5, 0, 0.58, 0)
	TweenService:Create(podiumGui.Frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

--! The Bootstrap wires State.Signals.Round to this: the podium closes when the next
--! round's vote opens (anything but MatchEnd).
function Scoreboard.onRoundState(payload)
	if podiumGui and payload.State and payload.State ~= "MatchEnd" then
		podiumGui.ScreenGui.Enabled = false
	end
end

return Scoreboard
