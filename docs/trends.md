# What the research said, and what this pack did about it

Synthesis of a late-2025/2026 survey of agentic-coding harnesses, the Agent Skills and MCP
ecosystems, practitioner workflow patterns, social sentiment, and both target domains. Each section
ends with the decision this pack made.

## 1. Which harness features actually matter

Surveyed: Claude Code, Codex CLI, Gemini CLI, OpenCode, Cline, Roo Code, Aider, Amp, Cursor (IDE +
CLI + cloud), Devin, Windsurf/Cascade, Continue, Goose, Crush, Zed's ACP host, Amazon Kiro, Qwen
Code, Poolside CLI, Jules, OpenHands, plus hosts/orchestrators.
Sources: [Claude Code best practices](https://code.claude.com/docs/en/best-practices),
[Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security),
[OpenCode agents](https://opencode.ai/docs/agents/), [Amp modes & subagents](https://ampcode.com/docs/models-and-subagents),
[Zed external agents](https://zed.dev/docs/ai/external-agents), [Kiro](https://aws.amazon.com/documentation-overview/kiro/).

The features that recur across every strong harness are: an explicit **plan/read-only mode**, a
**permission/sandbox model** separate from tool choice, **subagents with their own context**, and
**on-demand instruction loading**. Configuration-surface breadth correlates with operator burden,
not with better results.

**Decision:** use the features Freebuff actually has (verified in `probe-results.md`): `/plan`,
`/interview`, `/review`, `/model`, `/reasoning`, skills, and the trust gate. Do not write "portable"
config that assumes Claude-Code-only features such as hooks or `--plan`.

## 2. Skills beat prompt files — and the format is now portable

`SKILL.md` with progressive disclosure is an open, multi-host format (Anthropic, Codex, Cursor,
Copilot/VS Code, Gemini CLI, and Codebuff/Freebuff). Metadata is the standing cost; the body loads
on activation. Sources: [spec](https://agentskills.io/specification),
[Anthropic overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview),
[best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

**Decision:** skills are the pack's carrier for all procedural knowledge. Verified against the
shipped CLI rather than the docs: `name` must equal the directory name, `description` is truncated at
1024 chars, `disable-model-invocation` exists, and `description` is the only thing the model uses to
decide whether to load — so every description here states the capability *and* the trigger conditions.

## 3. MCP-everything does not survive contact with a free tier

Tool schemas are a real context cost (a five-server setup has been measured at ~55k tokens of
definitions), and the attack surface is real: tool poisoning, tool shadowing, rug pulls, and the
documented `mcp-remote` and `postmark-mcp` incidents. Mitigations the ecosystem converged on are
deferred tool loading, code-execution instead of one-call-per-tool, and narrow goal-oriented servers.
Sources: [advanced tool use](https://www.anthropic.com/engineering/advanced-tool-use),
[code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp),
[tool poisoning](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks),
[CVE-2025-6514](https://jfrog.com/blog/2025-6514-critical-mcp-remote-rce-vulnerability/),
[lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/).

**Decision:** ship **one** narrow, read-only, host-allowlisted MCP server (10 GET-only tools) instead
of a catalogue of wrappers; put third-party servers in a risk-ranked shortlist that names the risk
instead of recommending them; prefer CLI calls in every skill.

## 4. Verification is the product; the review burden is the real complaint

The consistent practitioner pattern is: run the tests first, red/green TDD, exercise the real feature,
then get a **fresh read-only reviewer** to try to falsify the claim. The dominant professional
complaint across HN/X is not that agents cannot code — it is that *review* became the bottleneck.
Sources: [Simon Willison's patterns](https://simonwillison.net/guides/agentic-engineering-patterns/first-run-the-tests/),
[Agentic manual testing](https://simonwillison.net/guides/agentic-engineering-patterns/agentic-manual-testing/),
[Anthropic: long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents),
[Ronacher: a year of vibes](https://lucumr.pocoo.org/2025/12/22/a-year-of-vibes/).

**Decision:** `core-verify-loop`, `prompts/04-verify.md`, and a packaged `@Verifier` agent whose
read-only-ness is enforced by its **tool allowlist**, plus a rule that "files written" is never
reported as "behaviour verified".

## 5. Workflow frameworks: borrow the shape, skip the dependency

Spec Kit, Superpowers, BMAD, OpenSpec, cc-sdd, Agent OS and Ruflo are all real and adopted; the
category also churns (Agent OS retired its v2 orchestration, Claude Flow became Ruflo), and heavy
frameworks drew consistent complaints about ceremony on small changes.
Sources: [spec-kit](https://github.com/github/spec-kit), [superpowers](https://github.com/obra/superpowers),
[BMAD](https://github.com/bmad-code-org/BMAD-METHOD), [OpenSpec](https://github.com/Fission-AI/OpenSpec),
[cc-sdd](https://github.com/gotalab/cc-sdd), [Agent OS v3](https://github.com/buildermethods/agent-os/discussions/310).

**Decision:** the five `prompts/` files reproduce the useful spine (interview → plan → one bounded
implementation → independent verification → handoff) with no installed framework, no plugin layer,
and no per-turn context cost. `core-plan-then-build` explicitly says to skip planning for a one-line fix.

## 6. Durable state is what makes a metered, session-limited harness workable

Context is a budget, context degrades as it grows ("context rot"), and long-horizon work fails when
progress lives only in the conversation. Anthropic's long-running-agent guidance is one feature at a
time, an environment set up once, a progress file, and explicit handoffs.
Sources: [context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents),
[long-running harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

**Decision:** `ops/taskboard.md`, `ops/progress.md`, `ops/decisions.md` and `core-handoff`, and a
`05-handoff.md` prompt. This is the single highest-leverage adaptation to Freebuff's per-session pricing.

## 7. Self-hosted media: these are APIs, not platforms

The *arr family is C#/.NET with local Swagger and no general plugin framework; Navidrome is Go with
a sandboxed WASM plugin system; Immich is TS + Python with OpenAPI-generated clients and no official
MCP server; slskd is a Soulseek client with a REST API and **no native Lidarr integration** on stable.
Jellyfin publishes an LLM contribution policy that permits AI as an aid and rejects unreviewed
submissions. Sources: [Lidarr plugins](https://wiki.servarr.com/en/lidarr/plugins),
[slskd config](https://github.com/slskd/slskd/blob/master/docs/config.md),
[Navidrome plugins](https://www.navidrome.org/docs/usage/features/plugins/),
[Jellyfin LLM policy](https://jellyfin.org/docs/general/contributing/llm-policies/).

**Decision:** every domain skill works at the API/config boundary, prefers **declarative extension
points** (Cardigann definitions, Recyclarr YAML, `.nsp` rules, plugin manifests), and states the
upstream contribution rules before suggesting a PR.

## 8. PKM: the vault is the best and worst agent substrate

Plain Markdown makes a vault trivially agent-readable and trivially agent-destroyable; folder scoping
is the only real permission boundary; Obsidian's Local REST API exposes not just a REST surface but an
MCP endpoint with write and delete. Local-first spans four different meanings from file sync to CRDT
merge. Sources: [Local REST API](https://github.com/coddingtonbear/obsidian-local-rest-api),
[Smart Connections](https://github.com/brianpetro/obsidian-smart-connections),
[Syncthing conflict behaviour](https://docs.syncthing.net/users/syncing.html), [Yjs](https://docs.yjs.dev/).

**Decision:** `pkm-safe-write` (staged drafts in the inbox, never rewrite existing notes, never touch
`.obsidian/`, never promote a draft), `pkm-vault-conventions` (read conventions before writing), and
`pkm-sync-choice` (name the conflict model and what it can lose, rather than recommending a brand).

## 9. Sentiment: what to design around

Love: real leverage on grunt work, debugging, and self-checking loops. Hate: review burden, context
loss late in multi-step work, hallucinated or outdated APIs, quota walls mid-session, and config
sprawl ("seven MCP servers, 5000-line AGENTS.md"). `AGENTS.md` vs `CLAUDE.md` vs `GEMINI.md`
duplication is an active grievance, and "skills are just prompt engineering" is a common dismissal
that is correct about *format* and wrong about *cost*: deferred loading is the whole point.
Freebuff-specific sentiment is thin — praise for free access and subagent UX; complaints about
regional/limited-mode caps, session-file growth, and the privacy model.
Sources: [Claude Skills thread](https://news.ycombinator.com/item?id=45607117),
[Superpowers thread](https://news.ycombinator.com/item?id=45547344),
[AGENTS.md thread](https://news.ycombinator.com/item?id=44381169).

**Decision:** one instruction file (`knowledge.md`), `AGENTS.md` as a symlink rather than a copy,
small descriptions, no config sprawl, and no always-on layer.

## 10. Evidence grading used throughout this pack

| Grade | Meaning |
|---|---|
| **verified** | observed in the Phase 0 probe against the shipped CLI, or executed in this session |
| ***[docs]*** | from Freebuff/Codebuff documentation read during this research |
| *practitioner* | a named practitioner's report or a project's own documentation |
| *thin* | one source, small sample, or a claim the pack does not rely on |

Where evidence was thin — notably whether Freebuff loads custom `.ts` agents, and Freebuff Desktop
parity — the pack ships the feature as **opt-in and labelled**, and `probe/USER-CHECKLIST.md` exists
so you can settle it on your own machine in ten minutes.
