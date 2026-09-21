--!nonstrict
--[[
	Types.lua — the shapes every contributor codes against.

	These types are documentation as much as enforcement: if you are an AI agent adding a
	modifier, `ModifierDef` below is the entire surface you are allowed to depend on.
]]

export type Phase = "Before" | "Commit" | "After"

--! A single declared change to the world. Modifiers return arrays of these; the
--! TransformScheduler merges them across all active modifiers and executes them once,
--! on one timeline, with one synchronised gameplay commit frame.
export type TransformStep = {
	Channel: string, -- gravity | lighting | floorGeometry | walls | cover | loot | audio | camera | hazard
	Phase: Phase?, -- defaults to "Before"
	Priority: number?, -- higher wins when two steps claim the same channel+phase
	Label: string?, -- shown in logs and analytics when a conflict is resolved
	Run: (ctx: any) -> any?, -- returns a Tween to await, or nil
}

--! Everything a modifier is allowed to touch. No modifier ever receives `Workspace`.
export type Ctx = {
	Round: RoundInfo,
	ModifierIds: { string },
	Rng: Random,
	Arena: any, -- ArenaController   (see docs/02-MODIFIER-API.md)
	Gameplay: any, -- GameplayController
	Loot: any, -- LootController
	Players: any, -- PlayersController
	Audio: any, -- AudioController
	Log: (fmt: string, ...any) -> (),
}

export type RoundInfo = {
	Number: number,
	Total: number,
	Format: string,
	Seed: number,
	Label: string,
	Length: number,
	Flags: { [string]: any },
}

export type ModifierDef = {
	Id: string,
	DisplayName: string,
	Blurb: string,
	Icon: string?,
	Tier: number, -- 1 = warm up, 2 = spice, 3 = chaos
	Weight: number?,
	Tags: { string }?, -- Gravity | Spatial | Combat | Environment | Chaos
	Conflicts: { string }?, -- modifier ids or category tags that cannot co-apply
	Requires: { string }?, -- arena feature tags required
	Bans: { string }?, -- arena feature tags that forbid this modifier
	MinRound: number?,
	MaxRound: number?,
	StacksWell: boolean?,
	Effects: { string }?, -- declarative effect names, consumed by the combo simulator

	Prepare: ((ctx: Ctx) -> ())?,
	Steps: ((ctx: Ctx) -> { TransformStep })?,
	OnRoundStart: ((ctx: Ctx) -> ())?,
	OnCharacterSpawn: ((ctx: Ctx, player: Player) -> ())?,
	OnPlayerDied: ((ctx: Ctx, player: Player, killer: Player?) -> ())?,
	Tick: ((ctx: Ctx, dt: number) -> ())?,
	OnRoundEnd: ((ctx: Ctx) -> ())?,
	Revert: ((ctx: Ctx) -> ())?,
}

return {}
