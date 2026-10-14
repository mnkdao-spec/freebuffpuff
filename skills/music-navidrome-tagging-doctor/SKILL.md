---
name: music-navidrome-tagging-doctor
description: Diagnose why Navidrome splits albums, hides tracks, mis-attributes artists, or ignores a retag - audit tags against grouping rules, multi-value artist fields, compilation flags and album identity, with a fix plan that cannot corrupt the library. Use for duplicated/fragmented albums, doubled artists, shredded compilations, wrong art, or ineffective retags.
metadata:
  category: music
  stack: navidrome, tags
---

# Navidrome tagging doctor

Navidrome is **tag-oriented**: folders don't define albums — tags do.

## Grouping rules
- **Album identity** prefers `musicbrainz_albumid`, else album artist + album + version/date.
  `PID.Album`/`PID.Track` changes need a **full scan** (back up DB first).
- **Artists:** `ARTISTS`/`ALBUMARTISTS` are multi-value entities (never split). Singular
  `ARTIST` alone **is** split on ` / `, ` feat. `, ` ft. `, `; ` — hence split exceptions for `AC/DC`.
- **Compilations:** uniform Album Artist + compilation flag (`TCMP=1` ID3, `COMPILATION=1` Vorbis).
  Never overwrite track artists with Various Artists.
- **Dates:** `DATE` = recording, `YEAR` = release. FLAC = Vorbis comments; MP3 = ID3v2.4.

## Audit (read-only)
Dump tags per folder (`metaflac --export-tags-to=-` filtered to ALBUM*/ARTIST*/TRACK/DATE/YEAR/
COMPILATION/MUSICBRAINZ_*); check ALBUM → ALBUMARTIST → TRACKNUMBER/DISCNUMBER →
MB_ALBUMID → compilation flag → separator hazards.

## The rule saving hours
**Move first, scan, then retag, then scan.** Move+retag at once breaks matching ("missing"
files, lost play counts). Missing files are marked missing, not deleted — never suggest
`Scanner.PurgeMissing`. Custom-tag/`PID.*` changes need full scans; art is cached.

## Output
```
ALBUM / GROUPING (id source, entities) / DEFECTS (file + tag each) / FIX PLAN (ordered, preview-then-apply) / SCAN ORDER / REVIEW (human decisions) / NOT CHANGED
```

## Never
Retag/move during diagnosis; rewrite credits to fix splits; merge distinct editions;
full rescan after `PID.*` change without a confirmed DB backup.
