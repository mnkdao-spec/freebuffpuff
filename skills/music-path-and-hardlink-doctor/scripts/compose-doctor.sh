#!/usr/bin/env bash
# compose-doctor.sh - READ-ONLY diagnosis of Docker Compose mounts, ids and hardlink feasibility.
# Changes nothing. Never runs docker compose up/down.
# Usage: compose-doctor.sh [docker-compose.yml] [--json]
set -uo pipefail

if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "compose-doctor: needs python (or set PYTHON=)." >&2; exit 2; fi
FILE=""; MODE=""
for a in "$@"; do
  case "$a" in
    --json) MODE="--json" ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*) echo "compose-doctor: unknown flag: $a" >&2; exit 2 ;;
    *) [ -z "$FILE" ] && FILE="$a" ;;
  esac
done
FILE="${FILE:-docker-compose.yml}"
[ -f "$FILE" ] || { echo "compose-doctor: no such file: $FILE" >&2; exit 2; }

RESOLVED=""
if command -v docker >/dev/null 2>&1 && [ -z "${COMPOSE_DOCTOR_NO_DOCKER:-}" ]; then
  RESOLVED="$(docker compose -f "$FILE" config --format json 2>/dev/null || true)"
fi

"$PY" - "$FILE" "$RESOLVED" "$MODE" <<'PY'
import json, os, re, sys
path, resolved_raw, mode = sys.argv[1], sys.argv[2], sys.argv[3]
findings, notes = [], []

def add(level, msg): findings.append((level, msg))

svcs = {}
if resolved_raw.strip():
    try:
        svcs = json.loads(resolved_raw).get("services", {})
        notes.append("source: `docker compose config --format json` (fully resolved)")
    except Exception as e:
        notes.append("resolved config unparsable: %s" % e)
if not svcs:
    try:
        import yaml
        with open(path) as fh:
            svcs = (yaml.safe_load(fh) or {}).get("services", {}) or {}
        notes.append("source: raw YAML via pyyaml (NOT resolved)")
    except Exception:
        text = open(path).read()
        svcs = {m.group(1): {} for m in re.finditer(r'^  ([A-Za-z0-9_.-]+):\\s*$', text, re.M)}
        notes.append("source: regex service-name scan only. Install pyyaml or use docker.")

mounts, ids = {}, {}
for name, s in svcs.items():
    vols = []
    for v in (s.get("volumes") or []):
        if isinstance(v, dict):
            src, tgt = v.get("source", ""), v.get("target", "")
            ro = v.get("read_only", False); typ = v.get("type", "bind")
        else:
            parts = str(v).split(":")
            src, tgt = (parts[0], parts[1]) if len(parts) > 1 else ("", parts[0])
            ro = len(parts) > 2 and "ro" in parts[2]; typ = "bind"
        vols.append((src, tgt, ro, typ))
    mounts[name] = vols
    env = s.get("environment") or {}
    if isinstance(env, list):
        env = dict(re.split(r"=", e, 1) for e in env if "=" in e)
    ids[name] = {k: env.get(k) for k in ("PUID", "PGID", "UMASK", "SLSKD_UMASK", "user")}

by_src = {}
for name, vols in mounts.items():
    for src, tgt, ro, typ in vols:
        if src and not src.startswith("/"):
            continue
        by_src.setdefault(src, []).append((name, tgt, ro))
for src, uses in sorted(by_src.items()):
    targets = {t for _, t, _ in uses}
    if len(targets) > 1:
        detail = ", ".join("%s:%s" % (n, t) for n, t, _ in uses)
        add("WARN", "host path %s at %d different container paths (%s)." % (src, len(targets), detail))

for name, vols in mounts.items():
    for src, tgt, ro, typ in vols:
        if typ and typ != "bind":
            add("INFO", "%s: volume %s type=%s at %s. Hardlinks to bind mounts impossible." % (name, src or "-", typ, tgt))

def _dev(p):
    try: return os.stat(p).st_dev
    except OSError: return None

_dl = sorted({src for v in mounts.values() for src, tgt, ro, typ in v
              if src and typ == "bind" and re.search(r'/(downloads|download|staging|incomplete|temp)/?$', src)})
_lib = sorted({src for v in mounts.values() for src, tgt, ro, typ in v
               if src and typ == "bind" and re.search(r'/(media|music|library)/?$', src)})
for a_path in _dl:
    for b_path in _lib:
        if a_path == b_path: continue
        da, db = _dev(a_path), _dev(b_path)
        if da is None or db is None:
            add("INFO", "hardlinks %s vs %s uncheckable here; verify with stat inside containers." % (a_path, b_path))
        elif da != db:
            add("WARN", "%s (dev %s) vs %s (dev %s): DIFFERENT filesystems, no hardlinks." % (a_path, da, b_path, db))
        else:
            add("OK", "%s and %s same filesystem (dev %s): hardlinks possible." % (a_path, b_path, da))

puids = {v.get("PUID") for v in ids.values() if v.get("PUID")}
pgids = {v.get("PGID") for v in ids.values() if v.get("PGID")}
if len(puids) > 1:
    add("WARN", "multiple PUID values: %s." % sorted(puids))
if len(pgids) > 1:
    add("WARN", "multiple PGID values: %s." % sorted(pgids))
for name, v in ids.items():
    if v.get("SLSKD_UMASK"):
        add("INFO", "%s uses SLSKD_UMASK (not PUID/PGID convention)." % name)

for name, s in svcs.items():
    if str(s.get("network_mode", "")).startswith("service:"):
        notes.append("%s uses network_mode %s: no own ports; publish on VPN container." % (name, s["network_mode"]))

if mode == "--json":
    print(json.dumps({"tool": "compose-doctor", "file": os.path.abspath(path),
                      "findings": [{"level": l, "message": m} for l, m in findings],
                      "notes": notes}, indent=2))
else:
    print("compose-doctor: %s" % os.path.abspath(path))
    for n in notes: print("  note: %s" % n)
    if not findings:
        print("  no structural findings.")
    for level, msg in findings:
        print("  [%s] %s" % (level, msg))
    print("  services: %s" % (", ".join(sorted(svcs)) if svcs else "(none parsed)"))
PY
[ "$MODE" = "--json" ] || echo "compose-doctor: read-only; nothing was changed."
