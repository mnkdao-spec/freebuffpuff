---
name: music-lyrics-and-art
description: Fetch and attach lyrics and cover art for a music library with sidecar-first review - use LRCLIB for lyrics and the Cover Art Archive for art, verify the match against the actual edition, keep originals, and treat embedding as a separate reviewed step. Use when asked to add missing lyrics or artwork, when cover art is wrong, or when planning a bulk metadata enrichment pass.
metadata:
  category: music
  stack: lyrics, cover-art-archive, beets
---

# Lyrics and artwork

Both are enrichment: valuable, optional, and easy to get *plausibly* wrong. Work sidecar-first.

## Lyrics
- **LRCLIB** provides plain and time-synced lyrics and is a source used by beets' `lyrics`
  plugin; `lrcget` writes `.lrc` sidecars next to the audio.
- Sidecar `.lrc` files are non-destructive and easy to revert. Write those first; embedding into
  tags is a second, reviewed step.
- **Matching is genuinely unreliable** for covers, live versions, remixes and similar titles.
  Report a confidence judgement (exact artist+title+duration match, or "guessed") and never
  silently accept a guess.
- Lyrics are copyrighted. Fetching them into a private library is not the same as having the
  right to redistribute them — do not copy lyrics into reports, commits, or shared files.

## Artwork
- Use the **Cover Art Archive**, never a guessed URL:
  `https://coverartarchive.org/release/<release-mbid>/` (list) and `/front` (selected front).
  Release-group endpoints return art sourced from a member release.
- **A download is not a match.** Deluxe, remaster, regional and compilation editions differ.
  Compare against the actual release MBID — `music-musicbrainz-lookup` tells you which kind of
  ID you hold.
- Prefer a `cover.jpg` sidecar beside the album. **Embedding rewrites every track file**, can
  enlarge them substantially, and is much harder to undo than deleting a sidecar.
- Watch the resolution order: per-track embedded art can take precedence over album-level art in
  players. Embedding art per track when the library wants one album cover produces a different
  result than the audio files suggest.
- Cached artwork is not always refreshed just because you changed a priority setting.

## Procedure
1. Identify candidates, read-only: which albums lack sidecar art or `.lrc` files.
2. Resolve the correct identifier per album (`music-musicbrainz-lookup classify`).
3. Fetch to a scratch staging directory — **not** into the library.
4. Show the human what was staged, with the source URL and why it matched.
5. Only after approval: copy the sidecars into the library, or run the reviewed embed step.
6. Re-scan the music server if the change should be visible there.

## Output format
```
STAGED:     scratch path, file count, total size
MATCHES:    album -> source URL -> why it is believed correct (release MBID, track count, year)
UNCERTAIN:  items where the match is a guess - listed separately, not staged
PROPOSED:   the exact copy/embed commands, for approval
REVERT:     how to undo (delete sidecar / restore tag backup)
LICENCE:    note that lyrics are copyrighted if they were fetched
NOT TOUCHED: confirm nothing was embedded or written into the library yet
```

## Never
- Download art or lyrics directly into the library without staging and review.
- Embed artwork as part of a "clean up metadata" pass.
- Delete or overwrite existing art that you have not compared.
