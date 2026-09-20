--!nonstrict
--[[
	Net.lua — every remote in the game, declared in one place.

	Rules: all gameplay is server-authoritative; every remote is rate limited; vote
	submissions are deduped server-side so a player can only ever cast one vote per round.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Log = require(script.Parent.Util.Log)

local Net = {}

Net.FolderName = "MRRemotes"

Net.Events = {
	-- client -> server
	VoteCast = "VoteCast", -- (modifierId: string)
	Objection = "Objection", -- ()  trailing player injects a wildcard candidate
	WeaponFire = "WeaponFire", -- (tool: Instance, origin: Vector3, direction: Vector3)

	-- server -> client
	RoundState = "RoundState", -- ({ State, Round, Total, EndsAt, ... })
	VoteState = "VoteState", -- ({ Candidates, Tallies, Voters, EndsAt, Locked })
	RoundResult = "RoundResult", -- ({ RoundWinner, Eliminations, Points, Modifiers })
	MatchResult = "MatchResult", -- ({ Winner, Points })
	WeaponTracer = "WeaponTracer", -- (shooter, from, to, didHit) cosmetic only
	TransformFx = "TransformFx", -- ({ ModifierIds, Duration, ... }) drives the cinematic
	Notify = "Notify", -- ({ Text, Kind })
}

Net.Functions = {
	RoundInfo = "RoundInfo", -- () -> current round snapshot for late joiners
}

local cache: { [string]: Instance } = {}

local function folder(): Instance
	local existing = cache.folder
	if existing and existing.Parent then
		return existing
	end

	if RunService:IsServer() then
		local found = ReplicatedStorage:FindFirstChild(Net.FolderName)
		if not found then
			found = Instance.new("Folder")
			found.Name = Net.FolderName
			found.Parent = ReplicatedStorage
		end
		cache.folder = found
		return found
	end

	local found = ReplicatedStorage:WaitForChild(Net.FolderName, 30)
	if not found then
		error("[Net] Remotes folder never replicated")
	end
	cache.folder = found
	return found
end

local function get(className: string, name: string): Instance
	local key = className .. ":" .. name
	local existing = cache[key]
	if existing and existing.Parent then
		return existing
	end

	local parent = folder()
	local instance
	if RunService:IsServer() then
		instance = parent:FindFirstChild(name)
		if not instance then
			instance = Instance.new(className)
			instance.Name = name
			instance.Parent = parent
		end
	else
		instance = parent:WaitForChild(name, 30)
		if not instance then
			error("[Net] Remote " .. name .. " never replicated")
		end
	end

	cache[key] = instance
	return instance
end

function Net.event(name: string): RemoteEvent
	return get("RemoteEvent", name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return get("RemoteFunction", name) :: RemoteFunction
end

--! Server-side rate limiter. Returns true when the caller is allowed to act.
function Net.rateLimit(bucket: { [Player]: number }, player: Player, minInterval: number): boolean
	local now = os.clock()
	local last = bucket[player]
	if last and now - last < minInterval then
		return false
	end
	bucket[player] = now
	return true
end

--! Convenience: fire an event to every player, or to one.
function Net.broadcast(name: string, ...: any)
	Net.event(name):FireAllClients(...)
end

function Net.send(player: Player, name: string, ...: any)
	local remote = Net.event(name)
	if player.Parent then
		remote:FireClient(player, ...)
	end
end

function Net.trySend(player: Player, name: string, ...: any)
	local ok, err = pcall(Net.send, player, name, ...)
	if not ok then
		Log.warn("Net.send failed for %s: %s", player.Name, tostring(err))
	end
end

return Net
