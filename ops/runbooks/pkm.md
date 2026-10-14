# Runbook: knowledge base

## Ground rules
- Read `.agents/skills/pkm-vault-conventions` first if you have not read the vault before.
- The **only** folder an agent writes to is the inbox, and only as `status: draft`.
- Never delete, rename, move or bulk-edit a note. Merge is a human decision.
- Never touch `.obsidian/`.

## Capture
```
Read <the source>, then stage draft notes in <vault>/_inbox/ using the vault's existing
frontmatter keys. One idea per note. Separate what the source says from your interpretation.
Verify every [[wikilink]] you write actually exists (grep first). Do not promote anything -
status stays draft. Print the paths and the full content, then stop.
```

## Find something
```bash
grep -ril "<term>" <vault> --include=*.md | head -20
```
Prefer full-text search for names, IDs and quotes; embeddings are for "what have I written about X".

## Weekly review (human, assisted)
1. List `_inbox/` notes with `status: draft`.
2. For each: propose where it belongs and which existing notes it should link to - as candidates.
3. The human promotes or discards.

## If notes go missing
```bash
find <vault> -name "*conflict*" -o -name "*sync-conflict*" -o -name "* (1).md"
git -C <vault> log --diff-filter=D --name-only --since="30 days ago" 2>/dev/null | head
```
Sync propagates deletion; if you rely on sync, you do not have a backup. See `pkm-sync-choice`.
