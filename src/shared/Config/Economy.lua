--!nonstrict
--[[
	Economy.lua — progression and monetization configuration.

	Two currencies only. `Clout` is earned and can never be bought; Robux purchases are
	cosmetics, convenience and vanity. There is deliberately no premium-currency wrapper:
	it simplifies the economics and keeps us clear of randomized-item policy complexity.

	MONETIZATION GUARDRAILS (non-negotiable, see docs/06-MONETIZATION.md):
	  * Never sell vote weight.
	  * Never sell in-round advantage.
	  * Disclose odds on anything randomized and offer a direct purchase alternative.
	  * Gate paid content through PolicyService before showing it.

	`Economy.Enabled` stays false until real asset ids are filled in below. While it is
	false, MonetizationService refuses to prompt anything, so a placeholder id can never
	charge a player by accident.
]]

local Economy = {}

Economy.Enabled = false

-- Earned currency
Economy.Clout = {
	PerKill = 5,
	PerRoundWin = 25,
	PerCorrectVote = 3, -- your pick won the vote
	PerMatchComplete = 20,
	PerMatchWin = 60,
	FirstMatchOfDay = 40,
}

-- Rewarded video
Economy.RewardedVideo = {
	Enabled = false,
	CloutMultiplier = 2,
	DailyCap = 5,
	MinAccountAgeDays = 0,
}

-- Passes (Roblox game pass ids). Fill these in before flipping Economy.Enabled.
Economy.Passes = {
	Speaker = 0, -- cosmetic flair, golden vote card skin, custom announcer, priority queue
	DecreePass = 0, -- seasonal cosmetic track
}

-- Dev products (must never grant power)
Economy.Products = {
	Clout = 0,
	CosmeticCrate = 0,
	Respect = 0, -- end-of-round gesture for the winner
}

-- Cosmetic price ladder: cheapest entry point is deliberately tiny.
Economy.PriceTiers = {
	{ Id = "Charm", Min = 0, Price = 25 },
	{ Id = "Flair", Min = 750, Price = 75 },
	{ Id = "Signature", Min = 3000, Price = 199 },
	{ Id = "Announcer", Min = 8000, Price = 349 },
}

-- Categories the cosmetic system will grow into. None of these affect gameplay.
Economy.CosmeticSlots = {
	"VoteCardSkin",
	"KillEffect",
	"Trail",
	"BannerFrame",
	"Emote",
	"Announcer",
	"VictoryPose",
	"NameColor",
}

return Economy
