# Runbook: Proxmox host

Read-only first. Every command in the Health section is safe to run at any time.

## Health
```bash
bash .agents/skills/proxmox-stack-map/scripts/pve-doctor.sh          # whole-host audit, read-only
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh <id> # one container, in depth
pveversion -v | head -3; uptime; df -h /
pvesm status                          # every storage active? (an unmounted one fills /)
pct list; qm list
zpool list -H -o name,health,capacity
systemctl --failed
```
Anything [FAIL] from pve-doctor is a data-loss or availability risk: storage inactive, pool
DEGRADED, root filesystem filling, Docker on the PVE host, no backup job.

## Before ANY risky change (upgrade, storage move, guest resize, mount change)
1. `bash .agents/skills/proxmox-backup-and-restore/scripts/...` - use the skill; at minimum run a
   backup and confirm it completed.
2. Capture the "before": `pveversion -v`, `pct config <id>`, `qm config <id>`, `cat /etc/network/interfaces`,
   `pvesm status`. Save it next to the change note.
3. Confirm free space on `/` and on the target storage.
4. Write the rollback command down first.

## Disk filling up
```bash
df -h; du -x -d1 / 2>/dev/null | sort -h | tail
ls -la /var/log/pve/tasks/ 2>/dev/null | tail
```
Usual causes: an external disk or NFS share not mounted so data landed on `/`; a ZFS pool that has
queued snapshots; backup files written into a mountpoint whose disk was absent.

## A container will not start
```bash
pct start <id> --debug            # read the FIRST error, not the last
pct config <id>                   # missing/symlinked bind source, bad mount target
df -h                             # cannot start: storage full
dmesg | tail -40                  # AppArmor / device denials
```
Do not "fix" it by setting the AppArmor profile to unconfined or making the container privileged.

## Docker inside a container stopped working after a host update
1. Capture versions before changing anything: `pveversion -v`, `lxc-ls --version`, `docker info`,
   `runc -v`.
2. `dmesg | grep -i apparmor` and the container's journal - look for a real denial.
3. Check whether a fixed `lxc-pve` is available. The 2025 `runc`/AppArmor breakage was fixed by a
   package update; disabling AppArmor was not the fix.
4. Re-verify `/dev/dri` mode/gid and the storage driver (`docker info`, not `vfs`).

## Upgrading the host
Follow `proxmox-upgrade-safety`. Minimum: tested backups, >10 GB free on `/`, notes read, `pve8to9
--full` for 8->9, repositories not mixed, and a post-upgrade check of guests, storage and the
nested Docker stack. There is no supported downgrade.

## Restore drill (do this quarterly, it is the only proof)
1. Restore the newest backup of one guest **to a new VMID**.
2. Start it with no network. Verify services, config files and the library mount.
3. Record the elapsed time and the steps you actually took. Delete the test guest after.
