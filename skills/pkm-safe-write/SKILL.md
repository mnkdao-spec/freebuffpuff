---
name: pkm-safe-write
description: Write to a personal knowledge base safely - stage new notes as drafts in the inbox, show exact content and path before writing, never rewrite or delete existing notes, keep a review queue. Use whenever an agent must create, edit or append to notes, capture into a vault, or update a daily note.
metadata:
  category: pkm
  stack: obsidian, markdown, git
---

# Safe vault writes

Vault mistakes are unrecoverable by re-running. Default to *proposing*, not writing.

## Write ladder (lowest rung that works)
1. **Propose only** (print in reply; zero risk). 2. **Stage in inbox** as new `status: draft`
   file (never overwrite; suffix on collision). 3. **Append to pack-owned scratch** (`.agents/ops/*`).
4. **Edit existing note** — only explicitly named, minimal, reversible, diff shown first.

## Hard rules
- **Never delete, rename, move, or bulk-edit notes.** Never rewrite whole notes (append/targeted edit).
- Never edit existing frontmatter without before/after. Preserve link integrity.
- **Never touch `.obsidian/`.** Never execute vault code (DataviewJS/Templater can run JS/system cmds).
- No secrets/personal data into prompts (prompts may feed ads; some models retain).

## Capture procedure
Confirm inbox → compose (matching keys; source vs interpretation separated) → print path + full
content → write only if explicitly asked → queue for review (never link into permanent graph).

## Duplicates
`grep` before creating; similar note exists → report candidate, ask. Merging is a meaning
judgement — not the agent's call.

## Output
```
MODE / PATH / CONTENT (verbatim) / DIFF / DUPLICATES / REVIEW / NOT DONE
```

Reverting: state the undo per write ("delete file" / `git checkout` / "revert section").
No clean undo → prefer rung 1.
