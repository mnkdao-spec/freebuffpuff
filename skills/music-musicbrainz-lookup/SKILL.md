---
name: music-musicbrainz-lookup
description: Look up MusicBrainz metadata correctly and politely - identify whether an ID is a release, release-group, recording or release-track, respect the one-request-per-second limit with a proper User-Agent, handle throttling, and fetch cover art from the Cover Art Archive. Use when you need an artist, album or track MBID, when checking whether an album exists in MusicBrainz, when a release lookup returns the wrong edition, when adding MBIDs to tags, or before any bulk metadata operation.
metadata:
  category: music
  stack: musicbrainz, cover-art-archive
---

# MusicBrainz lookup

Read-only, but rate-limited and etiquette-bound. An agent that loops on this API gets you
throttled, and throttling is not an error you can retry your way out of.

## Use the wrapper, not raw curl
```bash
bash scripts/mb-lookup.sh whoami                                   # show your User-Agent
bash scripts/mb-lookup.sh search-release-group "<artist>" "<album>"
bash scripts/mb-lookup.sh search-recording    "<artist>" "<track>"
bash scripts/mb-lookup.sh lookup release-group <mbid>
bash scripts/mb-lookup.sh lookup release       <mbid>
bash scripts/mb-lookup.sh classify <mbid>                          # which kind of ID is this?
```
It enforces **≥1.1 s between requests serialised across processes sharing the IP**, caches
responses, backs off on `503`, and sends a meaningful User-Agent. Set `MB_USER_AGENT` to
something that identifies you (`app/version (contact)`) before any bulk use — MusicBrainz
requires a genuine User-Agent, and the documented limit is **one request per second per client**.

Rules the wrapper encodes, so follow them if you ever call the API directly:
- **Never rotate clients or user agents to dodge throttling.**
- **`503` means back off**, not retry immediately. Do not hammer.
- **Cache.** Repeating a lookup you already made is wasted budget and bad manners.
- **Coordinate.** Any other tool on the same IP shares the same 1 req/s budget.

## The ID trap (this breaks Lidarr)
| Identifier | Means | Picard tag |
|---|---|---|
| **release** | one issued edition (country/label/format/remaster) | `MUSICBRAINZ_ALBUMID` |
| **release group** | the album as a work, across editions | `MUSICBRAINZ_RELEASEGROUPID` |
| **recording** | the recorded audio of a track | `MUSICBRAINZ_TRACKID` (Vorbis) |
| **release track** | a track position on one release, *not* the same as a recording | `MUSICBRAINZ_RELEASETRACKID` |

When adding an album in Lidarr you want the **release-group** MBID. Confusing release with
release-group is the single most common documented mistake. Run `classify` when unsure.

## Cover art
Use the **Cover Art Archive**, never a guessed image URL:
```
https://coverartarchive.org/release/<release-mbid>/          # all artwork for a release
https://coverartarchive.org/release/<release-mbid>/front     # selected front cover
https://coverartarchive.org/release-group/<rg-mbid>/         # art sourced from a member release
```
A successful download is **not** proof the image matches your copy — check deluxe, regional and
remastered editions before embedding anything. Handle `503` here too.

## Practical rules
- Prefer a release-specific lookup when edition accuracy matters; prefer release-group when you
  only need "does this album exist".
- MusicBrainz lacks track lengths for some releases. If Lidarr reports an album duration of 0,
  that is usually why — the release may be rejected in search results.
- Recent edits take time to propagate to consumers (Lidarr's metadata cache included). A
  brand-new album may genuinely not be visible yet.
- **Never submit model output as MusicBrainz data.** Data changes go through community review
  and voting; treat anything you generate as a proposal for a human, not a fact.

## Output format
```
QUERY:      what was searched, and against which entity type
RESULTS:    mbid | title | type | artist  (verbatim from the API)
INTERPRET:  which MBID to use for the task, and why
THROTTLED:  any 503s, retries, and how long you waited
NOT FOUND:  say so plainly instead of offering the nearest plausible match
```

## Never
- Bulk-fetch hundreds of entities without explicit approval and a documented budget.
- Add MBIDs to tags as part of a lookup task. Lookup reports; retagging is a separate,
  reviewed step (`music-beets-preview`).
