---
name: music-musicbrainz-lookup
description: Look up MusicBrainz metadata correctly and politely - identify ID kinds, respect one-request-per-second with a proper User-Agent, handle throttling, fetch Cover Art Archive art. Use for artist/album/track MBIDs, existence checks, wrong-edition lookups, pre-tag MBID work, or before bulk metadata ops.
metadata:
  category: music
  stack: musicbrainz, cover-art-archive
---

# MusicBrainz lookup

Read-only but rate-limited and etiquette-bound. Looping gets you throttled.

## Use the wrapper
```bash
bash scripts/mb-lookup.sh whoami
bash scripts/mb-lookup.sh search-release-group "<artist>" "<album>"
bash scripts/mb-lookup.sh search-recording "<artist>" "<track>"
bash scripts/mb-lookup.sh lookup release-group <mbid>
bash scripts/mb-lookup.sh classify <mbid>
```
Enforces **≥1.1 s between requests** (cross-process), caches, backs off on `503`, sends real
User-Agent. Set `MB_USER_AGENT` (`app/version (contact)`) before bulk use. Limit: **1 req/s/client**.
Never rotate clients to dodge throttling. `503` = back off. Cache. Coordinate per-IP budget.

## ID trap (breaks Lidarr)
| Identifier | Means | Picard tag |
|---|---|---|
| **release** | one edition | `MUSICBRAINZ_ALBUMID` | **release group** | album as work | `MUSICBRAINZ_RELEASEGROUPID` |
| **recording** | track audio | `MUSICBRAINZ_TRACKID` | **release track** | position on a release ≠ recording | `MUSICBRAINZ_RELEASETRACKID` |

Lidarr wants the **release-group** MBID. `classify` when unsure.

## Cover art
CAA only (`/release/<mbid>/`, `/front`). Download ≠ match — verify edition. Handle `503`.

## Practical rules
- Release-specific lookup for edition accuracy; release-group for existence.
- Duration-0 albums: MB often lacks lengths → search rejections. Try another edition.
- Recent MB edits propagate slowly (incl. Lidarr cache). New albums may be invisible yet.
- **Never submit model output as MB data.** Community review/voting; proposals only.

## Output
```
QUERY / RESULTS (mbid | title | type | artist, verbatim) / INTERPRET / THROTTLED / NOT FOUND (plainly, no nearest-guess)
```

## Never
Bulk-fetch hundreds without approval + budget; write MBIDs to tags in a lookup task (separate reviewed retag).
