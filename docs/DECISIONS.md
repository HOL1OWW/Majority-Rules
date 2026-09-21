# Decisions

Architecture decision record. **Reasoning lives here, not in a chat log** — an agent that hands a
task to another agent loses everything that was not written down, and "why is it like this" is the
most expensive question in a codebase with several authors.

Format: what we decided, why, and what it costs. Newest at the bottom.

---

### D-001 — Tags and attributes are the only crossing surface

**Status:** frozen · **Date:** phase 0

The map and the systems never reference each other's internals. All cross-team data is a
CollectionService tag or an Attribute whose name is declared once in `src/shared/Tags.lua`. Arena
models contain no scripts.

**Why:** three humans and several map-building AIs contribute in parallel. Any direct reference is
a coupling that breaks when someone else renames a part or rewrites a system.

**Cost:** a small indirection tax on every feature, and a validator to enforce it. Worth it.

---

### D-002 — Modifiers never touch Workspace

**Status:** frozen · **Date:** phase 0

A modifier receives a capability bag (`ctx.Arena`, `ctx.Gameplay`, `ctx.Loot`, ...) and describes
what should happen to a runtime state. No modifier reads or writes a part, a `Humanoid`, or a
service directly.

**Why:** it makes modifiers reviewable by anyone, testable without a world, and safe to write in
parallel. It is also the only way several authors can add modifiers without a shared edit surface.

**Cost:** a new idea sometimes needs a new capability, which is a conversation. That is a feature:
it is how the engine stays coherent.

---

### D-003 — One transform timeline, one commit frame

**Status:** frozen · **Date:** phase 1

Every active modifier's steps are merged into a single scheduler, sorted by phase
(`Before` → `Commit` → `After`), then priority, then modifier id. Exactly one step can claim each
`phase/channel`; the loser is logged. All gameplay values change on the `Commit` frame.

**Why:** independent tweens race, two modifiers fight over the same property, and a player can end
up inside a floor that is halfway between two shapes. Determinism also makes a bug reproducible.

**Cost:** a modifier cannot "just tweak" something another modifier owns. Declare the conflict and
let the ballot handle it.

---

### D-004 — The top N finishers all apply

**Status:** decided · **Date:** phase 1

`MaxStacked` in the escalation table means **the top N vote-getters are all applied**, not "N cards
are on the ballot". Round 1: 1 of 3. Round 6: 3 of 4.

**Why:** it makes stacking work at all, it means voting for a card that comes second is not
wasted, and it turns the escalation into a negotiation rather than a plurality race.

**Cost:** because any two cards on a ballot might both apply, the ballot draw must guarantee that
all cards are mutually compatible. That constraint lives in `Modifiers.draw`.

---

### D-005 — Arenas are cloned from ServerStorage every round

**Status:** frozen · **Date:** phase 0

Arenas live in `ServerStorage.Arenas` as models, are cloned into `Workspace.Arena` at match start,
and are destroyed at match end. The loaded model is `ModelStreamingMode.Atomic`.

**Why:** no state residue between rounds, unlimited arenas, and streaming can never pop a piece in
mid-transform. It also means an arena bug is fixable by replacing one model.

**Cost:** a clone per match. Fine for arenas in the low thousands of parts.

---

### D-006 — Procedural transforms ship first, variants upgrade them

**Status:** decided · **Date:** phase 1

Every modifier has a working procedural transform from day one. A map team can then drop
`Variants/<ModifierId>` into an arena to replace that modifier's procedural **geometry** steps
(`floorGeometry`, `walls`, `cover`), while the modifier's other steps (gravity, lighting, loot,
combat) still run.

**Why:** the systems and the art tracks must not block each other. Neither side ever waits.

**Cost:** two code paths for one feature, and the variant needs discipline to stay in sync with
what the modifier actually does. The validator warns on a variant that matches no modifier id.

---

### D-007 — Deterministic seeds, derived per round

**Status:** frozen · **Date:** phase 1

A match seed is generated at match start; every random decision (arena pick, ballot draw, coin
flips, crate contents) derives from it. The seed is logged and never sent to clients.

**Why:** "it broke on round 4" becomes reproducible, which matters enormously when several agents
write modifiers in parallel.

**Cost:** random draws must be passed an `rng` rather than calling `math.random`. Easy to forget in
review — check for it.

---

### D-008 — A Skirmish format exists for small servers

**Status:** decided · **Date:** phase 1

Under 4 players the game runs a 3-round Skirmish with 2-card ballots and handiwork-appropriate
timings, starting immediately rather than waiting for a lobby.

**Why:** Roblox's ranking signals are heaviest on first-play bounce (<60s and 61–180s), and a new
experience gets 1–3 player servers. A solo player must see the arena transform within a minute of
joining, or they are gone and the game never gets a second chance.

**Cost:** two escalation tables and a format branch in the round loop. Cheap for what it protects.

---

### D-009 — Eliminated players keep voting

**Status:** decided · **Date:** phase 0

Death removes you from the round, not from the vote. Dead players spectate and still cast a vote
in every subsequent round.

**Why:** it is the difference between a death and a session end. It also makes the vote matter more
as a match progresses, which is exactly when the stakes should be highest.

**Cost:** the vote is partly decided by players who cannot be killed for it. That is the point.

---

### D-010 — Damage uses a client-supplied ray, validated on the server

**Status:** decided · **Date:** phase 3

The client sends only a muzzle origin and a direction. The server validates the muzzle against the
shooter's head, rate-limits by weapon, then applies spread, pellets, range, ricochet, ammo and
damage itself.

**Why:** shooting where you look needs a client camera direction, but nothing else about a shot
should be client-decided. This is the smallest surface that still feels like a shooter.

**Cost:** `Tool.Activated` alone cannot express it, so firing goes through one remote. Any new
weapon must go through the same path — do not add a second one.

---

### D-011 — Weapons are data and carry no scripts

**Status:** frozen · **Date:** phase 3

A weapon is a profile table in `WeaponRegistry`. Tools are built from profiles and contain no
scripts; `CombatService` owns every firing path.

**Why:** a new weapon cannot introduce a new exploit, and balance is a number change. It also
avoids runtime `Source` assignment, which is not available in a live game.

**Cost:** a genuinely new *kind* of weapon (a placeable turret, a thrown grenade) needs a
capability rather than a profile. Acceptable.

---

### D-012 — Monetisation ships inert

**Status:** decided · **Date:** phase 0

`Economy.Enabled = false` and every pass/product id is `0`. `MonetizationService` refuses to prompt
while that is true. Rewarded video uses Roblox's native format only, gated behind `PolicyService`.

**Why:** a placeholder id must never be able to charge a player, and shipping the *hooks* before
the *economy* keeps the discipline decision (never sell vote weight) in the code rather than in
someone's memory.

**Cost:** nothing until Phase 6 deliberately flips the flag.

---

### D-013 — One server script, one client script

**Status:** decided · **Date:** phase 0

Everything is a module required by `Bootstrap.server.lua` or `Bootstrap.client.lua`.

**Why:** boot order is a real thing that goes wrong, and having exactly one place where it is
defined beats scattering `task.spawn` calls across forty scripts. It also means the modifier
registry is validated exactly once, before anything can hurt anyone.

**Cost:** the bootstrap files are load-bearing and should be read by anyone debugging startup.

---

### D-014 — `MatchState` exists to break a dependency cycle

**Status:** decided · **Date:** phase 3

Round flags, points, alive/eliminated sets and the death signal live in a small `MatchState` module
that `RoundService` writes and `CombatService` reads.

**Why:** combat needs to know whether ammo is infinite or bullets ricochet, and `RoundService`
needs combat. Without a shared state holder those two require each other and the module graph
becomes load-order dependent — a bug that appears only sometimes, which is the worst kind.

**Cost:** one more small module, and a rule: `RoundService` owns writes.

---

### D-015 — Audio ships as an error-free shell

**Status:** decided · **Date:** phase 4

`AudioService` has empty bed and cue tables. Modifiers may ask for a bed that does not exist; the
call is a safe no-op that records the request on a replicated attribute.

**Why:** the sound identity (stamp thud, tally click, transform rumble) is the biggest single
"feel" upgrade available, but no asset ids exist yet. Shipping the *interface* now means the brand
track fills in a table and every modifier that asked for atmosphere gets it.

**Cost:** an empty-looking service. Documented as such so nobody mistakes it for unfinished.

---

### D-016 — A gray-box reference arena is auto-built in Studio

**Status:** decided · **Date:** phase 1

If `ServerStorage.Arenas` is empty and we are in Studio, the bootstrap builds the Foundry arena
(`src/server/Dev/BuildFoundry.lua`) and logs that it did.

**Why:** pressing Play should always give you a game. It also produces the working example every
map contributor and map AI copies, and it is deliberately ugly so nobody mistakes it for final art.

**Cost:** a dev-only code path in the server bootstrap. It never runs outside Studio, and a real
`assets/arenas/*.rbxmx` simply takes over.

---

### D-017 — Crude structure checking until the real toolchain exists

**Status:** temporary · **Date:** phase 1

`tests/syntax_check.awk` strips comments and strings and checks block and bracket balance across
`src/`. It is not a parser.

**Why:** the repository was written before Rokit/Rojo/Luau LSP were installed on the machine, and
"no verification at all" was not acceptable for 60+ files of Luau. It catches unbalanced blocks,
stray `end`s, unterminated strings and mismatched brackets — the mistakes that actually happen.

**Cost:** false negatives (it cannot type check or resolve requires) and one false positive class
(Luau `if ... then ... else ...` expressions are rejected). **Delete it once `luau-lsp analyze`,
`stylua --check` and `selene` run in the loop.** Until then, run it before merging anything.

---

### D-018 — Aftman, not Rokit, is the toolchain manifest

**Status:** accepted · **Date:** 2026-09-20

`aftman.toml` pins `rojo-rbx/rojo@7.7.0`. `rokit.toml` was deleted.

**Why:** this machine already has Aftman 0.3.0 and Rojo 7.7.0 downloaded and on PATH, and Rokit is
not installed at all. Pinning a version that is already on disk makes `rojo serve` work with no
network. Two manifests pinning two different Rojo versions is the same class of bug as two arena
definitions: whichever happens to resolve wins, silently, and the symptom is a playtest that behaves
unlike the code.

**Cost:** StyLua, Selene and Luau LSP are not pinned yet — they are commented out in `aftman.toml`,
so the awk structure checker is still the only automated check. Rokit can replace Aftman later in one
commit; nothing in `src/` cares which manager resolves `rojo`.

---

### D-019 — Rojo's Two-Way Sync stays off; the working tree is the single writer

**Status:** accepted · **Date:** 2026-09-20

Scripts are edited in `src/` (by hand, by VS Code, or by an agent) and Rojo pushes them one way into
Studio. Studio-side script edits are brought back deliberately, not automatically.

**Why:** the feature was tested properly rather than guessed at. It does work — a one-line change to
`Util/Log.lua` in Studio grew the file on disk 1264 → 1307 bytes in about a second — but it is not
safe to leave on. Reverting that change in Studio did not survive: the server's copy was re-applied
to Studio, Studio re-sent it, and the file was rewritten every few seconds with unchanged content
while the plugin logged dozens of `Write response` entries. A deliberate change to the repository was
overwritten by a stale copy without any prompt, which is the exact failure mode this repository
exists to prevent. The plugin itself tags the setting `unstable`.

Two facts worth keeping, both read from the plugin's source rather than inferred:
- Detection is `instance.Changed` on instances Rojo owns, so **an unsaved script buffer is invisible**
  — Ctrl+S is what makes a Studio edit real. Most "my edit didn't sync" cases end here.
- Turning the setting on or off requires **Disconnect first**: `locked = syncActive` greys the toggle
  out while a session is live.

**Cost:** if you want to script in Studio, an explicit step is needed — ask for the change to be pulled
into the repo, or use Studio's native Script Sync (a separate, released mechanism that does not route
through Rojo's file watcher). Cheaper than a silent overwrite of committed work.

**Related:** `.gitattributes` now pins `eol=lf`. Rojo writes LF while `core.autocrlf=true` expected
CRLF, so every synced file showed up as modified in `git status` with an empty `git diff`. Pinning LF
removes the disagreement between the two tools.

---

### D-020 — Class names are tested with `IsA`, never with `typeof`

**Status:** accepted · **Date:** 2026-09-21

`typeof` reports the **datatype**, not the class name: `typeof(aTween)` is `"Instance"`, and so is
`typeof(aPart)`. The only correct way to ask "is this a Tween?" is
`typeof(x) == "Instance" and x:IsA("Tween")`.

**Why:** `TransformScheduler.collectTween` tested `typeof(result) == "Tween"`, which is **always
false**. The scheduler therefore collected no tweens, `Tweens.await` returned instantly against an
empty list, and every phase ran on before its geometry had finished moving — the exact inconsistency
the phase design exists to prevent. It failed silently: no error, no log line, and the code reads as
if it works.

Found by RobloxLSP's `invalid-class-name` hint (the string in a `typeof` comparison must be something
`typeof` can actually return) and confirmed **in the engine**, not from documentation:

```
typeof(tween)          = Instance
tween:IsA('Tween')     = true
typeof(tween)=='Tween' = false
```

Measured before/after with a real 0.6s tween: the `Before` phase now waits 0.60s; with the old check
it returned in ~0.00s.

**Cost:** a class test takes two steps instead of one. Worth it, because the one-step version is
silently always false — and `typeof(x) == "Instance"` is still the right guard before `IsA`, since
`IsA` only exists on instances. The other `typeof` uses in the repo are correct and unaffected:
`typeof(tool) ~= "Instance"`, `typeof(origin) == "Vector3"`, `typeof(modifierId) == "string"`.

**Related:** two analyzers are installed in VS Code and **both earn their place** — `luau-lsp` (Roblox
type definitions from `globalStorage` plus `sourcemap.json`; the one to trust on types) and
`nightrains.robloxlsp` (whose `invalid-class-name` hint caught this, and which `luau-lsp` does not
report). Do not "clean up" by removing either one.

---

### D-021 — A round ends by elimination only if it began contested

**Status:** accepted · **Date:** 2026-09-21

`waitForRoundEnd` decides whether to end early against a value measured **once, as the round goes
live**: `contested = aliveAtStart > Combat.MinAliveToContinue`. A round that began with nobody to
fight runs its full length and is decided by the deadline rule (healthiest survivor).

**Why:** `Combat.MinAliveToContinue` is 1 and the check was unconditional, so with one player it was
true on the round's first tick. A solo round returned `{ reason = "elimination" }` about **0.25s**
in, the match burned through its three rounds in seconds and then sat idle until the next match.
This is the **first-run experience** — Roblox serves new experiences to 1–3 player servers, and
`Escalation.formatForPlayerCount` already has a Skirmish format built explicitly for that case, so
the format and the rule were contradicting each other. The failure was also what made combat
untestable: a weapon equip was destroyed by a round restart before it could be fired twice.

The rule is not "solo players always win" — the deadline path awards `RoundWinPoints` to the
healthiest survivor, which for a lone player is simply them. The change is *when* the round ends.

**Cost:** a lone player now waits out the full round length (50–75s, Skirmish 50–60s) in an empty
arena. If that reads as dead air rather than anticipation, the honest fix is to shorten the solo
round length or fill it — not to restore an early exit that ends the round before it starts.

**Verification:** confirmed in a one-player Play session. Round 1 (default settings) reported
`Round 1 ended: timeout after 60.0s, 1 alive at the start`, and after a `DevConfig` override of
`RoundSeconds = 12` the next two rounds reported the same shape at `12.0s` — every round reaching its
deadline where the old code returned `elimination` after ~0.25s. **The elimination half is still
unverified**: it needs two players, and this engine offers no way to add one from a script, so it
requires a human to run `Test → Players: 2`.

---

### D-022 — "Has a character" means a playable character, not a non-nil property

**Status:** accepted · **Date:** 2026-09-21

`PlayerService.spawn` only treats a player as already spawned if `player.Character` is parented and
has a `Humanoid` (`hasPlayableCharacter`). `PlayerService.despawn` also drops the reference
(`player.Character = nil`) with the instance it just destroyed.

**Why:** `despawn` called `character:Destroy()`, and the engine left the resulting empty model —
0 children, no `Humanoid`, not parented to Workspace — attached to `player.Character`. The old guard
was `if player.Character then return true end`, so it answered "already spawned" **permanently** from
the first despawn onwards. The player kept a husk for the rest of the session: no `Humanoid`, no
loadout, no spawn point, and `MatchState.Alive[player]` never set. Measured in the live server, the
player sat as `hum=NIL children=0 inWorkspace=no` indefinitely; calling `LoadCharacter` by hand fixed
it instantly (21 children, `Humanoid`, in Workspace, `Health 100`).

This was found *because* D-021's fixed round reported `0 alive at the start`, and it is the other
half of the first-run problem: round 1 spawned fine (nothing had been despawned yet), so a lone
player watched one round and then became unplayable for every round after it. A one-player test is
exactly where a bug that needs a second despawn hides.

**Cost:** two guards instead of one, and `spawn` can now load a character for a player whose previous
model is mid-teardown. Worth it — the old guard failed silently and permanently, and every other
`if player.Character` check in the codebase was fooled by the same stale reference.

**Verification:** same session, after the fix — every round reported `1 alive at the start`, and a
world probe over 24s showed the cycle working: `hum=NIL children=0 inWorkspace=no` (between rounds)
→ `hum=yes health=100 walk=16 inWorkspace=yes children=22` (spawned) → `walk=0` (transform freeze).
The Backpack held `Tool:SIDEARM`, so the loadout path runs again too — **combat is finally testable**,
which it was not while the player had no `Humanoid`.

---

### D-023 — A victim is the Humanoid that owns the part, found by walking up

**Status:** accepted · **Date:** 2026-09-21

`CombatService` resolves a hit with `humanoidOfHit`, which walks up from the hit part until a node
*has* a Humanoid child, instead of `hit:FindFirstAncestorOfClass("Humanoid")`.

**Why:** a character's parts are **siblings** of its Humanoid — the Humanoid is a child of the
character Model, never an ancestor of its limbs — so the ancestor test is **always nil**, for players
and for bots alike. Measured against a live player character in the engine:

```
hit = Workspace.<player>.HumanoidRootPart
FindFirstAncestorOfClass("Humanoid") = nil            <- what the code asked
FindFirstAncestorOfClass("Model")    = <character>, whose Humanoid child exists
```

`findVictim` returned nil for every pellet of every shot, so **no shot in this game has ever damaged
anything**. It failed silently: no error, no warning, and the round simply ran to its deadline. The
same bug sat in the ricochet branch.

**Cost:** none — the walk is a couple of parent hops. `IsA`-style class checks still belong where the
repo already uses them (`D-020`).

**Verification:** player → bot damage through the real client path (`WeaponFire` remote, a real Tool):
`BOT 3 hp=100 → 10`, `BOT 1 hp=100 → 46`, then all three eliminated. See `docs/11-BOTS.md`.

---

### D-024 — Every player's Humanoid is bound at `CombatService.start`

**Status:** accepted · **Date:** 2026-09-21

`CombatService.start` connects `Players.PlayerAdded` → `CombatService.bindPlayer` and binds anyone
already in the server. Nothing had ever called `bindPlayer`.

**Why:** without the binding, `Humanoid.Died` is never connected for a player, so `onHumanoidDied`
never runs: no `Alive = false`, no `Eliminated`, no deaths in stats, no kill credit, and a round that
cannot end early. Measured before the fix: a player shot to zero health with three bots firing at the
body, the round running on, and no elimination line in the log.

Both this and `D-023` were invisible for the same reason: the damage path had never completed once, so
nothing could ever die and the code that handles death had never been asked to run.

**Cost:** nothing. It is one connection that the service already had the function for.

**Verification:** after the fix, a round in which the bots killed the player ended
`elimination after 10.4s`.

---

### D-025 — CPU combatants exist, Studio-only, behind `DevConfig.BotCount`

**Status:** accepted · **Date:** 2026-09-21

`BotService` spawns N CPU combatants per round when `ServerStorage.DevConfig` has `BotCount > 0`, and
`RoundService` counts them as combatants (`aliveCombatants`).

**Why:** Roblox serves a new experience to 1–3 player servers, and every interesting behaviour in
this game needs an opponent. With one human, elimination, kill credit and the round-end rule are all
unobservable — which is exactly why the two bugs above survived a whole build. A bot is a body that
obeys the same rules: the round's loadout supplies its weapon, `GameplayService`'s baseline supplies
its speed and health, and its shots go through the same `resolveShot` a trigger pull does.

**Cost and limits, both real:** bots are crude (no pathfinding — straight-line movement plus a
sidestep when blocked), they do not vote, they do not damage each other, a bot killing a player awards
nobody points, and they are invisible to every system keyed on `Player` (`MatchState`, the scoreboard,
the `PlayerDied` signal). Given a bot can now kill you, the round rule gained one clause: with the
humans dead and a bot still standing, the round ends rather than showing a spectator screen.

Gated by `DevService`, so **it cannot appear in a live server by accident**. Promoting it to a real
"fill the empty server" feature is a product decision with a short list of consequences, written down
in `docs/11-BOTS.md` rather than done quietly here.

**Verification:** all three rounds of a three-bot session ended by elimination — the player killing
all three bots (`34.9s`) and the bots killing the player (`10.4s`, `11.7s`). Bot health went
100 → 0 in about ten seconds of fire; the HUD credited six points for three kills and the round win.

---

### D-026 — The loadout changes at the transform, not at round start

**Status:** accepted (and a correction) · **Date:** 2026-09-21

A player carries the **previous** round's weapons during the vote. `PlayerService.spawn` applies
`CombatService.currentLoadout()` when the round's characters are created — before the ballot has
resolved — and the round's own loadout arrives with the transform, via `SetDefaultLoadout` (which
re-applies to everyone alive) and each loadout modifier's `OnCharacterSpawn`.

**Why it is not a bug:** the tools sit in the Backpack **unequipped**, and `handleFire` returns unless
`MatchState.State == "Live"`, so the old weapon is unusable and invisible during the vote window. A
weapon on screen during a ballot was never the intent, and there is not one.

Measured by flipping `ForceModifiers` between rounds in a live session and reading the replicated
`Loadout` attribute:

```
10:20:46  set MeleeOnly      ->  carrying Shotgun,SawnOff from the previous round
10:21:14  ->  Sword
10:21:26  set PistolsOnly
10:21:43  ->  Pistol,RapidPistol
10:22:06  set MeleeOnly      (flip back)
10:22:11  ->  Sword
```

Every change landed at the next round's transform, in both directions. There is no carry-over.

**Correction.** An earlier claim — that players spawned at round start kept the previous round's
loadout while bots got the new one, recorded in the commit message for `adbe566` and in chat — was
**wrong**. The observation came from a round whose vote really was `MeleeOnly`, so the sword in hand
was the round working as designed. The doc trail never repeated it; this entry is the measurement that
settled it.

**Cost:** a loadout cannot change mid-round before the transform, which is correct — the arena and the
rules are revealed together. If a design ever wants an earlier swap, the place to do it is the same
re-apply in `SetDefaultLoadout`, guarded on `MatchState.Alive`.

**Amended by D-027.** "There is no carry-over" holds only while another *loadout* modifier follows. A
loadout round followed by a round that votes for anything else **did** carry over — see D-027.

---

### D-027 — The loadout is reset every round, and a post-transform check enforces it

**Status:** accepted · **Date:** 2026-09-21

A loadout modifier's effect outlived its own round. `SetDefaultLoadout` overwrites the module-level
`defaultLoadout` in `CombatService`, and `CombatService.resetRound` cleared only the fire and damage
bookkeeping — so once a round voted `PistolsOnly`, **every later round in the match handed out pistols**
until another loadout modifier happened to win. Two siblings already had the reset this one was missing:
`LootService.reset` restores the crate pool and `GameplayService.reset` restores the gameplay baseline.

The loadout is now reset in the same place, at the top of `runRound` before any modifier runs:

```lua
function CombatService.resetRound()
	lastFireAt = {}
	lastDamageBy = {}
	defaultLoadout = table.clone(Combat.DefaultLoadout)   -- was missing
end
```

Order is what makes it safe: `resetRound` runs before `Prepare`/`OnRoundStart`, so a loadout modifier
re-sets the default in the same round it was voted for. Players therefore hold the **default** during a
plain round's vote rather than the previous round's decree — the same harmless pre-transform window
D-026 describes, with the correct weapon in it.

**Why a check, and not just the fix.** This bug is invisible in play: everyone holds a gun, the round
runs, nothing errors. It was found only by comparing the tools in hand against what the round asked for,
which is now a permanent Studio-only assertion, `src/server/Dev/LoadoutCheck.lua`, called from
`RoundService` right after the transform and the bot spawns. It compares each spawned player's actual
`Tool` instances *and* the replicated `Loadout` attribute (as order-insensitive sets) against the round's
expected list: `CombatService.currentLoadout()` when an applied modifier declares the `LoadoutOverride`
effect, and `Combat.DefaultLoadout` when none does.

It is deliberately **not fatal** — the precedent is the tween reporting in `Util/Tween.lua`, where a
reporter once took down the round it was describing. `DevConfig.StrictLoadoutCheck = true` makes it throw
instead. A failed `require` of the check now warns rather than skipping silently, learned the hard way:
its first wiring used `script.Parent.Dev`, but `Dev` is a **sibling** of `Services`, so the require threw
inside a `pcall` and the check never ran once while the log stayed clean.

**Verification.** Two live sessions, one player and one bot, `ForceModifiers` flipped mid-round:

```
BEFORE the fix                                      (the bug, four rounds running)
  Loadout check: 1 player(s) holding [Pistol,RapidPistol] as the round intends (set by a loadout modifier)
  LOADOUT CHECK FAILED - round 1, modifiers: Fog
    expected [Sidearm] (no modifier overrode it, so it is the default)
    whatamihereforfh holds [Pistol,RapidPistol] and its Loadout attribute says [Pistol,RapidPistol],
    but this round's loadout is [Sidearm]
  ... the same failure repeated for rounds 2, 3 and 4

AFTER the fix
  Loadout check: 1 player(s) holding [Pistol,RapidPistol] as the round intends (set by a loadout modifier)
  Loadout check: 1 player(s) holding [Sidearm] as the round intends (the default, since no modifier
                 overrode it)   x4 consecutive Fog rounds
```

The check earning its keep on the very bug it was written for, then going quiet, is the point: a check
that fails on the defect and passes on the fix is evidence, and a check that never fails is decoration.

**What it cannot see:** if a loadout modifier's own step failed outright, the round's loadout is still the
default and a player holding the default matches — a false pass. Closing that needs the modifier's declared
list, which is not exposed anywhere. Documented in the module header rather than papered over.
