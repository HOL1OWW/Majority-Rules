# 15 — AI ACCESS MAP: what an AI agent can actually see and do here

Why this file exists: **most AI models do not know they can see inside Roblox Studio.** They
assume their eyes stop at the repo. On this project that assumption is wrong, and work done
under it is slower and dumber than it needs to be. If you are an AI agent (any model), read
this once and then behave like someone with eyes on the place.

Everything below has been proven in practice on this project. Tool names come from the
Roblox_Studio MCP bridge as connected to the Freebuff client; if a future bridge renames a
tool, the *capability* is what matters — re-enumerate with the tool-search facility.

---

## 1. The bridge — how this access exists at all

- The **user** connects the Roblox_Studio MCP server in their Freebuff client settings
  (Settings → MCP servers / Connectors). **An agent cannot install it itself.** If no tools
  appear, the fix is on the human's side, not in the repo.
- Studio must be running **with the place open** and the MCP server enabled in Studio's
  Assistant settings. If the tool list replies "No Roblox Studio instances are connected",
  ask the human; don't retry in a loop.
- With it connected you get engine-level access to the live place — deeper than screen
  control: exact positions, properties, tags, attributes, script sources, and the ability to
  execute Luau in any datamodel.

### The studio_id dance

Every call takes a `studio_id`. The id is stable for a Studio session but **the bridge drops
and re-registers** (Freebuff restarts do it too). The pattern that always works:

```
1. list_roblox_studios  →  [{"id": "...", "name": "The Vote (placeId: ...)"}]
2. use that id everywhere; on "not connected" errors, re-list once before giving up
```

### The three datamodels — this is the key mental model

| Datamodel | When available | What it is |
|---|---|---|
| `Edit` | Studio open, not playing | The saved place. Your workspace for structural work. |
| `Server` | during Play | The game server. Secrets: all server state, MatchState, bots. |
| `Client` | during Play | The local player. Their PlayerGui, camera, client scripts. |

Read the state first with `get_studio_state` (returns `Current Studio Mode: Edit/Play` and
available datamodels). **`Edit` calls fail during Play** ("Edit datamodel is not available in
Play mode") and Play probes fail in Edit mode. Wrong-datamodel errors are the #1 time-waster.

---

## 2. Tool-by-tool, with what each is proven for

| Tool | Use it for | Proven on this project |
|---|---|---|
| `list_roblox_studios` | Discover the studio_id | Every session |
| `get_studio_state` | Mode + datamodel check before any call | The wedge of 2026-09-22 |
| `start_stop_play` | Start/stop Play Solo remotely | Bot playtests, boot verification |
| `search_game_tree` | The hierarchy: instances, classes, tags, attribute summaries | Found that Foundry's root was a Folder; full arena audits |
| `inspect_instance` | Full properties/attributes/tags of one instance | The `tags=[]` reveal on the stamped arena |
| `execute_luau` | **The big one** — run Luau in Edit/Server/Client | See section 3 |
| `get_console_output` | The Output window, per datamodel, with a limit param | Caught `aimDirection nil` spam, the podium concat-nil, boot verification |
| `script_read` / `script_grep` | Read/grep any script's Source in the place | Verified the fire fix at line 109 mid-session |
| `screen_capture` | A still of the Studio viewport (what the human sees) | Caught Lighting frozen dark by the Blackout modifier |
| `multi_edit` | Batch edits to one script in the place (dot paths) | Stamping/fixing without a repo round-trip |

`get_console_output` truncates hard on long output and **returns the tail, not the head** —
early boot lines scroll away. Two counters that work: (a) capture within ~5s of starting Play
while output is short, (b) don't rely on the console when a direct datamodel probe answers.

---

## 3. `execute_luau` is the universal tool

Anything the dedicated tools don't cover, Luau does, in all three datamodels:

```lua
-- Read game state (Server): require modules and inspect live tables
local MatchState = require(game:GetService("ServerScriptService")
    .MajorityRulesServer.Services.MatchState)
return MatchState.State .. " round " .. MatchState.Round

-- Mutate the place (Edit): stamp an arena root
local cs = game:GetService("CollectionService")
cs:AddTag(target, "MRArena")
target:SetAttribute("ArenaId", target.Name)

-- Control the human's editor camera (Edit) — see the courtesy rule below
workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
-- ...capture... then IMMEDIATELY:
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
```

This is how this project caught real bugs no file could have shown: a camera stuck
Scriptable 135 studs above the arena mid-round, a leaderboard that never received RoundState,
bot kill credit keyed by Model. **Probe the live datamodel before theorizing from files.**

### Courtesies when touching the human's session

- **Camera rule:** if you move the editor camera, reset `CameraType = Custom` immediately
  after. Leaving it Scriptable locks the human's mouse navigation (this happened once; the
  manual fix is the one-liner above in the Command Bar).
- **Lighting rule:** stop Play before relying on edit-mode Lighting — modifiers mutate it,
  and stopping Play can freeze mutated state into the session. Reset to neutral if dark.
- **No undo:** changes through the bridge bypass Ctrl+Z. Make deliberate, announced edits.

---

## 4. The honest blind spots

- **Team Test cloud servers are invisible live.** They run on Roblox's cloud, not in this
  Studio. You see them only through (a) Studio's Output relay (client-side lines), (b) the
  Roblox log files on disk after the fact, (c) the human telling you what they saw.
  (`TeamTestSuccess`, `Client ready for <user>` in the Studio log = the chain worked.)
- **No live video.** One frame per explicit capture (~12s round trip through the bridge).
  "Watching" a build session = flipbook on request, or polling live datamodel state (which
  IS real-time and cheaper — for playtests, prefer state polling over pixels).
- **No GUI driving.** No ribbon clicks, no gizmo drags, no dialogs. Engine-level edits are
  surgical; tactile work belongs to the human.
- **No unsaved editor text, no undo history.**

---

## 5. The local machine (beyond Studio)

Plain shell access to the dev machine gives you:

- **The repo** (`.../AI GAMES/The Vote`): git status/log/diff are always the first moves.
- **Roblox log files** — `%LOCALAPPDATA%\Roblox\logs\*.log`: Studio and client logs. This is
  where Team Test truth lives (`grep -a "TeamTest\|Client ready"`), and `find ... -mmin -30`
  finds the newest session log.
- **The publish pipeline** (Studio-first work): dirty check → place hash audit → compare vs
  repo → `git add`/`commit`/`push`. Documented in `docs/07-TEAM-WORKFLOW.md`.
- **Studio preferences (the human's File → Studio Settings)** —
  `%LOCALAPPDATA%\Roblox\GlobalSettings_13.xml`. Studio rewrites this file while it runs, so its
  **mtime is a freshness signal** (166 KB-1.8 MB of flags) and its values are the live preferences.
  A separate file, `GlobalBasicSettings_13_Studio.xml`, holds *basic* settings (camera mode,
  invert-Y, touch controls). Engine flag values — **including File → Beta Features enrollment**
  (`FFlagNewCameraControlsBetaFeature`) — live in `ClientSettings\StudioAppSettings.json` (1.4 MB,
  rewritten while Studio runs; a grep that finds nothing may have raced a write, so re-read it).
  Readable from the shell, **not writable through the bridge** — see the §7 limit entry.
- **`py tests/syntax_check.py`** — run it before every claim of "done". 70+ files, seconds.
- **Rojo** — runs on the machine syncing repo → place. Known quirk: it diffs at connect, so a
  file edited while connected may be stale in the place; verify with `script_grep`, and if
  needed patch the place's copy directly via `multi_edit`.

---

## 6. Working protocols proven here

1. **Probe live before theorizing.** A file read is a hypothesis; the datamodel is the fact.
2. **Marker greps lie.** Checking "is this code in the place" by string markers proves
   presence, not wiring. When behavior contradicts markers, read the whole block
   (`for line in src:gmatch("[^\n]+")` + index) or run the logic live.
3. **Early-boot console capture.** Start Play, wait 5–10s, capture with a small limit before
   bot spam floods and truncates the boot section.
4. **The wedge.** If Play mode reports stopped but `get_studio_state` still says Play and
   probes fail with "Target is not reachable": stop, wait 10s, start again; if it persists,
   verify from Edit mode (the facts you need are usually available there) and hand the human
   the two-click finish rather than burning ten minutes.
5. **Golden rule for the humans:** `Arenas` lives in `ServerStorage` before any Play. The map
   team drags it to Workspace to build; boot finds nothing if they forget to drag it back.
6. **Say what you'll touch.** Read-only audits are read-only; state your intent first.

---

## 7. The discovery ledger — your most important duty

**Every AI model has a different reach.** One agent discovers a tool, a quirk, or a wall that
another will never stumble on by itself. If a discovery is not written here before the thread
ends, it dies with the conversation and the next agent burns an hour re-proving it (or worse,
assumes the wall is permanent and designs around a limit that does not exist).

So this is a standing rule, not a suggestion:

> **If you discovered a capability, technique, or limit that this document did not already
> describe, YOU must add it to this document in the same session, and commit it.**

The test: anything that surprised you — a tool doing more than its description, a silent
failure mode, a workaround that unlocked something — is a discovery. "It's in the chat log"
never counts; the chat log is the one place future agents cannot read.

### How to write an entry

Append under the matching heading below (create a new heading if none fits). One entry, one
claim, dated, with the proof and the error signature someone would see:

```
### YYYY-MM-DD — <one-line claim>
<What was discovered. How to reproduce or use it. What it costs or breaks.>
<Proof: the exact error, log line, or probe result that demonstrated it.>
```

### Capability discoveries (things an agent can now do)

### 2026-09-23 — The human's Studio preferences are readable on disk, and numeric tokens decode from the docs
When the human reports a problem with **Studio itself** (an editor control that stopped behaving),
the truth is usually outside the place and outside the datamodel: in
`%LOCALAPPDATA%\Roblox\GlobalSettings_13.xml`. Plain file reads plus the public docs decode it —
match the XML `name`, then fetch the matching enum reference page to turn a bare token number into a
name. `inspect_instance` will never show any of this, and the datamodel does not contain it at all.
Proof, one round trip end to end: the file held `<token name="Camera Speed Adjust Binding">1</token>`,
and `http_get` on `https://create.roblox.com/docs/reference/engine/enums/CameraSpeedAdjustBinding.md`
returned `None=0, RmbScroll=1, AltScroll=2` with the plain-language copy *"Scrolling while holding the
right mouse button adjusts the camera fly speed instead of zooming"* — which named the exact mechanic
the owner had lost, in a session where the place was completely innocent.
`http_get` reaches any `create.roblox.com/docs` page ending in `.md`, including the
`/docs/reference/engine/enums/<Name>.md` set. Prefer it over guessing a token's meaning.
**Correction, same day:** the decode was right but the token was not the live cause — under the
2026 camera beta it is inert and its Settings entry is *gone from the UI*. The mechanic the owner
had lost came back through **File → Beta Features**, not this token. Read the beta-enrollment
entry below before acting on this one.

### Limit discoveries (things that look possible but are not)

### 2026-09-23 — Studio preferences are not writable through the bridge, even with `settings()`
`settings()` **is available** inside an Edit-mode `execute_luau`, and it reads plain numeric Studio
settings: `settings().Studio["Camera Mouse Wheel Speed"]` returned `15`. It is not a universal
handle. Capability-gated preferences refuse both read and write from that thread:
`The current thread cannot read 'Camera Speed Adjust Binding' (lacking capability RobloxScript)`
and the same for `CameraNavigationModel`. `pairs(settings().Studio)` also fails — it is an Instance,
not a table (`invalid argument #1 to 'pairs' (table expected, got Instance)`).
**Consequence to hand the human, not fight:** an editor-side preference change is a two-click job for
them (Studio Settings → Camera), or a one-token edit to `GlobalSettings_13.xml` *with Studio closed* —
Studio rewrites that file while running, so an edit under a live session is either ignored or
overwritten. Do not burn probes looking for a scripted path; there is none at this capability.
**Caveat, same day:** "Studio Settings → Camera" is not always available as that manual route — under
the 2026 camera beta the option had no UI at all (the beta *swept away* those configurations). See the
beta-enrollment technique entry below; the human's route was File → Beta Features instead.

### 2026-09-23 — `inspect_instance` never returns CollectionService tags
`inspect_instance` returns `properties`, `attributes` and a children summary, and **no tag list at
all** — a tagged part and an untagged one look identical in its output. Confirmed both ways in one
session: `Foundry` (which carries `MRArena`, proven present by `CollectionService:HasTag`) came back
with an `attributes` object and nothing tag-shaped, and a freshly imported mesh carrying no tags came
back looking the same.
**Use `execute_luau` with `instance:GetTags()`** — and `CollectionService:GetTagged(tag)` for the
reverse direction. Cost of not knowing: a false "the tag is missing" diagnosis, which is the very
first thing `docs/01-ARENA-CONTRACT.md` checks and the check D-056 exists because of.

### 2026-09-23 — `MeshPart.MeshId` cannot be written at runtime in Studio, by any thread
Assigning `MeshPart.MeshId` from game code fails with `The current thread cannot write 'MeshId'
(lacking capability NotAccessible)`. This is **not** a probe artefact: the round loop hit it too,
and because `LootService.SpawnAll` runs inline in a round, the throw **aborted the round** —
`[MR] WARN Round 1 aborted: The current thread cannot write 'MeshId' (lacking capability
NotAccessible)`, once per round, live.
What IS writable from the same thread: **`SpecialMesh.MeshId`**, **`SpecialMesh.TextureId`**, and
**`MeshPart.TextureID`**. `MeshPart.MeshContent` is gated exactly like `MeshId`.
What also works: **`Clone()` of an existing `MeshPart` keeps `MeshId` and `TextureID`** and the clone
renders, resizes and reparents normally (verified on `Workspace.PROP_STAGING.AGENT_Crate_1to1`).
Re-assigning `MeshId` on the clone afterwards still fails.
**Use `MeshPart.MeshSize`** (readable) when a `SpecialMesh` needs a scale factor — it reports the
mesh as authored, so `Scale = target / MeshSize` is exact.
Cost of not knowing: three aborted rounds of a Studio match, and a crate fix that needed a Play
restart to take effect.

### 2026-09-22 — `require()` inside client-side `execute_luau` returns a sandbox copy
During Play, calling `require(SomeModuleScript)` from an `execute_luau` probe on the **Client**
datamodel can return a **detached copy of the module**, not the one the running game uses.
Calling its functions silently does nothing: a UI-driving call like `Scoreboard.onMatchResult(...)`
returns success while the real PlayerGui never changes. Cost: two wasted probe rounds reading
"injected ok" from a module that touched nothing.
**Workaround:** verify client-side state through instances (read PlayerGui descendants directly),
not through module state; drive UI only through the real event pipeline (server broadcast →
connection). Server-side `require` of server modules has not shown this split.

### Technique discoveries

- **(2026-09-22) `get_console_output` can serve a stale cache.** During one Play session it returned the identical old output across Server/Client/Edit datamodels while the session ran fine. Proof: the Studio log file (`AppData/Local/Roblox/logs/*Studio*_last.log`, grep for `[MR]` and `FLog::CreatorOutput`) showed fresh lines for the same wall-clock window. Fallback: read the log file directly — it is always the ground truth for Play sessions. (protocols that worked)

- **(2026-09-23) "No Roblox Studio instances are connected" is usually transient — retry before believing it.** Mid-session, `list_roblox_studios` returned `{"studios":[]}` and an `execute_luau` failed with the not-connected error, within seconds of identical calls that had worked. A second `list_roblox_studios` returned the studio, and the same `execute_luau` then succeeded unchanged. Cost: concluding the human closed Studio and asking them to reopen it.
  **Protocol: on that error, re-list, then retry once before reporting anything.**

- **(2026-09-23) Finding content the human just added.** When the owner says "I added X" without saying where, `search_game_tree` with `keywords` locates it in one call — it matches instance *names* (`keywords: "crate,pistol"` found `Workspace.pistol_crate` immediately), so guess the prop's likely words. Then separate repo content from Studio-only content with `git status --porcelain`: whatever the human added in Studio is untracked, and **Rojo syncs one way — files → Studio — so nothing leaves the place on its own.** Studio-side work has no durable record until someone writes one.

- **(2026-09-23) Capturing the asset ids of a human-imported mesh.** A prop imported through Studio's 3D importer has no generation job to read ids back from. Read them off the instance instead: `MeshPart.MeshId` and `MeshPart.TextureID`, plus the `RBX_ReimportId` attribute the importer writes. A plain `inspect_instance` on the part prints both ids, so no id-lookup API is needed to get the pair into `assets/PROVENANCE.md`.

- **(2026-09-23) An editor-side complaint is not a place-side bug — check the preferences file before the codebase.** When the owner says something *in Studio* stopped working (scroll behaviour, keybinds, selection modifiers), the cause is usually a changed Studio default, and the project's own code is unrelated. Sequence that worked: grep the repo for the input in question (to rule out the game's own handling) → read the Studio settings file → decode any token against the docs enum page → check the new value against the feature's changelog thread on the DevForum. That is where the July 2026 camera-navigation rewrite surfaced, and where affected developers' reports matched the owner's wording almost verbatim. Cost of skipping it: "fixing" the game when the game was never broken.

- **(2026-09-23) This project can be edited by tools that are not this bridge.** `docs/12` lists Blender as agent-drivable headless; it has now actually been driven. The owner connected **Google Antigravity's Gemini agent to Blender over an MCP server and gave it full read/write access to the project directory**, which produced a prop plus four scripts in one afternoon. Nothing was lost, but the file tree changed between sessions without this agent doing it.
  **Protocol: whenever the human mentions any tool outside this bridge, run `git status --porcelain` and `git log --oneline -3` before planning work.** Untracked additions are the expected signature; **a modified tracked file is a much bigger deal**, because a Rojo-connected place will already have picked it up.

- **(2026-09-23) A cosmetic failure can abort a gameplay round — guard it, and let the log's clock point at the call site.** `LootService.SpawnAll` runs inline in the round, so an exception in crate *appearance* code propagated into the round's own error handler and ended the round with no loot, three rounds running. Two transferable moves came out of it: (1) **anything cosmetic that runs on a gameplay path gets a `pcall` and a fallback** — a crate's look must never be able to end a round; and (2) **the log's timestamps named the call site**: the abort landed exactly **3.000 s** after `Transform phase Commit`, and `Escalation.CountdownSeconds` is 3, which pinned it to `publish("Live")` → `SpawnAll` without adding a single debug line. Check a suspicious timestamp against the phase constants before instrumenting anything.

- **(2026-09-23) A Studio beta can remove a Settings option while its value is still live in the preferences file — check `ClientSettings\StudioAppSettings.json` for enrollment before chasing a "missing" setting.** That JSON is where File → Beta Features persists enrollment, as a **string** flag (`"FFlagNewCameraControlsBetaFeature": "True"`) beside the beta's own sub-flags (`FFlagNewCameraControls_BetaUpdate6`, `_IncrementalZoom`, `_UseAltForFocus`, …). Live case: the 2026 camera beta was enrolled on this machine **and** the option it removed was absent from the Settings window — the announcement says *"We swept away redundant configurations under Studio Settings > Camera"* — while `<token name="Camera Speed Adjust Binding">1</token>` still sat in `GlobalSettings_13.xml`, inert. The two camera generations coexist in that XML: camelCase tokens (`CameraNavigationModel`, `CameraTweenFocus`, `CameraZoomToMousePosition`) belong to the new camera, spaced-name tokens (`Camera Mouse Wheel Speed`, `Camera Speed Adjust Binding`, `Camera Zoom to Mouse Position`) to the classic one.
  Proof this was the operative cause rather than a guess: the owner's symptom ("scroll doesn't go back or forward") matched July-2026 thread 4751512 nearly verbatim — *"Scroll wheel is now instead completely disabled while moving around"*, *"the inability to right-click and scroll forward"* — and that thread's own remedy is disabling the beta (*"Disabling the beta features allows it"*).
  **Protocol: read both files, then hand the human the File → Beta Features toggle; flipping that one JSON line is the file-level equivalent and needs Studio closed. Do not edit the XML token — under the new camera it is inert.**
  Status two months on (thread's **last** page, 2026-09-05): the regression is **still open** — one user reports the wheel is made unresponsive by the new camera's interpolation and that cursor-position scrolling is gone, and Roblox's `tnavarts` replies *"After RDC we're going to do another significant iteration. I think it should address the things you're talking about there."* The same post adds the fallback camera *"has a weird acceleration issue"*, so offer the toggle with both sides showing: leaving restores the gesture but not the 2026 feel, and the beta may be worth re-enabling soon.
  **Owner's decision, same session:** *keep the beta and wait for the post-RDC iteration.* So a future wheel complaint in this workspace is expected behaviour on a knowingly-enrolled beta, not a fresh regression — check File → Beta Features and the thread's last page before diagnosing anything.

---

## 8. Where the rest of the context lives

- `docs/10-HANDOFF.md` — current state, what's installed, what's half-done. **Start here.**
- `docs/07-TEAM-WORKFLOW.md` — the human-side sync/publish workflows.
- `docs/01-ARENA-CONTRACT.md` + `ReplicatedStorage/Shared/Tags.lua` — the map↔code contract.
- `docs/DECISIONS.md` — every architectural decision with its D-number. The project's memory.
