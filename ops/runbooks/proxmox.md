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

## What a container backup does NOT contain - read this before trusting one
A container backup is the config plus the **root disk only**. The music library and the downloads
folder are bind mounts (or volume mount points with no `backup=1`), so:

- `vzdump` does **not** back up your library, and never backs up a bind mount.
- The DB and config live in the container rootfs and *are* backed up. So a restore gives you a
  Navidrome and Lidarr that start up cleanly and point at a library that was never in the backup.
  That is the failure mode this whole runbook exists to prevent.

Back up the library and `downloads` on their own schedule (a ZFS snapshot task, or `rsync`/`restic`
to another disk or host) and drill that restore too. To see which mounts are which, the read-only
audit lists every one and says which are covered:
`bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh <id>`.

## Before ANY risky change (upgrade, storage move, guest resize, mount change)
1. Read the `proxmox-backup-and-restore` skill and take a real backup of the guest you are about to
   touch. First check for a job covering it - `grep -E 'vzdump|vmid|mode|storage' /etc/pve/jobs.cfg` -
   and confirm its last run actually succeeded. No job, or no confirmed run, means run one by hand:
   `vzdump <id> --mode snapshot --storage <target>` (APPROVAL-REQUIRED), and wait for it to finish
   before changing anything else. A backup you have not seen complete is not a backup.
2. Remember step 1 does not cover the library - see the section above.
3. Capture the "before": `pveversion -v`, `pct config <id>`, `qm config <id>`, `cat /etc/network/interfaces`,
   `pvesm status`. Save it next to the change note.
4. Confirm free space on `/` and on the target storage.
5. Write the rollback command down first.

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
2. Start it with no network. Verify services, config files - and the library mount, which came from
   the separate library backup, not from this restore.
3. Repeat for the library backup on its own. A guest backup that restores into an empty `/data/media`
   is a test that passed while the thing you actually care about is still unverified.
4. Record the elapsed time and the steps you actually took. Delete the test guest after.
