--!nonstrict
--[[
	FxController — the cosmetic layer that makes server-authoritative combat readable.

	Two jobs:

	  1. **The nameplate.** The winning modifiers are written onto a physical part in the arena,
	     so the verdict is a thing standing in the world rather than a HUD element that
	     disappears. The server only sets a text attribute; the presentation is client-side and
	     therefore free to be rebuilt without touching gameplay.
	  2. **Tracers.** Bullets are simulated on the server, so hits need a visual to be
	     understandable. Traces are decorative only — they cannot influence a hit.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tags = require(Shared.Tags)
local Net = require(Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local FxController = {}

local nameplateLabel
local wiredArena

-- ---------------------------------------------------------------------------------------
-- Tracers
-- ---------------------------------------------------------------------------------------

local function drawTracer(from: Vector3, to: Vector3, didHit: boolean?)
	local distance = (to - from).Magnitude
	if distance <= 0.5 then
		return
	end

	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = didHit and Theme.Color.Combat or Theme.Color.Accent
	tracer.Transparency = 0.35
	tracer.Size = Vector3.new(0.12, 0.12, distance)
	tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, 0.07)
end

-- ---------------------------------------------------------------------------------------
-- Nameplate
-- ---------------------------------------------------------------------------------------

local function wireNameplate(part: BasePart)
	if nameplateLabel and nameplateLabel.Parent then
		return
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "MRNameplate"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.Adornee = part
	surface.Parent = part

	local backing = Instance.new("Frame")
	backing.Size = UDim2.new(1, 0, 1, 0)
	backing.BackgroundColor3 = Theme.Color.Graphite
	backing.BackgroundTransparency = 0.25
	backing.BorderSizePixel = 0
	backing.Parent = surface

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, -16)
	label.Position = UDim2.new(0, 10, 0, 8)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Display
	label.TextColor3 = Theme.Color.Paper
	label.TextScaled = true
	label.Text = "MAJORITY RULES"
	label.Parent = backing
	nameplateLabel = label

	local function refresh()
		local text = part:GetAttribute(Tags.Attr.Text)
		if text and #text > 0 then
			label.Text = text
			label.TextColor3 = Theme.Color.Accent
		end
	end

	part:GetAttributeChangedSignal(Tags.Attr.Text):Connect(refresh)
	refresh()
end

local function wireArena(arena: Instance)
	if wiredArena == arena then
		return
	end
	wiredArena = arena

	for _, instance in CollectionService:GetTagged(Tags.VoteNameplate) do
		if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
			wireNameplate(instance)
		end
	end
end

function FxController.init(options)
	local state = options.state

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "Arena" then
			task.wait(0.1)
			wireArena(child)
		end
	end)
	local existing = Workspace:FindFirstChild("Arena")
	if existing then
		wireArena(existing)
	end

	Net.event(Net.Events.WeaponTracer).OnClientEvent:Connect(function(_shooter, from, to, didHit)
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			drawTracer(from, to, didHit)
		end
	end)

	state.Signals.Transform:Connect(function()
		-- The nameplate text is set by the server during the transform; nothing to do here
		-- beyond making sure the plate exists on a freshly loaded arena.
		local arena = Workspace:FindFirstChild("Arena")
		if arena then
			wireArena(arena)
		end
	end)

	return FxController
end

return FxController
