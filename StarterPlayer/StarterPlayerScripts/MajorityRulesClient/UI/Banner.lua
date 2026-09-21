--!nonstrict
--[[
	Banner — the loud, centre-of-screen moments: the countdown, the verdict, the round result,
	and the final standings.

	The escalation labels come straight from the escalation table, so the drama is data-driven:
	round 1 says WARM UP, round 6 says THE VERDICT, and the last round gets the gold treatment.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Banner = {}

local state
local screenGui
local holder
local mainLabel
local subLabel
local currentTween
local countdownRunning = false

local function animateIn()
	if currentTween then
		currentTween:Cancel()
	end
	holder.Visible = true
	holder.Position = UDim2.new(0.5, 0, 0.34, 0)
	holder.BackgroundTransparency = 1
	mainLabel.TextTransparency = 1
	subLabel.TextTransparency = 1
	mainLabel.TextSize = 46

	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	currentTween = TweenService:Create(mainLabel, info, { TextTransparency = 0, TextSize = 56 })
	currentTween:Play()
	TweenService:Create(subLabel, info, { TextTransparency = 0 }):Play()
end

function Banner.show(main: string, sub: string?, duration: number?, color: Color3?)
	mainLabel.Text = main
	mainLabel.TextColor3 = color or Theme.Color.Accent
	subLabel.Text = sub or ""
	animateIn()
	if duration then
		task.delay(duration, function()
			Banner.hide()
		end)
	end
end

function Banner.hide()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	holder.Visible = false
end

local function startCountdown(endsAt: number, serverNow: number)
	if countdownRunning then
		return
	end
	countdownRunning = true

	task.spawn(function()
		local start = os.clock()
		local lastShown = nil
		while true do
			local elapsed = os.clock() - start
			local remaining = endsAt - (serverNow + elapsed)
			if remaining <= -0.4 then
				break
			end
			local number = math.ceil(remaining)
			if number >= 1 then
				if lastShown ~= number then
					lastShown = number
					Banner.show(tostring(number), nil, nil, Theme.Color.Paper)
				end
			elseif lastShown ~= "GO" then
				lastShown = "GO"
				Banner.show("FIGHT", nil, nil, Theme.Color.Accent)
			end
			task.wait(0.05)
		end
		task.delay(0.4, Banner.hide)
		countdownRunning = false
	end)
end

function Banner.init(options)
	state = options.state

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MRBanner"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 8
	screenGui.Parent = playerGui

	holder = Theme.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.34, 0),
		Size = UDim2.new(0, 760, 0, 150),
		BackgroundTransparency = 1,
		Visible = false,
	}, screenGui)

	mainLabel = Theme.label({
		Size = UDim2.new(1, 0, 0, 80),
		Text = "",
		TextSize = 56,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Accent,
	}, holder)

	subLabel = Theme.label({
		Position = UDim2.new(0, 0, 0, 84),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		TextSize = 20,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.PaperDim,
	}, holder)

	state.Signals.Round:Connect(function(payload)
		local roundState = payload.State

		if roundState == "VoteOpen" then
			Banner.hide()
		elseif roundState == "Reveal" then
			Banner.hide()
		elseif roundState == "Transform" then
			-- VoteUI owns the verdict stamp; the banner stays out of the way.
			Banner.hide()
		elseif roundState == "Countdown" then
			startCountdown(payload.EndsAt or 0, payload.ServerNow or 0)
		elseif roundState == "Live" then
			Banner.hide()
		elseif roundState == "RoundEnd" then
			local winner = payload.RoundWinner
			if winner then
				Banner.show("ROUND " .. tostring(payload.Round or ""), winner .. " SURVIVED", 3, Theme.Color.Paper)
			else
				Banner.show("NOBODY SURVIVED", "everyone lost simultaneously", 3, Theme.Color.Combat)
			end
		elseif roundState == "MatchEnd" then
			Banner.show("MATCH OVER", payload.Winner and (payload.Winner .. " WINS THE MATCH") or "", 6, Theme.Color.Verdict)
		end
	end)

	state.Signals.MatchResult:Connect(function(payload)
		local standings = payload.Standings or {}
		local lines = {}
		for index = 1, math.min(#standings, 3) do
			local row = standings[index]
			local player = Players:GetPlayerByUserId(row.UserId)
			local name = player and player.DisplayName or tostring(row.UserId)
			table.insert(lines, string.format("%d. %s  %d", row.Rank, name, row.Points))
		end
		Banner.show(
			payload.Winner .. " WINS",
			table.concat(lines, "     "),
			8,
			Theme.Color.Verdict
		)
	end)

	return Banner
end

return Banner
