---
name: core-compose-change
description: Change a Docker Compose service safely - validate the file, reason about paths, user ids and mounts, apply one service at a time, and confirm the container is actually healthy rather than merely started. Use when editing docker-compose.yml, adding a service, changing volumes or environment variables, updating an image tag, or debugging a container that is up but broken.
metadata:
  category: core
  stack: docker
---

# Compose change

`up -d` success means started, not working. Different claims.

## Before editing
```bash
docker compose config -q
docker compose config > /tmp/current.yml
docker compose ps
docker compose logs --tail=50 <service>
```

## Things that bite
- **Path consistency:** same storage at a sensible path in every container (`/data` root).
- **Hardlinks need one filesystem** (same mount). Separate mounts/pools/NFS/mergerfs silently copy+delete.
- **UID/GID/umask:** Servarr `PUID`/`PGID`/`UMASK` vs slskd `SLSKD_UMASK` — different conventions.
- **`depends_on` ≠ readiness.** Healthcheck + `condition: service_healthy`.
- **VPN sidecar owns the namespace** (`network_mode: service:gluetun` — publish on the VPN container).
- **`docker compose down -v` deletes named volumes.** Never propose it. Ever.

## Procedure
1. Read the file (resolved paths, not declared). 2. One service's change. 3. `config -q` must exit 0.
4. Diff resolved config. 5. Bring up only that service; check ps, logs, then a functional probe.
6. Report; don't silently continue.

## Never
`down -v`, `--force-recreate` on a DB without backup, `docker volume prune`; simultaneous
bind+container path changes unchecked; image+config changes together.
