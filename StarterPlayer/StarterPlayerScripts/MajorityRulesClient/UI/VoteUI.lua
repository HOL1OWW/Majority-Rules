--!nonstrict
--[[
	VoteUI — the centrepiece, in pixels.

	What it has to achieve in about two seconds of looking:

	  * make it obvious that this is a decision, not a loading screen,
	  * make it obvious what each card will do to the arena, in one short line,
	  * make it obvious what everyone else is picking, because the social pressure is the game,
	  * and make the winner feel like a verdict being stamped, not a menu closing.

	Card layout is driven by UISizeConstraint rather than hand-measured pixel maths, so it
	scales from a phone to a monitor without a device branch.
]]

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local VoteUI = {}

local state
local onVote
local screenGui
local root
local headerLabel
local statusLabel
local timerLabel
local cardRow
local stampOverlay
local stampCard
local stampTitle
local stampIcons
local stampDetail
local cards = {}
local thumbCache = {}
local stampTween

local TIER_LABEL = { "TIER 1", "TIER 2", "TIER 3" }

-- One emoji per Effects token. Chosen so the row reads as a sentence of mechanics at a
-- glance: float, slide, bounce, darkness. A modifier with an unmapped effect simply gets
-- no chip — silent, never wrong. Text glyphs rather than image assets: zero uploads, and
-- they inherit the category tint so chaos reads chaos at a glance.
local EFFECT_ICON = {
	GravityDown = "🪶",
	GravityUp = "🔺",
	AirTime = "🎈",
	AirJump = "⏫",
	Bouncy = "🫧",
	Drift = "🧊",
	ZeroFriction = "🧊",
	FastWalk = "👟",
	SlowWalk = "🐌",
	NoJump = "🚫",
	Collapse = "💥",
	Cover = "📦",
	Hazard = "⚠️",
	Lava = "🌋",
	Gamble = "🎰",
	InfiniteAmmo = "♾️",
	Lifesteal = "🩸",
	LoadoutOverride = "🔫",
	NoRanged = "🎯",
	LowHealth = "❤️‍🔥",
	Ricochet = "⚡",
	Shrink = "📉",
	VisionLimited = "🌫️",
	Darkness = "🌑",
	Example = "❓",
}

local function fetchThumbnail(userId: number): string
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
	return ok and url or ""
end

local function buildCard(index: number)
	local card = Theme.button({
		Name = "Card" .. index,
		LayoutOrder = index,
		BackgroundColor3 = Theme.Color.GraphiteSoft,
		Size = UDim2.new(0.25, -12, 1, 0),
	}, cardRow)
	Theme.corner(10, card)
	local stroke = Theme.stroke(Theme.Color.GraphiteLine, 2, card)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(120, 130)
	constraint.MaxSize = Vector2.new(260, 210)
	constraint.Parent = card

	local accent = Theme.frame({
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Theme.Color.Mute,
	}, card)

	local tier = Theme.label({
		Position = UDim2.new(0, 12, 0, 14),
		Size = UDim2.new(0, 80, 0, 14),
		Text = "TIER 1",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Mute,
	}, card)

	local name = Theme.label({
		Position = UDim2.new(0, 12, 0, 30),
		Size = UDim2.new(1, -24, 0, 44),
		Text = "MODIFIER",
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Paper,
	}, card)

	local blurb = Theme.label({
		Position = UDim2.new(0, 12, 0, 98),
		Size = UDim2.new(1, -24, 0, 34),
		Text = "",
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Font.Body,
		TextColor3 = Theme.Color.Mute,
	}, card)

	-- Effect chips: the mechanical truth under the fantasy. Built once per card, refilled
	-- by setEffects each render. Sits between the name and the blurb.
	local effectRow = Theme.frame({
		Position = UDim2.new(0, 12, 0, 76),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundTransparency = 1,
		ClipsDescendants = true, -- 5-card ballots make narrow cards; overflow must never paint over the tally
	}, card)
	Theme.listLayout(effectRow, Enum.FillDirection.Horizontal, 4)

	local tallyBackground = Theme.frame({
		Position = UDim2.new(0, 12, 1, -46),
		Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = Theme.Color.Graphite,
	}, card)
	Theme.corner(4, tallyBackground)
	local tallyFill = Theme.frame({
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Color.Accent,
	}, tallyBackground)
	Theme.corner(4, tallyFill)

	local voteCount = Theme.label({
		Position = UDim2.new(0, 12, 1, -30),
		Size = UDim2.new(0, 90, 0, 20),
		Text = "0 VOTES",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.PaperDim,
	}, card)

	local avatarRow = Theme.frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 1, -32),
		Size = UDim2.new(0, 116, 0, 24),
		BackgroundTransparency = 1,
	}, card)
	local avatarLayout = Theme.listLayout(avatarRow, Enum.FillDirection.Horizontal, 4)
	avatarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local avatarPool = {}
	for index2 = 1, 5 do
		local avatar = Instance.new("ImageLabel")
		avatar.Size = UDim2.new(0, 22, 0, 22)
		avatar.BackgroundColor3 = Theme.Color.Graphite
		avatar.BorderSizePixel = 0
		avatar.LayoutOrder = index2
		avatar.Visible = false
		avatar.Parent = avatarRow
		Theme.corner(11, avatar)
		table.insert(avatarPool, avatar)
	end

	local yourPick = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 14),
		Size = UDim2.new(0, 96, 0, 16),
		Text = "YOUR PICK",
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Accent,
		Visible = false,
	}, card)

	card.MouseEnter:Connect(function()
		if card:GetAttribute("Enabled") ~= false then
			stroke.Color = Theme.Color.AccentDim
		end
	end)
	card.MouseLeave:Connect(function()
		stroke.Color = Theme.Color.GraphiteLine
	end)

	return {
		button = card,
		stroke = stroke,
		accent = accent,
		tier = tier,
		name = name,
		blurb = blurb,
		effectRow = effectRow,
		tallyBackground = tallyBackground,
		tallyFill = tallyFill,
		voteCount = voteCount,
		avatars = avatarPool,
		yourPick = yourPick,
		modifierId = nil,
	}
end

local function ensureCards(count: number)
	while #cards < count do
		local index = #cards + 1
		local card = buildCard(index)
		local captured = card
		card.button.MouseButton1Click:Connect(function()
			if not captured.modifierId then
				return
			end
			if state.round.State ~= "VoteOpen" and state.round.State ~= "TieBreak" then
				return
			end
			onVote(captured.modifierId)
		end)
		table.insert(cards, card)
	end
	for index, card in cards do
		card.button.Visible = index <= count
		card.button.Size = UDim2.new(1 / count, -(12 * (count - 1)) / count, 1, 0)
	end
end

-- Refill a card's effect chips from its candidate. Pool pattern like the avatar row:
-- build lazily, toggle visibility, never churn instances on a 0.5s replication tick.
local function setEffects(card, effects, tint)
	local row = card.effectRow
	if not row then
		return
	end
	local pool = card.effectChips
	if not pool then
		pool = {}
		card.effectChips = pool
	end

	local list = (type(effects) == "table") and effects or {}
	for index = 1, math.max(#list, #pool) do
		local effect = list[index]
		local chip = pool[index]
		if effect and EFFECT_ICON[effect] then
			if not chip then
				chip = Theme.label({
					Size = UDim2.new(0, 20, 0, 18),
					TextSize = 13,
					Font = Theme.Font.Heading,
				}, row)
				pool[index] = chip
			end
			chip.Text = EFFECT_ICON[effect]
			chip.TextColor3 = tint
			chip.Visible = true
		elseif chip then
			chip.Visible = false
		end
	end
end

local function setAvatars(card, userIds: { number })
	for index = 1, 5 do
		local avatar = card.avatars[index]
		local userId = userIds[index]
		if userId then
			avatar.Visible = true
			local cached = thumbCache[userId]
			if cached then
				avatar.Image = cached
			else
				avatar.Image = ""
				task.spawn(function()
					local url = fetchThumbnail(userId)
					thumbCache[userId] = url
					if avatar.Parent then
						avatar.Image = url
					end
				end)
			end
		else
			avatar.Visible = false
		end
	end
end

local function render()
	local vote = state.vote
	if not vote then
		return
	end

	local roundState = state.round.State
	local voteVisible = roundState == "VoteOpen" or roundState == "VoteLock" or roundState == "TieBreak"
	root.Visible = voteVisible
	if not voteVisible then
		return
	end

	local candidates = vote.Candidates or {}
	ensureCards(#candidates)

	local maxTally = 1
	for _, candidate in candidates do
		maxTally = math.max(maxTally, candidate.Tally or 0)
	end

	if vote.TieBreak then
		statusLabel.Text = "IT IS A TIE. VOTE AGAIN. ONE CARD LEAVES."
		statusLabel.TextColor3 = Theme.Color.Combat
	else
		statusLabel.Text = state.round.Label or ""
		statusLabel.TextColor3 = Theme.Color.Verdict
	end
	statusLabel.Visible = true
	headerLabel.Text = vote.TieBreak and "SUDDEN DEATH REVOTE" or "WHAT HAPPENS TO THE ARENA?"

	for index, card in cards do
		local candidate = candidates[index]
		if candidate and card.button.Visible then
			card.modifierId = candidate.Id
			card.name.Text = candidate.DisplayName
			card.blurb.Text = candidate.Blurb
			card.tier.Text = TIER_LABEL[math.clamp(candidate.Tier or 1, 1, 3)]
			card.voteCount.Text = string.format("%d VOTE%s", candidate.Tally or 0, (candidate.Tally or 0) == 1 and "" or "S")
			card.yourPick.Visible = vote.YourVote == candidate.Id

			local isGamble = candidate.IsGamble == true
			local color = isGamble and Theme.Color.Verdict or Theme.categoryColor(candidate.Tags)
			card.accent.BackgroundColor3 = color
			card.tallyFill.BackgroundColor3 = isGamble and Theme.Color.Verdict or Theme.Color.Accent
			card.tier.TextColor3 = color
			setEffects(card, candidate.Effects, color)

			local fraction = (candidate.Tally or 0) / maxTally
			card.tallyFill.Size = UDim2.new(fraction, 0, 1, 0)

			card.button.BackgroundColor3 = (vote.YourVote == candidate.Id) and Theme.Color.Graphite
				or Theme.Color.GraphiteSoft
			card.stroke.Color = (vote.YourVote == candidate.Id) and Theme.Color.AccentDim
				or Theme.Color.GraphiteLine

			setAvatars(card, candidate.Voters or {})
		else
			card.modifierId = nil
		end
	end
end

local function updateTimer()
	if not root.Visible then
		return
	end
	local remaining = state.secondsRemaining()
	timerLabel.Text = Theme.formatClock(remaining)
	if state.round.Total and state.round.Total > 0 then
		timerLabel.Text = string.format("%s   %d/%d", Theme.formatClock(remaining), state.round.Round or 0, state.round.Total)
	end
	timerLabel.TextColor3 = remaining <= 5 and Theme.Color.Combat or Theme.Color.Accent
end

-- Look up the Effects of each winning modifier by name so the stamp can show the same
-- icons the card did. Requires Modifiers; only called from showStamp, which the nil-guard
-- already protects.
local function effectIconsFor(modifierNames)
	local ok, Modifiers = pcall(require, game:GetService("ReplicatedStorage").Shared.Modifiers)
	if not ok then
		return ""
	end
	local icons = {}
	for _, name in modifierNames do
		local def = Modifiers.ById[name] or Modifiers.ById[string.lower(name)]
		if not def then
			for _, candidate in pairs(Modifiers.ById) do
				if candidate.DisplayName == name then
					def = candidate
					break
				end
			end
		end
		if def then
			for _, effect in def.Effects or {} do
				local icon = EFFECT_ICON[effect]
				if icon and not table.find(icons, icon) then
					table.insert(icons, icon)
				end
			end
		end
	end
	return table.concat(icons, " ")
end

function VoteUI.showStamp(modifierNames: { string }, duration: number)
	-- A short round can resolve before the client has built this UI: Bootstrap connects the
	-- replication handlers before it calls `init`. There is nothing to draw on yet, so skip it
	-- rather than erroring on a nil label.
	if not stampOverlay or not stampTitle or not stampDetail or not stampIcons then
		return
	end

	stampTitle.Text = "APPROVED"
	stampDetail.Text = table.concat(modifierNames, "  +  ")
	stampIcons.Text = effectIconsFor(modifierNames)
	stampOverlay.Visible = true
	if stampTween then
		stampTween:Cancel()
	end
	stampCard.Size = UDim2.new(0, 420, 0, 150)
	stampCard.Rotation = -14
	local info = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	stampTween = game:GetService("TweenService"):Create(stampCard, info, {
		Size = UDim2.new(0, 470, 0, 168),
	})
	stampTween:Play()

	task.delay(duration, function()
		stampOverlay.Visible = false
	end)
end

function VoteUI.hideStamp()
	if not stampOverlay then
		return
	end

	stampOverlay.Visible = false
end

function VoteUI.init(options)
	state = options.state
	onVote = options.onVote

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MRVoteUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	root = Theme.frame({
		Name = "Vote",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 252),
		BackgroundColor3 = Theme.Color.Graphite,
		BackgroundTransparency = 0.08,
		Visible = false,
	}, screenGui)
	Theme.stroke(Theme.Color.AccentDim, 2, root)

	headerLabel = Theme.label({
		Position = UDim2.new(0, 20, 0, 10),
		Size = UDim2.new(1, -260, 0, 26),
		Text = "WHAT HAPPENS TO THE ARENA?",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Accent,
	}, root)

	statusLabel = Theme.label({
		Position = UDim2.new(0, 20, 0, 34),
		Size = UDim2.new(1, -260, 0, 18),
		Text = "",
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.Verdict,
		Visible = false,
	}, root)

	timerLabel = Theme.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 12),
		Size = UDim2.new(0, 240, 0, 30),
		Text = "20.0",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Accent,
	}, root)

	cardRow = Theme.frame({
		Position = UDim2.new(0, 20, 0, 58),
		Size = UDim2.new(1, -40, 1, -70),
		BackgroundTransparency = 1,
	}, root)
	local layout = Theme.listLayout(cardRow, Enum.FillDirection.Horizontal, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	-- The verdict stamp: the moment the vote stops being a menu and becomes a decision.
	stampOverlay = Theme.frame({
		Name = "Stamp",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}, screenGui)

	stampCard = Theme.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.new(0, 470, 0, 168),
		BackgroundColor3 = Theme.Color.Graphite,
		BackgroundTransparency = 0.08,
		Rotation = -14,
		ZIndex = 21,
	}, stampOverlay)
	Theme.corner(8, stampCard)
	Theme.stroke(Theme.Color.Accent, 6, stampCard)

	stampTitle = Theme.label({
		Position = UDim2.new(0, 0, 0, 12),
		Size = UDim2.new(1, 0, 0, 38),
		Text = "APPROVED",
		TextSize = 38,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Accent,
		ZIndex = 22,
	}, stampCard)

	-- The winner's mechanics, as icons: the same chips the voter saw on their card, so the
	-- stamp reads as the arena contract, not just a name.
	stampIcons = Theme.label({
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		TextSize = 20,
		Font = Theme.Font.Heading,
		TextColor3 = Theme.Color.PaperDim,
		ZIndex = 22,
	}, stampCard)

	stampDetail = Theme.label({
		Position = UDim2.new(0, 12, 0, 82),
		Size = UDim2.new(1, -24, 0, 72),
		Text = "",
		TextSize = 24,
		TextWrapped = true,
		Font = Theme.Font.Display,
		TextColor3 = Theme.Color.Paper,
		ZIndex = 22,
	}, stampCard)

	state.Signals.Vote:Connect(render)
	state.Signals.Round:Connect(render)

	task.spawn(function()
		while true do
			updateTimer()
			task.wait(0.1)
		end
	end)

	return VoteUI
end

return VoteUI
