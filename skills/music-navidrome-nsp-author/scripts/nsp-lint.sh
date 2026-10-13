#!/usr/bin/env bash
# nsp-lint.sh - validate Navidrome smart-playlist (.nsp) JSON files. READ-ONLY; changes nothing.
# Usage: nsp-lint.sh file.nsp [more.nsp ...]
# Structure/vocabulary check only. It cannot know your library's contents.
set -uo pipefail

# Resolve a Python interpreter once. Windows and Git Bash often have `python` but not
# `python3`; honours $PYTHON so you can force a specific one.
if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "nsp-lint: needs "$PY" (or python). Set PYTHON=/path/to/python." >&2; exit 2; fi
[ $# -ge 1 ] || { echo "usage: nsp-lint.sh <file.nsp> [...]" >&2; exit 2; }
"$PY" - "$@" <<'PY'
import json, sys, re

# A rule node is { <operator>: { <field>: <value> }, ... "all"/"any": [ <rule nodes> ] }.
OPS = {"is","isNot","contains","notContains","gt","lt","gte","lte","inTheRange","inTheLast",
       "before","after","isMissing","isNotMissing","inPlaylist","notInPlaylist",
       "startsWith","endsWith","isNot","notInTheRange"}
GROUPS = {"all","any"}
TOP = {"name","all","any","sort","order","limit","limitPercent","refreshDelay","comment","owner","public"}
DUR = re.compile(r'^\s*\d+\s*(s|sec|m|min|h|d|w|mo|y)?\s*$')
SORT_FIELD = re.compile(r'^-?[A-Za-z][A-Za-z0-9_.]*$')

def check_node(node, path, problems, warns):
    """node must be a rule node."""
    if not isinstance(node, dict):
        problems.append((path, "rule must be an object, got %s" % type(node).__name__)); return
    keys = list(node)
    if not keys:
        problems.append((path, "empty rule")); return
    known = [k for k in keys if k in OPS or k in GROUPS]
    if not known:
        problems.append((path, "no rule operator; keys=%s (expected one of all/any/%s)"
                         % (keys, "/".join(sorted(OPS)[:6]) + "/..."))); return
    for k, v in node.items():
        if k in GROUPS:
            if not isinstance(v, list) or not v:
                problems.append(("%s.%s" % (path, k), "must be a non-empty array of rules")); continue
            for i, child in enumerate(v):
                check_node(child, "%s.%s[%d]" % (path, k, i), problems, warns)
        elif k in OPS:
            if not isinstance(v, dict) or not v:
                problems.append(("%s.%s" % (path, k), "operator value must be a non-empty {field: value} object"))
                continue
            for fld, val in v.items():
                if not isinstance(fld, str) or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', fld):
                    problems.append(("%s.%s" % (path, k), "suspicious field name %r" % (fld,)))
                if isinstance(val, (dict, list)):
                    problems.append(("%s.%s.%s" % (path, k, fld), "expected a scalar value, got %s" % type(val).__name__))
                if k == "inTheLast" and isinstance(val, str) and not DUR.match(val):
                    problems.append(("%s.%s.%s" % (path, k, fld), "inTheLast expects a duration like '30d', got %r" % (val,)))
                if k == "inTheRange" and isinstance(val, str) and "," not in val:
                    warns.append(("%s.%s.%s" % (path, k, fld), "inTheRange usually needs 'min,max', got %r" % (val,)))
        else:
            problems.append(("%s.%s" % (path, k), "unknown operator %r" % (k,)))

bad = 0
for fn in sys.argv[1:]:
    problems, warns = [], []
    try:
        data = json.load(open(fn))
    except Exception as e:
        print("%s: INVALID JSON: %s" % (fn, e)); bad += 1; continue
    if not isinstance(data, dict):
        print("%s: top level must be a JSON object" % fn); bad += 1; continue
    if not isinstance(data.get("name"), str) or not data.get("name").strip():
        problems.append(("name", "required: a non-empty string"))
    if not any(data.get(k) for k in GROUPS):
        problems.append(("all/any", "at least one rule group is required"))
    for k, v in data.items():
        if k not in TOP:
            warns.append(("top-level", "unknown key %r (Navidrome may ignore it)" % k)); continue
        if k in GROUPS:
            if not isinstance(v, list) or not v:
                problems.append((k, "must be a non-empty array of rules")); continue
            for i, child in enumerate(v):
                check_node(child, "%s[%d]" % (k, i), problems, warns)
    s = data.get("sort")
    if s is not None and not (isinstance(s, str) and s.strip() and all(SORT_FIELD.match(p.strip()) for p in s.split(","))):
        problems.append(("sort", "must be comma-separated field names ('-' prefix = descending), got %r" % (s,)))
    for k in ("limit", "limitPercent"):
        if k in data and not isinstance(data[k], (int, float)):
            problems.append((k, "expected a number, got %r" % (data[k],)))
    lp = data.get("limitPercent")
    if isinstance(lp, (int, float)) and not 0 < lp <= 100:
        warns.append(("limitPercent", "outside 0..100: %r" % lp))
    if "refreshDelay" in data and not (isinstance(data["refreshDelay"], str) and DUR.match(data["refreshDelay"])):
        problems.append(("refreshDelay", "expected a duration like '1d', got %r" % (data["refreshDelay"],)))
    n_rules = sum(len(data.get(k, []) or []) for k in GROUPS)
    print("%s: %d top-level rule(s), %d problem(s), %d warning(s)" % (fn, n_rules, len(problems), len(warns)))
    for p, m in problems: print("   PROBLEM %s: %s" % (p, m))
    for p, m in warns:    print("   warning %s: %s" % (p, m))
    if problems: bad += 1
sys.exit(1 if bad else 0)
PY
