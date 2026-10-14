---
name: proxmox-guest-placement
description: Decide and audit where a Docker workload should live on Proxmox - VM versus unprivileged LXC - including nesting=1/keyctl=1, unprivileged uid/gid mapping, AppArmor and cgroup v2 limits, cloud-init templates, IaC options (Terraform bpg provider, Ansible community.proxmox) and the exact audit of one container's config. Use when creating a guest for the music stack or the site, when Docker inside an LXC misbehaves, when a container shows nobody-owned files, or when asked "should this be a VM or a container".
metadata:
  category: proxmox
---

# Guest placement (VM vs LXC)

## The decision, in one table

| | LXC (unprivileged) | VM (QEMU) |
|---|---|---|
| Overhead | shares the host kernel; very light | own kernel; needs RAM for the guest |
| Docker inside | **nested** containerisation; depends on host kernel, LXC, AppArmor, cgroups | normal Docker; the case its docs are written for |
| Storage driver | can hit OverlayFS-on-ZFS issues (`vfs` fallback = slow, huge) | you choose ext4/XFS; no nesting problem |
| Snapshots/backups | CT snapshots need snapshot-capable storage; **bind mounts are never backed up** | full VM snapshot/backup semantics |
| Isolation | weaker; a privileged CT escape is a host escape | strong boundary |
| iGPU / `/dev/dri` | device-node sharing is easy | needs full PCI passthrough (host loses the device) |
| Migration | `pct migrate` (local storage must move with it) | `qm migrate` |

**Default for a Docker Compose media stack:** one small **VM** (Debian/Ubuntu, VirtIO disks,
`qemu-guest-agent`) is the low-maintenance answer, and it is what Proxmox's own FAQ steers toward
- orchestration, live migration and maximum isolation belong in a QEMU guest.
**Choose an unprivileged LXC when** you want the low overhead and you accept debugging nesting: it
is extremely common and works well, but a PVE/LXC/`runc` update can change the rules under you.
**Never** run Docker on the PVE host itself.

## Creating / fixing the LXC
```bash
# the baseline for a Docker-in-LXC container
pct set <id> --features nesting=1,keyctl=1
pct config <id>                    # verify what is actually written
pct start <id> --debug             # when it will not start: read the first real error
```
- `nesting=1` exposes the procfs/sysfs bits a nested runtime needs. `keyctl=1` is what unprivileged
  containers usually need for systemd/Docker keyring calls. Add `fuse=1` only if you actually use
  `fuse-overlayfs` - and note Proxmox **discourages FUSE mounts inside containers** for
  snapshot/suspend backups (prefer a host FUSE mount bind-mounted in).
- Keep the container **unprivileged**. Privileged containers are for trusted environments only.
- Do **not** set the AppArmor profile to `unconfined` to "fix" Docker. Read `dmesg`/`journalctl`
  for the denial and update the packages instead: a late-2025 `runc` AppArmor change broke nested
  Docker and was fixed in `lxc-pve` 6.0.5-2. Downgrading or disabling AppArmor is not the fix.
- **cgroup v2 only** on PVE 9. Guest OSes need a systemd that supports a pure cgroup-v2
  environment. If a nested runtime breaks after a PVE upgrade, that is a prime suspect.
- Kernel modules (`overlay`, `br_netfilter`, `nf_nat`, ...) belong to the **host**, not the
  container. If Docker reports a missing module, look at the PVE host kernel and its config.

## Unprivileged uid/gid mapping
In an unprivileged CT, container uid 0 is host uid 100000 by default, so a host bind mount owned by
another user shows up as `nobody` inside and cannot be written.
```bash
stat -c '%u:%g %n' /tank/media          # on the host
pct exec <id> -- stat -c '%u:%g %n' /data   # inside the container - compare, do not chmod -R
grep -E '^(root|.*):' /etc/subuid /etc/subgid   # the mapping range the host allows
```
Fix by mapping deliberately (`lxc.idmap` / `mp0 ... ,idmap=` and the host `/etc/subuid`,
`/etc/subgid`), or by owning the data with the mapped uid on the host. Never `chmod 777`, never
`chown -R` a media library.

## Audit one container
```bash
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh 120
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh --config /etc/pve/lxc/120.conf
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh 120 --paths /data/downloads:/data/media
```
Read-only. Reports unprivileged/features, every `mp*`/`dev*`/`lxc.mount.entry` with its backup
consequences, system-path and symlink mount sources, duplicate or overlapping targets, world-writable
device nodes, and - with `--paths` - whether two paths are on the same filesystem as the guest sees
them (the hardlink question).

## Repeatable guests (only when it pays for itself)
- **Cloud-init template**: build one cloud-init-capable VM, convert it to a template, clone it. That
  is the native, supported path - no third-party tooling needed.
- **Terraform/OpenTofu**: `bpg/terraform-provider-proxmox` is community-maintained (not a Proxmox
  product), targets PVE 9.x, is still `0.x` and a few operations need SSH. Pin it and read its
  breaking-change notes; do not assume a stable API.
- **Ansible**: `community.proxmox` is likewise community-maintained.
- **Packer**: the hashicorp/proxmox integration is community-maintained and slow-moving; verify
  compatibility before building a workflow on it.
- Native tooling (`pvesh`, `qm`, `pct`, `pvesm`) is the supported interface. Reach for IaC when you
  rebuild guests often - not for a three-guest homelab.

## Hard rules
- One change per guest per turn, and state the rollback (`pct config <id>` output before/after).
- Snapshot first, but remember: a snapshot on non-snapshot-capable storage, or containing a bind
  mount, is not a backup.
- Never widen privileges (`unprivileged: 0`, `unconfined`, `mode=0666` on `/dev/dri`, `--force`)
  as a diagnostic step without saying so explicitly.
