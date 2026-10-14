# Custom agents (opt-in, Tier 3)

Five TypeScript agent definitions. Their `toolNames` allowlist is the mechanism that keeps them
read-only - **not** the prompt asking nicely:

| Agent | Purpose | Write tools in the allowlist |
|---|---|---|
| `repo-cartographer` | map a stack before you change it: services, ports, mounts, config ownership | none |
| `verifier` | adversarial read-only review of a change, against its acceptance criteria | none |
| `library-auditor` | read-only health check of the music stack and library | none |
| `proxmox-auditor` | read-only audit of the Proxmox host and guests: inventory, mounts that are not backed up, privilege/device findings, repo hygiene, upgrade risk | none |
| `site-qa` | read-only QA of the website build and deployment: builds the artefact, audits metadata/structured data/links/weight, verifies the live page against the build | none |

Every agent's allowlist is exactly
`['read_files', 'code_search', 'find_files', 'run_terminal_command', 'think_deeply', 'end_turn']`.
The file-writing tools - `write_file`, `str_replace`, `run_file_change_hooks` - are **absent from
every allowlist**, which is a property you can check mechanically (see below) rather than trust.

**The honest caveat:** `run_terminal_command` is granted, because the whole point is to run the
pack's read-only audit scripts (`pve-doctor.sh`, `lib-audit.sh`, `site-audit.sh`). A shell can
write, so for that one tool the constraint is the system prompt ("never run a mutating command",
with the forbidden commands listed by name), not the allowlist. `site-qa` builds the site, which
writes to its own output directory. If you want zero write capability at all, delete
`run_terminal_command` from the `toolNames` arrays - the audits then run in your session instead,
and the agents become purely advisory.

## Install
`install.sh` copies these for you — `./install.sh --project .` writes `.agents/*.ts` and
`.agents/types/agent-definition.d.ts`, and `--verify` loads every one under Node so a syntax error
fails the install. By hand it is the same three commands:

```bash
mkdir -p .agents/types
cp agents/*.ts .agents/
cp agents/types/agent-definition.d.ts .agents/types/
```
Then answer the **trust prompt** (`.agents/*.ts` is trust-gated; skills are not) and address them in
the TUI with `@` and their display name (e.g. `@Verifier`). Freebuff has no `--agent` flag — that is
Codebuff-only.

## Checking the definitions load

Node strips the TypeScript types on import, so this actually executes each definition, checks the
fields an agent needs, and validates every `toolName` against the **documented** tool vocabulary -
an allowlist is only meaningful if the names in it exist. (`node --check` does **not** strip types
and will reject `.ts` files - it is the wrong tool here; so is relying on the `.d.ts`, which only
helps an editor.) `tests/invariants.sh` runs this same check as part of the suite.

```bash
DOCUMENTED="add_subgoal browser_logs code_search create_plan end_turn find_files read_docs read_files run_file_change_hooks run_terminal_command spawn_agents str_replace think_deeply update_subgoal web_search write_file set_output"
for f in .agents/*.ts; do node -e '
const {pathToFileURL} = require("node:url");
import(pathToFileURL(process.argv[1]).href).then((m) => {
  const d = m.default, bad = [];
  if (!d.id) bad.push("id");
  if (!d.displayName) bad.push("displayName");
  if (!Array.isArray(d.toolNames) || !d.toolNames.length) bad.push("toolNames");
  const ok = new Set(process.argv[2].split(" "));
  for (const t of (d.toolNames || [])) if (!ok.has(t)) bad.push("UNDOCUMENTED TOOL: " + t);
  for (const w of ["write_file", "str_replace", "run_file_change_hooks"])
    if ((d.toolNames || []).includes(w)) bad.push("WRITE TOOL: " + w);
  console.log((bad.length ? "INVALID " + bad.join(", ") : "OK") + "  " + process.argv[1]);
}, (e) => { console.log("FAIL " + process.argv[1] + " :: " + e.message); process.exitCode = 1; });' "$PWD/$f" "$DOCUMENTED"; done
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

## The `model` field - a deliberate deviation from the docs

The current Codebuff agent reference lists **`model` as required**. These five definitions
**omit it on purpose**, so they inherit whatever model your session is using. Hard-coding an id
risks pinning one that does not exist in your catalog, and a catalog we cannot see from here.

That is a real deviation, so treat it as the first thing to check: if the TUI rejects or skips them,
add the id your `/model` command shows as one line per file, after `displayName:`

```ts
  model: '<id from /model>',
```

and re-run the load check above. `probe/USER-CHECKLIST.md` has this as a step.

## Design notes
- **No `model` field.** See the section above - documented as required, omitted deliberately so the
  agents inherit your session's model, with the one-line fix if your catalog needs it.
- **`includeMessageHistory: false`** so the verifier judges the artefacts, not the author's
  reasoning.
- **`toolNames` is an allowlist.** That is the mechanism that makes these agents read-only: the
  verifier cannot call a write tool because it was never given one, not because its prompt asks
  nicely.
