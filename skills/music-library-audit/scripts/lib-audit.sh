#!/usr/bin/env bash
# lib-audit.sh - READ-ONLY music library inventory. Never writes, moves, retags or deletes.
# Usage: lib-audit.sh <music-dir> [--max N] [--hash] [--out FILE] [--quiet]
#   --out takes a FILE path (its directory must already exist).
# Exit: 0 = report produced, 2 = usage, 3 = --out not writable, 4 = needs Python.
set -uo pipefail

if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v "$PY" || command -v python || true)"
fi
if [ -z "$PY" ]; then echo "lib-audit: needs python (or set PYTHON=)." >&2; exit 2; fi
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

if outpath and (outpath.endswith(("/", os.sep)) or os.path.isdir(outpath)):
    print("lib-audit: --out takes a FILE path, not a directory: %r" % outpath, file=sys.stderr)
    sys.exit(3)
if outpath and not os.path.isdir(os.path.dirname(os.path.abspath(outpath))):
    print("lib-audit: --out parent directory does not exist: %r" % os.path.dirname(os.path.abspath(outpath)), file=sys.stderr)
    sys.exit(3)
AUDIO = {".flac",".mp3",".m4a",".aac",".ogg",".opus",".wav",".aiff",".aif",".ape",".wv",".mpc",".wma"}
have_ffprobe = shutil.which("ffprobe") is not None
have_metaflac = shutil.which("metaflac") is not None
have_flac = shutil.which("flac") is not None
can_tag = have_ffprobe or have_metaflac

files, others, nsp = [], [], []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if not d.startswith(".")]
    for fn in filenames:
        ext = os.path.splitext(fn)[1].lower()
        p = os.path.join(dirpath, fn)
        if ext == ".nsp": nsp.append(p)
        elif ext in AUDIO: files.append(p)
        else: others.append(p)
    if len(files) > maxn: break
files = files[:maxn]

def probe(p):
    if not have_ffprobe: return {}
    r = subprocess.run(["ffprobe","-v","error","-show_entries",
        "format=format_name,duration,bit_rate:stream=codec_name,sample_rate,channels",
        "-of","json",p], capture_output=True, text=True)
    try: return json.loads(r.stdout or "{}")
    except Exception: return {}

def tags(p):
    t = {}
    if p.lower().endswith(".flac") and have_metaflac:
        r = subprocess.run(["metaflac","--export-tags-to=-",p], capture_output=True, text=True)
        for line in r.stdout.splitlines():
            if "=" in line:
                k, v = line.split("=", 1); k = k.upper()
                t.setdefault(k, []).append(v)
    elif have_ffprobe:
        try:
            r = subprocess.run(["ffprobe","-v","error","-show_entries","format_tags","-of","json",p],
                               capture_output=True, text=True)
            for k, v in (json.loads(r.stdout or "{}").get("format", {}).get("tags", {}) or {}).items():
                t.setdefault(k.upper(), []).append(str(v))
        except Exception: pass
    return t

rep = {"scanned": 0, "missing_tags": collections.Counter(), "anomalies": [], "dupes": [],
       "flac_bad": [], "ext_mismatch": [], "same_title": collections.Counter()}
by_sig = collections.defaultdict(list)
CODEC_EXT = {"flac":{".flac"}, "mp3":{".mp3"}, "aac":{".m4a",".aac"}, "vorbis":{".ogg"},
             "opus":{".opus"}, "pcm_s16le":{".wav"}, "alac":{".m4a"}, "wavpack":{".wv"},
             "monkey":{".ape"}, "wmav2":{".wma"}}

for p in sorted(files):
    rep["scanned"] += 1
    info = probe(p); fmt = (info.get("format") or {}); st = (info.get("streams") or [{}])[0]
    ext = os.path.splitext(p)[1].lower()
    codec = (st.get("codec_name") or "").lower()
    dur = float(fmt.get("duration") or 0); br = int(fmt.get("bit_rate") or 0)
    t = tags(p)
    if can_tag:
        for need in ("ARTIST","ALBUM","ALBUMARTIST","TITLE","TRACKNUMBER"):
            if not t.get(need): rep["missing_tags"][need] += 1
    if have_ffprobe and dur < 1:
        rep["anomalies"].append((p, "duration %s - unreadable, zero-length or truncated" % dur))
    if codec in CODEC_EXT and ext not in CODEC_EXT[codec]:
        rep["ext_mismatch"].append((p, "extension %s but codec %s" % (ext, codec)))
    if codec == "mp3" and 0 < br < 128000: rep["anomalies"].append((p, "low bitrate %d kbps" % (br//1000)))
    if codec in ("flac","alac") and 0 < br < 500000: rep["anomalies"].append((p, "lossless codec at only %d kbps - suspicious" % (br//1000)))
    sig = (os.path.getsize(p), round(dur, 1))
    by_sig[sig].append(p)
    key = (tuple(sorted(x.lower() for x in t.get("ARTIST", []))),
           tuple(sorted(x.lower() for x in t.get("ALBUM", []))),
           tuple(sorted(x.lower() for x in t.get("TITLE", []))))
    if all(key): rep["same_title"][key] += 1
    if p.lower().endswith(".flac") and have_flac:
        r = subprocess.run(["flac","-t","-s",p], capture_output=True)
        if r.returncode != 0: rep["flac_bad"].append((p, (r.stderr or b"").decode()[:120]))

for sig, group in by_sig.items():
    if len(group) > 1:
        hashes = set()
        if dohash:
            for g in group:
                h = hashlib.md5()
                try:
                    with open(g,"rb") as fh:
                        for chunk in iter(lambda: fh.read(1 << 20), b""): h.update(chunk)
                    hashes.add(h.hexdigest())
                except OSError: hashes.add("unreadable")
        if dohash:
            verdict = "IDENTICAL CONTENT" if len(hashes) == 1 else "same size/duration, different bytes"
        else:
            verdict = "same size+duration (run with --hash to confirm)"
        rep["dupes"].append((group, verdict))

print("lib-audit: %s" % os.path.abspath(root))
print("  audio files scanned : %d" % rep["scanned"])
print("  non-audio files     : %d" % len(others))
print("  tools: ffprobe=%s metaflac=%s flac=%s" % (have_ffprobe, have_metaflac, have_flac))
print()
if can_tag:
    print("TAG COMPLETENESS (files missing the tag):")
    for k, v in rep["missing_tags"].most_common():
        print("  %-12s %d  (%.0f%%)" % (k, v, 100.0*v/max(rep["scanned"],1)))
else:
    print("TAG COMPLETENESS: not measured (no tag reader installed).")
print()
print("FLAC INTEGRITY FAILURES: %d" % len(rep["flac_bad"]))
for p, e in rep["flac_bad"][:20]: print("  %s  %s" % (p, e))
print()
print("ANOMALIES: %d" % len(rep["anomalies"]))
for p, m in rep["anomalies"][:30]: print("  %-70s %s" % (p[-70:], m))
print()
print("EXTENSION/CODEC MISMATCHES: %d" % len(rep["ext_mismatch"]))
for p, m in rep["ext_mismatch"][:20]: print("  %-70s %s" % (p[-70:], m))
print()
print("DUPLICATE CANDIDATES: %d groups" % len(rep["dupes"]))
for group, verdict in rep["dupes"][:15]:
    print("  [%s]" % verdict)
    for g in group[:4]: print("      %s" % g)
print()
print("READ-ONLY: nothing was modified, moved, retagged or deleted.")

if outpath:
    try:
        with open(outpath, "w") as fh:
            fh.write(json.dumps({"scanned": rep["scanned"], "missing_tags": dict(rep["missing_tags"]),
                "anomalies": rep["anomalies"], "dupes": [[g, v] for g, v in rep["dupes"]],
                "flac_bad": rep["flac_bad"], "ext_mismatch": rep["ext_mismatch"]}, indent=2))
    except OSError as e:
        print("lib-audit: the report was NOT written - %s" % e, file=sys.stderr)
        sys.exit(3)
    print("report written: %s" % outpath)
PY
