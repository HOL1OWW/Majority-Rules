--!nonstrict
--[[
	AnalyticsService — the numbers that decide which modifiers live.

	The most valuable question this game can answer is not "how many people played" but
	"which modifiers make people quit". So every round reports its modifier set, and the
	per-modifier quit rate is derived from the round a player left in.

	Roblox's analytics calls take a Player and are best-effort: they must never be able to
	break a round, hence the pcall wrappers.
]]

local Players = game:GetService("Players")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local AnalyticsService = {}

AnalyticsService.enabled = true

local function safe(fn)
	if not AnalyticsService.enabled then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		Log.debug("Analytics call failed: %s", tostring(err))
	end
end

--! Custom event for one player. Names are prefixed so they group in the dashboard.
function AnalyticsService.event(player: Player, name: string, value: number?)
	safe(function()
		RobloxAnalytics:LogCustomEvent(player, "MR_" .. name, value or 1)
	end)
end

function AnalyticsService.broadcast(name: string, value: number?)
	for _, player in Players:GetPlayers() do
		AnalyticsService.event(player, name, value)
	end
end

function AnalyticsService.roundState(state: string)
	AnalyticsService.broadcast("RoundState_" .. state)
end

--! The single most important event in the game: which modifiers a round actually ran with.
function AnalyticsService.roundModifiers(round: number, modifierIds: { string }, elapsed: number)
	AnalyticsService.broadcast("RoundModifiers", #modifierIds)
	for _, player in Players:GetPlayers() do
		AnalyticsService.event(player, "Round_" .. round .. "_" .. table.concat(modifierIds, "_"), elapsed)
	end
end

function AnalyticsService.voteCast(player: Player, modifierId: string)
	AnalyticsService.event(player, "Vote_" .. modifierId)
end

function AnalyticsService.voteResult(player: Player, won: boolean)
	AnalyticsService.event(player, won and "VoteWon" or "VoteLost")
end

function AnalyticsService.roundCompleted(player: Player, won: boolean, points: number)
	AnalyticsService.event(player, won and "RoundWon" or "RoundLost", points)
end

function AnalyticsService.matchCompleted(player: Player, rank: number, points: number)
	AnalyticsService.event(player, "MatchCompleted", points)
	AnalyticsService.event(player, "MatchRank_" .. tostring(rank))
end

function AnalyticsService.economy(player: Player, eventName: string, amount: number, source: string)
	safe(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Clout",
			amount,
			"Clout_Ending",
			eventName,
			Enum.AnalyticsEconomyTransactionType.Gameplay,
			source
		)
	end)
end

return AnalyticsService
