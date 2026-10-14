---
name: proxmox-backup-and-restore
description: Design, audit and test Proxmox backups - vzdump modes, what container backups contain and omit, PBS dedup/verification/pruning, retention, real restore drills. Use when setting up/reviewing backups, before upgrades or risky changes, on suspiciously small backups, "are we backed up", or recovery planning.
metadata:
  category: proxmox
---

# Backup and restore

An unrestored backup is a hypothesis. Make it a fact.

## vzdump modes
`snapshot` (default; guest runs; needs all volumes snapshot-capable) | `suspend` (legacy rsync path) |
`stop` (shutdown first; strongest consistency, downtime). qemu-guest-agent freeze/thaw improves
app consistency; without agent, crash-consistent at best.

## What a container backup holds — and omits
Config + root disk data; always full. **Extra mounts excluded by default** (`backup=1` per volume
mount; `pct set <id> -mp0 <vol>,mp=/data,backup=1`). **Bind/device mounts: never.**
Backup holds a **lock** — never force-unlock mid-run; find the task first.
Music-stack consequence: DB/config in rootfs (backed up); **library (bind) is not** — separate
library backups, stated aloud.

## PBS vs plain vzdump target
**PBS**: deduped verified chunks, single-file restore browser, separate host/failure domain.
Directory/NFS target: plain files, no dedup/verify. PVE jobs are full logical backups every time;
PBS dedups on store. Prune removes metadata first, GC frees chunks later. Retention
(`keep-last/daily/weekly/monthly`) deliberate; use PBS prune simulator; **schedule verification**.

Read: `cat /etc/pve/jobs.cfg`; `pvesm status` (target mounted?); `proxmox-backup-client snapshot list`.

## Restore drill (the part that matters)
1. Restore recent backup **to a new VMID** (never over prod). 2. Start **networkless** (no collision).
3. Verify: services, configs, re-attachable library mount, one end-to-end request.
4. Record elapsed recovery time. 5. Destroy test guest after confirming prod healthy.

## Small backups without blind spots
Image layers/caches rebuildable; **DBs, compose files, secrets, user data are not** — identified
persistent paths. Don't blanket-exclude `/var/lib/docker` (named volumes live there).
`backup=0` = decision with a written why. Suddenly-smaller backup ⇒ unmounted target or new
exclusion, not success.

## Hard rules
Never restore over prod as a "test"; never delete/prune backups unasked; never claim coverage
from a job's existence — name covered + excluded + last verified/restored date.
