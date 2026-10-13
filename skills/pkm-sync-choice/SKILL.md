---
name: pkm-sync-choice
description: Choose and reason about synchronisation and conflict models for a knowledge base or local-first app - recognise that "local-first" means different things, distinguish file sync from CRDT merge, and avoid letting a sync tool silently destroy notes. Use when asked about Obsidian Sync versus Syncthing, when designing offline or multi-device support, when choosing between Yjs, Automerge and a sync platform, or when notes are being lost or duplicated across devices.
metadata:
  category: pkm
  stack: sync, crdt
---

# Sync and conflict models

"Local-first" is used loosely and means at least four different things: content stored locally,
a local cache for speed, an offline-capable app, and *concurrent edits that merge without loss*.
Only the last one requires a CRDT, and only the last one makes multi-device editing safe for the
same file.

## Pick from the model, not the brand
| Model | Examples | Behaviour to expect |
|---|---|---|
| File sync | Syncthing, rsync, cloud drives | transfers blocks and detects concurrent edits by producing a **conflict copy**; it does **not** merge paragraphs. Fine for one editor at a time. |
| Vendor sync | Obsidian Sync | integrated version history; end-to-end encryption applies to the *remote* vault, not the local one |
| CRDT library | Yjs, Automerge | concurrent updates merge; the app owns transport and persistence |
| Sync platform | Electric, Zero, Jazz, InstantDB | server-authoritative or query-based designs; not synonymous with CRDTs |

A real-time API is not proof of CRDT semantics, and a CRDT library is not a sync service. Ask
about the actual conflict model, offline guarantees, persistence, permissions and portability.

## Consequences for a notes vault
- **Sync propagates deletion.** Every device deletes too. Sync is not a backup; version history or
  a separate backup is.
- **Do not sync app state.** Syncing `.obsidian/` across devices with different plugin versions is
  a reliable source of corruption. Sync notes; configure the app per device.
- **Editing the same file on two devices simultaneously** in a file-sync setup produces a conflict
  copy, and it is the copy — not the original — that may disappear from view.
- **If you build on CRDTs**, the note format stops being plain Markdown in practice. That is a
  trade of portability for concurrent editing. Say so, and say which you value.

## Diagnosing lost or duplicated notes
```bash
# conflict copies are usually named like this
find <vault> -name "*conflict*" -o -name "*sync-conflict*" -o -name "* (1).md" | head -20
# was a note deleted on one device?
git -C <vault> log --diff-filter=D --name-only --since="30 days ago" 2>/dev/null | head -20
```
Report what happened; do not "repair" by merging conflict copies. A human decides which text is
the true one.

## Output format
```
GOAL:       which devices, how many simultaneous editors, offline needed?
MODEL:      file sync | vendor sync | CRDT | platform - and why
LOSES:      exactly what this model can lose, in plain words
BACKUP:     what backs up independently of sync
MIGRATION:  what moving between models would cost (file format, history, links)
RECOMMEND:  one choice, with the trade-off stated
NOT DONE:   no sync configuration, file or note was modified
```
