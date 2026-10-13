---
name: core-upstream-contribution
description: Prepare a change that will be submitted to an open-source project - check the project's contribution rules and AI policy first, keep the diff minimal, run the project's own checks, add tests, sign off where required, and disclose AI assistance honestly. Use when asked to fix or contribute to Navidrome, Lidarr, Prowlarr, slskd, beets, Immich or any upstream repository, or before opening a pull request.
metadata:
  category: core
---

# Upstream contribution

You are working in someone else's repository now. Their rules, their review time.

## First: read the rules, then decide
1. Read `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, the PR template, and any AI/LLM policy.
2. **If the project has an LLM policy, follow it exactly.** Jellyfin's, for example, allows
   AI as a development aid but requires the contributor to understand, test and defend the
   change, and rejects unreviewed "vibe coded" submissions. Navidrome, Lidarr and Prowlarr
   had no published AI policy at the time of writing — that is not permission to skip
   review, and it does not mean no maintainer will object.
3. Check the gates before writing code:
   - **Lidarr/Servarr**: new backend code requires **80% test coverage**; discuss
     unrequested features with maintainers *before* implementing.
   - **Navidrome**: open or reference an issue, use a branch, conventional commits, and
     **DCO sign-off** (`git commit --signoff`). Support questions go to the forum, not issues.
   - **MusicBrainz**: proposed data changes go through community review and voting. Never
     submit model output as verified fact.
4. If the project has no policy, still disclose that AI assistance was used, in the PR body.

## Keep the diff reviewable
- One concern per change. No drive-by reformatting, no dependency bumps, no version churn.
- Match the existing style; do not introduce a new library for something the repo already does.
- Do not upgrade dependencies to make your change work.
- Add or extend tests for the behaviour you changed — in the project's existing framework and
  layout, not a new one.
- If you cannot make the diff small, explain in the PR why it cannot be small.

## Run *their* checks
Discover, don't guess:
```bash
ls Makefile justfile package.json pyproject.toml 2>/dev/null
# examples: Navidrome `make test`, `make lintall`, `make pre-push`
#           Lidarr   `dotnet test`, style/coverage gates
#           slskd    `dotnet test`; beets `pytest`
```
Report the exact commands and their real exit codes. Partial runs must be labelled as partial.

## PR body template
```
## What
one paragraph, user-visible behaviour

## Why
the issue this addresses - link it

## How
the approach, and the alternatives you rejected

## Verification
- command -> exit code
- manual check performed, and what it showed
- what is NOT covered by tests

## AI assistance
State plainly how AI was used (drafting, tests, review) and confirm you have read, tested
and can defend every line. Do not submit code you cannot explain.
```

## Never
- Open a PR that has not been run by the human at least once, locally, against real data.
- Include generated noise: mass renames, doc regeneration, lockfile churn.
- Argue with a maintainer using confident model output as evidence.
