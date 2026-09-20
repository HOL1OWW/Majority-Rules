# assets/arenas

Hand-authored arenas live here, one `.rbxmx` per arena, named to match the model in
`ServerStorage.Arenas` (so `Foundry` → `Foundry.rbxmx`).

## Exporting an arena from Studio

Play mode must be stopped first.

1. In Explorer: `ServerStorage` → `Arenas` → right-click the arena model → **Save to File…**
2. Save into this folder as `Foundry.rbxmx`.
   Pick **Roblox Model Files (\*.rbxm, \*.rbxmx)** in the file type dropdown — binary `.rbxm` is
   also fine and is what Studio suggests first. Either way, the file must be **XML** (`.rbxmx`) if
   you want to be able to read and review its diff in git; binary works but is opaque.
3. Commit it. `*.rbxm` and `*.rbxmx` are tracked; built place files (`*.rbxl`, `*.rbxlx`) are not.

## What this file is, and is not

**It is a versioned copy.** The game does not currently load it: `assets/` is not mapped in
`default.project.json`, so the arena the game actually plays comes from `ServerStorage.Arenas` in
the place file. That place file exists in exactly one location and is not in version control, which
is the whole reason this export matters — today the real Foundry geometry has no second copy.

**It is not yet the source of truth.** Making it one is a deliberate step with a trade-off:

* map it in `default.project.json` (Rojo can insert a `.rbxmx` directly), delete the hand-built
  model from the place, and the arena becomes reproducible from the repository by anyone;
* but then Rojo owns the geometry, so edits made in Studio do **not** flow back — they must be
  re-exported. Two-way editing of one model is exactly the drift this repository is built to avoid.

Until that decision is made, keep the export fresh after any significant geometry change, and
treat `BuildFoundry` (`src/server/Dev/BuildFoundry.lua`) as what it is: a gray-box placeholder that
only builds when `ServerStorage.Arenas` is empty, so a fresh place still has something to play on.
