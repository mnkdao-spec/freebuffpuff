---
name: proxmox-stack-map
description: Map a Proxmox VE host and everything running on it - nodes, VMs vs LXC containers, storage (ZFS/LVM-thin/directory), bind mounts, network bridges, backup jobs - using read-only pvesh/API calls, then place the music stack inside that map. Use at the start of any Proxmox task, before changing anything on the hypervisor, when a guest or dataset must be located, when asked where a service actually runs, or when translating Docker Compose knowledge into Proxmox terms.
metadata:
  category: proxmox
---

# Proxmox stack map

Read-only orientation. On a hypervisor, guessing costs data - so establish the map first.

## The shape of it
```
Proxmox VE host (Debian + PVE kernel, NOT a Docker host)
  /etc/pve          <- cluster filesystem (pmxcfs), not a normal directory
  vmbr0             <- Linux bridge = your LAN; guests sit on it
  storage: local (dir) | local-zfs (ZFS) | local-lvm (LVM-thin) | NFS/CIFS
  |
  +-- LXC 120  music-stack   Docker Compose inside (nesting=1,keyctl=1)
  |     mp0: /tank/media -> /data          <- bind mount: NOT in vzdump backups
  +-- LXC 121  site          Caddy serving the built static site
  +-- VM  200  docker-vm     Docker on a real kernel (simpler, heavier)
```
Two facts that decide most questions:
- **The PVE host is not a Docker host.** Proxmox's own FAQ says do not run Docker on the
  hypervisor; run it in a guest. Installing Docker on the host is how APT dependency breakage
  starts, and it is the single most common way people damage a working PVE install.
- **Guest containers share the host kernel.** So Docker-in-LXC is nested containerisation, and
  the host's LXC/AppArmor/cgroup versions are part of the Docker stack's dependency tree.

## Read-only inventory
```bash
pveversion -v | head -3                        # PVE + kernel versions
pvesh get /nodes                               # node names, quorum, CPU/RAM load
pvesh get /cluster/resources --type vm | head -40   # every VM and CT: id, name, status, node, mem
pvesh get /nodes/<node>/status                 # loadavg, memory, rootfs
pvesh get /nodes/<node>/storage                # per storage: type, active, avail, total, shared
pvesh get /nodes/<node>/lxc                    # CTs on this node
pvesh get /nodes/<node>/qemu                   # VMs on this node
cat /etc/pve/lxc/<id>.conf                     # one CT's real config (mounts, features, idmap)
cat /etc/pve/jobs.cfg 2>/dev/null              # scheduled backup jobs (PVE 8+)
ls /etc/pve/lxc /etc/pve/qemu-server           # the whole guest inventory, as files
```
For all of it at once: `bash .agents/skills/proxmox-stack-map/scripts/pve-doctor.sh`
(`--json` for machine-readable). It needs `pvesh` or `/etc/pve` and a Python, and it changes nothing.

From another machine, the same data over the API with a **read-only token**:
```bash
curl --cacert pve-ca.pem -H 'Authorization: PVEAPIToken=monitor@pve!inventory=<SECRET>' \
  'https://pve.example.lan:8006/api2/json/cluster/resources?type=vm'
```
Create that credential properly - never hand out an admin password:
```bash
pveum user add monitor@pve
pveum user token add monitor@pve inventory --privsep 1     # secret shown ONCE
pveum acl modify / --users  monitor@pve         --roles PVEAuditor
pveum acl modify / --tokens 'monitor@pve!inventory' --roles PVEAuditor
pveum user permissions 'monitor@pve!inventory' --path /    # what it can actually do
```
`PVEAuditor` is read-only. A token's effective rights are the **intersection** of the user's and
the token's permissions, so `--privsep 1` plus a small ACL is the correct shape.

## Placing the music stack in the map
Work down this list and stop at the first thing you cannot answer:
1. Which guest id hosts Docker Compose, and is it a VM or a CT?
2. For that guest: which host paths are bind-mounted, and where do those paths really live
   (ZFS dataset? LVM-thin volume? NAS share? USB disk)?
3. Is the media library on the same filesystem as the download folder *as the guest sees it*?
   (Hardlinks are the reason this matters - see `proxmox-storage-and-mounts`.)
4. What backs this guest up, and is the library inside or outside that backup?
5. How is the LAN exposed - bridge, VLAN, firewall, reverse proxy, Cloudflare Tunnel/Tailscale?

## Hard rules
- **Read-only by default.** No `qm`/`pct set`, no `qm start`, no storage or cluster edits in a
  mapping turn. Changing a running guest's mounts is an APPROVAL-REQUIRED action.
- **Never edit `/etc/pve` by hand** while debugging. It is FUSE-backed by `pmxcfs`; if it looks
  empty or read-only, suspect quorum or `pve-cluster`, not the files.
- Do not read or echo secrets from `/etc/pve/priv`, `/etc/apt/auth.conf.d`, or a token file.
- Do not try to "fix" a subscription login notice by patching PVE's web files. The supported
  change is the repository, not the banner.

## Output format
```
HOST:       pve <version>, kernel, node name, quorum state
GUESTS:     id -> kind (VM/CT), name, status, node, purpose
DOCKER:      which guest, and whether it is VM or LXC (with features)
STORAGE:    store -> type, size, free, what lives on it
MOUNTS:     guest -> host path -> guest path -> backed up? (yes/no/bind)
NETWORK:    bridge/VLAN -> which guests, what is publicly reachable
BACKUPS:    job -> scope -> mode -> target -> retention
UNKNOWN:    what could not be determined, and the exact command that would settle it
```
