# Monetisation

Ordered by expected return on effort. **Nothing here grants gameplay power, and nothing here
can be exchanged for vote weight.**

## The line

> The vote is the product. A purchasable vote destroys the product.

Concretely, these are forbidden forever, not "for now":

* Buying vote weight, extra votes, or a veto.
* Buying in-round advantage: health, damage, speed, weapons, respawns, better crates.
* Selling the *outcome* of a vote, or the modifier pool, or the arena choice.
* Anything randomized without disclosed odds and a direct-purchase alternative.
* Ads shown to a player who has not opted in, or to anyone the policy API says cannot see them.

Everything below is cosmetics, convenience, vanity, or *the game being good enough that people
stay*.

## 1. Speaker Pass — game pass

Cosmetic flair, a golden vote-card skin, a lobby title, a custom announcer, the lobby practice
range, priority into full servers. Sold once, permanent. **Not** vote weight, not a queue skip
that affects match quality for others.

## 2. Seasonal Decree Pass — the primary long-term earner

Free track + premium track, progressed by playing (not by paying). Rewards are cosmetics and
Clout. Each month's theme ships with a themed modifier pack and arena art, so the pass and the
content pipeline are the same project. This is the format that actually earns on Roblox; it is
also the one that most needs a visible weekly update cadence behind it.

## 3. Rewarded video — native format only

Opt-in, 13+, ad-eligible players, one clearly-labelled offer at the results screen: *double your
Clout for this match*. Maybe a cosmetic crate spin as a second placement.

* Use Roblox's **native rewarded video integration**, not a bespoke ad implementation
  (independent implementations have been deprecated).
* Eligibility is gatekept: the creator needs an ID-verified 13+ account, and the *player* must be
  ad-eligible. Confirm the current requirements against Roblox's documentation at build time —
  do not code from memory.
* Daily cap in `Economy.RewardedVideo.DailyCap`.
* `Economy.Enabled = false` and zero ids means the service prompts nothing. **A placeholder id
  must never be able to charge anyone.**

## 4. Premium Payouts — passive

Roblox pays creators based on Premium members' engagement. The session-length and retention work
in `05-BRAND.md` raises this automatically; there is nothing else to build.

## 5. Private servers — surprising second earner

Eight friends in a hosted match with a host-controlled modifier pool, plus the "host picks from
four" rule. Roblox pays creators for private server subscriptions, it needs almost no code, and
it feeds the **intentional co-play days** ranking signal, which is a scored discovery metric.
Highest return per hour of work in this list after the pass.

## 6. UGC

MAJORITY RULES wearables (hats, a Clerk plush accessory, shirts), then a mirror pipeline where an
in-game cosmetic also grants the UGC equivalent. Needs an audience to be worth the modelling
time — it is a month-three item, not a launch item.

## 7. Sponsored modifiers

"LOW GRAVITY — presented by X" on the vote card, or a sponsored arena skin. This is unique to a
game whose centrepiece is a ballot, and it is the reason a brand would answer an email. Sell it
after there are MAU numbers and a clean brand-safety story; the content must stay inside Roblox's
advertising policies and be visually disclosed as sponsored.

## 8. Respect — an end-of-round gesture

A Robux gesture at the results screen: the tipper gets a cosmetic flair, the winner gets Clout
and a badge.

**Be honest about the mechanics in the UI:** Roblox does not allow paying other players Robux
directly. This is a purchase from the game that awards in-game currency to another player.

## Compliance checklist

Run this before shipping any new monetisation, and re-run it whenever Roblox updates policy.

- [ ] No purchase affects gameplay power, matchmaking fairness, or the vote
- [ ] Anything randomized discloses odds **before** purchase and offers a direct purchase path
- [ ] Every paid prompt is gated behind `PolicyService:GetPolicyInfoForPlayerAsync`
- [ ] `ArePaidRandomItemsRestricted` is respected wherever a random item is sold
- [ ] Off-platform links come only from `AllowedExternalLinkReferences`
- [ ] Ads use the native rewarded video format, are opt-in, and are never shown to players who
      bought an ad-free pass (if one is ever sold)
- [ ] Under-13 experience of the game is complete without spending anything
- [ ] `Economy.Enabled` is only true when every id it references is real and tested in Studio
- [ ] The spend surface is measured (`AnalyticsService.economy`) and reviewed monthly

## What to build first

1. **Speaker Pass + a cosmetic shop** using `Economy.CosmeticSlots` — the smallest thing that
   proves the cosmetic pipeline end to end.
2. **Private servers** — nearly free, and it earns and ranks at the same time.
3. **Rewarded video at results** — biggest reach-per-line-of-code, once eligibility is confirmed.
4. **Seasonal Decree Pass** — only once a weekly content cadence actually exists, because a pass
   with nothing to progress toward is the fastest way to look unfinished.
