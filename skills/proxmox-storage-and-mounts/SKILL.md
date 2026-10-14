---
name: proxmox-storage-and-mounts
description: Reason about Proxmox storage and guest mounts - ZFS vs LVM-thin vs directory vs NFS/CIFS, snapshot support, volume vs bind vs device mounts, what vzdump includes, why hardlinks break across datasets. Use before moving/extending libraries, designing download/library layout, invisible-data cases, vanishing disk space, or "is this really backed up".
metadata:
  category: proxmox
---

# Storage and mounts

| Backend | Snapshots | Bites |
|---|---|---|
| **ZFS** | yes | single-disk pool = no redundancy (checksums detect, can't repair); `ashift` fixed at creation |
| **LVM-thin** | yes | watch data AND metadata pools; full pool corrupts guests |
| **Directory** | no (qcow2 internal possible; can block running VMs) | slow on large/network disks |
| **NFS/CIFS** | share-dependent | good off-host backup target |

**A snapshot is not a backup.** Snapshot mode needs *all* backed-up volumes on capable storage.

## Mount types + the backup rule
`mp0: <vol>,mp=/data,backup=1` (volume: managed, snapshottable) vs `mp1: /tank/media,mp=/media`
(bind: host dir, unmanaged) vs `dev0: /dev/dri/...` (device). Docs verbatim: *additional mounts
excluded by default; GUI ticks the box for you; device and bind mounts are never backed up.*
Hand-edited configs are where `backup=1` goes missing. Bind-mount libraries need separate
protection (PBS dir backup, `zfs send`, restic/rclone) — same box ≠ protection.

## Hardlinks: one filesystem or nothing
**Two ZFS datasets = two filesystems.** Verify as the service user sees it:
`stat -c '%d %i %n'` both sides (same %d required); `findmnt -T`; or
`lxc-audit.sh <id> --paths A:B`. Layout: **one** dataset (`tank/media` with `downloads/`+`media/`),
**one** guest mount (`mp0: /tank/media,mp=/data`), same `/data` in every container.

## ZFS specifics
**ARC**: PVE ≥8.1 ≈10% RAM capped 16 GiB (check `zfs_arc_max`). `recordsize` per-dataset
(test 1 MiB for sequential media; never for DBs). Snapshots retain changed blocks — watch
`zfs list -o space`. `zfs send -R` for off-box copies (same-box replication ≠ backup).

## Growing disks
`qm disk resize` / `pct resize` + in-guest partition+filesystem growth. TRIM for thin disks.

## Failure modes first
Unmounted external/NFS → writes land on `/` (classic); `active: 0` storage = unmounted;
empty-in-container library = nested/duplicate mount or idmap issue; USB identity churn → prefer SATA/NAS.

## Hard rules
No delete/move/`chown -R` as part of storage changes (demonstrate read-only first);
no resize/migrate without verified backup + rollback; state un-backed-up items explicitly.
