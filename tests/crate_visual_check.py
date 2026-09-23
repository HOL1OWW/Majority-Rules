#!/usr/bin/env python3
"""
Keeps the crate-visual registry honest against the weapon registry.

`LootService` builds a crate's body from `CrateVisuals`, keyed by the weapon's `Class`. Three
failures are possible and none of them throws at runtime:

  * a weapon with no `Class`, or a typo'd one, quietly falls through to the default block — the
    sidearm case simply never appears for that weapon and nothing says so
  * a `ByClass` entry no weapon uses: dead art nobody discovers is dead
  * a mesh visual with no `MeshId`/`TextureId`, or an empty/absurd `Size`

It also prints the geometry the clearance contract is derived from, so a size change is visible
here rather than only in a live arena.

    python tests/crate_visual_check.py

Exits non-zero when the two registries disagree.
"""

import math
import os
import re
import sys

WEAPONS_FILE = os.path.join("ReplicatedStorage", "Shared", "Weapons", "WeaponRegistry.lua")
VISUALS_FILE = os.path.join("ReplicatedStorage", "Shared", "Weapons", "CrateVisuals.lua")

CLASSES = ("Sidearm", "Primary", "Melee")
MAX_REASONABLE_STUDS = 100

ENTRY_RE = re.compile(r"\n\t(\w+) = \{\n(.*?)\n\t\}", re.S)
CLASS_RE = re.compile(r'\bClass\s*=\s*"([^"]+)"')
# `\b` matters: without it this matches the `Size =` inside `NaturalSize =` too, and every
# size the check reports would be the authored one instead of the shipping one.
VECTOR_RE = re.compile(
    r"\bSize\s*=\s*Vector3\.new\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)"
)
LIFT_RE = re.compile(r"CrateVisuals\.UndersideLift\s*=\s*([-\d.]+)")
NATURAL_RE = re.compile(
    r"NaturalSize\s*=\s*Vector3\.new\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)"
)
UNIFORM_TOLERANCE = 0.01  # the shipping size may be 1% off a clean multiple of the mesh


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def table_body(source, marker):
    """Inner text of `<marker>{ ... }`, brace-matched. None when the marker is absent."""
    start = source.find(marker)
    if start == -1:
        return None
    depth = 0
    for index in range(start + len(marker) - 1, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start + len(marker):index]
    return None


def entries(body):
    """One-tab-deep entries of a table body: key -> inner text."""
    return {match.group(1): match.group(2) for match in ENTRY_RE.finditer(body)}


def size_of(body, pattern=VECTOR_RE):
    match = pattern.search(body)
    if not match:
        return None
    return tuple(float(match.group(index)) for index in (1, 2, 3))


def main():
    for path in (WEAPONS_FILE, VISUALS_FILE):
        if not os.path.isfile(path):
            print(f"FAIL: missing {path}")
            return 1

    weapons_source = read(WEAPONS_FILE)
    visuals_source = read(VISUALS_FILE)

    profiles_body = table_body(weapons_source, "Weapons.Profiles = {")
    by_class_body = table_body(visuals_source, "CrateVisuals.ByClass = {")
    default_body = table_body(visuals_source, "CrateVisuals.Default = {")
    if profiles_body is None or by_class_body is None or default_body is None:
        print("FAIL: could not parse the registries (format changed?)")
        return 1

    profiles = entries(profiles_body)
    if not profiles:
        print("FAIL: no weapon profiles parsed (format changed?)")
        return 1

    visuals = entries(by_class_body)
    default_size = size_of(default_body)
    lift_match = LIFT_RE.search(visuals_source)
    lift = float(lift_match.group(1)) if lift_match else None

    pool_match = re.search(r"Weapons\.CratePool\s*=\s*\{([^}]*)\}", weapons_source)
    pool = re.findall(r'"([^"]+)"', pool_match.group(1)) if pool_match else []

    failures = []
    grouped = {}

    # Every weapon must declare a class, or it silently gets the default crate.
    for weapon, body in sorted(profiles.items()):
        found = CLASS_RE.search(body)
        grouped.setdefault(found.group(1) if found else "?", []).append(weapon)
        if not found:
            failures.append(f"{weapon}: no Class - it will build the default crate by accident")
        elif found.group(1) not in CLASSES:
            failures.append(
                f"{weapon}: Class \"{found.group(1)}\" is not one of {'/'.join(CLASSES)} "
                f"- it will fall through to the default crate"
            )

    # Every crate-pool weapon must be a real profile, or the pool can hand out a crate for nothing.
    for weapon in pool:
        if weapon not in profiles:
            failures.append(f"CratePool lists \"{weapon}\", which has no profile")

    # Every visual must be reachable, and every mesh visual must be complete.
    for name, body in sorted(visuals.items()):
        if name not in grouped:
            failures.append(f"CrateVisuals.ByClass.{name}: no weapon declares this class - dead art")
        size = size_of(body)
        if size is None:
            failures.append(f"CrateVisuals.ByClass.{name}: no Size")
        elif any(component <= 0 or component > MAX_REASONABLE_STUDS for component in size):
            failures.append(
                f"CrateVisuals.ByClass.{name}: Size {size} is not sane "
                f"(positive, under {MAX_REASONABLE_STUDS} studs)"
            )
        if not re.search(r"MeshId\s*=\s*\"rbxassetid://\d+\"", body):
            failures.append(f"CrateVisuals.ByClass.{name}: no MeshId")
        if not re.search(r"TextureId\s*=\s*\"rbxassetid://\d+\"", body):
            failures.append(f"CrateVisuals.ByClass.{name}: no TextureId")

        # The shipping box has to be a uniform multiple of the mesh as authored. A non-uniform
        # stretch distorts every bracket and seam on a boxy prop at once, and at runtime it looks
        # like the model was bad rather than the numbers.
        natural = size_of(body, NATURAL_RE)
        if natural is None:
            failures.append(
                f"CrateVisuals.ByClass.{name}: no NaturalSize - the authored mesh size is what "
                f"`Size` must be a clean multiple of"
            )
        elif any(component <= 0 for component in natural):
            failures.append(f"CrateVisuals.ByClass.{name}: NaturalSize {natural} is not positive")
        elif size:
            factors = [size[index] / natural[index] for index in range(3)]
            spread = max(factors) - min(factors)
            if spread / max(factors) > UNIFORM_TOLERANCE:
                failures.append(
                    f"CrateVisuals.ByClass.{name}: Size is not a uniform multiple of NaturalSize "
                    f"(x{factors[0]:.3f} / x{factors[1]:.3f} / x{factors[2]:.3f}) - "
                    f"a non-uniform stretch distorts the whole mesh"
                )

    if default_size is None:
        failures.append("CrateVisuals.Default: no Size")
    if "MeshId" in default_body:
        failures.append("CrateVisuals.Default: should be a Part, but declares a MeshId")
    if lift is None or lift <= 0:
        failures.append("CrateVisuals.UndersideLift: missing or not positive")

    # What the clearance contract will actually use.
    if default_size:
        largest = list(default_size)
        for body in visuals.values():
            size = size_of(body)
            if size:
                largest = [max(a, b) for a, b in zip(largest, size)]
        half_diagonal = math.sqrt(sum((component / 2) ** 2 for component in largest))
        print(f"{len(profiles)} weapon profile(s), {len(pool)} in the crate pool")
        print(f"  largest crate: {largest[0]:.3f} x {largest[1]:.3f} x {largest[2]:.3f} studs")
        print(f"  ArenaValidator uses it as a {half_diagonal:.2f}-stud half-diagonal clearance")
        if lift:
            print(f"  crate origin sits {largest[1] / 2 + lift:.2f} studs above its loot point")

    for name in sorted(grouped):
        crate = "default block"
        if name in visuals:
            natural = size_of(visuals[name], NATURAL_RE)
            factor = f" x{size_of(visuals[name])[1] / natural[1]:.3f}" if natural else ""
            crate = f"meshed case{factor}"
        print(f"  {name} -> {crate}: {', '.join(grouped[name])}")

    if failures:
        print(f"\n{len(failures)} problem(s):")
        for line in failures:
            print(f"  - {line}")
        return 1

    print("\nOK: every weapon has a class, and every crate visual is reachable and complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
