# 13 — Arena design: The Foundry

The reference arena is `ServerScriptService/MajorityRulesServer/Dev/BuildFoundry.lua`, built into `ServerStorage.Arenas.Foundry`
at boot when no arena is authored there. It is the worked example every map contributor copies: the
brief for hand-authored arenas is `docs/08-MAP-AI-BRIEF.md`, the rulebook is
`docs/01-ARENA-CONTRACT.md`, and anything below that contradicts the contract is a bug in this file.

This document covers two things that are usually separate and here are not: the **layout** (where
things are, and why those numbers) and the **look** (what it is made of). The first version of this
arena was deliberately grey-box — a functional ring that passed the validator. It looked like
programmer art, which is a real defect in a game whose whole pitch is that the arena transforms in
front of you. Everything in "The look" below is built out of **primitives, materials and lighting**:
no meshes, no uploads, nothing that needs anyone's eyes but the person reading this.

---

## Why it was redesigned rather than tweaked

The first version passed the validator, which turned out to mean very little: the contract's
`ClearanceRadius` attribute is documented as *"how much open space a crate needs, **used by
tooling**"* and no tooling checked it. Once the check existed (`ArenaValidator`), the layout it had
been blessing failed in ten places:

```
4 loot points  -> their crates spawn INSIDE a cover piece (invisible, and takeable through it,
                  because the ProximityPrompt sets RequiresLineOfSight = false)
4 spawns       -> inside a cover piece: the player is ejected by the solver the moment cover rises
2 loot points  -> 6.36 studs from cover while declaring a clearance of 8
```

None of those are visible in Studio by looking. That is the argument for measuring: a layout that
reads fine in the viewport was unplayable in four spawns out of eight.

---

## The look

**The fiction is the game's own brand: a bureaucracy that has gone feral.** The hall is an
institution built out of forms — stacked paper courses over concrete, ribbed, buttressed, with
colour-coded windows, a wall of filing banks, pipework in the roof, banners, and a Clerk's box
overlooking the floor. It exists so that when the vote moves a partition or drops a floor tile, the
arena reads as *deliberately* changed rather than broken: the parts that transform were authored as
office partitions and a tiled floor, not as architecture.

Colour is the second half of it. The palette is `docs/05-BRAND.md` pushed hard, and **every bright
thing on screen means something**:

| Colour | Meaning | Where it appears |
| --- | --- | --- |
| lime `(214,255,63)` | the vote itself | spawn pads, the ballot X on the dais, buttress slots, window frames |
| gold `(255,197,61)` | the verdict | the centre dais, balcony lips, the Clerk's rail, the dais's brass ring |
| ink / graphite / paper `(24,25,30)` `(32,35,42)` `(240,236,226)` | structure | shell courses, floor checkerboard, filing banks, nosing on every stair |
| eight category hues | the eight modifier families (Gravity, Combat, Environment, Chaos, Spatial, Loadout, Mobility, Vision) | one per cover column (plinth, band, capital), one per window bay, one per banner, the tally board, the lamp ring |

So the colonnade is a colour key for the modifier catalogue, and the arena tells you which family is
in play before the ballot even resolves.

**Lighting and atmosphere are part of the design, not defaults.** `BuildFoundry` sets a dusk clock
(18.2), an `Atmosphere` with haze, a `Bloom`, a `ColorCorrection` pushing saturation, weak sun rays,
six coloured pendant lamps with `PointLight`s, and six `OnModifier`-gated particle systems (fog,
low-gravity motes, embers, frost, falling rubble, sparks). This is the look every modifier departs
from and returns to — `GameplayService` captures its baseline at round start — which is why it lives
in the builder rather than in a scene file.

---

## The layout

A broken ring of eight cover pieces — a colonnade — with a contested centre, an unbroken perimeter
lane, four corner balconies, and eight gaps that are the only sightlines through it.

| Element | Value | Why this number |
| --- | --- | --- |
| Floor | **8×8 tiles of 7.5 studs with a 0.5 grout gap = 64 tiles**, checkerboard | 16 tiles of 20 made CollapsingFloor remove quarter-arena slabs; a missing 7.5-stud tile is something a player can see coming and step off |
| Substrate | a non-colliding grout sheet under the tiles | Visible from above, but it must not stop a fall or the floor could never be holed — see "A hole must be a hole" |
| Plinth | **3 stepped courses, 34/37/42 half-extent, built as a frame** | The ledge outside the wall is a fall, not a sniper perch. A *slab* would seal the arena's underside from below, which is the same bug in concrete form |
| Partitions | **26 high**, 1.5 thick, on a 32-stud half-extent, authored as metal slats in a frame | `LowGravity` runs gravity at `196.2 × 0.35` with `JumpPower 50` → an apex of **22.8 studs**. At 20 the modifier was a way out of the arena. Slats are what makes them read as office partitions closing in, not as walls glitching |
| Shell | half-extent **38**, 38 high, six stacked courses + 6 ribs per wall + 4 window bays per wall | 6 studs of dead space outside the partitions, so the arena looks like it is *inside* something. Nothing in the shell ever transforms |
| Cover | **8 × 7×6×7 at radius 15**, rotated tangentially, each on an 8.2 plinth with a neon band and an 8.6 capital | Contract size (the plinth/capital are outside the measured box). Tangential rotation shows a long face down the lane and an edge at the gap, so the ring reads as a colonnade and the gaps are vertical seams |
| Cover height | **6** vs an R6 character's **5.00** | The first generated cover attempt came back at 4.78 — it would have hidden nobody, and no screenshot would have told us as cleanly as that number |
| Gaps | **(2π·15 − 8×7) / 8 = 4.78 studs** | Wide enough to fight and shoot through, narrow enough that the ring is cover rather than decoration |
| Spawns | **8 at radius 26**, phase `π/8` (half a slot off the ring) | Puts every spawn in a *gap*, equidistant from the two flanking pieces: no spawn is privileged, and no spawn starts inside cover |
| Loot | **5**: one on the dais, four on the diagonals at r=28 on stamped pads | Fewer crates than the 8-player roster keeps them contested. Each loot point's Y is set to `surfaceTop − 1`, because `LootService` always spawns a crate +2.5 above the point — so the crate's underside rests exactly on the dais or the pad |
| Clearance declared | **8 studs**, measured minimum **9.0** | The claim, and the fact |
| Dais | **16×16×1.2 gold**, on a lime seal, with an ink emblem, a lime ballot X and a ring of 12 brass plates | The contested centre. It also covers **4 of the 64 tiles**, which is deliberate: on a collapsing floor the middle of the arena stays, and the crate that spawns there is the round's prize |
| Balconies | **4, deck top 6.5 studs**, 8×8, railed on the two outward edges, reached by a 5-step flight along the wall | Normal jump apex is **6.4** studs, so a balcony is *stairs-only* until someone votes `LowGravity` (apex 22.8) — that interaction is the reason to have high ground at all |
| Clerk's box | a judging mezzanine on the north partition at y=12, gold rail, tally board of 24 unlit cells | Somebody is always watching the vote. The cells carry a `VoteIndex` attribute so the tally can light up later without a re-model |
| Filing banks | **4×3 drawers**, 7.2 high, flush against three of the four walls | The detail that says somebody works here, and real cover in the perimeter lane |
| Vote cameras | **5**, a shot list, all inside the shell | Establish from above the south partition → rake the lane at eye height → look down from a balcony → push in on the dais → the Clerk's box. Every sightline is checked against the built geometry with cover *both* hidden and up |
| Emitters | 6 containers, each `OnModifier`-gated, all `CanQuery = false` | Fog/Blackout mist, LowGravity motes, RisingLava embers, IceFloor frost, CollapsingFloor rubble, Ricochet sparks. Atmosphere a map contributor can author with no script change |

Spawn fairness is a property, not an intention: every spawn is the same distance from the ring, from
the centre and from the nearest crate.

---

## Three things this layout got wrong, and the numbers that caught them

Each of these was invisible in the source. All three were found by probing the built model, and the
first two are the reason that probing happens at all.

**1. The staircases ran through the colonnade.** The first flights climbed diagonally inward from the
balconies — and the eight columns sit at exactly the diagonal angles, so the stairs were *inside* the
cover ring. With cover hidden, players would walk up steps that later rose through them:
`12 contacts between `Geometry.Balconies` and `Transforms.Cover``. A `GetPartsInPart` pass now runs
over the balconies on every rebuild: **0 conflicts**.

**2. The plinth sealed the floor.** The base was three solid slabs under the tiles. A collapsed tile
would therefore be a two-stud step onto concrete, not a hole, and CollapsingFloor would have been
cosmetic. The plinth is a frame and the substrate does not collide. Measured with
`RaycastParams.RespectCanCollide`, casting down from a tile with the tile excluded:
`first collidable thing below a hole = nothing until the Lava volume at y = −17`.

**3. Half of every shell rib was underground.** The buttresses were centred on the arena's origin
rather than the wall, so all 24 ran from y −20 to +20: buried below the plinth, and absent from the
wall's upper storey. Now `0 … 40`, and the arena's vertical extent reads **−17 (Lava) … +45 (the
establishing camera)** instead of −20 … +44 from a half-buried rib.

---

## The same mistake, six times: props are placed by rule now

The 128-stud rebuild passed the validator and looked finished, and the placement probe then found
**118 pairs of props built inside each other**. The causes were not six different bugs. They were one
bug: a prop positioned by a stud count that stopped matching the geometry the moment the hall grew.

| What was inside what | Cause | Now |
| --- | --- | --- |
| 4 desks inside colonnade columns | placed in the ring's *gaps*, which are 10.8 studs wide and a desk is 7 | `settle` slides them along x until clear |
| 4 ballot stacks under cover pieces | same gaps, one 3.05 studs from a column's centre, under its 8.2-wide base | same |
| 2 mail carts inside filing banks | the west banks moved to z 10.7 / 34.7 / 58.7, the carts did not | banks and carts both settle along their wall |
| a filing bank inside a balcony leg | the third west bank landed on the south-west balcony's corner leg | the bank slides to the nearest clear point on that wall |
| 3 queue-barrier bases on crate pads | 21-stud lines through a ring of 7x7 pads | the pads are registered as keep-outs **before** the clutter is built |
| a notice board 0.4 studs inside the wall | `face` was computed inward from the partition's centre, not outward from its slat face | `face` is the slat face plus half a board |
| the marquee inside three shell ribs | ribs project 4.5 studs further into the hall than the wall does | the sign hangs in front of them |
| the archive inside the south-west staircase | the fourth shelf sat at 123°, the stairs land at 129° | the ring starts at 0.52π |
| the pigeonholes and the Clerk's box through the gallery deck | a deck crosses both walls at y 7..8 | the boxes start above it; the legs start on it |

`BuildFoundry` keeps world-space bounds for every visible part it creates and places props through
`settle`, which walks outward along the prop's own lane until its footprint is clear — *along* the wall
for wall furniture, so it stays flush. The authored position is candidate zero, so nothing moves
unless it has to, and every move is logged. See **D-034** for why this replaced hand-solved
coordinates, and **D-035** for the four props that turned out to be lying on their sides.

**Measured, two revisions later.** The probe's overlap count went **118 → 6 → 0** across three live
runs. The first run with both the guard and a working probe reported the six, and every one was the
guard or the probe mis-measuring rather than the arena being wrong:

| Pair | What it actually was |
| --- | --- |
| `BarrierBase_3 into LootPad_7`, `BarrierBase_1 into LootPad_2`, `BarrierPost_4 in Spawn_3` | the barrier's footprint was centred on the line's *origin*, not on the middle of a 21-stud line — the guard cleared a window that was half empty floor and half barrier |
| `Emblem into Press_Anvil`, `Emblem into Press_Foot` | real: the press stood in the dais emblem, and no 9.2-stud press fits a 22-stud dais beside a 9-stud emblem |
| `GalleryStrut_S_3 into VaultCrown_2` | real, and the **same** location as the crown in revision 6 — which is the tell that it was not fixed by siding the unit, and led to the `* S` bug behind it (D-039) |
| `MarqueeBack into ClockFace` | the probe's own arithmetic: `Position ± Size/2` claims 9 studs of depth for a 0.6-stud-thick clock face — the pair survived revision 6's extents fix, so it was a *real* 0.05-stud overlap between the sign's back plane and the clock's rim |

The last row is the cautionary one. It looked like a second instance of the probe bug already fixed in the
same session, and it was not: the fix was correct and the overlap was real. **A bug that repeats a
previous bug's symptom is the easiest kind to wave through**, and the way to tell them apart is to check
whether the fix is in the code path, which here took one `grep`.

---

## Measurements

All taken from the built model in the live place, not from the source.

**The gate** — `ArenaValidator.validate(Foundry)`:

```
ok=true  parts=1352  spawns=8  loot=11  cameras=6  transformables=369  groups=260
instances=1388  smallest loot clearance 9.9 studs (declared 8)  errors=0  warnings=0
```

That is the **128 x 128 hall**, read out of a Play session: 1352 of a 2500-part budget (54%), 369
parts the transform pipeline has to move, eleven crate points against five in the 96-stud version.
Identical in revision 2 and revision 5, which is itself a check: moving props and turning cylinders
upright changes no part counts and no clearance.

**The placement probe, measuring the family-hall and an inset 8 studs from the partitions** — 388
instances, 260 transform groups, 81 chest-height samples (19 of which stood inside a prop and were
dropped). Revision 6's report:

```
budget       parts 1352 / 2500 (54%), transformables 369, instances 1388
overlaps     6 pair(s) over 0.25 studs   (118 before the guard — see the section above)
markers      all 58 marker(s) have CanQuery = false
             14 visible non-colliding parts block rays (the grout substrate, the VOTE letters)
spawns       8 spawns, 0 with something in a standing player's volume
sightlines   62 samples at y=3
             cover hidden (round start):   992/1891 pairs blocked (52%)
             cover raised:                1544/1891 pairs blocked (82%)  ->  1.56x
 the hole     from Tile_1 down: nothing collidable at all below y = -2.1
```

Three things moved for the better between revisions 5 and 6: the spawn volumes went to **0 blocked** (a
barrier post was standing in one), the markers stayed silent at 58, and the sightlines settled at 52% /
82% — an arena with real sightlines under cover, and cover worth **1.56x** when it rises. The very first
reading was 74% / 87%, which is what a grid sampling from *inside the walls* looks like; it was fixed
before anybody acted on it (D-036).

**Revision 7, measured.** The prediction above was wrong. Revision 7's first live run reported
**13 pair(s) over 0.25 studs — not zero** — though not one of revision 6's six survived: the `S`-scale
fix (D-039) cleared the archive and booth rings out of the gallery struts for good. The 13 were all
new, and three defects produced every one of them:

| Reported (rev 7) | What it actually was | Fix (rev 8) |
| --- | --- | --- |
| 11 pairs: `Desk_4`/`DeskLeg`/`Typewriter`/`DeskLamp` into `Booth_03`'s parts, `BarrierPost_1`/`BarrierBase_1` into `BoothPanel_05` | the guard clears against what already exists, and the booths were built *after* the clutter had settled: `Desk_4`'s authored spot (29.7, 29.7) is booth 03's own position on the radius-41 ring, so the booth was constructed over a desk that had no reason to move | `votingBooths`/`archiveVault` now run between the keep-out reservations and the clutter (D-042) |
| `VaultFrame_1`/`VaultShelf_1` into `LootPad_3` by 0.29 | the vault's settle footprint was 3.6 studs square while the shelf it builds is 6.4 wide and faces the dais — up to 1.4 studs of shelf overhung the cleared box, inside `GUARD_MARGIN`, invisible to the guard | the footprint is now 6.5 square, covering the 6.4x2.6 shelf at every facing in the arc |
| `MarqueeBack into ClockFace` by 0.50 | the clock, for the third time: a cylinder's flat axis is its local X, and the quarter-turn about Z stands a disc *upright* — but a wall clock needs the disc *vertical*, facing out of the wall. This one lay flat like a 9-stud plate at y=35, reaching 4.5 studs off the north wall and straight through the marquee's plane. Three marquee fixes never killed the pair because the marquee was never the bug | rotated about Y instead; the disc now hangs like a clock, 3.1 studs clear of the sign's back plane (D-043) |

The same run's other numbers: sightlines **58% / 81% (1.38x)** — more pairs blocked at round start than
revision 6's 52%, because the booths and archive now sit mid-field where they intercept chest-height
rays, which also compresses the ratio. Budget unchanged (1352 parts, 369 transformables), spawns 0
blocked, all 58 markers silent. And the round data finally shows the shape the arena is built for:
**41.9s elimination among eight combatants**, then 19.0s and 6.2s — the >30s goal met organically, not
by a timer.

**Revision 8** is the fix revision: landmarks before clutter, an honest vault footprint, a clock that
stands up. One more Play reports whether the count reads zero.

Re-measure rather than trust any of this: `ArenaProbe.logReport` prints all of it on any Play.

The earlier gate, for scale — the first arena that passed it was 84 x 84 studs of play space:

```
ok=true  parts=438  spawns=8  loot=5  cameras=5  transformables=125  groups=68
minLootClearance=9.04 (declared 8)  floorCentreOffset=0.0  errors=0  warnings=0
extent 84 x 62.4 x 84 studs
```

**Tile naming is load-bearing.** `Tile_1` is a group name the contract requires and the validator
checks, so padding to `Tile_01` fails the gate the entire `Tiles` feature rests on:

```
unpadded (Tile_1)   ok=true  errors=0
padded   (Tile_01)  ok=false errors=1  [arena declares the Tiles feature but has no 'Tile_1' group]
```

**Spawn volumes.** Eight columns 6 studs tall and 3 studs across, five rays each, against all visible
geometry: **all 8 spawns clear** — no balcony, stair or filing bank hangs over a spawn.

**Stairs.** Risers **1.29–1.30** (a Humanoid steps ~2), top step **6.50** against a deck top of
**6.50**.

**Vote showcase sightlines**, on an *empty* arena — which is the state the vote is shown in, because
the colonnade is authored hidden and only the vote reveals it. 13 targets (8 spawns, 4 crates, the
dais), per shot, with cover excluded so the measurement is of the empty hall:

| Shot | Clear | What blocked the rest |
| --- | --- | --- |
| 1 — establishing, above the south partition | 12/13 | the dais's own emblem (the target), plus a lamp rod crossing the line to the dais, which re-phasing the lamp ring removed |
| 2 — eye height in the perimeter lane | 12/13 | the dais emblem (the target) |
| 3 — looking down from a balcony | 11/13 | its own balcony leg under the deck; the dais emblem |
| 4 — pushing in on the dais | 11/13 | the dais emblem; one ray clipped a stray R6 test dummy since deleted |
| 5 — the Clerk's box | 12/13 | the dais emblem (the target) |

Every remaining "block" is the **dais**, which is what several of the shots are aimed at, or
foreground furniture under the camera. With cover up the same shots read 6/13 — the colonnade doing
its job.

**Collapsing Floor on this arena**, sampled from the live server during a real round:

```
  7.0s  15/38 tiles gone, step 3 of 8 planned
 10.5s  20/38 tiles gone, step 4 of 8 planned
 14.0s  25/38 tiles gone, step 5 of 8 planned
 24.6s  38/38 tiles gone, step 8 of 8 planned   <- the 60% cap, reached on the 8th step
```

and on the following round, sampled every 6s from the round's start:

```
 6s: 0 hidden   12s: 10   18s: 20   24s: 25   30s: 35   36s: 38
```

Two things that verifies at once: the pacing (5 tiles every 3.5s, cap 38 = 60% of 64 — see D-029),
and the **reset** — the previous round's 38 missing tiles were all back at the 6-second mark.

**The void rule.** Holding a character 21 studs below the arena floor with no fall in progress (the
root pinned, so fall damage cannot explain a death) kills it within 0.25s, through the ordinary death
path:

```
[MR] Round: whatamihereforfh fell out of the arena (y -25.0, floor 0.0)
```

The two floors that set the margin are the place's own: the Lava volume at y = −16 and the
**Baseplate, 512×20×512 at (0,−39,0), top face y = −29** — the surface a fallen player used to land
on, alive and out of play.

---

## Honest gaps

* **I measured this arena; I did not play it, and I cannot see it.** Clearances, sightlines, risers
  and pacing are numbers. Whether the colonnade is *fun*, whether the palette reads at distance, and
  whether the Clerk's box is charming or silly are your call, and no probe answers them. The three I
  would watch first: the eight aligned lanes through the ring, whether 5 crates for 8 players is the
  right pressure, and whether the balconies are a strong position or a death trap once `LowGravity`
  makes them jump-reachable.
* **The dais is a permanent island** covering 4 of 64 tiles. Deliberate, and it means a collapsing
  floor always leaves somewhere to stand. If that turns out to defuse the modifier, shrink the dais —
  it is one constant.
* **Bots are not players, however many of them there are.** They target the nearest *living
  combatant* now, so a seven-bot round is a fight rather than seven shooters converging on you, but
  they do not vote, they do not loot, and nothing about how the game *feels* is measurable against
  them. Since D-037 a Studio Play fills the lobby to eight on its own, which makes a round worth
  watching — it does not make it a playtest.
* **Revision 8 has not been through a Play session; revision 7 has.** Revision 7's run is measured
  above: 13 pairs, three causes, all fixed. Revision 8's changes — landmarks before the clutter, the
  vault's honest footprint, the clock standing on the wall — are verified by arithmetic and the
  structure check, not by the engine. Expect the overlap count to read 0, and treat anything else as
  the guard or the probe reporting a placement the fix missed.
* **The placement guard moves props, and it does not know what looks good.** Seventeen props go through
  it. It keeps wall furniture against its wall and it logs every move, but a designer's composition is
  not one of its inputs — the authored coordinate is simply its first candidate.
* **Mobile and console have never been exercised**, so nothing here is verified at 30fps on a phone.
* The arena is still inside OneDrive (see `docs/10-HANDOFF.md`).

---

## How to re-measure any of it

Everything above came from probes runnable from the Studio connector. The three traps that cost the
most time:

1. **`require` caches per session and Rojo patches module source in place**, so a probe that requires
   a module directly can silently run the *old* code. Require a **clone**:

   ```lua
   local m = game.ServerStorage.Tools.ArenaValidator
   local c = m:Clone(); c.Parent = m.Parent
   local Validator = require(c); c:Destroy()
   ```

2. **`CanQuery = false` does not take effect for spatial queries in the same frame** (and in Edit mode
   there may be no solver step at all), so a raycast probe cannot "hide" a part by flag. Exclude parts
   through `RaycastParams.FilterDescendantsInstances` instead, and use `RespectCanCollide = true` when
   the question is "would a player land on this".

3. **In a playtest, requiring a server module from the assistant context can give you a *different
   instance* of it** — reads come back as fresh module defaults (`State = "Idle"`, `TotalRounds = 0`)
   while the server is mid-round. Read live state through the **DataModel** (Workspace, attributes) or
   the **Output log**, which is where the server's own `[MR]` lines land.

Rebuild and re-gate any time the layout changes:

```lua
local dev = game.ServerScriptService.MajorityRulesServer.Dev
local c = dev.BuildFoundry:Clone(); c.Parent = dev
local Build = require(c); c:Destroy()
Build.build()   -- rebuilds ServerStorage.Arenas.Foundry and runs the validator over the result
```
