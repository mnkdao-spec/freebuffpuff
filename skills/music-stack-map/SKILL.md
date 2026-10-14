---
name: music-stack-map
description: Map a self-hosted music stack end to end - which services exist, how Lidarr, Prowlarr, slskd, Navidrome and beets interconnect, where each config and API live, and where files flow from download to library. Use at the start of any music-stack task, when asked "how does this stack fit together", or before diagnosing an import problem.
metadata:
  category: music
---

# Music stack map

Read-only orientation. Establish before touching anything.

Key structural fact: **separate services joined by HTTP APIs**, not one platform.
Prowlarr syncs indexers into Lidarr. Lidarr talks to a *download client*; slskd is **not a
built-in Lidarr client** — needs **Soularr** bridge or a community plugin (nightly/develop
Lidarr). Navidrome scans the library root and groups by **tags**, not folders.

## Inventory (read-only)
```bash
docker compose ps
docker compose config -q && echo "compose parses"
curl -s -H "X-Api-Key: $LIDARR_API_KEY" http://localhost:8686/api/v1/health
curl -s -H "X-API-Key: $SLSKD_API_KEY" http://localhost:5030/api/v0/session
curl -s "http://localhost:4533/rest/ping?u=$ND_USER&t=$ND_TOKEN&s=$ND_SALT&v=1.16.1&c=agent&f=json"
```
Configs hold keys — locate, don't read: Lidarr/Prowlarr `config.xml` (`/config`),
slskd `slskd.yml` (`/app`; `SLSKD_CONFIG` override), Navidrome `navidrome.toml`.
APIs: Lidarr/Prowlarr `/api/v1` (`X-Api-Key`); slskd `/api/v0` (`X-API-Key`,
Administrator/ReadWrite/ReadOnly roles); Navidrome Subsonic `/rest/*`.

## File flow
1. slskd → staging/download folder. 2. Lidarr/Soularr notified. 3. Lidarr imports to
library root (**hardlink** if same filesystem, else **copy**). 4. Navidrome scans + regroups by tags.

Three failure domains, diagnose in order: **reachability** → **paths**
(`music-path-and-hardlink-doctor`) → **metadata** (`music-lidarr-match-doctor`).

## Output
```
SERVICES / LINKAGES (verified URLs) / PATHS (host → container) / LIBRARY (tag- vs folder-derived) / CONFIG (locations only) / UNKNOWN
```

## Hard rules
- No config reads with keys — use the environment. No state changes in a mapping turn.
