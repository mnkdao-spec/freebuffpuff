---
name: proxmox-stack-map
description: Map a Proxmox VE host and everything on it - nodes, VMs vs LXC, storage, bind mounts, bridges, backup jobs - via read-only pvesh/API calls, then place the music stack in that map. Use at the start of any Proxmox task, before hypervisor changes, to locate guests/datasets, or translating Compose knowledge to Proxmox.
metadata:
  category: proxmox
---

# Proxmox stack map

Read-only orientation. On a hypervisor, guessing costs data.

## Shape
PVE host (Debian + PVE kernel, NOT a Docker host) → vmbr0 (LAN bridge) → guests.
Example: LXC 120 music-stack (Docker, nesting=1,keyctl=1; mp0 bind → NOT in vzdump),
LXC 121 site (Caddy), VM 200 docker-vm.

Two deciding facts: **host is not a Docker host** (FAQ; host Docker = APT breakage);
**guests share the host kernel** (Docker-in-LXC = nested; host LXC/AppArmor/cgroup versions matter).

## Read-only inventory
`pveversion -v`; `pvesh get /nodes`, `/cluster/resources --type vm`, `/nodes/<node>/status|storage|lxc|qemu`;
`cat /etc/pve/lxc/<id>.conf`, `/etc/pve/jobs.cfg`; `ls /etc/pve/lxc /etc/pve/qemu-server`.
Or all-at-once: `pve-doctor.sh [--json]` (needs pvesh or /etc/pve + Python; changes nothing).
Remote: same via API with a **read-only token** (`PVEAuditor` role + `--privsep 1`; effective
rights = intersection of user and token rights).

## Place the music stack
1. Which guest hosts Compose (VM or CT)? 2. Host bind paths → real storage (ZFS? LVM-thin? NAS?)?
3. Library vs downloads same filesystem *as the guest sees it* (hardlinks)?
4. What backs up the guest — library inside or outside that backup?
5. LAN exposure (bridge/VLAN/firewall/proxy/tunnel)?

## Hard rules
- **Read-only default.** No `qm`/`pct set`, no starts, no storage/cluster edits in mapping turns.
- **Never hand-edit `/etc/pve`** (pmxcfs FUSE; empty/read-only ⇒ quorum/cluster issue).
- No secrets from `/etc/pve/priv`, auth configs, token files. No banner-patching for subscription nags.

## Output
```
HOST / GUESTS (id→kind/name/status/purpose) / DOCKER (which guest, VM-or-LXC) / STORAGE / MOUNTS (→backed-up?) / NETWORK / BACKUPS (job→scope→mode→target→retention) / UNKNOWN (+settling command)
```
