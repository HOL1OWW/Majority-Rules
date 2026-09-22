--!nonstrict
--[[
	harvest_icon_ids — paste into Studio's Command Bar ONCE after uploading the icons.

	You paste the list of new asset ids from the Creator Dashboard (any order, separated
	by commas, whitespace, or newlines). For each id this script asks Roblox for the
	asset's name (= the filename you uploaded, e.g. "GravityDown"), matches it against
	EffectIcons.ORDER, and prints a ready-to-paste ASSET table for EffectIcons.lua.

	Because matching is by NAME, paste order and stray duplicates cannot mis-assign an
	icon to the wrong token.

	Full procedure: docs/17-ICON-ASSETS.md, part B step 3.
]]

local MARKET = game:GetService("MarketplaceService")
local TOKENS = {
	"GravityDown", "GravityUp", "AirTime", "AirJump", "Bouncy", "Drift",
	"ZeroFriction", "FastWalk", "SlowWalk", "NoJump", "Collapse", "PistolOnly",
	"Cover", "Hazard", "Lava", "Gamble", "InfiniteAmmo", "Lifesteal",
	"LoadoutOverride", "NoRanged", "LowHealth", "Ricochet", "Shrink",
	"VisionLimited", "Darkness",
}

local function idListFromString(s)
	local ids = {}
	for token in string.gmatch(s, "%d+") do
		table.insert(ids, tonumber(token))
	end
	return ids
end

local function run()
	local PASTE = _G.MR_ICON_IDS or ""
	if #PASTE == 0 then
		print("[MR-Icons] Set _G.MR_ICON_IDS to your id list first, e.g.:")
		print('[MR-Icons] _G.MR_ICON_IDS = "1875463245, 1875463999, ..." then re-run require(...)')
		return
	end

	local byName = {}
	local unknown = {}
	for _, id in idListFromString(PASTE) do
		local ok, info = pcall(function()
			return MARKET:GetProductInfo(id, Enum.InfoType.Asset)
		end)
		if ok and info and info.Name then
			byName[info.Name] = id
		else
			table.insert(unknown, id)
		end
	end

	local missing = {}
	local lines = {}
	for _, token in TOKENS do
		local id = byName[token]
		if id then
			table.insert(lines, string.format("\t%s = \"%d\",", token, id))
		else
			table.insert(missing, token)
			table.insert(lines, string.format("\t%s = \"\", -- MISSING", token))
		end
	end

	print("[MR-Icons] ---- paste this ASSET table over the one in EffectIcons.lua ----")
	print("EffectIcons.ASSET = {")
	for _, line in lines do
		print(line)
	end
	print("}")
	if #missing > 0 then
		print(("[MR-Icons] %d token(s) had no matching upload: %s"):format(#missing, table.concat(missing, ", ")))
	end
	if #unknown > 0 then
		print(("[MR-Icons] %d id(s) could not be resolved (kept out): %s"):format(#unknown, table.concat(unknown, ", ")))
	end
end

run()
