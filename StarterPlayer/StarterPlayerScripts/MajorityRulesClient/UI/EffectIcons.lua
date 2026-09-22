--!nonstrict
--[[
	EffectIcons — one image asset per Effects token, with emoji fallback.

	How it works:
	  * ASSET holds the uploaded Roblox image ids (rbxassetid). Until an id is filled in,
	    the chip falls back to the emoji in EMOJI — so this module can ship before the
	    upload session happens and the ballot never regresses.
	  * To fill in ids after uploading: paste the id list into HARVEST below (one per line,
	    upload order), then set a temp attribute on ReplicatedStorage and run the one-liner
	    printed by tools/harvest_icon_ids.lua. See docs/17-ICON-ASSETS.md.
	  * Icons are drawn as flat line art in a single ink color; the UI tints them white.
	    Regenerate with `py tools/generate_effect_icons.py` after editing a glyph.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectIcons = {}

-- Upload order: this exact list is what the harvester matches filenames against.
EffectIcons.ORDER = {
	"GravityDown", "GravityUp", "AirTime", "AirJump", "Bouncy", "Drift",
	"ZeroFriction", "FastWalk", "SlowWalk", "NoJump", "Collapse", "PistolOnly",
	"Cover", "Hazard", "Lava", "Gamble", "InfiniteAmmo", "Lifesteal",
	"LoadoutOverride", "NoRanged", "LowHealth", "Ricochet", "Shrink",
	"VisionLimited", "Darkness",
}

-- Filled in after the upload session. Empty string = no asset yet (fallback shows).
EffectIcons.ASSET = {
	GravityDown = "",
	GravityUp = "",
	AirTime = "",
	AirJump = "",
	Bouncy = "",
	Drift = "",
	ZeroFriction = "",
	FastWalk = "",
	SlowWalk = "",
	NoJump = "",
	Collapse = "",
	PistolOnly = "",
	Cover = "",
	Hazard = "",
	Lava = "",
	Gamble = "",
	InfiniteAmmo = "",
	Lifesteal = "",
	LoadoutOverride = "",
	NoRanged = "",
	LowHealth = "",
	Ricochet = "",
	Shrink = "",
	VisionLimited = "",
	Darkness = "",
}

-- Fallback glyphs, one per token — the previous system, kept verbatim so behavior is
-- identical until the real assets land.
EffectIcons.EMOJI = {
	GravityDown = "🪶",
	GravityUp = "🔺",
	AirTime = "🎈",
	AirJump = "⏫",
	Bouncy = "🫧",
	Drift = "🧊",
	ZeroFriction = "🧊",
	FastWalk = "👟",
	SlowWalk = "🐌",
	NoJump = "🚫",
	Collapse = "💥",
	Cover = "📦",
	Hazard = "⚠️",
	Lava = "🌋",
	Gamble = "🎰",
	InfiniteAmmo = "♾️",
	Lifesteal = "🩸",
	LoadoutOverride = "🔫",
	NoRanged = "🎯",
	LowHealth = "❤️‍🔥",
	Ricochet = "⚡",
	Shrink = "📉",
	VisionLimited = "🌫️",
	Darkness = "🌑",
	Example = "❓",
}

-- Token -> base token sharing the same art. Extend when a new effect is a variant of an
-- existing glyph (e.g. a second friction token reusing the ice crystal).
EffectIcons.ALIAS = {}

-- Effect token -> drawn glyph name (must stay in sync with tools/generate_effect_icons.py
-- ICONS table). Aliased tokens reuse their base token's asset and emoji.
EffectIcons.GLYPH_OF = {
	GravityDown = "feather", GravityUp = "uparrow", AirTime = "balloon",
	AirJump = "doublechevronup", Bouncy = "bubble", Drift = "icecrystal",
	ZeroFriction = "icecrystal", FastWalk = "boot", SlowWalk = "snail",
	NoJump = "crosscircle", Collapse = "crack", PistolOnly = "pistol",
	Cover = "crate", Hazard = "warning", Lava = "lava", Gamble = "dice",
	InfinityAmmo = "infinity", InfiniteAmmo = "infinity",
	Lifesteal = "droplet", LoadoutOverride = "gunswap", NoRanged = "crosshairslash",
	LowHealth = "heart", Ricochet = "ricochet", Shrink = "shrinkarrow",
	VisionLimited = "fog", Darkness = "moon",
}

function EffectIcons.get(token)
	local asset = EffectIcons.ASSET[token]
	if asset ~= nil and asset ~= "" then
		return { kind = "image", value = asset }
	end
	-- alias: share the base token's asset if it has one
	local base = EffectIcons.ALIAS[token]
	if base and base ~= token then
		local baseAsset = EffectIcons.ASSET[base]
		if baseAsset ~= nil and baseAsset ~= "" then
			return { kind = "image", alias = base, value = baseAsset }
		end
	end
	local emoji = EffectIcons.EMOJI[token] or EffectIcons.EMOJI[base]
	if emoji then
		return { kind = "emoji", value = emoji }
	end
	return nil
end

function EffectIcons.hasAsset(token)
	local a = EffectIcons.ASSET[token]
	return a ~= nil and a ~= ""
end

function EffectIcons.countAssets()
	local n = 0
	for _, token in EffectIcons.ORDER do
		if EffectIcons.hasAsset(token) then
			n += 1
		end
	end
	return n
end

return EffectIcons
