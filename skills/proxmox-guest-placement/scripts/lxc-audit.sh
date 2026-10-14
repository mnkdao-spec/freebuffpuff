#!/usr/bin/env bash
# lxc-audit.sh - READ-ONLY audit of a Proxmox LXC container's config, from the host.
# Changes nothing: no pct set/start/stop, no storage writes.
#   * unprivileged / features / AppArmor-relevant settings for Docker-in-LXC
#   * every mpN, devN, rootfs and raw lxc.mount.entry, with backup consequences
#   * bind-mount sources that are host system paths, symlinks, or missing
#   * duplicate/overlapping mount targets
#   * device nodes granted world-writable
#   * --paths A:B -> are they the same filesystem (i.e. can hardlinks work)?
# Exit codes: 0 = report produced, 2 = usage/no config, 4 = needs Python.
#
# Usage: lxc-audit.sh <vmid> [--paths A:B] [--json] [--strict]
#        lxc-audit.sh --config /etc/pve/lxc/120.conf [--paths A:B]
set -uo pipefail

if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v python3 || command -v python || true)"
fi
[ -n "$PY" ] || { echo "lxc-audit: needs python3 (or python). Set PYTHON=/path/to/python3" >&2; exit 4; }

PVE_ETC="${PVE_ETC:-/etc/pve}"
VMID=""; CONF=""; PATHS=""; MODE=text; STRICT=0
while [ $# -gt 0 ]; do case "$1" in
  --config) CONF="${2:-}"; shift ;;
  --paths)  PATHS="${2:-}"; shift ;;
  --json)   MODE=json ;;
  --strict) STRICT=1 ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*) echo "unknown flag: $1" >&2; exit 2 ;;
  *) VMID="$1" ;;
esac; shift; done

# `pct config` output goes to a scratch file. mktemp gives it a 0600 mode and a unique name, and it
# has to be removed on EVERY exit path - this used to leak one /tmp file per run.
TMP_CONF=""
cleanup() { if [ -n "$TMP_CONF" ]; then rm -f "$TMP_CONF"; fi; }
trap cleanup EXIT

if [ -z "$CONF" ] && [ -n "$VMID" ]; then
  if command -v pct >/dev/null 2>&1; then
    TMP_CONF="$(mktemp)"; CONF="$TMP_CONF"
    pct config "$VMID" > "$CONF" 2>/dev/null || true
    if [ ! -s "$CONF" ]; then rm -f "$CONF"; TMP_CONF=""; CONF="$PVE_ETC/lxc/$VMID.conf"; fi
  else
    CONF="$PVE_ETC/lxc/$VMID.conf"
  fi
fi
[ -n "$CONF" ] || { echo "usage: lxc-audit.sh <vmid> [--paths A:B]   or   lxc-audit.sh --config FILE" >&2; exit 2; }
[ -r "$CONF" ] || { echo "lxc-audit: cannot read $CONF (run on the PVE host, or as root)" >&2; exit 2; }

"$PY" - "$CONF" "$PATHS" "$MODE" "$STRICT" "$VMID" <<'PY'
import os, re, subprocess, sys, json

conf, paths_arg, mode, strict, vmid = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1", sys.argv[5]
F = []
def add(level, cid, msg):
    F.append((level, cid, msg))

try:
    lines = open(conf, errors="replace").read().splitlines()
except Exception as e:
    print("lxc-audit: cannot read %s: %s" % (conf, e)); sys.exit(2)

cfg = {}
for line in lines:
    s = line.strip()
    if not s or s.startswith("#"):
        continue
    # PVE writes no inline comments, but people annotate hand-edited configs. Strip only a
    # whitespace-preceded '#' so a legitimate value containing '#' is left alone.
    s = re.sub(r"\s+#.*$", "", s)
    if ":" in s:
        k, v = s.split(":", 1)
        cfg.setdefault(k.strip(), []).append(v.strip())

# The container's own `hostname:` is authoritative; without one, name it from its ID. It must NOT
# fall back to the config filename: when the config came from `pct config <id>` that file is a random
# mktemp name, so the report used to read "hostname tmp.uBUZt2bL4W" for a real container.
base = os.path.basename(conf)
label = vmid or (base[:-5] if base.endswith(".conf") else base)
name = (cfg.get("hostname") or [""])[0].strip() or (("ct" + vmid) if vmid else label)
unpriv = (cfg.get("unprivileged") or ["0"])[0]
features = (cfg.get("features") or [""])[0]
add("INFO", "identity", "container %s, hostname %s, config %s" % (label, name, conf))

# --- privilege surface ------------------------------------------------------
if unpriv == "1":
    add("OK", "privileges", "unprivileged: 1 (container root maps to an unprivileged host uid)")
else:
    add("WARN", "privileges", "unprivileged is NOT 1. A privileged container's root is the host's root: a container escape is a host escape. Proxmox documents privileged containers for trusted environments only.")
feats = dict(p.split("=", 1) for p in features.split(",") if "=" in p)
if feats.get("nesting") == "1" and feats.get("keyctl") != "1":
    add("WARN", "features", "features '%s': nesting=1 without keyctl=1. Unprivileged containers commonly need keyctl for Docker/systemd keyring calls - add it before debugging anything else." % features)
elif feats.get("nesting") == "1":
    add("OK", "features", "features '%s' - the usual Docker-in-LXC baseline." % features)
elif features:
    add("INFO", "features", "features '%s' (nesting not enabled - Docker inside this container will not work)." % features)
if "unconfined" in features:
    add("WARN", "apparmor", "an unconfined AppArmor profile is in use. That removes a real security layer; Proxmox documents it as not recommended for production. Check `dmesg | grep -i apparmor` for the actual denial instead.")
if cfg.get("lxc.apparmor.profile") or cfg.get("lxc.apparmor.raw"):
    add("INFO", "apparmor", "custom AppArmor settings present in the config: %s" % ", ".join(sorted(k for k in cfg if k.startswith("lxc.apparmor"))))
if cfg.get("lxc.idmap") or cfg.get("lxc.id_map"):
    add("INFO", "idmap", "custom id mapping present: %s. Verify the host /etc/subuid and /etc/subgid cover it, and that data ownership matches the map - otherwise files appear as nobody/nogroup." % "; ".join(cfg.get("lxc.idmap", cfg.get("lxc.id_map", []))))

# --- mounts -----------------------------------------------------------------
SYSTEM_RE = re.compile(r"^/(etc|var|usr|boot|bin|sbin|lib|lib64|root|proc|sys|dev)(/|$)")
binds, volumes, devices, raws, targets = [], [], [], [], []
for k, values in cfg.items():
    for v in values:
        head, _, rest = v.partition(",")
        opts = dict(p.split("=", 1) for p in rest.split(",") if "=" in p)
        if re.match(r"^(mp\d+|rootfs)$", k):
            tgt = opts.get("mp", "/" if k == "rootfs" else "?")
            targets.append((k, tgt))
            if head.startswith("/dev/"):
                devices.append((k, head, tgt, opts))
            elif head.startswith("/"):
                binds.append((k, head, tgt, opts))
            else:
                volumes.append((k, head, tgt, opts))
        elif re.match(r"^dev\d+$", k):
            devices.append((k, head, opts.get("mp", "-"), opts))
        elif k in ("lxc.mount.entry", "lxc.mount"):
            raws.append(v)

if binds:
    add("WARN", "mounts:bind", "%d bind mount(s). Bind mounts are NOT included in vzdump backups, cannot be snapshotted by the PVE storage subsystem, and are not quota-managed. They need their own backup (PBS on the directory, a second host, ZFS send, restic/rclone -- not 'it is on the same machine')." % len(binds))
    for k, src, tgt, opts in binds:
        flags = []
        if opts.get("ro") == "1":
            flags.append("ro")
        if opts.get("backup") == "0":
            flags.append("backup=0")
        note = ""
        if not os.path.exists(src):
            note = " SOURCE DOES NOT EXIST on this host - PVE can refuse to start the guest when a bind source is missing."
        elif os.path.islink(src):
            note = " SOURCE IS A SYMLINK - PVE requires a real path and can refuse to start the guest."
        if SYSTEM_RE.match(src) or src == "/":
            note += " This is a HOST SYSTEM PATH; use a dedicated data directory instead."
        add("WARN" if note else "INFO", "mount:" + k, "%s -> %s%s.%s" % (src, tgt, (" (" + ", ".join(flags) + ")") if flags else "", note))
if volumes:
    for k, src, tgt, opts in volumes:
        if k == "rootfs":
            add("INFO", "mount:rootfs", "%s is the root filesystem. It is always included in a container backup; pct.conf documents no backup property for rootfs, so backup=0 there is meaningless." % src)
            continue
        bk = opts.get("backup")
        if bk == "0":
            add("WARN", "mount:" + k, "%s (mp=%s) has backup=0 - excluded from vzdump. Confirm the data really is disposable or is protected elsewhere." % (src, tgt))
        elif bk == "1":
            add("OK", "mount:" + k, "%s (mp=%s) is storage-backed with backup=1, so vzdump includes it (snapshot mode also needs snapshot-capable storage)." % (src, tgt))
        else:
            add("WARN", "mount:" + k, "%s (mp=%s) is storage-backed but has NO backup=1. Per the Backup and Restore chapter: 'By default additional mount points besides the Root Disk mount point are not included in backups.' The GUI's mount-point dialog enables the checkbox when creating one, so this is easy to miss on a hand-edited config. EITHER add backup=1 or document why the data is disposable." % (src, tgt))
if not binds and not volumes:
    add("INFO", "mounts", "no mpN entries: everything on this container is inside the rootfs (which is what backs up), or it mounts shares from inside the guest (which PVE cannot see at all).")
if devices:
    for k, src, tgt, opts in devices:
        m = opts.get("mode", "")
        msg = "%s (%s) grants a device into the container." % (src, k)
        if str(m) in ("0666", "666", "0x1b6", "0777", "777"):
            add("WARN", "device:" + k, msg + " mode=%s is world-readable/writable - grant the specific group (e.g. the host's render/video gid) instead. Also verify the gid inside the container matches, which differs for unprivileged containers." % m)
        else:
            add("INFO", "device:" + k, msg + " Nothing is backed up about it, and it binds this container to the host's kernel driver.")
if raws:
    for v in raws:
        add("INFO", "mount:raw", "raw mount entry: %s (lower-level than mp0; verify the container-side path and that it is not silently required for startup)." % v)

# overlapping / duplicate targets
seen = {}
for k, tgt in targets:
    if tgt in seen:
        add("WARN", "mounts:duplicate", "two mount points target the same path %s (%s and %s)." % (tgt, seen[tgt], k))
    seen[tgt] = k
# Each unordered pair once. Equal targets are duplicates (reported above), not nesting.
for i in range(len(targets)):
    for j in range(i + 1, len(targets)):
        (ak, at), (bk, bt) = targets[i], targets[j]
        a_norm, b_norm = at.rstrip("/") or "/", bt.rstrip("/") or "/"
        if a_norm == b_norm or a_norm == "/" or b_norm == "/":
            continue
        pair = None
        if b_norm.startswith(a_norm + "/"):
            pair = (ak, at, bk, bt)          # outer=mp0-style, inner=the deeper one
        elif a_norm.startswith(b_norm + "/"):
            pair = (bk, bt, ak, at)
        if pair:
            add("WARN", "mounts:nested", "%s (mp=%s) is nested inside %s (mp=%s) - the outer mount decides what the inner path resolves to; this is how 'the library looks empty inside the container' happens." % (pair[2], pair[3], pair[0], pair[1]))

# --- hardlink / same-filesystem question -----------------------------------
if paths_arg:
    if ":" not in paths_arg:
        add("WARN", "hardlinks", "--paths expects TWO paths separated by ':' (e.g. /data/downloads:/data/media).")
    else:
        a, b = paths_arg.split(":", 1)
        def dev(p):
            try:
                st = os.stat(p)
                return st.st_dev
            except OSError:
                return None
        da, db = dev(a), dev(b)
        if da is None or db is None:
            add("WARN", "hardlinks", "cannot stat both paths (missing=%s%s). Run this where the paths exist as the service sees them - typically inside the container: pct exec <id> -- bash /path/lxc-audit.sh --config ... --paths ..." % ("" if da is not None else a, "" if db is not None else b and ", " + b))
        elif da == db:
            add("OK", "hardlinks", "%s and %s are on the same filesystem (dev %d): hardlinks are possible, so an *arr hardlink import can work." % (a, b, da))
        else:
            add("FAIL", "hardlinks", "%s (dev %d) and %s (dev %d) are DIFFERENT filesystems: hardlinks are impossible, so the *arr import will fall back to copy+delete (slow, double I/O, breaks seeding). One ZFS dataset is one filesystem - two datasets in the same pool are still two filesystems. Fix by putting downloads and the library under one shared mount." % (a, da, b, db))

# --- summary ---------------------------------------------------------------
order = {"FAIL": 0, "WARN": 1, "OK": 2, "INFO": 3}
F.sort(key=lambda f: order.get(f[0], 9))
counts = {}
for lvl, _, _ in F:
    counts[lvl] = counts.get(lvl, 0) + 1

if mode == "json":
    print(json.dumps({"tool": "lxc-audit", "config": conf, "vmid": vmid,
                      "summary": counts,
                      "findings": [{"level": l, "id": i, "message": m} for l, i, m in F]}, indent=2))
else:
    print("lxc-audit - read-only (nothing was changed)")
    print("  %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(counts.items(), key=lambda kv: order.get(kv[0], 9))))
    print("")
    for lvl, cid, msg in F:
        print("[%s] %s: %s" % (lvl, cid, msg))
    print("")
    print("Anything that changes a mount, a feature flag or a privilege is APPROVAL-REQUIRED:")
    print("propose the exact `pct set` line, the guest's current config, and the rollback.")

sys.exit(1 if (strict and any(l == "FAIL" for l, _, _ in F)) else 0)
PY
