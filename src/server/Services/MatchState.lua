--!nonstrict
--[[
	MatchState — the single mutable description of the match in progress.

	This module exists so that CombatService (which needs round flags to know whether ammo is
	infinite, bullets ricochet, or hits steal health) never has to require RoundService, which
	requires CombatService. One direction of dependency, no cycle.

	RoundService owns every write. Everything else treats it as read-only.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Tags = require(Shared.Tags)

local MatchState = {}

MatchState.Active = false
MatchState.Format = "Full"
MatchState.Round = 0
MatchState.TotalRounds = 0
MatchState.Seed = 0
MatchState.Label = ""
MatchState.State = "Idle" -- Idle | VoteOpen | VoteLock | Reveal | Transform | Countdown | Live | RoundEnd | MatchEnd

--! Free-form round flags that modifiers write through ctx.Gameplay:Flag().
MatchState.Flags = {}

--! [Player] = points earned this match
MatchState.Points = {}
--! [Player] = true while alive this round
MatchState.Alive = {}
--! [Player] = true once eliminated this round (they keep voting)
MatchState.Eliminated = {}
--! [Player] = os.clock() timestamp until which damage is ignored
MatchState.Protection = {}
--! [Player] = { Kills, Deaths, RoundWins }
MatchState.Stats = {}
--! [Player] = round index of their last used Objection (one per match)
MatchState.ObjectionUsed = {}
--! Winner ids of the current round, in vote order
MatchState.ActiveModifiers = {}
--! Feature tags of the arena in play, so the ballot can filter against it
MatchState.ArenaFeatures = {}

MatchState.RoundDeadline = 0

MatchState.Signals = {
	StateChanged = Signal.new(),
	PlayerDied = Signal.new(), -- (player, killer)
	RoundEnded = Signal.new(),
	MatchEnded = Signal.new(),
}

function MatchState.resetRoundFlags()
	table.clear(MatchState.Flags)
	MatchState.ActiveModifiers = {}
end

function MatchState.setArena(arena: Model?)
	MatchState.ArenaFeatures = arena and Tags.featuresOf(arena) or {}
end

function MatchState.setFlag(name: string, value: any)
	MatchState.Flags[name] = value
end

function MatchState.getFlag(name: string, default: any): any
	local value = MatchState.Flags[name]
	if value == nil then
		return default
	end
	return value
end

function MatchState.ensurePlayer(player: Player)
	if not MatchState.Points[player] then
		MatchState.Points[player] = 0
	end
	MatchState.Stats[player] = MatchState.Stats[player] or { Kills = 0, Deaths = 0, RoundWins = 0 }
	if MatchState.Alive[player] == nil then
		MatchState.Alive[player] = false
	end
	if MatchState.Eliminated[player] == nil then
		MatchState.Eliminated[player] = false
	end
	return MatchState.Stats[player]
end

function MatchState.forgetPlayer(player: Player)
	MatchState.Points[player] = nil
	MatchState.Alive[player] = nil
	MatchState.Eliminated[player] = nil
	MatchState.Protection[player] = nil
	MatchState.Stats[player] = nil
	MatchState.ObjectionUsed[player] = nil
end

function MatchState.resetMatch()
	table.clear(MatchState.Points)
	table.clear(MatchState.Alive)
	table.clear(MatchState.Eliminated)
	table.clear(MatchState.Protection)
	table.clear(MatchState.Stats)
	table.clear(MatchState.ObjectionUsed)
	MatchState.resetRoundFlags()
	MatchState.Round = 0
end

function MatchState.alivePlayers(): { Player }
	local out = {}
	for player, alive in MatchState.Alive do
		if alive and player.Parent then
			table.insert(out, player)
		end
	end
	table.sort(out, function(a, b)
		return a.UserId < b.UserId
	end)
	return out
end

function MatchState.rankedPlayers(): { Player }
	local players = {}
	for _, player in game:GetService("Players"):GetPlayers() do
		table.insert(players, player)
	end
	table.sort(players, function(a, b)
		local left = MatchState.Points[a] or 0
		local right = MatchState.Points[b] or 0
		if left ~= right then
			return left > right
		end
		return a.UserId < b.UserId
	end)
	return players
end

return MatchState
