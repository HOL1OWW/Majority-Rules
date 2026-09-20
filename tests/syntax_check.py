#!/usr/bin/env python3
"""
Crude Luau structure checker, used until the proper toolchain (Rokit + styLua + luau-lsp)
is installed.

It is not a parser. It catches the class of mistake that actually happens when writing Luau
by hand and by machine: unbalanced `function/if/for/while/do/end/repeat/until`, unbalanced
brackets, unterminated strings and unterminated long strings/comments.

    python tests/syntax_check.py src
"""

import os
import re
import sys

KEYWORDS = {
    "function", "if", "for", "while", "do", "repeat", "end", "until",
    "then", "else", "elseif", "return", "local", "and", "or", "not",
}


def strip_code(text):
    """Replace comments and string contents with spaces, keeping newlines."""
    out = []
    i = 0
    n = len(text)
    long_depth = 0
    in_string = None
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if long_depth:
            if ch == "]" and text[i:i + long_depth * 2] == "]" * long_depth * 2:
                i += long_depth * 2
                long_depth = 0
                continue
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue

        if in_string:
            if ch == "\\":
                out.append("  ")
                i += 2
                continue
            if ch == in_string:
                in_string = None
            out.append("\n" if ch == "\n" else " ")
            i += 1
            continue

        if ch == "-" and nxt == "-":
            eq = 0
            while text[i + 2 + eq:i + 3 + eq] == "=":
                eq += 1
            opener = "[" + "=" * eq + "["
            if text[i + 2:i + 2 + len(opener)] == opener:
                long_depth = eq + 1
                i += 2 + len(opener)
                continue
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue

        if ch == "[":
            eq = 0
            while text[i + 1 + eq:i + 2 + eq] == "=":
                eq += 1
            opener = "[" + "=" * eq + "["
            if text[i:i + len(opener)] == opener:
                long_depth = eq + 1
                i += len(opener)
                continue

        if ch in "\"'":
            in_string = ch
            out.append(" ")
            i += 1
            continue

        out.append(ch)
        i += 1

    if in_string or long_depth:
        return None
    return "".join(out)


def check(path):
    problems = []
    with open(path, "r", encoding="utf-8") as handle:
        raw = handle.read()

    code = strip_code(raw)
    if code is None:
        return ["unterminated string or long string/comment"]

    tokens = re.finditer(r"[A-Za-z_][A-Za-z0-9_]*|[-+*/%^#=~<>(){}[\]:;.,]", code)

    stack = []
    brackets = []
    for token in tokens:
        value = token.group(0)
        line = code.count("\n", 0, token.start()) + 1

        if value in KEYWORDS:
            if value == "do":
                # `for ... do` and `while ... do` share one `end` with the loop keyword.
                if stack and stack[-1]["kind"] in ("for", "while") and stack[-1]["pending_do"]:
                    stack[-1]["pending_do"] = False
                else:
                    stack.append({"kind": "do", "line": line, "pending_do": False})
            elif value in ("function", "if", "for", "while", "repeat"):
                stack.append({"kind": value, "line": line, "pending_do": value in ("for", "while")})
            elif value == "end":
                if not stack:
                    problems.append("line %d: 'end' with nothing open" % line)
                else:
                    entry = stack.pop()
                    if entry["kind"] == "repeat":
                        problems.append(
                            "line %d: 'end' closing a 'repeat' opened on line %d" % (line, entry["line"]))
            elif value == "until":
                if stack and stack[-1]["kind"] == "repeat":
                    stack.pop()
                else:
                    problems.append("line %d: 'until' without a matching 'repeat'" % line)
            continue

        if value in "([{":
            brackets.append((value, line))
        elif value in ")]}":
            pairs = {")": "(", "]": "[", "}": "{"}
            if not brackets:
                problems.append("line %d: unmatched '%s'" % (line, value))
            else:
                opener, opened_at = brackets.pop()
                if opener != pairs[value]:
                    problems.append(
                        "line %d: '%s' closing '%s' opened on line %d" % (line, value, opener, opened_at))

    for entry in stack:
        problems.append("line %d: '%s' is never closed" % (entry["line"], entry["kind"]))
    for opener, opened_at in brackets:
        problems.append("line %d: '%s' is never closed" % (opened_at, opener))

    return problems


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "src"
    files = []
    for directory, _dirs, names in os.walk(root):
        for name in sorted(names):
            if name.endswith(".lua"):
                files.append(os.path.join(directory, name))

    failures = 0
    for path in sorted(files):
        problems = check(path)
        if problems:
            failures += 1
            print("FAIL %s" % path)
            for problem in problems:
                print("     %s" % problem)

    print("\n%d file(s) checked, %d with problems" % (len(files), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
