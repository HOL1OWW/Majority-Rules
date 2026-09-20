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
| 1 — vertical slice: lobby → vote → transform → round → results | **done** — booted, voted, transformed and scored across clean 3-round matches on 2026-09-20 |
| 2 — engine v2: stacking, tiers, seeds, variants, emitters | **done** |
| 3 — combat depth: weapon registry, crates, hazards, attribution | **code complete, never fired** (no playtest has had two players) |
| 4 — presentation: cinematic camera, vote UI, verdict stamp | **partial** (audio ids and Clerk model outstanding) |
| 5 — meta: saves, Clout, missions, mastery, shop, analytics | **not started** (analytics hooks exist) |
| 6 — monetisation + compliance | **not started** (`Economy.Enabled = false`, service inert by design) |

**Never exercised at all:** combat — hitscan, damage, elimination, points and every modifier that
depends on them — plus 8-player rounds, and the mobile and console input paths.

---

## 8. Working without VS Code (scripting from Studio)

You never need VS Code for **map work**, and this is the part people get wrong. Arena geometry is not
Rojo-managed: `ServerStorage.Arenas` is marked `$ignoreUnknownInstances`, so building and editing
arenas in Studio is the intended workflow and no sync overwrites it. Re-export
`assets/arenas/<arena>.rbxm` after significant geometry changes, per `assets/arenas/README.md`.

**Scripts** are owned by whatever is syncing them, so pick exactly one of these. Do not run two of
them at once — two systems owning the same Script instances is precisely the drift this repository
exists to prevent.

1. **Rojo's own two-way sync — tested on 2026-09-20, and NOT recommended for this project.** It
   does work, but it fights the repository. Leave it **off** unless you specifically go looking for
   this experiment again.

   What was proven, in order:
   - **A Studio edit only counts if you save it.** The plugin watches `instance.Changed` on the
     instances Rojo owns (`ServeSession.lua` → `InstanceMap` → `instance.Changed`), so text sitting
     in the script editor buffer is invisible to it. **Ctrl+S is what makes an edit real** — no save,
     no sync, no warning. This is the single most likely reason a Studio edit "didn't reach the
     file": it was never written into the DataModel at all.
   - **The write path itself works.** Appending a comment to `Util/Log.lua`'s `Source` grew the file
     on disk from 1264 to 1307 bytes within about a second, and the Output window logged
     `[Rojo-Info] Write response:` for each POST to `/api/write`.
   - **It then went into a feed-back loop.** Reverting the same change in Studio did not stick: the
     server's copy was re-applied to Studio, Studio re-sent it, and the file was rewritten every few
     seconds (mtime advancing 22:39:10 → 22:39:22 → 22:39:35 → 22:39:48 with unchanged content) while
     dozens of `Write response` lines piled up. The change had to be recovered with
     `git checkout -- <file>` and both sides let converge. This is what the `UNSTABLE` badge is
     actually warning about, and it is why this repo treats **the file on disk as the only writer**.

   Settings-panel details you will otherwise trip over:
   - The `UNSTABLE` tag is a severity badge, not a permission gate — the same tag sits on *Open
     Scripts Externally* and *Auto Connect Playtest Server*.
   - The toggle is **greyed out while Rojo is connected**, because the plugin sets
     `locked = syncActive`; its tooltip says *"Cannot change while currently syncing. Disconnect
     first."* So: **Ctrl+S → Disconnect → set the toggle → Connect.** To turn it back off, the same
     three steps in reverse.
   - The setting lives in **plugin settings**, per machine, not in `default.project.json` — your
     brother has to set it (or not) himself.

   If you do run it, the check that settles arguments is to hash both sides: run a Luau loop over the
   four mapped services summing `djb2` of every `Script.Source`, and compare with the same `djb2`
   computed over `src/**/*.lua` in bash. Identical totals mean the place and the repo really agree,
   which is how the "my edit vanished" question was answered here.
2. **Studio's native Script Sync** — Roblox's own feature, now in full release, two-way and resumed
   automatically when the place reopens. Right-click a Folder of scripts → *Sync with Directory…*.
   It expects its own file conventions (`.luau` suffixes, `init.luau` for folders), which are close
   to but not identical with this repo's Rojo layout (`.lua`, `.server.lua`, `.client.lua`). Choosing
   it means converting the tree and dropping Rojo for scripts.
3. **Rojo one-way, and have the agent pull your edit back.** Edit in Studio, then ask for the change
   to be brought into the repo: the agent reads the script from Studio and writes the file, so the
   repository stays the source of truth and the change stays reviewable. No experimental features.
   Slowest, least risk.

There is also a one-shot `rojo syncback` for pulling an existing place *into* the project layout,
which is the reverse direction of everything above.

### Publishing Studio-first work — no file names, nothing installed on the author's machine

This is the default workflow for anyone who would rather work only in Studio, which is how a second
contributor participates without installing Rojo, VS Code or GitHub Desktop at all.

**Nothing has to be named.** `tests/sync_audit.py` compares the place with the repository by hash, so
the difference *is* the list of edits: every path reported as `DIFFERS` or `ONLY IN STUDIO` is a
change somebody made in Studio, and every `ONLY ON DISK` is a file that never reached the place. The
agent pulls exactly those, so the author never has to write down what they touched.

**One thing `ONLY IN STUDIO` does not mean: junk.** It means *no file in this repository claims this
instance* — which is equally the signature of a half-finished idea from another contributor, since
the place is shared and live. Report such a path, ask who owns it, and leave it alone. Do not delete
it, do not delete it to get a green run, and do not assume an AGPL header or an unfamiliar author
makes it disposable. Current known examples and the handling rule are in `AGENTS.md`.

The loop:

1. Author edits in Studio and presses **Ctrl+S**.
2. Anyone says **"publish"**.
3. The agent:
   1. runs `tests/studio_dirty_check.luau`, which compares the *editor* text of every open script with
      the DataModel — an unsaved buffer is invisible to every other check, so this is what stops a
      publish from quietly leaving work behind;
   2. hashes the place against the repository, so the difference *is* the list of edits;
   3. reads exactly the differing scripts and writes the matching files, and deletes a file when the
      corresponding script was deleted in Studio (that shows up as `ONLY ON DISK`);
   4. shows the diff, commits, and pushes.

"Publish" here means **GitHub**. Publishing the experience to Roblox for players is a different act,
done from Studio (`File → Publish to Roblox`), and only a human can do it.

Two facts make this work for a contributor with no git tooling:

- **Team Create.** Editing the same place means every collaborator's saved edits land in the same
  DataModel, and that is the DataModel the agent reads. Nothing needs installing or configuring on
  their machine. If they are instead working in a *separate copy* of the place, the agent cannot see
  their work at all — they either join the team place, or publish their copy for someone to open here.
- **The agent can push.** The credential manager on the dev machine authenticates `git push`
  (verified 2026-09-20: `git push --dry-run` authenticated and reported everything up to date), so
  "commit and push" is one act on this side. Nothing is published by accident, though — it happens
  when it is asked for.

Caveats to state out loud, because each one looks like "the sync is broken":

- **Ctrl+S.** Unsaved script text is not in the DataModel and cannot be read by anything.
- **Drafting mode.** A teammate in a Team Create *draft* has not changed the shared DataModel yet;
  their work appears when they publish the draft.
- **Geometry is not covered.** The audit compares *scripts*. Parts, positions, attributes and tags are
  not script source, so moving a wall or adding cover produces no file at all. Arena changes still need
  `Save to File` → `assets/arenas/<Arena>.rbxmx`, which is a click a human must make, or the arena has
  to become Rojo-owned — see `assets/arenas/README.md` for that trade-off.
- **The trigger is a message, not a daemon.** An agent only acts when it is told to; it cannot watch
  Studio by itself.

What you give up by staying in Studio: `luau-lsp` type checking, `stylua` formatting, `selene`
lints, and reviewable diffs in an editor. That costs little for a tweak and a lot for a refactor
across many files — so it is a per-task choice, not a permanent one.
| 7 — content scale to 40+ modifiers, 8+ arenas | **23 modifiers, 1 arena** |

Next three jobs, in order: **connect Rojo and playtest a full match**, **build the Clerk**, **add
arenas 2 and 3**.
