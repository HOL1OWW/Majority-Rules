--!nonstrict
--[[
	Tween helpers used by the transform pipeline.

	A TransformStep may return a Tween. The scheduler collects every tween from a phase and
	awaits them together, bounded by a hard timeout, so one broken tween can never hang a
	round.

	(The internal table is called `Tweens` rather than `Tween` so that the return type
	annotations below refer to the Roblox `Tween` class and not to this module.)
]]

local TweenService = game:GetService("TweenService")
local Log = require(script.Parent.Log)

local Tweens = {}

--! Start a tween, or apply the values instantly when duration <= 0. Returns the Tween or nil.
function Tweens.go(instance: Instance, duration: number, properties: { [string]: any }, style: Enum.EasingStyle?): Tween?
	if duration <= 0 then
		for key, value in properties do
			(instance :: any)[key] = value
		end
		return nil
	end
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, properties)
	tween:Play()
	return tween
end

--! Start the same tween on many instances and return them all.
function Tweens.goAll(instances: { Instance }, duration: number, properties: { [string]: any }): { Tween }
	local out = {}
	for _, instance in instances do
		local tween = Tweens.go(instance, duration, properties)
		if tween then
			table.insert(out, tween)
		end
	end
	return out
end

--! Await a set of tweens with a hard ceiling. Returns true when everything finished.
function Tweens.await(tweens: { Tween }, timeout: number?): boolean
	if #tweens == 0 then
		return true
	end

	local pending = #tweens
	local connections = table.create(#tweens)
	for _, tween in tweens do
		table.insert(
			connections,
			tween.Completed:Connect(function()
				pending -= 1
			end)
		)
	end

	local deadline = os.clock() + (timeout or 10)
	while pending > 0 and os.clock() < deadline do
		task.wait(0.02)
	end

	for _, connection in connections do
		connection:Disconnect()
	end

	if pending > 0 then
		-- Name what is still running, and compare the counter against what the engine actually
		-- reports. The two can disagree: a tween that finished before its Completed connection was
		-- made never decrements `pending`, so the await burns its whole budget while nothing is
		-- playing at all. Printing both is what tells those two failures apart.
		local completed, playing, other = 0, 0, 0
		for _, tween in tweens do
			local state = tween.PlaybackState
			if state == Enum.PlaybackState.Completed then
				completed += 1
			elseif state == Enum.PlaybackState.Playing or state == Enum.PlaybackState.Delayed then
				playing += 1
			else
				other += 1
			end
		end

		Log.warn(
			"Tweens.await timed out: counter says %d of %d pending, engine reports %d completed / %d playing / %d other",
			pending,
			#tweens,
			completed,
			playing,
			other
		)

		-- Name the ones still running. Reporting must never be able to break the round it is
		-- describing, so every read happens inside a pcall and only properties that exist are touched:
		-- reading `Tween.Cancelled` (which does not exist) threw out of this function and aborted the
		-- round instead of logging anything at all.
		local listed = 0
		for _, tween in tweens do
			if listed >= 8 then
				break
			end

			local readable, state = pcall(function()
				return tween.PlaybackState
			end)
			if readable and state == Enum.PlaybackState.Completed then
				continue
			end

			local described, description = pcall(function()
				local info = tween.TweenInfo
				local instance = tween.Instance
				return string.format(
					"%s | %s | %s | tween time %.2fs",
					instance and instance:GetFullName() or "<instance gone>",
					string.gsub(tostring(state), "Enum.PlaybackState%.", ""),
					info and tostring(info.EasingStyle) or "?",
					info and info.Time or -1
				)
			end)

			listed += 1
			Log.warn("  stuck %d: %s", listed, described and description or ("unreadable tween: " .. tostring(description)))
		end

		for _, tween in tweens do
			tween:Cancel()
		end
		return false
	end
	return true
end

return Tweens
