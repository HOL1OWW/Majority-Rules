# 12 — The Art Pipeline (and who does what)

*Everything in this document is free. Nothing here requires a subscription, an API key, or a
payment — and Stage 0 needs no installation at all.*

The premise: **most of The Vote's art is not 3D-model-generation-shaped.** The arena is primitives
the transform system moves; the props are crates and pillars; the weapons are six shapes that must
sit in a hand and animate. Only a small slice of this game needs generated assets, and this doc is
honest about which slice.

---

## Who owns which half

| | Owned by | Why |
|---|---|---|
| The round state machine, modifier lifecycle, networking, contracts, validators, tests | **Buffy** | It's code, and code can be verified mechanically |
| Generating props, materials, textures into the place, then validating them | **Buffy** | Driveable through the Studio tools and a command line |
| Arena geometry (blocks, walls, cover, spawn markers) | **The map team** — you, your brother, map-specialist agents | It's authored against `docs/01-ARENA-CONTRACT.md` |
| Hero meshes, characters, animation feel, sound design, colour and lighting mood | **You, or a specialist agent** | Taste, not correctness — no checker can tell you it feels right |
| Uploads to Roblox, Creator Hub, Game Settings, the public listing, moderation | **You only** | Behind your account and your identity |
| Anything an AI generates and you ship | **You** | You carry the licence and the provenance |

The rule that keeps this workable: **anything another agent builds must arrive through a written
contract** — naming, scale, pivot, materials, tags — so it can be validated mechanically the moment
it lands instead of being described to Buffy in prose. `docs/01-ARENA-CONTRACT.md` is the shape of
that; the asset contract in Stage 4 follows it.

---

## Stage 0 — Already working. Nothing to install.

Roblox's Cube 3D model is reachable **today, in this place**, without the `Assistant Mesh Generation`
beta flag and without ID verification. Verified on 2026-09-21:

```
generate_mesh("a low-poly sci-fi weapon crate with a hinged lid, flat sides, no text",
              size = 4 x 3 x 4 studs, maxTriangles = 1200)

-> Model "a low-poly sci-fi weapon crate..." (2 children)
   Model lid   -> MeshPart lid_geom  | size 3.38, 0.21, 2.24 | MeshId rbxassetid://81516882782780
   Model body  -> MeshPart body_geom | size 4.00, 2.49, 2.77 | MeshId rbxassetid://115763224257029
   extents 4.00 x 2.60 x 2.77 studs (asked for a 4 x 3 x 4 box)
   both assets resolve in the catalogue, creator = your account
```

Three things that matter in that output:

1. **The MeshIds are real uploaded assets** owned by your account — not a runtime-only generation
   UUID. That is the durability question from earlier, answered: this path produces assets that
   survive saving and publishing, unlike the raw `GenerationService:GenerateModelAsync` route, which
   returns a `MeshPart` with an **empty** `MeshId`.
2. **It segments into named parts** (`lid`, `body`) instead of one welded blob, which is what a
   game asset needs — animation, colliders and swapping all need separate parts.
3. **`maxTriangles` and a bounding box are inputs.** Roblox budgets are respected at generation time
   rather than fixed afterwards.

There are three tools, all free and first-party:

| Tool | What it makes | Use it for |
|---|---|---|
| `generate_mesh` | A textured mesh from a prompt, with a size box, a triangle cap and named parts | Props, weapon silhouettes, debris, crates |
| `generate_procedural_model` | A **parametric** model built from primitive parts with editable attributes (size, colour, proportions), optionally from a reference image | Anything you'll want to tune later — and anything a modifier resizes |
| `generate_texture` | Re-textures an existing `MeshPart` or `Model` from a prompt or a style image | Making a mixed set of props share one look |

**Do this:** nothing. Ask for a prop. If the built-in quality is not enough for a specific hero asset,
that is the only reason to leave Stage 0.

---

## Stage 1 — Blender (needed for anything you intend to animate or ship cleanly)

Blender is the tool that turns "a mesh exists" into "a mesh behaves". It is free, and it is the one
install I would do today. It solves three problems nothing else here solves:

- **Pivots and orient** — a Roblox weapon must be aligned to its grip, or it sits sideways in hand.
- **Collision hulls and LODs** — AI output has none, and Roblox will not make good ones for you.
- **Fix-up after generation** — separating parts, closing holes, trimming a dense mesh to a budget.

Install (it needs no admin rights, and `winget` is available on this machine):

```
winget install --id BlenderFoundation.Blender -e
```

Confirm it, then leave it alone — **you do not need to learn Blender.** Buffy drives it headlessly:

```
blender --background --python <script>.py
```

That gives scripted, repeatable geometry work: parametric props, batch import/export, pivot
correction, UV setup, `.fbx`/`.obj` output for Roblox upload.

**Optional, and worth knowing about:** a community Blender MCP server lets an agent work *inside* a
live Blender viewport instead of only headless. Add it in Freebuff's MCP settings if you want an
interactive loop. Same caveat as any MCP server: it is arbitrary code execution on your machine, so
add only tools you trust.

---

## Stage 2 — ComfyUI + TRELLIS 2 (your permanently-owned generator)

This is the version that never bills you again: unlimited, offline, no credits, no watermarks, no
attribution obligations — and it runs on the hardware you already have. Your machine: **RTX 4060 Ti,
211 GB free on C:**. TRELLIS 2 runs in ~6 GB VRAM with low-VRAM options.

Two jobs, one install:

- **Image → 3D** (TRELLIS 2, MIT-licensed, native in ComfyUI since 2026)
- **2D generation** for icons, thumbnails and seamless texture sources, which matters for
  *consistency* — the only way twenty assets share a look is generating them from one setup

Steps:

1. Install **ComfyUI Desktop** from `comfy.org` (or the portable build). Pick a models folder with
   room — the weights for a 3D model plus an image model are roughly 15–25 GB.
2. Through **ComfyUI Manager**, install **TRELLIS 2** and one image model.
3. Launch it and note the local address (default `127.0.0.1:8188`). That HTTP API is how Buffy drives
   it — **no MCP server is needed for ComfyUI**, a command line reaches it.
4. Ask for one test generation to confirm the API is reachable.

**Before you rely on it, check one thing.** I found contradictory public statements about TRELLIS 2's
licence: ComfyUI's announcement calls it MIT while also describing it as research-only, the project
itself says MIT, and TRELLIS 1's issue tracker notes a missing patent waiver. **Open the `LICENSE`
file in the repository and read it.** MIT permits commercial use, so the "research only" sentence
looks like an error — but that is a five-minute check that protects the whole game, and it is
exactly the kind of thing that cannot be fixed retroactively after shipping.

---

## Stage 3 — The export loop (mesh → your account → the place)

Roblox assets have to be uploaded by you; no agent can do this step. The loop:

1. Buffy produces or fixes the model.
2. Buffy exports `.fbx`/`.obj` into a folder in the project.
3. **You** upload it in the Creator Hub (or via the Meshy Roblox Bridge if you use Meshy — see below).
4. Once it exists in your inventory, Buffy inserts and validates it by asset id.

Step 3 is the only manual link, and it is a hard boundary: uploads sit behind your identity.

### If you still want a hosted generator (Meshy and friends)

Fine as a **hero-asset fallback**, never as the main pipeline. What you are actually buying, per the
current plans:

| | Meshy free | Why it matters |
|---|---|---|
| Credits | 100/month | Fine for experimenting |
| Downloads | **10/month, Lite model only** | Meshy 6/7 downloads are paywalled |
| Licence | **CC BY 4.0 — you must credit Meshy** | Commercial use allowed *with attribution* |
| API | **None on free (Pro and up only)** | Buffy cannot drive it — every asset is you in a browser |
| Roblox | Meshy Roblox Bridge uploads to your Creator Hub inventory | Buffy can then insert and validate by asset id |

So: Meshy is a manual, capped, attribution-required path. Use it when a hero prop genuinely needs it,
plan the credit line if you ship free-tier output, and prefer tools Buffy can drive — anything with a
command line or an MCP server — because those cost you nothing per asset.

### Recommended order of work

1. **Stage 0 now, because it's already working** — ask for the props the arena actually needs.
2. **Blender next** — it upgrades every asset that follows, generated or hand-built.
3. **ComfyUI + TRELLIS 2 only if the quality gap actually bites** — after the licence check above.

And the cheapest real answer, once more: most of this game's look is **parametric primitives plus one
coherent material palette**, which costs nothing. A stylised arena that transforms dramatically beats
a detailed one that transforms subtly, and that is an art-direction decision rather than a tooling one.

---

## Stage 0 in practice: the first three props (measured 2026-09-21)

The arena needs three visual props and the code states the size of each. All three were generated
with the built-in tools, measured in the live place, and staged in `Workspace.PROP_STAGING` beside
the *current* primitives and an R6 character for scale. **Nothing is wired into the game.**

**Update, 2026-09-23.** A fourth prop arrived from a completely different tool: a pistol crate built
by **Google Antigravity's Gemini agent** driving Blender over an MCP server. It is the first prop
truly wired in — `Sidearm` weapons now spawn in it (`CrateVisuals`, D-062) — and the first asset
whose licence is not yet read, which is now a pre-publish blocker rather than a someday note. Ids and
provenance: `assets/PROVENANCE.md`. Its size comparison is staged in `Workspace.PROP_STAGING` as
`AGENT_Crate_1to1` (as imported, 1.78 × 0.82 × 1.18) beside `AGENT_Crate_ship` (×3.650, 6.49 × 3.00 ×
4.32 — the shipping size), with the R6 reference on the same row.

| Prop | What the code requires | Staged result | Distortion |
| --- | --- | --- | --- |
| **Weapon crate** | `CrateVisuals` builds a 3×3×3 `Part` by default; `Sidearm` weapons get the uploaded case | 3.00 × 3.48 × 2.86 | uniform only, none |
| **Cover piece** | `BuildFoundry` authors 7×6×7 | 7.00 × 6.00 × 6.97 | Y ×1.256 only |
| **Pillar** (decorative) | foundry corner pillars are 8×70×8 blocks | 5.45 × 20.00 × 5.45 | uniform ×0.68 |

Every id, with how strongly each was verified, is in **`assets/PROVENANCE.md`** — the register this
doc asks for, started here because these are the project's first assets. Two things in it are worth
knowing before you go looking: the **mesh id** a `MeshPart` references and the **published model id**
`insert_asset` accepts are different numbers for the same prop, and the cover's generation id is
gone from the model entirely — recovering it through `insert_asset` dropped the attribute, so its
asset id is the only link back.

### The size box is a hint, not a contract

This is the finding that matters most, because it silently determines whether props fit the game.
Three attempts at the *same* 7×6×7 cover with different wording:

| Prompt wording | Natural size returned | Stretch needed to reach 7×6×7 |
| --- | --- | --- |
| "wide and squat" | 7.00 × **4.78** × 6.97 | Y ×1.256 |
| "tall and thick" | **4.64** × 6.00 × **4.62** | X and Z ×1.51 |
| "7 studs wide, 6 studs tall, 7 studs deep" | 7.00 × **3.46** × **2.49** | Z ×2.81 |

Every one of them was given `size = (7, 6, 7)`. **The wording overrode the box every time**, and the
version that stated the dimensions numerically was the *worst* of the three. So:

* Generate, **measure**, then correct the axis that is wrong with a single-axis scale. Do not keep
  re-rolling prompts hoping the box wins — and do not assume the first attempt was the bad one. It
  was the best of the three, and it had to be recovered from its published asset id.
* A non-uniform scale is acceptable on a boxy prop when it touches one axis, and the one applied
  here (Y ×1.256) is invisible on concrete. Stretching X and Z by 1.51 distorts every corner post
  and seam at once, which is why that attempt was dropped.

### Traps, all of which cost time

1. **Generated parts arrive `Anchored = false`.** They fall the moment the place is played. Anchor
   the whole model, every time.
2. **`insert_asset` expands a package asynchronously.** Property writes — including
   `CollisionFidelity = Box` — issued immediately after the insert silently do not stick; the
   cover came back as `Default` while the same code worked on the generated models. Write
   properties on a *later* pass and verify by reading them back.
3. **They arrive tagged `AssistantAIGeneratedAsset`.** Strip it: a staged prop should carry no tag
   a contract check could mistake for arena content. The `Assistant-<uuid>` and
   `RBX_AI_GENERATION_ID` markers are worth keeping as provenance.
4. **Set `CollisionFidelity = Box`.** A 3-stud crate should collide as a box, not as a hull with
   nooks a bullet can thread. (A meshed crate avoids the question: a `Part` collides as its box.
   **`MeshPart.MeshId` cannot be assigned at runtime in Studio at all** — `lacking capability
   NotAccessible`, from game code as much as from a probe. Carry the mesh on a `SpecialMesh`, or
   clone a `MeshPart` that already has one. See D-062.)
5. **Blender units are not Roblox units — and nothing warns you.** A scene authored in metres imports
   at **1 unit = 1 stud**, so an 0.82 m crate becomes an 0.82-stud crate: a sixth of a player's
   height, and **3.66× smaller** than the 3-stud crate `LootService` actually builds. The mesh is
   valid, the texture lands, and it looks correct in Blender's viewport, so the defect only exists in
   the game. State the target size in **studs** inside the generator script, then measure the
   `MeshPart` after import before judging the model. (Measured 2026-09-23 on the pistol crate — see
   `assets/PROVENANCE.md`.)

### What the first three props bought, beyond the meshes

* **The crate lid is a separate `MeshPart`.** Segmenting with `partNames = "body, lid"` means the
  crate can *open* rather than vanish — `openCrate` currently calls `crate:Destroy()`, and an
  animated lid is now a script change rather than a modelling job.
* **The id-durability question is answered.** These are ordinary uploaded asset ids, not the
  runtime-only UUID that the raw `GenerationService` route returned. The two-client test below is
  still unrun, but the mechanism is now the same as any other asset.
* **Cover is measurably cover.** An R6 character is 5.00 studs tall; the cover is 6.00, a 1.00-stud
  margin. The first attempt at 4.78 studs would have hidden nobody — which is exactly the kind of
  defect a number catches and an eye does not.

Pillars are the weakest of the three: no arena currently uses a pillar that is not a plain block,
so nothing *asks* for it. It is staged as a component the map team can adopt, not as a need met.

---

## Provenance: the register

From the first external asset onward, every asset records four things: **source, licence, who made
it, where it lives in the project** — in `assets/PROVENANCE.md`, committed with the asset. It covers
Roblox moderation, the CC BY attribution Meshy's free tier requires, and the question "can we still
use this if we ever monetise" — all of which are unanswerable later if nothing was written down.

---

## What is still unverified

- **Two-client visibility.** Generated assets are real uploaded ids (see the ids above), so this
  should be fine, but "should be" is not "verified": the test is a saved place, a republish, and a
  second client.
- **The staged props' look.** They were verified by measurement, not by eye — generator output on a
  grey platform says nothing about whether the crate reads at distance or the texture holds up
  under the arena's lighting. That judgement is yours, and the props are sitting in
  `Workspace.PROP_STAGING` waiting for it.
- **Hero-asset quality.** Everything above is prop-grade. Nobody's AI output is production-ready
  without cleanup, and the cleanup is where the hours go.
- **Device performance.** Profiling happens in Studio; phones and consoles have never been tested.
