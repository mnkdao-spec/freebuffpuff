---
name: proxmox-backup-and-restore
description: Design, audit and test Proxmox backups - vzdump modes (snapshot/suspend/stop), what a container backup actually contains and what it silently omits, Proxmox Backup Server deduplication/verification/pruning, retention policies, and a real restore drill. Use when setting up or reviewing backups, before any upgrade or risky change, when a backup looks suspiciously small, when asked "are we backed up", or when planning how to recover a guest.
metadata:
  category: proxmox
---

# Backup and restore

A backup that has never been restored is a hypothesis. This skill is about turning it into a fact.

## vzdump modes
| Mode | What it does | When to use |
|---|---|---|
| `snapshot` | uses the underlying storage's snapshot facility; the guest keeps running (containers are briefly suspended for consistency) | default choice - **requires every backed-up volume to be on snapshot-capable storage** |
| `suspend` | legacy/compatibility path; rsyncs data with a temporary copy | when snapshot mode is impossible and you accept the cost |
| `stop` | shuts the guest down first | strongest consistency, real downtime |

With `qemu-guest-agent` in a VM, snapshot-mode backups can freeze/thaw the filesystem for better
application consistency. Without an agent, a running guest's backup is crash-consistent at best.

## What a container backup contains - and what it omits
- Config **and** all data of the root disk. Backups are always full backups.
- **Additional mount points are excluded by default.** Verbatim: *"By default additional mount
  points besides the Root Disk mount point are not included in backups. For volume mount points
  you can set the Backup option to include the mount point in the backup."* Add `backup=1` per
  volume mount point (`pct set 120 -mp0 <vol>,mp=/data,backup=1`).
- **Bind mounts and device mounts: never.** *"Device and bind mounts are never backed up as their
  content is managed outside the Proxmox VE storage library."*
- A container backup holds a **lock** while it runs. Do not force-unlock a guest mid-backup; find
  the running task first (`/var/log/pve/tasks` or the UI's Tasks pane).

Practical consequence: for the music stack, the DB/config lives in the container rootfs (backed
up) while **the library does not** (bind mount). Back up the library separately, and say so out loud
in `ops/runbooks/proxmox.md`.

## PBS vs a plain vzdump target
- **PBS** stores deduplicated, verified chunks and supports **single-file restore** from its backup
  browser (CT archives and supported VM disk filesystems - not guaranteed for every guest FS).
  Proxmox recommends running it on a **separate host**, or at least a separate failure domain.
- A directory/NFS vzdump target is simpler: plain backup files, no dedup, no verify workflow.
- PVE's backup job is still a **full logical backup** every time; PBS deduplicates so subsequent
  runs send/store only changed chunks. Prune removes snapshot metadata first, GC later frees
  unreferenced chunks - so a prune alone does not immediately reclaim space.

Configure and read:
```bash
cat /etc/pve/jobs.cfg                    # scheduled backup jobs (PVE 8+)
grep -E 'vzdump|vmid|mode|storage' /etc/pve/jobs.cfg
pvesm status                             # is the backup target actually mounted?
proxmox-backup-client snapshot list --repository <user>@<pbs>:<datastore>
```
Set retention deliberately (`keep-last`, `keep-daily`, `keep-weekly`, `keep-monthly`) and use
PBS's prune simulator rather than assuming the options interact the way you expect. Schedule PBS
**verification** as well as backups.

## Restore drill (the part that matters)
1. Pick a guest with a recent backup. Restore it **to a new VMID**, never over production:
   `qmrestore <backup> <newid>` / `pct restore <newid> <backup> --storage <target>`.
2. Start the restored guest with **no network** (or a firewalled bridge) so it cannot collide with
   the original.
3. Verify: services come up, the config files are the ones you expect, the library mount is
   re-attachable, and one end-to-end request works (a Navidrome `/rest/ping`, a web request).
4. Record the elapsed time. "How long to recover" is the number nobody has until they test it.
5. Destroy the test guest afterwards - and only after confirming the real one is healthy.

## Keeping backups small without creating blind spots
- Image layers and caches are rebuildable; **databases, Compose files, secrets and user data are
  not**. Keep the latter in identified persistent paths.
- Do **not** blindly exclude all of `/var/lib/docker` if Docker named volumes live there - that is
  where an app's real state often is.
- `backup=0` on a volume is a decision, not a default: write down why.
- If a backup got much smaller, suspect an unmounted target or a newly excluded mount - not success.

## Hard rules
- Never restore over a running production guest as a "test".
- Never delete backups, prune a datastore, or free "unused" space without an explicit instruction.
- Never claim data is backed up because a job exists. Name what the job covers, what it excludes,
  and when it was last verified/restored.
