# 02 — Plan (before any multi-file or state-touching change)

In the TUI, `/plan <request>` builds a plan; or paste the block below directly.

```
Produce a plan only. Do not edit any file in this turn.

Read first, then plan: the compose file, the relevant service configs, the code, the existing tests.
If a file holds credentials, do NOT read it - note its location and use environment variables.

Plan format:
  GOAL            one sentence, user-visible behaviour
  ACCEPTANCE      checkbox list, each independently observable
  FILES           path -> what changes and why
  COMMANDS        exact command (baseline) -> expected; exact command (after) -> expected
  OUT OF SCOPE    what you will not touch
  RISKS           what could break; what you could not determine
  OPEN QUESTIONS  only those that change the plan; include your recommended default

Then stop and wait for my approval. If any step would write to a music library, a notes vault,
a database, or a running service's state, say so explicitly in RISKS and mark it APPROVAL-REQUIRED.
```
