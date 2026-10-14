#!/usr/bin/env bash
# mb-lookup.sh - READ-ONLY MusicBrainz lookups with enforced rate limiting.
# MusicBrainz requires <= 1 request/second per client and a meaningful User-Agent.
# This script serialises requests across processes sharing an IP, caches responses,
# and backs off on 503. It never writes to MusicBrainz. Its only writes are $CACHE (per-user,
# created 0700/0600) and the rate-limit state file; no other path is touched.
#
# Usage:
#   mb-lookup.sh whoami
#   mb-lookup.sh search-release-group "<artist>" "<album>"
#   mb-lookup.sh lookup release-group <mbid>
#   mb-lookup.sh lookup release <mbid>
#   mb-lookup.sh classify <mbid>          # is this a release, release-group or recording id?
#   mb-lookup.sh search-recording "<artist>" "<track>"
set -uo pipefail

# Resolve a Python interpreter once. Windows and Git Bash often have `python` but not
# `python3`; honours $PYTHON so you can force a specific one.
if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "mb-lookup: needs python3 (or python). Set PYTHON=/path/to/python." >&2; exit 2; fi

UA="${MB_USER_AGENT:-freebuff-homelab-pack/1.0 ( https://example.invalid/contact )}"
# The cache holds raw API responses, so it belongs in the user's own cache directory. The old
# default, /tmp/mb-cache, was a predictable world-writable path: any local user could plant a
# response under a key and this script would serve it as a cache hit. MB_CACHE_DIR overrides it.
CACHE="${MB_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/freebuff-homelab-pack/mb}"
# The rate-limit state is the opposite case: it is deliberately SHARED between processes on this
# host, because MusicBrainz limits per client IP and two concurrent agents must not each spend the
# 1 req/s budget. It holds one timestamp, it is validated before use, and MB_RATE_STATE overrides it.
STATE="${MB_RATE_STATE:-/tmp/.mb-last-request}"
MIN_INTERVAL="${MB_MIN_INTERVAL:-1.1}"
umask 077                                  # cache, state and the response scratch file stay private
mkdir -p "$CACHE"
# curl writes the body here rather than to the predictable, shareable /tmp/.mb-body: an attacker
# could pre-create that path as a symlink and have us overwrite a file we own. mktemp creates this
# one exclusively and inside $CACHE, and the trap removes it on every exit path.
BODY="$(mktemp "$CACHE/body.XXXXXX" 2>/dev/null || echo /dev/null)"
trap 'rm -f "$BODY"' EXIT

command -v curl >/dev/null || { echo "mb-lookup: curl required" >&2; exit 2; }
JQ="$(command -v jq || true)"
json() { if [ -n "$JQ" ]; then jq -c "$1"; else "$PY" -c "import json,sys;d=json.load(sys.stdin);print(json.dumps(eval(sys.argv[1].replace('|','.')) if False else d))"; fi; }

get() { # get <path-with-query>
  local url="https://musicbrainz.org/ws/2/$1" key body code tries=0
  if command -v md5sum >/dev/null 2>&1; then
    key="$(printf '%s' "$url" | md5sum | cut -d' ' -f1)"
  elif command -v md5 >/dev/null 2>&1; then          # macOS and some Git Bash installs
    key="$(printf '%s' "$url" | md5 -q)"
  else
    key="$(printf '%s' "$url" | "$PY" -c 'import hashlib,sys;print(hashlib.md5(sys.stdin.buffer.read()).hexdigest())')"
  fi
  if [ -s "$CACHE/$key.json" ]; then echo "  [cache] $url" >&2; cat "$CACHE/$key.json"; return 0; fi
  printf '%s\n' "$url" >&2
  while : ; do
    tries=$((tries+1))
    # enforce >= MIN_INTERVAL since the last request by ANY process using this state file
    if command -v flock >/dev/null 2>&1; then
      exec 9>"$STATE.lock"; flock 9
      if [ -f "$STATE" ]; then
        local last now wait
        last="$(cat "$STATE" 2>/dev/null || echo 0)"
        case "$last" in ''|*[!0-9]*) last=0 ;; esac   # a shared /tmp path: never trust its contents
        now="$(date +%s%N)"
        wait="$(awk -v n="$now" -v l="$last" -v m="$MIN_INTERVAL" 'BEGIN{w=(l+ m*1e9 - n)/1e9; if(w<0)w=0; printf "%.3f", w}')"
        if awk -v w="$wait" 'BEGIN{exit !(w>0.05)}'; then sleep "$wait"; fi
      fi
      date +%s%N > "$STATE"
      exec 9>&-
    else
      sleep "$MIN_INTERVAL"
    fi
    code="$(curl -sS -m 20 -H "User-Agent: $UA" -H 'Accept: application/json' \
            -o "$BODY" -w '%{http_code}' "$url")"
    body="$(cat "$BODY")"
    case "$code" in
      200) printf '%s' "$body" > "$CACHE/$key.json"; printf '%s' "$body"; return 0 ;;
      503) if [ "$tries" -ge 3 ]; then echo "mb-lookup: 503 from MusicBrainz after $tries attempts; it is throttling. Stop and wait." >&2; return 1; fi
           echo "  [503] backing off (attempt $tries)" >&2; sleep $((tries*3)); continue ;;
      404) echo "NOT FOUND (404): $url" >&2; return 4 ;;
      *)   echo "mb-lookup: HTTP $code from $url" >&2; printf '%s' "$body" | head -c 300 >&2; return 1 ;;
    esac
  done
}

enc() { "$PY" -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  whoami)
    echo "User-Agent sent to MusicBrainz:"; echo "  $UA"
    echo "Rate limit enforced: >= ${MIN_INTERVAL}s between requests, serialised via $STATE.lock"
    echo "If you are not https://example.invalid/contact, set MB_USER_AGENT to something that"
    echo "identifies you (app/version + a contact address) before running bulk lookups."
    ;;
  search-release-group)
    [ $# -ge 1 ] || { echo "usage: search-release-group <artist> [album]" >&2; exit 2; }
    q="artist:\"$1\""; [ "${2:-}" ] && q="$q AND releasegroup:\"$2\""
    get "release-group/?query=$(enc "$q")&fmt=json&limit=8" | "$PY" -c '
import json,sys
d=json.load(sys.stdin)
print("%-38s %-30s %-10s %s" % ("release-group mbid","title","type","artist"))
for rg in d.get("release-groups",[]):
    a=", ".join(x["artist"]["name"] for x in rg.get("artist-credit",[]) if "artist" in x)
    print("%-38s %-30s %-10s %s" % (rg["id"], rg["title"][:30], rg.get("primary-type",""), a[:40]))'
    ;;
  lookup)
    kind="${1:-}"; mbid="${2:-}"
    case "$kind" in release|release-group|recording|artist) ;; *) echo "usage: lookup release|release-group|recording|artist <mbid>" >&2; exit 2 ;; esac
    enc_mbid="$(enc "$mbid")"
    get "$kind/$enc_mbid?fmt=json&inc=artist-credits" | "$PY" -c '
import json,sys
d=json.load(sys.stdin)
print("mbid:  " + d.get("id",""))
print("type:  " + str(d.get("primary-type") or d.get("type") or ""))
print("title: " + str(d.get("title","")))
if "artist-credit" in d and d["artist-credit"]:
    print("artist:" + ", ".join(x["artist"]["name"] for x in d["artist-credit"] if isinstance(x,dict) and "artist" in x))
if "media" in d: print("media:  " + ", ".join(str(m.get("format")) for m in d["media"]))
if "releases" in d: print("releases in group: %d" % len(d["releases"]))'
    ;;
  classify)
    mbid="${1:-}"; [ -n "$mbid" ] || { echo "usage: classify <mbid>" >&2; exit 2; }
    echo "Classifying $mbid (this is the mistake that breaks Lidarr album lookups):"
    for k in release-group release recording; do
      if out="$(get "$k/$(enc "$mbid")?fmt=json" 2>/dev/null)"; then
        echo "  -> it IS a $k mbid: $(printf '%s' "$out" | "$PY" -c 'import json,sys;print(json.load(sys.stdin).get("title",""))')"
      else echo "  -> not a $k"; fi
    done
    echo "Use the release-group MBID when adding an album in Lidarr. A release MBID selects one edition."
    ;;
  search-recording)
    [ $# -ge 1 ] || { echo "usage: search-recording <artist> [track]" >&2; exit 2; }
    q="artist:\"$1\""; [ "${2:-}" ] && q="$q AND recording:\"$2\""
    get "recording/?query=$(enc "$q")&fmt=json&limit=8" | "$PY" -c '
import json,sys
d=json.load(sys.stdin)
for r in d.get("recordings",[])[:8]:
    a=", ".join(x["artist"]["name"] for x in r.get("artist-credit",[]) if isinstance(x,dict) and "artist" in x)
    print("%-38s %-40s %s" % (r["id"], r["title"][:40], a[:30]))'
    ;;
  # An unknown command is a usage error, like every other script in this pack. Printing the
  # usage and exiting 0 would make a typo look like success to whatever called it.
  *) sed -n '6,14p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
