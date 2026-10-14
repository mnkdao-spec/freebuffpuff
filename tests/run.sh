#!/usr/bin/env bash
# tests/run.sh - reproducible verification for the Freebuff Homelab Pack.
#
#   bash tests/run.sh
#
# Builds fixtures, installs the pack into a scratch repo (--force, so it always tests the
# CURRENT source and never a stale install), runs every shipped script FROM ITS INSTALLED
# LOCATION, and asserts the findings. Read-only: it never touches a real service or library.
#
# Needs: bash, python3, curl, git. Uses network only for the MusicBrainz section (skipped
# with a warning when unreachable). Override the scratch directory with VERIFY_WORKDIR.
#
# Exit: 0 = every check passed, 1 = at least one check failed.
set -uo pipefail

PACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${VERIFY_WORKDIR:-/tmp/freebuff-pack-verify}"
FIX="$WORK/fixtures"
OUT="$WORK/out"
REPO="$WORK/repo"
SK="$REPO/.agents/skills"
FAKE="$WORK/fakebin"        # fake pvesh / pveversion / zpool
AUDIO_FAKE="$WORK/audio-bin" # fake ffprobe / metaflac / flac

pass=0; fail=0
ok()    { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()   { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
skip()  { printf '  \033[33mSKIP\033[0m %s\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
want()    { if grep -qiE -- "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1  (no /$3/ in $2)"; fi; }
wantnot() { if grep -qiE -- "$3" "$2" 2>/dev/null; then bad "$1  (unexpected /$3/)"; else ok "$1"; fi; }
exitcode() { if [ "$2" = "$3" ]; then ok "$1 (exit $3)"; else bad "$1 (want exit $2, got $3)"; fi; }
isjson() { if python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));assert d' "$2" 2>/dev/null; then ok "$1"; else bad "$1 (not valid standalone JSON: $2)"; fi; }

for tool in python3 curl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "tests/run.sh needs $tool on PATH" >&2; exit 1; }
done
export PYTHON="${PYTHON:-python3}"

printf '\033[1mFreebuff Homelab Pack - verification\033[0m\npack: %s\nwork: %s\n' "$PACK" "$WORK"

# ============================================================ fixtures
rm -rf "$WORK"; mkdir -p "$OUT" "$REPO" "$FAKE" "$AUDIO_FAKE"
mkdir -p "$FIX"/{pve/lxc,pve/qemu-server,apt/sources.list.d,lxc,music,site/assets,site/releases/2026-ep,compose,nsp,fs/downloads,fs/media}

# ---------------------------------------------------------- fake PVE host
cat > "$FAKE/pveversion" <<'EOF'
#!/usr/bin/env bash
echo "proxmox-ve: 8.2.4 (running kernel: 6.8.12-2-pve)"
echo "pve-manager: 8.2.4 (running version: 8.2.4)"
EOF
cat > "$FAKE/zpool" <<'EOF'
#!/usr/bin/env bash
printf 'rpool\tONLINE\t62\t1.00T\t400G\n'
printf 'tank\tDEGRADED\t88\t4.00T\t3.50T\n'
EOF
cat > "$FAKE/pvesh" <<'EOF'
#!/usr/bin/env bash
path="${2:-}"
case "$path" in
  /nodes)             echo '[{"node":"pve"}]' ;;
  /nodes/pve/status)  echo '{"rootfs":{"used":48000000000,"total":102400000000,"avail":54400000000,"used_fraction":0.46},"memory":{"used":42000000000,"total":67000000000}}' ;;
  /nodes/pve/storage) echo '[{"storage":"local","type":"dir","active":1,"total":102400000000,"avail":4000000000,"shared":0},
      {"storage":"nvme-media","type":"dir","active":1,"total":2000000000000,"avail":1400000000000,"shared":0},
      {"storage":"backup-nfs","type":"nfs","active":0,"total":0,"avail":0,"shared":1}]' ;;
  /cluster/resources) echo '[{"type":"lxc","vmid":120,"name":"media","status":"running"},
      {"type":"lxc","vmid":121,"name":"pkm","status":"running"},
      {"type":"qemu","vmid":900,"name":"haos","status":"stopped"}]' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FAKE"/*

cat > "$FIX/pve/storage.cfg" <<'EOF'
dir: local
	path /var/lib/vz
	content iso,vztmpl,backup
	shared 0
dir: nvme-media
	path /mnt/nvme/media
	content images,rootdir
	shared 0
nfs: backup-nfs
	export /exports/backup
	path /mnt/pve/backup-nfs
	content backup
	shared 1
EOF
# CT 120: mp0 is covered by backups, mp1 is NOT (the trap this pack documents)
cat > "$FIX/pve/lxc/120.conf" <<'EOF'
arch: amd64
cores: 4
features: nesting=1,keyctl=1
hostname: media
memory: 8192
mp0: /mnt/nvme/media,mp=/data/media,backup=1
mp1: /mnt/nvme/downloads,mp=/data/downloads
net0: name=eth0,bridge=vmbr0,ip=192.168.1.20/24,gw=192.168.1.1
onboot: 1
rootfs: nvme-media:120/vm-120-disk-0.raw,size=32G
unprivileged: 1
EOF
cat > "$FIX/pve/lxc/121.conf" <<'EOF'
arch: amd64
cores: 2
hostname: pkm
memory: 4096
mp0: /mnt/nvme/vault,mp=/vault,backup=1
net0: name=eth0,bridge=vmbr0,ip=192.168.1.21/24,gw=192.168.1.1
rootfs: nvme-media:121/vm-121-disk-0.raw,size=16G
unprivileged: 1
EOF
cat > "$FIX/pve/qemu-server/900.conf" <<'EOF'
cores: 2
memory: 4096
name: haos
onboot: 1
scsi0: local:900/vm-900-disk-0.qcow2,size=32G
EOF
cat > "$FIX/apt/sources.list" <<'EOF'
deb http://deb.debian.org/debian bookworm main contrib
EOF
cat > "$FIX/apt/sources.list.d/pve-enterprise.list" <<'EOF'
deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
cat > "$FIX/apt/sources.list.d/pve-no-subscription.list" <<'EOF'
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# ------------------------------------------------------------- LXC fixtures
cat > "$FIX/lxc/bad.conf" <<'EOF'
arch: amd64
cores: 0
features: nesting=1
memory: 2048
hostname: badbox
mp0: /mnt/nvme/media,mp=/data/media          # media library, should be backed up
mp1: /etc,mp=/host-etc
mp2: nvme-media:200/vm-200-disk-0.raw,mp=/data/extra,size=100G
onboot: 1
rootfs: nvme-media:200/vm-200-disk-0.raw,size=8G
unprivileged: 1
EOF
cat > "$FIX/lxc/good.conf" <<'EOF'
arch: amd64
cores: 4
features: nesting=1,keyctl=1
hostname: media
memory: 8192
mp0: /mnt/nvme/media,mp=/data/media,backup=1
mp1: /mnt/nvme/downloads,mp=/data/downloads,backup=1
onboot: 1
rootfs: nvme-media:120/vm-120-disk-0.raw,size=32G
unprivileged: 1
EOF

# --------------------------------------------------------- compose fixtures
cat > "$FIX/compose/docker-compose.yml" <<'EOF'
services:
  navidrome:
    image: deluan/navidrome:latest
    environment: { ND_MUSICFOLDER: /music, ND_DATAFOLDER: /data }
    volumes:
      - /mnt/nvme/media/music:/music:ro
      - /mnt/nvme/appdata/navidrome:/data
    networks: [media]
  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    environment: { PUID: 1000, PGID: 1000 }
    volumes:
      - /mnt/nvme/appdata/lidarr:/config
      - /mnt/nvme/media/music:/music
      - /mnt/nvme/downloads:/downloads
    networks: [media]
  slskd:
    image: slskd/slskd:latest
    environment: { SLSKD_DOWNLOADS_DIR: /data/downloads }
    volumes:
      - /mnt/nvme/downloads:/data/downloads
      - /mnt/nvme/media/music:/data/media
    networks: [media]
networks:
  media: { driver: bridge }
EOF
cat > "$FIX/compose/good.yml" <<'EOF'
services:
  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    volumes:
      - /mnt/nvme/appdata/lidarr:/config
      - /mnt/nvme/media/music:/data/media
      - /mnt/nvme/downloads:/data/downloads
  slskd:
    image: slskd/slskd:latest
    volumes:
      - /mnt/nvme/downloads:/data/downloads
      - /mnt/nvme/media/music:/data/media
EOF
# hardlink feasibility, all three outcomes
cat > "$FIX/fs/same.yml" <<EOF
services:
  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    volumes:
      - $FIX/fs/downloads:/data/downloads
      - $FIX/fs/media:/data/media
  slskd:
    image: slskd/slskd:latest
    volumes:
      - $FIX/fs/downloads:/data/downloads
EOF

# ------------------------------------------------------------- .nsp fixtures
cat > "$FIX/nsp/good.nsp" <<'EOF'
{
  "name": "Late night instrumental",
  "comment": "quiet listening, nothing played yet",
  "all": [
    { "is": { "genre": "Ambient" } },
    { "is": { "playCount": 0 } }
  ],
  "any": [
    { "gt": { "rating": 3 } },
    { "inTheLast": { "addedAt": "90d" } }
  ],
  "sort": "-rating,title",
  "limit": 100,
  "refreshDelay": "1d"
}
EOF
cat > "$FIX/nsp/bad.nsp" <<'EOF'
{
  "name": "Broken",
  "all": [ { "isLike": { "genre": "Ambient" } } ],
  "srot": "-rating"
}
EOF
cat > "$FIX/nsp/empty.nsp" <<'EOF'
{ "name": "Empty rules" }
EOF

# ----------------------------------------------------------- music fixture
M="$FIX/music"; mkdir -p "$M/Artist One/Album A" "$M/Artist Two/Album B"
python3 - "$M" <<'PY'
import os, sys, wave
base = sys.argv[1]
with wave.open(os.path.join(base, "Artist Two/Album B/02 - Real.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000)
    w.writeframes(b"\x00\x00" * 48000 * 240)
with wave.open(os.path.join(base, "Artist One/Album A/03 - Tiny.wav"), "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes(b"\x00\x00" * 44100)
for rel, magic in (("Artist One/Album A/01 - Good Track.flac", b"fLaC"),
                   ("Artist One/Album A/02 - Also Fine.flac", b"fLaC"),
                   ("Artist Two/Album B/01 - Untagged.mp3", b"ID3\x03\x00\x00\x00\x00\x00\x00")):
    with open(os.path.join(base, rel), "wb") as f: f.write(magic + os.urandom(4096))
open(os.path.join(base, "Artist Two/Album B/03 - Empty.flac"), "wb").close()
with open(os.path.join(base, "Artist One/Album A/cover.jpg"), "wb") as f:
    f.write(b"\xff\xd8\xff\xe0" + os.urandom(4096))
PY

# ------------------------------------------------------------ site fixture
S="$FIX/site"
cat > "$S/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Project - new EP out now</title>
  <meta name="description" content="New EP, tour dates and the mailing list.">
  <meta property="og:title" content="Project - new EP out now">
  <meta property="og:image" content="/assets/cover.jpg">
  <link rel="canonical" href="https://example.com/">
</head>
<body>
  <h1>Project</h1>
  <img src="/assets/cover.jpg" alt="Cover art">
  <img src="/assets/big-cover.jpg">
  <a href="/releases/2026-ep/">The EP</a>
</body>
</html>
EOF
cat > "$S/releases/2026-ep/index.html" <<'EOF'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>The EP - 2026</title>
<meta name="description" content="The 2026 EP: four tracks, recorded at home."></head>
<body><h1>The EP</h1><a href="/">Home</a></body>
</html>
EOF
cat > "$S/404.html" <<'EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Not found</title></head><body><h1>404</h1></body></html>
EOF
head -c 900000 /dev/urandom > "$S/assets/big-cover.jpg"
head -c 40000 /dev/urandom > "$S/assets/cover.jpg"
cat > "$S/assets/main.js" <<'EOF'
console.log("hi");
const STRIPE_LIVE = "sk_live_abcdefghij1234567890";
EOF
cat > "$S/.env" <<'EOF'
PUBLIC_SITE_URL=https://example.com
SMTP_PASSWORD=supersecret123
EOF

# -------------------------------------------------- fake audio toolchain
# lib-audit.sh must degrade honestly when ffmpeg/flac are absent, AND still find real problems
# when they are present. These fakes make both paths testable anywhere.
cat > "$AUDIO_FAKE/ffprobe" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do f="$a"; done
base="$(basename "$f")"
case "$base" in
  *Tiny*)     dur=0.4; codec="pcm_s16le"; rate=44100; br=1411200 ;;
  *Empty*)    dur=0;   codec="flac";      rate=44100; br=900000 ;;
  *Untagged*) dur=180; codec="mp3";       rate=44100; br=96000 ;;
  *Real*)     dur=240; codec="pcm_s16le"; rate=48000; br=1536000 ;;
  *)          dur=200; codec="flac";      rate=44100; br=900000 ;;
esac
case "$*" in
  *format_tags*)
    case "$base" in *Untagged*) echo '{"format":{"tags":{}}}' ;;
      *) echo "{\"format\":{\"tags\":{\"ARTIST\":\"Artist\",\"ALBUM\":\"Album\",\"ALBUMARTIST\":\"Artist\",\"TITLE\":\"$base\",\"TRACKNUMBER\":\"1\"}}}" ;; esac ;;
  *) printf '{"format":{"format_name":"%s","duration":"%s","bit_rate":"%s"},"streams":[{"codec_name":"%s","sample_rate":"%s","channels":2}]}' "$codec" "$dur" "$br" "$codec" "$rate" ;;
esac
EOF
cat > "$AUDIO_FAKE/metaflac" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do f="$a"; done
printf 'ARTIST=Artist\nALBUM=Album\nALBUMARTIST=Artist\nTITLE=%s\nTRACKNUMBER=1\n' "$(basename "$f")"
EOF
cat > "$AUDIO_FAKE/flac" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do f="$a"; done
if [ "$(basename "$f")" = "03 - Empty.flac" ]; then echo "$f: ERROR while decoding data" >&2; exit 1; fi
echo "$f: ok"; exit 0
EOF
chmod +x "$AUDIO_FAKE"/*

# ============================================================ install
head_ "install.sh  (validate + install into a scratch repo)"
cd "$REPO" || exit 1
git init -q . 2>/dev/null || true
bash "$PACK/install.sh" --project "$REPO" > "$OUT/install.txt" 2>&1
exitcode "clean install into an empty directory" 0 "$?"
want "validates every skill" "$OUT/install.txt" 'validated 39 skills, 0 invalid'
want "validates every agent" "$OUT/install.txt" 'validated 5 agents, 0 invalid'
# --force on every later run: install.sh skips existing files, so a stale .agents/ would hide fixes
bash "$PACK/install.sh" --project "$REPO" --force > "$OUT/reinstall.txt" 2>&1
exitcode "reinstall with --force (tests CURRENT source)" 0 "$?"
bash "$PACK/install.sh" --project "$REPO" > "$OUT/install2.txt" 2>&1
if grep -q 'skip (exists)' "$OUT/install2.txt" && [ "$(ls -1 "$SK" | wc -l)" = 39 ]; then
  ok "re-running is idempotent (skips, no duplicates)"
else bad "re-running is idempotent"; fi
bash "$PACK/install.sh" --verify > "$OUT/verify.txt" 2>&1
exitcode "--verify exits 0" 0 "$?"
want "--verify covers skills" "$OUT/verify.txt" 'validated 39 skills, 0 invalid'
want "--verify covers agents" "$OUT/verify.txt" 'validated 5 agents, 0 invalid'

# ======================================================= 1. pve-doctor.sh
head_ "pve-doctor.sh  (proxmox-stack-map, installed)"
PVE_S="$SK/proxmox-stack-map/scripts/pve-doctor.sh"
env -i PATH="$FAKE:/usr/local/bin:/usr/bin:/bin" HOME="$HOME" \
  PVE_ETC="$FIX/pve" APT_ETC="$FIX/apt" PYTHON=python3 \
  bash "$PVE_S" > "$OUT/pve.txt" 2>"$OUT/pve.err"; ec=$?
exitcode "runs on a simulated PVE host" 0 "$ec"
want "detects the 96%-full 'local' storage"      "$OUT/pve.txt" 'local.*9[0-9]% full'
want "detects the inactive 'backup-nfs' storage" "$OUT/pve.txt" 'backup-nfs.*inactive'
want "detects the DEGRADED ZFS pool 'tank'"      "$OUT/pve.txt" 'tank'
want "flags CT 120 mp1 as not backed up"         "$OUT/pve.txt" 'mp1|downloads'
want "reports the guest inventory"               "$OUT/pve.txt" 'CT 2 total|CT 2'
want "flags the enterprise repo without a sub"   "$OUT/pve.txt" 'enterprise'
want "flags the missing backup job"              "$OUT/pve.txt" 'no scheduled backup job'
env -i PATH="$FAKE:/usr/local/bin:/usr/bin:/bin" HOME="$HOME" \
  PVE_ETC="$FIX/pve" APT_ETC="$FIX/apt" PYTHON=python3 \
  bash "$PVE_S" --json > "$OUT/pve.json" 2>/dev/null
isjson "JSON mode emits one standalone JSON object" "$OUT/pve.json"
env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$HOME" bash "$PVE_S" >/dev/null 2>&1
exitcode "exits 3 off a PVE host" 3 "$?"

# ======================================================= 2. lxc-audit.sh
head_ "lxc-audit.sh  (proxmox-guest-placement, installed)"
LXC_S="$SK/proxmox-guest-placement/scripts/lxc-audit.sh"
bash "$LXC_S" --config "$FIX/lxc/bad.conf" > "$OUT/lxc-bad.txt" 2>&1; ec=$?
exitcode "runs on a hand-edited config" 0 "$ec"
want "flags mp0 (media) as NOT backed up"        "$OUT/lxc-bad.txt" 'mp0'
want "flags /etc as a host system path"          "$OUT/lxc-bad.txt" '/etc|host system path'
want "reads inline comments instead of choking"  "$OUT/lxc-bad.txt" 'badbox'
bash "$LXC_S" --config "$FIX/lxc/good.conf" > "$OUT/lxc-good.txt" 2>&1
wantnot "no backup warning on a clean config" "$OUT/lxc-good.txt" 'NO backup=1'
PYTHON=python3 bash "$LXC_S" --config "$FIX/lxc/good.conf" --json > "$OUT/lxc.json" 2>/dev/null
isjson "JSON mode emits one standalone JSON object" "$OUT/lxc.json"
bash "$LXC_S" >/dev/null 2>&1; exitcode "exits 2 with no argument" 2 "$?"

# =================================================== 3. compose-doctor.sh
head_ "compose-doctor.sh  (music-path-and-hardlink-doctor, installed)"
CD_S="$SK/music-path-and-hardlink-doctor/scripts/compose-doctor.sh"
bash "$CD_S" "$FIX/compose/docker-compose.yml" > "$OUT/compose.txt" 2>&1; ec=$?
exitcode "runs on the media-stack compose file" 0 "$ec"
want "catches the slskd/lidarr downloads mismatch" "$OUT/compose.txt" 'different container paths'
want "explains how to check an invisible path"     "$OUT/compose.txt" 'cannot be checked from here'
bash "$CD_S" "$FIX/compose/docker-compose.yml" --json > "$OUT/compose.json" 2>/dev/null
isjson "--json emits ONE standalone JSON object (pipeable)" "$OUT/compose.json"
bash "$CD_S" --json "$FIX/compose/good.yml" > "$OUT/compose-order.json" 2>/dev/null
isjson "--json accepted before the filename" "$OUT/compose-order.json"
bash "$CD_S" "$FIX/compose/good.yml" > "$OUT/compose-good.txt" 2>&1
wantnot "no mismatch for the consistent file" "$OUT/compose-good.txt" 'different container paths'
bash "$CD_S" "$FIX/fs/same.yml" > "$OUT/hl-same.txt" 2>&1
want "same filesystem -> hardlinks reported possible" "$OUT/hl-same.txt" 'same filesystem.*hardlinks are possible'
# The case that actually costs data: download root and library root on different filesystems.
# Needs a second filesystem to point at, so it is conditional.
OTHER=""
if [ -d /dev/shm ] && [ "$(stat -c %d /dev/shm 2>/dev/null)" != "$(stat -c %d "$FIX/fs/media" 2>/dev/null)" ]; then OTHER=/dev/shm; fi
if [ -n "$OTHER" ]; then
  # The path must end in a conventional root name (/downloads) for the heuristic to match it -
  # the same rule the script uses, so this also documents that limitation.
  mkdir -p "$OTHER/fbp-verify/downloads" 2>/dev/null
  cat > "$FIX/fs/cross.yml" <<EOF
services:
  lidarr:
    image: lscr.io/linuxserver/lidarr:latest
    volumes:
      - $OTHER/fbp-verify/downloads:/data/downloads
      - $FIX/fs/media:/data/media
  slskd:
    image: slskd/slskd:latest
    volumes:
      - $OTHER/fbp-verify/downloads:/data/downloads
EOF
  bash "$CD_S" "$FIX/fs/cross.yml" > "$OUT/hl-cross.txt" 2>&1
  want "different filesystems -> WARN against hardlinks" "$OUT/hl-cross.txt" 'DIFFERENT filesystems'
else
  skip "cross-filesystem hardlink case needs a second filesystem (no /dev/shm)"
fi

# ======================================================== 4. nsp-lint.sh
head_ "nsp-lint.sh  (music-navidrome-nsp-author, installed)"
NSP_S="$SK/music-navidrome-nsp-author/scripts/nsp-lint.sh"
bash "$NSP_S" "$FIX/nsp/good.nsp" > "$OUT/nsp-good.txt" 2>&1
exitcode "accepts a valid smart-playlist .nsp" 0 "$?"
want "reports zero problems on it" "$OUT/nsp-good.txt" '0 problem'
bash "$NSP_S" "$FIX/nsp/bad.nsp" > "$OUT/nsp-bad.txt" 2>&1
if [ $? -ne 0 ]; then ok "rejects an invented operator"; else bad "rejects an invented operator"; fi
want "names the unknown operator" "$OUT/nsp-bad.txt" 'isLike'
want "flags the mistyped key"     "$OUT/nsp-bad.txt" 'srot'
bash "$NSP_S" "$FIX/nsp/empty.nsp" >/dev/null 2>&1
if [ $? -ne 0 ]; then ok "rejects a rule-less .nsp"; else bad "rejects a rule-less .nsp"; fi

# ======================================================= 5. lib-audit.sh
head_ "lib-audit.sh  (music-library-audit, installed)"
LA_S="$SK/music-library-audit/scripts/lib-audit.sh"
# (a) a minimal box with no ffmpeg/flac at all: must degrade, never traceback or cry wolf
env -i PATH="/usr/local/bin:/usr/bin:/bin" HOME="$HOME" PYTHON=python3 \
  bash "$LA_S" "$FIX/music" > "$OUT/lib-nofp.txt" 2>"$OUT/lib-nofp.err"; ec=$?
exitcode "runs WITHOUT ffprobe (no traceback)" 0 "$ec"
wantnot "no Python traceback without ffprobe"    "$OUT/lib-nofp.err" 'Traceback'
want "names the checks that did NOT run"         "$OUT/lib-nofp.txt" 'NOT RUN'
want "does not claim tag findings it cannot see" "$OUT/lib-nofp.txt" 'not measured'
wantnot "does NOT flag every file as duration 0" "$OUT/lib-nofp.txt" 'ANOMALIES: 6'
# (b) a box with the audio toolchain present: real problems must be found
env PATH="$AUDIO_FAKE:$PATH" PYTHON=python3 bash "$LA_S" "$FIX/music" > "$OUT/lib-tools.txt" 2>&1; ec=$?
exitcode "runs WITH ffprobe/metaflac/flac" 0 "$ec"
want "catches the truncated 0.4s track"   "$OUT/lib-tools.txt" 'Tiny'
want "catches the zero-length file"       "$OUT/lib-tools.txt" 'Empty.*duration 0'
want "catches the low-bitrate mp3"        "$OUT/lib-tools.txt" 'low bitrate 96'
want "catches the FLAC integrity failure" "$OUT/lib-tools.txt" 'FLAC INTEGRITY FAILURES: 1'
want "counts files missing tags"          "$OUT/lib-tools.txt" 'ARTIST.*1'
env PATH="$AUDIO_FAKE:$PATH" PYTHON=python3 bash "$LA_S" "$FIX/music" --out "$OUT/lib.json" >/dev/null 2>&1
isjson "--out writes a standalone JSON report" "$OUT/lib.json"
# An unusable --out must be a clean message, not a traceback: the runbook used to document a
# directory (--out reports/), which died with IsADirectoryError inside the scan.
mkdir -p "$WORK/libout"
env PATH="$AUDIO_FAKE:$PATH" PYTHON=python3 bash "$LA_S" "$FIX/music" --out "$WORK/libout/" >/dev/null 2>"$OUT/lib-dir.err"
exitcode "--out <directory> is refused" 3 "$?"
wantnot "  ...without a traceback"      "$OUT/lib-dir.err" 'Traceback'
want "  ...and says what --out wants"   "$OUT/lib-dir.err" 'FILE path'
env PATH="$AUDIO_FAKE:$PATH" PYTHON=python3 bash "$LA_S" "$FIX/music" --out "$WORK/no-such-dir/audit.json" >/dev/null 2>"$OUT/lib-parent.err"
exitcode "--out with a missing parent is refused" 3 "$?"
wantnot "  ...without a traceback"                 "$OUT/lib-parent.err" 'Traceback'

# ===================================================== 6. slskd-doctor.sh
head_ "slskd-doctor.sh  (music-slskd-ops, installed)"
SD_S="$SK/music-slskd-ops/scripts/slskd-doctor.sh"
python3 - <<'PY' &
import http.server, socketserver, json
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/v0/session"):
            self.send_response(401); self.end_headers(); self.wfile.write(b'{"message":"Unauthorized"}')
        elif self.path.startswith("/api/v0/application"):
            b = json.dumps({"version": "0.21.4"}).encode()
            self.send_response(200); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(("127.0.0.1", 5030), H).serve_forever()
PY
SRV=$!; sleep 1
SLSKD_URL=http://127.0.0.1:5030 SLSKD_API_KEY=test-readonly-key PYTHON=python3 \
  bash "$SD_S" > "$OUT/slskd.txt" 2>&1; ec=$?
kill $SRV 2>/dev/null; wait $SRV 2>/dev/null
exitcode "probes a live slskd-shaped API" 0 "$ec"
want "reports a 401 per probe without dying" "$OUT/slskd.txt" '401'
want "reports the 200 endpoint"              "$OUT/slskd.txt" '200'
( unset SLSKD_API_KEY; bash "$SD_S" >/dev/null 2>&1 ); exitcode "exits 2 without SLSKD_API_KEY" 2 "$?"

# ====================================================== 7. mb-lookup.sh
head_ "mb-lookup.sh  (music-musicbrainz-lookup, installed)"
MB_S="$SK/music-musicbrainz-lookup/scripts/mb-lookup.sh"
if curl -sS -m 8 -o /dev/null https://musicbrainz.org/ws/2/ 2>/dev/null; then
  STATE="$WORK/mb-state"; MB_CACHE="$WORK/mb-cache"
  # A cache hit makes no HTTP request, so it must not be rate limited: clear the cache, or this
  # measures cache speed and proves nothing about the limiter.
  rm -rf "$MB_CACHE"; rm -f "$STATE" "$STATE.lock"
  env MB_RATE_STATE="$STATE" MB_CACHE_DIR="$MB_CACHE" PYTHON=python3 \
    bash "$MB_S" search-release-group "Boards of Canada" "Music Has the Right to Children" > "$OUT/mb1.txt" 2>&1
  exitcode "live MusicBrainz lookup succeeds" 0 "$?"
  want "returns a release-group match" "$OUT/mb1.txt" 'Music Has the Right|release-group|mbid'
  sA="$(cat "$STATE" 2>/dev/null || echo 0)"
  [ "$sA" = 0 ] && bad "the rate-limit state file was never written"
  env MB_RATE_STATE="$STATE" MB_CACHE_DIR="$MB_CACHE" PYTHON=python3 \
    bash "$MB_S" search-release-group "Autechre" "Amber" > "$OUT/mb2.txt" 2>&1
  sB="$(cat "$STATE" 2>/dev/null || echo 0)"
  gap="$(awk -v a="$sA" -v b="$sB" 'BEGIN{printf "%.3f", (b-a)/1e9}')"
  if awk -v g="$gap" 'BEGIN{exit !(g>=1.05)}'; then
    ok "second request started ${gap}s after the first (>= the 1.1s MB floor)"
  else bad "second request started only ${gap}s after the first - rate limit not enforced"; fi
  rm -rf "$MB_CACHE"; rm -f "$STATE" "$STATE.lock"
  S=$(date +%s.%N)
  for a in "Aphex Twin" "Squarepusher" "Autechre"; do
    env MB_RATE_STATE="$STATE" MB_CACHE_DIR="$MB_CACHE" PYTHON=python3 \
      bash "$MB_S" search-release-group "$a" distinct-unique > /dev/null 2>&1 &
  done
  wait; E=$(date +%s.%N)
  conc="$(awk -v s="$S" -v e="$E" 'BEGIN{printf "%.2f", e-s}')"
  if awk -v c="$conc" 'BEGIN{exit !(c>=2.0)}'; then
    ok "3 concurrent lookups serialised across processes (${conc}s wall)"
  else bad "3 concurrent lookups did not serialise (${conc}s wall)"; fi
else
  skip "MusicBrainz unreachable - live lookup and rate limit NOT verified"
fi

# ====================================================== 8. site-audit.sh
head_ "site-audit.sh  (web-perf-a11y, installed)"
SA_S="$SK/web-perf-a11y/scripts/site-audit.sh"
bash "$SA_S" "$FIX/site" > "$OUT/site.txt" 2>&1; ec=$?
exitcode "runs over the static site" 0 "$ec"
want "flags an image without alt text"          "$OUT/site.txt" 'alt'
want "flags an asset over the JS/image budget"  "$OUT/site.txt" 'big-cover|budget'
want "flags a .env in the published output"     "$OUT/site.txt" 'leak:file.*\.env'
want "finds a hardcoded live key in a JS asset" "$OUT/site.txt" 'leak:secret.*sk_live'
want "checks titles/descriptions"               "$OUT/site.txt" 'title|description'
( cd "$FIX/site" && python3 -m http.server 8099 --bind 127.0.0.1 >/dev/null 2>&1 ) & WEB=$!
sleep 1
bash "$SA_S" "$FIX/site" --url http://127.0.0.1:8099 > "$OUT/site-url.txt" 2>&1; ec=$?
kill $WEB 2>/dev/null; wait $WEB 2>/dev/null
exitcode "live --url checks run" 0 "$ec"
bash "$SA_S" "$FIX/site" --json > "$OUT/site.json" 2>/dev/null
isjson "--json emits one standalone JSON object" "$OUT/site.json"
bash "$SA_S" "$FIX/site" --strict >/dev/null 2>&1
if [ $? -eq 1 ]; then ok "--strict exits 1 on a failing site"; else bad "--strict exits 1 on a failing site"; fi
bash "$SA_S" >/dev/null 2>&1; exitcode "exits 2 with no directory" 2 "$?"

# ============================================================ 9. agents
head_ "agents  (installed by install.sh)"
n=0; for a in "$REPO"/.agents/*.ts; do [ -e "$a" ] || continue; n=$((n+1)); done
[ "$n" = 5 ] && ok "5 agent files installed in .agents/" || bad "expected 5 agent files in .agents/, found $n"
[ -f "$REPO/.agents/types/agent-definition.d.ts" ] \
  && ok "shared type installed at .agents/types/agent-definition.d.ts" \
  || bad "shared type missing at .agents/types/agent-definition.d.ts"
for a in "$REPO"/.agents/*.ts; do
  [ -e "$a" ] || continue
  if node -e 'const {pathToFileURL}=require("node:url"); import(pathToFileURL(process.argv[1]).href).then(()=>process.exit(0),e=>{console.error(e&&e.message);process.exit(1)})' "$a" 2>"$OUT/agent.err"; then
    ok "$(basename "$a") loads as an ES module"
  else bad "$(basename "$a") loads  ($(head -1 "$OUT/agent.err"))"; fi
done

# ============================================================ 10. MCP server
head_ "mcp/local-readonly  (handshake + tool surface)"
node "$PACK/mcp/local-readonly/server.js" > "$OUT/mcp.txt" 2>&1 <<'EOF' &
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"1"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
EOF
MCP_PID=$!; sleep 2; kill $MCP_PID 2>/dev/null; wait $MCP_PID 2>/dev/null
if grep -q '"tools"' "$OUT/mcp.txt"; then
  ok "server answers initialize + tools/list over stdio"
  if grep -qiE '"(write|delete|remove|exec|shell|post|put)[a-z_]*"' "$OUT/mcp.txt"; then
    bad "tool list contains a write-shaped tool name"
  else ok "no write-shaped tool is advertised (GET-only surface)"; fi
else
  bad "MCP server did not answer tools/list"
fi

printf '\n\033[1m%d passed, %d failed\033[0m\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
