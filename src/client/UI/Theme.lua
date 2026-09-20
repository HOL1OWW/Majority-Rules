--!nonstrict
--[[
	Theme — the brand, in code.

	Art direction: bureaucracy gone feral. Clean government-paperwork surfaces that have lost
	their mind: paper cards, hard stamped verdicts, category colours so a player learns what
	*kind* of chaos they are voting for at a glance.

	Palette and rationale live in docs/05-BRAND.md. Use built-in Roblox fonts only, so the game
	renders identically on every device with nothing to upload.
]]

local Theme = {}

Theme.Color = {
	Paper = Color3.fromRGB(240, 236, 226),
	PaperDim = Color3.fromRGB(206, 201, 190),
	Ink = Color3.fromRGB(24, 25, 30),
	Graphite = Color3.fromRGB(32, 35, 42),
	GraphiteSoft = Color3.fromRGB(50, 54, 64),
	GraphiteLine = Color3.fromRGB(78, 83, 96),

	Accent = Color3.fromRGB(214, 255, 63),
	AccentDim = Color3.fromRGB(146, 174, 44),

	Gravity = Color3.fromRGB(124, 107, 255),
	Combat = Color3.fromRGB(255, 77, 77),
	Environment = Color3.fromRGB(47, 208, 140),
	Chaos = Color3.fromRGB(255, 47, 176),
	Verdict = Color3.fromRGB(255, 197, 61),

	Spatial = Color3.fromRGB(79, 179, 255),
	Loadout = Color3.fromRGB(255, 159, 69),
	Vision = Color3.fromRGB(154, 164, 184),
	Mobility = Color3.fromRGB(95, 225, 225),
	Shrink = Color3.fromRGB(255, 138, 92),
	Mute = Color3.fromRGB(148, 152, 164),
}

Theme.Font = {
	Display = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Mono = Enum.Font.Code,
}

--! Category colour for a modifier's tag list.
function Theme.categoryColor(tags): Color3
	if type(tags) == "table" then
		for _, tag in tags do
			local color = Theme.Color[tag]
			if color then
				return color
			end
		end
	end
	return Theme.Color.Mute
end

function Theme.corner(radius: number, parent: Instance): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = parent
	return corner
end

function Theme.stroke(color: Color3, thickness: number?, parent: Instance): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Theme.padding(amount: number, parent: Instance): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = parent
	return padding
end

function Theme.frame(props: { [string]: any }, parent: Instance?): Frame
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Theme.Color.Graphite
	for key, value in props do
		(frame :: any)[key] = value
	end
	frame.Parent = parent
	return frame
end

function Theme.label(props: { [string]: any }, parent: Instance?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Body
	label.TextColor3 = Theme.Color.Paper
	label.TextScaled = false
	label.RichText = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function Theme.button(props: { [string]: any }, parent: Instance?): TextButton
	local button = Instance.new("TextButton")
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Theme.Color.GraphiteSoft
	for key, value in props do
		(button :: any)[key] = value
	end
	button.Parent = parent
	return button
end

function Theme.listLayout(parent: Instance, direction: Enum.FillDirection?, padding: number?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, padding or 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = parent
	return layout
end

function Theme.formatClock(seconds: number): string
	local value = math.max(0, seconds)
	if value >= 60 then
		return string.format("%d:%02d", math.floor(value / 60), math.floor(value % 60))
	end
	return string.format("%.1f", value)
end

function Theme.formatPoints(points: number?): string
	return string.format("%d", points or 0)
end

return Theme
