---
name: core-plan-then-build
description: Scope a non-trivial change before editing - read the real config and code, produce a short written plan with acceptance criteria and the exact commands to run, and get agreement. Use for multi-file changes, migrations, anything touching live services, or whenever the request is ambiguous or the blast radius is unclear.
metadata:
  category: core
---

# Plan, then build

Skip for a one-line fix. Use when cross-cutting, live-service-touching, or ambiguous.

## Procedure
1. **Read before writing** (read-only). 2. **State findings** with paths/lines; label inferences.
3. **Write the plan**: Goal / Acceptance criteria / Files / Commands (baseline + after) /
   Out of scope / Risks / Open questions. 4. Ask only about consequential ambiguity.
5. **Wait for agreement** before touching live services, databases, tags, or paths.
6. Implement in small checkable steps; hand off to `core-verify-loop`.

## Anti-pattern
A plan without acceptance criteria can't be verified; without "out of scope" it grows silently.
