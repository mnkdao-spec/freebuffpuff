# Freebuff Homelab Pack

An agent package for **Freebuff CLI and Desktop**, aimed at four things that share one box:
a self-hosted **music stack** (Navidrome, Lidarr, Prowlarr, slskd/Soularr, beets), a **personal
knowledge base** (Obsidian/plain Markdown), a **Proxmox VE homelab** hosting all of it, and the
**website** for the music project.

**39 skills · 8 verified diagnostic scripts · 1 read-only MCP server · 5 read-only agents · 7 workflow
prompts · 4 ops files + 4 runbooks.** Everything read-only by default.

```
./install.sh --project .            # into ./.agents/skills + ./.agents/*.ts + knowledge.md + .codebuffignore
./install.sh --global               # into ~/.agents/skills + ~/.agents/*.ts + ~/.knowledge.md
./install.sh --both                 # both
./install.sh --verify               # validate all 39 skills and 5 agents, change nothing
./install.sh --project . --mcp local-readonly    # adds ./.agents/mcp.json (opt-in, GET-only)
bash tests/run.sh                   # re-verify every script yourself (83 checks)
bash tests/invariants.sh            # check the pack's own claims (54 checks)
```

## What's inside

```
knowledge.md          lean, always-loaded: stack map, exact commands, hard rules  (you fill in <EDIT>s)
.agents/skills/       39 skills. Source layout is flat (skills/<skill-name>/); every skill carries
                      its domain as a prefix, and install.sh flattens them into .agents/skills/:
  core-*       (8) verify-loop, plan-then-build, handoff, secrets-hygiene, compose-change,
                   backup-restore-check, log-window-triage, upstream-contribution
  music-*     (11) stack-map, lidarr-match-doctor, path-and-hardlink-doctor, slskd-ops,
                   navidrome-tagging-doctor, navidrome-nsp-author, navidrome-plugin-dev,
                   musicbrainz-lookup, beets-preview, library-audit, lyrics-and-art
  proxmox-*    (7) stack-map, guest-placement, storage-and-mounts, backup-and-restore,
                   gpu-transcode, upgrade-safety, service-exposure
  web-*        (7) site-architect, release-page, structured-data, selfhost-deploy,
                   perf-a11y, audience-and-email, analytics
  pkm-*        (6) vault-conventions, safe-write, capture-to-note, obsidian-plugin-dev,
                   rag-design, sync-choice
scripts (8)           compose-doctor · slskd-doctor · nsp-lint · lib-audit · mb-lookup
                      pve-doctor · lxc-audit · site-audit
                      -> all read-only, all executed and verified before shipping
mcp/                  local-readonly server (10 GET-only tools) + risk-ranked third-party shortlist
agents/               5 read-only TS agents: Repo Cartographer, Verifier, Library Auditor,
                          Proxmox Auditor, Site QA. install.sh copies them to .agents/*.ts
                          (+ .agents/types/), which IS trust-gated - expect one prompt
tests/                run.sh: the verification harness. Builds fixtures, installs into a
                          scratch repo, runs every script and asserts the findings
                      invariants.sh: checks the claims this README makes - read-only,
                          agent allowlists, frontmatter contract, installer idempotency,
                          Windows failure modes, no shipped credentials
prompts/              01-interview · 02-plan · 03-implement · 04-verify · 05-handoff
                      · 06-infra-change · 07-release-day
ops/                  taskboard · progress · decisions · homelab-inventory
                      runbooks/{music, pkm, proxmox, website}
docs/                 probe-results · threat-model · token-budget · trends
                      music-notes · proxmox-notes · web-notes · pkm-notes · windows
probe/                the Phase 0 probe kit + USER-CHECKLIST.md (10 minutes, on your machine)
```

## The two new domains

### Proxmox (`skills/proxmox/`)
Everything is written for a **single-box homelab running the media stack**, where the failure that
actually costs data is a mount that is not in a backup. The skills encode the documented rules that
surprise people:

- **Additional container mount points are excluded from vzdump by default** - only the GUI's
  mount-point dialog ticks the box for you. Bind and device mounts are *never* backed up.
- **VM vs LXC for Docker** - Proxmox's FAQ says don't run Docker on the hypervisor; a VM is the
  low-maintenance guest, an unprivileged LXC with `nesting=1,keyctl=1` is the efficient one.
- **Nested Docker inherits host risk** - the 2025 `runc`/AppArmor breakage was fixed by updating
  `lxc-pve`, not by disabling AppArmor.
- **Hardlinks** need one filesystem: two ZFS datasets in one pool are two filesystems.
- **Never expose 8006**; the *arr UIs and the library stay on the LAN/tailnet.
- **Upgrades**: 8 → 9 is a Debian release change (`pve8to9 --full`, at least ~5 GB free on `/` and
  ideally >10 GB, no mixed suites), and there is no supported downgrade. PVE 8.4's support window
  ended in **August 2026**, so if you are still on 8.x the upgrade is the maintenance task.

### Website (`skills/web/`)
A **static-first** site for the project (Astro-shaped by default: content collections for releases,
tracks, gigs and posts), self-hosted behind Caddy on the same box, with:

- **release pages** with stable URLs, owned `/listen/<slug>/` smart links, facades for third-party
  players, and safe private pre-release streaming (a Navidrome *share* or a separate preview store -
  never an admin credential in browser code);
- **structured data** that is honest about the gap between valid markup and a Google rich result;
- **atomic deploys** (new release directory + symlink swap, never `rsync --delete` into live),
  with the CDN cache purge explicitly on the release checklist;
- **measurement**: Core Web Vitals budgets, JS budgets, and `site-audit.sh` for the built output;
- **audience**: double opt-in, SPF/DKIM/DMARC, and one server-side endpoint instead of keys in the
  browser bundle.

## The eight scripts (verified, read-only)

| Script | What it does | Proof it works |
|---|---|---|
| `compose-doctor.sh` | flags the same host path mounted at different container paths, named-volume vs bind, UID/GID/umask incoherence, `SLSKD_UMASK` misuse, VPN sidecar networking, `depends_on` without health, and whether the download root and library root are **one filesystem** (the hardlink precondition) | caught a real slskd `/downloads` vs Lidarr `/data/downloads` mismatch; reported same-device as OK and cross-device as a WARN, and said exactly how to check a path it cannot see |
| `lib-audit.sh` | tag completeness, codec/bitrate anomalies, extension-vs-codec mismatch, FLAC integrity, duplicate candidates (optionally content-hashed). Needs `ffprobe`/`metaflac`/`flac`; when a tool is missing it prints `NOT RUN` for those checks instead of guessing | detected a corrupt FLAC, a truncated 0.4 s track, a 0-length file, a 96 kbps file and missing tags **with** the toolchain; with **none** of it installed it exits 0, names every skipped check, and invents no findings |
| `nsp-lint.sh` | validates Navidrome `.nsp` smart-playlist JSON structure and vocabulary | rejects a bad rule tree and a 250% `limitPercent`; accepts a valid playlist |
| `mb-lookup.sh` | MusicBrainz lookups with enforced 1 req/s (serialised across processes), caching, 503 backoff, `classify` for the release-vs-release-group trap | request starts measured >=1.1 s apart; cache hit is instant |
| `slskd-doctor.sh` | read-only GETs for session/server/shares/transfer state, with an interpretation guide | reports per-endpoint status; treats 404 as "not in this version" |
| **`pve-doctor.sh`** | whole-host audit: rootfs/storage pressure, inactive storage, ZFS pool health, ARC limit, guest configs and **which mounts are not in a backup**, Docker on the host, repository hygiene, pending updates | on a fixture host it caught an inactive NFS store, a 95%-full thin pool, a `DEGRADED` pool, a `backup=0` volume, a world-writable `/dev/dri`, Docker on the host, an unsubscribed enterprise repo and two uncovered guests |
| **`lxc-audit.sh`** | one container in depth: unprivileged/features, every `mp*`/`dev*`/raw mount with its backup consequence, system-path and symlink sources, duplicate and nested targets, world-writable devices, and `--paths A:B` for the hardlink question | caught the mp-backup-default trap, a symlinked bind source, a duplicate mount target, and reported same/different filesystems correctly (exit 1 under `--strict`) |
| **`site-audit.sh`** | built-site audit: leaked `.env`/`.map`/`node_modules`/keys, invalid JSON-LD and missing required props, OG/canonical/title/description, images without alt/dimensions, broken internal links, missing 404/robots/sitemap/feed, JS weight vs budget; `--url` compares the **served bytes with your build** and checks for real 404s | flagged 2 publishing blockers + 9 warnings on a deliberately bad build while passing a good one; the `live:hash` check correctly matched a clean deploy and flagged a stale one |

## Safety stance

- **Nothing here writes to your music library, your vault, a running service's state, or the
  hypervisor without you saying so in that message.** Destructive steps are labelled
  APPROVAL-REQUIRED, not silently skipped.
- The Proxmox scripts are read-only by construction (no `qm`/`pct set`, no storage or firewall
  changes) and say what they could not read instead of guessing.
- The MCP server is **GET-only by construction**: host-allowlisted, every `fetch()` call site
  hardcoded to `GET`, and no write tool exposed. Verified by `tests/invariants.sh`.
- The five agents have **no file-writing tool in their allowlists** (`write_file`, `str_replace`,
  `run_file_change_hooks` are absent from all five) - that is checked mechanically. They *do*
  have `run_terminal_command`, because their job is to run the read-only audit scripts; for that
  one tool the guarantee is the system prompt, not the allowlist. Delete that name from
  `toolNames` if you want zero write capability. See `agents/README.md`.
- Known-bad commands (`docker compose down -v`, `docker volume prune`, `chown -R`,
  `duplicates --delete`, nightly branch switches, bulk renames, `rm` on data) are forbidden in
  every skill.
- The PVE API token in `docs/proxmox-notes.md` is a **read-only `PVEAuditor`** credential; the pack
  deliberately does not add Proxmox tools to the MCP server, because a PVE token is hypervisor-wide
  read and the read-only scripts are narrower and visible.
- `docs/threat-model.md` covers prompt injection from peer filenames and logs, the trust gate, and
  what Freebuff itself does with your prompts (ad personalisation; some models retain submissions).

## Windows 11

Read [`docs/windows.md`](docs/windows.md). The short version:

- Needs **Git for Windows** (for `bash`/`awk`/`sed`), **Node 18+**, **Python 3.9+**. Run the installer
  from **Git Bash**, not PowerShell or cmd. The scripts fall back to `python` when `python3` is missing.
- **Do not cross the WSL/Windows boundary.** Freebuff on Windows cannot execute a `server.js` on a
  `\\wsl$\` path. Keep the pack and the repo on the same side, per install.
- **Hardlinks are the real risk.** Media on `C:\` bind-mounted into Docker Desktop crosses the
  Windows→WSL2 boundary, where same-filesystem hardlink semantics are not guaranteed. Keep the
  library on a Linux-side filesystem and verify with `stat -c '%d %i'` inside the containers.
- The **Proxmox scripts run on the PVE host** (Linux), not on Windows. `site-audit.sh` works fine in
  Git Bash against a `dist/` built anywhere.
- Line endings are forced to LF by `.gitattributes`; the installer **refuses to install** CRLF scripts.

## Built against the real CLI, not the docs

The extension surface was probed against the shipped Freebuff binary (v0.2.27) before anything was
written. Full results in [`docs/probe-results.md`](docs/probe-results.md). The findings that shaped
this pack:

| Finding | Consequence |
|---|---|
| Freebuff's flag set is a strict subset of Codebuff's: `--continue`, `--cwd`, `--trust-agents`, `login`. **No `--plan`, `--max`, `--lite`, `--agent`, and no headless mode.** | The pack is designed for interactive use. `/plan`, `/interview`, `/review` are the real entry points. |
| **Skills are not trust-gated. `mcp.json` and `.agents/*.ts` are.** The prompt prints the exact commands it would run. | MCP and custom agents stay **opt-in**. Never install skills from a repo you have not read. |
| Skill `name` **must equal its directory name**; `description` is the only signal for auto-loading. | `install.sh --verify` enforces this on all 39 skills. Descriptions are written as triggers. |
| A missing `$VAR` in `mcp.json` **drops the whole file**, not one server. | Documented loudly in `mcp/README.md` and printed by the installer. |
| `~/.agents/mcp.json` **overrides** the project's. | Stated in `docs/probe-results.md`. |
| `.agents/**/*.ts` are listed as agent files; **`.d.ts` is excluded**. | The shared type file is `agent-definition.d.ts`, so it triggers no pointless trust prompt. |
| `/mode:*` does not exist in Freebuff (Codebuff only). | Nothing in the pack asks you to type it. |

## Working with the budget

Freebuff is metered in **Freebucks per session** (25/day, fewer on a VPN). 39 skills cost only their
metadata until used, `knowledge.md` stays short because it is paid every turn, subagents absorb noisy
output, and `ops/` makes a session ending cheap to recover from. Details and a model-routing table:
[`docs/token-budget.md`](docs/token-budget.md).

## Re-verifying it yourself

Two suites, both exit non-zero on any failure. They were written to catch the author, not to
flatter the pack - most of the defects listed in this file were found by one of them.

**`bash tests/run.sh`** (83 checks) - behavioural. Builds fake PVE, compose, `.nsp`, music, site and
audio-toolchain fixtures under `/tmp/freebuff-pack-verify`, installs the pack into a scratch repo
with `--force` (so it always tests *your current copy*, never a stale install), runs all 8 scripts
**from `.agents/skills/*/scripts/`** the way an agent would, and asserts the findings - including
the negative cases (a clean config must produce no warning, no `ffprobe` must produce no traceback,
a cache hit must not be rate-limited). The MusicBrainz section needs network and skips loudly
without it.

**`bash tests/invariants.sh`** (54 checks) - the claims *this README* makes, checked mechanically:

| Claim | How it is tested |
|---|---|
| "39 skills · 8 scripts · 5 agents · 7 prompts" | counts parsed out of this file and compared with the tree |
| every skill satisfies the documented frontmatter contract | name matches directory, charset, ≤64 chars, description 1-1024, **unique** names and descriptions, `metadata.category` matches the prefix |
| "read-only" | every input file is hashed before and after all 8 scripts run; the suite fails if a single byte changes |
| the agents are read-only | each definition is executed and its `toolNames` checked against the **documented** tool vocabulary; any `write_file`/`str_replace`/`run_file_change_hooks` fails the suite |
| known-bad commands are forbidden | every mention of `docker compose down -v`, `docker volume prune`, `chown -R`, `duplicates --delete` must sit in a prohibitive sentence |
| the installer is safe | `--dry-run` writes nothing; an existing `knowledge.md`/`.codebuffignore` is never overwritten; `--global` stays out of the cwd |
| Windows failure modes | a CRLF script makes the install abort; a BOM+CRLF skill still validates; a pack path with spaces and `&` still yields valid `mcp.json` with no raw backslashes |
| the MCP server is GET-only | every `fetch()` call site is hardcoded `method: 'GET'`; an unknown tool name returns a JSON-RPC error, not a result |
| no credentials ship | scans for key-shaped strings (`tests/` excluded - it plants one on purpose) |

## Honest limitations

1. **The Proxmox scripts were verified against fixtures and a shimmed `pvesh`, not on a live PVE
   host** (the build sandbox has no hypervisor). They report what they could not read; expect to
   confirm the JSON shape of a `pvesh get` endpoint on your version the first time you run them.
2. **The website tooling is static-only.** No browser automation was available, so nothing here has
   rendered a page, run Lighthouse, or driven a keyboard.
3. **Custom `.ts` agents are only half-verified.** `install.sh` copies them and `--verify` loads each
   one under Node's type stripping (so a syntax error fails the install), but whether *Freebuff*
   registers and runs them could not be tested - that needs a signed-in session past the trust
   prompt. Nothing else in the pack depends on them.
4. **Model-facing behaviour is unverified.** Whether a model *auto-selects* a skill by description
   cannot be tested without a signed-in turn. `probe/USER-CHECKLIST.md` settles it in 10 minutes.
5. **Desktop parity is unverified** - the same `.agents/` tree is likely shared, but that is a guess.
6. **Time-sensitive content, re-checked against the current docs (October 2026) but still
   time-sensitive.** `docs/music-notes.md` opens with a version-checkpoint table (Navidrome 0.64.x,
   Lidarr 3.x, slskd's `v0` API, PVE 9.2) naming the specific behaviour that changed. Confirmed
   against current docs: PVE 9.x with 8.4 already past EOL, ARC capped at 10%/16 GiB since 8.1,
   `PVEAuditor` + privilege separation, Navidrome's `.nsp` operator set and the all/any rule, the
   `.ndp` plugin package, Lidarr's 80%/60% as **album match and worst-matching track** (not a
   percentage of tracks), "Use Hardlinks Instead of Copy" on by default, the CWV set as **LCP/INP/CLS**
   (INP replaced FID), and the fact that Google lists **no** dedicated music rich result. Where a
   fact could not be confirmed from an official page it is marked as unverified rather than stated.
7. **The `model` field on the agents is a deliberate deviation.** Current Codebuff docs list it as
   required; these definitions omit it so they inherit your session's model instead of pinning an
   id that may not exist in your catalog. One line per file fixes it if your TUI rejects them -
   `agents/README.md` and the checklist say exactly what to add.
8. **`lib-audit.sh` reports only what your box can measure.** Codec/duration/bitrate checks need
   `ffprobe` (ffmpeg) and the FLAC integrity test needs `flac`; a minimal container may have neither.
   The script says which checks it skipped rather than reporting a library full of "duration 0".
9. **Not medical, legal or financial advice**, and nothing here advises on the legality of any
   content.

## Adapting it

- **Not a notes person?** Delete `skills/pkm/` (and `docs/pkm-notes.md`).
- **Not a music person?** Delete `skills/music/` (and `docs/music-notes.md`) and keep `skills/core/`.
- **Not on Proxmox?** Delete `skills/proxmox/`; the rest is hypervisor-agnostic.
- **No website?** Delete `skills/web/` and `prompts/07-release-day.md`.
- **Different stack?** `knowledge.md` is the only file with your specifics; the skills describe method.
- **Want fewer skills loaded?** Set `disable-model-invocation: true` in a skill's frontmatter to keep
  it out of the auto-selected list while keeping `/skill:<name>` available.
- **Uninstall:** delete `.agents/skills/*` you installed, `knowledge.md` (or your merged version),
  `.agents/mcp.json`, and the `.codebuffignore` lines listed in `templates/codebuffignore`.
