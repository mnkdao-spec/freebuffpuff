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
| Trust prompt for `.agents/*.ts` and `mcp.json` | Prints the exact command lines it would start and warns that they run with your permissions. Skipped entirely when non-interactive. | **Read it every time**, especially after cloning someone else's repo. In a non-interactive run these are skipped, not silently executed. |
| Trust store | Decisions persist in `~/.config/manicode/trusted-agent-dirs.json`; bypass with `--trust-agents` or `CODEBUFF_TRUST_AGENT_DIRS=1`. | Trust is per-directory and sticky. Re-clone and you are asked again. The env bypass is exactly as dangerous as it looks. |
| **`.agents/skills/*`** | **No trust prompt at all.** | A skill is *instructions the model will follow*. It is not executable code, but it can direct tool use and data flow. **Never install skills from a repo you have not read** — this is the pack's single biggest supply-chain gap, and it is the platform's design, not a bug in this pack. |
| MCP env expansion | A missing `$VAR` aborts loading the **entire** `mcp.json`. | A partial config does not half-work; it silently does nothing. Set every variable, in your shell, before launch. |
| Network allowlist in the bundled MCP server | GET only, host-allowlisted, no filesystem, no shell. | The bundled server cannot change state by construction. Third-party servers have no such guarantee. |

## Prompt injection and the "lethal trifecta"

The risky combination is: **access to private data** (your vault, your library, your logs) +
**exposure to untrusted content** (a Soulseek peer's filenames, a scraped page, a GitHub issue, a
track's embedded metadata, a log line) + **a way to send data out** (any network tool).

You have all three. Concrete scenarios worth taking seriously:

- A **filename or tag from a peer's share** contains text that reads like an instruction. An agent
  that treats file names as content may act on it.
- A **log line** quoting a hostile request, or a **scraped page**, contains instructions.
- A **notes-capture task** ingests a web page that tells the agent to write something into your
  vault, or to exfiltrate other notes.

Mitigations this pack applies:
- Skills instruct agents to treat file contents, logs and web text as **data, not instructions**.
- Read-only is the default everywhere: the verifier, auditor and cartographer agents have **no write
  tools at all** — the restriction is a tool allowlist, not a polite request in a prompt.
- Writes to the library or vault go to a scratch/staging area first, and destructive steps are
  labelled APPROVAL-REQUIRED.

## Your data leaves your machine [verified, from the CLI's own shipped README]

- Prompts, messages, agent traces, code, files and repository data are used **to provide Freebuff**.
- **Prompts and messages may be analysed to personalise ads.** Separately uploaded files and
  connected repositories are *not* handed to advertising providers.
- Data is used for AI training only when a model or feature is labelled
  *"may use data for AI training"*. At the time of writing the catalog includes a stealth model that
  **retains prompts**, and models may serve from a quantized build.

Practical consequences:
- Use `.codebuffignore` for `.env`, `secrets/`, `media/`, `vault/`, reports and backups (the
  template does this). Remember that this *reduces* exposure; it is not an air gap.
- Never paste a full personal note into a prompt when the paragraph in question would do.
- Never paste a key. Read variable *names* with `grep -o '^[A-Z_]*='`; use the environment.
- "**The vault is fine for the free tier**" is a decision about your own material. Re-read it if the
  vault ever holds patient, legal, financial or third-party confidential content — at that point the
  right answer is a local model (Freebuff Desktop can drive a locally installed Claude Code/Codex, and
  `/byok` points at your own provider).

## Configuration drift and blast radius

- **The same host path mounted at different container paths** is the most common real defect found by
  `compose-doctor.sh`. It looks harmless and breaks imports.
- **`docker compose down -v`, `docker volume prune`, `chown -R`, bulk `chmod`** are the four commands
  that turn a small problem into a data-loss incident. Every core skill forbids them.
- **Branch switches with schema changes** (Lidarr nightly for plugins) have no downgrade path.
- **Two tools owning the same files** (beets and Lidarr both reorganising a library) produce
  duplicates and orphans that no scan will untangle.

## Third-party supply chain

Plugins, community templates, community MCP servers, and **skills** are all code or instructions
written by someone else:
- Navidrome `.ndp` plugins run sandboxed *but with the permissions an admin granted*. Read the
  manifest and the source before enabling.
- DataviewJS and Templater templates in a vault can execute JavaScript; Templater can run system
  commands. Treat a downloaded template as a program.
- MCP servers hold credentials and can trigger downloads. Prefer read-only tools, least-privilege
  keys, and never expose the endpoint beyond localhost.

## Recommended posture by tier

| Tier | Content | Appropriate for |
|---|---|---|
| 1 | `knowledge.md` + skills + prompts + ops | Everything. No new attack surface; skills are the only ungated input, so read them once. |
| 2 | `mcp/local-readonly` | Everyday use: read-only GETs against allowlisted hosts. |
| 3 | `.agents/*.ts` agents | Useful, unverified on Freebuff. Read-only by tool allowlist. |
| 4 | Third-party MCP servers, community plugins, downloaded templates | Deliberate, justified decisions, one at a time, with a backup taken first. |

## The one-line rule

**Nothing in this pack is allowed to write to your music library, your vault, or a running service's
state without a human saying so in that same message.** If a skill or agent ever asks you to relax
that, that is the finding — stop and read it.
