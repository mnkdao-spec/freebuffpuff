---
name: pkm-sync-choice
description: Choose and reason about synchronisation and conflict models for a knowledge base or local-first app - local-first meanings, file sync vs CRDT merge, avoiding silent note destruction. Use for Obsidian Sync vs Syncthing questions, offline/multi-device design, Yjs/Automerge choices, or lost/duplicated notes.
metadata:
  category: pkm
  stack: sync, crdt
---

# Sync and conflict models

"Local-first" = 4 different claims (local storage / local cache / offline-capable /
**lossless concurrent merge** — only the last needs CRDTs).

## Models
| Model | Examples | Behaviour |
|---|---|---|
| File sync | Syncthing, rsync, cloud drives | **conflict copies** (`*.sync-conflict-*`), **no merge**. One-editor-at-a-time. |
| Vendor sync | Obsidian Sync | **merges Markdown** via text-diff (others: last-wins); merge can duplicate/mangle. E2EE default-but-optional, remote-only (local vault unencrypted); history time-limited. |
| CRDT library | Yjs, Automerge | concurrent updates merge; app owns transport/persistence |
| Sync platform | Electric, Zero, Jazz | server/query designs ≠ CRDTs |

## Vault consequences
- **Sync propagates deletion.** Sync ≠ backup; Sync history is time-limited — back up separately.
- **No double-syncing** (Sync + file-sync on one vault = documented disappearance cause).
- **`.obsidian/` syncs selectively** (opt-in categories; restart after new plugin settings).
- Same-file simultaneous edits (file-sync) → conflict copy; the copy may vanish from view.
- CRDTs trade Markdown portability for concurrent editing — state the trade.

## Lost/duplicated notes
`find` conflict copies; `git log --diff-filter=D` for deletions. Report; don't "repair" merges.
Human decides true text.

## Output
```
GOAL / MODEL (+why) / LOSES (plain words) / BACKUP (independent of sync) / MIGRATION cost / RECOMMEND (one, trade-off stated) / NOT DONE
```
