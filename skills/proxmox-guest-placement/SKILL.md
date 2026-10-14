---
name: proxmox-guest-placement
description: Decide and audit where a Docker workload lives on Proxmox - VM versus unprivileged LXC - including nesting/keyctl, uid/gid mapping, AppArmor and cgroup v2 limits, cloud-init templates, IaC options and exact single-container audits. Use when creating guests, when Docker-in-LXC misbehaves, for nobody-owned files, or "VM or container?".
metadata:
  category: proxmox
---

# Guest placement (VM vs LXC)

| | LXC (unprivileged) | VM (QEMU) |
|---|---|---|
| Overhead | shares kernel; light | own kernel; needs RAM |
| Docker | **nested** (host kernel/LXC/AppArmor/cgroup dependent) | normal Docker |
| Storage | OverlayFS-on-ZFS pitfalls (`vfs` fallback slow) | ext4/XFS of choice |
| Snapshots | need capable storage; **bind mounts never backed up** | full semantics |
| Isolation | weaker | strong |
| iGPU | easy device-node share | full PCIe passthrough (host loses device) |

**Default for Compose media stack:** small **VM** (VirtIO, qemu-guest-agent) — FAQ-steered,
low-maintenance. **LXC** for low overhead if you accept nesting debug. **Never Docker on the host.**

## LXC baseline
`pct set <id> --features nesting=1,keyctl=1` (`nesting` for runtime bits, `keyctl` for
keyring calls; `fuse=1` only for real FUSE use — host FUSE bind-mounted in preferred).
Keep **unprivileged**. Never `unconfined` AppArmor to "fix" Docker (2025 runc breakage =
`lxc-pve` 6.0.5-2 package fix). **cgroup v2 only** on PVE 9. Kernel modules live on the **host**.

## Unprivileged mapping
CT uid 0 = host uid 100000 by default → foreign-owned binds show `nobody`.
Compare `stat` host vs `pct exec` guest; fix via `lxc.idmap`/mp idmap + subuid/subgid, or own
data as mapped uid. Never `chmod 777` / `chown -R` media.

## Audit one container (read-only)
`lxc-audit.sh <id> [--config path] [--paths A:B]` — unprivileged/features, every mount + backup
consequence, symlink sources, duplicate targets, writable devices, same-filesystem check.

## Repeatable guests
Cloud-init template + clone = native path. Terraform `bpg/provider` (community, 0.x, some SSH ops),
Ansible `community.proxmox`, Packer integration — all community; pin and verify. Native
`pvesh/qm/pct/pvesm` is the supported interface. IaC when rebuilding often, not for 3 guests.

## Hard rules
One change per guest per turn + stated rollback; snapshot first (bind-mount snapshots ≠ backups);
never widen privileges as a diagnostic without saying so.
