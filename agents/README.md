# Custom agents (opt-in, Tier 3)

Three TypeScript agent definitions, all **read-only by construction** (no write tools at all):

| Agent | Purpose | Write tools |
|---|---|---|
| `repo-cartographer` | map a stack before you change it: services, ports, mounts, config ownership | none |
| `verifier` | adversarial read-only review of a change, against its acceptance criteria | none |
| `library-auditor` | read-only health check of the music stack and library | none |

## Install
```bash
mkdir -p .agents/types
cp agents/*.ts .agents/
cp agents/types/agent-definition.d.ts .agents/types/
```
Then address them in the TUI with `@` and their display name (e.g. `@Verifier`). Freebuff has no
`--agent` flag — that is Codebuff-only.

## What was verified, and what was not

**Verified (Phase 0, see `../docs/probe-results.md`):** Freebuff scans `.agents/**/*.ts` and lists
those files in its trust prompt — for example:
```
freebuff found agent files in this repository it has not run before:
  /path/to/repo/.agents
    agents: repo-cartographer.ts
    mcp.json: would start
      localReadonly: node /path/.../server.js
```
`.d.ts` files are excluded from that scan, which is why the shared type lives in
`agent-definition.d.ts` and not `agent-definition.ts` — a plain `.ts` type file shows up as a
spurious "agent" and forces the trust prompt for no reason.

**Not verified:** that Freebuff loads these agents successfully and can spawn them. This is
documented for Codebuff, not confirmed for Freebuff CLI/Desktop. The sandbox probe could not get
past the trust prompt into a signed-in session. Treat Tier 3 as opt-in and check the TUI after you
copy them (`@` should autocomplete the display names). If they do not load, nothing else in the
pack depends on them — delete `.agents/*.ts` and you lose only this tier.

## Type-checking
The documented check is `bun run typecheck` inside `.agents/`. The bundled
`types/agent-definition.d.ts` is a minimal local shape so the files are self-contained; the
platform may export a richer type.

## Design notes
- **No `model` field.** Agents inherit the session's selected model. Hard-coding a model id risks
  pinning one that does not exist in your Freebuff catalog (the catalog changes).
- **`includeMessageHistory: false`** so the verifier judges the artefacts, not the author's
  reasoning.
- **`toolNames` is an allowlist.** That is the mechanism that makes these agents read-only: the
  verifier cannot call a write tool because it was never given one, not because its prompt asks
  nicely.
