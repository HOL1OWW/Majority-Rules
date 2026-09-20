# 10 — HANDOFF: current state of the build

**Read this first if you are picking this project up cold** — a new agent thread, a new machine, or
future-you in three weeks. It is the session's memory written to disk. Then read
`docs/00-VISION.md` (what the game is) and `docs/09-SETUP.md` (how to run it).

Last updated: **2026-09-20**.

---

## The short version

The code is complete for Phases 0–1: the vote-driven modifier engine, the arena contract, the
transform scheduler, server-authoritative combat, the client vote UI, and a hand-built gray-box
arena. **It runs.** As of 2026-09-20 it boots, loads 23 modifiers, loads `Foundry`, opens ballots,
transforms the arena, resolves conflicts and scores — two consecutive matches, zero errors, zero
warnings, with the vote panel visible on screen. Ten faults found on the way were fixed and committed.

What has **never** happened: anything was shot at anything. Hitscan, damage, elimination, points, and
every modifier that depends on them (`Vampire`, `Fragile`, `Ricochet`, `InfiniteAmmo`) are still
unexercised, along with 8-player rounds and mobile/console input. A two-player local playtest is the
next real milestone.

---

## Where everything lives

| Thing | Location | State |
| --- | --- | --- |
| **Canonical project** | `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote` | the real repo — 64 Luau modules, 10 docs. Still inside OneDrive; see "Moving" below |
| **GitHub** | `https://github.com/HOL1OWW/Majority-Rules` (remote `origin`) | **in sync** — `origin/main` and local `main` are the same commit. The agent can push from this machine (the credential manager authenticates), so "publish" includes the push. |
| **Studio place** | `The Vote`, placeId `72737093276287` | **Team Create**, so a second contributor works in the same place and needs no tooling. Contains the hand-built `Foundry` arena and all 64 synced scripts. |
| **Stray copy 1** | `C:\Users\selab\Majority-Rules` | the DevForum guide's `rojo init` skeleton (`Hello.luau`). **No game code. Delete it.** |
| **Stray copy 2** | `...\Documents\GitHub\Majority Rules` | already deleted. |

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

## The daily loop — start here every session

**Opening (about a minute).**

1. **Open the project folder in VS Code** — `File → Open Folder` →
   `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote`. Open the *folder*, not a file, so the
   tasks below exist.
2. **Terminal → Run Task… → `rojo serve`.** Leave that terminal open; you want to see
   `Rojo server listening: Address: localhost, Port: 34872`. The task runs it from the workspace root
   because `rojo` only resolves inside a folder containing `aftman.toml`.
3. **In Studio: open the place → Plugins → Rojo → Connect.** Confirm it says Connected. If it
   complains about a session lock, `Ctrl+C` the task, run it again, reconnect.
4. **Press Play once** to confirm the engine is alive. Expect `[MR] server booting`,
   `Modifier registry OK: 23 modifiers loaded`, `Arena loaded: Foundry`, then `Client ready for …`.

Only if something looks wrong, ask the server what it is serving — it must say `MajorityRules`: the
`curl` line is in "Where everything lives" above.

**Working.**

- Edit scripts in VS Code → they reach the open place in about a second. Press Play to test.
- Or edit scripts in Studio (the workflow is `docs/07-TEAM-WORKFLOW.md` section 8) — press **Ctrl+S**,
  because an unsaved buffer is invisible to Rojo, to git and to every check.
- Geometry: build and move things in Studio freely. `ServerStorage.Arenas` is protected by
  `$ignoreUnknownInstances`.
- `rojo build -o build/MajorityRules.rbxl` produces an uploadable place file when you need one.

**Publishing.** Say **"publish"** to the agent. It checks for unsaved Studio text, hashes the place
against the repository so that nothing has to be named, pulls the differing scripts into their files,
shows the diff, commits and pushes to GitHub. If the **map** changed, do the one manual step first:
right-click the arena → *Save to File* → `assets/arenas/` (nothing can export an instance for you).

**Closing (this is the part that protects the work).**

1. `Ctrl+S` in Studio.
2. Ask for a publish if you have not already — unpushed work is one drive failure from gone.
3. `Ctrl+C` the `rojo serve` terminal.
4. Close Studio, VS Code and Freebuff.

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

A versioned copy sits at `assets/arenas/Foundry.rbxm` (binary, 8.4 KB, still current). It is a
backup, not a load path — re-export it after significant geometry changes. The leftovers from the
stray sync (`ReplicatedStorage.Shared.Hello`, `ServerScriptService.Server`,
`StarterPlayerScripts.Client`) were deleted from the place on 2026-09-20.

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

1. **Two-player playtest — `Test → Players: 2`.** This is the untouched half of the game: nothing has
ever been shot at anything. Watch hitscan registration, damage, elimination, points, and the modifiers
that depend on combat (`Vampire`, `Fragile`, `Ricochet`, `InfiniteAmmo`, `MeleesOnly`, `PistolsOnly`,
`ShotgunsOnly`). Expect client-side and combat errors; that is the next round of work and it is the
interesting kind. Report what the Output window says rather than what you see.
2. **Build the Clerk** — the mascot, per `docs/05-BRAND.md`. It is the face of the brand and the
   loudest thing missing from the pitch.
3. **Arenas 2 and 3**, against `docs/01-ARENA-CONTRACT.md`. One arena is a demo; three is a game. The
   brief for map contributors is `docs/08-MAP-AI-BRIEF.md`.

Standing item: **move the project out of OneDrive** (next section). Safe now — the code, the docs and
the arena are all on GitHub.

Re-export the arena as `.rbxmx` rather than `.rbxm` the next time you touch it, so its diffs are
readable. See `assets/arenas/README.md`.

---

## Moving the project out of OneDrive

The folder is still inside OneDrive against the advice in `docs/09-SETUP.md`. The conditions that
made this risky are gone — the game boots, and the code, docs and arena are all on GitHub — so this is
safe to do whenever you want to spend an hour on careful file moves:

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
