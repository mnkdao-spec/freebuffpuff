---
name: core-handoff
description: Keep durable state across turns and sessions - write and update a taskboard, a progress log and a decisions log so work can resume after a context reset, a session limit or a new terminal. Use at the start of a work session, when resuming unfinished work, when context is getting long, or when a Freebuff session is about to end.
metadata:
  category: core
---

# Handoff and resume

Context is a budget and sessions are capped (Freebucks are spent per one-hour session).
Files survive; conversations do not.

## Files (created by the pack installer)
- `.agents/ops/taskboard.md` - what is in flight, one line per item, with status
- `.agents/ops/progress.md` - append-only log: date, what changed, what was verified
- `.agents/ops/decisions.md` - append-only: decision, why, what it rules out

Write these at these moments:
| Moment | Write |
|---|---|
| Start of session | read taskboard; put the current item in flight |
| Before a risky edit | one line in progress.md: what you're about to try |
| After verification | progress.md: the command and its exit code |
| When you choose an approach over an alternative | decisions.md |
| Before context gets long / session ending | taskboard + a "next step" line |

## Resume procedure
1. Read `.agents/ops/taskboard.md` and the last ~30 lines of `progress.md`.
2. Re-run the check that the last verified entry claims passed. Do not trust the note;
   trust the command. (This catches work that was reverted or never committed.)
3. Continue from the recorded next step, or say why the plan should change.

## Handoff summary format
```
STATE:     where things stand in one or two sentences
DONE:      verified items, with the command that proved them
IN FLEGHT: the current item and its exact next action
NEXT:      the single next action someone else can pick up cold
BLOCKED:   what needs a human decision, and the question to answer
FILES:     paths touched, and whether they are committed
```

## Notes specific to this setup
- `progress.md` entries must include the exit code. "Ran the tests" is not an entry.
- Never record secrets, API keys or vault contents in these files.
- If you finish everything, say so explicitly - do not leave the board ambiguous.
