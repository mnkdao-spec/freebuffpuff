# Freebuff Homelab Pack

An agent package for **Freebuff CLI and Desktop**: self-hosted **music stack** (Navidrome, Lidarr, Prowlarr, slskd/Soularr, beets), **personal knowledge base** (Obsidian/plain Markdown), **Proxmox VE homelab**, and the **website** for the music project.

**39 skills · 8 verified diagnostic scripts · 1 read-only MCP server · 5 read-only agents · 7 workflow prompts · 4 ops files + 4 runbooks.** Everything read-only by default.

```
./install.sh --project .            # into ./.agents/skills + ./.agents/*.ts + knowledge.md + .codebuffignore
./install.sh --global               # into ~/.agents/skills + ~/.agents/*.ts + ~/.knowledge.md
./install.sh --both                 # both
./install.sh --verify               # validate all 39 skills and 5 agents, change nothing
./install.sh --project . --mcp local-readonly    # adds ./.agents/mcp.json (opt-in, GET-only)
bash tests/run.sh                   # re-verify every script yourself (83 checks)
bash tests/invariants.sh            # check the pack's own claims (54 checks)
```

See **USER_GUIDE.md** for the extensive user guide (install, skills, agents, scripts, testing, troubleshooting) and **HANDOFF_PROMPT.md** for the handoff prompt to run environment-specific tests on your own machine.

## What's inside

```
knowledge.md          lean, always-loaded: stack map, exact commands, hard rules  (you fill in <EDIT>s)
.agents/skills/       39 skills (core-* music-* proxmox-* web-* pkm-*); install.sh flattens skills/<name>/ into .agents/skills/
scripts (8)           compose-doctor · slskd-doctor · nsp-lint · lib-audit · mb-lookup · pve-doctor · lxc-audit · site-audit
mcp/                  local-readonly server (10 GET-only tools) + risk-ranked third-party shortlist
agents/               5 read-only TS agents: Repo Cartographer, Verifier, Library Auditor, Proxmox Auditor, Site QA
tests/                run.sh (83 checks) + invariants.sh (54 checks)
prompts/              01-interview · 02-plan · 03-implement · 04-verify · 05-handoff · 06-infra-change · 07-release-day
ops/                  taskboard · progress · decisions · homelab-inventory + runbooks/{music, pkm, proxmox, website}
docs/                 probe-results · threat-model · token-budget · trends · music-notes · proxmox-notes · web-notes · pkm-notes · windows
probe/                Phase 0 probe kit + USER-CHECKLIST.md (10 minutes, on your machine)
```

## Safety stance

- **Nothing here writes to your music library, vault, service state, or hypervisor without you saying so in that message.** Destructive steps are APPROVAL-REQUIRED.
- Proxmox scripts are read-only by construction; MCP server is **GET-only** (host-allowlisted); agents have **no file-writing tools** in allowlists (checked mechanically by tests/invariants.sh).
- Known-bad commands (`docker compose down -v`, `docker volume prune`, `chown -R`, `duplicates --delete`, bulk renames, `rm` on data) are forbidden in every skill.
- `docs/threat-model.md` covers prompt injection, the trust gate, and what Freebuff does with prompts.

## Skill domains

- **Proxmox**: additional container mounts excluded from vzdump by default (GUI ticks the box); VM vs LXC for Docker; nested-Docker host risk; hardlinks need one filesystem; never expose 8006; 8→9 is a Debian release change (`pve8to9 --full`), no downgrade. PVE 9.x current; 8.4 EOL Aug 2026.
- **Website**: static-first (Astro content collections), self-hosted Caddy or managed hosting; release pages with stable URLs + owned `/listen/<slug/>` links; honest structured data (valid ≠ rich result); atomic deploys (new dir + symlink swap); Core Web Vitals budgets + `site-audit.sh`.
- **Music**: Navidrome tag-oriented grouping; Lidarr release-group (not release) MBIDs, ~80%/60% import thresholds; slskd not a native Lidarr client (Soularr bridge or nightly plugin); MusicBrainz ≤1 req/s; beets `--pretend` first.
- **PKM**: Obsidian plugin manifest requires `author`; Vault API over Adapter; embedding input limits (MiniLM 256 tokens); Sync merges Markdown; double-syncing loses files.

## Re-verifying it yourself

Two suites, both exit non-zero on failure:

- **`bash tests/run.sh`** (83 checks): fixtures under `/tmp/freebuff-pack-verify`, installs with `--force`, runs all 8 scripts from installed locations, asserts findings incl. negative cases. MusicBrainz section needs network (skips loudly without it).
- **`bash tests/invariants.sh`** (54 checks): counts vs tree, frontmatter contract, read-only (input hashing), agent allowlists vs documented vocabulary, installer safety, Windows modes, MCP GET-only, no shipped credentials.

## Honest limitations

1. Proxmox scripts verified against fixtures + shimmed `pvesh`, not a live host.
2. Website tooling is static-only; no page has been rendered in a browser here.
3. Custom `.ts` agents half-verified (load under Node; Freebuff registration needs a signed-in session).
4. Skill auto-selection unverified (needs a signed-in turn). `probe/USER-CHECKLIST.md` settles it in 10 minutes.
5. Desktop parity unverified.
6. Time-sensitive content re-checked Oct 2026; re-verify versions against upstream docs.
7. Agents omit `model` deliberately (inherit session model); one-line fix in `agents/README.md` if your TUI requires it.
8. `lib-audit.sh` needs `ffprobe`/`flac` for codec/integrity checks; otherwise reports NOT RUN.
