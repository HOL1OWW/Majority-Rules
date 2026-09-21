--!nonstrict
--[[
	LoadoutCheck — a Studio-only assertion that runs right after a transform and answers one question:
	is every player holding the weapons *this* round voted for?

	Why it exists. A loadout modifier changes the default loadout, and the round's own reversion is
	spread across three services: `LootService.reset` restores the crate pool, `GameplayService.reset`
	restores the baseline, and every modifier's `Revert` hook fires at round end. The loadout was the
	one per-round effect with nothing restoring it, so a `PistolsOnly` round handed out pistols for
	the rest of the match — measured, not theorised:

	    round 1  vote: PistolsOnly      -> Loadout=Pistol,RapidPistol
	    round 2  forced: Fog            -> Loadout=Pistol,RapidPistol   (still)

	That is invisible in play. It looks like the game working: everyone holds a gun, the round runs,
	nothing errors. Only a comparison against what the round *asked for* catches it, which is what this
	file is.

	What it cannot see. A loadout round is judged against `CombatService.currentLoadout()` — the list the
	modifier actually *set*, not the list it meant to set. If a loadout modifier's own step failed
	outright, the round's loadout is still the default and a player holding the default matches, which
	is a false pass. Closing that needs the modifier's declared list, which lives in its own local
	table and is not exposed anywhere. So read this as covering two failures and not a third: a loadout
	outliving its round (the bug it was written for), and a modifier that never reached the players.

	It is deliberately not fatal. The precedent is the tween reporting in `Util/Tween.lua`: reporting
	must never be able to break the round it is describing. A failure here prints a banner naming the
	player, what they hold, and what the round's loadout is. Set `DevConfig.StrictLoadoutCheck = true`
	to make it throw instead, which aborts the round through `RoundService`'s pcall — loud, and
	destructive, so it is opt-in.

	Only called from `RoundService` inside `RunService:IsStudio()`. It never runs in a live server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Log = require(Shared.Util.Log)

local DevService = require(script.Parent.Parent.Services.DevService)
local CombatService = require(script.Parent.Parent.Services.CombatService)

local LoadoutCheck = {}

local function sorted(ids: { string }): { string }
	local out = table.clone(ids)
	table.sort(out)
	return out
end

local function key(ids: { string }): string
	return table.concat(sorted(ids), ",")
end

--! A comma-joined attribute (or a tool list) as a sorted set, so order never causes a false failure.
local function keyOfText(text: string): string
	local ids = {}
	for token in string.gmatch(text, "[^,]+") do
		table.insert(ids, token)
	end
	return key(ids)
end

--! What this round says a player should be carrying, and whether a modifier is what said it.
local function expectedLoadout(defs): ({ string }, boolean)
	for _, def in defs do
		for _, effect in (def.Effects or {}) do
			if effect == "LoadoutOverride" then
				return CombatService.currentLoadout(), true
			end
		end
	end
	return Combat.DefaultLoadout, false
end

--! Every weapon id a player is actually holding, in the Backpack and in their hands.
local function heldBy(player: Player): { string }
	local out = {}
	local containers = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					local weaponId = child:GetAttribute("WeaponId")
					if type(weaponId) == "string" then
						table.insert(out, weaponId)
					end
				end
			end
		end
	end
	return out
end

--! Returns true when every spawned player holds the round's loadout. Loud, never fatal by default.
function LoadoutCheck.afterTransform(roundNumber: number, appliedIds: { string }, defs): boolean
	local expected, fromModifier = expectedLoadout(defs)
	local expectedKey = key(expected)

	local problems = {}
	local checked = 0

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid then
			checked += 1
			local heldKey = key(heldBy(player))
			local attributeKey = keyOfText(tostring(player:GetAttribute("Loadout")))
			if heldKey ~= expectedKey or attributeKey ~= expectedKey then
				table.insert(
					problems,
					string.format(
						"  %s holds [%s] and its Loadout attribute says [%s], but this round's loadout is [%s]",
						player.Name,
						heldKey,
						attributeKey,
						expectedKey
					)
				)
			end
		end
	end

	if #problems == 0 then
		Log.debug(
			"Loadout check: %d player(s) holding [%s] as the round intends (%s)",
			checked,
			expectedKey,
			fromModifier and "set by a loadout modifier" or "the default, since no modifier overrode it"
		)
		return true
	end

	Log.warn("=============================================================")
	Log.warn("LOADOUT CHECK FAILED - round %d, modifiers: %s", roundNumber, table.concat(appliedIds, "+"))
	Log.warn(
		"  expected [%s] (%s)",
		expectedKey,
		fromModifier and "a loadout modifier set it" or "no modifier overrode it, so it is the default"
	)
	for _, line in problems do
		Log.warn("%s", line)
	end
	Log.warn("  a weapon that outlived its round means nothing restored the default loadout at")
	Log.warn("  round start, or a loadout modifier failed to apply. See docs/DECISIONS.md D-027.")
	Log.warn("=============================================================")

	if DevService.get("StrictLoadoutCheck", false) == true then
		Log.error("Loadout check failed in strict mode, aborting the round")
	end

	return false
end

return LoadoutCheck
