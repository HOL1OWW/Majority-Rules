# Decisions

Architecture decision record. **Reasoning lives here, not in a chat log** — an agent that hands a
task to another agent loses everything that was not written down, and "why is it like this" is the
most expensive question in a codebase with several authors.

Format: what we decided, why, and what it costs. Newest at the bottom.

---

### D-001 — Tags and attributes are the only crossing surface

**Status:** frozen · **Date:** phase 0

The map and the systems never reference each other's internals. All cross-team data is a
CollectionService tag or an Attribute whose name is declared once in `ReplicatedStorage/Shared/Tags.lua`. Arena
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
(`ServerScriptService/MajorityRulesServer/Dev/BuildFoundry.lua`) and logs that it did.

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
which is now a permanent Studio-only assertion, `ServerScriptService/MajorityRulesServer/Dev/LoadoutCheck.lua`, called from
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

---

### D-028 — The reference arena is designed against a measured gate, and the gate now measures clearance

**Status:** accepted · **Date:** 2026-09-21

`ClearanceRadius` was documented in the contract as *"how much open space a crate needs, used by
**tooling**"* and no tooling had ever read it, so the first Foundry layout passed the validator while being
unplayable in four spawns out of eight. The validator now measures the crate `LootService` actually
builds — 3×3×3, spawned 2.5 studs above the loot point — against the real (rotated) cover boxes, and
errors when a crate would spawn inside cover or closer than the clearance it declares.

That check failed the layout it had been blessing, in **ten** places: four loot points whose crates spawn
inside cover (invisible, and takeable *through* it because the prompt sets `RequiresLineOfSight = false`),
four spawns inside cover (the player is ejected when cover rises), and two loot points 6.36 studs from
cover while declaring 8.

The arena was rebuilt rather than patched: a colonnade of eight 7×6×7 cover pieces at radius 15, spawns
half a slot out of phase at radius 26 so every spawn is equidistant from cover and none sits inside it,
5 loot points (centre plus diagonals), 8-stud tiles instead of 20 (64 of them, so a collapse removes a tile
a player can see coming), and walls 26 high against `LowGravity`'s own 22.8-stud jump apex.

**Verification.** `ArenaValidator.validate(Foundry)` → `ok=true`, 107 parts, 8 spawns, 5 loot, 4 cameras,
`minLootClearance=9.5` against a declared 8, 0 errors and 0 warnings. Sightlines measured by raycast at
chest height over 7260 point pairs: **100% clear with cover hidden** (round 1 really is an open square)
and **39% clear with cover up**, median line 33.9 → 24.7 studs. Full numbers, the deliberate aligned fire
lanes, and the two probe traps (`require` caching, and `CanQuery = false` not applying within the frame)
are in `docs/13-ARENA-DESIGN.md`.

**Cost:** the reference arena is now four times the parts (107) for the same play space, and its layout is
opinionated — a symmetric ring is fair but produces symmetric lanes. Both are recorded as tuning knobs
rather than solved. The arena is also still grey-box: this is layout, not art.

**Amended by D-030:** the "this is layout, not art" half did not survive contact with the game's own
premise and is superseded — the arena is art-directed now, out of primitives. The layout half of this entry
still stands.

---

### D-029 — A modifier's pace belongs to the modifier, not to the arena's part count

**Status:** accepted · **Date:** 2026-09-21

`CollapsingFloor` removed **one tile per 3.5s** up to 60% of the floor. That reads as a fixed pace and is
not one: it is a property of how many tiles the arena happens to have. On the 16-tile floor it was tuned
against, 60% takes 31.5s; on the new 64-tile floor the same rule would need **133 seconds**, so the round
would end with the floor barely touched — a modifier that silently stops being itself on a bigger map.

The batch size is now derived from the tile count against a time budget, so the promise ("most of the floor
gone within a round") holds on any arena, and the 16-tile case is arithmetically unchanged at one tile per
step:

```
batch = ceil(floor(tiles * 0.6) / floor(32 / 3.5))
```

| tiles | 60% limit | batch | limit reached in |
| --- | --- | --- | --- |
| 16 (the arena it was tuned on) | 9 | 1 | 31.5s (unchanged) |
| 48 | 28 | 4 | 24.5s |
| **64 (the new Foundry)** | **38** | **5** | **28.0s** |
| 100 | 60 | 7 | 31.5s |

The modifier also logs its own progress now, Studio-only via `Log.debug`, because its pace was previously
invisible: tuning it meant sampling the arena from outside the game.

**Verification.** Pacing exercised against a stub context across five tile counts (table above), and
confirmed in a live round by sampling the built arena every 2s: `38/64` collapsed and flat thereafter —
the 60% limit holding, not just the pace. The log line renders in a real session; in the stubbed pacing run
its elapsed-seconds column reads `0.0s` because no wall time passes between simulated ticks — an artefact
of the harness, not of the modifier.

**Cost:** the modifier now has one more constant (a 32-second budget) that someone must keep in mind when
the round length changes. It is stated in the file, next to the arithmetic that uses it.

---

### D-030 — The arena is art-directed out of primitives, not left grey-box

**Status:** accepted · **Date:** 2026-09-21

D-028 described the rebuilt arena as "layout, not art" and left the look to a map-side job. That was
the wrong call for this game in particular. The pitch is that the arena **transforms in front of you**,
which means the arena is on screen for the entire first impression and most of the round; a grey-box
hall of concrete and two greys makes the transforming parts read as a bug rather than as a change.

So the reference arena is looked after as a design object:

* **The fiction is the brand.** A hall built out of forms — stacked paper courses over concrete, ribbed
  and buttressed, colour-coded windows, a wall of filing banks, roof pipework, banners, a Clerk's box
  watching the floor. The transforming parts are authored as **office partitions and a tiled floor**, so
  when a vote moves them it reads as the institution closing in.
* **Colour is information.** Lime is the vote, gold is the verdict, and the eight modifier categories
  each own a hue. Every cover column, window bay, banner and lamp is one of them, so the colonnade is a
  colour key for the modifier catalogue.
* **Lighting and VFX are part of the build**, not defaults: dusk clock, haze, bloom, colour correction,
  sun rays, coloured pendant lamps with point lights, and six `OnModifier`-gated particle systems.
  `GameplayService` captures its baseline at round start, so the builder owns the look every modifier
  departs from and returns to.
* **Zero meshes.** All primitives, Roblox materials (`Slate`, `Granite`, `Concrete`, `Marble`,
  `DiamondPlate`, `CorrodedMetal`, `CeramicTiles`, `Pavement`, `Fabric`, `WoodPlanks`), `SurfaceType`
  studs, inlets and grooves, plus `Neon`. Nothing to upload, nothing to licence, and every dimension stays
  editable by the system that has to move it.

**Why not meshes:** the parts that transform must remain scaled and repositioned by `ArenaService`, and a
mesh is a frozen shape. Decorating the *static* shell with generated meshes is a valid next step (see
`docs/12-ART-PIPELINE.md`) and does not affect this decision.

**Verification.** `ArenaValidator` passes on 438 parts, 8 spawns, 5 loot, 5 cameras, minimum crate
clearance 9.0 against a declared 8. Extent 84 x 62.4 x 84. Palette, layout table, sightline counts and
live collapse timings: `docs/13-ARENA-DESIGN.md`.

**Cost:** 438 parts against 107 (a 4x increase, still a fifth of the contract's 2500 budget) and a much
longer builder module. It is also an *opinion* about look, which the map team may overrule — the contract
asks for geometry and tags, and nothing here is required by it.

---

### D-031 — An invisible part is a marker and must not block a ray

**Status:** accepted · **Date:** 2026-09-21

Combat and bots both reach their targets with `Workspace:Raycast`. Nothing in the codebase distinguished
"a part you can see" from "a part that only exists to mark a position", so every invisible helper was an
invisible wall. Two bugs, both found by probing the built arena rather than by reading it:

1. **The arena's own emitter containers swallowed every shot.** Six atmosphere containers are 64-by-64
   plates parked at combat height (embers at y = 1.5, frost at 2.5, sparks at 6, motes at 10, mist at 16,
   rubble at 24). All six were raycast-hittable, so bullets stopped in mid-air and bots looked through a
   solid plate. A probe reported `invisibleStillQueryable = 51` parts; it is now **0**.
2. **Hidden cover still blocked line of sight.** `ArenaService.applyAnchorState` set `Transparency = 1`
   and `CanCollide = false` for authored-hidden parts but left `CanQuery` alone — and the arena *starts*
   with the whole colonnade hidden, so on round 1 every bot was aiming at cover nobody could see and every
   shot stopped on it. `CanQuery` is now written by the anchor-state path in both directions, and restored
   from the snapshot like `CanCollide`.

The rule is now stated in both places it can be violated: `BuildFoundry`'s part helper applies
`CanQuery = false, CanTouch = false` to anything that is both transparent and non-colliding, and
`AGENTS.md` tells map contributors the same thing.

**Verification.** The builder probe counts invisible parts that are still queryable: 51 → 0. The
anchor-state half is covered by code inspection plus the snapshot/restore path; it has **not** been
observed in a live round with cover revealed, because forcing `CoverCrates` in a playtest needs a vote
that skips. That is an honest gap, and the next `CoverCrates` round should confirm it.

**Cost:** `CanTouch = false` on markers means a touch-based hazard or trigger could not be built on an
invisible part. Hazards here are volume checks (`CombatService` tests the character's position against the
hazard box), so nothing existing is affected.

---

### D-032 — A hole in the floor must be a hole, and falling out of the arena must end you

**Status:** accepted · **Date:** 2026-09-21

The arena's plinth was three solid slabs under the tiles, so a collapsed tile was a two-stud step onto
concrete rather than a hole: “Collapsing Floor” could remove 60% of the floor and change nothing that
mattered. The plinth is now a **frame** with the interior open, and the grout substrate under the tiles
is non-colliding, so a missing tile is a real fall.

That change created a second problem the old design could not have. Below the arena sits the place's
Baseplate — **512x20x512 at (0,-39,0), top face y = -29** — so a player who fell through a hole landed on
it: alive, 29 studs below the play space, and never eliminated. `waitForRoundEnd` never saw them die, so
the round could not be decided by elimination and the player could not get back. Nothing anywhere checked
for it: there was no out-of-bounds rule in the codebase.

`RoundService` now has one, `voidKill`: while a round is live, any living player whose root goes below
`FloorY - 20` has their Humanoid killed, which routes through the ordinary death path (stats, kill credit,
`PlayerDied`, spectator camera). The margin sits between the two real floors of this place — the Lava
volume at y = -16 and the Baseplate at y = -29 — and is a constant at the top of the rule.

**Verification.** Live, with the character's root pinned 21 studs below the floor so that no fall is in
progress and fall damage cannot explain a death: health 100 → 0 within 0.25s, and the log line
`Round: whatamihereforfh fell out of the arena (y -25.0, floor 0.0)`. Separately, the hole itself was
verified in Edit mode with `RespectCanCollide = true`: casting down from a tile with that tile excluded
finds nothing collidable until the Lava volume at y = -17.

**Cost:** an arena whose floor is *meant* to be a pit would need this rule relaxed — the margin is a
single constant, but the assumption that below the floor means death is now baked into the round. The
wider cost is that the contract now has a requirement it did not state, so it has been added: see
`docs/01-ARENA-CONTRACT.md`, “the underside must stay open”.

### D-033 — The upper level is one circuit, not four islands

The first two-level version had a gallery along the north and south walls and four corner balconies
joined to them by two straights: you could take height, but only in two places, and the east and west
walls had no second level at all. On a 128-stud floor that is a camping platform, not a route. The
gallery now runs **all four walls** — six segments each, from x/z −47 to +47, butting into the corner
balconies at both ends — so the upper level is a ring a player can run the whole way round. `Vertical`
is an honest feature tag because of it.

Three things had to move to make the ring work, and all three were invisible in the source:

* **The stairs.** A flight centred on its balcony climbed through the gallery deck of the wall it lands
  beside. Flights run in the *inboard* half of the balcony's width now (`BALCONY_SIZE −
  GALLERY_DEPTH − 0.8`), against the wall, so the landing is clear.
* **The pigeonholes.** The records counter's wall of boxes ran from y 5.6, and the west gallery deck
  crosses that wall at y 7..8: the bottom row was built *through* a deck players walk on, a 0.70-stud
  intersection. The stack now starts above the deck.
* **The Clerk's box legs.** They ran from the floor to y 14 on the north wall, which is exactly where
  the north gallery deck is. They start at the deck (y 8) now, so the box stands *on* the gallery —
  which is also the only sensible way to reach it.

**Cost:** the ring makes the perimeter a strong position — 7 studs of height, a rail on the arena
side only, and no floor-level way to see it coming except the stairs. It is drop-off only under normal
gravity, and LowGravity makes it jump-reachable both ways, so the modifier that decides this is a
round vote rather than an arena constant.

### D-034 — Prop placement is a rule, not a set of coordinates

Every real bug in this arena has been the same bug in different clothes: a prop positioned by a stud
count that stopped matching the geometry. Four desks inside a colonnade column. Four ballot stacks
under cover pieces. Two mail carts inside filing banks. A stamp press inside a column. A filing bank
inside a balcony leg. Three queue-barrier bases standing on crate pads. A notice board's back 0.4
studs inside the wall it was mounted on. None of those broke a contract rule, and none were findable
by reading the code — they were found by cloning the built model and asking the engine.

`BuildFoundry` now keeps a table of world-space bounds for every visible part it creates, and props
are placed through `settle` (slide along the prop's own lane until the footprint is clear) or
`settle`-style candidate search. Wall furniture slides *along its wall*, so it stays flush; the
authored position is always candidate zero, so a prop only moves when it has to, and every move is
logged. Crate pads and spawn volumes are registered as keep-outs **before** the clutter is built, from
the same ring constants, because a crate that spawns inside a prop is worse than a prop that moved.

**Verification:** structure check clean; the guard is deterministic and runs on every rebuild. The
one thing it cannot do is prove the *authored* composition survives — 17 props now go through it, and
the probe reports any prop that could not find clear ground rather than placing it anyway.

**Cost:** the guard is conservative — rotated parts register their axis-aligned box, so a rotated prop
reserves slightly more floor than it occupies, and a prop can be pushed a few studs off the position a
designer chose. Both are the right direction to be wrong in, and the log names every prop that moved.

### D-035 — A cylinder's axis is its local X, and three props were built on their sides

`Shape = Enum.PartType.Cylinder` puts the axis along the part's **local X**, not its Y. So a part with
`Size = Vector3.new(3.4, 0.5, 0.5)` and no rotation is a 3.4-stud bar lying horizontally. Every queue
barrier in the hall was built that way:

* the "posts" were horizontal bars at chest height, 3.4 studs long
* the bases were 2.4-stud discs standing on their rims, with **0.98 studs of the disc under the
  floor** — which is what the probe was reporting as 44 separate floor intersections, and which the
  previous fix had chased to 0.22 studs of lift rather than to the orientation
* the "ropes" were 1.2 studs long between posts 7 studs apart, so 5.8 studs of every gap was nothing

The same mistake had the water cooler's bottle lying on its side on top of the cooler. All of it is
turned up now: `CFrame.Angles(0, 0, math.pi / 2)` stands a cylinder up, the rope is 7 studs long with
no rotation when the queue runs along X, and the footplate is a 0.4-thick disc at y 0.2 with none of
itself below the tiles.

**Cost:** a cylinder sized as `(height, diameter, diameter)` reads as upright and is not — the
orientation has to be explicit at every call site. Worth a helper if a fourth one appears.

### D-036 — The probe must not report its own instruments

The placement probe's first run reported 118 pairs and 14 "markers that still block rays". Both
numbers were wrong, and both were wrong in the same direction: the probe was measuring itself.

* **Markers.** The rule was "transparent **or** non-colliding", which made the grout substrate two
  studs under the floor and four neon `VOTE` letters thirty-four studs up into "markers that still
  block rays" — a false alarm about D-031, which is exactly the alarm that must never be false. A
  marker is transparent **and** non-colliding. Visible non-colliding parts are now reported
  separately, as information, because a sign that stops a bullet is legal and a wall you cannot see
  is not.
* **Sampling.** The sightline grid ran to `half − 2`, which is the *outer edge of the outer tiles* —
  so the corner samples stood inside the partitions, the filing banks and the records counter, and
  every one of their rays was blocked at zero range. The arena read as **74% blind at chest height
  with cover hidden**, which would have sent someone hunting for geometry that is not there. Samples
  are inset 8 studs and any grid point standing inside a prop is dropped and counted.
* **The hole.** The downward cast started at `tile.Position + Size.Y`, which is above the tile's *top*
  face, so the first thing the ray hit was the tile being asked about: `first collidable part is
  Tile_1 at y = 0.0`. It starts below the tile now.

**Lesson:** a probe is code, and the reference arena's probes have been wrong more often than the
arena. Every number this file quotes is worth re-deriving before it is trusted, and a *false* finding
costs more than a missing one because it looks like progress.

### D-037 — Studio fills the lobby with bots

`DevConfig.BotCount` was the only way to get CPU combatants, and `ServerStorage.DevConfig` is created
by hand in Studio and does not survive a restart of the editor. So the last four Play sessions ran
**one human and zero bots** — every round a 50–60s timeout with nothing in it — while the log said
`0 bot(s)` and looked fine. A test harness that has to be remembered is a test harness that is not
running.

`BotService.devCount()` now decides the count: an explicit `BotCount` wins (including 0, for a solo
round), and otherwise **Studio fills the lobby to 8** while a live server gets zero. The gate is
`RunService:IsStudio()`, not the presence of a config folder, so there is still no way to turn this on
in production. Bots were already full combatants for the round-end rule (`aliveCombatants` counts
them), which is why a round with them can end by elimination.

### D-038 — A vision modifier has to blind the bots too

With D-037 in place, a Play session finally produced a round worth reading, and the round durations
were:

| Vote | Round length |
| --- | --- |
| `Fragile`, `ShotgunsOnly`, `NoJump`, `Gamble` | **2.8s** |
| `Fog`, `MeleeOnly`, `SmallMap`, `Gamble` | **4.7s** |
| `LowGravity`, `DoubleJump`, `SpeedBoost`, `Gamble` | 7.6s |
| `PistolsOnly`, `Blackout` | **8.0s** |
| `ShotgunsOnly`, `NoJump` | 12.5s |

Two readings. The first is that the short rounds are the *right* short rounds: `Fragile` cuts health and
`MeleeOnly` takes away reach, so a 2.8-second brawl is the modifier working, not the arena failing. The
second is a bug. A bot's line of sight is a geometric raycast, so **`Blackout` blotted out the hall for
the one human and did nothing at all to seven machines** — an 8.0-second turkey shoot that reads in a
log exactly like a well-balanced round.

Until bots have a vision model worth the name — a sight cone, a memory of where a target went — they get
the handicap by *range*: each stacked modifier carrying the `VisionLimited` effect halves engagement
range, floored at a quarter (`BotService.visionScale`). That is deliberately crude. The point is that a
vision modifier now changes the fight for everyone in it, and a round that votes `Blackout` is no longer
the round where the machines win by default.

**Cost:** bots are now noticeably weaker in `Fog` and `Blackout`, which will make those rounds last
longer and read as easier. If a bot is meant to be a *threat* in a vision round rather than a body,
that is the knob to argue about — and the honest fix is a sight cone, not a range multiplier.

### D-039 — `S` is for props authored against the 96-stud hall, not for new ones

`local S = HALF / 48` exists so furniture placed for the 96-stud hall travels with the walls when the
floor grows. Two rings were authored for the **128-stud** hall and scaled by it anyway:

| | Intended | With `* S` | What it hit |
| --- | --- | --- | --- |
| the archive | `44 * S` → radius **58.7** | hard against the east wall, inside the gallery circuit | two `GalleryStrut_S` intersections — a shelf crown and a frame through the strut that carries the upper deck |
| the voting booths | `43 * S` → radius **57.3** | same wall band | `Vending_Body` 0.85 studs inside a booth's back panel |

Neither was a placement error at the time it was written: at radius 44 the archive is in open mid-field,
and at 43 the booths are too. Multiplying an absolute stud by a hall-resize factor moved both 14–15 studs
outward, onto the perimeter, underneath a gallery level that did not exist when either was authored.

Both are now absolute, and both are where geometry says they fit:

* **Archive at 42.** The free band between the colonnade's outer face (38.1) and the crate pads' inner
  edge (44.5) is **6.4 studs**, and a unit is 3.0 wide radially, so a centre in 39.5..43.0 keeps a stud of
  air at both ends. Units are 15 degrees apart at that radius — 11.0 studs against a 6.8-stud unit — and
  are slid along **X**, which for this arc is close to the tangent. Sliding along Z looks right and is
  wrong: it drifts the ring out to 47.7 into the crate pads, and in to 36.3 into the colonnade.
* **Booths at 41**, i.e. 2.9 studs off the colonnade and 3.5 off the crate pads.

**A wording trap:** `ServerStorage/Tools/ArenaValidator.lua`'s `ClearanceRadius` doc says a loot point declares a
"radius whose circumference must be clear of cover". That is a statement about the **crate**, which
`LootService` builds as 3x3x3 — *not* about the 7x7 marble pad under it, which the validator does not
measure and which every loot point has stood inside since the pads were introduced. Worth knowing before
somebody "fixes" the pads to satisfy a documentation line.

### D-040 — The placement guard converges only when landmarks are placed first

The guard settles each prop against everything already built, so the order props are placed in decides
the result. In revision 6 the five voting booths and the four archive units were placed **last**, after
every desk, barrier and bank, and the probe then found:

```
Vending_Body into BoothBack_01 by 0.85
GalleryStrut_S_3 into VaultCrown_2 by 0.50
GalleryStrut_S_3 into VaultFrame_2 by 0.42
BarrierBase_4 into VaultFrame_1 by 0.33
```

Every one of those is a prop that landed on a landmark which had already made its own decision, and a
barrier base touching a shelf frame is not a clearance problem — it is furniture built inside furniture,
which is the exact class of bug this guard exists to remove. Landmarks are now placed among the
keep-outs, before anything that slides out of the way. The keep-out table already established the
principle for contract geometry; this extends it to scenery.

**Still standing, and worth a session of its own:** the guard is a sequential search, not a solver. A prop
moved 24.5 studs to satisfy everything before it can violate something built after it, and the fix is
always another pass. If overlaps appear again the answer is a two-pass build (reserve, then place) or a
cost function — not a third `settle` call site.

---

### D-041 — The repository mirrors the Roblox tree, not a `src/` layout

**Status:** accepted · **Date:** 2026-09-21

The code directories are named after the services they sync into: `ReplicatedStorage/`,
`ServerScriptService/` (holding `MajorityRulesServer/`), `ServerStorage/` (holding `Tools/`), and
`StarterPlayer/StarterPlayerScripts/` (holding `MajorityRulesClient/`). `default.project.json`
maps each one to its instance, so **instance paths are unchanged** — the place, Rojo and
`tests/sync_audit.py` are unaffected; only disk paths moved.

**Why:** the Explorer and the file tree now read the same, so "the place is the repo" is visible at
a glance — which matters because the whole Studio-first workflow treats the two as one project.
The old `src/{shared,server,tools,client}` layout translated in everyone's head, and the
translation was a standing source of wrong paths in docs, tasks and comments.

**Cost:** paths in prose longer (`ServerScriptService/MajorityRulesServer/Dev/` was `src/server/Dev/`);
every doc, config and comment had to move in the same commit or the reference rot begins. The old
`src/` name must never be recreated — a fresh `git clone` of a pre-D-041 revision syncs correctly
only until the project file and the directories disagree.

---

### D-042 — Landmarks are built before the clutter, not after

**Status:** accepted · **Date:** 2026-09-21

`votingBooths` and `archiveVault` are called after the keep-out reservations and before the settling
clutter in `build`. On rev 7 they were built last, so the desks, barriers and cabinets had already
settled into the floor the booths were about to claim — 12 of the 13 overlaps the probe reported on
the rev-7 run, including a desk at booth 03's own position. The code now does what its comment always
claimed ("landmarks first").

**Why:** `settle` clears against what already exists in `occupied`; it cannot avoid a thing that does
not exist yet. D-040's reserve-then-place prediction came true, and the fix is the cheapest form of
it: the guard never needed to be a solver, it needed the world to exist before it searched.

**Cost:** the booths and vault units no longer slide away from a colliding prop — they are
authoritative. A prop that cannot clear them reports "no clear ground" and stays put; that is the
correct failure, because the fix for it is editing the prop's authored spot, not moving a landmark.

---

### D-043 — A cylinder's flat axis is its local X; standing a disc up and facing it out of a wall are different turns

**Status:** accepted · **Date:** 2026-09-21

The Clerk's box clock used `CFrame.Angles(0, 0, pi/2)` on its cylinder face — the turn every other
cylinder in the file uses to stand a disc *upright* (axis vertical: posts, wheels, trunks). A wall
clock needs the disc *vertical and facing out of the wall*, which is `Angles(0, pi/2, 0)`. The clock
has therefore been a horizontal 9-stud plate at y=35 since it was authored, poking 4.5 studs off the
north wall — through the marquee.

**Why:** `MarqueeBack into ClockFace` survived three fixes across revisions 5, 6 and 7, each moving
the marquee. The pair was real every time; the marquee was never the bug. The probe's rotated-extents
math was correct — it was faithfully measuring a disc that really was horizontal.

**Cost:** the clock hands moved out 0.6 studs to sit in front of the upright disc. Nothing else uses
the wrong-axis idiom — every cylinder was checked by hand.

---

### D-044 — Bots are combatants, not props: bot shots damage bots

**Status:** accepted · **Date:** 2026-09-21

`resolveShot`'s victim gate — "a bot's shot only counts against players" — is gone. Any humanoid
counts: bot on bot, bot on player, player on either. Alongside it, BotService gained the three
behaviours that make a bot read as a body: it **retaliates** against whoever last damaged it
(`CombatService.lastAttackerOf`, a 5-second grudge that beats nearest-target), **drifts sideways**
while holding position so a still bot is not a free shot, and **disengages** when fresh damage drops
it below 30% health. Targeting also gained 10 studs of per-bot stickiness so seven bots stop agreeing
on one nearest target and moving as a school of fish.

**Why:** the old gate existed when bots were a prop for testing the human's round, and it made the
simulation a puppet show — every bot aimed at another bot, fired, and the damage was discarded before
it was applied. A "fight" where shots cannot connect is not a fight. In a live server no shooter and
no victim is a bot, so the removed branch was unreachable in production; the change is
Studio-simulation-only in effect.

**Cost:** kill credit stays player-only (`lastDamageBy` records the firing *character* for
retaliation, but only a player attacker can claim the kill), so a bot that softens a target for a
player still cannot steal the kill. Attribution now stores a Model alongside the Player, and
`lastAttackerOf` reads it without consuming it, so `creditKill` behaviour is unchanged. The
retaliation grudge can pull a bot across the map toward its attacker; that is what a player would do.
