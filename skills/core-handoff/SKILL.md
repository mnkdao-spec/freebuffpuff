---
name: core-handoff
description: Keep durable state across turns and sessions - write and update a taskboard, a progress log and a decisions log so work can resume after a context reset, a session limit or a new terminal. Use at the start of a work session, when resuming unfinished work, when context is getting long, or when a Freebuff session is about to end.
metadata:
  category: core
---

# Handoff and resume

Context is a budget; sessions are capped. Files survive; conversations do not.

## Files
- `.agents/ops/taskboard.md` - in flight, one line per item
- `.agents/ops/progress.md` - append-only: date, change, verification
- `.agents/ops/decisions.md` - append-only: decision, why, ruled-out alternative

Write at: session start (read board, mark in-flight); before risky edits; after verification
(cmd + exit code); on approach choices; before context gets long / session ends.

## Resume
1. Read taskboard + last ~30 lines of progress. 2. Re-run the last claimed-passing check
   (don't trust the note; trust the command). 3. Continue from recorded next step.

## Handoff format
```
STATE / DONE (with proving commands) / IN FLIGHT + next action / NEXT / BLOCKED / FILES
```

- `progress.md` entries must include exit codes. Never record secrets in these files.
