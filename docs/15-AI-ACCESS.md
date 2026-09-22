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

*(empty — be the first to add one)*

### Limit discoveries (things that look possible but are not)

### 2026-09-22 — `require()` inside client-side `execute_luau` returns a sandbox copy
During Play, calling `require(SomeModuleScript)` from an `execute_luau` probe on the **Client**
datamodel can return a **detached copy of the module**, not the one the running game uses.
Calling its functions silently does nothing: a UI-driving call like `Scoreboard.onMatchResult(...)`
returns success while the real PlayerGui never changes. Cost: two wasted probe rounds reading
"injected ok" from a module that touched nothing.
**Workaround:** verify client-side state through instances (read PlayerGui descendants directly),
not through module state; drive UI only through the real event pipeline (server broadcast →
connection). Server-side `require` of server modules has not shown this split.

### Technique discoveries (protocols that worked)

---

## 8. Where the rest of the context lives

- `docs/10-HANDOFF.md` — current state, what's installed, what's half-done. **Start here.**
- `docs/07-TEAM-WORKFLOW.md` — the human-side sync/publish workflows.
- `docs/01-ARENA-CONTRACT.md` + `ReplicatedStorage/Shared/Tags.lua` — the map↔code contract.
- `docs/DECISIONS.md` — every architectural decision with its D-number. The project's memory.
