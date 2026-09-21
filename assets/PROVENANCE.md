# Asset provenance register

Every asset that did not come out of this repository's own scripts gets a row here **when it is
created**, not when someone remembers. Source, licence, who made it, where it lives. See
`docs/12-ART-PIPELINE.md` for why: Roblox moderation, attribution obligations (Meshy's free tier is
CC BY 4.0), and "can we still use this if we monetise" are all unanswerable retroactively.

## Tooling sources

| Tool | Where it comes from | Licence / attribution | Can the agent drive it? |
| --- | --- | --- | --- |
| Roblox built-in mesh generation (`generate_mesh`, `generate_procedural_model`, `generate_texture`) | Roblox Studio assistant tools | First-party. No attribution, no per-asset cap, no cost. | **Yes** — via the Studio connector |
| Blender | blender.org | GPL, free | Yes, headless (`blender --background --python`) once installed |
| ComfyUI + TRELLIS 2 | comfy.org | **Unverified** — the project says MIT; ComfyUI's announcement also calls it research-only. Read the repo `LICENSE` before shipping anything from it. | Yes, over its local HTTP API |
| Meshy, Tripo, Rodin and similar | hosted web apps | Meshy free tier is **CC BY 4.0 — attribution to Meshy required**; free tier allows 10 downloads/month and has **no API**. Others vary by tier: check before shipping. | No on free tiers — every asset is a manual browser session |

## Assets

All four below are **first-party Roblox-generated meshes** (no third-party licence, no attribution
obligation), created by the Studio generation tools and published to this account.

Two id levels appear here and they are not interchangeable: the **mesh id** is what a `MeshPart`
references, and the **model id** is what `insert_asset` accepts to bring the whole prop back.

| Prop | Mesh id (read from the place) | Published model id | Generation id | Lives in |
| --- | --- | --- | --- | --- |
| Weapon crate — body | `rbxassetid://122941623621376` | `124375179095900` | `fb0b7962-69a0-4aae-91bd-9e8d3b3e01e3` | `Workspace.PROP_STAGING.GEN_Crate.body` |
| Weapon crate — lid | `rbxassetid://119919244609530` | " | `fb0b7962-69a0-4aae-91bd-9e8d3b3e01e3` | `Workspace.PROP_STAGING.GEN_Crate.lid` |
| Arena cover block | `rbxassetid://114574100581850` | `134466368359318` | `cefb5159-229b-4568-80e3-743a662e0b66` | `Workspace.PROP_STAGING.GEN_Cover` |
| Arena pillar | `rbxassetid://116213610982087` | `92381832471932` | `1dacd85f-13c4-4821-8c44-8019b9394afb` | `Workspace.PROP_STAGING.GEN_Pillar` |

How each row was checked, so the strength of the record is visible:

* **Mesh ids** were read out of the live `MeshPart.MeshId` properties, so they are confirmed.
* **The cover's model id is the best-evidenced row of the four**: `insert_asset` was called with
  `134466368359318` and returned a real model, which is what recovered this prop. Nothing weaker
  than an actual successful insert verifies a model id.
* **The crate's and pillar's model ids come from the generation job results only** — they have not
  been re-inserted, so treat them as reported rather than proven.
* **Generation ids** were read from the models' `RBX_AI_GENERATION_ID` attribute where they exist.
  **The cover's does not** — recovering it through `insert_asset` dropped the attribute, so only the
  asset id links it back, and its generation id above comes from the generation job.
* `AssetService:GetAssetIdsForPackage` returned false for these ids. That proves nothing either
  way and is recorded only so nobody re-runs it expecting a different answer.

**None of these are wired into the game.** They are staged for review in `Workspace.PROP_STAGING`,
which is Studio-side content and not part of the synced repo — so this table is currently the only
place outside Studio that records their ids.

Two further cover generations were made and discarded while testing how much control the size box
gives. Their model ids are recorded here so nobody mistakes them for live content:
`101549430330245` and `109855040395016`. Both remain in the account's asset history and can be
ignored. (An earlier throwaway crate probe was deleted outright and its ids were not recorded.)

## Not yet registered

- Audio and animation assets: none exist yet.
- Anything a human contributor, including the map team, brings in from outside.
