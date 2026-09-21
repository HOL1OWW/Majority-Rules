--!nonstrict
--[[
	MatchmakingService — how a server decides what kind of match it is running.

	A brand new Roblox experience does not get 8-player servers. It gets one player at 2am.
	This service exists so that fact is a design decision made in one place rather than a bug
	discovered in analytics:

	  * 1-3 players  -> Skirmish, 3 rounds, starts immediately (a lone player's arena still
	                    transforms within 60 seconds of joining, which is the signal Roblox
	                    ranks most heavily)
	  * 4+ players   -> Full, 6 rounds, the real game

	It is also where party/teleport logic will live when "play with friends" is built, because
	co-play days are a ranked discovery signal and the 8-player format is naturally social.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Escalation = require(Shared.Config.Escalation)

local MatchmakingService = {}

function MatchmakingService.formatForPlayerCount(playerCount: number): string
	return Escalation.formatForPlayerCount(playerCount)
end

function MatchmakingService.describe(playerCount: number)
	local formatId = MatchmakingService.formatForPlayerCount(playerCount)
	local format = Escalation.Formats[formatId]
	return {
		Id = formatId,
		DisplayName = format.DisplayName,
		Rounds = #format.Rounds,
		PlayerCount = playerCount,
	}
end

--! True when a server has enough players for the full format but is currently in a Skirmish:
--! used to decide whether to end early rather than drag a small match out.
function MatchmakingService.shouldUpgrade(playerCount: number, currentFormat: string): boolean
	return currentFormat == "Skirmish" and playerCount >= Escalation.Formats.Full.MinPlayers
end

return MatchmakingService
