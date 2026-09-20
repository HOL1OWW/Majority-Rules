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
		Log.warn("Tweens.await timed out with %d tween(s) still running", pending)
		for _, tween in tweens do
			tween:Cancel()
		end
		return false
	end
	return true
end

return Tweens
