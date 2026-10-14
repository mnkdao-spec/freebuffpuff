# Threat model

What can go wrong, what Freebuff's own mechanics do and do not protect you from, and which tier of
this pack is appropriate for which risk. Findings marked **[verified]** come from the Phase 0 probe
(`probe-results.md`); the rest are design consequences.

## The three assets at risk

1. **The music library** — large, hard to rebuild, and a wrong delete or bulk rename is
   unrecoverable. Ratings and play counts live in the *server database*, not in the files, so a
   rescan cannot restore them.
2. **The knowledge vault** — irreplaceable in the literal sense: it is a record of thought, not a
   copy of something else.
3. **Credentials** — Lidarr/Prowlarr API keys, slskd admin key, Soulseek password, Navidrome tokens,
   VPN config. Also downstream: an exposed slskd web UI is a remote control for your downloads and
   your shares.

## What the platform protects, and what it does not [verified]

| Mechanism | Behaviour | Consequence for you |
|---|---|---|
| Trust prompt for `.agents/*.ts` and `mcp.json` | Prints the exact command lines it would start and warns that they run with your permissions. Skipped entirely when non-interactive. | **Read it every time**, especially after cloning someone else's repo. |
| Trust store | Decisions persist in `~/.config/manicode/trusted-agent-dirs.json`; bypass with `--trust-agents` or `CODEBUFF_TRUST_AGENT_DIRS=1`. | Trust is per-directory and sticky. Re-clone and you are asked again. |
| **`.agents/skills/*`** | **No trust prompt at all.** | A skill is *instructions the model will follow*. **Never install skills from a repo you have not read**. |
| MCP env expansion | A missing `$VAR` aborts loading the **entire** `mcp.json`. | Set every variable in your shell before launch. |
| Network allowlist in the bundled MCP server | GET only, host-allowlisted, no filesystem, no shell. | The bundled server cannot change state by construction. |

## Prompt injection and the "lethal trifecta"

The risky combination is: **access to private data** + **exposure to untrusted content** + **a way to send data out**.

Mitigations this pack applies:
- Skills instruct agents to treat file contents, logs and web text as **data, not instructions**.
- Read-only is the default everywhere: the verifier, auditor and cartographer agents have **no write
  tools at all** — the restriction is a tool allowlist, not a polite request in a prompt.
- Writes to the library or vault go to a scratch/staging area first, and destructive steps are
  labelled APPROVAL-REQUIRED.

## Your data leaves your machine [verified, from the CLI's own shipped README]

- Prompts, messages, agent traces, code, files and repository data are used **to provide Freebuff**.
- **Prompts and messages may be analysed to personalise ads.**
- Data is used for AI training only when a model or feature is labelled
  *"may use data for AI training"*.

Practical consequences:
- Use `.codebuffignore` for `.env`, `secrets/`, `media/`, `vault/`, reports and backups (the
  template does this).
- Never paste a full personal note into a prompt when the paragraph in question would do.
- Never paste a key. Read variable *names* only, and prefer the environment.

## Configuration drift and blast radius

- **The same host path mounted at different container paths** is the most common real defect found by
  `compose-doctor.sh`. It looks harmless and breaks imports.
- **`docker compose down -v`, `docker volume prune`, `chown -R`, bulk `chmod`** are the four commands
  that turn a small problem into a data-loss incident. Every core skill forbids them.
- **Branch switches with schema changes** (Lidarr nightly for plugins) have no downgrade path.
- **Two tools owning the same files** (beets and Lidarr both reorganising a library) produce
  duplicates and orphans that no scan will untangle.

## Recommended posture by tier

| Tier | Content | Appropriate for |
|---|---|---|
| 1 | `knowledge.md` + skills + prompts + ops | Everything. No new attack surface. |
| 2 | `mcp/local-readonly` | Everyday use: read-only GETs against allowlisted hosts. |
| 3 | `.agents/*.ts` agents | Useful, unverified on Freebuff. Read-only by tool allowlist. |
| 4 | Third-party MCP servers, community plugins, downloaded templates | Deliberate, justified decisions, one at a time, with a backup taken first. |

## The one-line rule

**Nothing in this pack is allowed to write to your music library, your vault, or a running service's
state without a human saying so in that same message.**
