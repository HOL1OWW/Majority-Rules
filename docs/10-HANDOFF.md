# 10 — HANDOFF: current state of the build

**Read this first if you are picking this project up cold** — a new agent thread, a new machine, or
future-you in three weeks. It is the session's memory written to disk. Then read
`docs/00-VISION.md` (what the game is) and `docs/09-SETUP.md` (how to run it).

Last updated: **2026-09-21**.

---

## The short version

The code is complete for Phases 0–1: the vote-driven modifier engine, the arena contract, the
transform scheduler, server-authoritative combat, the client vote UI, and a hand-built gray-box
arena. **It runs.** As of 2026-09-20 it boots, loads 23 modifiers, loads `Foundry`, opens ballots,
transforms the arena, resolves conflicts and scores — two consecutive matches, zero errors, zero
warnings, with the vote panel visible on screen. Ten faults found on the way were fixed and committed.

As of 2026-09-21 **combat has fired for the first time**, and getting there took three bugs that had
each been invisible precisely because nothing could die (see `DECISIONS.md` D-020, D-023, D-024): the
scheduler collected no tweens, no shot could resolve a victim, and no player's `Humanoid.Died` was
ever connected. With those fixed, a 3-bot session ran three rounds that **all ended by elimination**,
with kill credit and points landing on the HUD.

**Hand edits to the Foundry hall now persist** — 2026-09-22. The Bootstrap rule that rebuilt any hall
whose `GeneratorRevision` stamp disagreed with the generator source now skips any arena stamped
`HandAuthored = true`. That attribute is the freeze button: set it in Studio (no scripting) and the
hall stops being generator property — you edit it with parts like any map, hand edits survive Play,
and the publish pipeline ports the whole hall to `assets/arenas/Foundry.rbxmx` (unmapped-instance
detection: a model in `Arenas` with no repo file is reported as `ONLY IN STUDIO`, which is the signal
to export it). While frozen, code changes to `BuildFoundry.lua` do **not** reach the hall — unset
`HandAuthored` and the next Play rebuilds from source. See doc 7 §9.1 for the full workflow.

**Speed and scale changed on 2026-09-22 (D-046, D-047).** Base WalkSpeed is 22 and **sprint exists**:
Shift, server-authoritative through `GameplayService`'s stamina state machine (client only sends
`Net.SprintInput`; `SprintController` renders a guessed bar). The **Colosseum** is a second arena —
a 180-stud open sand floor, drum wall that shrinking modifiers crush inward, rising cover — built by
`Dev/BuildColosseum.lua` and now the fallback build. The hand-authored Foundry still works as-is.

**Bots exist now** — `BotService`, Studio-only behind `DevConfig.BotCount`, so a round can be played
and observed without a second human. Read `docs/11-BOTS.md`. This is what replaced "find a second
player" as the way to exercise combat. Since D-044 they fight like bodies, not turrets: bot shots
damage bots (the old player-only gate made every bot-on-bot shot a whiff), they retaliate against
whoever last hit them, drift while holding, and disengage when losing.

**The loadout leak was real, and is fixed.** D-026 said there was no carry-over; a round that voted
`PistolsOnly` followed by a round that voted for anything else proved there was — every later round
handed out pistols, because `CombatService.resetRound` never restored the default loadout that its two
siblings (`LootService.reset`, `GameplayService.reset`) both restored. `ServerScriptService/MajorityRulesServer/Dev/LoadoutCheck.lua`
fails loudly on it after every transform and now passes; D-027 has the before/after logs.

**The reference arena was redesigned, against a gate that now actually measures things.** The contract's
`ClearanceRadius` was documented as "used by tooling" and no tooling read it, so the first `Foundry` layout
passed the validator while four of its eight **spawns** sat inside cover (players ejected the moment cover
rises) and four of its six loot points had crates spawning inside cover — invisible, and takeable straight
through it. Ten defects in total once the check existed. The arena is now a colonnade of eight cover pieces
with a contested centre, 64 small tiles instead of 16 large ones, and walls tall enough that `LowGravity` is
not a way out. `CollapsingFloor` was changed with it, because its pace turned out to be a property of the
arena's tile count rather than the modifier's (D-029). Full reasoning, the measured sightline numbers, and the
probes to re-run them are in **`docs/13-ARENA-DESIGN.md`**; decisions are D-028 and D-029.

What has still **never** happened: two humans in one match, 8-player rounds, and mobile/console input.
No modifier that depends on combat (`Vampire`, `Fragile`, `Ricochet`, `InfiniteAmmo`) has been checked
against a real fight — the bots make that check possible now.

---

## Where everything lives

| Thing | Location | State |
| --- | --- | --- |
| **Canonical project** | `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote` | the real repo — 66 Luau modules, 14 numbered docs. Still inside OneDrive; see "Moving" below |
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

`ServerStorage.Arenas.Foundry` — a 128 x 128 hall (4x the floor of the first version): `Geometry` (the
stepped frame plinth, the shell in stacked courses with 24 ribs and 24 lit window bays, a gold dais
with its ballot X and brass ring, 4 corner balconies, a gallery circuit on all four walls, the Clerk's
box standing on the north gallery, 15 filing banks, an archive of 4 rolling shelves, 5 voting booths,
a switchback queue, 4 busts, roof pipework, 14 pendant lamps, 6 banners, 10 pressed stamps, notice
boards, planters, turnstiles), `Transforms` (`Floor` **256 tiles of 7.5 studs**, `Walls` 4 partitions in
slats, 20 dressed columns authored hidden), `Hazards` (1 lava volume), `Spawns` (8), `LootPoints` (11),
`VoteShowcase` (6 cameras + nameplate), `VFX` (6 emitter containers, all `CanQuery = false`), `Audio`
(empty by design), `Variants`.

It passes `ArenaValidator` with **1352 parts, 8 spawns, 11 loot, 6 cameras, 369 transformables, 260
groups, minimum crate clearance 9.9 studs against a declared 8, 0 errors, 0 warnings**. The layout, the
look, every number and the probes behind them: `docs/13-ARENA-DESIGN.md`. Rebuild it any time with
`BuildFoundry.build()` (from a **clone** of the module — `require` caches per session, see that doc);
the build validates itself and logs the result.

The place can be **one revision behind the source**, and that is worth knowing before trusting anything
measured here: `BuildFoundry.Revision` is stamped onto the arena as `GeneratorRevision`, and `Bootstrap`
rebuilds on a mismatch — but Rojo does not patch the place while Studio is in Play, so a Play started
before an edit runs the *old* hall against the *new* source. The stamp is what makes that visible
instead of silent.

**This arena is the worked example in three places**, and they are worth reading before hand-authoring
one: the layout table in `docs/13-ARENA-DESIGN.md`, the two rules a green validator does *not* check
(markers must not block rays; the underside must stay open) in `docs/01-ARENA-CONTRACT.md`, and the
conventions section of `AGENTS.md`.

It survives a stray sync because `Arenas` is marked `"$ignoreUnknownInstances": true` in
`default.project.json`. **Never remove that flag** — it is the only thing protecting hand-built
geometry from Rojo.

A versioned copy sits at `assets/arenas/Foundry.rbxm` (binary, 8.4 KB). It is a backup, **not a load
path**, and it is now **stale** — it predates this redesign, so treat it as history rather than as the
arena. Re-export it after significant geometry changes, and prefer `.rbxmx` so diffs are readable. See
`assets/arenas/README.md`. The leftovers from the stray sync (`ReplicatedStorage.Shared.Hello`,
`ServerScriptService.Server`, `StarterPlayerScripts.Client`) were deleted from the place on 2026-09-20.

---

## What is NOT built

* Phase 5 in full: saves, Clout currency, missions, weapon mastery, the shop. `Economy.Enabled` is
  `false`, so no code path can charge anyone.
* The Clerk (mascot) — model, animation, voice lines. Design is in `docs/05-BRAND.md`.
* Real audio ids — `AudioService` is a deliberate no-op shell.
* 1 arena and 23 modifiers, against a 40+ modifier target. `docs/08-MAP-AI-BRIEF.md` is the brief
  handed to map contributors.
* Mobile/console gamepad input paths have never been exercised.
* A bot *vision* model. Bots aim by a geometric raycast plus a range, so `Blackout` and `Fog` are
  approximated as a range penalty rather than a sight cone, and a bot has no memory of where a target
  went (D-038). Everything else about bots is real: they take damage, count as combatants for the
  round-end rule, and shoot through the same `resolveShot` a player trigger pull uses.

---

## Immediate next steps, in order

1. **Press Play.** As of D-037 Studio fills the lobby with bots on its own, so a Play is now a
seven-opponent round with no setup: watch the combat-dependent modifiers (`Vampire`, `Fragile`,
`Ricochet`, `InfiniteAmmo`, `MeleeOnly`, `PistolsOnly`, `ShotgunsOnly`) and read the gate and the
placement probe in the Output window. `DevConfig.BotCount = 0` still gives a solo round, and
`DevConfig.ForceModifiers` with `SkipVote` gives a chosen modifier without the ballot. See
`docs/11-BOTS.md`. Bots target the nearest living combatant, so bots kill bots — the earlier caveat
(seven shooters converging on one human, round over in seconds) no longer applies. Nothing beats a
real human for feel: use `Test → Players: 2` for the client-side paths bots cannot cover.

**The one thing to read first, because it is new:** the placement guard (D-034) moves props a few
studs to keep them out of each other. 17 props go through it, and every move is logged — if the hall
reads as *wrong* rather than *free of intersections*, that log says which props moved and the authored
coordinates are one table in `BuildFoundry`.
2. **Build the Clerk** — the mascot, per `docs/05-BRAND.md`. It is the face of the brand and the
   loudest thing missing from the pitch.
3. **Arenas 2 and 3**, against `docs/01-ARENA-CONTRACT.md`. One arena is a demo; three is a game. The
   brief for map contributors is `docs/08-MAP-AI-BRIEF.md`, and `ServerScriptService/MajorityRulesServer/Dev/BuildFoundry.lua` is the
   worked example to copy — it passes the validator and says why every number is what it is.
4. **Judge the redesigned arena with real players.** Two open questions, both measured and deliberately
   left to a playtest (`docs/13-ARENA-DESIGN.md`): the eight aligned fire lanes that survive cover, and
   whether 5 crates for 8 players is the right pressure. The tuning knob for the first is the cover ring's
   radius, not the piece size. Re-export `assets/arenas/Foundry.rbxmx` while you are in there.

   Two things to look at specifically, because an agent cannot judge either: whether the **palette reads at
   distance** (the colonnade is a colour key — one hue per modifier category — and if it reads as noise,
   that is one table in `BuildFoundry`), and whether the **balconies are a strong position or a trap** now
   that `LowGravity` makes their 6.5-stud deck jump-reachable.

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
