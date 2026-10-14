# 02 — Plan (before any multi-file or state-touching change)

`/plan <request>` builds a plan; or paste below directly.

```
Produce a plan only. Do not edit any file this turn.
Read first: compose file, service configs, code, existing tests. Files with credentials:
do NOT read — note location, use environment variables.

Plan format:
  GOAL            one sentence, user-visible behaviour
  ACCEPTANCE      checkbox list, each independently observable
  FILES           path -> what changes and why
  COMMANDS        exact command (baseline) -> expected; (after) -> expected
  OUT OF SCOPE    what you will not touch
  RISKS           what could break; what you could not determine
  OPEN QUESTIONS  only plan-changing ones; include your recommended default

Then stop and wait for approval. Flag any library/vault/database/service-state writes
as APPROVAL-REQUIRED in RISKS.
```
