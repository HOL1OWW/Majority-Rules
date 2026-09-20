--!nonstrict
--[[
	CameraController — the cinematic.

	The transformation is the product, so the camera has to sell it. Three modes:

	  orbit     the vote and the transform: the camera detaches and drifts through the arena's
	            `VoteShowcase` markers, so players watch their decision happen from outside
	  player    normal play
	  spectate  after elimination: follow someone who is still alive

	Accessibility: if the player has reduced motion enabled we keep the wide framing but stop
	moving the camera, rather than skipping the moment entirely — they still see the arena
	rebuild, they just are not dragged around while it happens.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tags = require(ReplicatedStorage:WaitForChild("Shared").Tags)

local CameraController = {}

local state
local camera
local mode = "player"
local orbit = {}
local progress = 0
local reducedMotion = false
local spectateTarget = nil
local spectateTimer = 0

local VOTE_STATES = { VoteOpen = true, VoteLock = true, TieBreak = true, Reveal = true, Transform = true }

local function detectReducedMotion()
	pcall(function()
		local settings = UserSettings():GetService("UserGameSettings")
		reducedMotion = settings.ReducedMotion == Enum.ReducedMotion.Enabled
	end)
end

local function arenaCenter(): Vector3
	local arena = workspace:FindFirstChild("Arena")
	if arena and arena:IsA("Model") then
		return arena:GetPivot().Position
	end
	return Vector3.new(0, 0, 0)
end

--! Prefer the markers the map team authored; fall back to a generated ring so the cinematic
--! works on any arena, including one that forgot to add them.
local function rebuildOrbit()
	orbit = {}
	local markers = {}
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, instance in CollectionService:GetTagged(Tags.VoteCamera) do
			if instance:IsDescendantOf(arena) and instance:IsA("BasePart") then
				table.insert(markers, instance)
			end
		end
	end
	table.sort(markers, function(a, b)
		return (a:GetAttribute(Tags.Attr.Order) or 0) < (b:GetAttribute(Tags.Attr.Order) or 0)
	end)

	if #markers > 0 then
		for _, marker in markers do
			orbit[#orbit + 1] = marker.CFrame
		end
		return
	end

	local center = arenaCenter()
	local height = 46
	local radius = 88
	for index = 1, 4 do
		local angle = (index - 1) / 4 * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		orbit[#orbit + 1] = CFrame.lookAt(position, center + Vector3.new(0, 6, 0))
	end
end

local function setMode(newMode: string)
	if mode == newMode then
		return
	end
	mode = newMode
	progress = 0

	if mode == "orbit" then
		rebuildOrbit()
		camera.CameraType = Enum.CameraType.Scriptable
		if #orbit > 0 then
			camera.CFrame = orbit[1]
		end
	else
		camera.CameraType = Enum.CameraType.Custom
		local player = Players.LocalPlayer
		if player.Character then
			camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
		end
	end
end

local function pickSpectateTarget()
	local candidates = {}
	for _, player in Players:GetPlayers() do
		if player ~= Players.LocalPlayer and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(candidates, humanoid)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function step(dt: number)
	if mode == "orbit" and #orbit > 1 then
		if reducedMotion then
			camera.CFrame = orbit[1]
			return
		end
		local speed = (state.round.State == "Transform") and 0.28 or 0.12
		progress = (progress + dt * speed) % 1
		local scaled = progress * #orbit
		local index = math.floor(scaled) + 1
		local nextIndex = (index % #orbit) + 1
		local alpha = scaled - math.floor(scaled)
		camera.CFrame = orbit[index]:Lerp(orbit[nextIndex], alpha)
	elseif mode == "spectate" then
		spectateTimer -= dt
		if spectateTimer <= 0 or not spectateTarget or not spectateTarget.Parent or spectateTarget.Health <= 0 then
			spectateTarget = pickSpectateTarget()
			spectateTimer = 6
		end
		if spectateTarget then
			camera.CameraSubject = spectateTarget
		else
			setMode("orbit")
		end
	end
end

local function onRoundState(payload)
	local roundState = payload.State

	if VOTE_STATES[roundState] then
		setMode("orbit")
		return
	end

	if roundState == "Countdown" or roundState == "Live" then
		local player = Players.LocalPlayer
		if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
			setMode("player")
		else
			setMode("spectate")
		end
		return
	end

	if roundState == "Idle" or roundState == "MatchEnd" then
		setMode("player")
	end
end

function CameraController.init(options)
	state = options.state
	camera = workspace.CurrentCamera
	detectReducedMotion()

	state.Signals.Round:Connect(onRoundState)

	-- A new arena means new showcase markers.
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Arena" then
			task.wait(0.1)
			rebuildOrbit()
		end
	end)

	RunService.RenderStepped:Connect(step)

	-- The local player dying should immediately hand the camera to a spectator view.
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		if state.round.State == "Live" then
			setMode("spectate")
		end
	end)

	return CameraController
end

return CameraController
