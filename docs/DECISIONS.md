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
