--!nonstrict
--[[
	CrateVisuals — what a weapon crate looks like, chosen by the weapon inside it.

	A crate's silhouette is a read, not decoration: a player sees the crate before they see the
	weapon, so a sidearm arrives in a flat case and everything else arrives in the standard block.
	`Class` on the weapon profile is the switch; a class with no entry here gets `Default`, so a
	new weapon needs no crate code at all.

	WHY A `Part` + `SpecialMesh` AND NOT A `MeshPart` — this cost a live round, so it is written down:

	Writing `MeshPart.MeshId` at runtime is REFUSED in Studio. Every thread we could test it from —
	an MCP probe and the round loop itself — failed with

	    The current thread cannot write 'MeshId' (lacking capability NotAccessible)

	`LootService.SpawnAll` runs inline in the round, so the throw took the whole round with it
	("Round 1 aborted: ... MeshId"). `SpecialMesh.MeshId` and `SpecialMesh.TextureId` are not gated,
	and a `Part` collides as its box — which is the collision a crate wants anyway. See D-062.

	Mesh ids are uploaded assets on this account. `assets/PROVENANCE.md` records where the case came
	from, who made it, and that its licence is still unread — do not publish the game until that row
	says otherwise.
]]

local CrateVisuals = {}

--! The crate the game has always built: a bright block. Crates are the one high-contrast object
--! in the arena, so a visual that replaces this trades that away on purpose.
CrateVisuals.Default = {
	Size = Vector3.new(3, 3, 3),
	Color = Color3.fromRGB(214, 255, 63), -- brand accent: crates are the only bright thing
	Material = Enum.Material.Metal,
}

--! How far a crate's underside sits above its loot point. Loot points are authored at
--! `surfaceTop - 1` (see docs/13), so this is what puts the crate exactly on the floor.
CrateVisuals.UndersideLift = 1

--! Keyed by the weapon profile's `Class`. Anything absent falls through to `Default`.
--!
--! `NaturalSize` is the mesh exactly as uploaded, measured off the `MeshPart` the importer made
--! (the authoring script said 1.60 x 1.10 x 0.82 m and it arrived 1:1 in studs, so 1 Blender unit
--! came in as 1 stud). `Size` is the shipping box, and it must stay a UNIFORM multiple of
--! `NaturalSize` — a non-uniform stretch distorts every bracket, seam and rivet at once, which is
--! the mistake `docs/12-ART-PIPELINE.md` records from the Roblox-generated props.
CrateVisuals.ByClass = {
	Sidearm = {
		MeshId = "rbxassetid://74022968545497",
		TextureId = "rbxassetid://95272820017246",
		NaturalSize = Vector3.new(1.7792, 0.8220, 1.1827),
		Size = Vector3.new(6.493, 3.000, 4.316), -- x3.650 of natural: 3 studs tall, like the block
		Color = Color3.new(1, 1, 1), -- the atlas carries the look; a tint only muddies it
	},
}

local Weapons = require(script.Parent.WeaponRegistry)

--! The visual for the crate that would hold this weapon.
function CrateVisuals.forWeapon(weaponId: string)
	local profile = Weapons.get(weaponId)
	local class = profile and profile.Class
	return (class and CrateVisuals.ByClass[class]) or CrateVisuals.Default
end

--! The scale that takes a mesh from its authored size to its shipping size. Uniform by
--! construction — `tests/crate_visual_check.py` fails if `Size` stops being a clean multiple.
function CrateVisuals.meshScale(visual): Vector3
	return visual.Size / visual.NaturalSize
end

--! The largest crate any weapon can spawn in. The clearance check has to use this one: a loot
--! point that is legal for a 3-stud block can still bury a 6.5-stud case in cover.
function CrateVisuals.largestSize(): Vector3
	local default = CrateVisuals.Default.Size
	local x, y, z = default.X, default.Y, default.Z
	for _, visual in CrateVisuals.ByClass do
		x = math.max(x, visual.Size.X)
		y = math.max(y, visual.Size.Y)
		z = math.max(z, visual.Size.Z)
	end
	return Vector3.new(x, y, z)
end

--! Where a crate's origin goes relative to its loot point, so its underside rests exactly
--! `UndersideLift` above it. Derived from the built crate's real height rather than written down
--! as a constant: a taller crate with a hardcoded offset floats, a shorter one sinks into the
--! floor, and a visual that falls back to the block would do both at once.
function CrateVisuals.spawnOffset(size: Vector3): Vector3
	return Vector3.new(0, size.Y / 2 + CrateVisuals.UndersideLift, 0)
end

return CrateVisuals
