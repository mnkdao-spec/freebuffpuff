---
name: proxmox-storage-and-mounts
description: Reason about Proxmox storage and guest mount points - ZFS vs LVM-thin vs directory vs NFS/CIFS, which support snapshots, volume mount points vs host bind mounts vs device passthrough, what vzdump actually includes, and why hardlinks break across datasets. Use before moving or extending a media library, when designing where downloads and the library live, when a guest cannot see its data, when disk space is disappearing, or when asked whether something is really backed up.
metadata:
  category: proxmox
---

# Storage and mounts

## What each backend can and cannot do

| Backend | Snapshots | Notes that bite |
|---|---|---|
| **ZFS** (`zfspool`) | yes | Container rootfs = subvolume, VM disks = zvol. A **single-disk pool has no redundancy** - checksums detect corruption but cannot repair it. `ashift` is fixed at pool creation. |
| **LVM-thin** (`lvmthin`) | yes | Thin provisioning: watch **both** the data and the metadata pool. A full thin pool corrupts guests. |
| **Directory** (`dir`) | no general fs snapshots | VM images can use qcow2 snapshots; per the storage guide, creating/deleting internal qcow2 snapshots **can block a running VM** and is slow on large/network-backed disks. |
| **NFS / CIFS** | depends on the share | Convenient, and a good place for off-host backup. VM snapshot support here is qcow2-based. |

**A PVE snapshot is not a backup.** Snapshot mode additionally requires that *all backed-up volumes*
sit on snapshot-capable storage (Backup and Restore chapter).

## Mount point types, and the backup rule that surprises everyone
Three different things look the same in `pct config`:
```bash
# volume mount point - managed by the PVE storage subsystem (snapshottable, quota, resize)
mp0: local-zfs:subvol-120-disk-1,mp=/data,size=500G,backup=1
# host bind mount - a host directory, not managed by PVE
mp1: /tank/media,mp=/media
# device passthrough
dev0: /dev/dri/renderD128,mode=0660,gid=104
```
Verbatim from the current docs:
- Backup and Restore: *"By default additional mount points besides the Root Disk mount point are
  not included in backups. For volume mount points you can set the Backup option to include the
  mount point in the backup."*
- Container Toolkit: *"When creating a new mount point in the GUI, this option is enabled by
  default."* - so a **hand-edited config is exactly where this gets missed**.
- Backup and Restore: *"Device and bind mounts are never backed up as their content is managed
  outside the Proxmox VE storage library."*
- Container Toolkit: *"The contents of bind mount points are not backed up when using vzdump."*
- Container Toolkit, on bind mounts: *"you cannot make snapshots or deal with quotas from inside
  the container."*

`backup=0` on `rootfs` is not a documented toggle - the root disk is always included.

So for a media library on a bind mount: **the PVE backup does not contain it, and never will.**
That data needs its own protection (PBS backup of the directory, `zfs send`, restic/rclone to
another machine) - and "it is on the same box" is not protection.

## Hardlinks: one filesystem, or nothing
Hardlinks cannot cross filesystems, and **two ZFS datasets in one pool are two filesystems**.
Consequences for an *arr stack:
```bash
# inside the guest, as the service user sees it:
stat -c '%d %i %n' /data/downloads/some/file /data/media/Music/Album/track.flac
# same %d = same filesystem = hardlink possible. Different %d = copy+delete fallback.
findmnt -T /data/downloads -o TARGET,SOURCE,FSTYPE,OPTIONS
```
Audit it from the host instead:
```bash
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh 120 --paths /data/downloads:/data/media
```
Layout that keeps hardlinks working: **one** dataset/share (`tank/media` with `downloads/` and
`media/` beneath it), passed into the guest as **one** mount (`mp0: /tank/media,mp=/data`), with
every container mounting the same `/data` - never `/downloads` and `/media` as separate mounts.
That mirrors the Servarr guidance and it is why `music-path-and-hardlink-doctor` exists.

## ZFS specifics worth knowing
- **ARC** is cache. PVE >= 8.1 sets ~10% of RAM capped at 16 GiB (`/etc/modprobe.d/zfs.conf`);
  older installs may still have a much larger limit. Check `zfs_arc_max`, don't guess.
- **`recordsize`** is per-dataset. For large sequential media, a bigger record (often 1 MiB) is
  worth *testing*; do not apply it to dataset holding databases or many small files.
- Snapshots are cheap at first and then **retain every block that later changes**. Watch
  `zfs list -o space` and snapshot retention, or a pool fills silently.
- `zfs send -R` / `receive` is how you get a real off-box copy. PVE's own **storage replication**
  sends ZFS deltas between nodes - but replication to the same box is not a backup.

## Growing disks (shrinking is not the reverse)
```bash
qm disk resize 200 scsi0 +20G          # VM
pct resize 120 rootfs +5G              # container
# then grow the partition AND the filesystem INSIDE the guest (growpart/resize2fs, zpool online -e)
```
Enable TRIM/discard for thin-backed disks and watch both free space and pool health.

## Failure modes to check first
1. **An external disk or NFS share is not mounted** → the guest/backup writes onto `/` and fills
   the root filesystem. Classic. `df -h`, then `du -x -d1 /`.
2. **Storage shows `active: 0`** in `pvesm status` → it is not mounted at all; anything writing
   there is writing somewhere else.
3. **"The library is empty inside the container"** → a nested/duplicate mount target, or a
   uid/gid mapping problem, not a missing file. See `proxmox-guest-placement`.
4. **USB-attached disks** change device identity; for a library, prefer SATA/SAS/HBA or a NAS.

## Hard rules
- Never delete, move or `chown -R` library data as part of a storage change. Demonstrate the
  problem read-only first.
- Never resize/shrink a disk or move a guest between storages without a verified backup and the
  exact rollback command.
- Report what is *not* backed up explicitly. Silent gaps are how homelabs lose data.
