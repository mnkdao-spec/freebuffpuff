---
name: music-library-audit
description: Produce a read-only health report for a music library - tag completeness, codec and bitrate anomalies, extension-versus-codec mismatches, FLAC integrity failures, duplicate candidates and possible duplicate editions - without changing, moving or deleting anything. Use when asked to audit or clean up a library, when the library feels messy or duplicated, when disk usage is higher than expected, before a bulk metadata pass, or when a music server is missing albums.
metadata:
  category: music
  stack: flac, ffprobe, beets
---

# Library audit

Read-only. The deliverable is a report and a ranked list of candidates for a human to act on,
never a cleanup.

## Run the auditor
```bash
bash scripts/lib-audit.sh <music-dir>                  # next to this SKILL.md
bash scripts/lib-audit.sh <music-dir> --hash           # confirm duplicates by content
bash scripts/lib-audit.sh <music-dir> --max 5000 --out <scratch>/reports/audit.json
```
It reports: files scanned, tools available, per-tag completeness percentages, FLAC integrity
failures (`flac -t`), anomalies (very low bitrate, lossless codec with a suspiciously low
bitrate, zero-length/unreadable duration, unusual sample rates), extension-vs-codec mismatches,
groups of tracks sharing artist+album+title, and duplicate candidates by size+duration with an
optional content hash to separate "identical" from "similar".

## What the findings mean, and what they do not
- **FLAC integrity failure** = the decoded audio does not match the stored signature. Recovery
  means restoring a known-good copy or re-ripping. Renaming or retagging "fixes" nothing.
- **Missing tags** are the leading cause of a server splitting albums and artists. See
  `music-navidrome-tagging-doctor` before proposing any tag fixes.
- **Extension vs codec mismatch** is a **hint**, not proof. Only a spectrogram (a heuristic,
  never a verdict) plus provenance can speak to whether a file came from a lossy source.
- **Duplicate candidates by size+duration** are just that — candidates. Different MusicBrainz
  release IDs legitimately mean different editions (deluxe, remaster, regional reissue,
  catalogue variants). Same-title groups are a *review* queue.
- This audit **cannot** decide what to keep. It does not rank by provenance, does not detect
  transcodes, and does not know what you care about.

## Procedure
1. Run the auditor read-only. Report the exact command.
2. Summarise the counts first, then the worst 10-20 items per category.
3. Group findings into: **safe to fix in bulk** (missing sidecar art, empty genre),
   **needs review** (duplicates, odd bitrates, mismatches), **needs a human decision**
   (editions, deletion, re-ripping).
4. Write the report to the scratch directory, never into the library.
5. Propose at most one next action, and make it reversible.

## Output format
```
COMMAND:    exact auditor invocation
SCOPE:      directory, files scanned, cap applied
COUNTS:     scanned / missing tags / anomalies / integrity failures / mismatch / dupe groups
WORST:      the most severe items, with paths and the literal finding
TRIAGE:     safe-to-fix | needs review | needs a decision
PROPOSED:   one reversible next action, for approval
NOT DONE:   no file was modified, moved, retagged or deleted
```

## Never
- Delete anything. Not duplicates, not "obviously corrupt" files, not one of a "confirmed"
  identical pair — deleting either hardlink of a pair has implications, and deleting either copy
  of a real duplicate is still a human's call.
- Rewrite tags based on this report alone; that is a separate reviewed task.
- Present a heuristic (spectrogram cutoff, bitrate, file size) as proof of quality.
