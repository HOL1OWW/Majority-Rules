--!nonstrict
--[[
	PlayerService — spawning, despawning, freezing, and the `ctx.Players` capability.

	Respawn is manual (`Players.CharacterAutoLoads = false`) because a round is an elimination
	round: the engine decides when a character exists, never the default respawn timer. That
	also lets the transform cinematic freeze everyone on one frame and release them on another.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Log = require(Shared.Util.Log)

local ArenaService = require(script.Parent.ArenaService)
local GameplayService = require(script.Parent.GameplayService)
local MatchState = require(script.Parent.MatchState)

local PlayerService = {}

local spawnCursor = 0
local frozen = false

function PlayerService.setup()
	-- The engine decides when a character exists. `RespawnTime` is deliberately left alone:
	-- with CharacterAutoLoads off it is never consulted, and a non-finite number assigned to a
	-- float property is a needless boot risk.
	Players.CharacterAutoLoads = false
end

function PlayerService.ensure(player: Player)
	MatchState.ensurePlayer(player)
end

function PlayerService.isFrozen(): boolean
	return frozen
end

-- ---------------------------------------------------------------------------------------
-- Spawning
-- ---------------------------------------------------------------------------------------

--! Deterministic and spread out: consecutive spawns walk around the arena's spawn ring.
function PlayerService.assignSpawnPoint(player: Player): BasePart?
	local spawns = ArenaService.GetSpawnParts()
	if #spawns == 0 then
		return nil
	end
	spawnCursor += 1
	local index = ((spawnCursor - 1) % #spawns) + 1
	return spawns[index]
end

--! A non-nil `player.Character` is not the same thing as a spawned player. `despawn` destroys the
--! character model, and the engine leaves that (now empty, unparented, Humanoid-less) model attached
--! to the property, so `if player.Character then return true end` answered "already spawned" —
--! permanently, from the first despawn onwards. The player then kept a husk: no Humanoid, no loadout,
--! no spawn point, and `MatchState.Alive` never set, which is why rounds after the first reported
--! *zero* players alive. Round 1 looked healthy only because nothing had been despawned yet, and a
--! one-player test is exactly where that hides.
local function hasPlayableCharacter(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	return character.Parent ~= nil and character:FindFirstChildOfClass("Humanoid") ~= nil
end

function PlayerService.spawn(player: Player): boolean
	if not MatchState.Active or MatchState.Eliminated[player] then
		return false
	end
	if hasPlayableCharacter(player) then
		return true
	end

	local spawnPart = PlayerService.assignSpawnPoint(player)
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		Log.warn("LoadCharacter failed for %s: %s", player.Name, tostring(err))
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	if spawnPart then
		pcall(function()
			character:PivotTo(spawnPart.CFrame + Vector3.new(0, Combat.SpawnHeightOffset, 0))
		end)
	end

	GameplayService.applyBaseline(player, character)
	local CombatService = require(script.Parent.CombatService)
	CombatService.ApplyLoadout(player, CombatService.currentLoadout())
	if frozen then
		PlayerService.freezeCharacter(player, true)
	end

	MatchState.Alive[player] = true
	MatchState.Eliminated[player] = false
	MatchState.Protection[player] = os.clock() + Combat.SpawnProtectionSeconds
	return true
end

function PlayerService.despawn(player: Player)
	local character = player.Character
	if character then
		character:Destroy()
	end
	-- Drop the reference with the instance. Leaving it pointing at the destroyed husk is what made
	-- `spawn` believe the player was still spawned (see `hasPlayableCharacter`).
	player.Character = nil
	MatchState.Alive[player] = false
end

function PlayerService.respawnAll()
	for _, player in Players:GetPlayers() do
		if not MatchState.Eliminated[player] then
			PlayerService.spawn(player)
		end
	end
end

function PlayerService.despawnAll()
	for _, player in Players:GetPlayers() do
		PlayerService.despawn(player)
	end
end

--! Fresh round: nobody is eliminated and nobody is alive until the countdown ends.
function PlayerService.resetRound()
	for _, player in Players:GetPlayers() do
		MatchState.ensurePlayer(player)
		MatchState.Alive[player] = false
		MatchState.Eliminated[player] = false
		MatchState.Protection[player] = nil
	end
	spawnCursor = 0
end

-- ---------------------------------------------------------------------------------------
-- Freezing (the transform cinematic)
-- ---------------------------------------------------------------------------------------

function PlayerService.freezeCharacter(player: Player, value: boolean)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root then
		root.Anchored = value
	end
	if humanoid then
		if value then
			humanoid.WalkSpeed = 0
			pcall(function()
				humanoid.JumpPower = 0
			end)
		else
			GameplayService.applyBaseline(player, character)
		end
	end
end

--! Called around the transform. Collision stays on so nobody falls through a moving floor.
function PlayerService.freezeAll(value: boolean)
	frozen = value
	for _, player in Players:GetPlayers() do
		PlayerService.freezeCharacter(player, value)
	end
end

-- ---------------------------------------------------------------------------------------
-- ctx.Players capability
-- ---------------------------------------------------------------------------------------

function PlayerService.All(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		table.insert(out, player)
	end
	return out
end

function PlayerService.Alive(): { Player }
	return MatchState.alivePlayers()
end

function PlayerService.Characters(): { Model }
	local out = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(out, player.Character)
		end
	end
	return out
end

function PlayerService.ForEachCharacter(fn: (Model, Player) -> ())
	for _, player in Players:GetPlayers() do
		if player.Character then
			fn(player.Character, player)
		end
	end
end

return PlayerService
