---
name: music-navidrome-tagging-doctor
description: Diagnose why Navidrome splits one album into several, hides tracks, mis-attributes artists, or ignores a retag - audit tags against Navidrome's grouping rules, check multi-value artist fields, compilation flags and album identity, and produce a fix plan that does not corrupt the library. Use when albums are duplicated or fragmented, when an artist appears twice, when a Various Artists release is shredded, when cover art is wrong, or when a retag had no effect.
metadata:
  category: music
  stack: navidrome, tags
---

# Navidrome tagging doctor

Navidrome is **tag-oriented**. Folders and filenames do not define albums or artists — tags do.
Almost every grouping complaint is a tag consistency problem.

## How Navidrome decides
- **Album identity** prefers the `musicbrainz_albumid` tag. Without it, the album is derived from
  album artist + album + version/date. **Track identity** prefers a MusicBrainz track ID,
  otherwise album/disc/track/title. Both are configurable via `PID.Album` / `PID.Track` — and
  changing those triggers a **full rescan**, with a documented recommendation to back up the
  database first.
- **Artists.** `ARTISTS` / `ALBUMARTISTS` are multi-value and are treated as explicit, distinct
  artist entities — Navidrome does **not** split them on separators. When both singular and
  plural tags exist, the singular `ARTIST`/`ALBUMARTIST` is the display text and the plural tag
  supplies the entities. If only plural values exist, they are joined (default ` • `) for display.
- With only a singular `ARTIST`, Navidrome **does** split on defaults such as ` / `, ` feat. `,
  ` ft. ` and `; ` — which is how `AC/DC` becomes two artists. `Scanner.ArtistSplitExceptions`
  exists for exactly this.
- **Compilations.** All tracks need the same Album Artist (usually `Various Artists`) *and* the
  compilation flag (`TCMP=1` for ID3, `COMPILATION=1` for Vorbis/FLAC). Keep each track's own
  artist; do not overwrite track artists with `Various Artists`.
- **Dates.** `DATE` maps to recording date; `YEAR` is the **release** date; `ORIGINALDATE` /
  `ORIGINALYEAR` map to original release. Mixing these shifts album ordering and grouping.
- **Format trap.** FLAC uses Vorbis comments (repeated fields allowed); MP3 uses ID3. Some
  editors write duplicate MP4 atoms for multi-value tags in AAC/M4A, so only one value shows —
  re-saving with a tool that supports multiple values fixes it.

## Audit, read-only
```bash
# what Navidrome actually sees for one album (Subsonic API, never modifies anything)
curl -s "http://localhost:4533/rest/getAlbum?id=<ALBUM_ID>&u=$ND_USER&t=$ND_TOKEN&s=$ND_SALT&v=1.16.1&c=agent&f=json" | jq '.subsonic-response.album | {name,artist,artistId,songCount}'

# tag inventory for the folder - read-only dump
for f in "<album dir>"/*.flac; do
  echo "== $f"; metaflac --export-tags-to=- "$f" | grep -iE '^(ALBUM|ALBUMARTIST|ALBUMARTISTS|ARTIST|ARTISTS|TRACKNUMBER|DISCNUMBER|DATE|YEAR|COMPILATION|MUSICBRAINZ_)'
done | head -80
```
Check, in this order: same `ALBUM` across tracks -> same `ALBUMARTIST` across tracks ->
present and unique `TRACKNUMBER` (with `DISCNUMBER` for multi-disc) -> `MUSICBRAINZ_ALBUMID`
consistent -> compilation flag if it is a compilation -> separator hazards in artist names.

## The rule that saves hours
**Move first, scan, then retag, then scan.** Doing a move and a retag in the same operation
prevents Navidrome from matching the file to its existing record, which produces "missing" files
and lost play counts. Missing files are, by default, only marked missing — not deleted — which
preserves ratings, play counts and playlist references. Do not suggest `Scanner.PurgeMissing`.

Also: **custom-tag configuration changes and `PID.*` changes require a full scan**; a quick scan
will not reprocess them. And artwork is cached — changing `CoverArtPriority` alone does not
refresh stored artwork.

## Output format
```
ALBUM:       path, track count
GROUPING:    how Navidrome currently resolves it (album id source, artist entities)
DEFECTS:     one line per problem, each with the file + tag value that causes it
FIX PLAN:    ordered, per-file tag changes; state "preview then apply" explicitly
SCAN ORDER:  the exact scan sequence (move -> scan -> retag -> scan)
REVIEW:      which changes need a human decision (artist credits, merges, VA handling)
NOT CHANGED: confirm nothing was retagged, moved or deleted
```

## Never
- Retag or move files as part of the diagnosis.
- Rewrite artist credits to fix a split; fix the tag that caused it (or add a split exception).
- Collapse deluxe/remaster/reissue editions into one just because titles look similar — they are
  legitimately different releases.
- Run a full rescan after a `PID.*` change without confirming a database backup exists.
