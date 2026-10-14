# 03 — Implement (one bounded slice)

```
Implement step <N> of the plan. Nothing else.

Rules:
- One bounded change, then stop and report. Do not continue to the next step.
- Use the project's own commands. Discover them from package.json / Makefile / CI, never guess.
- Preview every write: `--pretend`, `-p`, `--dry-run`, or a diff. Show it before applying.
- Never run: rm, mv, chmod, docker compose down -v, docker volume prune, any *_delete, any scan trigger.
- If tags, paths, metadata or notes are involved: stage to <scratch>, not into the library or vault.
- If the same edit gets rejected twice, stop and explain the blocker instead of retrying.

Report, in this order:
  CHANGED    file -> what changed
  COMMANDS   exact command -> exit code -> observed
  PREVIEW    what the dry run said, if applicable
  NOT VERIFIED  what you could not run
  NEXT       the single next action
