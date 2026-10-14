# Runbook: knowledge base

## Ground rules
- Read `pkm-vault-conventions` first for an unfamiliar vault.
- The **only** folder an agent writes to is the inbox, as `status: draft`.
- Never delete, rename, move or bulk-edit a note. Merge is human.
- Never touch `.obsidian/`.

## Capture
Read the source, stage drafts in `<vault>/_inbox/` with the vault's frontmatter keys.
One idea per note. Verify every [[wikilink]] exists (grep first). Stay draft. Print paths, stop.

## Find something
`grep -ril "<term>" <vault> --include=*.md | head -20`. Full-text for names/IDs/quotes;
embeddings for "what have I written about X".

## Weekly review (human, assisted)
List `_inbox/` drafts; propose placement + links as candidates; human promotes/discards.

## If notes go missing
`find` conflict copies; `git log --diff-filter=D` for deletions. Sync propagates deletion;
if you rely on sync, you do not have a backup. See `pkm-sync-choice`.
