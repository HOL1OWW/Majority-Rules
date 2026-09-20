# 10 — HANDOFF: current state of the build

**Read this first if you are picking this project up cold** — a new agent thread, a new machine, or
future-you in three weeks. It is the session's memory written to disk. Then read
`docs/00-VISION.md` (what the game is) and `docs/09-SETUP.md` (how to run it).

Last updated: **2026-09-20**.

---

## The short version

The code is complete for Phases 0–1: the vote-driven modifier engine, the arena contract, the
transform scheduler, server-authoritative combat, the client vote UI, and a hand-built gray-box
arena. **None of it has ever been executed.** The next real milestone is one full playtest, and
the expected outcome is a debugging session, not a demo.

---

## Where everything lives

| Thing | Location | State |
| --- | --- | --- |
| **Canonical project** | `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote` | the real repo — 64 Luau modules, 10 docs. Still inside OneDrive; see "Moving" below |
| **GitHub** | `https://github.com/HOL1OWW/Majority-Rules` (remote `origin`) | attached and merged locally; **local `main` is ahead of `origin/main` and needs a push** |
| **Studio place** | `The Vote`, placeId `72737093276287`, DataModel renamed to `Majority-Rules` | contains the hand-built `Foundry` arena; awaiting a Rojo sync of the scripts |
| **Stray copy 1** | `C:\Users\selab\Majority-Rules` | the DevForum guide's `rojo init` skeleton (`Hello.luau`). **No game code. Delete it.** |
| **Stray copy 2** | `C:\Users\selab\OneDrive\Documents\GitHub\Majority Rules` | a second checkout of the same GitHub repo — LICENSE, README, `main.luau`. **Delete it.** |

If a `rojo serve` is ever running from either stray copy, Studio will sync an empty skeleton into the
place and it will look exactly like "the game is gone". Check which project owns the connection:

```bash
curl -s http://127.0.0.1:34872/api/rojo | tr -c '[:print:]' '\n' | grep -A1 projectName
```

It must say **`MajorityRules`**. (`Majority-Rules` means a stray copy is serving.)

---

## What is installed on this machine (verified, not assumed)

* **Aftman 0.3.0**, with **Rojo 7.7.0** already in `%USERPROFILE%\.aftman\tool-storage` — works
  offline. `aftman.toml` is the manifest; `rokit.toml` was deleted (see `DECISIONS.md` D-018).
  Rokit is **not** installed.
* **Rojo Studio plugin** — `%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm`.
* **VS Code** 1.138 with `evaera.vscode-rojo`, `kampfkarren.selene-vscode`,
  `nightrains.robloxlsp`. Luau LSP and StyLua are *not* installed, so there is no type checking or
  formatting in the loop yet; `aftman.toml` has them commented out.
* **Git + GitHub Desktop**, identity `HOL1OWW <selabshukoor123@gmail.com>`.
* **Rojo parses this project cleanly** — `rojo sourcemap` and `rojo build` both succeed, producing
  62 `ModuleScript`s, 1 `Script` (`MajorityRulesServer.Bootstrap`), 1 `LocalScript`
  (`MajorityRulesClient.Bootstrap`) and 16 `Folder`s.

---

## The daily loop

```bash
cd "/c/Users/selab/OneDrive/Documents/AI GAMES/The Vote"
rojo serve            # leave running; `rojo` only resolves inside this folder
```

Then in Studio: **Plugins → Rojo → Connect**. Editing any `.lua` file syncs into the open place in
about a second. `rojo build -o build/MajorityRules.rbxl` produces an uploadable place file.

**When a fix appears to do nothing, suspect delivery before suspecting the fix.** After a Play/Edit
cycle the plugin can hold a socket open while no longer patching, so Studio runs stale code. Restart
`rojo serve`, then read the script back *from Studio* to confirm the change arrived — the sequence
that matters is repo → place → runtime, and only the last of those shows up in the Output window.

---

## The arena, as it stands in the place

`ServerStorage.Arenas.Foundry` — `Geometry` (6 parts), `Transforms` (3 folders), `Hazards` (1),
`Spawns` (8), `LootPoints` (6), `VoteShowcase` (5), `VFX` (1), `Audio`, `Variants`.

It survived a stray sync because `Arenas` is marked `"$ignoreUnknownInstances": true` in
`default.project.json`. **Never remove that flag** — it is the only thing protecting hand-built
geometry from Rojo.

Leftovers currently in the place from that stray sync, safe to delete in Explorer:
`ReplicatedStorage.Shared.Hello` and `ServerScriptService.Server`.

---

## What is NOT built

* Phase 5 in full: saves, Clout currency, missions, weapon mastery, the shop. `Economy.Enabled` is
  `false`, so no code path can charge anyone.
* The Clerk (mascot) — model, animation, voice lines. Design is in `docs/05-BRAND.md`.
* Real audio ids — `AudioService` is a deliberate no-op shell.
* 1 arena and 23 modifiers, against a 40+ modifier target. `docs/08-MAP-AI-BRIEF.md` is the brief
  handed to map contributors.
* Mobile/console gamepad input paths have never been exercised.

---

## Immediate next steps, in order

1. **Push to GitHub.** GitHub Desktop → *File → Add Local Repository* → this folder → **Push
   origin**. `origin` is already configured, and the merge means it is a clean fast-forward.
2. **Playtest.** Connect Rojo, press **Play**, read the Output window. Every log line goes through
   `src/shared/Util/Log.lua`, so it is readable. Expect errors — ~8,800 lines have never run.
3. **Fast smoke test** (see `docs/09-SETUP.md`, Step 7) — a `ServerStorage.DevConfig` folder with
   `ForceModifiers = "SmallMap,IceFloor,CoverCrates"`, `SkipVote = true`, `RoundSeconds = 30`.
4. **Version the arena.** Right-click `Foundry` → *Save to File* → `assets/arenas/Foundry.rbxmx`,
   then commit. Until then the arena exists only inside the place file.

---

## Moving the project out of OneDrive

The folder is still inside OneDrive against the advice in `docs/09-SETUP.md`. Do this **once the
game boots and step 1 is done** (the GitHub copy is the safety net):

```bash
mkdir -p /c/dev
mv "/c/Users/selab/OneDrive/Documents/AI GAMES/The Vote" /c/dev/majority-rules
```

Then: reopen the Freebuff project at `C:\dev\majority-rules`, and in GitHub Desktop use
*File → Add Local Repository* again (GitHub Desktop tracks repos by absolute path, so it will report
the old one as missing — that is expected, and `Remove from list` does not touch files).

**Why it matters:** OneDrive syncing a `.git` directory is a documented way to corrupt a repository,
and Rojo writes on every keystroke, so every edit queues a sync upload.

**No agent thread survives the move.** Conversation history is bound to the project folder; the
files and these docs travel, the chat does not. That is why this document exists — it is the
handoff, and `AGENTS.md` points at it.
