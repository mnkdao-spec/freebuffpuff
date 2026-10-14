---
name: music-path-and-hardlink-doctor
description: Diagnose container path, mount, UID/GID and hardlink problems in a media stack - check whether services see the same storage at consistent paths, whether hardlinks are actually possible, and whether permissions explain a failed import. Use when Lidarr says a download client is unavailable, when an album never imports, when files are copied instead of hardlinked, when an import fails with permission errors, or when editing docker-compose.yml for a music stack.
metadata:
  category: music
  stack: docker
---

# Path and hardlink doctor

Three of the four most common "Lidarr is broken" causes live here, not in Lidarr's settings:
container paths, permissions, and filesystem boundaries.

## Run the read-only checker first
```bash
bash scripts/compose-doctor.sh docker-compose.yml          # next to this SKILL.md
bash scripts/compose-doctor.sh docker-compose.yml --json
```
It reports: the same host path mounted at different container paths, named-volume vs bind
mounts, remote/UNC paths, inconsistent `PUID`/`PGID`/`UMASK`, `SLSKD_UMASK` usage,
`network_mode: service:*` sidecar networking, and `depends_on` without a health condition.
It changes nothing and never runs `up`/`down`.

## The four rules
1. **Same file, same path, everywhere.** The usual failure: slskd reports
   `/downloads/Album/01.flac`, Lidarr only has `/data/downloads` mounted, so nothing matches.
   Give every participating container one shared mount (commonly the host data root at
   `/data`) and use paths under it consistently. Remote Path Mappings can translate, but
   consistent mounts are cheaper to debug.
2. **Hardlinks require one filesystem, seen through the same mount.** Lidarr's "Use Hardlinks
   Instead of Copy" is **on by default**. Across filesystems, separate bind mounts, named
   volumes, mergerfs branches, ZFS datasets or NFS/SMB exports it silently degrades to
   copy-and-delete: double the disk, double the I/O.
3. **One UID/GID story.** Either one shared user, or a shared group with group-writable files.
   Servarr guidance: `UMASK=002` so group members can write. **slskd uses `SLSKD_UMASK` and
   does not follow the `PUID`/`PGID` convention** — never copy env vars between these images.
4. **`depends_on` is not readiness.** Short syntax waits for the container to start, not to be
   usable. Use a healthcheck plus `condition: service_healthy` where it matters.

## Verify hardlinking empirically (read-only)
```bash
# do both containers see the SAME inode for a real file?
docker compose exec lidarr    stat -c '%d %i %n' /data/downloads/<album>/<track>.flac
docker compose exec slskd     stat -c '%d %i %n' /downloads/<album>/<track>.flac
# same device (%d) in both containers is the precondition for a hardlink
docker compose exec lidarr    df -h /data/downloads /data/music
```
Different device numbers, or `/data/music` absent from one of them, means hardlinks are not
happening regardless of the setting. Report it — do not "fix" it by moving files.

## Permission triage
```bash
docker compose exec lidarr id
ls -ldn <host download dir> <host library dir>      # numeric owner/group + mode
docker compose logs --tail=50 lidarr | grep -iE 'permission denied|access|unauthorized'
```
`permission denied` is ownership, not a missing file. Check the container's numeric UID against
the host directory's numeric owner — usernames differ between host and image and mean nothing.

## Output format
```
FINDINGS:    from compose-doctor.sh, verbatim
INEFFECTIVE: any setting that cannot work as configured (e.g. hardlinks across filesystems)
EVIDENCE:    device/inode/df output or log lines
RECOMMEND:   the smallest change, with the exact diff, for a human to apply
RISK:        what changes if that fix is applied (restart? rescan? nothing?)
NOT CHANGED: no compose file, permission, or mount was modified
```

## Never
- Run `docker compose down -v`, `docker volume prune`, or `--force-recreate` on a database.
- `chown -R` or `chmod -R` a media tree to fix a permission error.
- Move or re-point a mount while services are running. Propose it; the human applies it.
