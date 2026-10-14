---
name: core-plan-then-build
description: Scope a non-trivial change before editing - read the real config and code, produce a short written plan with acceptance criteria and the exact commands to run, and get agreement. Use for multi-file changes, migrations, anything touching live services, or whenever the request is ambiguous or the blast radius is unclear.
metadata:
  category: core
---

# Plan, then build

Skip this for a one-line fix. Use it when the change is cross-cutting, touches a running
service, or the request could mean two different things.

## Procedure
1. **Read before writing.** Open the actual files: compose file, service configs, the code,
   the existing tests. Read-only.
2. **State what you found**, with file paths and line numbers. If a claim is an inference,
   label it as one.
3. **Write the plan** in this shape:

```markdown
## Goal
One sentence, user-visible behaviour.

## Acceptance criteria
- [ ] observable, testable statement
- [ ] observable, testable statement

## Files to change
- path - what changes and why

## Commands to run
- exact command (baseline) -> expected
- exact command (after)    -> expected

## Out of scope
- what you will deliberately not touch

## Risks / unknowns
- what could break; what you could not determine

## Open questions
- anything that changes the plan if answered differently
```

4. **Ask only about consequential ambiguity.** If the choice is minor and reversible, state
   the assumption and proceed.
5. **Wait for agreement** before editing anything that touches a live service, a database,
   tags, or file paths.
6. Then implement in small, independently checkable steps and hand off to `core-verify-loop`.

## Freebuff specifics
- `/plan` in the TUI creates a plan; free-tier sessions are metered per hour, so spend the
  first minutes reading rather than editing.
- Batch your questions: one message, all of them.
- If you're unsure whether a file is safe to touch, ask before touching it.

## Anti-pattern
A plan that lists intentions without acceptance criteria cannot be verified later, and a
plan with no "out of scope" section will quietly grow.
