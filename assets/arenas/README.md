# assets/arenas

Hand-authored arenas live here, one `.rbxmx` per arena, named to match the model in
`ServerStorage.Arenas`.

## Current state

**No arena file exists yet, on purpose.** The 2026-09-22 reset (D-048) deleted the Foundry and the
Colosseum — geometry and generators both. The arena is now the **outline** (`Dev/BuildOutline.lua`):
a 500-stud floor, a boundary, spawn pads, loot pads, cameras — the minimum the game needs, nothing
more. The human team builds the real arena on that canvas by hand.

When your first hand-built arena is ready to version:

1. Export it from Studio: right-click the arena model → **Save to File…** → this folder, as
   `<ArenaId>.rbxmx` (XML, so diffs are readable; binary `.rbxm` also works but is opaque).
2. Say "publish" — the file lands in the repo, gets committed and pushed.

## Exporting an arena from Studio

Play mode must be stopped first.

1. In Explorer: `ServerStorage` → `Arenas` → right-click the arena model → **Save to File…**
2. Save into this folder. Pick **Roblox Model Files (\*.rbxm, \*.rbxmx)** in the file type dropdown.
   The file must be **XML** (`.rbxmx`) if you want to read its diff in git; binary works but is
   opaque.
3. Commit it. `*.rbxm` and `*.rbxmx` are tracked; built place files (`*.rbxl`, `*.rbxlx`) are not.

## Why a Studio-built arena always needs one manual click

Re-confirmed 2026-09-22: nothing in Studio's toolset can write an instance out to disk — not to a
file, not to an agent, not to a plugin — so an arena can never version itself. `Save to File` is a
human click, and it is the only manual step anywhere in the Studio-first publish flow. Everything
after it is automatic once someone says "publish".

## What this file is, and is not

An `.rbxmx` here is a *snapshot*, not the live arena: the place is the source of truth while it is
being edited, and this folder is the versioned backup the publish pipeline carries. If the place and
a file here disagree, the place is newer unless someone says otherwise.

## Building on the outline — the tags that make the game work

The game finds everything by tag, never by name (docs/01-ARENA-CONTRACT.md §3). What the outline
provides and what you can grow:

| Feature | Outline has | Tag / attribute to grow it |
| --- | --- | --- |
| Floor + boundary | ✓ (500-stud floor, 4 walls in group `Wall`) | keep walls tagged `TransformGroup "Wall"` so shrinking works |
| Spawns | 12 pads (`MRArenaSpawn`, `SpawnIndex`) | add more anywhere, spacing ≥ 8 studs |
| Loot points | 5 pads (`MRLootPoint`, `LootWeight`, `ClearanceRadius`) | more pads = more contested crates |
| Vote showcase | 6 cameras + nameplate | keep ≥ 3 `MRVoteCamera` |
| Cover | — | tag parts `MRArenaTransformable`, `TransformGroup "Cover"`, `AnchorState "Hidden"`, then add `Cover` to the arena's `FeatureTags` — CoverCrates joins the ballot |
| Collapsing floor | — | `TransformGroup "Floor,Tile_N"` tiles + the `Tiles` feature tag |
| Hazards | — | `MRArenaHazard` + `HazardType`, add `Hazard` to `FeatureTags` |

The ballot auto-filters: a modifier only appears on a vote if the arena's `FeatureTags` satisfy its
`Requires` — so the arena can start bare and grow into the full modifier list one feature at a time.
