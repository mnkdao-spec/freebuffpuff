---
name: pkm-capture-to-note
description: Turn raw material into structured draft notes - links, articles, meetings, PDFs, chats, shell output, research - extracting claims, separating source from interpretation, adding frontmatter, staging in the inbox. Use to capture, summarise, file, ingest or "turn this into notes", or building research notes.
metadata:
  category: pkm
  stack: markdown, obsidian
---

# Capture to note

Output = **drafts in the inbox**, never permanent notes. Humans promote.

## Note shape (vault keys first; default if none)
Frontmatter: title / created / updated / tags / status: draft / source / confidence.
Body: Source (one line + when read) / Key points (one claim per bullet) / My interpretation
(marked inferences) / Open questions / Related (**verified-existing** [[links]] only).

## Rules
1. **Source ≠ interpretation.** Mark inferences; flag thin sources.
2. **One idea per note** (Zettelkasten) or one source-note (PARA).
3. **Verify links** (`grep` first) — dead links are broken promises.
4. **Never invent citations** (`source: unverified` + say so; no fabricated authors/dates/URLs).
5. No private data into prompts. 6. **Never promote drafts** (status change = human act).

## Procedure
Inventory input (completeness?) → extract (entities/claims/numbers/dates/contradictions) →
collision-check vault (report; don't merge) → compose → print + stage in `_inbox/` →
list human decisions (promote? merge? links?).

## Output
```
INPUT / CREATED (path + summary) / COLLISIONS / CONFIDENCE / LINKS (VERIFIED vs PROPOSED) / REVIEW / NOT DONE
```

Confident summaries of half-read sources are worse than no notes — state truncation plainly.
