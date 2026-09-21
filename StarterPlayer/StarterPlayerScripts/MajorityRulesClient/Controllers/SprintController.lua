--!nonstrict
--[[
	SprintController — Shift to sprint.

	The client is a *requester*, nothing more: it reads the input, fires one boolean, and shows a
	stamina bar as a pure guess (the server owns the real state machine). This keeps gameplay
	server-authoritative while the input stays client-side where input belongs.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Net = require(Shared.Net)

local SprintController = {}

local player = Players.LocalPlayer

local remote -- set in init; created by Net.materialize on the server
local bar, fill -- the stamina bar

local function request(sprinting: boolean)
	if remote then
		remote:FireServer(sprinting)
	end
end

local function buildBar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MRSprint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	bar = Instance.new("Frame")
	bar.Name = "StaminaBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.Size = UDim2.new(0, 180, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	bar.BackgroundTransparency = 0.25
	bar.BorderSizePixel = 0
	bar.Parent = gui

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bar

	gui.Parent = player:WaitForChild("PlayerGui")
end

function SprintController.init()
	remote = Net.event(Net.Events.SprintInput)

	local sprinting = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprinting = true
			request(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			sprinting = false
			request(false)
		end
	end)

	-- Mobile: double-tap the movement stick is not reliable across devices; a UI button is the
	-- honest cross-platform answer and can be added with the HUD pass. For now keyboard only,
	-- which the Notify channel can tell mobile players about.

	buildBar()

	-- Client-side mirror of the server's state machine, for the bar only.
	local stamina = Combat.SprintStaminaMax
	local locked = false
	local heartbeat = game:GetService("RunService").RenderStepped
	heartbeat:Connect(function(dt)
		-- guess the same arithmetic the server runs, so the bar reads right without a replica
		if sprinting and stamina > 0 and not locked then
			stamina = math.max(0, stamina - Combat.SprintDrainPerSecond * dt)
			if stamina <= 0 then
				locked = true
			end
		else
			stamina = math.min(Combat.SprintStaminaMax, stamina + Combat.SprintRegenPerSecond * dt)
			if locked and stamina >= Combat.SprintResetThreshold then
				locked = false
			end
		end
		if fill then
			fill.Size = UDim2.new(stamina / Combat.SprintStaminaMax, 0, 1, 0)
			fill.BackgroundColor3 = locked and Color3.fromRGB(200, 80, 80) or Color3.fromRGB(120, 200, 255)
		end
	end)
end

return SprintController
