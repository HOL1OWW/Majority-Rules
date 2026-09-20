# Brief for a map-building AI

Paste this whole file into the agent, then fill in the TASK block at the bottom. It is written to
be self-contained: an agent that has never seen this project should be able to produce one valid
arena from it.

---

## What you are building

Arena geometry for a Roblox experience called **MAJORITY RULES**. Eight players stand in a plain
empty arena, vote on one modifier, and the arena **physically rebuilds itself** — floors scale,
cover rises out of the ground, gravity shifts, lava climbs. Then they fight in it. Six rounds,
escalating to three stacked modifiers.

You are building one arena. You are not writing any code, and you must not.

## The one rule

**Your arena is geometry, tags and attributes. Nothing else.**

* No `Script`, `LocalScript` or `ModuleScript` inside the arena model. Ever. This is checked and
  the arena will be rejected.
* No part is ever referred to by name by the game. The game finds things by **CollectionService
  tag** and reads **Attributes**. If you put a part in the wrong folder but tag it correctly, it
  still works. If you name it beautifully and tag it wrong, it does not exist.
* All geometry must be **anchored**.

## The exact structure

```
Arena (Model, tagged MRArena)
├── Geometry/       decoration only, tagged MRArenaStatic
├── Transforms/     the parts the game is allowed to move
│   ├── Floor/      TransformGroup "Floor"  (+ "Tile_n" if tiled)
│   ├── Walls/      TransformGroup "Wall"
│   └── Cover/      TransformGroup "Cover", AnchorState "Hidden"
├── Spawns/         tagged MRArenaSpawn
├── LootPoints/     tagged MRLootPoint
├── Hazards/        tagged MRArenaHazard
├── VoteShowcase/   tagged MRVoteCamera (>=3, unique Order) + one MRVoteNameplate
├── VFX/            emitters tagged MREmitter with an OnModifier attribute
├── Audio/          sounds tagged MREmitter with an OnModifier attribute
└── Variants/       leave empty unless told otherwise
```

## Root attributes (Model)

| Attribute | Type | Value |
| --- | --- | --- |
| `ArenaId` | string | must match the model name |
| `DisplayName` | string | uppercase, e.g. `THE FOUNDRY` |
| `MinPlayers` | number | usually 1 |
| `MaxPlayers` | number | must be ≤ the number of spawn points |
| `SizeClass` | string | `Tiny` / `Small` / `Medium` / `Large` |
| `FeatureTags` | string | comma list, see below — **only declare what actually exists** |
| `FloorY` | number | Y of the playing surface |
| `Weight` | number | 10 unless told otherwise |

**Feature tags:** `Cover` `Vertical` `Hazard` `Lava` `FlatFloor` `Tiles` `Indoor` `Water`.

Declaring a feature you do not have is an **error** the validator will catch (e.g. `Cover` with no
parts in a `Cover` group). Declaring too few silently removes modifiers from the ballot.

## Transformable parts

Tagged `MRArenaTransformable`, anchored, with:

| Attribute | Value |
| --- | --- |
| `TransformGroup` | comma list of group names, e.g. `Floor` or `Floor,Tile_3` |
| `CanScale` / `CanHide` / `CanMorph` | `true` where the game may scale / hide / swap it |
| `AnchorState` | `Shown`, or `Hidden` for things that start absent (cover, lava) |

Groups the game already drives:

| Group | The game will | Authored state |
| --- | --- | --- |
| `Floor` | scale the whole surface, change its physics and material | shown |
| `Wall` | scale the perimeter inward to shrink the arena | shown |
| `Cover` | reveal it | **hidden** |
| `Tile_n` | hide tiles one at a time, in numeric order, no gaps | shown |
| `Lava` | raise it, switch it on | **hidden**, below the floor |

**Floor design matters more than decoration.** A tiled floor (say 6×6 tiles, each listing
`"Floor,Tile_7"`) gives the game both "shrink the arena" and "the floor falls away" for free. A
floor made of one enormous union cannot do either.

## Spawns

Tagged `MRArenaSpawn`, `SpawnIndex` numbered from 1, invisible, non-colliding, **at least 8 studs
apart**, at least `MaxPlayers` of them (the validator fails an arena that has fewer than it claims
to support). Put them at floor level — the engine lifts characters.

## Loot points

Tagged `MRLootPoint`, invisible, non-colliding, 4–8 of them, inside the arena, above the floor.
Attributes: `LootWeight` (10), `ClearanceRadius` (8), `Zone` (a label like `Ring` or `Upper`).

Their placement is a design decision: crates in the open are contested, crates in corners are
safe and boring. 4–8 contested points is better than 14 scattered ones.

## Hazards (optional)

Tagged `MRArenaHazard`, `HazardType` = `Lava` / `Void` / `Trampoline` / `Conveyor`, invisible,
**non-colliding** (they are volumes), authored below the floor. `Transparency = 1`.

## Vote showcase (required)

* **≥3 parts** tagged `MRVoteCamera` with unique `Order` attributes. Each is a camera **position
  and orientation**; the game lerps between them in order. Compose them like a shot list: a wide
  establishing shot, then something lower and closer, then a high hero angle.
* **Exactly one** part tagged `MRVoteNameplate`, high up, facing the centre. The game writes the
  winning modifier's name into its `Text` attribute and the client renders it. Make it big enough
  to read from the play space — it is the physical verdict sign.

## Emitters: the best value work in this whole brief

Tag a `ParticleEmitter`, `Beam`, `Trail` or `Sound` — or a container part holding them — with
`MREmitter`, then set:

```
OnModifier = "Fog,Blackout"
```

When a round runs with those modifiers, those emitters switch on. The engine does not know what
fog is; it only toggles. **That means you can author the look of a modifier without anyone
writing any code.**

Examples worth building: fog banks for `Fog`/`Blackout`, dust motes for `LowGravity`, heat shimmer
and steam for `RisingLava`, snow for a winter theme, and a low rumble bed for `MovingArena`.

## Budgets

≤ 2,500 parts, ≤ 250,000 triangles, anchored only, no runtime unions, share materials. Mobile is
a first-class target, and the transform pipeline moves parts at runtime, so part count is not
free.

## Before you hand it back

Run the validator and include its output in your response:

```lua
local Validator = require(game.ServerStorage.Tools.ArenaValidator)
print(Validator.reportAll())
```

It checks the root tag and attributes, spawn count and spacing, loot points, transform groups,
anchor states, unanchored geometry, scripts inside the model, hazard types, the vote camera set,
feature tags backed by real geometry, and the part budget.

**A report with errors in it is an unfinished deliverable.** Fix them and re-run.

## What to send back

1. The arena Model (as `.rbxmx`, or built in Studio at `ServerStorage.Arenas/<ArenaId>`).
2. The full `ArenaValidator` report — it must say PASS.
3. A one-paragraph note on the **design intent**: what fights well here, which groups exist, which
   feature tags you declared, and what the vote camera shots are meant to show.
4. Anything you could not express with the tags above. Say so explicitly rather than inventing a
   private convention — that is how the contract grows.

---

## TASK

*(Fill this in before sending.)*

* **ArenaId / DisplayName:**
* **Size class, play space dimensions:**
* **Theme / visual brief:**
* **Feature tags to declare:**
* **Layout intent** (sightlines, chokepoints, verticality, how many contestable areas):
* **Transform groups required, and what they should look like when changed:**
* **Camera shot list intent (3–5 shots):**
* **Emitters to author, and which modifiers they belong to:**
