--!nonstrict
--[[
	GameplayService — the player-facing half of the modifier capability surface (`ctx.Gameplay`).

	Modifiers never touch a Humanoid. They describe the *rule* ("everyone walks at 23", "everyone
	has 45 health") and this service is the one place that knows how to push that rule onto a
	character, now and at every future respawn.

	That distinction matters for a stacking modifier game: a modifier applies to players who
	join midway through a round, respawn after the vote, or spawn three seconds after the
	transform finished. All of those paths funnel through `applyBaseline`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Log = require(Shared.Util.Log)
local MatchState = require(script.Parent.MatchState)

local GameplayService = {}

--! Round-wide baseline. Modifiers write here through SetWalkSpeed / SetMaxHealth / etc.
local baseline = {
	WalkSpeed = Combat.WalkSpeed,
	JumpPower = Combat.JumpPower,
	JumpEnabled = true,
	MaxHealth = Combat.Health,
	FrictionScale = 1,
}

--! Per-player overrides (a modifier may target one player, e.g. a future Juggernaut).
local overrides = {}

local function defaults()
	return {
		WalkSpeed = Combat.WalkSpeed,
		JumpPower = Combat.JumpPower,
		JumpEnabled = true,
		MaxHealth = Combat.Health,
		FrictionScale = 1,
	}
end

function GameplayService.reset()
	baseline = defaults()
	table.clear(overrides)
	MatchState.resetRoundFlags()
end

function GameplayService.baseline()
	return baseline
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function resolve(player: Player?)
	if player and overrides[player] then
		return overrides[player]
	end
	return baseline
end

local function applyJump(humanoid: Humanoid, settings)
	pcall(function()
		humanoid.UseJumpPower = true
		humanoid.JumpPower = settings.JumpEnabled and settings.JumpPower or 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, settings.JumpEnabled)
	end)
end

--! The rules themselves, applied to any character. Split out because a bot character has to obey
--! the same round rules as a player's and has no Player to resolve settings against.
local function applySettings(character_: Model, settings)
	local humanoid = character_:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = settings.WalkSpeed
	applyJump(humanoid, settings)

	humanoid.MaxHealth = settings.MaxHealth
	if humanoid.Health > settings.MaxHealth then
		humanoid.Health = settings.MaxHealth
	end

	if settings.FrictionScale ~= 1 then
		for _, descendant in character_:GetDescendants() do
			if descendant:IsA("BasePart") then
				pcall(function()
					descendant.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3 * settings.FrictionScale, 0, 1, 1)
				end)
			end
		end
	end
end

--! Push the current rules onto one character. Called on every spawn and after every transform.
function GameplayService.applyBaseline(player: Player, character: Model?)
	local character_ = character or player.Character
	if not character_ then
		return
	end
	applySettings(character_, resolve(player))
end

--! The same rules for a bot: it has no Player, so it follows the round baseline — which means
--! "everyone walks at 23" from a modifier applies to the bots too.
function GameplayService.applyToBot(character: Model)
	applySettings(character, baseline)
end

function GameplayService.applyAll()
	for _, player in Players:GetPlayers() do
		if player.Character then
			GameplayService.applyBaseline(player)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Capabilities
-- ---------------------------------------------------------------------------------------

function GameplayService.SetWalkSpeed(speed: number, player: Player?)
	if player then
		overrides[player] = overrides[player] or defaults()
		overrides[player].WalkSpeed = speed
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.WalkSpeed = speed
		end
		return
	end

	baseline.WalkSpeed = speed
	for _, other in Players:GetPlayers() do
		if not overrides[other] then
			local humanoid = humanoidOf(other)
			if humanoid then
				humanoid.WalkSpeed = speed
			end
		end
	end
end

function GameplayService.SetJumpPower(power: number, player: Player?)
	if player then
		overrides[player] = overrides[player] or defaults()
		overrides[player].JumpPower = power
		overrides[player].JumpEnabled = true
		local humanoid = humanoidOf(player)
		if humanoid then
			applyJump(humanoid, overrides[player])
		end
		return
	end

	baseline.JumpPower = power
	baseline.JumpEnabled = true
	for _, other in Players:GetPlayers() do
		if not overrides[other] then
			local humanoid = humanoidOf(other)
			if humanoid then
				applyJump(humanoid, baseline)
			end
		end
	end
end

function GameplayService.SetJumpEnabled(enabled: boolean, player: Player?)
	if player then
		overrides[player] = overrides[player] or defaults()
		overrides[player].JumpEnabled = enabled
		local humanoid = humanoidOf(player)
		if humanoid then
			applyJump(humanoid, overrides[player])
		end
		return
	end

	baseline.JumpEnabled = enabled
	for _, other in Players:GetPlayers() do
		if not overrides[other] then
			local humanoid = humanoidOf(other)
			if humanoid then
				applyJump(humanoid, baseline)
			end
		end
	end
end

function GameplayService.SetMaxHealth(health: number, player: Player?)
	if player then
		overrides[player] = overrides[player] or defaults()
		overrides[player].MaxHealth = health
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.MaxHealth = health
			humanoid.Health = math.min(humanoid.Health, health)
		end
		return
	end

	baseline.MaxHealth = health
	for _, other in Players:GetPlayers() do
		if not overrides[other] then
			local humanoid = humanoidOf(other)
			if humanoid then
				humanoid.MaxHealth = health
				humanoid.Health = math.min(humanoid.Health, health)
			end
		end
	end
end

function GameplayService.SetFrictionScale(scale: number)
	baseline.FrictionScale = scale
	GameplayService.applyAll()
end

--! Round flags are read by CombatService. This is how a modifier says "infinite ammo" or
--! "bullets ricochet" without owning any combat code.
function GameplayService.Flag(name: string, value: any)
	MatchState.setFlag(name, value)
end

function GameplayService.SetLifesteal(fraction: number)
	MatchState.setFlag("Lifesteal", fraction)
end

function GameplayService.Heal(player: Player, amount: number)
	local humanoid = humanoidOf(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

function GameplayService.Damage(player: Player, amount: number, reason: string?)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
	if reason then
		Log.debug("Damage to %s: %.1f (%s)", player.Name, amount, reason)
	end
end

--! Loadout rules live in CombatService; this forwards so modifiers have one place to call.
function GameplayService.SetDefaultLoadout(weaponIds: { string })
	local CombatService = require(script.Parent.CombatService)
	CombatService.SetDefaultLoadout(weaponIds)
end

function GameplayService.ForceLoadout(player: Player, weaponIds: { string })
	local CombatService = require(script.Parent.CombatService)
	CombatService.ApplyLoadout(player, weaponIds)
end

function GameplayService.GrantWeapon(player: Player, weaponId: string)
	local CombatService = require(script.Parent.CombatService)
	return CombatService.GrantWeapon(player, weaponId)
end

return GameplayService
