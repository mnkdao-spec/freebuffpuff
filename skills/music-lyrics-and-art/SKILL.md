---
name: music-lyrics-and-art
description: Fetch and attach lyrics and cover art with sidecar-first review - use LRCLIB for lyrics and Cover Art Archive for art, verify against the actual edition, keep originals, and treat embedding as a separate reviewed step. Use when adding missing lyrics/artwork, when art is wrong, or planning bulk enrichment.
metadata:
  category: music
  stack: lyrics, cover-art-archive, beets
---

# Lyrics and artwork

Enrichment: valuable, optional, easy to get *plausibly* wrong. Sidecar-first.

## Lyrics
- **LRCLIB** (plain + synced); `lrcget` writes `.lrc` sidecars. Sidecars revert easily;
  embedding is a second reviewed step.
- **Matching is unreliable** for covers/live/remixes/similar titles. Judge confidence
  (exact artist+title+duration vs "guessed"); never silently accept guesses.
- Lyrics are copyrighted: private-library fetching ≠ redistribution rights. Don't copy
  lyrics into reports/commits/shared files.

## Artwork
- **Cover Art Archive** only (`/release/<mbid>/`, `/front`); release-group endpoints source
  from a member release. **A download is not a match** — check deluxe/remaster/regional editions
  against the actual release MBID.
- Prefer `cover.jpg` sidecars. **Embedding rewrites every track**, enlarges files, hard to undo.
- Per-track embedded art can override album art in players. Cached art may not refresh on
  priority changes.

## Procedure
1. Candidates read-only (missing sidecars). 2. Resolve IDs (`mb-lookup classify`).
3. Fetch to **scratch staging, not the library**. 4. Show human: source URL + match reason.
5. After approval: copy sidecars or run reviewed embed. 6. Re-scan server if needed.

## Output
```
STAGED / MATCHES (album → URL → why) / UNCERTAIN (guesses, unstaged) / PROPOSED / REVERT / LICENCE NOTE / NOT TOUCHED
```

## Never
Download into the library without staging+review; embed in a "cleanup" pass;
delete/overwrite uncompared existing art.
