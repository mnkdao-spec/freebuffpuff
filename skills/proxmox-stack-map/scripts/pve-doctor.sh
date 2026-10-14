#!/usr/bin/env bash
# pve-doctor.sh - READ-ONLY Proxmox VE host audit. Changes nothing, starts nothing, edits nothing.
# Reports disk/rootfs pressure, storage health, guest mounts that are NOT covered by backups,
# risky guest settings, repository hygiene, pending updates, ZFS ARC and pool health.
# Exit codes: 0 = report produced (findings are output, not errors), 2 = usage, 3 = not a PVE host,
#             4 = needs a JSON-capable Python (or set PYTHON=/path/to/python3).
#
# Usage: pve-doctor.sh [--json] [--quiet]
set -uo pipefail

if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v python3 || command -v python || true)"
fi
if [ -z "$PY" ]; then
  echo "pve-doctor: needs python3 (or python) to analyse the report. On PVE: apt install python3" >&2
  echo "pve-doctor: or set PYTHON=/path/to/python3" >&2
  exit 4
fi

MODE=text
while [ $# -gt 0 ]; do case "$1" in
  --json) MODE=json ;; --quiet) exec >/dev/null ;; *) echo "unknown flag: $1" >&2; exit 2 ;;
esac; shift; done

PVE_ETC="${PVE_ETC:-/etc/pve}"
APT_ETC="${APT_ETC:-/etc/apt}"
if [ ! -d "$PVE_ETC" ] && ! command -v pvesh >/dev/null 2>&1; then
  echo "pve-doctor: this does not look like a Proxmox VE host (no /etc/pve and no pvesh)." >&2
  echo "pve-doctor: run it on the PVE host, or over SSH: ssh root@pve 'bash -s' < pve-doctor.sh" >&2
  exit 3
fi

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t pvedoctor)"; trap 'rm -rf "$TMP"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }
grab() { # grab <outfile> <cmd...>
  local out="$1"; shift
  if have "$1"; then "$@" >"$out" 2>/dev/null || : ; else : >"$out"; fi
}

have pveversion    && pveversion -v > "$TMP/pveversion" 2>/dev/null || : > "$TMP/pveversion"
have pvesh         && pvesh get /nodes --output-format json > "$TMP/nodes.json" 2>/dev/null || : > "$TMP/nodes.json"
NODE="$(head -c 2000 "$TMP/nodes.json" 2>/dev/null | "$PY" -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print([n["node"] for n in d if n.get("node")][0] if d else "")
except Exception: print("")' 2>/dev/null)"
if [ -n "$NODE" ] && have pvesh; then
  pvesh get "/nodes/$NODE/status"               --output-format json > "$TMP/node_status.json" 2>/dev/null || : > "$TMP/node_status.json"
  pvesh get "/nodes/$NODE/storage"              --output-format json > "$TMP/storage.json"     2>/dev/null || : > "$TMP/storage.json"
  pvesh get "/cluster/resources" --type vm      --output-format json > "$TMP/resources.json"   2>/dev/null || : > "$TMP/resources.json"
fi
have zpool         && zpool list -H -o name,health,capacity,size,alloc > "$TMP/zpool" 2>/dev/null || : > "$TMP/zpool"
have apt-get       && apt list --upgradable 2>/dev/null > "$TMP/upgradable" || : > "$TMP/upgradable"
df -h / 2>/dev/null > "$TMP/df_root" || : > "$TMP/df_root"
have docker        && echo "docker CLI present on host: $(command -v docker)" > "$TMP/docker" || : > "$TMP/docker"

NODE_NAME="$NODE" "$PY" - "$TMP" "$PVE_ETC" "$APT_ETC" "$MODE" <<'PY'
import glob, json, os, sys, re
tmp, pve_etc, apt_etc, mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
F = []  # findings: (level, id, message)

def add(level, cid, msg):
    F.append((level, cid, msg))

def human(n):
    try:
        n = float(n)
    except Exception:
        return str(n)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(n) < 1024 or unit == "TiB":
            return "%.1f %s" % (n, unit)
        n /= 1024.0

def read(name):
    p = os.path.join(tmp, name)
    try:
        return open(p, errors="replace").read()
    except Exception:
        return ""

def jread(name):
    raw = read(name).strip()
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None

# --- versions ---------------------------------------------------------------
pvever = read("pveversion").splitlines()
version_line = pvever[0] if pvever else ""
if not version_line:
    add("WARN", "version", "pveversion produced nothing - cannot confirm the PVE version.")

# --- root filesystem --------------------------------------------------------
df_root = read("df_root").splitlines()
if len(df_root) >= 2:
    parts = df_root[1].split()
    if len(parts) >= 6:
        total, used, avail, pct = parts[1], parts[2], parts[3], parts[4]
        try:
            p = int(pct.rstrip("%"))
        except ValueError:
            p = 0
        msg = "/ (root) is %s of %s used, %s free" % (pct, total, avail)
        if p >= 90:
            add("FAIL", "rootfs", msg + " - a full root filesystem breaks backups and can damage guests. Investigate with `du -x -d1 /` and check that any external disk is actually mounted.")
        elif p >= 80:
            add("WARN", "rootfs", msg + " - plan some headroom before an upgrade (the 8->9 guide wants >10 GB free).")
        else:
            add("OK", "rootfs", msg)
else:
    add("WARN", "rootfs", "could not read `df -h /`.")

# --- storage ---------------------------------------------------------------
st = jread("storage.json")
if isinstance(st, list) and st:
    for s in st:
        sid = s.get("storage", "?")
        typ = s.get("type", "?")
        active = s.get("active", 0)
        total = s.get("total") or 0
        avail = s.get("avail") or 0
        shared = s.get("shared", 0)
        if not active:
            add("FAIL", "storage:" + sid, "storage %r (%s) is inactive - it is not mounted. That is the classic cause of data quietly landing on / instead of the disk." % (sid, typ))
            continue
        if total:
            usedpct = 100.0 * (total - avail) / total
            if usedpct >= 95:
                add("FAIL", "storage:" + sid, "%s (%s) is %.0f%% full (%s free). Thin pools and full ZFS pools cause guest I/O errors and filesystem damage." % (sid, typ, usedpct, human(avail)))
            elif usedpct >= 85:
                add("WARN", "storage:" + sid, "%s (%s) is %.0f%% full." % (sid, typ, usedpct))
            else:
                add("OK", "storage:" + sid, "%s (%s) %.0f%% used, %s free%s" % (sid, typ, usedpct, human(avail), " (shared)" if shared else ""))
        else:
            add("OK", "storage:" + sid, "%s (%s) active" % (sid, typ))
else:
    add("WARN", "storage", "no storage inventory returned by `pvesh get /nodes/<node>/storage`.")

# --- ZFS pools and ARC -----------------------------------------------------
zp = [l.split() for l in read("zpool").splitlines() if l.strip()]
for row in zp:
    if len(row) >= 2:
        name, health = row[0], row[1]
        if health.upper() != "ONLINE":
            add("FAIL", "zpool:" + name, "pool %s health is %s - read the exact error with `zpool status -x` before writing more data to it." % (name, health))
        else:
            add("OK", "zpool:" + name, "pool %s ONLINE" % name)

arc_max_file = "/sys/module/zfs/parameters/zfs_arc_max"
arc_max = 0
try:
    arc_max = int(open(arc_max_file).read().strip())
except Exception:
    pass
meminfo = ""
try:
    meminfo = open("/proc/meminfo").read()
except Exception:
    pass
mem_total_kb = 0
m = re.search(r"MemTotal:\s+(\d+) kB", meminfo)
if m:
    mem_total_kb = int(m.group(1))
if arc_max == 0 and os.path.exists(arc_max_file):
    hint = ""
    for p in ("/etc/modprobe.d/zfs.conf", "/etc/modprobe.d/zfs.conf.d"):
        try:
            if os.path.exists(p):
                txt = open(p, errors="replace").read()
                hint = " found: " + ", ".join(re.findall(r"zfs_arc_max=\S+", txt)) if re.findall(r"zfs_arc_max=\S+", txt) else " (no zfs_arc_max line)"
                break
        except Exception:
            pass
    add("WARN", "zfs-arc", "zfs_arc_max is 0 (no runtime limit). PVE >=8.1 normally sets ~10%% of RAM capped at 16 GiB in /etc/modprobe.d/zfs.conf;%s. Host RAM: %.1f GiB. Check the module option before blaming ZFS for 'eating' memory." % (hint or " no such file", mem_total_kb / 1048576.0))
elif arc_max:
    add("OK", "zfs-arc", "zfs_arc_max = %s (host RAM %.1f GiB)" % (human(arc_max), mem_total_kb / 1048576.0))

# --- guests ---------------------------------------------------------------
res = jread("resources.json")
guests = []
if isinstance(res, list):
    for g in res:
        if g.get("type") in ("lxc", "qemu") and g.get("vmid"):
            guests.append(g)
if guests:
    by = {}
    for g in guests:
        by.setdefault(g.get("type"), []).append(g)
    parts = []
    for kind, lst in sorted(by.items()):
        running = sum(1 for g in lst if g.get("status") == "running")
        parts.append("%s %d total / %d running" % ({"lxc": "CT", "qemu": "VM"}[kind], len(lst), running))
    add("OK", "guests", "; ".join(parts) + " - " + ", ".join(sorted("%d %s" % (g["vmid"], g.get("name", "?")) for g in guests)[:12]))
else:
    add("WARN", "guests", "no guest inventory returned by `pvesh get /cluster/resources --type vm`.")

# --- guest configs: mounts NOT covered by backups, risky settings -----------
def parse_kv(line):
    if ":" not in line:
        return None, None
    k, v = line.split(":", 1)
    return k.strip(), v.strip()

conf_files = []
for pat, kind in ((os.path.join(pve_etc, "lxc", "*.conf"), "lxc"),
                  (os.path.join(pve_etc, "qemu-server", "*.conf"), "qemu")):
    for p in sorted(glob.glob(pat)):
        conf_files.append((p, kind))

if not conf_files:
    add("WARN", "guests:config", "no guest config files readable under %s (permissions, or not a PVE host)." % pve_etc)

bind_mounts, unbacked, risky = [], [], []
for path, kind in conf_files:
    vmid = os.path.basename(path).split(".")[0]
    try:
        lines = open(path, errors="replace").read().splitlines()
    except Exception:
        continue
    cfg = {}
    for line in lines:
        if line.strip().startswith("#") or not line.strip():
            continue
        k, v = parse_kv(line)
        if k:
            cfg.setdefault(k, []).append(v)
    for k in list(cfg):
        if not re.match(r"^(mp|rootfs|dev)\d+$", k):
            continue
        for v in cfg[k]:
            first = v.split(",")[0]
            opts = dict(p.split("=", 1) for p in v.split(",")[1:] if "=" in p)
            target = opts.get("mp", "?")
            is_bind = first.startswith("/") and not first.startswith("/dev/")
            is_dev = first.startswith("/dev/") or k.startswith("dev")
            if is_dev:
                mode_opt = opts.get("mode", "")
                extra = ""
                if mode_opt in ("0666", "666", "0x1b6"):
                    extra = " It is also mode=%s (world-readable/writable) - prefer a specific gid (e.g. the host 'render' group) over 0666." % mode_opt
                if is_dev:
                    risky.append("CT/VM %s: %s (%s) is a device passthrough; it is never in a vzdump backup and has no snapshot support.%s" % (vmid, first, k, extra))
                else:
                    risky.append("CT/VM %s: %s -> %s is a device mount; it is never in a vzdump backup.%s" % (vmid, first, target, extra))
            elif is_bind:
                bind_mounts.append((vmid, first, target, opts.get("ro"), opts.get("backup")))
                if os.path.exists(first) and os.path.islink(first):
                    risky.append("CT/VM %s: bind-mount source %s is a symlink; PVE requires a real path and can refuse to start the guest." % (vmid, first))
                if re.match(r"^/(etc|var|usr|root|boot|bin|sbin|lib)(/|$)", first) or first == "/":
                    risky.append("CT/VM %s: bind-mount source %s is a host system path; use a dedicated data directory instead." % (vmid, first))
            else:
                bk = opts.get("backup")
                if bk == "0":
                    unbacked.append("guest %s: volume %s (mp=%s) has backup=0 - excluded from vzdump on purpose. Confirm that is intended." % (vmid, first, target))
                elif bk != "1":
                    unbacked.append("guest %s: volume %s (mp=%s) has no backup=1. Additional mount points are NOT included in backups by default (Backup and Restore chapter); only the GUI's mount-point dialog ticks the box for you. Add backup=1 or document why it is disposable." % (vmid, first, target))
    if kind == "lxc":
        unpriv = (cfg.get("unprivileged") or ["0"])[0]
        feats = (cfg.get("features") or [""])[0]
        if unpriv != "1":
            risky.append("CT %s: unprivileged is not 1 - privileged containers are for trusted environments only (a container escape is a host escape)." % vmid)
        if "nesting=1" in feats and "keyctl=1" not in feats:
            risky.append("CT %s: features 'nesting=1' without 'keyctl=1' - Docker/systemd keyring calls commonly fail in unprivileged containers without it." % vmid)
        if "unconfined" in feats:
            risky.append("CT %s: an unconfined AppArmor profile disables a real boundary layer; Proxmox documents this as not recommended for production." % vmid)

if bind_mounts:
    add("WARN", "mounts:bind", "%d bind mount(s) across guests. Bind mounts are NOT included in vzdump backups and cannot be snapshotted by the PVE storage subsystem - they need their own backup plan:" % len(bind_mounts))
    for vmid, src, tgt, ro, bk in bind_mounts[:12]:
        add("WARN", "mounts:bind", "  guest %s: %s -> %s%s" % (vmid, src, tgt, " (ro)" if ro == "1" else ""))
else:
    add("OK", "mounts:bind", "no bind mounts found in guest configs (everything is storage-backed, so vzdump can see it).")

for u in unbacked[:12]:
    add("WARN", "mounts:backup0", u)
for r in risky[:20]:
    add("WARN", "guest:setting", r)
if not risky:
    add("OK", "guest:setting", "no unprivileged/dev/path problems found in guest configs.")

# --- backup jobs ----------------------------------------------------------
jobs = ""
for cand in (os.path.join(pve_etc, "jobs.cfg"), os.path.join(pve_etc, "vzdump.cron")):
    try:
        jobs += open(cand, errors="replace").read()
    except Exception:
        pass
if not jobs.strip():
    add("FAIL", "backups", "no scheduled backup job found (%s/jobs.cfg or vzdump.cron missing or empty). Scheduled, tested backups are the only thing that makes a homelab recoverable." % pve_etc)
else:
    covered, allflag = set(), False
    for m in re.finditer(r"vmid\s*:?\s*([0-9,\- ]+)", jobs):
        for part in m.group(1).strip().replace(" ", "").split(","):
            if "-" in part:
                a, _, b = part.partition("-")
                if a.isdigit() and b.isdigit():
                    covered.update(range(int(a), int(b) + 1))
            elif part.isdigit():
                covered.add(int(part))
            elif part == "all":
                allflag = True
    if allflag:
        adds = "job(s) target 'all' guests"
    else:
        present = {int(g["vmid"]) for g in guests}
        missing = sorted(present - covered)
        adds = "%d guest(s) covered by id" % len(covered & present)
        if missing:
            add("WARN", "backups:coverage", "guests with no backup job: %s - either add them or document why they are disposable." % ", ".join(str(x) for x in missing))
    modes = sorted(set(re.findall(r"mode\s+(\w+)", jobs))) or ["snapshot (default)"]
    add("OK", "backups", "backup job found (%s), mode(s): %s. A backup that has never been restored is a hypothesis - schedule a restore drill." % (adds, ", ".join(modes)))

# --- repositories ---------------------------------------------------------
repo_text, repo_files = [], []
for pat in (os.path.join(apt_etc, "sources.list"), os.path.join(apt_etc, "sources.list.d", "*.list"), os.path.join(apt_etc, "sources.list.d", "*.sources")):
    for p in sorted(glob.glob(pat)):
        try:
            txt = open(p, errors="replace").read()
        except Exception:
            continue
        repo_files.append(p)
        for line in txt.splitlines():
            s = line.strip()
            if s.startswith("#") or not s:
                continue
            repo_text.append((p, s))
if not repo_text:
    add("WARN", "repos", "no APT sources readable under %s." % apt_etc)
else:
    suites = set()
    ent, nosub, test = [], [], []
    for p, s in repo_text:
        for su in re.findall(r"\b(bookworm|trixie|bullseye|forky)\b", s):
            suites.add(su)
        if "enterprise.proxmox.com" in s:
            ent.append(p)
        if "download.proxmox.com" in s and "no-subscription" in s:
            nosub.append(p)
        if "download.proxmox.com" in s and "/test" in s:
            test.append(p)
    auth = any(os.path.exists(x) for x in ("/etc/apt/auth.conf.d/pve.conf", "/etc/apt/auth.conf"))
    if ent and not auth:
        add("WARN", "repos:enterprise", "an enterprise.proxmox.com source is enabled but no APT auth file was found. APT errors from it are not general PVE update failures - disable it or configure a subscription.")
    if nosub:
        add("OK", "repos:no-subscription", "No-subscription repository configured (%s)." % ", ".join(sorted(os.path.basename(x) for x in set(nosub))))
    if test:
        add("WARN", "repos:test", "a pve-test repository is enabled. That is a developer/testing repo, not a daily driver.")
    if len(suites) > 1:
        add("FAIL", "repos:suite", "mixed Debian suites found across sources: %s. Mixing suites is how a PVE host ends up in an unsupported, hard-to-repair package state." % ", ".join(sorted(suites)))
    elif suites:
        add("OK", "repos:suite", "Debian suite(s) in use: %s" % ", ".join(sorted(suites)))
    if not ent and not nosub:
        add("WARN", "repos", "neither enterprise nor no-subscription Proxmox sources were recognised - check %s by hand." % ", ".join(sorted(repo_files)) or "APT sources")

# --- updates, host docker -------------------------------------------------
up = [l for l in read("upgradable").splitlines() if l.strip() and not l.startswith("Listing")]
if up:
    add("WARN", "updates", "%d package(s) upgradable (apt list --upgradable). Read the release notes, snapshot/back up guests, then `apt update && apt dist-upgrade` - or follow the 8->9 guide for a major jump." % len(up))
else:
    add("OK", "updates", "no upgradable packages reported (or apt list unavailable).")

dk = read("docker").strip()
if dk:
    add("FAIL", "host:docker", "a Docker CLI is installed ON the PVE host (%s). Proxmox's FAQ says not to run Docker on the hypervisor: it conflicts with PVE's package set, the PVE kernel and its own bridge/firewall. Run Docker in a VM or an unprivileged LXC instead." % dk)

# --- output ---------------------------------------------------------------
order = {"FAIL": 0, "WARN": 1, "OK": 2, "INFO": 3}
F.sort(key=lambda f: order.get(f[0], 9))
counts = {}
for lvl, _, _ in F:
    counts[lvl] = counts.get(lvl, 0) + 1

if mode == "json":
    print(json.dumps({
        "tool": "pve-doctor",
        "version_line": version_line,
        "node": os.environ.get("NODE_NAME", ""),
        "summary": counts,
        "findings": [{"level": l, "id": i, "message": m} for l, i, m in F],
    }, indent=2))
    sys.exit(0)

print("pve-doctor - read-only Proxmox VE audit (nothing was changed)")
if version_line:
    print("  " + version_line)
print("  %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(counts.items(), key=lambda kv: order.get(kv[0], 9))))
print("")
for lvl, cid, msg in F:
    print("[%s] %s: %s" % (lvl, cid, msg))
print("")
print("Reminder: [WARN] and [FAIL] are findings, not failures of the check. This script never")
print("changes state. Anything in guest configs (mounts, features, backup flags) is an")
print("APPROVAL-REQUIRED change to make through the PVE UI or `pct set`, one guest at a time.")
PY
