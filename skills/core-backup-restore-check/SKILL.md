---
name: core-backup-restore-check
description: Verify that backups exist, are recent and can actually be restored - check repository and snapshot state, run read-only integrity checks, and produce a restore checklist without touching production data. Use before an upgrade, before a migration, when asked whether backups are working, or when planning anything that changes a database or library.
metadata:
  category: core
  stack: restic, borg, docker
---

# Backup and restore check

A backup job that reports success is not the same as a restorable backup. Verify the
recovery path, read-only.

## Read-only checks
```bash
# restic: what exists, and is the repo consistent?
restic snapshots --latest 5
restic check                      # read-only metadata consistency check
restic check --read-data-subset=1/100   # samples real data blocks; still read-only

# borg: check is read-only by default; --verify-data is slow; --repair is DESTRUCTIVE
borg check /path/to/repo
borg list ::<archive> | head -50

# docker: named volumes and where they really live
docker volume ls
docker volume inspect <name> --format '{{.Mountpoint}}'
df -h /srv/media
```
`restic --repair` and `borg --repair` can lose data. Never propose them; a human decides.

## Service-specific facts that change the checklist
- **Navidrome**: SQLite database lives in `DataFolder`. Ratings, play counts, playlists and
  smart-playlist state are *in that database*, not in the music files. Back up the database
  and the config; a rescan rebuilds the index, not the history. Changing `PID.*` settings
  requires a full scan and the docs recommend backing up the DB first.
- **Lidarr/Radarr**: the database and `config.xml` (which contains the API key) live in the
  appdata dir. After a schema migration, **downgrading needs a restore** — back up before
  changing branches or image tags.
- **slskd**: `slskd.yml` holds API keys and credentials; downloads are replaceable, the
  config and share list are not.
- **Immich** (if present): the database backup is **not** the photo library. Both are needed.
- **Jellyfin** (if present): no downgrade path after migrations; its built-in backup covers
  the database and optionally metadata.

## Procedure
1. List snapshots/archives with timestamps. State the newest one and its age.
2. Run the least expensive integrity check the tool offers.
3. Pick one *small* file and demonstrate it is restorable **to a scratch path**:
   `restic restore --target /tmp/restore-check --include <path> latest` (never over live data).
4. List what is *not* covered: media files themselves, secrets, external configs, DNS, VPN keys.
5. Write `/tmp/restore-checklist.md` — but do not run a restore.

## Output format
```
BACKUP:   tool, repo path, newest snapshot + age, integrity result
COVERAGE: what is included / what is NOT
PROVEN:   the file actually restored to scratch, and where
GAPS:     anything without a backup
STEPS:    ordered restore steps, with "STOP and confirm" markers where they are destructive
```
