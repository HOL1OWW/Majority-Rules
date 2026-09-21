#!/usr/bin/env python3
"""
Is the place in Roblox Studio running exactly the scripts that are in this repository?

The place and the code directories are two copies of the same ~64 modules, and they drift
silently. A script
edited in Studio without Ctrl+S never existed anywhere else. A `.lua` file added outside a mapped
directory in
directory the project file does not map is never synced. A script created in Studio has no file at
all. In every one of those cases the game runs something the repository cannot account for, and the
symptom is a fix that "does not work" even though the code is correct.

This hashes every script on both sides and names the paths that differ. Nothing is written and
nothing is changed.

Usage — the place is only readable from inside Studio, so there are two halves:

  1. In Studio, run `tests/studio_hashes.luau` (an agent does this with the Studio MCP
     `execute_luau` tool) and save the returned text to `.sync-audit/place.txt`.
  2. py tests/sync_audit.py --place-dump .sync-audit/place.txt

`py` is the Windows launcher; on other machines use `python3`. Exit code 1 means the two sides
disagree, 0 means they agree, so it works as a check.

The instance paths are derived from `default.project.json` rather than hard-coded, so moving
`ReplicatedStorage/Shared` somewhere else in the tree does not silently break the audit.
"""

import argparse
import json
import os
import sys

HASH_BASE = 5381
HASH_MULTIPLIER = 33
HASH_MODULUS = 2 ** 32
SCRIPT_SUFFIXES = (".lua", ".luau")
LUAU_SNIPPET = os.path.join("tests", "studio_hashes.luau")


def djb2(data):
    """Identical to djb2() in tests/studio_hashes.luau — change one, change both."""
    value = HASH_BASE
    for byte in data:
        value = (value * HASH_MULTIPLIER + byte) % HASH_MODULUS
    return value


def parse_script_file(filename):
    """
    Apply Rojo's file-to-instance rules.

    `SpeedBoost.lua` -> "SpeedBoost", `Bootstrap.server.lua` -> "Bootstrap",
    `init.lua` -> "init" (the file *is* the folder's instance). Returns None for
    anything that is not a script — `.meta.json`, `.model.json`, `.rbxmx` and so on.
    """
    stem = filename
    for suffix in SCRIPT_SUFFIXES:
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    else:
        return None

    for variant in (".server", ".client"):
        if stem.endswith(variant):
            stem = stem[: -len(variant)]
            break

    return stem


def collect_mappings(node, prefix, found):
    """Walk the project tree collecting (`$path` directory, instance prefix) pairs."""
    if not isinstance(node, dict):
        return

    if "$path" in node:
        found.append((node["$path"], prefix))

    for key, value in node.items():
        if key.startswith("$"):
            continue
        child_prefix = key if not prefix else prefix + "." + key
        collect_mappings(value, child_prefix, found)


def read_source(path):
    """Return (source bytes with LF endings, whether CRLF was present)."""
    with open(path, "rb") as handle:
        data = handle.read()
    crlf = b"\r\n" in data
    return data.replace(b"\r\n", b"\n"), crlf


def repo_scripts(root, project_path):
    """Map every script file in a mapped directory to its instance path."""
    with open(project_path, encoding="utf-8") as handle:
        project = json.load(handle)

    mappings = []
    collect_mappings(project.get("tree", {}), "", mappings)

    scripts = {}
    mapped_dirs = []
    for relative_dir, prefix in mappings:
        directory = os.path.normpath(os.path.join(root, relative_dir))
        mapped_dirs.append(directory)
        if not os.path.isdir(directory):
            print("WARNING project file maps %s, which does not exist" % relative_dir)
            continue

        for base, _dirs, names in os.walk(directory):
            for name in sorted(names):
                stem = parse_script_file(name)
                if stem is None:
                    continue
                relative = os.path.relpath(os.path.join(base, name), directory)
                parts = relative.replace("\\", "/").split("/")
                folders = parts[:-1]
                segments = folders if stem == "init" else folders + [stem]
                instance = prefix if not segments else prefix + "." + ".".join(segments)
                scripts[instance] = os.path.join(base, name)

    return scripts, mapped_dirs


def unmapped_scripts(root, mapped_dirs):
    """Script files under the code directories that the project file would never sync."""
    source_dirs = (
        "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer",
    )
    found = []
    for source_dir in source_dirs:
      for base, _dirs, names in os.walk(os.path.join(root, source_dir)):
        base = os.path.normpath(base)
        if any(base == mapped or base.startswith(mapped + os.sep) for mapped in mapped_dirs):
            continue
        for name in sorted(names):
            if parse_script_file(name) is not None:
                found.append(os.path.join(base, name))
    return found


def read_dump(path):
    """Parse the `<InstancePath>\t<hash>` output of tests/studio_hashes.luau."""
    entries = {}
    skipped = []
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            line = line.strip().lstrip("\ufeff")
            if not line:
                continue
            instance, separator, raw_hash = line.rpartition("\t")
            if not separator:
                skipped.append((number, line))
                continue
            try:
                entries[instance.strip()] = int(raw_hash.strip())
            except ValueError:
                skipped.append((number, line))
    return entries, skipped


def report(studio, repo, files, root, skipped, crlf_files, unmapped):
    def show(path):
        try:
            return os.path.relpath(path, root).replace("\\", "/")
        except ValueError:
            return path

    matched = []
    differ = []
    for instance in sorted(set(studio) & set(repo)):
        if studio[instance] == repo[instance]:
            matched.append(instance)
        else:
            differ.append(instance)
    only_studio = sorted(set(studio) - set(repo))
    only_repo = sorted(set(repo) - set(studio))

    for instance in differ:
        print("DIFFERS         %s" % instance)
        print("                place %d" % studio[instance])
        print("                repo  %d   (%s)" % (repo[instance], show(files[instance])))

    for instance in only_studio:
        print("ONLY IN STUDIO  %s" % instance)
    for instance in only_repo:
        print("ONLY ON DISK    %s   (%s)" % (instance, show(files[instance])))
    for path in unmapped:
        print("NOT MAPPED      %s   (the project file never syncs this file)" % show(path))
    for number, line in skipped:
        print("UNREADABLE LINE dump line %d: %r" % (number, line))
    for path in crlf_files:
        print("NOTE            %s has CRLF endings; Studio's Source is LF" % show(path))

    if differ or only_studio or only_repo:
        verdict = "DO NOT MATCH"
    else:
        verdict = "match"

    print(
        "\n%d compared . %d match . %d differ . %d only in Studio . %d only on disk"
        % (len(matched) + len(differ), len(matched), len(differ), len(only_studio), len(only_repo))
    )
    print("place and repo %s" % verdict)

    return 1 if differ or only_studio or only_repo else 0


def main(argv=None):
    root_default = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parser = argparse.ArgumentParser(
        description="Compare every script in the Studio place against its file in this repository."
    )
    parser.add_argument("--place-dump", help="file holding the output of tests/studio_hashes.luau")
    parser.add_argument("--project", help="project file (default: <root>/default.project.json)")
    parser.add_argument("--root", default=root_default, help="repository root")
    parser.add_argument(
        "--print-luau",
        action="store_true",
        help="print the snippet to run in Studio, then exit",
    )
    args = parser.parse_args(argv)

    if args.print_luau:
        with open(os.path.join(args.root, LUAU_SNIPPET), encoding="utf-8") as handle:
            sys.stdout.write(handle.read())
        return 0

    if not args.place_dump:
        parser.error("--place-dump is required (or use --print-luau)")

    project_path = args.project or os.path.join(args.root, "default.project.json")
    repo, mapped_dirs = repo_scripts(args.root, project_path)
    repo_hashes = {}
    crlf_files = []
    for instance, path in repo.items():
        source, crlf = read_source(path)
        repo_hashes[instance] = djb2(source)
        if crlf:
            crlf_files.append(path)

    studio, skipped = read_dump(args.place_dump)
    unmapped = unmapped_scripts(args.root, mapped_dirs)

    return report(studio, repo_hashes, repo, args.root, skipped, crlf_files, unmapped)


if __name__ == "__main__":
    sys.exit(main())
