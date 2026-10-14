---
name: music-library-audit
description: Produce a read-only health report for a music library - tag completeness, codec and bitrate anomalies, extension-versus-codec mismatches, FLAC integrity failures, duplicate candidates and possible duplicate editions - without changing, moving or deleting anything. Use when asked to audit or clean up a library, when the library feels messy or duplicated, when disk usage is higher than expected, before a bulk metadata pass, or when a music server is missing albums.
metadata:
  category: music
  stack: flac, ffprobe, beets
---

# Library audit

Read-only. Deliverable = report + ranked human-action candidates, never cleanup.

## Run the auditor
```bash
bash scripts/lib-audit.sh <music-dir>
bash scripts/lib-audit.sh <music-dir> --hash
bash scripts/lib-audit.sh <music-dir> --max 5000 --out <scratch>/reports/audit.json
```
Reports: files scanned, tool availability, tag completeness %, FLAC integrity (`flac -t`),
anomalies (low bitrate, zero-length, odd sample rates), extension-vs-codec mismatches,
same artist+album+title groups, size+duration duplicate candidates (+optional content hash).

## Meanings
- **FLAC failure** = audio ≠ stored signature. Recovery = restore/re-rip; retagging fixes nothing.
- **Missing tags** = top cause of server splits (see tagging-doctor before tag fixes).
- **Extension mismatch** = hint only; spectrogram is heuristic, never verdict.
- **Size+duration dupes** = candidates; distinct MBIDs can mean legit editions. Review queue.
- Cannot decide what to keep; doesn't detect transcodes; doesn't know your priorities.

## Procedure
1. Run read-only; report exact cmd. 2. Counts first, then worst 10-20 per category.
3. Triage: **bulk-safe** / **needs review** / **human decision**. 4. Report to scratch, never library.
5. Propose at most one reversible next action.

## Output
```
COMMAND / SCOPE / COUNTS / WORST / TRIAGE / PROPOSED / NOT DONE
```

## Never
Delete anything (dupes, "corrupt", "confirmed identical" — human's call); retag from this
report alone; present heuristics as proof.
