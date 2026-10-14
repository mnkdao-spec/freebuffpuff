# Runbook: music stack

Read-only first. Every Health command is safe at any time.

## Health
```bash
docker compose ps
docker compose config -q && echo "compose parses"
bash .agents/skills/music-path-and-hardlink-doctor/scripts/compose-doctor.sh docker-compose.yml
curl -s -H "X-Api-Key: $LIDARR_API_KEY" http://localhost:8686/api/v1/health | head -c 800
curl -s -H "X-API-Key: $SLSKD_API_KEY" http://localhost:5030/api/v0/server | head -c 400
```

## Album will not import
1. `music-lidarr-match-doctor` — rank causes; check release-group vs release MBID trap.
2. `music-path-and-hardlink-doctor` — is the download visible *inside* the Lidarr container?
3. Then Manual Import. Never force by retagging files.

## Downloads stalling
1. `slskd-doctor.sh` — connected? queued? 2. Listening-port reachability (≠ web UI port).
3. Is an import racing the transfer on a partial folder?

## Server shows a mess (splits, wrong artists)
`music-navidrome-tagging-doctor`. Tags, not folders. Sequence: move, scan, retag, scan.

## Anomaly sweep (read-only)
```bash
bash .agents/skills/music-library-audit/scripts/lib-audit.sh <library> --hash --out <scratch>/reports/audit.json
```
`--out` takes a **file** path, not a directory. Never delete on a duplicate candidate.

## Playlist will not load
`nsp-lint.sh <file>.nsp`, then confirm a scan ran since the file was added.

## Before upgrade/migration
`core-backup-restore-check`. Lidarr has **no downgrade** after a schema migration.
