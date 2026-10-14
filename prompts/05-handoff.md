# 05 — Handoff (end of session, or before context gets long)

Sessions end normally (per-session pricing, no headless mode). Make resume cheap.

```
Before we stop, update durable state:
1. .agents/ops/taskboard.md — item status + single next action.
2. .agents/ops/progress.md — append: date, change, proving command, exit code.
3. .agents/ops/decisions.md — choices made + rejected alternatives.

Then print: STATE (1-2 sentences) | DONE (with proving commands) | IN FLIGHT +
exact next action | NEXT (one cold-pickup action) | BLOCKED (as questions) |
FILES (touched, committed?) | NOT VERIFIED.
```
