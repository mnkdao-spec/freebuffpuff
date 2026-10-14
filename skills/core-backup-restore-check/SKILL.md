---
name: core-backup-restore-check
description: Verify that backups exist, are recent and can actually be restored - check repository and snapshot state, run read-only integrity checks, and produce a restore checklist without touching production data. Use before an upgrade, before a migration, when asked whether backups are working, or when planning anything that changes a database or library.
metadata:
  category: core
  stack: restic, borg, docker
---

# Backup and restore check

A succeeding backup job is not a restorable backup. Verify the recovery path, read-only.

## Read-only checks
```bash
restic snapshots --latest 5
restic check
borg check /path/to/repo
borg list ::<archive> | head -50
docker volume ls; docker volume inspect <name> --format '{{.Mountpoint}}'
```
`restic --repair` / `borg --repair` can lose data. Never propose them.

## Service facts
- **Navidrome**: SQLite in `DataFolder` holds ratings/plays/playlists — back up DB + config.
- **Lidarr**: DB + `config.xml` in appdata; **no downgrade** after schema migration.
- **slskd**: `slskd.yml` holds keys; downloads replaceable, config isn't.
- **Immich**: DB backup ≠ photo library. **Jellyfin**: no downgrade after migrations.

## Procedure
1. Snapshots + ages. 2. Cheapest integrity check. 3. Restore one *small* file **to scratch**
   (never over live data). 4. List uncovered items. 5. Write restore checklist; don't run a restore.

## Output
```
BACKUP / COVERAGE (in + NOT) / PROVEN (file → scratch path) / GAPS / STEPS (with STOP markers)
```
