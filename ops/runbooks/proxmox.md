# Runbook: Proxmox host

Read-only first. Every command in the Health section is safe at any time.

## Health
```bash
bash .agents/skills/proxmox-stack-map/scripts/pve-doctor.sh
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh <id>
pveversion -v | head -3; uptime; df -h /
pvesm status
pct list; qm list
zpool list -H -o name,health,capacity
systemctl --failed
```

## Backups do NOT contain the library
A container backup is config + **root disk only**. Library/downloads are bind mounts
(or volumes without `backup=1`): `vzdump` never backs up a bind mount. Back up the
library separately (ZFS snapshots, `rsync`/`restic`) and drill that restore too.
Audit coverage: `lxc-audit.sh <id>` lists every mount and its backup status.

## Before ANY risky change
1. Real backup of the guest; confirm the job's last run succeeded, else `vzdump` by hand
   (APPROVAL-REQUIRED). A backup you haven't seen complete is not a backup.
2. Library needs its own backup — see above.
3. Capture "before": `pveversion -v`, `pct/qm config`, network, `pvesm status`.
4. Confirm free space on `/` and target storage. 5. Write the rollback down first.

## Disk filling up
Usual causes: unmounted external/NFS so data landed on `/`; queued ZFS snapshots;
backups written into an absent mountpoint.

## Container will not start
`pct start <id> --debug` (first error), `pct config`, `df -h`, `dmesg` (AppArmor denials).
Do not "fix" with unconfined AppArmor or privileged mode.

## Docker broke after host update
Capture versions first; check `dmesg` AppArmor denials; look for a fixed `lxc-pve`
(the 2025 runc breakage was a package fix, not an AppArmor downgrade).

## Upgrading
`proxmox-upgrade-safety`: tested backups, >10 GB free on `/`, `pve8to9 --full` for 8->9,
unmixed repos, post-upgrade guest/storage/Docker checks. No supported downgrade.

## Restore drill (quarterly)
Restore newest backup **to a new VMID**, start with no network, verify services + library
mount (from the *separate* library backup). Record time and steps. Delete test guest after.
