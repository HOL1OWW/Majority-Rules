# Icon Assets — from PNGs on disk to the ballot

**Status:** icons drawn, module wired with fallback, image path live — only the **upload
session** (yours) is outstanding. Until then every chip shows its emoji, exactly as before.

---

## Part A — what already exists

- `assets/icons/staging/*.png` — 25 icons, 256×256, flat line style, transparent
  background, drawn in the theme's ink color. One per `Effects` token.
- `assets/icons/contact_sheet.png` — all 25 labeled on one sheet; review it before
  uploading.
- `tools/generate_effect_icons.py` — regenerates everything (`py tools/generate_effect_icons.py`).
  Edit a glyph there if you want different art, re-run, re-upload.
- `tools/harvest_icon_ids.lua` — turns your uploaded ids into the finished ASSET table.
- `StarterPlayer/StarterPlayerScripts/MajorityRulesClient/UI/EffectIcons.lua` — the
  module the UI reads. Emoji fallback until ids are filled in.

## Part B — the upload session (you, ~15 minutes)

1. Open `assets/icons/contact_sheet.png` and sanity-check the art.
2. Go to **create.roblox.com → Creations → Development → Image Assets** and bulk-upload
   every PNG in `assets/icons/staging/`. Keep the filenames as they are — the filename
   **is** the effect token name the harvester matches on.
3. When the uploads finish, copy all the new asset ids from the dashboard list.
4. In Studio, open the Command Bar and paste the contents of
   `tools/harvest_icon_ids.lua`, but first edit its last line to run with your ids —
   simplest: add at the top `_G.MR_ICON_IDS = "id1, id2, id3, ..."` (order does not
   matter; matching is by asset name).
5. The Output window prints a finished `EffectIcons.ASSET = { ... }` table. Paste it over
   the empty table in `EffectIcons.lua`, save, Rojo syncs, done — the ballot flips from
   emoji to icons by itself.

## Part C — verifying it took

- Boot a Play session. On the ballot, image chips are 18px square line icons; emoji chips
  are the familiar glyphs. Mixed states are legal mid-migration.
- The APPROVED stamp shows the same icons for the winning modifier.
- `EffectIcons.countAssets()` (Command Bar) returns how many tokens have real assets —
  25 means complete.

## Style rules for future icons

- 256×256, transparent background, single ink `(24,25,30)`, flat line art with ~40px
  clearance, drawn in `tools/generate_effect_icons.py` and re-uploaded under the token's
  exact name.
- A new Effects token with no entry renders **no chip** — never a wrong one.
