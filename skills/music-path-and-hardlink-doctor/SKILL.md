---
name: music-path-and-hardlink-doctor
description: Diagnose container path, mount, UID/GID and hardlink problems - check services see the same storage at consistent paths, whether hardlinks are possible, and whether permissions explain a failed import. Use when Lidarr says the client is unavailable, imports never happen, files copy instead of hardlink, permission errors, or editing compose for a music stack.
metadata:
  category: music
  stack: docker
---

# Path and hardlink doctor

Top "Lidarr is broken" causes live here, not in settings: paths, permissions, filesystem boundaries.

## Run the checker first (read-only)
`bash scripts/compose-doctor.sh docker-compose.yml [--json]` — reports same host path at
different container paths, named-vs-bind mounts, remote paths, PUID/PGID/UMASK incoherence,
`SLSKD_UMASK` misuse, sidecar networking, `depends_on` without health. Never runs up/down.

## Four rules
1. **Same file, same path, everywhere.** One shared mount (host data root at `/data`),
   consistent subpaths. Remote Path Mappings translate, but consistent mounts debug easier.
2. **Hardlinks need one filesystem through the same mount.** "Use Hardlinks Instead of Copy"
   is **on by default**; across filesystems/mounts/volumes/datasets/NFS it silently copy+deletes.
3. **One UID/GID story.** Shared user or shared group + `UMASK=002`. **slskd `SLSKD_UMASK` ≠
   `PUID`/`PGID`** — never copy env vars between images.
4. **`depends_on` ≠ readiness.** Healthcheck + `condition: service_healthy`.

## Verify empirically (read-only)
Same inode in both containers = precondition:
`docker compose exec <svc> stat -c '%d %i %n' <path>` — same device (%d) required.
`permission denied` = numeric UID vs host owner (usernames differ across images; compare numbers).

## Output
```
FINDINGS (verbatim) / INEFFECTIVE settings / EVIDENCE / RECOMMEND (smallest diff, human applies) / RISK / NOT CHANGED
```

## Never
`down -v`, `volume prune`, `--force-recreate` on a DB; `chown/chmod -R` media trees;
moving mounts while services run (propose; human applies).
