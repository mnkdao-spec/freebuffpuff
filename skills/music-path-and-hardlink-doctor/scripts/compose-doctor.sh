#!/usr/bin/env bash
# compose-doctor.sh - READ-ONLY diagnosis of Docker Compose mounts, ids and hardlink feasibility.
# Changes nothing. Never runs docker compose up/down. Exit 0 always (findings are output, not errors).
#
# Usage: compose-doctor.sh [docker-compose.yml] [--json]
#          --json prints ONE JSON object and nothing else (machine-readable), like the pack's
#          other scripts. Text mode prints the human report.
set -uo pipefail

# Resolve a Python interpreter once. Windows and Git Bash often have `python` but not
# `python3`; honours $PYTHON so you can force a specific one.
if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "compose-doctor: needs python3 (or python). Set PYTHON=/path/to/python." >&2; exit 2; fi
# Flags in any order, like the other scripts in this pack (compose-doctor.sh --json FILE works).
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
        import yaml  # type: ignore
        with open(path) as fh:
            svcs = (yaml.safe_load(fh) or {}).get("services", {}) or {}
        notes.append("source: raw YAML via pyyaml (NOT resolved - env vars unsubstituted)")
    except Exception:
        text = open(path).read()
        svcs = {m.group(1): {} for m in re.finditer(r'^  ([A-Za-z0-9_.-]+):\s*$', text, re.M)}
        notes.append("source: regex service-name scan only (no yaml module). Install pyyaml or use docker.")

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

# 1. same host dir -> different container paths across services (breaks consistent pathing)
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
        add("WARN", "host path %s is mounted at %d different container paths (%s). "
                    "Path mismatches between slskd-reported and Lidarr-visible paths are the "
                    "usual cause of 'album never imports'." % (src, len(targets), detail))

# 2. shared download/library root: do the music services agree on one /data?
data_users = {n: {t for _, t, _, _ in v if t.startswith("/data")} for n, v in mounts.items()}
n_with = sum(1 for v in data_users.values() if v)
if n_with >= 2:
    notes.append("services mounting under /data: %s" % ", ".join(sorted(n for n, v in data_users.items() if v)))

# 3. hardlink feasibility notes
for name, vols in mounts.items():
    for src, tgt, ro, typ in vols:
        if typ and typ != "bind":
            add("INFO", "%s: volume %s is type=%s (named volume) mounted at %s. Hardlinks between "
                        "a named volume and a bind mount are not possible; Lidarr will copy." % (name, src or "-", typ, tgt))
        if re.match(r'^(\\\\|[A-Za-z]:[\\\\/])', src) or ":" in src and "//" in src:
            add("INFO", "%s: %s looks like a remote/UNC path. Hardlink and atomic-move support "
                        "depends on the server and mount; verify before relying on it." % (name, src))
# 3b. hardlink precondition: are the download root and the library root ONE filesystem?
#     "Use Hardlinks Instead of Copy" silently degrades to copy when they are not - and the
#     copy deletes the source, so the seeding torrent dies. Check it here when the host paths
#     are visible; otherwise say exactly how to check it where they are (inside the container).
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
            add("INFO", "hardlinks between %s and %s cannot be checked from here (path not visible "
                        "on this host). Verify where the files actually are: "
                        "docker compose exec <lidarr> stat -c '%%d %%n' <file under %s> and the same "
                        "file as <slskd> sees it under %s - equal device numbers are the precondition "
                        "for a hardlink." % (a_path, b_path, b_path, a_path))
        elif da != db:
            add("WARN", "%s (device %s) and %s (device %s) are on DIFFERENT filesystems. Lidarr cannot "
                        "hardlink across them: 'Use Hardlinks Instead of Copy' will fall back to copy "
                        "and delete the download, and a move can fail with 'Invalid cross-device link'. "
                        "Put the download root and the library root on one filesystem." % (a_path, da, b_path, db))
        else:
            add("OK", "%s and %s are on the same filesystem (device %s) - hardlinks are possible, so "
                      "Lidarr can import without copying." % (a_path, b_path, da))

# 4. uid/gid/umask coherence
puids = {v.get("PUID") for v in ids.values() if v.get("PUID")}
pgids = {v.get("PGID") for v in ids.values() if v.get("PGID")}
if len(puids) > 1:
    add("WARN", "multiple PUID values across services: %s. Mixed ownership is a common cause of "
                "'permission denied' on import." % sorted(puids))
if len(pgids) > 1:
    add("WARN", "multiple PGID values across services: %s." % sorted(pgids))
ser = {n: v.get("UMASK") for n, v in ids.items() if v.get("UMASK")}
if ser and len(set(ser.values())) > 1:
    add("WARN", "inconsistent UMASK values: %s. UMASK=002 (group-writable) is the Servarr "
                "recommendation when a shared group is used." % ser)
for name, v in ids.items():
    if v.get("SLSKD_UMASK"):
        add("INFO", "%s uses SLSKD_UMASK. slskd does not follow the Servarr PUID/PGID convention - "
                    "do not copy env vars between these images." % name)
    if v.get("user"):
        notes.append("%s sets user=%s" % (name, v["user"]))

# 5. dangerous patterns
for name, s in svcs.items():
    if str(s.get("network_mode", "")).startswith("service:"):
        notes.append("%s uses network_mode: %s - it has no ports of its own; publish ports on the "
                     "VPN container." % (name, s["network_mode"]))
    d = s.get("depends_on")
    if isinstance(d, dict) and any("condition" not in v for v in d.values() if isinstance(v, dict)):
        add("INFO", "%s depends_on without condition: service_healthy - ordering waits for start, "
                    "not readiness." % name)

if mode == "--json":
    # One JSON object and nothing else, so this is safe to pipe into jq.
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
