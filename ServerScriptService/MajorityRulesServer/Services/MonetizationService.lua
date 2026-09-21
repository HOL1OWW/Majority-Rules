--!nonstrict
--[[
	MonetizationService — deliberately inert until real asset ids exist.

	Two hard rules encoded here:

	  1. `Economy.Enabled` is false and the pass/product ids are 0, so this service refuses to
	     prompt anything. A placeholder id can never charge a player by accident.
	  2. Nothing this service can ever grant touches gameplay. Clout is earned currency;
	     cosmetics are cosmetics; the vote has no price.

	Rewarded video uses Roblox's native Rewarded Video integration only (independent rewarded
	ad implementations are deprecated), and it is gated on both ad eligibility and the
	player's own policy information, because paid random items and off-platform links are
	region and age restricted.

	Phase 6 work: pass prompts, the seasonal Decree Pass, rewarded video placement at the
	results screen, private servers, and the UGC mirror. See docs/06-MONETIZATION.md.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Log = require(Shared.Util.Log)

local MonetizationService = {}

MonetizationService.ready = false

function MonetizationService.policyFor(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok then
		Log.debug("PolicyService unavailable for %s", player.Name)
		return nil
	end
	return info
end

--! Nothing may be shown to a player until we know their region and age policy.
function MonetizationService.canPrompt(player: Player): boolean
	if not Economy.Enabled then
		return false
	end
	if Economy.Passes.Speaker == 0 and Economy.Products.Clout == 0 then
		return false
	end
	local info = MonetizationService.policyFor(player)
	if not info then
		return false
	end
	--! Consumers that sell anything randomized must additionally check
	--! info.ArePaidRandomItemsRestricted, and offer a direct-purchase alternative when it is
	--! true. The vote itself is never purchasable, so this service needs no further gate.
	return true
end

function MonetizationService.promptPass(player: Player, passKey: string)
	if not MonetizationService.canPrompt(player) or Economy.Passes[passKey] == 0 then
		Log.debug("MonetizationService is inert (pass '%s' has no id)", passKey)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Economy.Passes[passKey])
end

--! Rewarded video is the only ad format this game will use, and it is opt-in.
function MonetizationService.promptRewardedVideo(player: Player)
	if not Economy.Enabled or not Economy.RewardedVideo.Enabled then
		Log.debug("Rewarded video not enabled")
		return
	end
	-- Implementation lands in Phase 6 against the native rewarded video API, after the
	-- eligibility requirements are confirmed against the current Roblox documentation.
end

return MonetizationService
