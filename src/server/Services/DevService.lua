--!nonstrict
--[[
	DevService — Studio-only overrides so a full match can be tested in seconds.

	Set attributes on `ServerStorage.DevConfig` (create the folder in Studio, no repo change
	needed) and this service exposes them to the round loop:

		ForceModifiers   string  comma separated ids applied without a vote, e.g. "Fog,IceFloor"
		SkipVote         bool    skip the vote entirely (pair with ForceModifiers)
		RoundSeconds     number  override the round length
		VoteSeconds      number  override the vote timer
		TotalRounds      number  shorten a match to N rounds
		ArenaId          string  force a specific arena
		StartingRound    number  start the match at round N (to test high-tier chaos fast)

	Outside Studio every override is ignored, so this can never affect a live server.
]]

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local DevService = {}

local function config(): Instance?
	return ServerStorage:FindFirstChild("DevConfig")
end

function DevService.active(): boolean
	return RunService:IsStudio() and config() ~= nil
end

function DevService.get(name: string, default: any): any
	if not DevService.active() then
		return default
	end
	local value = (config() :: Instance):GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

function DevService.forcedModifiers(): { string }?
	local raw = DevService.get("ForceModifiers", nil)
	if type(raw) ~= "string" or #raw == 0 then
		return nil
	end
	local out = {}
	for token in string.gmatch(raw, "[^,]+") do
		local trimmed = string.match(token, "^%s*(.-)%s*$")
		if trimmed and #trimmed > 0 then
			table.insert(out, trimmed)
		end
	end
	if #out == 0 then
		return nil
	end
	Log.info("DevService: forcing modifiers %s", table.concat(out, ", "))
	return out
end

return DevService
