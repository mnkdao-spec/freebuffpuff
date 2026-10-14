---
name: music-lidarr-match-doctor
description: Diagnose why a Lidarr album will not import or will not match - check release-type metadata profiles, quality profiles versus custom formats, the release-group-versus-release MusicBrainz ID mistake, tag quality and the import similarity thresholds, then produce a ranked cause list and the manual-import path. Use when an album is stuck in the queue, when Lidarr says a release is unmatched, when a search returns nothing, or when asked "why won't this album import".
metadata:
  category: music
---

# Lidarr match doctor

Read-only diagnosis of the single most common Lidarr complaint. **Do not** add artists,
trigger searches, or change profiles during diagnosis.

## Model first
- Lidarr tracks **release groups** (the album as a work). A MusicBrainz **release** is one
  edition (country, label, format, remaster, deluxe). Lidarr's import matches files against
  a specific **release** inside the tracked release group.
- **The most common MBID mistake** is adding an album by *release* MBID instead of
  *release-group* MBID. If you are handed an MBID, determine which kind it is before using it:
  `GET https://musicbrainz.org/ws/2/release-group/<mbid>?fmt=json` — a 404 there plus a 200 on
  `/release/<mbid>` means it is a release MBID.
- Where each control acts:
  | Control | Acts on | Does **not** do |
  |---|---|---|
  | Metadata profile | which release-group **types/statuses** are visible/tracked | affect quality |
  | Quality profile | accepted formats, upgrades, cutoff | fix a bad import match |
  | Quality definitions | size/bitrate sanity | pick a specific edition |
  | Custom formats | **grab time only** — release title, release group, source, indexer flags | change how downloaded files are matched at import |
  | Release profiles (legacy) | **grab time** title terms | import matching |

## Import matching, and why it fails
Lidarr's automatic import wants roughly **≥80% album similarity** and **≥60% similarity for
the worst-matching track** for a new download. Its matcher weighs file tags, filenames, track
count, durations and MusicBrainz IDs. Recording IDs are the strongest evidence. Files named
`track01.mp3` with thin tags are much harder to place, and fingerprinting cannot identify a
release that the metadata source does not contain.

## Check, in this order
```bash
L="http://localhost:8686/api/v1"; H=(-H "X-Api-Key: $LIDARR_API_KEY")
curl -s "${H[@]}" "$L/queue?includeUnknownArtistItems=true" | jq '.records[]|{title,status,messages,trackedDownloadStatus}'
curl -s "${H[@]}" "$L/history?pageSize=20" | jq '.records[]|{eventType,sourceTitle,data}'
curl -s "${H[@]}" "$L/wanted/missing?pageSize=10" | jq '.records[]|{title,releaseDate,statistics}'
# does Lidarr see the completed download at all? (path is inside the container)
docker compose exec lidarr ls -la /data/downloads/soulseek/<release>
```
1. **Can the Lidarr process see the files?** Wrong/absent mount, or a path that differs from
   what slskd reported. Check inside the container, not on the host.
2. **Permissions.** `permission denied` = UID/GID/umask, not a missing file.
3. **Extension recognised** by Lidarr, and the folder is a complete release — not an
   in-progress transfer and not a multi-album pack.
4. **Tags.** Album / Album Artist / Track Number / Disc. Are MusicBrainz IDs present? Compare
   the *number of tracks* against the release.
5. **Album duration 0.** If Lidarr reports duration 0, MusicBrainz may lack track lengths for
   that release; the FAQ notes this can cause search results to be rejected. Try another
   edition, or check the MusicBrainz release directly.
6. **Release-type filtering.** The metadata profile may exclude the release-group type or
   status (e.g. it is classified Unknown, or is a single/EP/live/compilation you don't track).
7. **Propagation lag.** A recent MusicBrainz edit may not have reached Lidarr's metadata cache.
8. **Nothing at all left to try?** Then the fix is Manual Import, and that is a human step.

## The fix that is almost always right
**Manual Import** — `Activity → Queue → Manual Import` for a queued item, or
`Wanted → Manual Import` for a stray folder. It lets a human pick artist, album, edition and
the track mapping. Do not attempt to force an automatic match by rewriting tags blind.
If the folder came from outside Lidarr, it must be staged **outside** the library root;
copying files directly into the library bypasses the import pipeline and Lidarr will not know
they exist.

## Output format
```
TARGET:      artist / album / release-group MBID (and whether it is a release-group or release id)
SYMPTOM:     won't import | won't match | search finds nothing | stuck in queue
EVIDENCE:    literal queue/history/health entries, quoted
RANKED CAUSES: 1..n, each with the observation that supports it and the probe that would disconfirm
PATH:        inside-container path check: exists? readable? complete?
RECOMMEND:   exact next step, read-only, or "Manual Import: <exact menu path>"
NOT CHANGED: no profiles, artists or searches were modified
```

## Never
- Change a quality profile, metadata profile or custom format as a "fix" for an import problem.
  Custom formats act at grab time; they cannot repair an existing mismatch.
- Add the artist/album again, or trigger a search, to test a theory.
- Rename or retag files to force a match.
