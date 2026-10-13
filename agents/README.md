# Custom agents (opt-in, Tier 3)

Five TypeScript agent definitions, all **read-only by construction** (no write tools at all):

| Agent | Purpose | Write tools |
|---|---|---|
| `repo-cartographer` | map a stack before you change it: services, ports, mounts, config ownership | none |
| `verifier` | adversarial read-only review of a change, against its acceptance criteria | none |
| `library-auditor` | read-only health check of the music stack and library | none |
| `proxmox-auditor` | read-only audit of the Proxmox host and guests: inventory, mounts that are not backed up, privilege/device findings, repo hygiene, upgrade risk | none |
| `site-qa` | read-only QA of the website build and deployment: builds the artefact, audits metadata/structured data/links/weight, verifies the live page against the build | none |

`site-qa` and `proxmox-auditor` may run the project's own build/test commands and the pack's
read-only scripts (a build writes to its output directory; neither edits source or touches the
hypervisor).

## Install
```bash
mkdir -p .agents/types
cp agents/*.ts .agents/
cp agents/types/agent-definition.d.ts .agents/types/
```
Then address them in the TUI with `@` and their display name (e.g. `@Verifier`). Freebuff has no
`--agent` flag — that is Codebuff-only.

## Checking the definitions load

Node strips the TypeScript types on import, so this actually executes each definition and validates
the fields an agent needs. (`node --check` does **not** strip types and will reject `.ts` files -
it is the wrong tool here; so is relying on the `.d.ts`, which only helps an editor.)

```bash
for f in .agents/*.ts; do node --input-type=module -e "
const m = await import('./$f'); const d = m.default;
const bad = [];
if (!d.id) bad.push('id');
if (!Array.isArray(d.toolNames) || !d.toolNames.length) bad.push('toolNames');
for (const w of ['write_file','str_replace','apply_patch']) if ((d.toolNames||[]).includes(w)) bad.push('WRITE TOOL: '+w);
console.log((bad.length ? 'INVALID ' + bad.join(',') : 'OK') + '  $f');
"; done
```

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
