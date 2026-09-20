--!nonstrict
--[[
	VoteService — the centrepiece.

	What the player experiences: three (sometimes four) cards, live tallies, avatar heads
	appearing on the card they chose, and a winner that physically rebuilds the arena.

	Three decisions worth knowing about:

	  1. **The top N vote-getters all apply.** `MaxStacked` from the escalation table is N. In
	     round 1 that is one modifier; by round 6 it is three. Voting for a card that comes
	     second is therefore not wasted, which is what makes a stacking round feel like a
	     negotiation instead of a plurality race.
	  2. **Ties are never resolved silently.** A tie at the cut line triggers a sudden-death
	     revote restricted to the tied cards; if that ties again, a seeded coin flip decides
	     and the UI shows it happening.
	  3. **The ballot is always well formed.** No two cards can contradict each other, because
	     any two of them might both end up applying. That filtering lives in Modifiers.draw.

	Votes can be changed until the lock, and eliminated players keep voting — the whole reason
	dying is not the end of your involvement in the round.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modifiers = require(Shared.Modifiers)
local Net = require(Shared.Net)
local Pick = require(Shared.Util.Pick)
local Log = require(Shared.Util.Log)

local MatchState = require(script.Parent.MatchState)

local VoteService = {}

local state = {
	open = false,
	locked = false,
	round = 0,
	endsAt = 0,
	startedAt = 0,
	seconds = 0,
	candidates = {},
	tallies = {},
	voters = {},
	tieBreak = nil,
	defaulted = false,
}

local queuedInjections = {} -- Objection wildcards waiting for the next ballot

-- ---------------------------------------------------------------------------------------
-- Opening
-- ---------------------------------------------------------------------------------------

local function candidateIds(candidates): { string }
	local out = {}
	for _, def in candidates do
		table.insert(out, def.Id)
	end
	return out
end

local function broadcast()
	for _, player in Players:GetPlayers() do
		Net.trySend(player, Net.Events.VoteState, VoteService.payloadFor(player))
	end
end

function VoteService.payloadFor(player: Player)
	local candidates = {}
	for _, def in state.candidates do
		local voters = {}
		for voter, id in state.voters do
			if id == def.Id then
				table.insert(voters, voter.UserId)
			end
		end
		table.insert(candidates, {
			Id = def.Id,
			DisplayName = def.DisplayName,
			Blurb = def.Blurb,
			Tier = def.Tier,
			Tags = def.Tags,
			IsGamble = def.IsGamble == true,
			Tally = state.tallies[def.Id] or 0,
			Voters = voters,
		})
	end

	return {
		Round = state.round,
		Open = state.open,
		Locked = state.locked,
		StartedAt = state.startedAt,
		EndsAt = state.endsAt,
		ServerNow = Workspace:GetServerTimeNow(),
		TieBreak = state.tieBreak,
		Candidates = candidates,
		YourVote = player and state.voters[player] or nil,
		VoterCount = #Players:GetPlayers(),
		Defaulted = state.defaulted,
	}
end

--! opts = { Round, Count, Tiers, Features, Chosen, Banned, GuaranteeTier, MaxStacked, Gamble,
--!          Rng, Seconds, TieBreak }
--! `TieBreak` (an array of ids) re-opens the ballot restricted to those cards.
function VoteService.open(opts)
	state.open = true
	state.locked = false
	state.defaulted = false
	state.round = opts.Round or 0
	state.seconds = opts.Seconds or 20
	state.startedAt = Workspace:GetServerTimeNow()
	state.endsAt = state.startedAt + state.seconds
	state.voters = {}
	state.tieBreak = opts.TieBreak

	local rng = opts.Rng or Random.new()

	if opts.TieBreak then
		local restricted = {}
		for _, id in opts.TieBreak do
			local def = Modifiers.get(id)
			if def then
				table.insert(restricted, def)
			end
		end
		state.candidates = restricted
	else
		local candidates = Modifiers.draw({
			Count = opts.Count or 3,
			Tiers = opts.Tiers or { 1, 2, 3 },
			Round = opts.Round,
			Features = opts.Features or {},
			Chosen = opts.Chosen or {},
			Banned = opts.Banned or {},
			GuaranteeTier = opts.GuaranteeTier,
			MaxStacked = opts.MaxStacked or 1,
		}, rng)

		for _, def in queuedInjections do
			local already = false
			for _, existing in candidates do
				if existing.Id == def.Id then
					already = true
					break
				end
			end
			if not already then
				table.insert(candidates, def)
			end
		end
		table.clear(queuedInjections)

		if opts.Gamble and #candidates < 4 then
			table.insert(candidates, Modifiers.Gamble)
		end

		state.candidates = candidates
	end

	state.tallies = {}
	for _, def in state.candidates do
		state.tallies[def.Id] = 0
	end

	broadcast()
	Log.info("Ballot open (round %d): %s", state.round, table.concat(candidateIds(state.candidates), ", "))
	return state.candidates
end

function VoteService.isOpen(): boolean
	return state.open and not state.locked
end

function VoteService.secondsRemaining(): number
	return math.max(0, state.endsAt - Workspace:GetServerTimeNow())
end

-- ---------------------------------------------------------------------------------------
-- Voting
-- ---------------------------------------------------------------------------------------

--! One vote per player, changeable until the lock. Server-side only, deduped by player key.
function VoteService.cast(player: Player, modifierId: any): boolean
	if not VoteService.isOpen() then
		return false
	end
	if typeof(modifierId) ~= "string" or #modifierId > 40 then
		return false
	end

	local known = false
	for _, def in state.candidates do
		if def.Id == modifierId then
			known = true
			break
		end
	end
	if not known then
		return false
	end

	state.voters[player] = modifierId
	state.tallies = {}
	for _, def in state.candidates do
		state.tallies[def.Id] = 0
	end
	for _voter, id in state.voters do
		if state.tallies[id] ~= nil then
			state.tallies[id] += 1
		end
	end

	broadcast()
	return true
end

function VoteService.voterCount(): number
	local count = 0
	for _ in state.voters do
		count += 1
	end
	return count
end

function VoteService.everyoneVoted(): boolean
	local total = #Players:GetPlayers()
	if total == 0 then
		return false
	end
	return VoteService.voterCount() >= total
end

function VoteService.lock()
	state.locked = true
	broadcast()
end

function VoteService.close()
	state.open = false
	state.locked = true
	broadcast()
end

--! Queues a wildcard injection for the next ballot (the trailing player's Objection).
function VoteService.queueInjection(modifierId: string): boolean
	local def = Modifiers.get(modifierId)
	if not def then
		return false
	end
	for _, existing in queuedInjections do
		if existing.Id == def.Id then
			return false
		end
	end
	table.insert(queuedInjections, def)
	return true
end

--! The trailing player may force one extra card onto the next ballot, once per match.
function VoteService.objection(player: Player): boolean
	if not MatchState.Active then
		return false
	end
	if MatchState.ObjectionUsed[player] then
		return false
	end

	local ranked = MatchState.rankedPlayers()
	if #ranked < 2 or ranked[#ranked] ~= player then
		return false
	end

	local pool = Modifiers.candidatePool({
		Tiers = { 1, 2, 3 },
		Features = MatchState.ArenaFeatures or {},
		Round = MatchState.Round,
	})
	if #pool == 0 then
		return false
	end

	local def = Pick.weighted(pool, function(item)
		return item.Weight
	end, Random.new(os.clock() * 1000 % 2147483647))
	if not def or not VoteService.queueInjection(def.Id) then
		return false
	end

	MatchState.ObjectionUsed[player] = MatchState.Round
	Net.broadcast(Net.Events.Notify, { Text = "OBJECTION: " .. def.DisplayName, Kind = "objection" })
	return true
end

-- ---------------------------------------------------------------------------------------
-- Resolving
-- ---------------------------------------------------------------------------------------

--! Ranking for the ballot. `maxStacked` is how many of the top finishers apply.
--! When `allowTieBreak` is true a tie at the cut line is returned instead of resolved, so
--! RoundService can run the sudden-death revote. Otherwise ties are broken by seeded
--! randomness, on stream, which is the honest version of a coin flip.
function VoteService.resolve(maxStacked: number, rng: Random, allowTieBreak: boolean)
	local ranking = {}
	for _, def in state.candidates do
		table.insert(ranking, { Id = def.Id, Count = state.tallies[def.Id] or 0 })
	end
	table.sort(ranking, function(a, b)
		if a.Count ~= b.Count then
			return a.Count > b.Count
		end
		return a.Id < b.Id
	end)

	local totalVotes = 0
	for _, entry in ranking do
		totalVotes += entry.Count
	end

	--! A tie only *matters* when more cards are tied at the cut line than there are slots.
	--! Three cards tied for three slots is not a tie, it is a unanimous ballot.
	local tieBreak = nil
	if totalVotes > 0 and #ranking > maxStacked then
		local cutCount = ranking[maxStacked].Count
		local tied = {}
		for _, entry in ranking do
			if entry.Count == cutCount then
				table.insert(tied, entry.Id)
			end
		end
		if #tied > maxStacked then
			tieBreak = tied
		end
	end

	if tieBreak and not allowTieBreak then
		-- Sudden death has already failed once. Break it with the match seed, visibly and
		-- without falsifying the tally: the chosen card simply moves to the front.
		local chosen = tieBreak[rng:NextInteger(1, #tieBreak)]
		local reordered = {}
		for _, entry in ranking do
			if entry.Id == chosen then
				table.insert(reordered, 1, entry)
			else
				table.insert(reordered, entry)
			end
		end
		ranking = reordered
		tieBreak = nil
	end

	local winners = {}
	local houseDecided = totalVotes == 0
	if houseDecided then
		-- Nobody voted (a solo player who never clicked). The arena must still transform.
		for index = 1, math.min(maxStacked, #ranking) do
			table.insert(winners, ranking[index].Id)
		end
		state.defaulted = true
	elseif not tieBreak then
		for index = 1, math.min(maxStacked, #ranking) do
			table.insert(winners, ranking[index].Id)
		end
	end

	local voteMap = {}
	for voter, id in state.voters do
		voteMap[voter] = id
	end

	return {
		ranking = ranking,
		winners = winners,
		tieBreak = tieBreak,
		voteMap = voteMap,
		voted = VoteService.voterCount(),
		defaulted = houseDecided,
	}
end

--! Did this player's pick make it into the round? Used for the Oracle stat and rewards.
function VoteService.wasCorrect(player: Player, appliedIds: { string }): boolean
	local pick = state.voters[player]
	if not pick then
		return false
	end
	return table.find(appliedIds, pick) ~= nil
end

function VoteService.reset()
	state.open = false
	state.locked = false
	state.candidates = {}
	state.tallies = {}
	state.voters = {}
	state.tieBreak = nil
	state.defaulted = false
	table.clear(queuedInjections)
end

return VoteService
