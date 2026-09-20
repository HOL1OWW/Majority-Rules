--!nonstrict
--[[
	AudioService — the `ctx.Audio` capability.

	Audio is the single biggest "feel" upgrade available to this game (the transform needs a
	riser and a slam, each modifier family needs its own music bed), but no asset ids exist
	yet. So this service is deliberately a safe, honest shell:

	  * calls never error, so a modifier can ask for a bed that does not exist yet,
	  * every request is recorded on a replicated attribute so the client audio controller can
	    pick it up the moment real ids land,
	  * the brand track owns the actual sound list (docs/05-BRAND.md).

	When ids arrive, only this file and the client audio controller change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local AudioService = {}

--! Authored by the brand track. Empty string means "not yet authored" and is a no-op.
AudioService.Beds = {
	Default = "",
	Vote = "",
	Tension = "",
	Chaos = "",
}

AudioService.Cues = {
	Stamp = "",
	Tally = "",
	Rumble = "",
	Gavel = "",
}

function AudioService.SetMusicBed(bedId: string)
	if AudioService.Beds[bedId] == nil then
		Log.debug("AudioService: unknown bed '%s'", bedId)
		return
	end
	ReplicatedStorage:SetAttribute("MRMusicBed", bedId)
end

function AudioService.PlayCue(cueId: string)
	if AudioService.Cues[cueId] == nil then
		Log.debug("AudioService: unknown cue '%s'", cueId)
		return
	end
	ReplicatedStorage:SetAttribute("MRAudioCue", cueId)
end

return AudioService
