--!nonstrict
--[[
	ModifierSim — the combinatorial safety net.

	The point of a stacking modifier game is that combinations are surprising. The failure mode
	is that some combination is *unplayable*: nobody can move, or nobody can reach anybody, and
	a round ends in silence.

	Because the game gives up 23 modifiers today and 40+ later, nobody can review every triple
	by hand. So this enumerates them, applies declared conflicts plus a small set of
	effect-based rules, and reports anything sick. It is the cheapest possible insurance for a
	multi-author modifier catalogue, and it runs in a second.

	Adding a modifier automatically adds it to the simulation. Adding an *effect* to
	`EffectRules` automatically protects every future modifier that declares it.

	Usage: require(game.ServerStorage.Tools.ModifierSim).report()
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Modifiers = require(Shared.Modifiers)
local Escalation = require(Shared.Config.Escalation)

local ModifierSim = {}

local MAX_COMBO = 3 -- round 6 stacks three modifiers

--! Effect-based rules. A combination containing every effect in a rule is unplayable, whether
--! or not any individual modifier declared a conflict. This is what catches a *new* modifier
--! that is individually reasonable but lethal in company.
ModifierSim.EffectRules = {
	{
		Effects = { "ZeroFriction", "NoJump" },
		Message = "no friction and no jump: players cannot stop or leave the ground",
	},
	{
		Effects = { "ZeroFriction", "SlowWalk" },
		Message = "no friction and slowed: movement becomes a punishment, not a mechanic",
	},
	{
		Effects = { "ZeroFriction", "Shrink" },
		Message = "slippery floor with closing walls: a coin flip, not a fight",
	},
	{
		Effects = { "VisionLimited", "VisionLimited" },
		Message = "two vision modifiers stacked: the round becomes unwatchable",
	},
	{
		Effects = { "LoadoutOverride", "LoadoutOverride" },
		Message = "two loadout overrides: one of them silently wins, so a vote was wasted",
	},
	{
		Effects = { "GravityUp", "GravityDown" },
		Message = "opposing gravity modifiers",
	},
	{
		Effects = { "Hazard", "Collapse" },
		Message = "two simultaneous clocks on the round",
	},
}

local function effectSet(def)
	local set = {}
	for _, effect in def.Effects do
		set[effect] = true
	end
	return set
end

local function checkRules(combo): { string }
	local problems = {}
	local effects = {}
	for _, def in combo do
		for effect in effectSet(def) do
			effects[effect] = true
		end
	end

	for _, rule in ModifierSim.EffectRules do
		local matched = true
		for _, effect in rule.Effects do
			if not effects[effect] then
				matched = false
				break
			end
		end
		if matched then
			table.insert(problems, rule.Message)
		end
	end

	return problems
end

--! Can some arena host every modifier in this combo? If not, the ballot can still produce it
--! on an arena that only satisfies one, which is a real (if subtle) quality bug.
local function featureRequirementGap(combo, arenas: { { [string]: boolean } }): string?
	if #arenas == 0 then
		return nil
	end

	local required = {}
	for _, def in combo do
		for _, feature in def.Requires do
			required[feature] = true
		end
	end

	for _, features in arenas do
		local satisfies = true
		for feature in required do
			if not features[feature] then
				satisfies = false
				break
			end
		end
		if satisfies then
			return nil
		end
	end

	local missing = {}
	for feature in required do
		table.insert(missing, feature)
	end
	table.sort(missing)
	return "no single arena provides: " .. table.concat(missing, ", ")
end

function ModifierSim.run(options)
	options = options or {}
	local maxCombo = options.maxCombo or MAX_COMBO
	local arenaFeatures = options.arenaFeatures or {}

	local all = Modifiers.All
	local problems = {}
	local combosChecked = 0
	local conflictsFound = 0

	-- Size 1
	for _, def in all do
		combosChecked += 1
		if #def.Requires > 0 and #arenaFeatures > 0 then
			local gap = featureRequirementGap({ def }, arenaFeatures)
			if gap then
				-- not an error on its own: the modifier simply cannot appear on that arena
				table.insert(problems, {
					Kind = "Inapplicable",
					Ids = { def.Id },
					Message = gap,
				})
			end
		end
	end

	-- Size 2 and 3
	for first = 1, #all do
		for second = first + 1, #all do
			local pair = { all[first], all[second] }
			combosChecked += 1

			if Modifiers.conflicts(pair[1], pair[2]) then
				conflictsFound += 1
				-- A declared conflict is only a bug if the two could still be drawn together.
				-- Modifiers.draw filters them, so here we only verify symmetry is intentional.
			else
				local issues = checkRules(pair)
				for _, message in issues do
					table.insert(problems, {
						Kind = "Unplayable",
						Ids = { pair[1].Id, pair[2].Id },
						Message = message,
					})
				end
			end

			if maxCombo >= 3 then
				for third = second + 1, #all do
					local triple = { all[first], all[second], all[third] }
					combosChecked += 1

					local conflicting = false
					for a = 1, 3 do
						for b = a + 1, 3 do
							if Modifiers.conflicts(triple[a], triple[b]) then
								conflicting = true
							end
						end
					end
					if conflicting then
						conflictsFound += 1
					else
						local issues = checkRules(triple)
						for _, message in issues do
							table.insert(problems, {
								Kind = "Unplayable",
								Ids = { triple[1].Id, triple[2].Id, triple[3].Id },
								Message = message,
							})
						end

						local gap = featureRequirementGap(triple, arenaFeatures)
						if gap then
							table.insert(problems, {
								Kind = "Unhostable",
								Ids = { triple[1].Id, triple[2].Id, triple[3].Id },
								Message = gap,
							})
						end
					end
				end
			end
		end
	end

	local unplayable = 0
	for _, problem in problems do
		if problem.Kind == "Unplayable" then
			unplayable += 1
		end
	end

	return {
		ok = unplayable == 0,
		combosChecked = combosChecked,
		conflictsFound = conflictsFound,
		problems = problems,
		modifierCount = #all,
		maxStacked = Escalation.Formats.Full.Rounds[#Escalation.Formats.Full.Rounds].MaxStacked,
	}
end

function ModifierSim.report(options): string
	local result = ModifierSim.run(options)
	local lines = {}
	local function add(text: string)
		table.insert(lines, text)
	end

	add(
		string.format(
			"=== ModifierSim: %d modifiers, %d combos checked (up to %d stacked), %d declared conflicts ===",
			result.modifierCount,
			result.combosChecked,
			result.maxStacked,
			result.conflictsFound
		)
	)

	if #result.problems == 0 then
		add("  no unplayable combinations found")
	else
		for _, problem in result.problems do
			add(string.format("  %-11s %s -- %s", problem.Kind, table.concat(problem.Ids, " + "), problem.Message))
		end
	end

	add(result.ok and "  RESULT: PASS" or "  RESULT: FAIL (unplayable combinations exist)")
	return table.concat(lines, "\n")
end

return ModifierSim
