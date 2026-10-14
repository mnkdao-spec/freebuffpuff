---
name: music-lidarr-match-doctor
description: Diagnose why a Lidarr album will not import or match - check metadata/quality profiles, the release-group-versus-release MBID mistake, tag quality and import thresholds, then a ranked cause list and the manual-import path. Use when an album is stuck, unmatched, search finds nothing, or "why won't this import".
metadata:
  category: music
---

# Lidarr match doctor

Read-only. **Do not** add artists, trigger searches, or change profiles during diagnosis.

## Model
- Lidarr tracks **release groups** (album as work); a **release** is one edition.
- **Top MBID mistake:** adding by *release* MBID instead of *release-group* MBID. Check kind first:
  `GET /ws/2/release-group/<mbid>?fmt=json` — 404 there + 200 on `/release/<mbid>` = release MBID.
- Controls: **Metadata profile** (visible types/statuses, not quality) | **Quality profile**
  (formats/upgrades/cutoff, not match repair) | **Quality definitions** (size sanity) |
  **Custom formats** = **grab time only** (can't fix import mismatch) | **Release profiles** = grab-time terms.

## Import matching
Auto-import wants roughly **≥80% album similarity** and **≥60% worst-track similarity**.
Matcher weighs tags, filenames, track count, durations, MBIDs. Recording IDs strongest.
`track01.mp3` + thin tags = hard. No fingerprint fallback for unknown releases.

## Check order
1. **Can Lidarr see the files?** Check inside the container, not the host.
2. **Permissions** (`permission denied` = UID/GID/umask). 3. **Extension recognised**, folder
   complete (not partial transfer / multi-album pack). 4. **Tags** (Album/AlbumArtist/Track/Disc;
   MBIDs present? track count vs release?). 5. **Duration 0** → MB lacks lengths; try another edition.
6. **Release-type filtering** (metadata profile exclusions). 7. **Propagation lag** (recent MB edits).
8. Else: **Manual Import** (`Activity → Queue → Manual Import`) — a human step. Stage stray
   folders **outside** the library root; direct copies bypass the pipeline.

## Output
```
TARGET (artist/album/MBID kind) / SYMPTOM / EVIDENCE (quoted) / RANKED CAUSES / PATH / RECOMMEND / NOT CHANGED
```

## Never
- Change profiles/formats to "fix" imports (grab-time only). - Add artist/album or trigger search
  to test theories. - Rename/retag to force a match.
