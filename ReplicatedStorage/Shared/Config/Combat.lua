--!nonstrict
--[[
	Combat.lua — combat and round tuning values. Data only, no behaviour.

	Everything here is a number a designer should be able to change without reading code.
]]

local Combat = {}

-- Player baseline
-- WalkSpeed 22: the outline arena is 500 studs across, so the base pace has to cross it; sprint
-- on top of that for the burst.
Combat.Health = 100
Combat.WalkSpeed = 22
Combat.JumpPower = 50

-- Sprint. Server-authoritative: the client only asks, this service decides. A multiplier on the
-- round baseline so modifiers compose — Sluggish sprinting is still slower than a plain walk.
Combat.SprintMultiplier = 1.5
Combat.SprintStaminaMax = 100
Combat.SprintDrainPerSecond = 14 -- about 7 seconds of full sprint from full stamina
Combat.SprintRegenPerSecond = 9
Combat.SprintMinStamina = 20 -- must regen above this before sprint can start again
Combat.SprintResetThreshold = 40 -- stamina climbs back to this before another sprint is allowed

Combat.ResetOnSpawn = false

-- Spawning
Combat.SpawnHeightOffset = 4
Combat.SpawnProtectionSeconds = 2 -- brief invulnerability so a spawn is not an execution
Combat.SpawnSpreadStuds = 8 -- minimum spacing the arena validator enforces

-- Scoring
Combat.KillPoints = 1
Combat.RoundWinPoints = 3
Combat.SurvivalOrderBreaksTies = true

-- Weapons
Combat.DefaultLoadout = { "Sidearm" }
Combat.MaxReserveWeapons = 3
Combat.CooldownGraceSeconds = 0.02 -- tolerance on the server-side fire-rate check
Combat.MaxFireOriginOffsetStuds = 12 -- anti-cheat: muzzle must be near the shooter
Combat.RicochetBounces = 1

-- Crates
Combat.CrateOpenRadius = 8
Combat.CrateRespawnSeconds = 25
Combat.MaxCratesPerLootPoint = 1
Combat.CratePoolSize = 4 -- weapons per round drawn from the active pool

-- Hazards
Combat.HazardDamagePerSecond = 22
Combat.HazardTickSeconds = 0.5
Combat.HazardGraceAfterSpawn = 1.5

-- Round rules
Combat.EliminateOnDeath = true
Combat.KeepVotingWhenEliminated = true -- the whole reason the vote stays interesting after death
Combat.MinAliveToContinue = 1 -- round ends when <= this many players are alive

return Combat
