---
name: music-stack-map
description: Map a self-hosted music stack end to end - which services exist, how Lidarr, Prowlarr, slskd, Navidrome and beets actually interconnect, where each one's config and API live, and where files flow from download to library. Use at the start of any music-stack task, when a service is unfamiliar, when asked "how does this stack fit together", or before diagnosing an import problem.
metadata:
  category: music
---

# Music stack map

Read-only orientation. Establish this before touching anything.

## The shape of it
```
        MusicBrainz  <-- metadata (artists, release groups, MBIDs)
             |
  Prowlarr --|--> Lidarr  --(wanted list)--> download client
  (indexers, |      |                              |
   syncs to  |      |                              +--> slskd (Soulseek)
   Lidarr)   |      |                                        |
             |      +--(import: hardlink/copy/move)--> library root
             |                                                |
             |                                                v
             |                                        Navidrome (scans tags)
             |                                                |
             |                                        clients (Feishin, Symfonium...)
        beets (tagging/reorg) <-- optional, before or after import
```
Key structural fact: **these are separate services joined by HTTP APIs**, not one platform.
Prowlarr syncs indexers into Lidarr. Lidarr talks to a *download client*; slskd is **not a
built-in Lidarr client** — it needs either the external **Soularr** bridge or a community
Lidarr plugin (which requires a nightly/develop Lidarr build). Navidrome never sees the
download folder: it scans the library root and groups by **tags**, not folders.

## Inventory (read-only)
```bash
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'
docker compose config -q && echo "compose parses"
# each service's own health view
curl -s -H "X-Api-Key: $LIDARR_API_KEY"   http://localhost:8686/api/v1/health   | jq -r '.[]|"\(.type) \(.message)"'
curl -s -H "X-Api-Key: $PROWLARR_API_KEY" http://localhost:9696/api/v1/health   | jq -r '.[]|"\(.type) \(.message)"'
curl -s -H "X-API-Key: $SLSKD_API_KEY"    http://localhost:5030/api/v0/session  | jq .
curl -s "http://localhost:4533/rest/ping?u=$ND_USER&t=$ND_TOKEN&s=$ND_SALT&v=1.16.1&c=agent&f=json"
```
Config locations to locate, not to read (they contain keys):
| Service | Config | API |
|---|---|---|
| Lidarr | appdata `config.xml` (`/config` in Docker) | `/api/v1`, header `X-Api-Key` |
| Prowlarr | appdata `config.xml` | `/api/v1`, header `X-Api-Key` |
| slskd | `slskd.yml` at the app dir (`/app` in the official image; override with `SLSKD_CONFIG`) | `/api/v0`, header `X-API-Key`, roles Administrator/ReadWrite/ReadOnly |
| Navidrome | `navidrome.toml` in `/data` | Subsonic `/rest/*`; OpenSubsonic extensions |

## Where files actually go
1. slskd writes to a **staging/download** folder.
2. Lidarr (or Soularr) tells Lidarr about the completed folder.
3. Lidarr imports into the library root, using **hardlink** if source and destination are on
   the same filesystem, otherwise **copy**.
4. Navidrome scans the library root and re-groups everything from tags.

So there are three independent failure domains: **reachability** (can the containers see each
other), **paths** (do they see the same storage at consistent paths), and **metadata** (do the
tags identify the release well enough to import and to group). Diagnose in that order —
`music-path-and-hardlink-doctor` for paths, `music-lidarr-match-doctor` for metadata.

## Output format
```
SERVICES:   name -> status, health, port (from ps)
LINKAGES:   which service talks to which, and over what URL  <- verify, don't assume
PATHS:      host path -> container path, per service
LIBRARY:    library root + whether it is tag-derived (Navidrome) or folder-derived (Lidarr)
CONFIG:     locations only; never values
UNKNOWN:    what you could not determine
```

## Hard rules
- Do not read config files that contain API keys or credentials. Use the environment.
- Do not change service state (add artists, trigger searches, delete playlists) in a
  mapping turn.
