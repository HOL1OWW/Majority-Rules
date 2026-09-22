#!/usr/bin/env python3
"""
Keeps the EffectIcons lexicons honest against the modifier registry.

The ballot renders one chip per `Effects` token a modifier declares, and each chip needs
two things to be useful:

  * art   — an entry in EffectIcons.ASSET (an asset id) or EffectIcons.EMOJI (fallback)
  * words — an entry in EffectIcons.HELP (the hover tooltip line)

A modifier that declares a token with no art renders nothing; with no HELP it hovers to
nothing. Both are silent failures at runtime, which is exactly why this check exists.

    python tests/effect_help_check.py

Exits non-zero when a token a modifier declares has no art or no tooltip.
"""

import os
import re
import sys

MODIFIERS_DIR = os.path.join("ReplicatedStorage", "Shared", "Modifiers")
ICONS_FILE = os.path.join(
    "StarterPlayer", "StarterPlayerScripts", "MajorityRulesClient", "UI", "EffectIcons.lua"
)

EFFECTS_RE = re.compile(r"Effects\s*=\s*\{([^}]*)\}", re.S)
QUOTED_RE = re.compile(r'"([^"]+)"')


def declared_tokens():
    """token -> set of modifier ids that declare it"""
    tokens = {}
    for root, _dirs, files in os.walk(MODIFIERS_DIR):
        for name in files:
            if not name.endswith(".lua"):
                continue
            path = os.path.join(root, name)
            with open(path, "r", encoding="utf-8") as handle:
                text = handle.read()
            if "Effects" not in text:
                continue
            for match in EFFECTS_RE.finditer(text):
                for token in QUOTED_RE.findall(match.group(1)):
                    tokens.setdefault(token, set()).add(name)
    return tokens


def lexicon_keys(source, table_name):
    """Keys of `EffectIcons.<table_name> = { ... }` (top-level entries only)."""
    marker = f"EffectIcons.{table_name} = {{"
    start = source.find(marker)
    if start == -1:
        return set()
    depth = 0
    body = []
    for char in source[start + len(marker) - 1:]:
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
        body.append(char)
    body = "".join(body)
    return set(re.findall(r"(\w+)\s*=", body))


def main():
    if not os.path.isfile(ICONS_FILE):
        print(f"FAIL: missing {ICONS_FILE}")
        return 1

    with open(ICONS_FILE, "r", encoding="utf-8") as handle:
        source = handle.read()

    emoji = lexicon_keys(source, "EMOJI")
    help_text = lexicon_keys(source, "HELP")
    asset = lexicon_keys(source, "ASSET")
    alias = lexicon_keys(source, "ALIAS")

    if not emoji:
        print("FAIL: could not parse EMOJI lexicon (format changed?)")
        return 1
    if not help_text:
        print("FAIL: could not parse HELP lexicon (format changed?)")
        return 1
    if not asset:
        print("FAIL: could not parse ASSET lexicon (format changed?)")
        return 1

    declared = declared_tokens()
    failures = []

    for token in sorted(declared):
        has_art = token in emoji or token in asset or (token in alias and alias[token] in emoji)
        if not has_art:
            failures.append(
                f"{token}: no art — add it to EffectIcons.EMOJI or EffectIcons.ASSET "
                f"(used by {', '.join(sorted(declared[token]))})"
            )
        if token not in help_text:
            failures.append(
                f"{token}: no tooltip — add a line to EffectIcons.HELP "
                f"(used by {', '.join(sorted(declared[token]))})"
            )

    covered = sum(1 for t in declared if t in help_text)
    print(f"{len(declared)} effect token(s) declared by modifiers")
    print(f"  {covered} with tooltip copy, {len(help_text)} HELP entries total")
    print(f"  {len(asset)} with an asset slot, {len(emoji)} with emoji art")

    unused = sorted(set(help_text) - set(declared))
    if unused:
        print(f"  note: HELP entries no modifier uses yet: {', '.join(unused)}")

    if failures:
        print(f"\n{len(failures)} problem(s):")
        for line in failures:
            print(f"  - {line}")
        return 1

    print("\nOK: every declared effect token has art and a tooltip line.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
