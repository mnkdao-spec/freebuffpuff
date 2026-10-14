---
name: core-verify-loop
description: The evidence loop for any code, config or infrastructure change - establish a baseline, make one bounded change, run the project's real checks, and report what is still unverified. Use when implementing, fixing, or reviewing any change, when asked to "make sure it works", or before claiming a task is done.
metadata:
  category: core
---

# Verify loop

Never report success without evidence. Freebuff's models are fast and confident; the cheap
part is the edit, the expensive part is being wrong.

## Rules
1. **Baseline first.** Before changing anything, run the command that currently proves the
   thing works (or fails). If you cannot run it, say so and stop claiming verification.
2. **One change, then check.** Don't stack three edits and test once.
3. **The project's real command.** Prefer the repo's own script over an invented one.
   Discover it from `package.json`, `Makefile`, `pyproject.toml`, `docker-compose.yml`,
   CI config — do not guess.
4. **Report the exit code and the actual output**, trimmed. Not a summary of a summary.
5. **Never weaken a check to pass.** No skipped tests, no loosened assertions, no
   `--no-verify`, no adding type suppressions. If a check is genuinely wrong, fix the check
   and say why.

## Procedure
1. Identify the claim being verified ("imports stop dropping albums", "compose validates").
2. Capture the baseline: exact command, exit code, key output lines.
3. Make the smallest change that could satisfy the claim.
4. Re-run the focused check, then the next-wider check that exists:
   `docker compose config -q` -> unit tests -> integration -> live probe.
5. For anything user-visible, exercise it for real, not just at unit level.
6. Report.

## Output format
```
CLAIM:        what was supposed to become true
BASELINE:     command -> exit code -> observed
CHANGE:       files touched, one line each
VERIFIED:     command -> exit code -> observed
NOT VERIFIED: what you could not run and why
RISK:         what could still break, and the signal to watch
```

## Red flags in your own work
- "This should work" / "the tests pass" without output.
- A passing test you never saw fail.
- Editing the test to match the implementation.
- A fix that only works because you disabled something else.

## Anti-pattern
Do not end a turn with "done" when the only evidence is that files were written. Files
written is not behaviour verified.
