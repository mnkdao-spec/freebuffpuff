# Working inside the Freebuff budget

Freebuff is ad-supported and metered in **Freebucks, priced per one-hour session** — not per token.

## The numbers that matter [from the CLI's own shipped README, v0.2.27]

| | Full access (US, CA, UK, EU, select others) | Limited access (everywhere else, or on a VPN/proxy) |
|---|---|---|
| Allowance | daily sessions, models below unmetered | **25 Freebucks/day, 20 on a VPN** |
| Model cost | MiMo 2.6 Flash, GLM 5.3 Flash, DeepSeek V4.1 Flash, Solar Mini 4, Solar Pro 4 **unmetered** | every model spends Freebucks; price per one-hour session shown in the picker |
| Cheapest | GLM 5.3 Flash is described as the cheapest to run | same, and today's allowance is spent first regardless of model |

## Why this pack is skills, not a big `AGENTS.md`

- A skill's **name and description** are the only always-loaded cost (order of 100 tokens each).
  Its body loads **only when activated**.
- A long `knowledge.md` is paid on **every single turn**. Keep `knowledge.md` to facts the agent cannot infer, and push every
  procedure into a skill.
- A hook, plugin or MCP server that injects text into every session is a *per-turn* tax. That is why
  the bundled MCP server is 10 narrow read-only tools and nothing else.

## Model routing for this work

| Work | Use | Why |
|---|---|---|
| File finding, inventory, grep, formatting, `.nsp` authoring, report writing | the default / cheapest available model | mechanical, verifiable, no deep reasoning |
| Reasoning about an import failure, writing a plugin, planning a migration | the strongest *unmetered* reasoning model you have | hardest thinking, still free |
| Anything that keeps failing | escalate **deliberately** via `/model`, and use `/reasoning` to raise effort | one expensive session beats ten flailing cheap ones |
| A private note you would not send to a hosted model | `/byok` with your own provider, or Freebuff Desktop driving a locally installed model | the /byok path is verified present in the CLI |

## Habits that actually save sessions

1. **`/plan` before you build.** A plan turn is cheap; a wrong implementation turn is not.
2. **One bounded task per turn.** Long autonomous loops are where budget and correctness both go.
3. **Durable state in files.** `.agents/ops/{taskboard,progress,decisions}.md` means a session ending
   costs nothing.
4. **Subagents for noise.** A directory walk or log window examined by a subagent
   returns a summary instead of filling the main context.
5. **CLI over MCP.** `curl | head -c 800` costs a fraction of a full JSON response, and gives a real exit code.
6. **`/new` when you change topic.**
7. **`/usage` and `/dashboard`** to see where you are; `/history` to resume rather than re-do.
8. **Don't re-read what you already know.** Ask for the diff, not the file.
9. **Prefer the unmetered models for grunt work**; save metered sessions for judgement.

## What this pack deliberately leaves out

- **No hooks and no always-on plugin layer.**
- **No broad MCP servers.**
- **No generated "mega" instruction file.**
- **No CI automation.** There is no headless mode.
