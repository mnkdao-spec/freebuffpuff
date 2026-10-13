---
name: proxmox-upgrade-safety
description: Plan and verify Proxmox VE updates and major upgrades (8 to 9, point releases) without losing guests - release-channel hygiene, the pve8to9 check, free-space and backup prerequisites, known breakage (nested Docker/AppArmor, cgroup v1 removal, network interface naming, passthrough), what to never install on the host, and a post-upgrade verification checklist. Use before running apt upgrade on a hypervisor, when PVE update errors appear, when a container's Docker stopped working after a host update, or when asked whether it is safe to upgrade.
metadata:
  category: proxmox
---

# Upgrade safety

Hypervisor upgrades are the one place a homelab can lose everything at once. Treat it as a
change with a written plan, not as an `apt upgrade`.

## Know what you are on
```bash
pveversion -v | head -3          # PVE + kernel + QEMU + LXC versions
pve8to9 --full                   # ONLY on a host being moved 8 -> 9; read every line
df -h /                          # free space on the root filesystem
cat /etc/apt/sources.list /etc/apt/sources.list.d/*.{list,sources} 2>/dev/null
bash .agents/skills/proxmox-stack-map/scripts/pve-doctor.sh        # flags repos, space, guests, backups
```
Version reality to check rather than assume: the current line is **PVE 9.x** (based on Debian 13
"Trixie"); **PVE 8.4** security/critical support ended in **August 2026**. If you are still on 8.x,
that is a reason to plan the move, not to panic-install.

## Repository hygiene (the source of most "update is broken" reports)
- **`pve-enterprise` needs a subscription.** Without one, disable it and use
  `pve-no-subscription`. An `enterprise.proxmox.com` error in `apt` is not a general PVE failure.
- The subscription **login notice** is a separate thing from repository access. Do not patch PVE's
  web files to hide it: those patches get overwritten by updates and leave you debugged in a state
  nobody supports.
- **`pve-test` is not a daily driver.**
- **Never mix Debian suites** (e.g. a leftover `bookworm` line next to `trixie`). On PVE 9 use the
  deb822 `.sources` format with the matching suite. `pve-doctor.sh` fails loudly on mixed suites.
- Keep the base Debian repos for the same suite enabled.

## Prerequisites before a major upgrade
1. **A current, tested backup of every guest** - and, ideally, an off-box copy. A snapshot on the
   same storage is not that.
2. **Free space:** the 8->9 guide requires at least ~5 GB on `/` and recommends more than 10 GB.
3. **Read the release notes** for the target version before you touch anything. The guide also
   lists risks worth checking on your hardware: network interface naming, **cgroup v1 removal**
   (PVE 9 is cgroup v2 only), PCI passthrough, and older CPUs.
4. **Note your current state** so "is it broken?" is answerable: `pveversion -v`, `pct list`,
   `qm list`, `pvesm status`, `cat /etc/pve/lxc/*.conf`, plus a copy of `/etc/pve` (guest configs
   live there) and `/etc/network/interfaces`.
5. **Point releases (e.g. 9.1 -> 9.2):** ordinary update after reading the notes. **Major jumps
   (8 -> 9):** follow the official guide - first bring the host to the latest 8.4, then upgrade.
   Do not improvise a Debian suite conversion or a bare `dist-upgrade`.

## What to never do on the host
- **Do not install Docker on the PVE host.** The FAQ says not to; it pulls conflicting packages
  against the PVE kernel and package set, and it is the classic route to APT breakage.
- Do not add unrelated third-party repositories.
- Do not "fix" a container's nested Docker by setting the AppArmor profile to `unconfined`.

## The lesson from the nested-Docker breakage
A late-2025 `runc` AppArmor change broke Docker inside unprivileged containers (sysctl/procfs
reopen denied). Proxmox shipped a fixed `lxc-pve`; the correct response was to update the package,
not to disable AppArmor or downgrade `runc`. The general lesson stands: **Docker-in-LXC depends on
host LXC, AppArmor, cgroup and `runc` versions**, so a host update is also a Docker update.

## Post-upgrade verification (in this order)
```bash
pveversion -v                                   # new version + kernel; reboot into the new kernel
pvesm status                                    # every storage active (a missing mount fills /)
pct list; qm list                               # guests present, expected state
for id in <your ids>; do pct start $id; done    # guests actually start - read the first error
# inside the Docker guest:
docker info | head -20                          # storage driver, not 'vfs'
docker compose up -d --dry-run 2>/dev/null || docker compose config -q
docker ps --format '{{.Names}}\t{{.Status}}'    # everything healthy, not restart-looping
```
Then verify the things the guides warn about: the iGPU (`/dev/dri` mode/gid may need re-checking
after a kernel change), PCIe passthrough VMs, and the media stack end to end. If a nested runtime
misbehaves, capture versions (`pveversion`, `lxc-ls --version`, `docker info`, `containerd -v`,
`runc -v`) **before** changing policy.

## Rollback reality
There is no supported downgrade path. Your rollback plan is: a tested guest backup, the saved
`/etc/pve` and `/etc/network/interfaces` copies, a note of the previous kernel
(`proxmox-boot-tool kernel list`), and - if it comes to it - a reinstall plus restore. Write that
plan down before starting; "I would restore from backup" is only true if you have restored one.

## Hard rules
- Never run a major upgrade, `dist-upgrade`, or a reboot of the hypervisor without an explicit
  instruction in that message.
- Never disable a repository or a security feature to make an update "work" - report the conflict.
- Report the upgrade as verified only after guests, storage and the nested Docker stack are
  checked. "apt exited 0" is not a verification.
