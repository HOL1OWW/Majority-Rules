--!nonstrict
--[[
	Modifiers — the registry.

	Every `.lua` file in `Tier1/`, `Tier2/` and `Tier3/` is auto-loaded as a modifier; files
	whose name starts with `_` are ignored. Adding a modifier is therefore dropping in one
	file, with no central list to edit and no merge conflicts between contributors.

	This module also owns the *draw*: which candidates appear on the vote cards, and how the
	engine guarantees a well-formed ballot (no two cards that contradict each other, a tier-3
	card when the escalation table demands one, and no modifier that the current arena
	cannot host).

	This module is required by BOTH server and client: the client needs names, blurbs and
	category colours for the vote cards. Only the `Steps`/hook functions ever run on the
	server.
]]

local Log = require(script.Parent.Util.Log)
local Pick = require(script.Parent.Util.Pick)

local Modifiers = {}

Modifiers.ById = {}
Modifiers.All = {}
Modifiers.Errors = {}

--! Category tags. The first four are also the UI colour groups. The rest exist so that a
--! whole family of modifiers can be declared mutually exclusive in one line: any modifier
--! tagged "Loadout" conflicts with any other, without naming each id individually.
local CATEGORY_TAGS = {
	Gravity = true,
	Spatial = true,
	Combat = true,
	Environment = true,
	Chaos = true,
	Loadout = true,
	Vision = true,
	Mobility = true,
	Shrink = true,
}

--! Arena feature tags the engine understands. `Requires`/`Bans` may only reference these.
Modifiers.KnownFeatures = {
	Cover = true,
	Vertical = true,
	Hazard = true,
	Lava = true,
	FlatFloor = true,
	Tiles = true,
	Indoor = true,
	Water = true,
}

--! The fourth card. Voting for it hands the decision to the machine.
Modifiers.GambleId = "Gamble"
Modifiers.Gamble = {
	Id = "Gamble",
	DisplayName = "GAMBLE",
	Blurb = "Nobody knows. The machine decides. Probably something awful.",
	Tier = 2,
	Weight = 0,
	Tags = { "Chaos" },
	Conflicts = {},
	Requires = {},
	Bans = {},
	Effects = { "Gamble" },
	IsGamble = true,
	StacksWell = true,
}

local function toArray(value: any): { any }
	if type(value) == "table" then
		return value
	end
	return {}
end

--! True when `def` forbids `other`, reading both ids and category tags.
local function forbids(def, other): boolean
	if not def.Conflicts or not other then
		return false
	end
	for _, entry in def.Conflicts do
		if entry == other.Id then
			return true
		end
		if other.Tags then
			for _, tag in other.Tags do
				if tag == entry then
					return true
				end
			end
		end
	end
	return false
end

--! Symmetric conflict test: modifiers must never contradict each other in any order.
function Modifiers.conflicts(a, b): boolean
	if not a or not b or a.Id == b.Id then
		return false
	end
	return forbids(a, b) or forbids(b, a)
end

function Modifiers.register(def)
	if type(def) ~= "table" or type(def.Id) ~= "string" or #def.Id == 0 then
		table.insert(Modifiers.Errors, "a modifier is missing a string Id")
		return false
	end
	if Modifiers.ById[def.Id] then
		table.insert(Modifiers.Errors, string.format("duplicate modifier id '%s'", def.Id))
		return false
	end
	if type(def.DisplayName) ~= "string" or type(def.Blurb) ~= "string" then
		table.insert(Modifiers.Errors, string.format("%s is missing DisplayName or Blurb", def.Id))
		return false
	end
	if type(def.Tier) ~= "number" or def.Tier < 1 or def.Tier > 3 then
		table.insert(Modifiers.Errors, string.format("%s has an invalid Tier", def.Id))
		return false
	end

	def.Weight = def.Weight or 10
	def.Tags = toArray(def.Tags)
	def.Conflicts = toArray(def.Conflicts)
	def.Requires = toArray(def.Requires)
	def.Bans = toArray(def.Bans)
	def.Effects = toArray(def.Effects)
	if def.StacksWell == nil then
		def.StacksWell = true
	end

	Modifiers.ById[def.Id] = def
	table.insert(Modifiers.All, def)
	return true
end

local function loadContainer(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Folder") then
			loadContainer(child)
		elseif child:IsA("ModuleScript") and string.sub(child.Name, 1, 1) ~= "_" then
			local ok, def = pcall(require, child)
			if not ok then
				table.insert(Modifiers.Errors, string.format("failed to load %s: %s", child.Name, tostring(def)))
			elseif type(def) == "table" then
				Modifiers.register(def)
			else
				table.insert(Modifiers.Errors, string.format("%s did not return a table", child.Name))
			end
		end
	end
end

loadContainer(script)
table.sort(Modifiers.All, function(a, b)
	return a.Id < b.Id
end)

function Modifiers.get(id: string?)
	if not id then
		return nil
	end
	if id == Modifiers.GambleId then
		return Modifiers.Gamble
	end
	return Modifiers.ById[id]
end

function Modifiers.count(): number
	return #Modifiers.All
end

--! Boot-time self check. Reports, never throws: a broken modifier should not kill the game.
function Modifiers.validate()
	local problems = {}

	for _, problem in Modifiers.Errors do
		table.insert(problems, problem)
	end

	for _, def in Modifiers.All do
		for _, entry in def.Conflicts do
			if not CATEGORY_TAGS[entry] and not Modifiers.ById[entry] then
				table.insert(problems, string.format("%s conflicts with unknown id or tag '%s'", def.Id, entry))
			end
		end
		for _, entry in def.Requires do
			if not Modifiers.KnownFeatures[entry] then
				table.insert(problems, string.format("%s requires unknown arena feature '%s'", def.Id, entry))
			end
		end
		for _, entry in def.Bans do
			if not Modifiers.KnownFeatures[entry] then
				table.insert(problems, string.format("%s bans unknown arena feature '%s'", def.Id, entry))
			end
		end
		if not def.Steps and not def.OnRoundStart and not def.Tick and not def.OnCharacterSpawn then
			table.insert(problems, string.format("%s does nothing", def.Id))
		end
	end

	return {
		ok = #problems == 0,
		problems = problems,
		count = #Modifiers.All,
	}
end

--! Can these modifiers legally coexist? Used by the ballot draw and the combo simulator.
function Modifiers.validateCombo(ids: { string }): (boolean, string?)
	local defs = {}
	for _, id in ids do
		local def = Modifiers.get(id)
		if not def then
			return false, string.format("unknown modifier '%s'", id)
		end
		table.insert(defs, def)
	end
	for index = 1, #defs do
		for otherIndex = index + 1, #defs do
			if Modifiers.conflicts(defs[index], defs[otherIndex]) then
				return false, string.format("%s conflicts with %s", defs[index].Id, defs[otherIndex].Id)
			end
		end
	end
	return true, nil
end

--! Every modifier that could legally appear on a ballot for this round of this arena.
function Modifiers.candidatePool(opts)
	local features = opts.Features or {}
	local tiers = {}
	for _, tier in opts.Tiers or {} do
		tiers[tier] = true
	end
	local banned = opts.Banned or {}
	local chosen = opts.Chosen or {}
	local allowSingles = opts.AllowSingles ~= false

	local pool = {}
	for _, def in Modifiers.All do
		local ok = tiers[def.Tier] == true

		if ok and opts.Round then
			if def.MinRound and opts.Round < def.MinRound then
				ok = false
			end
			if def.MaxRound and opts.Round > def.MaxRound then
				ok = false
			end
		end

		if ok then
			for _, entry in def.Requires do
				if not features[entry] then
					ok = false
					break
				end
			end
		end

		if ok then
			for _, entry in def.Bans do
				if features[entry] then
					ok = false
					break
				end
			end
		end

		-- A modifier that does not stack well may only appear when it is the whole ballot.
		-- Otherwise a card that cannot coexist with anything would poison a stacking round.
		if ok and def.StacksWell == false and not allowSingles then
			ok = false
		end

		if ok and (banned[def.Id] or banned[def.Tags]) then
			ok = false
		end

		if ok and #chosen > 0 then
			for _, id in chosen do
				local other = Modifiers.get(id)
				if other and Modifiers.conflicts(def, other) then
					ok = false
					break
				end
			end
		end

		if ok then
			table.insert(pool, def)
		end
	end

	table.sort(pool, function(a, b)
		return a.Id < b.Id
	end)
	return pool
end

--! Weighted draw of the ballot. Guarantees the requested tier coverage and keeps every card
--! mutually compatible, because in a stacking round any two cards can end up applying.
function Modifiers.draw(opts, rng: Random)
	local count = opts.Count or 3
	-- `MaxStacked` is how many of the top finishers apply; see docs/04-ESCALATION.md.
	opts.MaxStacked = opts.MaxStacked or 1
	local picked = {}
	local chosen = table.clone(opts.Chosen or {})

	local function take(tierFilter)
		local pool = Modifiers.candidatePool({
			Features = opts.Features or {},
			Tiers = tierFilter or opts.Tiers or { 1, 2, 3 },
			Round = opts.Round,
			Banned = opts.Banned or {},
			Chosen = chosen,
			-- StacksWell = false modifiers are only legal when a single modifier is applied,
			-- because in a stacking round any two ballot cards might both win.
			AllowSingles = (opts.MaxStacked or 1) <= 1,
		})

		local filtered = {}
		for _, def in pool do
			local alreadyPicked = false
			for _, existing in picked do
				if existing.Id == def.Id then
					alreadyPicked = true
					break
				end
			end
			if not alreadyPicked then
				table.insert(filtered, def)
			end
		end

		local def = Pick.weighted(filtered, function(item)
			return item.Weight
		end, rng)
		if def then
			table.insert(picked, def)
			table.insert(chosen, def.Id)
		end
		return def
	end

	if opts.GuaranteeTier then
		take({ opts.GuaranteeTier })
	end

	local guard = 0
	while #picked < count and guard < count * 4 + 8 do
		guard += 1
		if not take(nil) then
			break
		end
	end

	return picked
end

return Modifiers
