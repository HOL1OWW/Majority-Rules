--!nonstrict
--[[
	Escalation.lua — the ramp.

	Round 1 is one gentle twist. Round 6 is three stacked chaos modifiers announced as
	THE VERDICT. This table is the single place that decides how fast the game gets loud.

	Two formats exist because a brand new experience has small servers:

	  Full     8+ players  — 6 rounds, full escalation, this is the real game
	  Skirmish 1-3 players — 3 rounds, starts immediately, exists so that a solo player's
	                         arena still transforms inside 60 seconds of joining
	                         (first-play bounce is the dominant discovery signal)

	Never make a player wait for a lobby to fill before their first transformation.
]]

local Escalation = {}

-- Timings (seconds)
Escalation.VoteSeconds = { Full = 20, Skirmish = 12 }
Escalation.LockSeconds = 2 -- "pens down" beat after voting closes
Escalation.RevealSeconds = 2.5 -- winner announcement before the transform starts
Escalation.CountdownSeconds = 3
Escalation.TransformCeiling = 4.5 -- hard cap on a transform; a broken step can never hang a round
Escalation.RoundEndSeconds = 8
Escalation.MatchEndSeconds = 15
Escalation.TieBreakSeconds = 5 -- sudden-death revote between tied candidates
Escalation.FreezeLeadIn = 0.35 -- players are frozen slightly before the transform begins

--! Format selection. Thresholds are deliberately generous: a 4-player server still gets
--! the full experience because the game is fun at 4, but a lone player never waits.
Escalation.Formats = {
	Skirmish = {
		Id = "Skirmish",
		DisplayName = "HOUSE DECREE",
		MinPlayers = 0,
		Rounds = {
			{ Cands = 2, MaxStacked = 1, Tiers = { 1 }, Length = 60, Label = "HOUSE DECREE" },
			{
				Cands = 3,
				MaxStacked = 2,
				Tiers = { 1, 2 },
				Length = 55,
				Label = "SECOND READING",
				Gamble = true,
			},
			{
				Cands = 3,
				MaxStacked = 2,
				Tiers = { 1, 2 },
				Length = 50,
				Label = "THE VERDICT",
				Gamble = true,
				Cinematic = true,
			},
		},
	},

	Full = {
		Id = "Full",
		DisplayName = "FULL SESSION",
		MinPlayers = 4,
		Rounds = {
			{ Cands = 3, MaxStacked = 1, Tiers = { 1 }, Length = 75, Label = "WARM UP" },
			{ Cands = 3, MaxStacked = 1, Tiers = { 1, 2 }, Length = 70, Label = "FIRST READING" },
			{
				Cands = 3,
				MaxStacked = 2,
				Tiers = { 1, 2 },
				Length = 65,
				Label = "SECOND READING",
				Gamble = true,
			},
			{
				Cands = 4,
				MaxStacked = 2,
				Tiers = { 1, 2, 3 },
				Length = 60,
				Label = "POINT OF ORDER",
				Gamble = true,
				GuaranteeTier = 3,
			},
			{
				Cands = 4,
				MaxStacked = 3,
				Tiers = { 1, 2, 3 },
				Length = 55,
				Label = "THE FLOOR",
				Gamble = true,
				GuaranteeTier = 3,
			},
			{
				Cands = 4,
				MaxStacked = 3,
				Tiers = { 1, 2, 3 },
				Length = 50,
				Label = "THE VERDICT",
				Gamble = true,
				GuaranteeTier = 3,
				Cinematic = true,
			},
		},
	},
}

function Escalation.formatForPlayerCount(playerCount: number): string
	if playerCount < Escalation.Formats.Full.MinPlayers then
		return "Skirmish"
	end
	return "Full"
end

function Escalation.totalRounds(formatId: string): number
	local format = Escalation.Formats[formatId] or Escalation.Formats.Full
	return #format.Rounds
end

function Escalation.forRound(formatId: string, roundNumber: number)
	local format = Escalation.Formats[formatId] or Escalation.Formats.Full
	local entry = format.Rounds[math.clamp(roundNumber, 1, #format.Rounds)]
	return entry, format
end

function Escalation.voteSeconds(formatId: string): number
	return Escalation.VoteSeconds[formatId] or Escalation.VoteSeconds.Full
end

return Escalation
