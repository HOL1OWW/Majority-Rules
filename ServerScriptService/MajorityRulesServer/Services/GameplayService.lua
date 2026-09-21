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
local RunService = game:GetService("RunService")

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

--! Sprint. The client only *asks* (Net.SprintInput); this service owns the state machine: whether
--! sprint is active is decided here from server-tracked stamina, so a cheater's humanoid never
--! moves faster than the round rules allow. Stamina lives per player, survives respawns, and the
--! multiplier applies to whatever the round baseline currently is — so Sluggish sprinting is
--! still slower than a plain walk, and SpeedBoost sprinting is faster still.
local sprint = {} -- [Player] = { Requesting, Stamina, Active, Locked }
local sprintConnection: RBXScriptConnection? = nil

local function sprintDefaults()
	return { Requesting = false, Stamina = Combat.SprintStaminaMax, Active = false, Locked = false }
end

local function sprintTick(dt: number)
	for player, state in sprint do
		if not player.Parent then
			sprint[player] = nil
			continue
		end
		if state.Active then
			state.Stamina = math.max(0, state.Stamina - Combat.SprintDrainPerSecond * dt)
			if state.Stamina <= 0 then
				state.Active = false
				state.Locked = true
			end
		else
			state.Stamina = math.min(Combat.SprintStaminaMax, state.Stamina + Combat.SprintRegenPerSecond * dt)
			if state.Locked and state.Stamina >= Combat.SprintResetThreshold then
				state.Locked = false
			end
		end

		local wants = state.Requesting and not state.Locked and state.Stamina > Combat.SprintMinStamina
		if wants ~= state.Active then
			state.Active = wants
			local humanoid
			local character = player.Character
			humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				GameplayService.applyBaseline(player)
			end
		end
	end
end

--! Called once from Bootstrap, before the first spawn.
function GameplayService.setup()
	if sprintConnection then
		return
	end
	sprintConnection = RunService.Heartbeat:Connect(sprintTick)
	Players.PlayerRemoving:Connect(function(player)
		sprint[player] = nil
	end)
	Log.info("GameplayService: sprint online (%.1fx, drain %.0f/s)", Combat.SprintMultiplier, Combat.SprintDrainPerSecond)
end

--! Client asks; the state machine decides. Rate limiting is unnecessary: the payload is one
--! boolean and the handler is idempotent.
function GameplayService.requestSprint(player: Player, wants: any)
	local state = sprint[player] or sprintDefaults()
	state.Requesting = wants == true
	sprint[player] = state
end

--! Current sprint state for one player, for HUD/telemetry reads.
function GameplayService.sprintState(player: Player)
	return sprint[player]
end

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

--! The rules one player runs under right now: the round baseline (or override), plus the sprint
--! multiplier if that player's sprint state machine says they are sprinting. Returns a copy when
--! sprinting so the multiplier never leaks into the shared baseline table.
local function effectiveSettings(player: Player?)
	local settings = resolve(player)
	local state = player and sprint[player]
	if state and state.Active then
		local effective = table.clone(settings)
		effective.WalkSpeed = settings.WalkSpeed * Combat.SprintMultiplier
		return effective
	end
	return settings
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

--! Push the current rules onto one character. Called on every spawn, after every transform, and
--! whenever the sprint state machine flips. Bots never sprint as players do — BotService decides
--! their bursts itself.
function GameplayService.applyBaseline(player: Player, character: Model?)
	local character_ = character or player.Character
	if not character_ then
		return
	end
	applySettings(character_, effectiveSettings(player))
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
