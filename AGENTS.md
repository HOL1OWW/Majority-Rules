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

## Conventions

- Luau, typed where it helps. Tabs for indentation (StyLua default config).
- Server services are singletons in `src/server/Services/`, each exposing `Init()`/`Start()`.
- Clients render UI as a pure function of replicated round state. No client round logic.
- Naming: `PascalCase` files matching the module's table name; `MR` prefix on all tags.
- Never use `wait()`, `spawn()` or `delay()` — use `task.wait`, `task.spawn`, `task.delay`.
- Never leave a `print` in shipped code — use `Util/Log.lua`.

---

## Definition of done

A change is done when: it boots in Studio, `ArenaValidator` is green (map changes),
a round completes end-to-end, there are no server errors across a 3-round playtest,
analytics events fire, and the mobile performance floor holds.
