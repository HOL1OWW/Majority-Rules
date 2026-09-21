# Modifier API

A modifier is one file in `ReplicatedStorage/Shared/Modifiers/Tier1|Tier2|Tier3/`. The registry auto-loads
every `.lua` file in those folders (files starting with `_` are skipped), so **adding a modifier
is adding a file** — no central list, no merge conflict with another author.

A modifier never touches `Workspace`, never touches a `Humanoid`, and never references an arena
part. It receives a **capability bag** (`ctx`) and describes what it wants to happen. This
document is the complete list of what it may do.

---

## 1. Shape of a modifier

```lua
return {
    Id = "LowGravity",              -- must equal the file name
    DisplayName = "LOW GRAVITY",    -- uppercase; this is what is on the vote card
    Blurb = "Everyone floats. Fights go vertical.",  -- one line a 9 year old gets instantly
    Tier = 1,                       -- 1 warm-up | 2 spice | 3 chaos
    Weight = 12,                    -- relative chance of appearing on a ballot
    Tags = { "Gravity" },           -- category colour + conflict grouping
    Conflicts = { "Gravity" },      -- ids or category tags that cannot co-apply
    Requires = { "FlatFloor" },     -- arena feature tags that must be present
    Bans = { "Indoor" },            -- arena feature tags that must be absent
    Effects = { "GravityDown" },    -- declarative effect names for ModifierSim

    Prepare          = function(ctx) end,
    Steps            = function(ctx) return { ... } end,
    OnRoundStart     = function(ctx) end,
    OnCharacterSpawn = function(ctx, player) end,
    OnPlayerDied     = function(ctx, player, killer) end,
    Tick             = function(ctx, dt) end,
    OnRoundEnd       = function(ctx) end,
    Revert           = function(ctx) end,
}
```

**Category tags** (also the vote card colours):

`Gravity` `Spatial` `Combat` `Environment` `Chaos` — and the grouping-only tags `Loadout`
`Vision` `Mobility` `Shrink`, which exist so that a whole family can be made mutually exclusive
in one line. Any modifier tagged `Loadout` automatically conflicts with any other `Loadout`
modifier, without naming ids.

---

## 2. Lifecycle, in order

| Hook | When | Use it for |
| --- | --- | --- |
| `Prepare(ctx)` | after the vote resolves, **before** the transform begins | Enumerating arena groups, preloading, validating assumptions |
| `Steps(ctx)` | during the transform | The actual arena change, as declarative steps |
| `OnRoundStart(ctx)` | immediately after the transform lands | Non-geometry setup (loadout, flags) |
| `OnCharacterSpawn(ctx, player)` | on every spawn, including join-in-progress | Per-player rules that must survive a respawn |
| `Tick(ctx, dt)` | every frame while the round is Live | Ongoing effects (rising lava, collapsing tiles) |
| `OnPlayerDied(ctx, player, killer)` | on each elimination | Kill-streak style effects |
| `OnRoundEnd(ctx)` | when the round stops | Cleanup that must happen before results |
| `Revert(ctx)` | after the results screen | Explicit undo. The engine also resets everything. |

Every hook is wrapped in `pcall` by the engine: **a broken modifier logs a warning and is
skipped, it never takes the round down with it.**

---

## 3. Transform steps

`Steps(ctx)` returns an array of declared changes. All active modifiers' steps are merged into
**one timeline with one synchronised commit frame** — so two modifiers that both move the floor
cannot race, and nobody falls through a half-scaled world.

```lua
{
    Channel = "floorGeometry",   -- what kind of thing is being changed
    Phase = "Before",            -- Before | Commit | After   (default Before)
    Priority = 30,               -- higher wins a channel collision
    Label = "SmallMap floor",    -- shows up in logs when a conflict is resolved
    Run = function()
        return ctx.Arena:ScaleGroup("Floor", 0.62, 2.4, Vector3.new(1, 0, 1))
    end,                          -- return a Tween (or a table of Tweens) to be awaited
}
```

**Phases.** `Before` starts visuals while the world is still consistent. `Commit` is *the frame*
gameplay values change — gravity, health, loadouts, flags. `After` is follow-up.

**Channels** in use: `gravity` `lighting` `floorGeometry` `walls` `cover` `loot` `combat`
`hazard` `audio` `camera` `arenaVariant` `misc`.

**Conflicts.** Exactly one step may claim a `phase/channel`. If two claim it, the higher
`Priority` wins, ties break on modifier id (deterministic), and the loser is logged. That is
deliberate: silent racing is how a transform ends up with a floor at 0.62 scale and a wall at
1.0, and nobody knows why. If you need a channel, take it; if you need to *cooperate* on a
channel, that is a signal the capability should be richer, not that you should fight.

---

## 4. Capabilities

### `ctx.Arena` — geometry, lighting, hazards

| Call | Does |
| --- | --- |
| `Center()` | Arena centre as a Vector3 |
| `FloorY()` | Declared floor height |
| `Bounds()` | `{ Center, Size }` of the arena's bounding box |
| `GroupNames()` | Every transform group name in this arena |
| `GroupParts(group)` | The parts in a group |
| `ScaleGroup(group, factor, duration, axes?)` | Scale a group about the arena centre. `axes` defaults to X/Z. **Uses live size, so repeated calls accumulate.** Vertical-only scaling pins the bottom face, so a wall grows upward. Returns tweens. |
| `MoveGroup(group, offset, duration)` | Translate a group. `duration = 0` applies instantly. |
| `SetGroupHidden(group, hidden, duration?)` | Collision flips immediately (physics is never mid-tween), transparency animates. |
| `SetGroupPhysics(group, { Friction, Elasticity, Density })` | Custom physical properties for a group. |
| `SetGroupMaterial(group, Enum.Material)` | Material swap. |
| `SetGravity(value)` / `SetGravityScale(scale)` | Absolute, or relative to the arena's neutral gravity. Prefer the scale. |
| `TweenLighting(props, duration)` | Tween any `Lighting` property (`Ambient`, `OutdoorAmbient`, `Brightness`, `ClockTime`, `Fog*`, `Environment*`). |
| `SetHazardEnabled(hazardType, enabled, duration?)` | Switch a hazard volume on/off. Damage is applied by the engine. |
| `HazardParts(hazardType)` | The parts of a hazard. |
| `SetDriftOffset(offset)` | Move the whole arena. Expensive — see MovingArena's rate limiting. |
| `SetNameplate(text)` | Write the in-world verdict sign. |
| `ShowVariant(id)` / `ClearVariant()` / `hasVariant(id)` | Hand-authored override lookups. The engine calls these automatically; a modifier rarely needs them. |

### `ctx.Gameplay` — player rules

| Call | Does |
| --- | --- |
| `SetWalkSpeed(speed, player?)` | Round-wide, or for one player |
| `SetJumpPower(power, player?)` | |
| `SetJumpEnabled(enabled, player?)` | |
| `SetMaxHealth(health, player?)` | Applies now and at every future spawn |
| `SetFrictionScale(scale)` | Character friction multiplier |
| `Flag(name, value)` | **Round flags** — replicated to clients, read by CombatService (`InfiniteAmmo`, `Ricochet`, `Lifesteal`, `DoubleJump`) |
| `SetLifesteal(fraction)` | Sugar for `Flag("Lifesteal", f)` |
| `Heal(player, amount)` / `Damage(player, amount, reason?)` | |
| `SetDefaultLoadout(ids)` | The loadout every spawn gets, for the rest of the round |
| `ForceLoadout(player, ids)` | Replace one player's weapons now |
| `GrantWeapon(player, id)` | Add one weapon |

Anything set here is re-applied to players who respawn or join mid-round. That is the point:
`SetWalkSpeed(23)` is a **rule**, not an event.

### `ctx.Loot` — the weapon pool

| Call | Does |
| --- | --- |
| `SetWeaponPool(ids)` / `RestrictPoolTo(ids)` | Only these weapons can come out of crates |
| `AddWeaponPool(ids)` | Add to the pool |
| `CurrentPool()` | What a crate would give right now |
| `HaltCrates()` | Stop crates entirely (used by Melee Only, which promises no guns) |
| `SpawnAt(point, rng?)` / `SpawnAll(rng?)` / `ClearAll()` | Manual control, rarely needed |

### `ctx.Players`

`All()` · `Alive()` · `Characters()` · `ForEachCharacter(fn)`

### `ctx.Audio`

`SetMusicBed(id)` · `PlayCue(id)` — safe no-ops until the brand track authors real ids.

### `ctx.Round`, `ctx.Rng`, `ctx.ModifierIds`, `ctx.Log`

```lua
ctx.Round = { Number, Total, Format, Seed, Label, Length, Flags }
```

* `ctx.Round.Flags` is a **persistent per-round scratchpad** shared by all active modifiers.
  Namespace your keys (`ShrinkScale`, `TileIndex`) — this is the one place two modifiers can
  collide, so prefix anything non-obvious with your own id.
* `ctx.Rng` is derived from the match seed: same match, same numbers, every time. Use it for
  anything a player could notice, so a bug report is reproducible.
* `ctx.Log(fmt, ...)` prefixes your modifier's id and only prints in Studio.

---

## 5. Rules of thumb

1. **Prefer `Steps` to `Tick`.** Steps compose; ticks fight.
2. **Declare `Effects`.** They cost nothing and they feed the combination simulator, which is
   the only thing standing between you and an unplayable triple.
3. **Declare `Conflicts` when you know a pairing is bad.** The simulator catches effect-level
   collisions; declared conflicts catch everything else and stop the bad card from ever being
   drawn next to yours.
4. **Re-apply per-player rules in `OnCharacterSpawn`.** Round-wide setters do this for you;
   anything you do manually must survive a respawn.
5. **Never assume an arena has what you need.** `Requires` / `Bans` filter the ballot; if the
   optional thing is absent, degrade gracefully and log.
6. **Do not move the camera.** That is the cinematic's job.
7. Keep the blurb under about 40 characters of actual meaning. It is read in a second.

---

## 6. After adding a modifier

1. `Modifiers.validate()` runs at boot in Studio and reports problems. Read the output.
2. `require(game.ServerStorage.Tools.ModifierSim).report()` — no unplayable combinations.
3. Add a row to `docs/03-MODIFIER-CATALOGUE.md`.
4. Test it in a real round. The only test that counts is a full round completing on a
   transformed arena.

If you cannot express your idea with the capabilities above, **the engine needs a new
capability** — that is a `DECISIONS.md` entry and a conversation, not a workaround.
