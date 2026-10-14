#!/usr/bin/env bash
# lxc-audit.sh - READ-ONLY audit of a Proxmox LXC container's config, from the host.
# Changes nothing: no pct set/start/stop, no storage writes.
# Exit codes: 0 = report produced, 2 = usage/no config, 4 = needs Python.
# Usage: lxc-audit.sh <vmid> [--paths A:B] [--json] [--strict]
#        lxc-audit.sh --config /etc/pve/lxc/120.conf [--paths A:B]
set -uo pipefail

if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v python3 || command -v python || true)"
fi
[ -n "$PY" ] || { echo "lxc-audit: needs python3 (or python)." >&2; exit 4; }

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

if [ -z "$CONF" ] && [ -n "$VMID" ]; then
  if command -v pct >/dev/null 2>&1; then
    CONF="$(mktemp)"; pct config "$VMID" > "$CONF" 2>/dev/null || true
    [ -s "$CONF" ] || { rm -f "$CONF"; CONF="$PVE_ETC/lxc/$VMID.conf"; }
  else
    CONF="$PVE_ETC/lxc/$VMID.conf"
  fi
fi
[ -n "$CONF" ] || { echo "usage: lxc-audit.sh <vmid> [--paths A:B]" >&2; exit 2; }
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
    s = re.sub(r"\s+#.*$", "", s)
    if ":" in s:
        k, v = s.split(":", 1)
        cfg.setdefault(k.strip(), []).append(v.strip())

name = (cfg.get("hostname") or [os.path.basename(conf)])[0]
unpriv = (cfg.get("unprivileged") or ["0"])[0]
features = (cfg.get("features") or [""])[0]
add("INFO", "identity", "container %s, hostname %s, config %s" % (vmid or os.path.basename(conf), name, conf))

if unpriv == "1":
    add("OK", "privileges", "unprivileged: 1")
else:
    add("WARN", "privileges", "unprivileged is NOT 1: container escape is host escape.")
feats = dict(p.split("=", 1) for p in features.split(",") if "=" in p)
if feats.get("nesting") == "1" and feats.get("keyctl") != "1":
    add("WARN", "features", "nesting=1 without keyctl=1: add keyctl for Docker/systemd keyring calls.")
elif feats.get("nesting") == "1":
    add("OK", "features", "nesting+keyctl baseline for Docker-in-LXC.")
if "unconfined" in features:
    add("WARN", "apparmor", "unconfined profile removes a real security layer.")

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
    add("WARN", "mounts:bind", "%d bind mount(s): NOT in vzdump backups, no PVE snapshots/quotas; need own backup." % len(binds))
    for k, src, tgt, opts in binds:
        note = ""
        if not os.path.exists(src):
            note = " SOURCE MISSING - PVE can refuse to start the guest."
        elif os.path.islink(src):
            note = " SOURCE IS A SYMLINK - PVE needs a real path."
        if SYSTEM_RE.match(src) or src == "/":
            note += " HOST SYSTEM PATH - use a dedicated data dir."
        add("WARN" if note else "INFO", "mount:" + k, "%s -> %s.%s" % (src, tgt, note))
if volumes:
    for k, src, tgt, opts in volumes:
        if k == "rootfs":
            add("INFO", "mount:rootfs", "%s is the root fs (always backed up)." % src)
            continue
        bk = opts.get("backup")
        if bk == "0":
            add("WARN", "mount:" + k, "%s (mp=%s) backup=0: excluded from vzdump." % (src, tgt))
        elif bk == "1":
            add("OK", "mount:" + k, "%s (mp=%s) backup=1: vzdump includes it." % (src, tgt))
        else:
            add("WARN", "mount:" + k, "%s (mp=%s) NO backup=1: excluded by default per docs. Add backup=1 or document why disposable." % (src, tgt))
if devices:
    for k, src, tgt, opts in devices:
        m = opts.get("mode", "")
        if str(m) in ("0666", "666", "0777", "777"):
            add("WARN", "device:" + k, "%s mode=%s world-writable: use specific gid instead." % (src, m))
        else:
            add("INFO", "device:" + k, "%s granted into container; not backed up." % src)

seen = {}
for k, tgt in targets:
    if tgt in seen:
        add("WARN", "mounts:duplicate", "%s and %s both target %s." % (seen[tgt], k, tgt))
    seen[tgt] = k

if paths_arg:
    if ":" not in paths_arg:
        add("WARN", "hardlinks", "--paths needs A:B.")
    else:
        a, b = paths_arg.split(":", 1)
        def dev(p):
            try: return os.stat(p).st_dev
            except OSError: return None
        da, db = dev(a), dev(b)
        if da is None or db is None:
            add("WARN", "hardlinks", "cannot stat both paths; run where they exist as the service sees them.")
        elif da == db:
            add("OK", "hardlinks", "%s and %s same filesystem (dev %d): hardlinks possible." % (a, b, da))
        else:
            add("FAIL", "hardlinks", "%s (dev %d) vs %s (dev %d): DIFFERENT filesystems, no hardlinks; *arr falls back to copy+delete." % (a, da, b, db))

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
    print("  %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(counts.items())))
    print("")
    for lvl, cid, msg in F:
        print("[%s] %s: %s" % (lvl, cid, msg))
    print("")
    print("Mount/feature/privilege changes are APPROVAL-REQUIRED with rollback.")

sys.exit(1 if (strict and any(l == "FAIL" for l, _, _ in F)) else 0)
PY
