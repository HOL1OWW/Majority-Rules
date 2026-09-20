--!nonstrict
--[[
	Client State — a mirror of what the server told us, and nothing else.

	The client never decides anything. Every UI in the game reads from this store and re-renders
	when it changes, which means "why does my UI say the wrong thing" has exactly one answer:
	the server said something different.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local State = {}

State.round = {
	State = "Idle",
	Round = 0,
	Total = 0,
	Label = "MAJORITY RULES",
	Format = "Full",
	Alive = 0,
	PlayerCount = 0,
	Points = {},
	Names = {},
	Modifiers = {},
	Flags = {},
	EndsAt = nil,
	ServerNow = 0,
}

State.vote = nil
State.transform = nil
State.lastResult = nil
State.matchResult = nil
State.eliminated = false

State.Signals = {
	Round = Signal.new(),
	Vote = Signal.new(),
	Transform = Signal.new(),
	Result = Signal.new(),
	MatchResult = Signal.new(),
	Notify = Signal.new(),
}

function State.setRound(payload)
	--! Timers are interpolated locally between server updates using the synced server clock.
	payload.FetchedAt = os.clock()
	State.round = payload
	local localPlayer = game:GetService("Players").LocalPlayer
	if localPlayer then
		local myPoints = payload.Points and payload.Points[tostring(localPlayer.UserId)]
		State.myPoints = myPoints or 0
	end
	State.Signals.Round:Fire(payload)
end

function State.setVote(payload)
	State.vote = payload
	State.Signals.Vote:Fire(payload)
end

function State.setTransform(payload)
	State.transform = payload
	State.Signals.Transform:Fire(payload)
end

function State.setResult(payload)
	State.lastResult = payload
	State.Signals.Result:Fire(payload)
end

function State.setMatchResult(payload)
	State.matchResult = payload
	State.Signals.MatchResult:Fire(payload)
end

function State.notify(payload)
	State.Signals.Notify:Fire(payload)
end

--! Seconds left on whatever timed state we are in, from the synced server clock.
function State.secondsRemaining(): number
	local deadline = State.round.EndsAt
	if not deadline or deadline == 0 then
		return 0
	end
	local elapsedSince = os.clock() - State.round.FetchedAt
	local remaining = deadline - (State.round.ServerNow + elapsedSince)
	return math.max(0, remaining)
end

--! Convenience for UI: sorted standings from the points map.
function State.standings()
	local PlayerList = game:GetService("Players")
	local rows = {}
	for userId, points in State.round.Points do
		local numericId = tonumber(userId) or 0
		local player = PlayerList:GetPlayerByUserId(numericId)
		table.insert(rows, {
			UserId = numericId,
			Name = (player and player.DisplayName) or State.round.Names[userId] or ("Player " .. userId),
			Points = points,
			IsLocal = player == PlayerList.LocalPlayer,
		})
	end
	table.sort(rows, function(a, b)
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		return a.Name < b.Name
	end)
	return rows
end

return State
