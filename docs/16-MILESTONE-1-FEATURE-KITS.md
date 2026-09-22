# Milestone 1 — Feature Kits and the Restyle Guide

**Status:** scaffolding complete in the Foundry and verified live; hand-restyle open to you and your brother.
**Related:** `01-ARENA-CONTRACT.md`, `13-ARENA-DESIGN.md`, `DECISIONS.md` D-057.

---

## What shipped

The Foundry now carries three tagged kits. All three were verified in one live round
(force-applied via `DevConfig`): cover rose, 15 of 25 tiles collapsed on the planned
pacing, lava sheet rose and dealt damage — zero errors. A follow-up probe confirmed the
D-057 reveal fix: revealed cover is visible + solid + **queryable** (blocks bullets).

| Kit | Parts | Contract wiring | Unlocks |
|---|---|---|---|
| Collapsing floor tiles | 25 (5×5 grid, 96×96 studs each) | `TransformGroup = "Floor,Tile_<n>"` + `MRArenaTransformable` | `Tiles`, keeps `FlatFloor` → **CollapsingFloor**, keeps SmallMap/ShrinkingArena scaling seamless |
| Hidden cover | 10 low walls in `Geometry/Hidden_Cover` | group `Cover`, `AnchorState = "Hidden"` at final positions + `MRArenaTransformable` | `Cover` → **CoverCrates** |
| Hazard volume | lava sheet in `Geometry/Lava` | group `Lava`, tag `MRArenaHazard`, `HazardType = "Lava"`, hidden below floor | `Hazard` + `Lava` → **RisingLava** |

**Ballot effect:** before Milestone 1, `FeatureTags` was nil so every modifier with a
`Requires` clause was silently excluded — 7 modifiers never appeared. Now
`FeatureTags = "FlatFloor, Tiles, Cover, Hazard, Lava"` on the Foundry root makes
**23 of 23 modifiers eligible** (+44% ballot variety).

---

## The restyle guide — what to change by hand, and what not to touch

You may restyle anything visually. The contract only cares about four things.

### Never touch (the kit skeleton)

1. **Tags and attributes** on kit parts: `MRArenaTransformable`, `MRArenaHazard`,
   `TransformGroup`, `AnchorState`, `HazardType`. Restyle by selecting the *part*, not
   re-creating it. If you must rebuild a part, copy its Attributes window first.
2. **The tile grid topology:** keep exactly 25 tiles, keep the `Tile_1..25` names and the
   `Floor,Tile_<n>` attribute on each. CollapsingFloor paces by grid index.
3. **Spawn clearance:** nothing taller than ~2 studs within 8 studs of any `MRArenaSpawn`.
4. **Root stamps:** `MRArena` tag, `ArenaId`, `MaxPlayers`, `FeatureTags`, `FloorY` on the
   Foundry model itself.

### Safe to restyle freely

- **Materials and colors** of tiles: the grid is deliberately neutral gray. Suggested
  direction: darker seams between tiles (a thin inset border material or texture), so the
  5×5 grid reads as arena "zones" — that also teaches players which tiles collapse.
- **Cover walls:** they are plain 12×8×2 slabs. Make them look like arena infrastructure —
  angled, chamfered, team-neutral colors. Keep footprint ≤ their current one so spawn
  sightlines stay honest.
- **The lava sheet:** material/color/emission are free. Keep it a flat sheet *below* the
  floor in the loaded position; RisingLava animates its position, not its look.
- **Decoration outside the walls** (crowd silhouettes, banners, sky) — no contract impact,
  go wild.

### Rules of thumb

- Visual detail should be **outside the play plane** where possible; the floor plane must
  stay predictable for combat (it's a shooter).
- If you add new cover parts, put them in group `Cover` with `AnchorState="Hidden"` —
  they will then be part of CoverCrates' rise.
- Anything you add that should react to modifiers must carry a tag or group; anything
  static just needs `MRArenaStatic`.

---

## Ballot polish (D-058)

Vote cards now show **effect icon chips** — one emoji per mechanical effect (`Effects`
array on the modifier def), tinted with the modifier's category color, plus the same icon
row on the APPROVED stamp. The mapping lives in `VoteUI.lua` (`EFFECT_ICON`): every
current effect token is mapped; an unmapped token simply renders no chip, so adding a
modifier with new effects never breaks the UI. Adding an icon for a new effect is a
one-line table entry.

Verified live: real ballots rendered `HEAVY GRAVITY → 🔺` and `BLACKOUT → 🌫️🌑`.

**Important discovery while verifying (now a checklist item):** both **Bootstrap scripts
can be toggled off with the checkbox in Studio's Properties pane**. When they are, Play
runs with zero game code — no arena, no vote, no UI, no error anywhere. If Play ever
feels like an empty baseplate, check that checkbox on
`ServerScriptService/MajorityRulesServer/Bootstrap` and
`StarterPlayerScripts/MajorityRulesClient/Bootstrap` before debugging anything else.

## Milestone 1 remaining (hand work)

1. Restyle tiles + cover per above (you + brother).
2. Optional second hazard volume (e.g. `HazardType = "Spike"`) — engine already supports
   it; add tag + `HazardType` attribute and a Tier-3 modifier can use it.
3. Ballot rebalance pass: with all 23 modifiers eligible, watch 3–4 rounds of votes and
   prune anything that feels dominant in the 8-player context.
