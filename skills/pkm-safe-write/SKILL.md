---
name: pkm-safe-write
description: Write to a personal knowledge base safely - stage new notes as drafts in the inbox, show the exact content and path before writing, never rewrite or delete existing notes, and keep a review queue so nothing enters the permanent graph unreviewed. Use whenever an agent must create, edit or append to notes, capture content into a vault, or update a daily note.
metadata:
  category: pkm
  stack: obsidian, markdown, git
---

# Safe vault writes

The vault is the one place where an agent's mistake is unrecoverable by re-running a command.
Default to *proposing* content, not writing it.

## The write ladder — use the lowest rung that works
1. **Propose only.** Print the note in the reply. Zero risk. Use this for anything consequential.
2. **Stage in the inbox.** Write a *new* file into `<vault>/_inbox/` (or the vault's existing
   inbox) with `status: draft` frontmatter. Never overwrite; if the name exists, add a suffix.
3. **Append to a scratch/task file** the pack already owns (`.agents/ops/*`).
4. **Edit an existing note** — only with an explicit instruction naming that note, and only as a
   minimal, reversible edit. Show a diff first.

## Hard rules
- **Never delete, rename or move a note.** Not empty ones, not duplicates, not "cleaned up" ones.
- **Never rewrite an entire note** when an append or a targeted section edit will do.
- **Never edit frontmatter of an existing note** without showing before/after values.
- **Preserve link integrity.** Adding a note is safe; renaming one breaks every `[[link]]`.
- **Never touch `.obsidian/`** (settings, plugins, workspace) — that is app config, not notes.
- **Never execute vault code.** DataviewJS and Templater templates can run JavaScript, and
  Templater can run system commands. Read such notes; do not run them.
- **No secrets or personal data into the prompt.** Vault content you choose to send is sent —
  and Freebuff prompts may be analysed to personalise ads, with some models retaining
  submissions. Check your own comfort level before pasting a journal entry.

## Procedure for a capture
1. Confirm the inbox path from `pkm-vault-conventions`.
2. Compose the note: frontmatter (matching existing keys), a title, a body that distinguishes
   **what the source said** from **your interpretation**.
3. Print the file path and the full content.
4. Write it only if the task explicitly asked you to write (in-bulk tasks should say so).
5. Add the note to the review queue (`ops/taskboard.md` or a `status: draft` list) rather than
   linking it into the permanent graph.

## Duplicate and conflict handling
Check before creating: `grep -ril "<title words>" <vault> | head`. If a similar note exists,
**do not merge or overwrite** — report the candidate and ask. Merging two notes is a judgement
call about meaning, and it is not yours to make.

## Output format
```
MODE:       proposed | staged-in-inbox | appended | edited-existing
PATH:       exact target path
CONTENT:    the full note, verbatim
DIFF:       for edits only, before -> after
DUPLICATES: similar existing notes found, if any
REVIEW:     how this gets into the permanent graph (a human moves/relinks it)
NOT DONE:   confirm you did not delete, rename, move or bulk-edit anything
```

## Reverting
State the undo for every write: "delete this file", "restore from git `git checkout -- <path>`",
or "revert the appended section". If you cannot state a clean undo, prefer rung 1.
