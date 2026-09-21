# MAJORITY RULES — read this before you touch anything

You are working on a Roblox experience where 8 players vote on one modifier, the arena
physically rebuilds itself, and then they fight. Rounds escalate from one gentle twist to
three stacked chaos modifiers.

**If you are an AI agent contributing here: this file is your contract.** Read it, then read
`docs/01-ARENA-CONTRACT.md` (map work) or `docs/02-MODIFIER-API.md` (systems work) before
writing code or geometry.

**Picking this up cold — a new thread, a new machine, or future-you?** Read
`docs/10-HANDOFF.md` first. It records what is built, what is installed on the dev machine, what
is half-done, and the next three steps. Do not re-derive state from the code if that file can
answer it; update that file when the state changes.

---

## The hard rules

These exist because three humans and several AI agents work in this repo at the same time.

1. **One writer per file.** Do not edit a file you do not own (see ownership map below). If you
   believe a file outside your area is broken, report it — do not fix it silently.
2. **Modifiers never touch `Workspace`.** A modifier receives a capability bag (`ctx`) and calls
   `ctx.Arena`, `ctx.Gameplay`, `ctx.Loot`, `ctx.Players`, `ctx.Rng`, `ctx.Log`. If you need a
   new capability, add it to `ArenaService` and document it in `docs/02-MODIFIER-API.md`.
3. **The map and the script communicate only through CollectionService tags and Attributes.**
   Never reference an arena part by name, and never by path. All tag and attribute names are
   declared once in `src/shared/Tags.lua`.
4. **No arena model contains a Script.** Arena models are geometry, tags and attributes only.
5. **Every arena passes `ArenaValidator` before merge.** No exceptions, human or AI.
6. **`main` must always be playable** — boot, vote, transform, complete a round.
7. **Nothing gameplay-relevant happens on the client.** Damage, votes, spawns, loadsouts, points
   and transformations are server-authoritative.
8. **Decisions go in `docs/DECISIONS.md`.** Reasoning must live in the repo, not in a chat log.

---

## File ownership

| Area | Paths | Owner |
| --- | --- | --- |
| Systems (code) | `src/server/**`, `src/client/**`, `src/shared/Config/**`, `src/shared/Net.lua`, `src/shared/Types.lua` | Systems track |
| Modifiers | `src/shared/Modifiers/**` | One file per modifier — any contributor, one modifier at a time |
| Contract | `src/shared/Tags.lua`, `src/tools/**` | Frozen — change requires a `DECISIONS.md` entry |
| Arenas (models) | `assets/arenas/**` | Map track, one arena per contributor |
| Arena kits | `assets/kits/**` | Map track, one kit per contributor |
| Brand assets | `assets/brand/**` | Brand track |
| Docs | `docs/**` | Anyone, but `01`/`02` are frozen contract docs |

---

## Adding a modifier (the most common task)

1. Copy `src/shared/Modifiers/_template.lua` into `Tier1/`, `Tier2/` or `Tier3/`.
2. Rename the file to the modifier `Id`. The registry auto-loads every `.lua` in `Tier*/`;
   files starting with `_` are ignored.
3. Fill in metadata: `Id`, `DisplayName`, `Blurb`, `Tier`, `Weight`, `Tags`, `Conflicts`,
   `Requires`, `Bans`, `Effects`.
4. Implement your effect using **only** capabilities that already exist. Prefer declarative
   `Steps` over `Tick`.
5. Run the boot validator (`Modifiers.validate()`) and `src/tools/ModifierSim.lua`.
6. Add the entry to `docs/03-MODIFIER-CATALOGUE.md`.

A modifier that cannot express itself with existing capabilities is a signal that the engine
needs a new capability — not that the modifier should reach into `Workspace`.

---

## Building an arena

1. Read `docs/01-ARENA-CONTRACT.md` in full.
2. Copy an existing arena as your starting point rather than starting empty.
3. Tag and attribute everything the contract requires. Nothing optional is optional.
4. Run `ArenaValidator` and get a clean report.
5. Save as `assets/arenas/<ArenaId>.rbxmx` and commit.

---

## Is the engine running the code you think it is?

Studio and the repository are two copies of the same scripts, and they drift silently: an edit made
in Studio without Ctrl+S never exists anywhere else, a file added under an unmapped `src/` directory
is never synced, and a script created in Studio has no file at all. Twice now that has cost an hour
of debugging a fix that was correct but never reached the engine. Do not guess — hash both sides:

1. Run `tests/studio_hashes.luau` in Studio (via the Studio MCP `execute_luau` tool, datamodel
   `Edit`).
2. Save the returned text to `.sync-audit/place.txt` (git-ignored, so it will not be committed).
3. `py tests/sync_audit.py --place-dump .sync-audit/place.txt`

It derives instance paths from `default.project.json`, hashes every script on both sides and names
the paths that differ — `DIFFERS`, `ONLY IN STUDIO`, `ONLY ON DISK`, `NOT MAPPED`. Exit code is 1
when they disagree, and a clean run ends with:

```
64 compared . 64 match . 0 differ . 0 only in Studio . 0 only on disk
place and repo match
```

If you change the hash on one side, change it on the other — the two implementations are in
`tests/studio_hashes.luau` and `tests/sync_audit.py`.

**A Play session snapshots the place, so it can start without your newest file.** Pressing Play while
the plugin is still patching gives you a server running the *previous* code, which looks exactly like
a change that did not work — and it happened twice on 2026-09-21, once costing a whole debugging pass
on a module that was never loaded. Before pressing Play, confirm the module exists in the **Edit**
datamodel; after pressing Play, confirm the running server agrees. Both are two lines of
`execute_luau`:

**Two analyzers are installed, and they disagree usefully.** `johnnymorganz.luau-lsp` resolves types
through `sourcemap.json`; `nightrains.robloxlsp` checks Roblox-specific things it does not. Both
binaries ship inside their VS Code extensions, so neither needs `aftman install` — run one directly to
get the checker's own answer instead of guessing (on this machine they live under
`.vscode/extensions/`, and RobloxLSP logs every diagnostic it publishes to `server/log/`).
RobloxLSP's `invalid-class-name` hint found a real bug that luau-lsp reports nothing about, so treat
that hint as credible and see `DECISIONS.md` D-020 before dismissing it.

**Instances the audit flags that are not yours to touch.** The place holds content with no file in
this repository, so the audit reports it as `ONLY IN STUDIO`. Seen so far: a transient
`sabuiltin_Assistant` LocalScript under `StarterGui`, which Studio's own Assistant tooling creates
while AI tools run code; and a `Gist` folder under `ServerScriptService` (`Main` LocalScript +
`MainMod` ModuleScript, AGPL header, author "Iuha Dust") alongside a `trdm` folder in `Workspace`.

A flag means **unmapped**, not *junk*. Studio is a shared, live place and another contributor may be
mid-build on exactly that thing; `Gist`/`trdm` are unexplained, so nobody has confirmed their
purpose yet. So: report them, do not delete or restructure them, and do not "fix" them to make a red
run go green. If the same path keeps appearing, ask a human who owns it before doing anything at all.
Record a path here only after it is explained, and never edit `ServerStorage.Arenas` geometry or
anything else a contributor may be working in.

**When a human says "publish" (or "pull my Studio changes"), that is this audit plus the write-back:**
run `tests/studio_dirty_check.luau` first (unsaved editor text is invisible to the audit, so skipping
it silently loses work), then the dump, then take every `DIFFERS` and `ONLY IN STUDIO` path, read
those scripts from Studio, write them to their mapped files, delete a file when its script was
deleted in Studio (`ONLY ON DISK`), show the diff, commit, push. Nobody has to name the scripts they
touched — the hash difference is the list. See `docs/07-TEAM-WORKFLOW.md` section 8.

Remember that this covers **script source only**. Geometry, attributes and tags produce no file, and
no Studio tool can export an instance to disk, so a hand-built arena still needs a human
`Save to File`. An arena built by code (`src/server/Dev/BuildFoundry.lua` is one) needs nothing — it
is a script, so it publishes like any other.

---

## Conventions

- Luau, typed where it helps. Tabs for indentation (StyLua default config).
- Server services are singletons in `src/server/Services/`, each exposing `Init()`/`Start()`.
- Clients render UI as a pure function of replicated round state. No client round logic.
- Naming: `PascalCase` files matching the module's table name; `MR` prefix on all tags.
- Never use `wait()`, `spawn()` or `delay()` — use `task.wait`, `task.spawn`, `task.delay`.
- Never test a class name with `typeof(x) == "ClassName"` — `typeof` returns the datatype, so that is
  always false. Use `typeof(x) == "Instance" and x:IsA("ClassName")`. See `DECISIONS.md` D-020.
- `--` is a comment; `--!` is magic-comment syntax reserved for `--!strict`, `--!nonstrict`,
  `--!nocheck`, `--!native`, `--!nolint`. Do not use `--!` to introduce prose — some analysers read it
  as a directive. Existing files still contain such comments, and the *first* line of each file is a
  real directive, so only new prose comments are affected.
- Never leave a `print` in shipped code — use `Util/Log.lua`.
- Before calling something a bug, correlate the observation with the round's **phase and active
  modifier** — the log timestamps both. Two false alarms in this repository came from inferring a
  fault from one observation: a weapon in hand during a `MeleeOnly` round is the round working, and an
  `ONLY IN STUDIO` audit line is another contributor's work in progress. Measure the mechanism
  (flip the input, read the replicated result) before writing a fix, and check whether the behaviour
  is reachable at all — the loadout above is unusable because firing requires `State == "Live"`.

---

## Testing a fight without a second human

`BotService` spawns CPU combatants when `ServerStorage.DevConfig` has `BotCount > 0` (Studio only —
`DevService` ignores every override outside Studio, so a live server cannot contain bots). They obey
the round's rules: the loadout decides their weapon, `GameplayService`'s baseline decides their speed
and health, their shots go through the same `resolveShot` a trigger pull does, and they count as
combatants for the round-end rule.

Use it before asking for a two-human test, because it is the only way to observe elimination, kill
credit and a contested round alone. `docs/11-BOTS.md` has the setup, the debug lines to read, what
the bots deliberately do *not* do, and what promoting it to a real feature would cost. Bots are a
test aid gated behind a dev flag — do not wire them into a live match path without a decision entry.

---

## Definition of done

A change is done when: it boots in Studio, `ArenaValidator` is green (map changes),
a round completes end-to-end, there are no server errors across a 3-round playtest,
analytics events fire, and the mobile performance floor holds.
