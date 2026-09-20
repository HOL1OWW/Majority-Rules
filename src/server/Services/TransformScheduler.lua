--!nonstrict
--[[
	TransformScheduler — one timeline for every active modifier.

	The problem this solves: if three voted modifiers each start their own tweens, they race
	each other, two of them fight over the same property, and a player can fall through a floor
	that is halfway between two shapes.

	The solution: every modifier describes its changes as declarative steps. The scheduler:

	  1. sorts steps into phases — Before (visuals start) -> Commit (gameplay values) ->
	     After (follow-up),
	  2. within a phase, sorts by priority then modifier id, which is deterministic,
	  3. lets exactly ONE step claim each channel+phase (the highest priority), logging any
	     conflicts rather than letting them silently fight,
	  4. runs a whole phase's steps synchronously and then awaits their tweens together,
	     bounded by a hard budget so a broken modifier cannot hang a round.

	Commit is the frame where gameplay actually changes. It happens after the geometry has
	started moving and before anything else can observe an inconsistent world.
]]

local Log = require(game:GetService("ReplicatedStorage").Shared.Util.Log)
local Tweens = require(game:GetService("ReplicatedStorage").Shared.Util.Tween)

local TransformScheduler = {}

local PHASES = { "Before", "Commit", "After" }

-- `typeof` reports the datatype, not the class name: typeof(aTween) is "Instance", never "Tween".
-- A tween has to be recognised with IsA. Testing `typeof(x) == "Tween"` is always false, which
-- collected nothing at all and let every phase continue before its geometry had stopped moving —
-- the exact inconsistency the phases above exist to prevent.
local function isTween(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Tween")
end

local function collectTween(result: any, into: { Tween })
	if result == nil then
		return
	end
	if isTween(result) then
		table.insert(into, result)
		return
	end
	if type(result) == "table" then
		for _, item in result do
			if isTween(item) then
				table.insert(into, item)
			end
		end
	end
end

--! collected: { { ModifierId: string, Step: TransformStep } }
--! Returns a report other systems (and the analytics pipeline) can act on.
function TransformScheduler.run(ctx, collected, budget: number?)
	local ceiling = budget or 8

	local byPhase = { Before = {}, Commit = {}, After = {} }
	for _, entry in collected do
		local phase = entry.Step.Phase or "Before"
		if not byPhase[phase] then
			Log.warn("TransformScheduler: unknown phase '%s' from %s", tostring(phase), entry.ModifierId)
			phase = "Before"
		end
		table.insert(byPhase[phase], entry)
	end

	local claimed = {}
	local conflicts = {}
	local failures = {}
	local executed = {}

	for _, phase in PHASES do
		local entries = byPhase[phase]
		table.sort(entries, function(a, b)
			local left = a.Step.Priority or 0
			local right = b.Step.Priority or 0
			if left ~= right then
				return left > right
			end
			return a.ModifierId < b.ModifierId
		end)

		local tweens = {}
		for _, entry in entries do
			local channel = entry.Step.Channel or "misc"
			local key = phase .. "/" .. channel
			local owner = claimed[key]

			if owner then
				table.insert(conflicts, {
					Channel = channel,
					Phase = phase,
					Winner = owner,
					Loser = entry.ModifierId,
					Label = entry.Step.Label,
				})
			else
				claimed[key] = entry.ModifierId
				table.insert(executed, { ModifierId = entry.ModifierId, Channel = channel, Phase = phase })

				local ok, result = pcall(entry.Step.Run, ctx)
				if not ok then
					table.insert(failures, { ModifierId = entry.ModifierId, Error = tostring(result) })
					Log.warn("Transform step failed for %s: %s", entry.ModifierId, tostring(result))
				else
					collectTween(result, tweens)
				end
			end
		end

		Tweens.await(tweens, math.max(ceiling / 2, 2))
	end

	for _, conflict in conflicts do
		Log.info(
			"Transform conflict on %s/%s: %s kept, %s skipped",
			conflict.Phase,
			conflict.Channel,
			conflict.Winner,
			conflict.Loser
		)
	end

	return {
		executed = executed,
		conflicts = conflicts,
		failures = failures,
		steps = #collected,
	}
end

return TransformScheduler
