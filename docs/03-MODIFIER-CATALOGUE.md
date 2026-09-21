# Modifier catalogue

**Implemented: 23.** Target for launch: 40+. Every row is one file in
`src/shared/Modifiers/TierN/`.

Legend: **T** = tier · **W** = draw weight · **Req** = required arena feature ·
**Conflicts** = cannot be drawn alongside.

---

## Tier 1 — warm up (single modifier, low stakes)

| T | Id | Card text | W | Req | Conflicts | Effects |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `LowGravity` | Everyone floats. Fights go vertical. | 12 | — | `Gravity` | GravityDown, AirTime |
| 1 | `HighGravity` | You are heavy now. Good luck jumping. | 10 | — | `Gravity` | GravityUp |
| 1 | `Fog` | Thick fog. You will hear them before you see them. | 12 | — | `Vision` | VisionLimited |
| 1 | `Blackout` | Lights out. Fight by muzzle flash. | 9 | — | `Vision` | VisionLimited, Darkness |
| 1 | `ShotgunsOnly` | Close range. Every fight is a decision. | 12 | — | `Loadout` | LoadoutOverride |
| 1 | `PistolsOnly` | Small guns. Big nerves. | 11 | — | `Loadout` | LoadoutOverride |
| 1 | `MeleeOnly` | No guns. Just judgement. | 9 | — | `Loadout` | LoadoutOverride, NoRanged |
| 1 | `SpeedBoost` | Everyone gets faster. Aiming gets harder. | 11 | — | `SlowWalk` | FastWalk |
| 1 | `Sluggish` | Everyone is slow. Positioning is everything. | 9 | — | `FastWalk` | SlowWalk |
| 1 | `NoJump` | Grounded. You walk everywhere now. | 10 | — | — | NoJump |
| 1 | `InfiniteAmmo` | Never reload again. | 10 | — | — | InfiniteAmmo |

## Tier 2 — spice (stacking begins from round 3)

| T | Id | Card text | W | Req | Conflicts | Effects |
| --- | --- | --- | --- | --- | --- | --- |
| 2 | `SmallMap` | The arena shrinks. Contact is immediate. | 10 | FlatFloor | `Shrink` | Shrink |
| 2 | `CoverCrates` | Cover slams up out of the floor. | 11 | Cover | — | Cover |
| 2 | `IceFloor` | Slippery. You cannot stop, only steer. | 9 | FlatFloor | NoJump, Sluggish, `Shrink` | ZeroFriction |
| 2 | `BouncyFloor` | The floor bounces. Aim while airborne. | 9 | FlatFloor | — | Bouncy |
| 2 | `DoubleJump` | Jump again in mid-air. | 11 | — | NoJump | AirJump |
| 2 | `Fragile` | One good shot is all it takes. | 10 | — | — | LowHealth |
| 2 | `Vampire` | Damage you deal heals you. Get closer. | 9 | — | — | Lifesteal |
| 2 | `ShrinkingArena` | The walls creep in. The round has a clock now. | 9 | FlatFloor | `Shrink` | Shrink |

## Tier 3 — chaos (rounds 4–6)

| T | Id | Card text | W | Req | Conflicts | Effects |
| --- | --- | --- | --- | --- | --- | --- |
| 3 | `RisingLava` | The floor is lava. It is climbing. | 10 | Hazard, Lava | `Shrink`, `Collapse` | Hazard, Lava |
| 3 | `CollapsingFloor` | The floor is leaving. Do not be standing on it. | 10 | Tiles | `Shrink`, ZeroFriction | Collapse |
| 3 | `Ricochet` | Bullets bounce once. Corners are lethal. | 9 | — | MeleeOnly | Ricochet |
| 3 | `MovingArena` | The whole arena is drifting. Compensate. | 8 | — | — | Drift |
| 2 | `Gamble` | Nobody knows. The machine decides. Probably something awful. | — | — | — | Gamble (pseudo-card, not a real modifier) |

`CollapsingFloor` removes a batch **derived from the arena's tile count** rather than one tile per step, so
60% of the floor goes in roughly 30 seconds on any arena. On the 16-tile arena it was tuned against that is
still one tile per 3.5s. See D-029.

---

## Next up (planned, not implemented)

These are the highest-value additions by expected fun-per-hour of work. Anyone can take one —
**one file, one author, one PR.**

**Tier 1:** `LowGravity+BouncyCombo`? No — instead: `LoudFootsteps` (audio-led), `BigTargets`
(increased hitbox), `OneEyeOpen` (screen vignette), `TinyPlayers`, `HealOnKill`, `RandomLoadout`.

**Tier 2:** `Duos` (temporary teams, needs a team capability), `Juggernaut` (one player buffed,
everyone else hunts them — needs `ctx.Gameplay` per-player overrides to shine), `GravityFlip`
(walking on the ceiling — needs a real capability, log a DECISION), `TurretDrop` (AI turrets),
`GrenadeRain`, `NoRadar`, `TrapDoors` (map-authored, hazard-driven).

**Tier 3:** `ArenaFlips` (invert the whole arena: capability needed), `BossRush` (server AI boss),
`SplitArena` (two arenas, two votes — a big one, likely a mode rather than a modifier),
`MinigunRain`, `TeleportPulse`, `MirrorMode`, `SuddenDeathTimer`.

**Themed Decree packs** (monthly, cosmetic + modifier bundles): Winter Decree (Ice Floor,
Blizzard, Snowball Launchers), Foundry Decree (heat, steam vents, conveyor belts), Deep Decree
(water level rising, low visibility, harpoon-only).

---

## Modifier pruning

Modifiers are data-pruned, not sacred. `docs/05-BRAND.md` covers presentation; this is
balance:

* Track **per-modifier round quit rate** and **post-transform kill rate** from analytics.
* A modifier nobody dies in, or that correlates with players leaving, gets reworked or cut.
* A modifier that wins the vote too often is boring; adjust `Weight`, not its effect.
* Findings live in this document, under the table, with dates. Nobody remembers why a weight
  changed six weeks ago, and an AI agent writing a new modifier needs to know.
