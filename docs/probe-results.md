# Phase 0 — Freebuff capability probe (observed results)

Method: `npm i freebuff` (v0.2.27) → launcher downloads the platform binary.
Probe repo: `probe/fake-homelab-repo` with token'd instruction files, one skill,
one stdio MCP server, one secret file behind `.codebuffignore`. Run in a PTY.

## VERIFIED

| # | Finding | Evidence |
|---|---|---|
| 1 | **Freebuff CLI flags are a strict subset of Codebuff's** (only `--continue`, `--cwd`, `--trust-agents`, `login`). | `freebuff --help` |
| 2 | **No `--plan`, `--max`, `--lite`, `--agent`, no headless mode.** Codebuff-only. | `--help`; binary args branch |
| 3 | **`/mode:*` does not exist in Freebuff**; `/plan`, `/interview`, `/review` instead. | binary command definitions |
| 4 | Freebuff slash commands: `/interview` `/plan` `/review` `/model` `/reasoning` `/todo` `/queue` `/history` `/new` `/export` `/copy` `/byok` `/dashboard` `/end-session` `/help` `/diagnostics` `/feedback` `/bash` `/theme:toggle` `/logout` `/exit` `/skill:<name>`. | binary palette |
| 5 | Freebuff-excluded: `/mode:*`, `/init`, `/image`, `/publish`, `/ads:*`, `/usage`, `/subscribe`. | binary filter |
| 6 | **`knowledge.md` is the idiomatic instruction file.** Recognised: `knowledge.md`, `*.knowledge.md`, `AGENTS.md`, `CLAUDE.md`. | binary init prompt |
| 7 | **Skills NOT trust-gated; MCP + `.ts` agents ARE.** | pty runs |
| 8 | Trust prompt **names exact command lines**; skipped when non-interactive. | observed prompt |
| 9 | Bypass: `--trust-agents` or `CODEBUFF_TRUST_AGENT_DIRS=1`; persists in `trusted-agent-dirs.json`. | binary + observed |
| 10 | Skill frontmatter: `name` (1–64, slug, **== dirname**), `description` (<=1024), `license`, `disable-model-invocation`, `metadata`. | binary zod schema |
| 11 | Skills advertised in `<available_skills>` + `/skill:<name>`. `disable-model-invocation` hides from block, keeps slash. | binary |
| 12 | `mcp.json` search: `{cwd}/.agents` → `{cwd}/../.agents` → `~/.agents`; **global overrides project**. | binary |
| 13 | Missing `$VAR` **aborts the whole `mcp.json` file**, not one server. | binary |
| 14 | Project `mcp.json` servers merge into every base agent. | binary |
| 15 | Custom TS agents: `.agents/**/*.ts` (excl. `.d.ts`, `.test.ts`); failures warn, don't crash. | binary |
| 16 | No `--agent` flag; agents addressed via `@Display Name`. | binary + docs |
| 17 | Project state in `~/.config/manicode/projects/`; settings in `settings.json`. | observed fs |
| 18 | **BYOK** (`/byok`) + `/reasoning` supported. | binary |
| 19 | Pricing **per one-hour session** in Freebucks (25/day, 20 on VPN). Unmetered models in full access. | npm README |
| 20 | Freebuff writes learnings into `.agents/skills/<topic>/SKILL.md` — skills are the platform's own path. | binary |

## NOT VERIFIABLE FROM SANDBOX (needs your machine)

1. **Model-facing behaviour** — skill auto-invocation, MCP tool calls. Needs a signed-in turn.
2. **Desktop parity** — same `.agents/` tree?
3. `/reasoning` levels per model.
4. Local API reachability — see `probe/USER-CHECKLIST.md`.

## Design consequences

- Skill-first: no trust prompt, cheap metadata, platform's own path.
- `knowledge.md` as the file; `AGENTS.md` as symlink (no duplication).
- MCP opt-in and tiny (trust friction + context).
- Missing `$VAR` kills whole `mcp.json` → fragments reference vars; installer tells you to export first.
- No headless mode → interactive-driven pack (no CI loop).
