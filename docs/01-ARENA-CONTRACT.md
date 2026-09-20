# The Arena Contract

**This document is frozen.** Changing it requires an entry in `docs/DECISIONS.md`.

An arena is a **Model** in `ServerStorage.Arenas` that the game can find, host, transform and
reset. It never contains a script, and no script ever references one of its parts by name.
Everything crosses the boundary through **CollectionService tags** and **Attributes**, whose
names are declared once in `src/shared/Tags.lua`.

That single rule is what lets three humans and several map-building AIs work at the same time
without breaking the game: **the map cannot see the code, and the code cannot see the map.**

---

## 1. The rule that matters most

> If you are about to write a script that looks up a part by name, or a map that needs a
> script to work, you have found a missing tag or attribute. Add it to `Tags.lua` and log it in
> `DECISIONS.md` — do not work around the contract.

---

## 2. Arena root

The arena root is a `Model` tagged **`MRArena`** with these attributes:

| Attribute | Type | Required | Notes |
| --- | --- | --- | --- |
| `ArenaId` | string | yes | Stable id used by logs, analytics and the dev override. Matches the file name. |
| `DisplayName` | string | yes | Shown in UI, e.g. `THE FOUNDRY`. |
| `MinPlayers` | number | yes | Arena is not eligible below this player count. Usually 1. |
| `MaxPlayers` | number | yes | **The validator requires at least this many spawn points.** 1–8. |
| `SizeClass` | string | yes | `Tiny` / `Small` / `Medium` / `Large`. Modifiers filter on it. |
| `FeatureTags` | string | yes | Comma list. Modifiers' `Requires`/`Bans` match against these. |
| `FloorY` | number | recommended | Y of the playing surface. Used by spawn and hazard checks. |
| `Weight` | number | yes | Relative chance of being picked (default 10). |
| `BannedModifiers` | string | optional | Comma list of modifier ids this arena must never offer. |

**Feature tags the engine understands** (anything else is ignored, and the validator warns):

`Cover` `Vertical` `Hazard` `Lava` `FlatFloor` `Tiles` `Indoor` `Water`

Declare them honestly. A modifier that `Requires FlatFloor` will never appear on an arena that
does not declare it, and the FLOOR-SCALING modifiers will look broken if the floor is not flat.

---

## 3. Required folder structure

```
Arena (Model, tagged MRArena)
├── Geometry/            parts tagged MRArenaStatic — decoration, never transformed
├── Transforms/          the parts modifiers are allowed to touch
│   ├── Floor/           TransformGroup "Floor" (+ "Tile_n" if the floor is tiled)
│   ├── Walls/           TransformGroup "Wall"
│   └── Cover/           TransformGroup "Cover", AnchorState "Hidden"
├── Spawns/              parts tagged MRArenaSpawn, SpawnIndex 1..n
├── LootPoints/          parts tagged MRLootPoint
├── Hazards/             parts tagged MRArenaHazard (optional)
├── VoteShowcase/        >=3 parts tagged MRVoteCamera with Order, + 1 MRVoteNameplate
├── VFX/                 emitters tagged MREmitter (optional but strongly encouraged)
├── Audio/               sounds tagged MREmitter (optional)
└── Variants/            one Model per hand-authored modifier override (optional)
```

Folder names are conventional; **tags are authoritative.** A part works because it is tagged and
attributed, not because it sits in the right folder.

---

## 4. Transformable parts

Every part a modifier may move, scale or hide must be:

* tagged **`MRArenaTransformable`**
* **anchored**
* given a `TransformGroup` — a **comma-separated list**, so one part can belong to several
  groups at once

| Attribute | Type | Notes |
| --- | --- | --- |
| `TransformGroup` | string | e.g. `"Floor,Tile_3"` — the floor as a whole, and this tile individually. |
| `CanScale` | bool | Declares intent. Informational for tooling; not yet enforced. |
| `CanHide` | bool | Same. |
| `CanMorph` | bool | Same. |
| `AnchorState` | string | `Shown` or `Hidden`. Hidden parts load invisible and non-colliding. |

### Group names modifiers already use

| Group | Used by | Meaning |
| --- | --- | --- |
| `Floor` | Small Map, Ice Floor, Bouncy Floor | The whole playing surface. Scale it, change its physics. |
| `Wall` | Small Map, Shrinking Arena | The perimeter. Scaled inward to shrink the arena. |
| `Cover` | Cover Drops | Cover pieces, authored `AnchorState = "Hidden"`. |
| `Tile_n` | Collapsing Floor | Individual floor tiles. `n` is numeric and must run 1..n with no gaps. |
| `Lava` | Rising Lava | The hazard volume, authored below the floor and invisible. |

If you invent a new group, add it to this table and tell the systems track — that is how the
catalogue stays honest.

---

## 5. Spawns

* Parts tagged **`MRArenaSpawn`**, `SpawnIndex` 1..n, `CanCollide = false`, usually
  `Transparency = 1`.
* At least `MaxPlayers` of them, **at least 8 studs apart** (the validator enforces both).
* Spawn height comes from `Combat.SpawnHeightOffset`; put the part at floor level and the engine
  lifts the character.
* Players are placed by a deterministic rotating cursor, so consecutive spawns walk around the
  ring rather than stacking.

---

## 6. Loot points

* Parts tagged **`MRLootPoint`**, invisible, non-colliding.
* Attributes: `LootWeight` (relative chance), `ClearanceRadius` (how much open space a crate
  needs, used by tooling), `Zone` (free-form label, e.g. `Ring`, `Upper`).
* 4–8 points is the sweet spot. More than 12 and the arena stops having contested space, which
  is where weapon crates get their meaning.

---

## 7. Hazards

* Parts tagged **`MRArenaHazard`** with `HazardType` = `Lava` / `Void` / `Trampoline` /
  `Conveyor`.
* Hazards are **volumes**: `CanCollide = false`, authored `Transparency = 1`, usually below the
  floor, and switched on by a modifier.
* Damage is applied by the engine, not by the map. A hazard that is switched on hurts everyone
  in it at `Combat.HazardDamagePerSecond`.

---

## 8. Vote showcase

* **≥3 parts** tagged **`MRVoteCamera`** with a unique `Order` (1, 2, 3, …). Each is a camera
  position *and orientation*: the cinematic lerps between their CFrames in `Order`.
  Compose them like a shot list — a wide establishing shot, then something closer and lower.
* **Exactly one** part tagged **`MRVoteNameplate`**, ideally high up and facing the arena. The
  engine writes the winning modifier names into its `Text` attribute; the client draws them.
  A physical verdict sign in the world is worth more than a HUD element that fades.
* If you provide no cameras the engine falls back to a generated ring, which will look generic.
  The validator fails an arena with fewer than three.

---

## 9. Emitters: authoring a modifier's atmosphere

This is the cheapest parallel-work win in the whole project.

Tag a `ParticleEmitter`, `Beam`, `Trail` or `Sound` — or a container part holding them — with
**`MREmitter`**, and give it an attribute:

```
OnModifier = "Fog,Blackout"
```

Whenever a round runs with `Fog` or `Blackout` applied, those emitters switch on; the rest of
the time they are off. The engine does nothing else — it does not know what a fog bank is.

**So the map team can upgrade the look of every modifier in the game without touching a line of
script.** Want Lightning to have arc flashes? Author the emitter. Want Low Gravity to have dust
motes hanging in the air? Author the emitter. Same for audio beds.

---

## 10. Variants: hand-authored modifier overrides

Ship a model at `Variants/<ModifierId>` and it **replaces that modifier's procedural geometry
steps** for this arena, while keeping everything else the variant cannot express (gravity,
lighting, loot, combat, hazards).

```
Variants/
└── SmallMap/           # replaces SmallMap's floor and wall scaling on this arena
    ├── Geometry/        parts shown while the variant is active
    ├── Spawns/          optional: spawn override used while active
    └── LootPoints/      optional: loot override used while active
```

The rules, exactly:

1. Procedural `floorGeometry`, `walls` and `cover` steps for that modifier are **dropped**.
2. Everything else the modifier does (gravity, `loot`, `combat`, ...) still runs.
3. The variant is shown during the transform and the arena's `Geometry/` folder is hidden.
4. `ArenaService.reset()` restores the normal state between rounds, every round.

This means the systems track ships a working procedural transform for every modifier on day
one, and the map track upgrades them one at a time by authoring art. **Neither ever blocks the
other** — which is the entire reason this project can have several authors at once.

---

## 11. Budgets and performance

| Budget | Value | Why |
| --- | --- | --- |
| Parts | ≤ 2,500 | The transform moves parts; the drift modifier moves all of them. |
| Triangles | ≤ 250,000 | Mobile floor. |
| Geometry style | anchored, no runtime unions | Unions at runtime are a frame-time cliff. |
| Streaming | handled by the engine | The loaded arena is `ModelStreamingMode.Atomic`. |

Prefer a few large MeshParts over many small ones, and share materials across the arena so the
engine can batch draws.

---

## 12. Before you merge: run the validator

```
-- Studio command bar, or via the Roblox Studio connector
local Validator = require(game.ServerStorage.Tools.ArenaValidator)
print(Validator.reportAll())          -- every arena
print(Validator.report(game.ServerStorage.Arenas.Foundry))  -- one arena
```

A failing arena is not merged. This applies to humans and to AIs equally — it is the only
mechanism that keeps several contributors compatible.

It checks, among other things: the root tag and required attributes, spawn count and spacing,
loot point presence, transform groups on every transformable, valid `AnchorState`s, anchored
geometry, no scripts inside the model, hazard types, ≥3 uniquely ordered vote cameras, feature
tags actually backed by geometry (declaring `Cover` with no `Cover` group is an error), and the
part budget.

---

## 13. Arena checklist

Copy this into your pull request.

- [ ] Root tagged `MRArena`, all required attributes set honestly
- [ ] `FeatureTags` list matches the geometry that actually exists
- [ ] `Transforms/` groups present: `Floor`, `Wall`, `Cover`, `Tile_n`, `Lava` as applicable
- [ ] Cover pieces authored `AnchorState = "Hidden"`
- [ ] Spawns ≥ `MaxPlayers`, ≥8 studs apart, indexed from 1
- [ ] 4–8 loot points, inside the arena, above the floor
- [ ] Hazards authored invisible, non-colliding, below the floor
- [ ] ≥3 vote cameras with unique `Order`, composed as an actual shot list
- [ ] Exactly one nameplate, facing the arena
- [ ] Emitters tagged with sensible `OnModifier` lists
- [ ] No scripts, no unanchored geometry, `PrimaryPart` set
- [ ] `ArenaValidator` reports PASS
- [ ] Saved as `assets/arenas/<ArenaId>.rbxmx` and committed
