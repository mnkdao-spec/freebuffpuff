# Phase 0 — Freebuff capability probe (observed results)

Method: `npm i freebuff` (v0.2.27) → launcher downloads the platform binary to
`~/.config/manicode/freebuff` (+ `tree-sitter.wasm`, `settings.json`).
Probe repo: `probe/fake-homelab-repo` with token'd instruction files, one skill,
one stdio MCP server, one secret file behind `.codebuffignore`.
Run in a PTY (`script -qec`) so the interactive prompt could be observed.

Everything below is **observed** unless marked `[docs]` (from codebuff.com docs verified in
this session) or `[binary]` (string/behaviour reconstructed from the shipped binary).

## VERIFIED

| # | Finding | Evidence |
|---|---|---|
| 1 | **Freebuff CLI flags are a strict subset of Codebuff's.** Freebuff accepts only `-v/--version`, `--continue [conversation-id]`, `--cwd <directory>`, `--trust-agents`, `-h/--help`, and the positional `login`. | `freebuff --help` output |
| 2 | **No `--plan`, `--max`, `--lite`, `--free`, `--agent`, `--clear-logs`, no `-p`/`--print`/`--json`, no headless mode.** Those flags exist only in the Codebuff build of the same binary. | `freebuff --help`; `[binary]` args branch `if(aA){freebuff options}else{codebuff options}` |
| 3 | **`/mode:*` commands do not exist in Freebuff** (they're Codebuff-only). Freebuff instead has `/plan`, `/interview`, `/review` which set an *input mode* or send a templated message. | `[binary]` `aA?[]:U9.map(...)` for `mode:` slash commands; handlers `v8({name:"plan"})`, `{name:"interview"}`, `{name:"review"}` |
| 4 | Freebuff slash commands present: `/interview` `/plan` `/review` `/model` `/reasoning` `/todo` `/queue` `/history` `/new` `/export` `/copy` `/byok` `/dashboard` `/end-session` `/help` `/diagnostics` `/feedback` `/bash` (`!` prefix) `/theme:toggle` `/logout` `/exit` `/skill:<name>`. | `[binary]` command palette definitions |
| 5 | Freebuff-excluded commands: `/mode:*`, `/init`, `/image`, `/publish`, `/ads:enable`, `/ads:disable`, `/usage`, `/subscribe`, `/agent:gpt-5`. | `[binary]` `eXL` filter applied when `freebuff` |
| 6 | **`knowledge.md` is the idiomatic instruction file.** The built-in init prompt says "Ensure there is a `knowledge.md` file in the project root… Do not mention any deprecated configuration files." Recognised: `knowledge.md`, `*.knowledge.md`, `AGENTS.md`, `CLAUDE.md`. | `[binary]` init prompt text; `wF=["agents.md","claude.md"]` + `endsWith(".knowledge.md")` |
| 7 | **Skills are NOT trust-gated; MCP servers and `.ts` agents ARE.** With only `.agents/skills/hello/SKILL.md` present, Freebuff started the TUI with *no* prompt. With `.agents/mcp.json` present it stopped and asked. | TEST A / TEST B pty runs |
| 8 | The trust prompt **names the exact command line it would run**: `mcp.json: would start \| probeEcho: node /…/mcp-echo.js` and warns "These run with your permissions and can read your environment." Skipped entirely when non-interactive. | observed prompt text |
| 9 | Bypass/env for the trust gate: `--trust-agents` or `CODEBUFF_TRUST_AGENT_DIRS=1`; decisions persist in `~/.config/manicode/trusted-agent-dirs.json`. | `[binary]` `grA()` / `FrA()`; observed prompt text |
| 10 | Skill frontmatter schema: `name` (required, 1–64, `^[a-z0-9]+(-[a-z0-9]+)*$`, **must equal directory name**), `description` (required, silently truncated at 1024), `license`, `disable-model-invocation` (bool), `metadata` (string map). Frontmatter must be YAML after `---` (JS/coffee engines throw). | `[binary]` zod schema `THA`, `kh()` validation + error strings |
| 11 | Skills are advertised to the model in an `<available_skills>` block, and every skill also becomes `/skill:<name>`. `disable-model-invocation: true` removes it from that block but keeps the slash command. | `[binary]` `z$A()` / `Pk()` |
| 12 | `mcp.json` search order is `{cwd}/.agents` → `{cwd}/../.agents` → `~/.agents`, and **later wins — so the global `~/.agents/mcp.json` overrides the project's**. `[docs]` also states this. | `[binary]` `bO$()` + assignment loop |
| 13 | A missing `$VAR` referenced in `mcp.json` **aborts loading that whole file** (server logs "Missing environment variable 'X' required by MCP server 'Y'"), it does not degrade to skipping one server. | `[binary]` `jO$()` throws; caught per-file |
| 14 | Project-scoped `mcp.json` servers are merged into **every** `base*` agent automatically. | `[binary]` `uu()` |
| 15 | Custom TS agents: any `.agents/**/*.ts` (excluding `.d.ts`, `.test.ts`); the agent `id` is extracted and the agent is appended to base agents' spawnable list. Load failures only warn, they don't crash the CLI. | `[binary]` `_EL()`, `jvA()` |
| 16 | In Freebuff you cannot select an agent with `--agent` (Codebuff-only). Agents are addressed in the TUI by `@Display Name`. | `[binary]` flag branch; `[docs]` custom-agent page |
| 17 | Per-project state lives in `~/.config/manicode/projects/<repo-name>/`; user settings in `~/.config/manicode/settings.json` (`mode`, `adsEnabled`, `freebuffModelDefaultMigration`). | observed filesystem |
| 18 | Freebuff supports **BYOK** (`/byok` → OpenRouter or any OpenAI-compatible endpoint) and `/reasoning` (per-model reasoning effort). | `[binary]` command palette + `byok` state/handlers |
| 19 | Model pricing is **per one-hour session** in Freebucks (25/day limited access, 20 on VPN/proxy). In *full* access, MiMo 2.6 Flash / GLM 5.3 Flash / DeepSeek V4.1 Flash / Solar Mini 4 / Solar Pro 4 are unmetered; in *limited* mode every model spends Freebucks. GLM 5.3 Flash is described as the cheapest to run. | npm package README (v0.2.27) |
| 20 | Freebuff itself writes learnings into `.agents/skills/<topic>/SKILL.md` (and `.agents/skills/meta/SKILL.md`), i.e. skills are the platform's own extension path. | `[binary]` learn-prompt text |

## NOT VERIFIABLE FROM THIS SANDBOX (needs your machine)

1. **Model-facing behaviour** — auto-invocation of a skill (does the model actually pick `music-lidarr-match-doctor` from its description?) and whether MCP tools actually get called. Both need a signed-in model turn.
2. **Desktop parity** — whether Freebuff Desktop reads the same `.agents/` tree and honours the same trust prompt.
3. Whether `/reasoning` accepts the exact levels the pack suggests, per model.
4. Local API reachability from inside your project dir (Navidrome/Sonarr/Lidarr `localhost` ports) — see `probe/USER-CHECKLIST.md`.

## Design consequences

- Skill-first is correct: skills load without a trust prompt, are cheap (metadata only), and are the platform's own extension path.
- Keep `knowledge.md` as *the* instruction file; write `AGENTS.md` as a symlink for other tools rather than a second copy (duplication is a known grievance).
- MCP stays **opt-in and tiny**, because it costs trust friction at every new clone *plus* context.
- Since a missing `$VAR` kills the whole `mcp.json`, the pack's MCP fragments only reference variables and the installer tells you to export them before first run.
- `--reasoning`/`/model` and BYOK are the real budget levers; there is no headless mode, so the pack must be driven interactively (no CI loop).
