# Setup — from a bare Windows machine to a running match

Follow this in order. Every step has a way to check it worked before you move on; if a check
fails, jump to **Troubleshooting** at the bottom rather than pushing forward.

Total time: about 15 minutes, mostly downloads.

---

## Where things actually stand on this machine (2026-09-20)

Read this before the steps. It exists because the DevForum guide and this repository do not agree,
and following the guide end to end left **three** copies of the project on disk. Only one of them
holds the game:

| Folder | What it is | Verdict |
| --- | --- | --- |
| `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote` | the real repo: 64 Luau modules, 23 modifiers, 10 documents, `default.project.json`. No commits yet. | **This is the project.** Rojo must serve from here. |
| `C:\Users\selab\Majority-Rules` | a `git clone` of `github.com/HOL1OWW/Majority-Rules` holding an untouched `rojo init` skeleton — `src/shared/Hello.luau`, `GameFiles`, and a `default.project.json` that still says `MY_GAMES_NAME_HERE_THIS_CAN_BE_ANYTHING`. | serves nothing. Delete once the real repo is on GitHub. |
| `C:\Users\selab\OneDrive\Documents\GitHub\Majority Rules` | a second checkout of the same GitHub repo: LICENSE, README, `main.luau`, `.idea`. No game code. | redundant. Delete. |

Already installed and verified on this machine:

* **Aftman 0.3.0** with **Rojo 7.7.0** pre-downloaded in `%USERPROFILE%\.aftman\tool-storage`, so
  `rojo` runs offline today. Rokit is **not** installed; `aftman.toml` is the manifest.
* **The Rojo Studio plugin** — `%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm`.
* **VS Code** with `evaera.vscode-rojo`, `kampfkarren.selene-vscode`, `nightrains.robloxlsp`.
* **Git and GitHub Desktop**, identity `HOL1OWW` — plus a GitHub repo `HOL1OWW/Majority-Rules`
  which, as of this writing, contains none of the game.

The one thing that is **not** done: no file in this repo has ever reached the Studio place. The
sync server has to be started **from this folder** (Step 5). Starting it from either of the other
two folders syncs an empty skeleton into the place — which is exactly what "I followed the guide and
nothing happened" looks like from the outside.

---

## Step 0 — Move the project out of OneDrive (do this first)

The project currently lives at `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote`.

OneDrive is actively hostile to this workflow:

* **Files On-Demand** can "dehydrate" files into placeholders. Rojo and Luau LSP then read
  truncated or missing content, which fails in confusing ways.
* Rojo writes constantly while you work, so every keystroke queues a sync upload.
* `build/*.rbxl` files are tens of megabytes and will be re-uploaded on every build.

Move it (close Studio and VS Code first, then run in Git Bash):

```bash
mkdir -p /c/dev
mv "/c/Users/selab/OneDrive/Documents/AI GAMES/The Vote" /c/dev/majority-rules
cd /c/dev/majority-rules
```

Then **reopen this project from the new path** — `C:\dev\majority-rules`. Git history and every
file travel with the folder.

**Check:** `git status` runs, and `git log` shows the repo (even with no commits yet).

If you genuinely cannot move it: right-click the folder → *Free up space* must be **off**, and
OneDrive sync should be paused while you work. It will still be a worse experience.

---

## Step 1 — Visual Studio Code

Install from <https://code.visualstudio.com>. On the install screen, leave **"Add to PATH"**
ticked — that is what puts the `code` command on your system.

**Check:** open a *new* Git Bash window and run `code --version`. It should print a version
number.

Then install the four extensions. Either open the Extensions panel (`Ctrl+Shift+X`) and install
these by name, or run this from the project folder:

```bash
code --install-extension evaera.vscode-rojo
code --install-extension JohnnyMorganz.luau-lsp
code --install-extension JohnnyMorganz.stylua
code --install-extension Kampfkarren.selene-vscode
```

Opening the folder also prompts you to install them, because `.vscode/extensions.json` lists
them as recommendations.

**Check:** VS Code's Extensions panel shows all four enabled.

---

## Step 2 — Aftman (the toolchain manager)

Aftman is the toolchain manager this machine already has, and it is what resolves `rojo` here. It
reads `aftman.toml`. If you ever see a `rokit.toml` in the repo, delete it: two manifests means two
answers to "which Rojo am I actually running", and the wrong one wins silently.

Aftman lives in `%USERPROFILE%\.aftman\bin` and is already on your PATH. Should you ever need to
reinstate it:

```powershell
winget install --id LPGhatguy.aftman
```

**Check:** open a **new** terminal and run `aftman --version` — it prints `aftman 0.3.0`.

> A "new terminal" matters: Windows only picks up PATH changes in processes started afterwards. If
> `aftman` is "not recognized", close every terminal and VS Code, open a fresh one.

---

## Step 3 — Install the toolchain into the project

From the **project folder** — the one containing `default.project.json`:

```bash
cd "/c/Users/selab/OneDrive/Documents/AI GAMES/The Vote"   # or wherever you move it to
aftman install
```

This reads `aftman.toml` and links the pinned Rojo into `%USERPROFILE%\.aftman\bin`.

**Check:** `rojo --version` prints `rojo 7.7.0`.

Run it from *inside* the project. Aftman's shim resolves versions from the nearest `aftman.toml`, so
run from anywhere else it fails with "no aftman.toml files list this tool". That error is not a
broken install — it is the shim saying it has no version to resolve for the current folder.

StyLua, Selene and Luau LSP are commented out at the bottom of `aftman.toml`. Add them with
`aftman add <tool>` then `aftman install` when you want formatting, linting and type checking.

---

## Step 4 — Install the Rojo plugin into Roblox Studio

```bash
rojo plugin install
```

**Check:** open Roblox Studio → the **Plugins** tab → you should see **Rojo** in the toolbar. If
it is not there, restart Studio.

The plugin and the CLI are versioned separately: a v7 CLI needs the v7 plugin.
`rojo plugin install` always installs the matching one, which is why you should use it rather
than the Roblox.com plugin page.

---

## Step 5 — Connect and press Play

1. In the project folder, start the sync server:

   ```bash
   rojo serve
   ```

   It prints something like `Rojo server listening on 127.0.0.1:34872`. **Leave this terminal
   running.**

2. In Studio, open the place (`The Vote`, placeId `72737093276287`), go to the **Plugins** tab →
   **Rojo** → click **Connect**.

3. You should see the sync succeed and files appear in the Explorer: `ReplicatedStorage.Shared`,
   `ServerScriptService.MajorityRulesServer`, `StarterPlayer.StarterPlayerScripts.MajorityRulesClient`,
   `ServerStorage.Tools`.

4. **Press Play.** Watch the Output window (`View → Output`).

**Check:** the Output window shows lines starting with `[MR]` — the bootstrap banner,
`Modifier registry OK: 23 modifiers loaded`, `Arena loaded: Foundry`, and the
`ArenaValidator` / `ModifierSim` reports. Then: a vote panel appears at the bottom of the screen
with cards, you cast a vote, the winner is stamped, the arena transforms, and the round starts.

### What to expect the first time

**Expect errors.** About 8,800 lines of Luau were written before Rojo was available, so the code
has been structurally checked but never executed. The first Play will probably surface a handful
of real bugs — a wrong property, a nil index, a bad require path. That is a normal first
playtest, not a failure. The rule that makes it fast to fix: **every log line in the game goes
through `src/shared/Util/Log.lua`**, so anything in the Output window is worth reading.

When you hit one, tell me the exact red text and I'll fix it.

---

## Step 6 — The development loop, from now on

```bash
# terminal 1: leave running while you work
rojo serve
```

Then: edit any `.lua` file in this repo → save → the Studio place updates instantly → press Play.

To produce a place file you can upload:

```bash
rojo build -o build/MajorityRules.rbxl
```

To give Luau LSP full type information about the Roblox API (do this once, and again after
adding services or instances):

```bash
rojo sourcemap default.project.json -o sourcemap.json
```

`sourcemap.json` is git-ignored — it is generated, not authored.

---

## Step 7 — Test fast with dev overrides

Waiting through a six-round match to reach a three-stack chaos round is slow. In Studio:

1. Right-click `ServerStorage` → **Insert Object** → **Folder**, name it `DevConfig`.
2. Add attributes by clicking **Add Attribute** in the Properties panel:

| Attribute | Type | Example | Effect |
| --- | --- | --- | --- |
| `ForceModifiers` | string | `Fog,IceFloor,RisingLava` | Applies these and skips the vote |
| `SkipVote` | bool | `true` | Skips the vote entirely |
| `StartingRound` | number | `5` | Start at round 5 (three-stack rounds) |
| `RoundSeconds` | number | `25` | Shorter rounds |
| `VoteSeconds` | number | `6` | Shorter vote |
| `TotalRounds` | number | `2` | Shorten the whole match |
| `ArenaId` | string | `Foundry` | Force a specific arena |

These only work in Studio. A published server ignores them completely.

**The single best smoke test:**

```
ForceModifiers = "SmallMap,IceFloor,CoverCrates"
SkipVote       = true
RoundSeconds   = 30
```

Three simultaneous transforms with a vote skipped: if that round plays without the floor
desyncing or a player falling through the world, the transform pipeline is working.

---

## Following the DevForum "Setup Rojo Fast" guide?

That tutorial (<https://devforum.roblox.com/t/838182>) is a good walkthrough for a *fresh* project,
but it was written in 2020 and this repository already exists. Four of its steps will fight what
is here. Deviate as follows, in the order they will bite you.

1. **Do NOT run `rojo init`.** It creates a new `default.project.json`, and ours already maps the
   whole tree (`ReplicatedStorage.Shared`, `ServerScriptService.MajorityRulesServer`,
   `StarterPlayerScripts.MajorityRulesClient`, `ServerStorage.Arenas` and `.Tools`). If `rojo init`
   overwrites or errors here, you have found the reason. Skip the step.

2. **The Aftman step is the one step of that tutorial we keep.** Aftman is installed here and
   `aftman.toml` is our manifest. The tutorial predates Rokit, so its Foreman alternative is simply
   unnecessary. One caveat: run `aftman init` (and later `aftman add`) **inside the project
   folder** — run it elsewhere and Aftman writes a manifest in the wrong directory, so the version
   it pins never resolves inside the repo.

3. **In GitHub Desktop, use `File → Add Local Repository`** — *not* "Create a new repository". The
   repo already exists: `git init` was run, the branch is `main`, and there is a `.gitignore` and
   everything else in place. "Creating" a repository over an existing one is how you end up with a
   nested repo or a confused GitHub Desktop. Add the existing folder, and GitHub Desktop will
   show the ~70 untracked files ready for the first commit.

4. **The Rojo VS Code extension can manage the Studio plugin for you** (the tutorial's
   "MANAGE IT FOR ME" button, and it can start and stop the sync server too). That is a legitimate
   replacement for `rojo plugin install`; either is fine. But be aware of one thing the tutorial
   does not mention: **the extension does not put `rojo` on your PATH.** Two things in this repo
   need the CLI — `rojo build` (producing a `.rbxl`) and `luau-lsp.sourcemap.autogenerate` in
   `.vscode/settings.json` (which is what gives you hover docs for every Roblox API). So install
   Rokit anyway. If you deliberately do not want the CLI, set
   `"luau-lsp.sourcemap.autogenerate": false` in `.vscode/settings.json` and accept worse
autocomplete.

5. **"Always open VS Code through GitHub Desktop"** is good advice, with one addition: the folder
   VS Code opens must be the **repo root** (the folder containing `default.project.json`). Rojo,
   Luau LSP and StyLua all resolve paths relative to it.

6. **Point Rojo at this repo, not at the folder the tutorial had you `rojo init`.** If you already
   created a skeleton elsewhere (see the status table at the top), it is harmless — just never run
   `rojo serve` from it, because that is the copy that will sync an empty game into your place.

Everything else in the tutorial — the reasoning about version control, reviewing diffs, branches,
not losing work to a Studio crash — applies exactly as written, and is why we are doing this.

---

## Troubleshooting

**`rojo` is not recognized, or says "no aftman.toml files list this tool".** Two separate causes.
PATH is only read at process start, so a terminal opened before the install will not see it — close
all terminals and VS Code, open a fresh one. The other cause is location: Aftman's shim resolves
versions from the nearest `aftman.toml`, so `cd` into the repo root before running `rojo`.

**Rojo says "Could not find project file".** You ran `rojo serve` from the wrong folder. It must
be the folder containing `default.project.json`.

**The plugin says it cannot connect.** The `rojo serve` terminal must still be running and on the
same machine. Restart the server, then reconnect.

**Plugin/CLI version mismatch.** Re-run `rojo plugin install` after any Rojo update.

**Rojo deleted something in Studio.** Rojo owns the parts of the DataModel that the project file
declares. Hand-built instances must live under a node marked `"$ignoreUnknownInstances": true`
— `ServerStorage.Arenas` is already marked that way, precisely so arenas you build by hand
survive a sync. Everything you author should end up in this repo anyway; that is the point.

**Nothing appears in Studio after Connect.** Check the Rojo panel's output in Studio. Usually the
project file has a syntax error — JSON does not allow trailing commas.

**"I connected Rojo and the game isn't there."** You are almost certainly serving a different
folder. You can ask the running server what it is serving, from any terminal, with Studio open or
closed:

```bash
curl -s http://127.0.0.1:34872/api/rojo | tr -c '[:print:]' '\n' | grep -i projectname
```

`projectName` names the project that owns the connection. Only one process can listen on port
34872, so a stale `rojo serve` started in the wrong folder blocks the correct one until you press
`Ctrl+C` in its terminal. This is the single most likely cause of "I followed the setup and nothing
happened" — the sync works perfectly, it is just feeding Studio an empty skeleton.

**Rojo is connected, but your edits stop reaching Studio.** Seen after a Play/Edit cycle: the plugin
holds a socket open to the server while no longer applying patches, so Studio quietly runs stale
code while the repository looks updated. This is the most misleading failure mode in the whole
setup — a fix that "does not work" when it was never delivered. Restart the server (`Ctrl+C`, then
`rojo serve`): the plugin reconnects on its own and does a full reconcile. When a change appears to
do nothing, read the script back from Studio before doubting the change:

```lua
-- via the Studio MCP tools, or just open the script in Explorer
script_read(target_file = "ReplicatedStorage.Shared.Net", start_line_one_indexed = 64, end_line_one_indexed_inclusive = 70)
```

**Scripts appear but nothing happens on Play.** Look for a red line in the Output window. Every
service logs through `Log`, so silence means the bootstrap itself did not run — check that
`ServerScriptService.MajorityRulesServer.Bootstrap` exists and is a `Script` (not a
`ModuleScript`) with its `Enabled` property true.

**The vote panel never appears.** The client bootstrap is a `LocalScript`; confirm
`StarterPlayer.StarterPlayerScripts.MajorityRulesClient.Bootstrap` exists. Also check that the
server logged a `VoteOpen` round state.

**Everything is stuttering on mobile / with 8 players.** Check the `MovingArena` modifier first —
it is the only one that touches every part of the arena every frame, by design and by
documented trade-off.

---

## Once it runs

1. Play a full six-round match through to the standings screen.
2. Save the gray-box arena as `assets/arenas/Foundry.rbxmx` (right-click the `Foundry` model in
   `ServerStorage.Arenas` → **Save to File**) and commit it, so the arena is version controlled
   rather than living only in the place file.
3. Make the first commit:

   ```bash
   git add .
   git commit -m "Initial scaffold, modifier engine, vote loop and gray-box Foundry arena"
   ```

4. Then read `docs/07-TEAM-WORKFLOW.md` — that is the daily loop, ownership map and cadence.
