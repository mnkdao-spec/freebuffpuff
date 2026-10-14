# 05 — Handoff (end of a session, or before context gets long)

Freebuff spends Freebucks per hour-long session and has no headless mode, so a session ending is
normal, not a failure. Make it cheap to resume.

```
Before we stop, update durable state:

1. .agents/ops/taskboard.md - mark this item's status, and write the single next action.
2. .agents/ops/progress.md - append: date, what changed, the exact command that proved it, exit code.
3. .agents/ops/decisions.md - record any choice you made and the alternative you rejected.

Then print:
  STATE      where things stand, one or two sentences
  DONE       verified items, each with the command that proved it
  IN FLIGHT  the current item and its exact next action
  NEXT       one action someone else can pick up cold
  BLOCKED    what needs my decision, phrased as a question
  FILES      paths touched, and whether they are committed
  NOT VERIFIED  anything you did not run
```
