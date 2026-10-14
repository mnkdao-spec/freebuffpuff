---
name: core-compose-change
description: Change a Docker Compose service safely - validate the file, reason about paths, user ids and mounts, apply one service at a time, and confirm the container is actually healthy rather than merely started. Use when editing docker-compose.yml, adding a service, changing volumes or environment variables, updating an image tag, or debugging a container that is up but broken.
metadata:
  category: core
  stack: docker
---

# Compose change

`docker compose up -d` returning success means the container started. It does not mean the
service works. Those are different claims.

## Before editing
```bash
docker compose config -q                 # syntax only. Exit 0 = parses. Says nothing about runtime.
docker compose config > /tmp/current.yml  # what Compose actually resolves (env substitution included)
docker compose ps                        # what is running, and whether healthchecks pass
docker compose logs --tail=50 <service>  # its current state of mind
```
Record the baseline. If the service is already unhealthy, that is not your change's fault —
say so.

## Things that bite in this stack
- **Path consistency.** The *same physical storage* must be visible at a path that makes
  sense to every container that needs it. A common pattern: mount the host data root at
  `/data` everywhere, then use `/data/downloads/...` and `/data/media/...` inside containers.
  If slskd reports `/downloads/album` but Lidarr only knows `/media-downloads`, nothing
  links up. Remote Path Mappings can translate, but consistent mounts are easier to debug.
- **Hardlinks need one filesystem.** Lidarr's "Use Hardlinks Instead of Copy" is on by
  default. Source and destination must be on the same filesystem, seen through the same
  mount. Separate mounts, separate pools, NFS/SMB shares or mergerfs branches can silently
  fall back to copy-and-delete (double disk usage, slow imports).
- **UID/GID and umask.** Servarr images use `PUID`/`PGID`/`UMASK`; slskd uses `SLSKD_UMASK`
  and does **not** follow the same convention. Do not assume one image's env vars work on
  another. Group-writable (`UMASK=002`) with a shared group is the common arrangement.
- **`depends_on` is not readiness.** Short syntax waits for the container to *start*. Use a
  healthcheck plus `condition: service_healthy` when one service genuinely needs another.
- **A VPN sidecar owns the network namespace.** With `network_mode: service:gluetun`, the
  dependent service gets no ports of its own — publish them on the VPN container.
- **`docker compose down -v` deletes named volumes.** Never propose it. Ever.

## Procedure
1. Read the existing file. Note the resolved paths, not the declared ones.
2. Make **one** service's change.
3. `docker compose config -q` — must exit 0.
4. Diff the resolved config: `docker compose config > /tmp/after.yml; diff /tmp/current.yml /tmp/after.yml`
   This shows env substitution and path resolution, which is where mistakes hide.
5. Bring up only that service, then check, in order: `ps` (health), `logs --tail=100`, then an
   actual functional probe (an API call, a file appearing, a page loading).
6. Report; do not silently continue to the next service.

## Output format
```
SERVICE:  name
CHANGED:  file -> keys changed
RESOLVED: path/port/env before -> after
CHECKS:   config -q (exit), ps (health), logs (errors), functional probe (result)
REVERT:   the exact command or edit to undo this
```

## Never do
- `down -v`, `--force-recreate` on a database without a backup, or `docker volume prune`.
- Change a bind mount path and a container-side path in the same step without checking both.
- Upgrade an image tag and change config simultaneously; separate them so a failure is attributable.
