---
name: proxmox-upgrade-safety
description: Plan and verify Proxmox VE updates and major upgrades (8 to 9, point releases) without losing guests - channel hygiene, pve8to9 checks, space and backup prerequisites, known breakage, post-upgrade verification. Use before apt on a hypervisor, on PVE update errors, post-update nested-Docker breakage, or "safe to upgrade?".
metadata:
  category: proxmox
---

# Upgrade safety

Hypervisor upgrades can lose everything at once. Written plan, not bare `apt upgrade`.

## Know your version
`pveversion -v`; `pve8to9 --full` (8→9 only; read every line); `df -h /`;
sources files; `pve-doctor.sh` (repos/space/guests/backups). Current: **PVE 9.x** (Debian 13);
**8.4 support ended Aug 2026** — still on 8.x means plan the move.

## Repo hygiene (most "update broken" reports)
`pve-enterprise` needs a subscription → else disable, use `pve-no-subscription`.
Login notice ≠ repo access — never patch web files (updates overwrite). No `pve-test` daily driving.
**Never mix Debian suites** (deb822 `.sources`, matching suite; doctor fails loudly on mixes).
Keep base Debian repos for the same suite.

## Before major upgrades
1. **Current tested backup of every guest** (+off-box copy ideally; same-storage snapshot ≠ backup).
2. **Space:** 8→9 needs ~5 GB on `/`, recommends >10 GB. 3. **Read target release notes**
   (interface naming, **cgroup v1 removal** in PVE 9, passthrough, old CPUs).
4. **Snapshot current state** (`pveversion`, lists, configs, `/etc/pve` + network copies).
5. Point releases: update after notes. Major: latest 8.4 first, then the official guide — never
   improvised suite conversions or bare `dist-upgrade`.

## Never on the host
No Docker on PVE (FAQ; conflicting packages, APT breakage). No stray third-party repos.
No `unconfined` AppArmor "fixes" for nested Docker.

## Nested-Docker lesson
Late-2025 runc/AppArmor breakage = `lxc-pve` package fix, not AppArmor downgrade.
**Host updates are Docker updates** for Docker-in-LXC.

## Post-upgrade verify (in order)
`pveversion` (new kernel booted) → `pvesm status` (all active) → guest lists → guests start
(first error counts) → `docker info` (driver, not vfs) → compose dry-run → `docker ps` healthy →
iGPU/passthrough/media-stack end-to-end. Capture versions before changing policy on failures.

## Rollback reality
No supported downgrade. Rollback = tested guest backups + saved configs + noted previous kernel
(+reinstall+restore if needed). Write it down first.

## Hard rules
No major upgrade/dist-upgrade/hypervisor reboot without explicit instruction. Never disable
repos/security to make updates "work". Verified only after guests+storage+nested-Docker check
(`apt` exit 0 ≠ verified).
