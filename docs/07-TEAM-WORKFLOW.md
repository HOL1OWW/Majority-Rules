# Workflow, setup and cadence

Three humans and several AIs work on this repository at the same time. This document is how that
does not turn into a pile of broken files.

---

## 1. One-time setup (about 15 minutes)

You need: **Git**, **VS Code**, **Aftman**, and the **Rojo Studio plugin**. See
`docs/09-SETUP.md` for the state of this specific machine — the toolchain is already installed
there, and the project folder is still inside OneDrive.

> **Do this outside OneDrive.** The project currently sits in
> `OneDrive/Documents/AI GAMES/The Vote`. OneDrive plus Rojo's file watcher plus hundreds of
> small Luau files produces file locks, sync churn and unusable diffs. Move the folder to
> `C:\dev\majority-rules` (or exclude it from OneDrive sync) before you start. Everything —
> including git history — moves with the folder.

### Steps

1. **Install Git** — <https://git-scm.com/downloads>. Verify: `git --version`.

2. **Install VS Code** — <https://code.visualstudio.com>. Then install these extensions:
   * `Rojo` (rojo-rbx) — connects Studio to these files
   * `Luau LSP` (JohnnyMorganz) — real type checking and go-to-definition
   * `StyLua` (JohnnyMorganz) — formatting on save

3. **Install Aftman** (the toolchain manager) — `winget install --id LPGhatguy.aftman`, or see
   <https://github.com/LPGhatguy/aftman>. It reads `aftman.toml` and installs the pinned toolchain.
   Do not add a Rokit manifest alongside it: two manifests pinning two Rojo versions is the same
   class of bug as two arena definitions, and whichever resolves wins silently.

4. **Install the toolchain.** From the project folder:

   ```bash
   aftman install
   ```

   `rojo` then resolves only from inside this folder (or a subfolder of it) — Aftman's shim looks
   for the nearest `aftman.toml`. If a pinned version fails to resolve, run `aftman add
   rojo-rbx/rojo` to fetch the latest and commit the updated `aftman.toml`.

   StyLua, Selene and Luau LSP are commented out in `aftman.toml`; uncomment and `aftman install`
   when we want formatting, linting and type checking in the loop.

5. **Install the Studio plugin:**

   ```bash
   rojo plugin install
   ```

6. **Check the repo is in a good state:**

   ```bash
   git status
   ```

### Daily loop

```bash
# terminal 1 — watches these files and pushes them into Studio
rojo serve
```

In Studio: open the **Rojo** panel → **Connect**. From then on, saving a `.lua` file here updates
the place instantly, and you press Play in Studio to test.

To produce a shippable file:

```bash
rojo build -o build/MajorityRules.rbxl
```

### Arenas and Rojo

`ServerStorage.Arenas` is declared in `default.project.json` with
`"$ignoreUnknownInstances": true`, which means **Rojo will not delete arena models that were
hand-built in Studio**. That matters: the gray-box Foundry arena already lives in the place.

For permanence, save an arena as `assets/arenas/<ArenaId>.rbxmx` and commit it. Hand-placed
models are convenient to iterate on but they are not version controlled, and a model nobody can
revert is a model nobody can safely improve.

### Without Rojo

You can work entirely in Studio, but understand what you lose: no diffs, no review, no rollback,
and no way for several authors to work at once. If Rojo genuinely will not work for someone,
they work on **arena models only** (`assets/arenas/*.rbxmx`) and never on `src/`.

---

## 2. Ownership — one writer per file

| Area | Paths | Owner |
| --- | --- | --- |
| Systems | `src/server/**`, `src/client/**`, `src/shared/Config/**`, `src/shared/Net.lua`, `src/shared/Types.lua` | Systems track |
| Modifiers | `src/shared/Modifiers/TierN/*.lua` | Any contributor — **one file at a time, one author per file** |
| Contract | `src/shared/Tags.lua`, `src/tools/**` | Frozen — changes need a `DECISIONS.md` entry |
| Arenas | `assets/arenas/*.rbxmx` | Map track — one arena per author |
| Kits | `assets/kits/**` | Map track — one kit per author |
| Brand assets | `assets/brand/**` | Brand track |
| Docs | `docs/**` | Anyone, except `01` and `02` which are frozen contracts |

The rule that prevents 90% of collisions: **if you did not create the file, do not edit it.** If
something outside your area is broken, report it — do not fix it silently. A mystery fix from an
unknown author is worse than a known bug.

---

## 3. Cadence

**Daily (15 minutes, everyone):** three questions only.
1. What new tags or attributes do we need? (Only the contract owner can add them.)
2. What modifiers or arena features are stuck?
3. What is blocked, and on whom?

**Per change:** branch `feat/<thing>` or `map/<arena>`, one review, squash merge. `main` must
always boot, vote, transform and complete a round. If your branch breaks that, it does not merge.

**Weekly:** ship something a player can see. Roblox counts updates as an input to discovery
impressions, so this is a growth activity, not just a morale activity.

---

## 4. Definition of done

A change is done when:

* [ ] it boots in Studio, with no red lines in the output
* [ ] `ArenaValidator` reports PASS (map changes)
* [ ] `ModifierSim` reports no unplayable combinations (modifier changes)
* [ ] a full round completes end to end on the transformed arena
* [ ] a three-round playtest produces no server errors
* [ ] analytics events fire for the new behaviour
* [ ] the mobile performance floor holds
* [ ] the relevant doc is updated in the same change

---

## 5. Working with AI contributors

Several agents write code and geometry here. Three things make that work:

1. **`AGENTS.md` at the repo root is the briefing.** Every agent reads it first. If you are
   briefing an agent manually, paste it, then paste the specific contract doc for the task —
   AI-authored arenas should start from `docs/08-MAP-AI-BRIEF.md`.
2. **The contract is the interface, not the conversation.** An agent that cannot express its idea
   with the existing tags and capabilities must report that rather than inventing a private
   convention that nothing else understands.
3. **Reasoning goes in `DECISIONS.md`, not in a chat log.** Chat history is not part of the
   repository, so an agent that hands a task to another agent loses everything not written down.
   If a decision mattered, it goes in the file.

Practical guardrails when several agents work at once:

* One file, one agent. Never let two agents touch the same file in the same session.
* Give each map agent a **distinct arena or kit**, and require the validator before merge.
* Agents are good at breadth (twenty modifiers, one arena's geometry) and bad at cross-cutting
  refactors of frozen files. Keep the contract work with humans.
* Ask for the diff, not the summary. A confident summary of broken code is the normal failure
  mode.

---

## 6. Verification without Studio

`tests/syntax_check.awk` is a crude Luau structure checker — it strips comments and strings, then
verifies block and bracket balance. It is not a parser, and it exists only because the real
toolchain had not been installed yet.

```bash
for f in $(find src -name '*.lua'); do awk -f tests/syntax_check.awk "$f"; done
```

Once StyLua, Selene and Luau LSP are added to `aftman.toml`, the real checks are `luau-lsp analyze`
(types), `stylua --check` (formatting) and `selene` (lints). Prefer them; delete the awk script when
they are in place.

---

## 7. Status of the build

| Phase | State |
| --- | --- |
| 0 — scaffold, contract, validator, gray-box Foundry arena | **done** |
| 1 — vertical slice: lobby → vote → transform → round → results | **code complete, awaiting a Rojo-synced playtest** |
| 2 — engine v2: stacking, tiers, seeds, variants, emitters | **done** |
| 3 — combat depth: weapon registry, crates, hazards, attribution | **done** |
| 4 — presentation: cinematic camera, vote UI, verdict stamp | **partial** (audio ids and Clerk model outstanding) |
| 5 — meta: saves, Clout, missions, mastery, shop, analytics | **not started** (analytics hooks exist) |
| 6 — monetisation + compliance | **not started** (`Economy.Enabled = false`, service inert by design) |
| 7 — content scale to 40+ modifiers, 8+ arenas | **23 modifiers, 1 arena** |

Next three jobs, in order: **connect Rojo and playtest a full match**, **build the Clerk**, **add
arenas 2 and 3**.
