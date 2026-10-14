---
name: core-upstream-contribution
description: Prepare a change for an open-source project - check contribution rules and AI policy first, keep the diff minimal, run the project's own checks, add tests, sign off where required, and disclose AI assistance honestly. Use when contributing to Navidrome, Lidarr, Prowlarr, slskd, beets, Immich or any upstream repo, or before opening a pull request.
metadata:
  category: core
---

# Upstream contribution

Their repo, their rules, their review time.

1. Read `CONTRIBUTING.md`, PR template, AI/LLM policy. Follow LLM policies exactly.
2. Gates: **Servarr new backend code needs 80% coverage**; **Navidrome needs DCO sign-off**
   + issue reference + conventional commits; MusicBrainz data changes need community votes.
3. No policy? Still disclose AI assistance in the PR body.
4. One concern per change. Match style. No drive-by reformatting/dependency bumps.
5. Add tests in their framework/layout. Run *their* checks; report exact cmds + exit codes.
6. Never open an untested-locally PR; no generated noise; don't argue with maintainers via model output.

## PR body: What / Why (linked issue) / How (+rejected alternatives) / Verification
(cmds + exits, manual checks, uncovered parts) / AI assistance (how used, confirm you can
defend every line).
