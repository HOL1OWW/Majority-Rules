# MAJORITY RULES — the one-pager

**Experience:** MAJORITY RULES 🗳️ Vote The Arena · placeId `72737093276287`

## What it is

Eight players load into a totally plain, empty arena. No cover, no weapons visible. A prompt
appears: everyone votes on **one modifier** — low gravity, fog, shotguns only, rising lava.
Whatever gets the most votes, the arena **physically rebuilds itself in front of them**. The
floor scales, the gravity shifts, cover slams up out of the ground, crates appear. Then the
round starts.

Six rounds, and every round gets wilder: one modifier, then two, then three stacked at once,
ending in a round announced as **THE VERDICT**. Every match looks and plays differently because
the players authored it.

## The fantasy

Not "I survived the map." It is **"I built the trap that killed you, and I can prove it with the
vote tally."** The vote is the content generator and the social engine at the same time: a
3-second social argument with a physical consequence you are standing inside of.

## Three pillars

1. **The vote must feel like a decision with consequences.** Live tallies, avatars on the card
   you chose, an honest tie-break, and a stalemate that is never resolved silently.
2. **The transformation must be a spectacle.** This is the product. A three-second cinematic
   where the arena rebuilds itself is the thing players screenshot, clip and send to friends.
3. **Escalation must ramp.** Round 1 is one gentle twist. Round 6 is three stacked chaos
   modifiers. The ramp — not the modifier list — is what makes a match feel like a match.

Working rule for every feature decision: **nothing in this game is static except the lobby.**

## Why it comes back

* **Modifier mastery:** win rounds of each modifier to unlock titles. A collection loop that
  doubles as the tutorial, and the reason to return on day 12 rather than day 1.
* **The Oracle stat:** how often your pick actually won. Makes the vote a long-term game.
* **The Objection:** the trailing player gets one wildcard per match to force a card onto the
  ballot. A comeback lever nobody can buy.
* **Monthly Decree themes** and player-submitted modifiers, credited on the card.

## Why it earns without selling power

Cosmetics, a seasonal pass, and opt-in rewarded video at the results screen. **Never vote
weight. Never in-round advantage. No exceptions** — the vote is the product, and a purchasable
vote destroys it. Full detail and the compliance checklist are in `06-MONETIZATION.md`.

## Non-negotiables

* **Server-authoritative.** Damage, votes, spawns, points and transforms are decided on the
  server. Clients render.
* **The arena must transform within 60 seconds of a player joining, even solo.** First-play
  bounce is the discovery signal that matters most, and a new experience gets 1–3 player
  servers. That is why the Skirmish format and the House Decree exist.
* **The map and the script only ever touch through tags and attributes.** See
  `01-ARENA-CONTRACT.md`.
* **A modifier is a file**, not an edit to five systems. See `02-MODIFIER-API.md`.

## Where the name and the look go

`05-BRAND.md`. Short version: bureaucracy gone feral — clean government-paperwork UI that has
lost its mind, a stamp-happy mascot called **the Clerk**, and one violent accent colour reserved
for the moment the vote lands.
