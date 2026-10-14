#!/usr/bin/env bash
# lib-audit.sh - READ-ONLY music library inventory. Never writes, moves, retags or deletes.
# Reports: tag completeness, codec/bitrate/duration anomalies, extension-vs-codec mismatches,
# duplicate candidates, FLAC integrity failures. Output to stdout (and optionally --out FILE).
#
# Usage: lib-audit.sh <music-dir> [--max N] [--hash] [--out FILE] [--quiet]
#   --out takes a FILE path (its directory must already exist).
# Exit: 0 = report produced (findings are output, not errors), 2 = usage, 3 = --out not writable,
#       4 = needs Python.
set -uo pipefail

# Resolve a Python interpreter once. Windows and Git Bash often have `python` but not
# `python3`; honours $PYTHON so you can force a specific one.
if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "lib-audit: needs "$PY" (or python). Set PYTHON=/path/to/python." >&2; exit 2; fi
DIR="${1:-}"; [ -n "$DIR" ] && [ -d "$DIR" ] || { echo "usage: lib-audit.sh <music-dir> [--max N] [--hash] [--out FILE]" >&2; exit 2; }
shift || true
MAX=2000; HASH=0; OUT=""
while [ $# -gt 0 ]; do case "$1" in
  --max) MAX="$2"; shift ;; --hash) HASH=1 ;; --out) OUT="$2"; shift ;;
  --quiet) exec >/dev/null ;; *) echo "unknown flag: $1" >&2; exit 2 ;;
esac; shift; done

"$PY" - "$DIR" "$MAX" "$HASH" "$OUT" <<'PY'
import os, subprocess, sys, json, collections, hashlib, re, shutil
root, maxn, dohash, outpath = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "1", sys.argv[4]

# A trailing slash or an existing directory is the common mistake (--out reports/ instead of
# --out reports/audit.json). Say so before scanning, rather than dying with a traceback at the end.
if outpath and (outpath.endswith(("/", os.sep)) or os.path.isdir(outpath)):
    print("lib-audit: --out takes a FILE path, not a directory: %r" % outpath, file=sys.stderr)
    print("lib-audit: e.g. --out <scratch>/reports/audit.json (the directory must exist)", file=sys.stderr)
    sys.exit(3)
if outpath and not os.path.isdir(os.path.dirname(os.path.abspath(outpath))):
    print("lib-audit: --out parent directory does not exist: %r" % os.path.dirname(os.path.abspath(outpath)), file=sys.stderr)
    sys.exit(3)
AUDIO = {".flac",".mp3",".m4a",".aac",".ogg",".opus",".wav",".aiff",".aif",".ape",".wv",".mpc",".wma"}
have_ffprobe = shutil.which("ffprobe") is not None
have_metaflac = shutil.which("metaflac") is not None
can_tag = have_ffprobe or have_metaflac
