# Next-session handoff prompt

**Paste the block below as the first message of a fresh window.** It is written to survive a
total context reset: everything a new agent needs is either in this prompt or in the docs it
tells the agent to read first.

---

You are continuing work on **"The Vote"** — a Roblox arena shooter where 8 players vote on
ONE arena modifier per round and the arena physically transforms to match the vote: floor
changes, gravity shifts, weapon crates appear. Replayability comes from players building the
round themselves. I am the owner (non-expert coder, I work in Roblox Studio and read your
transcript); you are the agent.

- Repo: `github.com/HOL1OWW/Majority-Rules` (branch `main`)
- Local checkout: `C:\Users\selab\OneDrive\Documents\AI GAMES\The Vote`
- Studio place: **"The Vote"** (placeId `72737093276287`), synced by Rojo from the repo
- You reach the live place through the `Roblox_Studio` MCP bridge

## 1. Read these first, in this order (~2 minutes, do not skip)

1. `AGENTS.md` — the agent contract and working rules
2. `docs/15-AI-ACCESS.md` — exactly what you can see and do in Studio, the honest blind
   spots, and the **discovery ledger** (§7) you are required to append to
3. `docs/DECISIONS.md` — 61 decisions; `D-053` onward is the current era
4. `docs/16-MILESTONE-1-FEATURE-KITS.md` — the arena feature kits, the hand-restyle guide,
   and the ballot polish notes
5. `docs/17-ICON-ASSETS.md` — the icon pipeline and the upload procedure I still owe you

## 2. Where the project actually is (verified 2026-09-22)

- **Team Test works** for me and my brother (2 real players), and a full match loop runs
  solo: 3 rounds, 7 bots that genuinely fight each other, eliminations, match podium.
- **The Foundry arena** lives in `ServerStorage.Arenas` as a Model with 29 transform groups
  (25 floor tiles, 10 hidden cover walls, 1 lava volume) and all **23 of 23 modifiers are
  now ballot-eligible** (was 16 before the kits).
- **Leaderboard system** shipped: player-list stats, hold-Tab live board with kill feed,
  end-of-match podium, career DataStore (dormant in Studio until place API access exists).
- **Ballot**: each card shows effect icon chips (image assets once uploaded, per-token emoji
  fallback until then) plus hover tooltips with one plain-language line per effect.
- **Arena robustness**: boot self-heals a missing/tag-stripped/Folder-rooted arena
  (D-055/D-056), and revealed hidden cover correctly blocks bullets (D-057).
- **Checks that must pass before any commit**: `py tests/syntax_check.py` (73 files) and
  `py tests/effect_help_check.py` (keeps effect icons/tooltips in sync with the registry).
- Latest commit: `c8564ac`, working tree clean.

## 3. Your first tasks, in priority order

1. **Health check, then report.** Probe the live Studio state before touching anything:
   is Play running, are both Bootstraps enabled, is Foundry stamped, does the
   `ArenaProbe`/`ArenaValidator` report read clean? Give me a 5-line status and your
   recommendation, then **wait for my go-ahead**.
2. **Tooltip visual confirmation.** I hover a chip in a live round and tell you what I see —
   you cannot synthesize mouse input, so this one confirmation is inherently mine.
3. **Icon upload support.** When I say I have uploaded, take my asset-id list, run the
   harvester in `tools/harvest_icon_ids.lua`, fill `EffectIcons.ASSET`, and verify
   `EffectIcons.countAssets() == 24` in a live Play session.
4. **Milestone 1 hand restyle review.** I restyle tiles and cover walls per the guide in
   `docs/16`; you then check the result against the arena contract (tags, attributes, spawn
   clearance, sightlines) and re-run the validator.
5. **Ballot audit.** After a few matches, report which modifiers win most often and propose a
   rebalance — the pool only just unlocked from 16 to 23 options.
6. **Then: write `docs/19-ROADMAP.md`.** It does not exist yet (the roadmap only ever lived
   in chat, which is why it is gone). Reconstruct it from the shipped state and pick
   Milestone 2 with me. Candidate directions: fill-empty-servers bot scaling for launch,
   the cosmetic economy from `docs/06-MONETIZATION.md`, enabling place API access for
   persistent stats, a second hazard kit, and intermission/lobby flow.

## 4. House rules

- **Do not commit or push until I say publish.** Investigate, edit, verify — then propose.
  When I say publish, stage only the files in play and follow the existing commit style.
- **Record every architectural choice in `docs/DECISIONS.md`** (next free number: `D-062`).
- **Append every new capability, limit or technique you discover to the ledger in
  `docs/15-AI-ACCESS.md` §7 in the same session**, with the proof. Knowledge that stays in a
  chat log dies with the thread.
- Keep prose short — I watch the transcript live.
- Leave Studio as you found it: Play stopped, `workspace.CurrentCamera.CameraType` back to
  `Custom` if you flew it for a capture.
- My workflow: I edit in Studio **or** you edit files; either way we publish through git and
  verify against the live place afterwards. Tell me plainly when something is only
  structurally verified versus proven in a running game.

## 5. Known traps — each of these cost real time, do not rediscover them

- **Disabled Bootstraps (D-058).** If Play shows an empty baseplate and no `[MR]` lines
  appear, check `ServerScriptService.MajorityRulesServer.Bootstrap.Enabled` and
  `StarterPlayerScripts.MajorityRulesClient.Bootstrap.Enabled` FIRST. Both were found
  disabled once, and the game is completely silent about it.
- **Place-side changes need my Ctrl+S.** No tool on the bridge can save the place, and Team
  Test boots the last saved/published copy.
- **Rojo staleness.** A Play session started around a file sync can run pre-edit code. Verify
  the place's actual source (read `.Source` via `execute_luau` in Edit mode), then stop and
  restart Play.
- **Console capture can serve stale output.** The ground truth is the Studio log file:
  `%LOCALAPPDATA%\Roblox\logs\*Studio*_last.log`, grep for `[MR]`.
- **You cannot synthesize input** (`VirtualInputManager` is capability-locked) and cannot see
  live video; viewport capture is roughly one frame per 12 seconds and does not show GUI.
- **Client `require()` in a probe returns a sandbox copy** — calling its functions silently
  does nothing. Verify through instances and the real event pipeline.
- **Arena roots lose stamps** when models move between Workspace and ServerStorage (D-056
  self-heals at boot; re-check after any large move).
- **Studio can wedge.** If Play latches or APIs contradict each other, stop and start Play
  twice, then retry before assuming a code bug.

## 6. What only I can do

Press Ctrl+S; upload images/videos to Roblox; hover, click and move in a live session; enable
place API access; publish the experience to the public. Ask me directly when a task needs one
of these.

## 7. Start with this

Run both checkers, read the docs in §1, probe the live Studio state, and report the 5-line
status described in §3.1. Do not change anything until I answer.
