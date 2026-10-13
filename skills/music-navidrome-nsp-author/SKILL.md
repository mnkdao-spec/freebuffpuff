---
name: music-navidrome-nsp-author
description: Author and validate Navidrome smart playlists (.nsp JSON rule files) - design rule sets from library fields, generate the JSON, lint it, and explain exactly how the scan picks it up. Use when asked to create a playlist, build a "best of" or "recently played" list, turn a description into playlist rules, or fix a smart playlist that will not load.
metadata:
  category: music
  stack: navidrome
---

# Navidrome smart playlist author

Navidrome smart playlists are **JSON rule files** named `*.nsp`, saved in the library or a
configured `PlaylistsPath`, imported during a scan. The playlist is evaluated dynamically and is
read-only in the UI — the rules live in the file. Feishin can edit them too.

This is the safest AI-facing music task in the whole stack: writing rules touches **no audio
files** and cannot corrupt tags. It is still a file write, so preview it.

## Rules
1. **Never overwrite an existing `.nsp`.** Create a new file, or write a `.nsp.new` for the human
   to review. State the target path explicitly.
2. **Keep it small.** One playlist, one intent.
3. **Lint before proposing.** `bash scripts/nsp-lint.sh <file>.nsp` (next to this SKILL.md).
4. **A scan is required for Navidrome to import it.** Say so; do not trigger a scan yourself.
5. **Don't invent fields.** Prefer fields you can see in the library: tags, dates, play counts,
   ratings, album/artist properties, MusicBrainz IDs, `library_id`.

## Shape
```json
{
  "name": "Late night instrumental",
  "comment": "why this exists, for your future self",
  "all": [
    { "is":   { "genre": "Ambient" } },
    { "is":   { "playCount": 0 } }
  ],
  "any": [
    { "gt": { "rating": 3 } },
    { "inTheLast": { "addedAt": "90d" } }
  ],
  "sort": "-rating,title",
  "limit": 100,
  "refreshDelay": "1d"
}
```
- `all` = AND, `any` = OR; rule groups nest by repeating the operator.
- Operators seen in the docs: `is`, `contains`, `gt`, `inTheRange`, `inTheLast`, `isMissing`, plus
  playlist references. Lint warns on anything unrecognised rather than guessing.
- `sort` accepts multiple fields with a `-` prefix per field for descending.
- `limit` or `limitPercent` bound the result. `refreshDelay` stabilises randomised lists so
  offline-caching clients do not thrash.
- `library_id` scopes a rule to one of several libraries.

## Procedure
1. Translate the request into a testable sentence ("tracks in genre Ambient, never played,
   rated above 3, added in the last 90 days").
2. Map each clause to a field the library actually has. If a field's existence is uncertain,
   say so and offer the closest alternative instead of inventing one.
3. Write the JSON; run the linter; fix every PROBLEM, and decide on each warning deliberately.
4. Report the path, the rules in plain English, and the expected effect on an empty library
   (usually: empty playlist — say that rather than implying it will be full).

## Output format
```
FILE:      proposed path (never an existing file)
INTENT:    one sentence
RULES:     plain-English rendering of each clause, with the field used
LINT:      linter output, verbatim
IMPORT:    "a scan imports this; run it when you're ready" + how
CAVEAT:    fields that may not exist in this library; expected result on a thin library
NOT DONE:  no scan triggered, no existing playlist modified
```

## Never
- Write into the music library without being asked to. Propose the path first.
- Assume a tag exists because it is common (moods, BPM, `albumtype`) — Navidrome reads tags from
  your files, and custom tags only exist if configured in `navidrome.toml` (which needs a full scan).
