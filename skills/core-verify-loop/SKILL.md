---
name: core-verify-loop
description: The evidence loop for any code, config or infrastructure change - establish a baseline, make one bounded change, run the project's real checks, and report what is still unverified. Use when implementing, fixing, or reviewing any change, when asked to "make sure it works", or before claiming a task is done.
metadata:
  category: core
---

# Verify loop

Never report success without evidence.

## Rules
1. **Baseline first.** Run the proving command before changing anything.
2. **One change, then check.** Don't stack edits and test once.
3. **The project's real command.** Discover from `package.json`/`Makefile`/CI — do not guess.
4. **Report exit code + actual output**, trimmed.
5. **Never weaken a check to pass.** No skipped tests, loosened assertions, `--no-verify`, or new suppressions.

## Procedure
1. Name the claim. 2. Capture baseline (cmd -> exit -> observed). 3. Smallest change.
4. Re-run focused check, then the next-wider one. 5. Exercise user-visible things for real. 6. Report.

## Output format
```
CLAIM / BASELINE / CHANGE / VERIFIED / NOT VERIFIED / RISK
```

## Red flags
"Should work" without output; a passing test never seen failing; editing the test to match;
a fix that works only because something else was disabled.
