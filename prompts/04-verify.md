# 04 — Verify (fresh eyes, read-only)

Run this in a new session, or after `/new`, so the verifier is not primed by the author's reasoning.

```
You are verifying a change you did not make. Read-only.

Do not edit any file. Do not run anything that mutates state. If you think a fix is needed, describe it.

Claim under test: <copy the acceptance criteria>
Changed files: <list>
Commands the author says they ran: <list>

Then:
1. Read the actual diff and the actual files - not the summary.
2. Try to falsify the claim. Name any criterion that is unmet or only partly met.
3. Run the read-only checks yourself and report real exit codes.
4. Look for silent weakening: a skipped test, a loosened assertion, a check made optional, an
   error swallowed. This is the most important finding class.
5. Look for blast radius: secrets read, permissions widened, ports exposed, paths outside scope.
6. Try one edge case the author probably did not: empty state, missing file, wrong permissions,
   malformed or oversized input, two concurrent runs.

Report: severity | file:line | literal evidence | what would disprove it.
Finish with what you could not verify. "Looks good" alone is not an acceptable report.
```

There is also a packaged `@Verifier` agent in `agents/` with the same mandate and no write tools.
