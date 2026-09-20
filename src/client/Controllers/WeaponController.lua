--!nonstrict
--[[
	WeaponController — "I fired", and nothing more.

	The client's entire contribution to combat is a muzzle position and a direction. Spread,
	range, pellets, damage, ricochet and ammo are all decided on the server, which means there
	is no client-side combat code to exploit — the worst a modified client can do is ask to fire
	slightly more often than it is allowed to.

	Firing is driven from `Tool.Activated` for semi-automatic weapons and from a held-input loop
	for automatic ones, and it correctly reports the camera's aim direction rather than the
	character's facing, because shooting where you look is the whole point.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage:WaitForChild("Shared").Weapons.WeaponRegistry)

local WeaponController = {}

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
	remotes.WeaponFire:FireServer(tool, origin, Workspace.CurrentCamera.CFrame.LookVector)
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

	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	return WeaponController
end

return WeaponController
