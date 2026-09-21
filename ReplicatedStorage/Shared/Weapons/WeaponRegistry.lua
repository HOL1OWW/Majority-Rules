--!nonstrict
--[[
	WeaponRegistry — weapons are data.

	A weapon is a profile table. Nothing about a weapon lives in a script, so a new weapon is a
	new entry and a balance pass is a number change. The one function here builds the Roblox Tool
	instance from a profile (server only) — tools carry no scripts of their own; CombatService
	owns every firing path.

	`Ammo = -1` means infinite.
]]

local RunService = game:GetService("RunService")

local Weapons = {}

Weapons.Profiles = {
	Sidearm = {
		DisplayName = "SIDEARM",
		Kind = "Gun",
		Damage = 18,
		Pellets = 1,
		SpreadDegrees = 1.2,
		Range = 180,
		FireRate = 0.35,
		Automatic = false,
		Ammo = 8,
		ReloadTime = 1.1,
		Color = Color3.fromRGB(120, 120, 132),
		Size = Vector3.new(0.5, 0.9, 1.6),
	},
	Pistol = {
		DisplayName = "PISTOL",
		Kind = "Gun",
		Damage = 22,
		Pellets = 1,
		SpreadDegrees = 0.8,
		Range = 200,
		FireRate = 0.4,
		Automatic = false,
		Ammo = 7,
		ReloadTime = 1.2,
		Color = Color3.fromRGB(92, 96, 110),
		Size = Vector3.new(0.5, 0.9, 1.7),
	},
	RapidPistol = {
		DisplayName = "RAPID PISTOL",
		Kind = "Gun",
		Damage = 14,
		Pellets = 1,
		SpreadDegrees = 1.8,
		Range = 160,
		FireRate = 0.16,
		Automatic = true,
		Ammo = 15,
		ReloadTime = 1.3,
		Color = Color3.fromRGB(140, 128, 96),
		Size = Vector3.new(0.5, 0.9, 1.6),
	},
	Shotgun = {
		DisplayName = "SHOTGUN",
		Kind = "Gun",
		Damage = 9,
		Pellets = 8,
		SpreadDegrees = 7,
		Range = 70,
		FireRate = 0.85,
		Automatic = false,
		Ammo = 5,
		ReloadTime = 1.7,
		Color = Color3.fromRGB(86, 62, 44),
		Size = Vector3.new(0.6, 0.9, 2.6),
	},
	SawnOff = {
		DisplayName = "SAWN-OFF",
		Kind = "Gun",
		Damage = 11,
		Pellets = 10,
		SpreadDegrees = 11,
		Range = 42,
		FireRate = 1.05,
		Automatic = false,
		Ammo = 2,
		ReloadTime = 1.5,
		Color = Color3.fromRGB(104, 74, 52),
		Size = Vector3.new(0.6, 0.85, 1.5),
	},
	Rifle = {
		DisplayName = "RIFLE",
		Kind = "Gun",
		Damage = 15,
		Pellets = 1,
		SpreadDegrees = 1.1,
		Range = 260,
		FireRate = 0.13,
		Automatic = true,
		Ammo = 26,
		ReloadTime = 1.9,
		Color = Color3.fromRGB(64, 66, 72),
		Size = Vector3.new(0.5, 0.9, 3),
	},
	SMG = {
		DisplayName = "SMG",
		Kind = "Gun",
		Damage = 10,
		Pellets = 1,
		SpreadDegrees = 2.4,
		Range = 130,
		FireRate = 0.085,
		Automatic = true,
		Ammo = 32,
		ReloadTime = 1.6,
		Color = Color3.fromRGB(78, 84, 78),
		Size = Vector3.new(0.5, 0.9, 2.1),
	},
	Sword = {
		DisplayName = "SWORD",
		Kind = "Melee",
		Damage = 34,
		Pellets = 1,
		SpreadDegrees = 0,
		Range = 9,
		FireRate = 0.6,
		Automatic = false,
		Ammo = -1,
		ReloadTime = 0,
		Color = Color3.fromRGB(196, 200, 210),
		Size = Vector3.new(0.2, 0.4, 3.2),
	},
}

--! Everything that can appear in a crate.
Weapons.CratePool = { "Pistol", "RapidPistol", "Shotgun", "SawnOff", "Rifle", "SMG", "Sword" }

function Weapons.get(weaponId: string)
	return Weapons.Profiles[weaponId]
end

function Weapons.exists(weaponId: string): boolean
	return Weapons.Profiles[weaponId] ~= nil
end

function Weapons.isMelee(profile): boolean
	return profile ~= nil and profile.Kind == "Melee"
end

--! Builds the Tool instance for a profile. Server only: clients never create weapons.
function Weapons.buildTool(weaponId: string): Tool?
	local profile = Weapons.Profiles[weaponId]
	if not profile or not RunService:IsServer() then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = profile.DisplayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = profile.DisplayName
	tool:SetAttribute("WeaponId", weaponId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = profile.Size
	handle.Color = profile.Color
	handle.Material = Enum.Material.Metal
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- A cheap muzzle marker so the server can derive a fire origin without guessing.
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0, -profile.Size.Z / 2)
	muzzle.Parent = handle

	tool:SetAttribute("Ammo", profile.Ammo)
	tool:SetAttribute("Magazine", profile.Ammo)

	return tool
end

return Weapons
