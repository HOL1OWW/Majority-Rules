--!nonstrict
--[[
	BotService — CPU combatants, so a round can be *played* instead of tested alone.

	Why this exists: a Roblox experience launches onto 1–3 player servers, and almost everything this
	game does only becomes observable with a second body in the arena — elimination, kill credit, a
	round that ends early because someone ran out of health, a modifier that turns out to be lethal.
	Testing that by hand needs two humans, which is exactly what a developer pressing Play does not
	have. These bots are that second body.

	Count: `ServerStorage.DevConfig.BotCount` decides it if that folder exists, including 0 for a solo
	round. With no config folder, Studio fills the lobby to `FULL_LOBBY` and a live server gets none —
	`RunService:IsStudio()` is the gate, not the presence of a folder. This is deliberate: the override
	used to be the *only* way to get bots, and it lives in a folder that does not survive a restart of
	the editor, so a Play button press silently produced a round with one human and nothing to measure.
	Promoting this to a real "fill the server" feature is a product decision, not a code change — the
	only line that would move is `devCount`.

	Bots get no special cases in the rules:
	  * the round spawns them and the round destroys them, like a player character
	  * their weapon is the round's loadout, so "ShotgunsOnly" applies to them too
	  * their shots go through `CombatService.botFire`, the same `resolveShot` a trigger pull uses
	  * their health and walk speed come from GameplayService's round baseline, so Sluggish and
	    SpeedBoost reach them
	--   * they fight like bodies: they answer whoever shot them, drift while holding, and disengage
	--     when losing — which is what makes seven of them a match instead of a firing line (D-044)
	  * they count as combatants for the round-end rule — which is the entire point
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Combat = require(Shared.Config.Combat)
local Modifiers = require(Shared.Modifiers)
local Weapons = require(Shared.Weapons.WeaponRegistry)
local Log = require(Shared.Util.Log)

local ArenaService = require(script.Parent.ArenaService)
local CombatService = require(script.Parent.CombatService)
local DevService = require(script.Parent.DevService)
local GameplayService = require(script.Parent.GameplayService)
local MatchState = require(script.Parent.MatchState)

local BotService = {}

--! The arena's own MaxPlayers: a full match rather than a crowd.
local FULL_LOBBY = 8

--! How many CPU combatants this round should have.
--!
--! An explicit `BotCount` wins, including zero. Otherwise Studio fills up to a full lobby — every
--! player who is not a bot is a body the round already has — and a live server gets none.
function BotService.devCount(): number
	if not RunService:IsStudio() then
		return 0
	end
	local configured = DevService.get("BotCount", nil)
	if type(configured) == "number" then
		return math.clamp(math.floor(configured), 0, FULL_LOBBY)
	end
	return math.clamp(FULL_LOBBY - #Players:GetPlayers(), 0, FULL_LOBBY - 1)
end

-- Tuning. A bot should be a genuine threat and still a losable one: it fires slower than the weapon
-- allows, aims with a fixed error that does not shrink with distance, and does not lead a target.
-- Everything here is a number a designer should be able to change without reading the AI.
local FIRE_INTERVAL_SCALE = 2.4 -- multiple of the weapon's own FireRate
local AIM_ERROR_RADIUS = 2.2 -- studs of miss at the target's distance
local ENGAGE_RANGE = 40 -- close to within this before shooting; further out it advances instead

--! Playing like a body, not a turret (D-044): a bot that answers its attacker, drifts sideways while
--! it holds, and backs off when it is losing reads as a player. Every number here is a designer
--! knob; none of them change what a shot can do — that is CombatService's business.
local TARGET_STICKINESS = 10 -- studs of preference keeping the current target interesting
local GRUDGE_SECONDS = 5 -- how long the last character that damaged this bot stays its target
local STRAFE_SECONDS = 1.2 -- how long one sideways drift lasts before the direction may flip
local STRAFE_STUDS = 6 -- how far a drift reaches
local RETREAT_HEALTH_FRACTION = 0.3 -- below this share of health, disengage after the next hit
local RETREAT_SECONDS = 2.5 -- how long a disengagement runs before re-engaging
local RETREAT_STUDS = 14 -- how far a disengagement runs

-- -------------------------------------------------------------------------------- vision handicap
--! Vision modifiers are the one family a bot cannot feel. Its line of sight is a geometric raycast, so
--! `Blackout` and `Fog` blind the player and leave the machine untouched: a round that voted Blackout
--! lasted **8.0 seconds** with seven bots that could see the whole hall and one human who could not
--! (D-038). Until there is a real vision model — a sight cone, a memory of where a target was — bots
--! take the same handicap the lighting gives a player, by *range* rather than by pixels.
local VISION_EFFECT = "VisionLimited"
local VISION_FLOOR = 0.25 -- a quarter of normal range is a room's length, not a wallhack

local function visionScale(): number
	local scale = 1
	for _, id in MatchState.ActiveModifiers do
		local def = Modifiers.get(id)
		if def and def.Effects then
			for _, effect in def.Effects do
				if effect == VISION_EFFECT then
					scale *= 0.5
					break
				end
			end
		end
	end
	return math.max(VISION_FLOOR, scale)
end
local REPATH_INTERVAL = 0.4 -- seconds between MoveTo calls
local FIRST_SHOT_DELAY = 1.5 -- a beat, so a round does not open with three simultaneous shots
local CORPSE_SECONDS = 3 -- how long a dead bot stays visible
local REPORT_INTERVAL = 3 -- seconds between decision reports, debug level and Studio only

-- Unsticking. A bot walking straight at a target jams against cover and can stand there for a whole
-- round, which measured as "51.7 studs" in every report for twenty seconds. When one stops making
-- progress it steps sideways instead of pressing into the wall.
local PROGRESS_INTERVAL = 2
local PROGRESS_MIN_STUDS = 2
local SIDESTEP_SECONDS = 1.2
local SIDESTEP_STUDS = 10

local folder: Folder? = nil
local bots = {} -- [Model] = { Humanoid, Root, Profile, Rng, NextFireAt, NextRepathAt, NextReportAt, ... }
local tickConnection: RBXScriptConnection? = nil

local function botFolder(): Folder
	if folder and folder.Parent then
		return folder
	end

	local existing = Workspace:FindFirstChild("Bots")
	local container: Folder
	if existing and existing:IsA("Folder") then
		container = existing
	else
		container = Instance.new("Folder")
		container.Name = "Bots"
		container.Parent = Workspace
	end

	folder = container
	return container
end

--! The gun a bot carries: the first weapon in the round's loadout that is not melee. A melee-only
--! round therefore produces bots that close in and do not shoot, which is a fair reading of the vote.
local function botProfile()
	for _, weaponId in CombatService.currentLoadout() do
		local profile = Weapons.get(weaponId)
		if profile and not Weapons.isMelee(profile) then
			return profile
		end
	end
	return nil
end

--! True when a character is still in the round and alive, for grudge bookkeeping.
local function livingCharacter(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return model.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0
end

--! The nearest living combatant — a player *or* another bot.
--!
--! Targeting only players made a dev round measure nothing: with one human and seven bots, all
--! seven converge on the human and never fire at each other, so the match is decided by the human's
--! first death. `RoundService.waitForRoundEnd` also ends a round the moment no player is alive, even
--! with seven bots standing, so a "round length" measured that way is the human's survival time, not
--! the arena's. Bots that fight each other are the only way a Studio round is eight players instead
--! of one. In production there are no bots, so this is exactly the old behaviour.
local function nearestCombatant(origin: Vector3, self: Model, rng: Random): (Model?, Vector3?)
	local best: Model? = nil
	local bestPosition: Vector3? = nil
	local bestDistance = math.huge

	local function consider(character: Model?)
		if not character or character == self then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		local distance = (root.Position - origin).Magnitude
		-- Ten studs of stickiness, drawn from the bot's own rng so every bot draws differently:
		-- without it seven bots in a ring all agree on the same nearest body and move as one school
		-- of fish, which is exactly the not-players look this service exists to avoid.
		distance += rng:NextNumber() * TARGET_STICKINESS
		if distance < bestDistance then
			best = character
			bestPosition = root.Position
			bestDistance = distance
		end
	end

	for _, player in MatchState.alivePlayers() do
		consider(player.Character)
	end
	for model in bots do
		consider(model)
	end

	return best, bestPosition
end

--! True when the first thing between the bot's head and the target belongs to the target.
local function hasLineOfSight(character: Model, target: Model): boolean
	local head = character:FindFirstChild("Head")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not head or not targetRoot then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(head.Position, targetRoot.Position - head.Position, params)
	if not result then
		return false
	end
	return result.Instance:IsDescendantOf(target)
end

--! Face the target without letting the physics rotate the bot back: AutoRotate is off, so a bot can
--! walk one way and shoot another, which is what makes it read as deliberate rather than as a prop.
local function aimAt(character: Model, position: Vector3)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local flat = Vector3.new(position.X, root.Position.Y, position.Z)
	if (flat - root.Position).Magnitude < 0.1 then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, flat)
end

local function tickBot(model: Model, state)
	local humanoid = state.Humanoid
	local root = state.Root
	if not humanoid.Parent or not root.Parent or humanoid.Health <= 0 then
		return
	end

	-- Round rules reach bots too. Re-read every tick so a transform that lands mid-round applies.
	-- Sprint: a bot bursts when it is chasing (long gap, target unseen) or fleeing. Combat is close
	-- and holding, so a burst is a *dash toward the fight*, not a permanent gallop — the timers make
	-- it read like a player tapping sprint, and a holding bot never wastes its dash.
	local baseSpeed = GameplayService.baseline().WalkSpeed
	humanoid.WalkSpeed = baseSpeed

	if MatchState.State ~= "Live" then
		return
	end

	local now = os.clock()

	-- Answer your attacker (D-044). CombatService records which character landed the last hit, so a
	-- bot being shot in the back turns around instead of walking at whoever is nearest. The grudge
	-- decays after GRUDGE_SECONDS, and a dead or despawned attacker is dropped immediately.
	local attacker = CombatService.lastAttackerOf(humanoid)
	if attacker and attacker ~= model then
		state.Grudge = attacker
		state.GrudgeUntil = now + GRUDGE_SECONDS
	elseif state.Grudge and (now >= state.GrudgeUntil or not livingCharacter(state.Grudge)) then
		state.Grudge = nil
	end

	local target, targetPosition = nearestCombatant(root.Position, model, state.Rng)
	if state.Grudge then
		local grudgeRoot = state.Grudge:FindFirstChild("HumanoidRootPart")
		if grudgeRoot then
			target = state.Grudge
			targetPosition = grudgeRoot.Position
		end
	end
	if not target or not targetPosition then
		return
	end

	local distance = (targetPosition - root.Position).Magnitude
	local visible = hasLineOfSight(model, target)
	local profile = state.Profile
	local engageRange = profile and math.min(profile.Range, ENGAGE_RANGE * visionScale()) or 0

	-- Back off when the fight is being lost (D-044): real players reset a fight they are losing, and
	-- a bot that only ever advances dies mid-charge with its weapon unused. Retriggering needs
	-- *fresh* damage — a bot at 20% that disengages, survives and re-engages does not flee forever.
	local healthFraction = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	if state.LastHealthFraction - healthFraction > 0.02
		and healthFraction < RETREAT_HEALTH_FRACTION
		and now >= state.RetreatUntil then
		state.RetreatUntil = now + RETREAT_SECONDS
	end
	state.LastHealthFraction = healthFraction

	-- Advance until there is a shot to take, then hold. Two lessons are baked into this: the first
	-- version only advanced while the target was beyond HOLD_DISTANCE, so on an arena with cover every
	-- bot stood still and never fired; and it wrote the root CFrame every frame to aim, which fights
	-- the walker and keeps it in place. Facing is the humanoid's job while it walks.
	local advancing = (not visible) or distance > engageRange

	if now >= state.NextProgressCheckAt then
		state.NextProgressCheckAt = now + PROGRESS_INTERVAL
		local moved = (root.Position - state.LastPosition).Magnitude
		if advancing and moved < PROGRESS_MIN_STUDS then
			local toTarget = Vector3.new(targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z)
			if toTarget.Magnitude > 0.1 then
				local side = state.Rng:NextNumber() < 0.5 and 1 or -1
				local perpendicular = Vector3.new(-toTarget.Unit.Z, 0, toTarget.Unit.X) * side
				state.SidestepUntil = now + SIDESTEP_SECONDS
				state.SidestepTarget = root.Position + perpendicular * SIDESTEP_STUDS
				Log.debug("Bots: %s is blocked, stepping sideways", model.Name)
			end
		end
		state.LastPosition = root.Position
	end

	local sidestepping = now < state.SidestepUntil and state.SidestepTarget ~= nil
	local retreating = now < state.RetreatUntil

	-- Sprint bursts: only meaningful while covering ground. Requires line of sight or a grudge so
	-- a blind sprint does not outrun the information that justified it.
	if state.SprintUntil and now >= state.SprintUntil then
		state.SprintUntil = nil
	end
	local chasing = advancing and distance > ENGAGE_RANGE * 1.2
	if not state.SprintUntil and not retreating and chasing and state.Rng:NextNumber() < 0.5 then
		state.SprintUntil = now + 1.2 + state.Rng:NextNumber() * 0.8 -- 1.2–2.0s bursts
	end
	humanoid.WalkSpeed = baseSpeed * (state.SprintUntil and Combat.SprintMultiplier or 1)

	if now >= state.NextRepathAt then
		state.NextRepathAt = now + REPATH_INTERVAL
		if sidestepping then
			humanoid:MoveTo(state.SidestepTarget :: Vector3)
		elseif retreating then
			-- Away from the target, refreshed each repath so the run curves around cover instead of
			-- backing straight into a corner. It may still fire while running, which is kiting.
			local away = (root.Position - targetPosition) * Vector3.new(1, 0, 1)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
			humanoid:MoveTo(root.Position + away * RETREAT_STUDS)
		elseif advancing then
			humanoid:MoveTo(targetPosition)
		else
			-- Hold, but like a body: track sideways so a still bot is not a free shot and seven
			-- holders do not line up in one lane. When the drift is spent the bot plants and aims,
			-- which is the only time it writes the CFrame — walking and writing it fight.
			if now >= state.StrafeUntil then
				state.StrafeUntil = now + STRAFE_SECONDS * (0.6 + state.Rng:NextNumber() * 0.8)
				if state.Rng:NextNumber() < 0.35 then
					state.StrafeDir = -state.StrafeDir
				end
				local toTarget = Vector3.new(
					targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z
				)
				if toTarget.Magnitude > 0.1 then
					local perpendicular = Vector3.new(-toTarget.Unit.Z, 0, toTarget.Unit.X) * state.StrafeDir
					state.StrafeTarget = root.Position + perpendicular * STRAFE_STUDS
				end
			end
			local drift = state.StrafeTarget
			if drift and (drift - root.Position).Magnitude > 1.5 then
				humanoid:MoveTo(drift)
			else
				humanoid:MoveTo(root.Position)
				aimAt(model, targetPosition)
			end
		end
	end

	local ready = profile ~= nil and now >= state.NextFireAt and distance <= engageRange and not sidestepping

	-- Debug level, so Studio-only. A bot that stands there silently is indistinguishable from a bot
	-- whose AI never ran, and this is the difference between reading the reason off a log and
	-- guessing at it — the same argument as the transform phase lines.
	if now >= state.NextReportAt then
		state.NextReportAt = now + REPORT_INTERVAL
		Log.debug(
			"Bots: %s target=%s %.1f studs los=%s ready=%s retreat=%s weapon=%s",
			model.Name,
			target.Name,
			distance,
			tostring(visible),
			tostring(ready),
			tostring(retreating),
			profile and profile.DisplayName or "none"
		)
	end

	if not ready then
		return
	end

	if not visible then
		state.NextFireAt = now + 0.2 -- blocked by cover: look again shortly
		return
	end

	local head = model:FindFirstChild("Head")
	if not head then
		return
	end

	state.NextFireAt = now + profile.FireRate * FIRE_INTERVAL_SCALE + state.Rng:NextNumber() * 0.25

	-- Aim at the centre of mass with a fixed miss radius, so a bot at range is a nuisance and a bot
	-- at knife range is dangerous.
	local aim = (targetPosition - head.Position).Unit
	local miss = Vector3.new(
		(state.Rng:NextNumber() - 0.5) * 2 * AIM_ERROR_RADIUS,
		(state.Rng:NextNumber() - 0.5) * 2 * AIM_ERROR_RADIUS * 0.5,
		(state.Rng:NextNumber() - 0.5) * 2 * AIM_ERROR_RADIUS
	) / math.max(distance, 1)

	if CombatService.botFire(model, head.Position, aim + miss, profile) then
		Log.debug("Bots: %s fired at %s from %.1f studs", model.Name, target.Name, distance)
	end
end

function BotService.aliveCount(): number
	local count = 0
	for model, state in bots do
		if model.Parent and state.Humanoid.Parent and state.Humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

function BotService.spawnAll(count: number)
	BotService.despawnAll()
	if count <= 0 then
		return
	end

	local profile = botProfile()
	if not profile then
		Log.warn("Bots: the round's loadout has no ranged weapon, so bots will not shoot back")
	end

	local spawns = ArenaService.GetSpawnParts()
	local created = 0

	for index = 1, count do
		local description = Instance.new("HumanoidDescription")
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
		end)
		if not ok or not model then
			Log.warn("Bots: could not build rig %d: %s", index, tostring(model))
			break
		end

		model.Name = string.format("BOT %d", index)

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then
			Log.warn("Bots: rig %d came back without a Humanoid or root part", index)
			model:Destroy()
			break
		end

		humanoid.DisplayName = model.Name
		-- Facing is the humanoid's own business while it walks; aiming takes over only when it holds
		-- still. Writing the root CFrame every frame is what stopped the first version from moving.
		humanoid.AutoRotate = true

		-- Tinted so a bot is never mistaken for a player during a test.
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Color = Color3.fromRGB(198, 96, 92)
			end
		end

		-- Spread across the ring rather than taking the first N points. The player takes ring slot 1
		-- (PlayerService walks its own cursor), so bots start from slot 2 and stride outwards: without
		-- this they spawned on the player's own spawn point, which made the first test look like three
		-- bots stacked on one body.
		if #spawns > 1 then
			local stride = math.max(1, math.floor(#spawns / count))
			local slot = 2 + ((index - 1) * stride) % (#spawns - 1)
			root.CFrame = spawns[slot].CFrame + Vector3.new(0, Combat.SpawnHeightOffset, 0)
		end

		model.Parent = botFolder()
		GameplayService.applyToBot(model)
		humanoid.Health = humanoid.MaxHealth

		CombatService.bindBot(model, function()
			bots[model] = nil
			Log.debug("Bots: %s was eliminated", model.Name)
			task.delay(CORPSE_SECONDS, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		end)

		bots[model] = {
			Humanoid = humanoid,
			Root = root,
			Profile = profile,
			-- Seeded from the match, so a bot's behaviour is reproducible for a reported seed even
			-- though it is never part of the match itself.
			Rng = Random.new(MatchState.Seed + index * 7919),
			NextFireAt = os.clock() + FIRST_SHOT_DELAY,
			NextRepathAt = 0,
			NextReportAt = 0,
			NextProgressCheckAt = 0,
			LastPosition = root.Position,
			SidestepUntil = 0,
			SidestepTarget = nil,
			Grudge = nil,
			GrudgeUntil = 0,
			StrafeUntil = 0,
			StrafeDir = 1,
			StrafeTarget = nil,
			RetreatUntil = 0,
			LastHealthFraction = 1,
		}
		created += 1
	end

	if created > 0 then
		Log.info(
			"Bots: %d spawned (weapon=%s, %d spawn point(s) available)",
			created,
			profile and profile.DisplayName or "none",
			#spawns
		)
	end
end

function BotService.despawnAll()
	local models = {}
	for model in bots do
		table.insert(models, model)
	end
	for _, model in models do
		bots[model] = nil
		if model.Parent then
			model:Destroy()
		end
	end

	if folder and folder.Parent then
		folder:ClearAllChildren()
	end
end

function BotService.setup()
	if tickConnection then
		return
	end

	tickConnection = RunService.Heartbeat:Connect(function()
		if next(bots) == nil then
			return
		end

		local broken = nil
		for model, state in bots do
			local ok, err = pcall(tickBot, model, state)
			if not ok then
				Log.warn("Bots: tick failed for %s: %s", model.Name, tostring(err))
				broken = broken or {}
				table.insert(broken, model)
			end
		end
		-- Collected and dropped after the loop: removing a key while iterating a table is undefined.
		if broken then
			for _, model in broken do
				bots[model] = nil
			end
		end
	end)
end

return BotService
