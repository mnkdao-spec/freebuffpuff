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

See the one-liner in the repo version of this file. `tests/invariants.sh` runs the same check as part of the suite.

## What was verified, and what was not

**Verified (Phase 0, see `../docs/probe-results.md`):** Freebuff scans `.agents/**/*.ts` and lists
those files in its trust prompt. `.d.ts` files are excluded from that scan, which is why the shared type lives in
`agent-definition.d.ts`.

**Not verified:** that Freebuff loads these agents successfully and can spawn them. Treat Tier 3 as opt-in and check the TUI after you
copy them. If they do not load, nothing else in the pack depends on them.

## The `model` field - a deliberate deviation from the docs

The current Codebuff agent reference lists **`model` as required**. These five definitions
**omit it on purpose**, so they inherit whatever model your session is using.

If the TUI rejects or skips them, add the id your `/model` command shows as one line per file, after `displayName:`

```ts
  model: '<id from /model>',
```

and re-run the load check above. `probe/USER-CHECKLIST.md` has this as a step.
