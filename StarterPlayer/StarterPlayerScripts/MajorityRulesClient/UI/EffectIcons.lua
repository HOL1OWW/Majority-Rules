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

-- One plain-language line per token, shown as a hover tooltip on the chip. Written for a
-- player mid-vote: what the arena does to YOU, no jargon. An unknown token has no tooltip —
-- silent, never wrong, same philosophy as the chips.
EffectIcons.HELP = {
	GravityDown = "Low gravity — you float and jumps go much higher.",
	GravityUp = "Heavy gravity — jumps feel weak and everything is heavy.",
	AirTime = "Every jump hangs in the air much longer.",
	AirJump = "You can jump again in mid-air.",
	Bouncy = "The floor is a trampoline — landings bounce you back up.",
	Drift = "The ground is slippery — you slide instead of stopping.",
	ZeroFriction = "Zero grip — once you move, you cannot stop sliding.",
	FastWalk = "Everyone runs noticeably faster.",
	SlowWalk = "Everyone moves in slow motion.",
	NoJump = "Jumping is disabled for the whole round.",
	Collapse = "Floor tiles crumble away as the round goes on.",
	Cover = "Walls rise out of the floor when the round starts.",
	Hazard = "A deadly hazard appears somewhere in the arena.",
	Lava = "Lava rises from below and floods the arena floor.",
	Gamble = "The winner is drawn at random — anyone can take it.",
	InfiniteAmmo = "Nobody ever runs out of ammo.",
	Lifesteal = "Damage you deal heals you.",
	LoadoutOverride = "Your weapons are replaced by a surprise loadout.",
	NoRanged = "Ranged weapons are out — melee only.",
	LowHealth = "Everyone starts with a sliver of health.",
	Ricochet = "Bullets bounce off walls.",
	Shrink = "The arena shrinks as the round goes on.",
	VisionLimited = "Fog rolls in — you can barely see past mid-range.",
	Darkness = "Lights out — night vision is the only vision.",
	Example = "Example effect used by the tutorial modifier.",
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

function EffectIcons.helpFor(token)
	if not token then
		return nil
	end
	return EffectIcons.HELP[token] or EffectIcons.HELP[EffectIcons.ALIAS[token]]
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
