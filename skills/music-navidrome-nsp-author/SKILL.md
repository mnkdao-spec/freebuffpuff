---
name: music-navidrome-nsp-author
description: Author and validate Navidrome smart playlists (.nsp JSON rule files) - design rule sets from library fields, generate the JSON, lint it, and explain how the scan picks it up. Use to create playlists, build best-of/recent lists, turn descriptions into rules, or fix a playlist that won't load.
metadata:
  category: music
  stack: navidrome
---

# Navidrome smart playlist author

`.nsp` JSON rule files in the library/`PlaylistsPath`, imported during scans, read-only in UI.
Safest AI music task: rules touch **no audio files**. Still preview writes.

## Rules
1. **Never overwrite an existing `.nsp`.** New file or `.nsp.new` for review.
2. **One playlist, one intent.** 3. **Lint first** (`scripts/nsp-lint.sh`).
4. **A scan imports it** — say so; don't trigger scans. 5. **Don't invent fields** — use tags,
   dates, play counts, ratings, MBIDs, `library_id` actually in the library.

## Shape
`all` = AND, `any` = OR. **One level may not mix both** (Navidrome ≥0.63.2 rejects; linter fails it).
Nest the OR branch inside AND. Documented operators (0.64.x): `is`, `isNot`, `gt`, `lt`,
`contains`, `notContains`, `startsWith`, `endsWith`, `inTheRange`, `before`, `after`,
`inTheLast`, `notInTheLast`, `inPlaylist`, `notInPlaylist`, `isMissing`, `isPresent`.
`gte`/`lte`/`in` are **not** documented (linter warns). Top-level keys: `name`, `comment`,
`public`, `all`, `any`, `sort`, `order`, `limit`, `limitPercent`, `refreshDelay`. No `owner` key.
`sort` takes multiple `-`-prefixed fields; `random` special. `limit`/`limitPercent` bound results.

## Procedure
1. Testable sentence. 2. Map clauses to real fields (flag uncertainty; offer alternatives).
3. Write JSON; lint; fix PROBLEMs, decide warnings. 4. Report path, plain-English rules,
   empty-library expectation.

## Output
```
FILE (proposed, never existing) / INTENT / RULES / LINT (verbatim) / IMPORT (scan note + how) / CAVEAT / NOT DONE
```

## Never
Write into the library unasked; assume tags exist (moods/BPM/`albumtype` need `navidrome.toml`
custom-tag config + full scan).
