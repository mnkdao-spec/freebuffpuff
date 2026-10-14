# Runbook: music stack

Read-only first. Every command in the Health section is safe to run at any time.

## Health
```bash
docker compose ps                                    # status + health, all services
docker compose config -q && echo "compose parses"     # syntax, not runtime
bash .agents/skills/music-path-and-hardlink-doctor/scripts/compose-doctor.sh docker-compose.yml
curl -s -H "X-Api-Key: $LIDARR_API_KEY" http://localhost:8686/api/v1/health | head -c 800
curl -s -H "X-API-Key: $SLSKD_API_KEY"  http://localhost:5030/api/v0/server | head -c 400
curl -s "http://localhost:4533/rest/ping?u=$ND_USER&t=$ND_TOKEN&s=$ND_SALT&v=1.16.1&c=agent&f=json"
```

## An album will not import
1. `music-lidarr-match-doctor` - rank the causes; check the release-group versus release MBID trap.
2. `music-path-and-hardlink-doctor` - is the completed download visible *inside* the Lidarr container?
3. Only then Manual Import (`Activity -> Queue -> Manual Import`). Never force it by retagging files.

## Downloads are stalling
1. `bash .agents/skills/music-slskd-ops/scripts/slskd-doctor.sh` - connected? transfers queued?
2. Listening-port reachability. It is a different port from the web UI, and a missing forward makes
   search results and browsing unreliable too, not just uploads.
3. Is an import (Lidarr or Soularr) racing the transfer and reading a partial folder as complete?

## The music server shows a mess (split albums, wrong artists, shredded compilations)
`music-navidrome-tagging-doctor`. Grouping comes from tags, not folders. Remember the sequence:
move, scan, retag, scan - doing both at once breaks matching.

## Anomaly sweep (read-only)
```bash
mkdir -p <scratch>/reports          # --out needs an existing directory
bash .agents/skills/music-library-audit/scripts/lib-audit.sh <library> --hash --out <scratch>/reports/audit.json
```
`--out` takes a **file** path, not a directory - `--out <scratch>/reports/` exits 3 with a message.
Read the report, then propose only reversible fixes. Never delete on a duplicate candidate.

## Smart playlist will not load
`bash .agents/skills/music-navidrome-nsp-author/scripts/nsp-lint.sh <file>.nsp`, then check that a
scan has run since the file was added.

## Before any upgrade or migration
`core-backup-restore-check`. Lidarr (and Jellyfin) have **no downgrade path** after a database
schema migration - a restore is the only way back. Immich's database backup is not the photo library.
