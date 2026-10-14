#!/usr/bin/env bash
# slskd-doctor.sh - READ-ONLY slskd API probe. Changes no state; only issues GET requests.
# Requires: SLSKD_URL (default http://localhost:5030) and SLSKD_API_KEY.
# A 401/403/404 is reported per probe and is not fatal - endpoint availability varies by version.
set -uo pipefail

# Resolve a Python interpreter once. Windows and Git Bash often have `python` but not
# `python3`; honours $PYTHON so you can force a specific one.
if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "slskd-doctor: needs "$PY" (or python). Set PYTHON=/path/to/python." >&2; exit 2; fi
BASE="${SLSKD_URL:-http://localhost:5030}"
KEY="${SLSKD_API_KEY:-}"
if [ -z "$KEY" ]; then
  echo "slskd-doctor: SLSKD_API_KEY is not set. Export a READ-ONLY key (not the admin key)." >&2
  exit 2
fi
probe() {
  local path="$1" desc="$2"
  local out code
  out="$(curl -sS -m 10 -o /tmp/.slskd-body -w '%{http_code}' -H "X-API-Key: $KEY" "$BASE$path" 2>/dev/null)"
  code="${out:-000}"
  printf '  %-34s %-4s %s\n' "$path" "$code" "$desc"
  if [ "$code" = "200" ]; then
    head -c 400 /tmp/.slskd-body | "$PY" -c 'import json,sys;d=sys.stdin.read();
try: print("      ->", json.dumps(json.loads(d))[:300])
except Exception: print("      ->", d.replace("\n"," ")[:200])' 2>/dev/null || true
  fi
}
echo "slskd-doctor: $BASE (read-only GETs only)"
probe /api/v0/session    "current session / user"
probe /api/v0/application "app state + version"
probe /api/v0/server     "Soulseek server connection state"
probe /api/v0/shares     "configured shares (are you sharing?)"
probe /api/v0/transfers/downloads "download transfer counts"
probe /api/v0/transfers/uploads   "upload transfer counts"
echo
echo "Interpretation (read-only, no changes made):"
echo "  * /api/v0/server should show a connected/LoggedIn state. If not, the client is offline."
echo "  * Nothing here proves your Soulseek listening port is reachable from outside. Search"
echo "    results and browsing other users can be unreliable when that port is not forwarded,"
echo "    and a misconfigured forward also affects downloads."
echo "  * Shares are PUBLIC. Confirm you are sharing a dedicated folder and not /data, your home"
echo "    directory or a whole drive."
echo "  * If you exposed the web UI/API beyond localhost, that is a finding to report to the human."
