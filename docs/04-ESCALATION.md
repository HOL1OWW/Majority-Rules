# Escalation

The ramp from "one gentle twist" to "three stacked chaos modifiers" is the single biggest
reason a match feels like a match rather than a loop of unrelated rounds. It is configured in
`src/shared/Config/Escalation.lua` — data, not code.

## The rule that makes stacking work

`Cands` is how many cards are on the ballot. **`MaxStacked` is how many of the top finishers
actually apply.** In round 1 that is one card; by round 6 it is three.

This is why a vote for a card that comes second is not wasted, and why the escalation reads as
a negotiation instead of a plurality race. It also means **any two cards on a ballot might both
end up applying**, so the ballot draw guarantees no two cards contradict each other
(`Modifiers.draw` → `candidatePool` → `Modifiers.conflicts`).

## Full format — 4+ players, 6 rounds

| Round | Cards | Applied | Tier pool | Length | Label | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 3 | 1 | 1 | 75s | WARM UP | No hazards, no stacking |
| 2 | 3 | 1 | 1–2 | 70s | FIRST READING | |
| 3 | 3 + Gamble | 2 | 1–2 | 65s | SECOND READING | Stacking begins |
| 4 | 4 + Gamble | 2 | 1–3, one forced T3 | 60s | POINT OF ORDER | Cover and hazards unlock |
| 5 | 4 + Gamble | 3 | 1–3, one forced T3 | 55s | THE FLOOR | |
| 6 | 4 + Gamble | 3 | 1–3, one forced T3 | 50s | THE VERDICT | Cinematic camera, gold UI |

## Skirmish format — 1–3 players, 3 rounds

Exists for one reason: **a new Roblox experience gets 1–3 player servers**, and a lone player's
arena must still transform inside 60 seconds of them joining. Making someone wait for a lobby to
fill is how you lose them in the first minute, which is the heaviest-weighted discovery signal
there is.

| Round | Cards | Applied | Tier pool | Length | Label |
| --- | --- | --- | --- | --- | --- |
| 1 | 2 | 1 | 1 | 60s | HOUSE DECREE |
| 2 | 3 | 2 | 1–2 | 55s | SECOND READING |
| 3 | 3 | 2 | 1–2 | 50s | THE VERDICT |

Format selection: `Escalation.formatForPlayerCount(n)` — under 4 players is Skirmish, 4+ is Full.

## Ballot construction

1. Filter the registry: tier pool ∩ `MinRound`/`MaxRound` ∩ arena `FeatureTags` against each
   modifier's `Requires`/`Bans` ∩ the arena's `BannedModifiers`.
2. Drop anything conflicting with an already-chosen card (symmetric, id or category tag).
3. Ensure tier coverage: round 4+ takes one tier-3 card first, so the round has teeth even if
   the weighted draw would have gone gentle.
4. Weighted-sample the rest without replacement.
5. Round 3+ appends the **Gamble** card if there is space. Voting for it hands the choice to the
   machine, which then draws a real modifier from the full pool respecting the other winners.
6. A queued **Objection** injection (trailing player's wildcard) is appended if it is not
   already present.

## Timings

| Beat | Default | Notes |
| --- | --- | --- |
| Vote open | 20s (12s Skirmish) | Ends early if everyone has voted |
| Vote lock | 2s | "Pens down" — tallies freeze, visible |
| Tie-break revote | 5s | Only on a genuine tie at the cut line |
| Reveal | 2.5s | Winner announced, before the transform |
| Transform | ≤4.5s hard cap | Steps run in phases; the cap protects the round |
| Countdown | 3s | 3 · 2 · 1 · FIGHT |
| Live | 50–75s by round | Ends early when ≤1 player remains, but only in a round that began with more |
| Round end | 8s | Results screen |
| Match end | 15s | Standings, then a new match |

### When a round is allowed to end early

`Combat.MinAliveToContinue` is 1, so a round ends the moment ≤1 player is left — **provided the
round began with more than that**. The "began with" half is not a formality: with a single player
alive, the survivor check is true on the round's first tick, so a solo round returned as an
`elimination` about a quarter of a second in. The Full format picks Skirmish below 4 players and a
new experience serves 1–3 player servers, which means **that was the first-run experience**: a lone
player watched the arena transform, saw a results screen, and never played a round at all.

A solo round now runs its full length and is won on the `timeout` rule (healthiest survivor), which
is what `RoundService` already awarded at the deadline. Verification, in Studio only: the server
logs `Round N ended: <reason> after <t>s, <n> alive at the start` at debug level, so an early exit
and a full-length round are distinguishable without guessing.

## Tie-breaks

A tie only *matters* when more cards are tied at the cut line than there are slots — three cards
tied for three slots is a unanimous ballot, not a tie.

1. **Sudden-death revote**, restricted to the tied cards, 5s. (Up to twice.)
2. If it ties again, **a seeded coin flip decides, on stream**, and the card visibly moves to the
   front of the tally. The randomness comes from the match seed, so a reported match can be
   replayed exactly.
3. A ballot where **nobody voted** is decided by the house: the top finishers still apply, and
   the UI says so. The arena always transforms. There is no state in which the game stalls
   waiting for input.

## Dev overrides

`DevService` reads attributes on `ServerStorage.DevConfig` (Studio only): `ForceModifiers`,
`SkipVote`, `RoundSeconds`, `VoteSeconds`, `TotalRounds`, `ArenaId`, `StartingRound`. Use
`StartingRound = 5` to jump straight to a three-stack chaos round while testing.
