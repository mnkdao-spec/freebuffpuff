# Freebuff Homelab Pack

An agent package for **Freebuff CLI and Desktop**, aimed at a self-hosted **music stack** (Navidrome,
Lidarr, Prowlarr, slskd/Soularr, beets) and a **personal knowledge base** (Obsidian/plain Markdown).

**25 skills · 5 verified diagnostic scripts · 1 read-only MCP server · 3 read-only agents · 5 workflow
prompts · 4 ops files.** Everything read-only by default.

```
./install.sh --project .            # into ./.agents/skills + knowledge.md + .codebuffignore
./install.sh --global               # into ~/.agents/skills + ~/.knowledge.md
./install.sh --both                 # both
./install.sh --verify               # validate all 25 skills, change nothing
./install.sh --project . --mcp local-readonly    # adds ./.agents/mcp.json (opt-in, GET-only)
```

## Windows 11

Read [`docs/windows.md`](docs/windows.md). The short version:

- Needs **Git for Windows** (for `bash`/`awk`/`sed`), **Node 18+**, **Python 3.9+**. Run the installer
  from **Git Bash**, not PowerShell or cmd. The scripts fall back to `python` when `python3` is missing.
- **Do not cross the WSL/Windows boundary.** Freebuff on Windows cannot execute a `server.js` living
  on a `\\wsl$\` path. Keep the pack and the repo on the same side, per install.
- **Hardlinks are the real risk.** Media on `C:\` bind-mounted into Docker Desktop crosses the
  Windows to WSL2 boundary, where same-filesystem hardlink semantics are not guaranteed. Keep the
  library on a Linux-side filesystem and verify with `stat -c '%d %i'` inside the containers.
- Line endings are forced to LF by `.gitattributes`; the installer **refuses to install** CRLF scripts
  rather than failing later with `\r: command not found` (a ZIP download is the usual cause).
- Without Developer Mode, `AGENTS.md` is created as a copy instead of a symlink, and the installer says so.

## Built against the real CLI, not the docs

The extension surface was probed against the shipped Freebuff binary (v0.2.27) before anything was
written. Full results in [`docs/probe-results.md`](docs/probe-results.md). The findings that shaped
this pack:

| Finding | Consequence |
|---|---|
| Freebuff's flag set is a strict subset of Codebuff's: `--continue`, `--cwd`, `--trust-agents`, `login`. **No `--plan`, `--max`, `--lite`, `--agent`, and no headless/`-p` mode.** | The pack is designed for interactive use. No CI automation is pretended. `/plan`, `/interview`, `/review` are the real entry points. |
| **Skills are not trust-gated. `mcp.json` and `.agents/*.ts` are.** The prompt prints the exact commands it would run. | MCP and custom agents stay **opt-in**; the pack's own docs tell you to read the prompt. Never install skills from a repo you haven't read. |
| Skill `name` **must equal its directory name**; `description` is truncated at 1024 chars and is the only signal for auto-loading. | `install.sh --verify` enforces this on all 25 skills before installing anything. Descriptions are written as triggers. |
| A missing `$VAR` in `mcp.json` **drops the whole file**, not one server. | Documented loudly in `mcp/README.md` and printed by the installer. |
| `~/.agents/mcp.json` **overrides** the project's. | Stated in `docs/probe-results.md` — surprising, and a real source of confusion. |
| `.agents/**/*.ts` are listed as agent files; **`.d.ts` is excluded**. | The shared type file is `agent-definition.d.ts`, so it does not trigger a pointless trust prompt. |
| `/mode:*` does not exist in Freebuff (Codebuff only). | Nothing in the pack asks you to type it. |

## What's inside

```
knowledge.md          lean, always-loaded: stack map, exact commands, hard rules  (you fill in <EDIT>s)
.agents/skills/       25 skills, flattened from:
  skills/core/        8   verify-loop, plan-then-build, handoff, secrets-hygiene, compose-change,
                          backup-restore-check, log-window-triage, upstream-contribution
  skills/music/      11   stack-map, lidarr-match-doctor, path-and-hardlink-doctor, slskd-ops,
                          navidrome-tagging-doctor, navidrome-nsp-author, navidrome-plugin-dev,
                          musicbrainz-lookup, beets-preview, library-audit, lyrics-and-art
  skills/pkm/         6   vault-conventions, safe-write, capture-to-note, obsidian-plugin-dev,
                          rag-design, sync-choice
scripts (5)           compose-doctor · slskd-doctor · nsp-lint · lib-audit · mb-lookup
                      -> all read-only, all executed and verified in this session
mcp/                  local-readonly server (10 GET-only tools) + risk-ranked third-party shortlist
agents/               3 read-only TS agents: Repo Cartographer, Verifier, Library Auditor
prompts/              01-interview · 02-plan · 03-implement · 04-verify · 05-handoff
ops/                  taskboard · progress · decisions · runbooks/{music,pkm}
docs/                 probe-results · threat-model · token-budget · trends · music-notes
probe/                the Phase 0 probe kit + USER-CHECKLIST.md (10 minutes, on your machine)
```

## The five scripts (verified, read-only)

| Script | What it does | Proof it works |
|---|---|---|
| `compose-doctor.sh` | flags the same host path mounted at different container paths, named-volume vs bind, UID/GID/umask incoherence, `SLSKD_UMASK` misuse, VPN sidecar networking, `depends_on` without health | caught a real slskd `/downloads` vs Lidarr `/data/downloads` mismatch and a PUID mismatch in a fixture |
| `lib-audit.sh` | tag completeness, codec/bitrate anomalies, extension-vs-codec mismatch, FLAC integrity, duplicate candidates (optionally content-hashed) | detected a corrupt FLAC, a `.mp3` that reports as FLAC, a 64 kbps file, missing tags, and a byte-identical duplicate |
| `nsp-lint.sh` | validates Navidrome `.nsp` smart-playlist JSON structure and vocabulary | rejects a bad rule tree and a 250% `limitPercent`; accepts a valid multi-group playlist |
| `mb-lookup.sh` | MusicBrainz lookups with **enforced 1 req/s** (serialised across processes), caching, 503 backoff, real User-Agent, plus `classify` for the release-vs-release-group trap | live lookups; request starts measured ≥1.1 s apart; cache hit is instant |
| `slskd-doctor.sh` | read-only GETs for session/server/shares/transfer state, with an interpretation guide | reports per-endpoint HTTP status; treats 404 as "not in this version" |

## Safety stance

- **Nothing here writes to your music library, your vault, or a running service's state without you
  saying so in that message.** Destructive steps are labelled APPROVAL-REQUIRED, not silently skipped.
- The MCP server and all three agents are **read-only by construction** — GET-only/host-allowlisted, and
  a tool allowlist with no write tools — not by prompt request.
- Writes go to a scratch/staging area and are shown as a diff or a dry run first.
- Known-bad commands (`docker compose down -v`, `docker volume prune`, `chown -R`, `duplicates --delete`,
  branch switches to nightly, bulk renames) are forbidden in every skill.
- `docs/threat-model.md` covers prompt injection from peer filenames and logs, the trust gate, and what
  Freebuff itself does with your prompts (ad personalisation; some models retain submissions).

## Working with the budget

Freebuff is metered in **Freebucks per one-hour session** (25/day, 20 on a VPN — full access unmeters
some models). The pack is designed around that: skills cost only their metadata until used, `knowledge.md`
stays short because it is paid every turn, subagents absorb noisy output, and `ops/` files make a session
ending cheap to recover from. Details and a model-routing table: [`docs/token-budget.md`](docs/token-budget.md).

## Honest limitations

1. **Custom `.ts` agents are unverified on Freebuff.** Documented for Codebuff; the sandbox could not get
   past the trust prompt into a signed-in session. They are opt-in (Tier 3) and nothing else depends on them.
2. **Model-facing behaviour is unverified.** Whether a model *auto-selects* a skill by its description
   cannot be tested without a signed-in turn. `probe/USER-CHECKLIST.md` settles it in 10 minutes.
3. **Desktop parity is unverified** — the same `.agents/` tree is likely shared, but that is a guess.
4. **Time-sensitive content.** Model names, prices and Freebuff flags change. The pack states *how* to
   check rather than pinning a catalogue.
5. **Not medical, legal or financial advice**, and nothing here advises on the legality of any content.

## Adapting it

- **Not a music person?** Delete `skills/music/` and keep `skills/core/` — it is domain-neutral.
- **Different stack?** `knowledge.md` is the only file with your specifics; the skills describe *method*.
- **Want fewer skills loaded?** Set `disable-model-invocation: true` in a skill's frontmatter to keep it
  out of the auto-selected list while keeping `/skill:<name>` available.
- **Uninstall:** delete `.agents/skills/*` you installed, `knowledge.md` (or your merged version),
  `.agents/mcp.json`, and the `.codebuffignore` lines listed in `templates/codebuffignore`.
