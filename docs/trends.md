# What the research said, and what this pack did about it

Synthesis of a 2025/2026 survey of agentic-coding harnesses, Agent Skills/MCP ecosystems,
workflow patterns, and both target domains. Each section ends with the pack's decision.

## 1. Which harness features actually matter
Plan/read-only mode, a permission model separate from tool choice, subagents with own context,
on-demand instruction loading. Config breadth correlates with burden, not results.
**Decision:** use what Freebuff has (`/plan`, `/interview`, `/review`, `/model`, `/reasoning`,
skills, trust gate). No Claude-Code-only assumptions (hooks, `--plan`).

## 2. Skills beat prompt files — portable format
`SKILL.md` with progressive disclosure is multi-host (Anthropic, Codex, Cursor, Copilot,
Gemini CLI, Codebuff/Freebuff). Metadata is the standing cost; body loads on activation.
**Decision:** skills carry all procedural knowledge. Verified vs shipped CLI: `name` ==
dirname, description <=1024, `disable-model-invocation` exists.

## 3. MCP-everything does not survive a free tier
Tool schemas cost context; attack surface is real (poisoning, shadowing, rug pulls).
**Decision:** one narrow read-only host-allowlisted MCP server (10 GET-only tools); CLI calls
in every skill; third-party servers risk-ranked, not recommended.

## 4. Verification is the product
Pattern: tests first, red/green, exercise the feature, then a **fresh read-only reviewer**
 tries to falsify the claim. Complaint #1 is review burden, not code ability.
**Decision:** `core-verify-loop`, `prompts/04-verify.md`, packaged `@Verifier` agent with
tool-allowlist read-only-ness; "files written" is never "behaviour verified".

## 5. Workflow frameworks: borrow shape, skip dependency
Spec Kit, Superpowers, BMAD, OpenSpec churn; heavy frameworks draw ceremony complaints.
**Decision:** five `prompts/` files (interview → plan → bounded implementation →
verification → handoff). No framework, no plugin layer, no per-turn cost.

## 6. Durable state for metered sessions
Context rots as it grows; long work fails when progress lives only in conversation.
**Decision:** `ops/taskboard.md`, `ops/progress.md`, `ops/decisions.md`, `core-handoff`,
`05-handoff.md`. Highest-leverage adaptation to per-session pricing.

## 7. Self-hosted media: APIs, not platforms
*arr = C#/.NET + Swagger, no plugin framework; Navidrome = Go + WASM plugins;
slskd = Soulseek client + REST, **no native Lidarr integration** on stable.
**Decision:** every skill works at API/config boundary; declarative extension points
(Cardigann, Recyclarr YAML, `.nsp` rules, manifests); upstream contribution rules first.

## 8. PKM: best and worst agent substrate
Plain Markdown = trivially readable AND destroyable; folder scoping is the only permission
boundary; Local REST API exposes write/delete (+MCP endpoint).
**Decision:** `pkm-safe-write` (staged inbox drafts, never rewrite notes, never touch
`.obsidian/`), `pkm-vault-conventions` (read first), `pkm-sync-choice` (name the conflict model).

## 9. Sentiment to design around
Love: grunt-work leverage, debugging, self-check loops. Hate: review burden, context loss,
hallucinated APIs, quota walls, config sprawl. `AGENTS.md` duplication is an active grievance.
**Decision:** one instruction file (`knowledge.md`), `AGENTS.md` as symlink, small descriptions.

## 10. Evidence grading
**verified** = observed in probe or executed here; **[docs]** = docs read in research;
*practitioner* = named report/project docs; *thin* = single source. Thin claims ship **opt-in
and labelled**; `probe/USER-CHECKLIST.md` settles them on your machine.

## 11. Two domains added later (Proxmox + website)
Hypervisor + public face of the project. Same stance: read-only default, no secrets in
prompts/build output, every claim carries its command. Details: `proxmox-notes.md`, `web-notes.md`.
