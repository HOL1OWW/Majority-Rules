--!nonstrict
--[[
	Hud — everything the player needs while they are actually playing.

	Deliberately quiet: a round label, a clock, the scoreboard, and one loud thing when you have
	been eliminated, because "you can still vote" is the rule players most need to be told.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Hud = {}

local state
local screenGui
local roundLabel
local clockLabel
local aliveLabel
local scoreboard
local scoreRows = {}
local eliminatedPanel
local toastHolder
local toasts = {}

local TIMED_STATES = {
	VoteOpen = true,
	VoteLock = true,
	TieBreak = true,
	Reveal = true,
	Transform = true,
	Countdown = true,
	Live = true,
	RoundEnd = true,
}

function Hud.init(options)
	state = options.state

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MRHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui

	-- round label, top left
	roundLabel = Theme.label({
		Position = UDim2.new(0, 16, 0, 12),
		Size = UDim2.new(0, 300, 0, 22),
		Text = "MAJORITY RULES",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Accent,
	}, screenGui)

	-- clock, top centre
	clockLabel = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 200, 0, 30),
		Text = "",
		TextSize = 24,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Paper,
	}, screenGui)

	aliveLabel = Theme.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(0, 260, 0, 18),
		Text = "",
		TextSize = 13,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Mute,
	}, screenGui)

	-- scoreboard, top right
	local board = Theme.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.new(0, 210, 0, 26),
		BackgroundColor3 = Theme.Color.Graphite,
		BackgroundTransparency = 0.25,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, screenGui)
	Theme.corner(8, board)
	Theme.padding(8, board)
	scoreboard = board

	local layout = Theme.listLayout(board, Enum.FillDirection.Vertical, 3)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- elimination notice, centre
	eliminatedPanel = Theme.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.34, 0),
		Size = UDim2.new(0, 420, 0, 74),
		BackgroundColor3 = Theme.Color.Graphite,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, screenGui)
	Theme.corner(10, eliminatedPanel)
	Theme.stroke(Theme.Color.Combat, 3, eliminatedPanel)

	Theme.label({
		Position = UDim2.new(0, 0, 0, 10),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "ELIMINATED",
		TextSize = 26,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Combat,
	}, eliminatedPanel)

	Theme.label({
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "You still get a vote. Try to ruin it for everyone.",
		TextSize = 13,
		Font = Theme.Font.Body,
		TextColor3 = Theme.Color.PaperDim,
	}, eliminatedPanel)

	-- toasts, bottom left
	toastHolder = Theme.frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -266),
		Size = UDim2.new(0, 280, 0, 200),
		BackgroundTransparency = 1,
	}, screenGui)
	local toastLayout = Theme.listLayout(toastHolder, Enum.FillDirection.Vertical, 6)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	state.Signals.Round:Connect(Hud.render)
	state.Signals.Notify:Connect(Hud.toast)

	task.spawn(function()
		while true do
			Hud.updateClock()
			task.wait(0.1)
		end
	end)

	return Hud
end

function Hud.updateClock()
	if not TIMED_STATES[state.round.State] then
		clockLabel.Text = ""
		return
	end
	local remaining = state.secondsRemaining()
	clockLabel.Text = Theme.formatClock(remaining)
	clockLabel.TextColor3 = remaining <= 5 and Theme.Color.Combat or Theme.Color.Paper
end

function Hud.render()
	local round = state.round

	local label = round.Label or "MAJORITY RULES"
	roundLabel.Text = (round.Total and round.Total > 0)
			and string.format("%s  ·  ROUND %d/%d", label, round.Round or 0, round.Total)
		or label

	if round.State == "Live" then
		aliveLabel.Text = string.format("%d ALIVE  ·  %d PLAYERS", round.Alive or 0, round.PlayerCount or 0)
	elseif round.State == "VoteOpen" or round.State == "VoteLock" or round.State == "TieBreak" then
		aliveLabel.Text = "CAST YOUR VOTE"
	elseif round.State == "Transform" then
		aliveLabel.Text = "THE ARENA IS CHANGING"
	else
		aliveLabel.Text = ""
	end

	-- scoreboard
	local standings = state.standings()
	local localPlayer = Players.LocalPlayer
	for index, row in standings do
		local entry = scoreRows[index]
		if not entry then
			entry = Theme.frame({
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				LayoutOrder = index,
			}, scoreboard)
			entry.name = Theme.label({
				Size = UDim2.new(1, -50, 1, 0),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font.Heading,
			}, entry)
			entry.points = Theme.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0, 44, 1, 0),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				Font = Theme.Font.Mono,
			}, entry)
			scoreRows[index] = entry
		end
		entry.Visible = true
		entry.LayoutOrder = index
		entry.name.Text = string.format("%d. %s", index, row.Name)
		entry.points.Text = Theme.formatPoints(row.Points)
		entry.name.TextColor3 = row.IsLocal and Theme.Color.Accent or Theme.Color.PaperDim
		entry.points.TextColor3 = row.IsLocal and Theme.Color.Accent or Theme.Color.PaperDim
	end
	for index = #standings + 1, #scoreRows do
		scoreRows[index].Visible = false
	end

	-- elimination notice
	local myName = localPlayer and tostring(localPlayer.UserId)
	local myPoints = round.Points and round.Points[myName]
	local eliminated = round.State == "Live" and localPlayer and not localPlayer.Character
	if eliminated and myPoints then
		eliminatedPanel.Visible = true
	else
		eliminatedPanel.Visible = false
	end
end

function Hud.toast(payload)
	if type(payload) ~= "table" or not payload.Text then
		return
	end

	local toast = Theme.frame({
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = payload.Kind == "kill" and Theme.Color.Combat or Theme.Color.GraphiteSoft,
		BackgroundTransparency = 0.15,
	}, toastHolder)
	Theme.corner(6, toast)

	Theme.label({
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = payload.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Paper,
	}, toast)

	table.insert(toasts, toast)
	if #toasts > 5 then
		local oldest = table.remove(toasts, 1)
		oldest:Destroy()
	end

	task.delay(3, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			fade:Play()
			task.wait(0.35)
			toast:Destroy()
		end
	end)
end

return Hud
