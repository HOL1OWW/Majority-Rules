--!nonstrict
--[[
	Tags.lua — THE CONTRACT.

	Every piece of data that crosses between the map team and the systems team passes through
	a CollectionService tag or an Attribute name declared in this file. Nothing else.

	Rules:
	  * No script may reference an arena part by name or by path.
	  * No arena model may contain a Script.
	  * Renaming anything here is a contract change and needs a docs/DECISIONS.md entry.
]]

local CollectionService = game:GetService("CollectionService")

local Tags = {}

-- ---------------------------------------------------------------------------------------
-- CollectionService tags
-- ---------------------------------------------------------------------------------------

Tags.Arena = "MRArena" -- Model: root of an arena. Exactly one per arena model.
Tags.Static = "MRArenaStatic" -- BasePart: always-visible geometry, never transformed.
Tags.Transformable = "MRArenaTransformable" -- BasePart: a modifier may move/scale/hide it.
Tags.Spawn = "MRArenaSpawn" -- BasePart: a player spawn point.
Tags.LootPoint = "MRLootPoint" -- BasePart/Attachment: where a weapon crate may appear.
Tags.Hazard = "MRArenaHazard" -- BasePart: damaging volume, opt-in per modifier.
Tags.VoteCamera = "MRVoteCamera" -- BasePart: a CFrame marker for the vote showcase orbit.
Tags.VoteNameplate = "MRVoteNameplate" -- BasePart: carries the winning modifier's name.
Tags.Emitter = "MREmitter" -- ParticleEmitter/Beam/Trail/Sound: toggled by modifier id.
Tags.Crate = "MRCrate" -- Model/BasePart: a spawned weapon crate (runtime).
Tags.Variant = "MRVariant" -- Model: a hand-authored per-modifier arena variant.

Tags.List = {
	Tags.Arena,
	Tags.Static,
	Tags.Transformable,
	Tags.Spawn,
	Tags.LootPoint,
	Tags.Hazard,
	Tags.VoteCamera,
	Tags.VoteNameplate,
	Tags.Emitter,
	Tags.Crate,
	Tags.Variant,
}

-- ---------------------------------------------------------------------------------------
-- Attribute names
-- ---------------------------------------------------------------------------------------

Tags.Attr = {
	-- Arena root
	ArenaId = "ArenaId",
	DisplayName = "DisplayName",
	MinPlayers = "MinPlayers",
	MaxPlayers = "MaxPlayers",
	SizeClass = "SizeClass", -- Tiny | Small | Medium | Large
	FeatureTags = "FeatureTags", -- comma separated: Cover,Vertical,Hazard,FlatFloor,Indoor,Water
	FloorY = "FloorY",
	Weight = "Weight",
	BannedModifiers = "BannedModifiers",
	SupportedModifiers = "SupportedModifiers",

	-- Transformable parts
	TransformGroup = "TransformGroup", -- comma separated group names, e.g. "Floor,Tile_3"
	CanScale = "CanScale",
	CanHide = "CanHide",
	CanMorph = "CanMorph",
	AnchorState = "AnchorState", -- Shown | Hidden

	-- Spawns and loot
	SpawnIndex = "SpawnIndex",
	LootWeight = "LootWeight",
	ClearanceRadius = "ClearanceRadius",
	Zone = "Zone",

	-- Hazards
	HazardType = "HazardType", -- Lava | Void | Trampoline | Conveyor

	-- Showcase
	Order = "Order",

	-- Emitters and variants
	OnModifier = "OnModifier", -- comma separated modifier ids that switch this emitter on
	VariantOf = "VariantOf", -- modifier id a Variants/<Id> model belongs to

	-- Runtime / replicated state
	Text = "Text",
	ModifierId = "ModifierId",
	WeaponId = "WeaponId",
	Phase = "Phase",
	Label = "Label",
}

-- ---------------------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------------------

--! Split "Cover,Vertical" into { Cover = true, Vertical = true }
function Tags.listToSet(value: string?): { [string]: boolean }
	local set = {}
	if not value then
		return set
	end
	for token in string.gmatch(value, "[^,]+") do
		local trimmed = string.match(token, "^%s*(.-)%s*$")
		if trimmed and #trimmed > 0 then
			set[trimmed] = true
		end
	end
	return set
end

function Tags.setToList(set: { [string]: boolean }): string
	local out = {}
	for key in set do
		table.insert(out, key)
	end
	table.sort(out)
	return table.concat(out, ",")
end

--! Arena feature tags declared on the arena root.
function Tags.featuresOf(arena: Instance): { [string]: boolean }
	return Tags.listToSet(arena:GetAttribute(Tags.Attr.FeatureTags))
end

function Tags.hasFeature(arena: Instance, feature: string): boolean
	return Tags.featuresOf(arena)[feature] == true
end

--! Transform groups a part belongs to.
function Tags.groupsOf(part: Instance): { [string]: boolean }
	return Tags.listToSet(part:GetAttribute(Tags.Attr.TransformGroup))
end

--! True when an emitter's OnModifier list intersects the active modifier set.
function Tags.emitterMatches(instance: Instance, activeIds: { [string]: boolean }): boolean
	local list = Tags.listToSet(instance:GetAttribute(Tags.Attr.OnModifier))
	for id in list do
		if activeIds[id] then
			return true
		end
	end
	return false
end

--! All tagged descendants of a container, as an array.
function Tags.tagged(container: Instance, tag: string, recursive: boolean?): { Instance }
	local out = {}
	if recursive == false then
		for _, child in container:GetChildren() do
			if CollectionService:HasTag(child, tag) then
				table.insert(out, child)
			end
		end
		return out
	end
	for _, descendant in CollectionService:GetTagged(tag) do
		if descendant:IsDescendantOf(container) then
			table.insert(out, descendant)
		end
	end
	return out
end

--! Children of a named folder, or {} when the folder is absent.
function Tags.folder(parent: Instance, name: string): Instance?
	local found = parent:FindFirstChild(name)
	if found and found:IsA("Folder") then
		return found
	end
	return nil
end

function Tags.attr(instance: Instance, name: string, default: any): any
	local value = instance:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

return Tags
