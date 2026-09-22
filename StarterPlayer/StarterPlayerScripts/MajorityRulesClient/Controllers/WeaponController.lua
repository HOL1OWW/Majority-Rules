--!nonstrict
--[[
	WeaponController — "I aimed at THIS point, from THIS muzzle", and nothing more.

	The client's entire contribution to combat is a muzzle position and an AIM POINT: the world
	location the camera ray through the mouse cursor settles on. The server derives the real shot
	direction from muzzle → aim point, so the shot converges on the target instead of running
	parallel to the camera's ray (D-051 — the shiftlock-only bug). Spread, range, pellets, damage,
	ricochet and ammo are all decided on the server, which means there is no client-side combat
	code to exploit — the worst a modified client can do is ask to fire slightly more often than
	it is allowed to.

	Firing is driven from `Tool.Activated` for semi-automatic weapons and from a held-input loop
	for automatic ones. The crosshair dot marks the convergence point; a white flash confirms a
	connected pellet on the shooter's own screen.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage:WaitForChild("Shared").Weapons.WeaponRegistry)

local WeaponController = {}

local Camera = Workspace.CurrentCamera

local remotes
local player
local equipped: Tool?
local autoLoopActive = false

local function profileOf(tool: Instance?)
	if not tool or not tool:IsA("Tool") then
		return nil
	end
	local weaponId = tool:GetAttribute("WeaponId")
	if not weaponId then
		return nil
	end
	return Weapons.get(weaponId)
end

local function muzzleOrigin(tool: Tool): Vector3?
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local muzzle = handle:FindFirstChild("Muzzle")
		if muzzle and muzzle:IsA("Attachment") then
			return muzzle.WorldPosition
		end
		return handle.Position
	end
	return nil
end

--! ----------------------------------------------------------------------------- aim point
--! D-049/D-051: a third-person shot must separate AIMING from SHOOTING.
--!
--!   Aim   — the camera ray through the mouse cursor picks a POINT in the world (what the player
--!           believes they are pointing at). On nothing, the point rides the ray to weapon range.
--!   Shoot — the server casts from the MUZZLE toward that point, so the two rays CONVERGE on the
--!           target. Casting muzzle + camera direction instead leaves them parallel-but-offset,
--!           which only meets its mark when the target sits dead-centre — the exact reason this
--!           used to work in shiftlock and nowhere else.

local AIM_SEARCH_STUDS = 600 -- how far the aim ray hunts for a surface before giving up

local crosshit -- one-shot flash frame at the cursor, shown when one of your pellets connects

local function aimRaycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { Camera }
	local character = player.Character
	if character then
		table.insert(exclude, character)
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function aimPoint(): Vector3
	local point: Vector3
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_SEARCH_STUDS, aimRaycastParams())
		if result then
			point = result.Position
		else
			point = ray.Origin + ray.Direction * AIM_SEARCH_STUDS
		end
	else
		-- Touch: no cursor. Screen centre is the honest read of intent on a phone.
		local ray = Camera:ViewportPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_SEARCH_STUDS, aimRaycastParams())
		point = result and result.Position or (ray.Origin + ray.Direction * AIM_SEARCH_STUDS)
	end
	if crosshit then
		crosshit.Visible = false -- per-shot flash, reset as the next one is acquired
	end
	return point
end

local function fire(tool: Tool)
	local profile = profileOf(tool)
	if not profile then
		return
	end
	local character = player.Character
	if not character or not tool:IsDescendantOf(character) then
		return
	end
	local origin = muzzleOrigin(tool)
	if not origin then
		return
	end
	local aimAt = aimPoint()
	local aimFrom = Camera.CFrame.Position

	-- D-051 contract: (tool, muzzleOrigin, legacyDirection, aimPoint, aimFrom). The legacy
	-- direction slot is sent as nil; the server converges the true ray from muzzle → aim point.
	remotes.WeaponFire:FireServer(tool, origin, nil, aimAt, aimFrom)
end

local function stopAutoLoop()
	autoLoopActive = false
end

local function startAutoLoop()
	if autoLoopActive then
		return
	end
	autoLoopActive = true

	task.spawn(function()
		while autoLoopActive do
			local tool = equipped
			local profile = profileOf(tool)
			if tool and profile and profile.Automatic then
				local held = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
					or UserInputService:IsKeyDown(Enum.KeyCode.ButtonR2)
				if held then
					fire(tool)
					task.wait(math.max(profile.FireRate, 0.03))
				else
					task.wait(0.03)
				end
			else
				task.wait(0.05)
			end
		end
	end)
end

local function bindTool(tool: Tool)
	tool.Equipped:Connect(function()
		equipped = tool
		startAutoLoop()
	end)

	tool.Unequipped:Connect(function()
		if equipped == tool then
			equipped = nil
			stopAutoLoop()
		end
	end)

	tool.Activated:Connect(function()
		local profile = profileOf(tool)
		if not profile then
			return
		end
		if not profile.Automatic then
			fire(tool)
		elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			-- On touch there is no held-mouse state; one tap is one shot.
			fire(tool)
		end
	end)
end

--! ----------------------------------------------------------------------------- crosshair
--! Two pieces of feedback that make third-person aim trustworthy:
--!   * a small dot that sits exactly where shots will converge (the cursor itself is the aim)
--!   * a white flash the instant one of YOUR pellets connects (the server says didHit)
--! The old failure mode — shots you could not see and hits you could not confirm — is what made
--! the aiming bug feel like "shooting is broken" rather than "aiming is offset".
local gui, dot, flash

local function buildCrosshair()
	if gui then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "MRAim"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- position in raw viewport pixels, same space GetMouseLocation reports
	gui.DisplayOrder = 10

	dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(4, 4)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = 0.25
	dot.BorderSizePixel = 0
	dot.Visible = false
	dot.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	flash = Instance.new("Frame")
	flash.Name = "HitFlash"
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Size = UDim2.fromOffset(18, 18)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Visible = false
	flash.Parent = gui

	local flashCorner = Instance.new("UICorner")
	flashCorner.CornerRadius = UDim.new(1, 0)
	flashCorner.Parent = flash

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function updateCrosshair()
	if not dot then
		return
	end
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		dot.Position = UDim2.fromOffset(mouse.X, mouse.Y)
		dot.Visible = true
	else
		dot.Visible = false -- touch: the platform draws its own aim indicator
	end
end

local function confirmHit()
	if not flash then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	flash.Position = UDim2.fromOffset(mouse.X, mouse.Y)
	flash.BackgroundTransparency = 0
	flash.Visible = true
	task.delay(0.12, function()
		if flash then
			flash.Visible = false
			flash.BackgroundTransparency = 1
		end
	end)
end

local function bindCharacter(character: Model)
	equipped = nil
	stopAutoLoop()

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
end

function WeaponController.init(options)
	remotes = options.remotes
	player = Players.LocalPlayer

	buildCrosshair()
	RunService.RenderStepped:Connect(updateCrosshair)

	-- Hit confirmation: the server's tracer broadcast carries didHit; when the shooter is this
	-- player and a pellet connected, flash the crosshair. FxController draws the tracer itself;
	-- this is the shooter's private feedback.
	local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
	Net.event(Net.Events.WeaponTracer).OnClientEvent:Connect(function(shooter, _from, _to, didHit)
		if shooter == player and didHit then
			confirmHit()
		end
	end)

	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	return WeaponController
end

return WeaponController
