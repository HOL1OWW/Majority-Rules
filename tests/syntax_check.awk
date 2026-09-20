# Crude Luau structure checker, used until Rokit + stylua + luau-lsp are installed.
#
# It is not a parser. It strips comments and string literals, then verifies that every
# `function`, `if`, `for`, `while`, `do` and `repeat` is closed, and that brackets balance.
# That is the class of mistake that actually happens when Luau is written by hand or by an
# agent, and it is far better than no check at all.
#
#   for f in $(find src -name '*.lua'); do awk -f tests/syntax_check.awk "$f"; done

function rep(c, n,   s, k) {
  s = ""
  for (k = 0; k < n; k++) s = s c
  return s
}

function strip(src,   i, n, ch, nxt, out, inStr, longDepth, eq, opener, closer) {
  out = ""
  inStr = ""
  longDepth = 0
  i = 1
  n = length(src)
  while (i <= n) {
    ch = substr(src, i, 1)
    nxt = (i < n) ? substr(src, i + 1, 1) : ""

    if (longDepth > 0) {
      closer = rep("]", longDepth * 2)
      if (substr(src, i, longDepth * 2) == closer) {
        i += longDepth * 2
        longDepth = 0
        continue
      }
      out = out ((ch == "\n") ? "\n" : " ")
      i++
      continue
    }

    if (inStr != "") {
      if (ch == "\\") { out = out "  "; i += 2; continue }
      if (ch == inStr) inStr = ""
      out = out ((ch == "\n") ? "\n" : " ")
      i++
      continue
    }

    if (ch == "-" && nxt == "-") {
      eq = 0
      while (substr(src, i + 2 + eq, 1) == "=") eq++
      opener = "[" rep("=", eq) "["
      if (substr(src, i + 2, length(opener)) == opener) {
        longDepth = eq + 1
        i += 2 + length(opener)
        continue
      }
      while (i <= n && substr(src, i, 1) != "\n") { out = out " "; i++ }
      continue
    }

    if (ch == "[") {
      eq = 0
      while (substr(src, i + 1 + eq, 1) == "=") eq++
      opener = "[" rep("=", eq) "["
      if (substr(src, i, length(opener)) == opener) {
        longDepth = eq + 1
        i += length(opener)
        continue
      }
    }

    if (ch == "\"" || ch == "'") { inStr = ch; out = out " "; i++; continue }

    out = out ch
    i++
  }

  if (inStr != "" || longDepth > 0) return "@BAD"
  return out
}

function inspect(code,   rest, tok, ch, line, problems, depth, bdepth, stack, brackets, entry, kb, kb2, idx) {
  problems = ""
  depth = 0
  bdepth = 0
  line = 1
  rest = code

  while (length(rest) > 0) {
    if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*/)) {
      tok = substr(rest, 1, RLENGTH)
      rest = substr(rest, RLENGTH + 1)

      if (tok == "function" || tok == "if" || tok == "for" || tok == "while" || tok == "repeat") {
        stack[++depth] = tok "|" line
      } else if (tok == "do") {
        entry = (depth > 0) ? stack[depth] : ""
        split(entry, kb, "|")
        if ((kb[1] == "for" || kb[1] == "while") && kb[3] != "do") {
          stack[depth] = entry "|do"
        } else {
          stack[++depth] = "do|" line
        }
      } else if (tok == "end") {
        if (depth == 0) {
          problems = problems "  line " line ": 'end' with nothing open\n"
        } else {
          entry = stack[depth--]
          split(entry, kb2, "|")
          if (kb2[1] == "repeat") {
            problems = problems "  line " line ": 'end' closing a 'repeat' from line " kb2[2] "\n"
          }
        }
      } else if (tok == "until") {
        entry = (depth > 0) ? stack[depth] : ""
        split(entry, kb2, "|")
        if (kb2[1] == "repeat") {
          depth--
        } else {
          problems = problems "  line " line ": 'until' without a matching 'repeat'\n"
        }
      }
      continue
    }

    ch = substr(rest, 1, 1)
    if (ch == "\n") {
      line++
    } else if (ch == "(" || ch == "[" || ch == "{") {
      brackets[++bdepth] = ch "|" line
    } else if (ch == ")" || ch == "]" || ch == "}") {
      if (bdepth == 0) {
        problems = problems "  line " line ": unmatched '" ch "'\n"
      } else {
        entry = brackets[bdepth--]
        split(entry, kb2, "|")
        if ((kb2[1] == "(" && ch != ")") || (kb2[1] == "[" && ch != "]") || (kb2[1] == "{" && ch != "}")) {
          problems = problems "  line " line ": '" ch "' closing '" kb2[1] "' from line " kb2[2] "\n"
        }
      }
    }
    rest = substr(rest, 2)
  }

  for (idx = 1; idx <= depth; idx++) {
    split(stack[idx], kb2, "|")
    problems = problems "  line " kb2[2] ": '" kb2[1] "' is never closed\n"
  }
  for (idx = 1; idx <= bdepth; idx++) {
    split(brackets[idx], kb2, "|")
    problems = problems "  line " kb2[2] ": '" kb2[1] "' is never closed\n"
  }

  return problems
}

{ src = src "\n" $0 }

END {
  code = strip(src)
  if (code == "@BAD") {
    print "FAIL " FILENAME "  unterminated string or long string/comment"
  } else {
    problems = inspect(code)
    if (problems != "") {
      print "FAIL " FILENAME
      printf "%s", problems
    }
  }
}
