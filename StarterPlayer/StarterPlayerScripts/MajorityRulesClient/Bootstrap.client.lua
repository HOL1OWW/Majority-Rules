--!nonstrict
--[[
	Client bootstrap. This is the only LocalScript in the game.

	It wires the replication surface into the state store, then hands the state store to the UI
	and the controllers. Nothing here makes gameplay decisions — the client is a renderer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local State = require(Controllers.State)
local CameraController = require(Controllers.CameraController)
local FxController = require(Controllers.FxController)
local SprintController = require(Controllers.SprintController)
local WeaponController = require(Controllers.WeaponController)

local Banner = require(UI.Banner)
local Hud = require(UI.Hud)
local VoteUI = require(UI.VoteUI)

local remotes = {
	VoteCast = Net.event(Net.Events.VoteCast),
	Objection = Net.event(Net.Events.Objection),
	WeaponFire = Net.event(Net.Events.WeaponFire),
	RoundInfo = Net.func(Net.Functions.RoundInfo),
}

-- ---------------------------------------------------------------------------------------
-- Replication in
-- ---------------------------------------------------------------------------------------

Net.event(Net.Events.RoundState).OnClientEvent:Connect(function(payload)
	State.setRound(payload)
end)

Net.event(Net.Events.VoteState).OnClientEvent:Connect(function(payload)
	State.setVote(payload)
end)

Net.event(Net.Events.TransformFx).OnClientEvent:Connect(function(payload)
	State.setTransform(payload)
	VoteUI.showStamp(payload.WinnerNames or payload.ModifierIds or {}, (payload.Duration or 3) + 2)
end)

Net.event(Net.Events.RoundResult).OnClientEvent:Connect(function(payload)
	State.setResult(payload)
	VoteUI.hideStamp()
end)

Net.event(Net.Events.MatchResult).OnClientEvent:Connect(function(payload)
	State.setMatchResult(payload)
end)

Net.event(Net.Events.Notify).OnClientEvent:Connect(function(payload)
	State.notify(payload)
end)

-- ---------------------------------------------------------------------------------------
-- UI and controllers
-- ---------------------------------------------------------------------------------------

Hud.init({ state = State })
Banner.init({ state = State })
VoteUI.init({
	state = State,
	onVote = function(modifierId)
		remotes.VoteCast:FireServer(modifierId)
	end,
})
FxController.init({ state = State })
SprintController.init()
CameraController.init({ state = State })
WeaponController.init({ remotes = remotes })

-- Join-in-progress: ask for the current round immediately rather than waiting for the next
-- state change to arrive. A late joiner should never be looking at an empty screen.
task.spawn(function()
	for _ = 1, 10 do
		local ok, snapshot = pcall(function()
			return remotes.RoundInfo:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			State.setRound(snapshot)
			return
		end
		task.wait(0.5)
	end
	Log.debug("No round snapshot received; waiting for the next state change")
end)

Log.info("Client ready for %s", Players.LocalPlayer.Name)
