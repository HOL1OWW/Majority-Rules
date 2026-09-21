# 11 — BOTS: CPU combatants for testing

A Roblox experience launches onto **1–3 player servers**, and almost everything this game does only
becomes observable when a second body is in the arena: elimination, kill credit, a round that ends
early because someone ran out of health, a modifier that turns out to be lethal. Testing that by hand
needs two humans — which is exactly what a developer pressing Play does not have.

`BotService` supplies the second body. It is a **test aid**, not a game feature (see "Promoting it"
at the bottom), and it lives behind `DevConfig` so it cannot appear in a live server.

---

## Turning it on

Create `ServerStorage.DevConfig` (in Studio, during a play session — it does not need to be in the
repository) and set attributes:

| Attribute | Value for a bot test | Why |
| --- | --- | --- |
| `BotCount` | `3` | how many bots spawn **each round** |
| `SkipVote` | `true` | pair with a forced modifier so rounds start in seconds |
| `ForceModifiers` | `PistolsOnly` | bots carry the round's loadout, so this decides their weapon |
| `RoundSeconds` | `30` | a short round for a fast loop |
| `TotalRounds` | `2` | shorten the match |

Then press Play. Expect, once per round:

```
[MR] Bots: 3 spawned (weapon=PISTOL, 8 spawn point(s) available)
```

`weapon=none` means the round's loadout has no ranged weapon (a melee-only round): the bots will
close in and hit nobody, which is a faithful reading of the vote and is logged as a warning.

`DevService` ignores every override outside Studio, so `BotCount` in a live server does nothing.

---

## What the bots actually do

They get **no special cases in the rules**:

* the round spawns them and the round destroys them, exactly like a player character
* their weapon is the round's loadout, so `ShotgunsOnly` applies to them too
* their shots go through `CombatService.botFire` → the same `resolveShot` a trigger pull uses: same
  range, pellet count, spread, ricochet flag, spawn protection and elimination rules
* their health and walk speed come from `GameplayService`'s round baseline, so `Sluggish` and
  `SpeedBoost` reach them
* they count as combatants for the round-end rule (`RoundService.aliveCombatants`), which is the point
* they spawn spread across the arena's spawn ring, starting one slot after the player's

Their behaviour is deliberately crude and readable. It is driven by one `Heartbeat` tick per bot:

1. pick the nearest alive player
2. **advance** until they can see them and are within `ENGAGE_RANGE` (40 studs), then hold and face
3. if they have not moved 2 studs in 2 seconds while trying to close, step sideways for a moment and
   resume (a bot that walks straight at cover stands there for a whole round otherwise — measured)
4. fire on the weapon's `FireRate × 2.4`, with an aim error of ~2.2 studs, and only with line of sight

Tuning lives in constants at the top of `BotService.lua`. Aim jitter and fire jitter come from a
`Random.new` seeded off `MatchState.Seed`, so a bot's behaviour is reproducible for a reported seed
even though bots are never part of the match itself.

### What they do not do

* **they do not vote**, and they are not on the ballot or the scoreboard
* **they do not damage each other** — a bot's shot only counts against players, so two bots cannot
  grind each other down while the human is the point of the test
* **they do not pathfind.** There is no `PathfindingService`; movement is straight-line plus the
  sidestep above, so a bot can be held up by a wall it cannot walk around
* **a bot killing a player awards nobody points** (there is no Player to credit). A player killing a
  bot is worth the full `Combat.KillPoints`, same as killing a human
* they are **not in `MatchState`**: no points, no stats, no `PlayerDied` signal, so no modifier that
  reacts to a player death fires for them

### Reading the output

Debug level, so Studio only:

```
[MR] DEBUG Bots: BOT 1 target=whatamihereforfh 21.4 studs los=false ready=false weapon=PISTOL
[MR] DEBUG Bots: BOT 3 is blocked, stepping sideways
[MR] DEBUG Bots: BOT 2 fired at whatamihereforfh from 3.5 studs
[MR] DEBUG Round 1 ended: elimination after 34.9s, 4 alive at the start (3 bot(s))
```

A bot that stands still and silent is indistinguishable from a bot whose AI never ran; these lines are
the difference between reading the reason and guessing at it. `REPORT_INTERVAL` (3s) controls how
often the per-bot decision line appears — raise it if the Output window gets in your way.

---

## Verified behaviour

Measured in one Studio session, 3 bots, `PistolsOnly`, all three rounds ended by **elimination**:

```
Round 1 ended: elimination after 34.9s, 4 alive at the start (3 bot(s))   <- the player killed all 3
Round 2 ended: elimination after 10.4s, 4 alive at the start (3 bot(s))   <- the bots killed the player
Round 3 ended: elimination after 11.7s, 4 alive at the start (3 bot(s))
```

Bot approaches and damage, from a world probe: 52 → 42 → 32 → 24 → 16 → 9 → 2 studs, with the player's
health going 100 → 82 → 65 → 48 → 31 → 14 → 0 in about ten seconds.

Player → bot damage through a real client fire (the actual `WeaponFire` remote), reporting bot health
before and after: `BOT 3 hp=100 → 10`, `BOT 1 hp=100 → 46`, then all three eliminated, and the HUD
showed `1. HOL1OW 6` — three kills plus the round win.

---

## Promoting it to a real feature

Filling an empty server with bots is a product decision, not a rewrite. What would change:

1. the `DevService.get("BotCount", 0)` lookup in `RoundService` becomes a real matchmaking rule
   ("server below N players after X seconds → fill with bots")
2. the UI has to say a bot is a bot — the HUD's alive count already includes them, but the scoreboard
   has no rows for them and nothing labels them
3. bot kills should probably be worth less than player kills, or not count toward a leaderboard
4. `BotService`'s `ENGAGE_RANGE`, aim error and fire-rate scale become difficulty settings

Until then, keep it behind `DevConfig`: the whole point of the flag is that a live match cannot
silently contain bots.
