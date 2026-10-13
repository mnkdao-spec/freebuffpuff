# Working inside the Freebuff budget

Freebuff is ad-supported and metered in **Freebucks, priced per one-hour session** — not per token.
That single fact changes how you should work, and this pack is shaped by it.

## The numbers that matter [from the CLI's own shipped README, v0.2.27]

| | Full access (US, CA, UK, EU, select others) | Limited access (everywhere else, or on a VPN/proxy) |
|---|---|---|
| Allowance | daily sessions, models below unmetered | **25 Freebucks/day, 20 on a VPN** |
| Model cost | MiMo 2.6 Flash, GLM 5.3 Flash, DeepSeek V4.1 Flash, Solar Mini 4, Solar Pro 4 **unmetered** | every model spends Freebucks; price per one-hour session shown in the picker |
| Cheapest | GLM 5.3 Flash is described as the cheapest to run | same, and today's allowance is spent first regardless of model |

Also worth knowing: some models are locked behind a paid plan (they appear in the picker but open the
plans page); one US-promotional model gives every account one session a day; models may serve from a
quantized (Q8_0) build; and **there is no headless mode**, so there is no CI loop to spend budget on
— the budget is spent by *you, interactively*.

## Why this pack is skills, not a big `AGENTS.md`

- A skill's **name and description** are the only always-loaded cost (order of 100 tokens each).
  Its body loads **only when activated**. 25 skills is a small standing cost.
- A long `knowledge.md` is paid on **every single turn**. A 2026 study found LLM-generated
  repo-context files slightly *reduced* success while raising inference cost by ~20%; developer-written
  ones helped only marginally. So: keep `knowledge.md` to facts the agent cannot infer, and push every
  procedure into a skill. ([study](https://arxiv.org/html/2602.11988v1),
  [context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents))
- A hook, plugin or MCP server that injects text into every session is a *per-turn* tax. That is why
  the bundled MCP server is 10 narrow read-only tools and nothing else.

## Model routing for this work

| Work | Use | Why |
|---|---|---|
| File finding, inventory, grep, formatting, `.nsp` authoring, report writing | the default / cheapest available model | mechanical, verifiable, no deep reasoning |
| Reasoning about an import failure, writing a plugin, planning a migration | the strongest *unmetered* reasoning model you have (GLM 5.3 Flash at the time of writing) | hardest thinking, still free |
| Anything that keeps failing | escalate **deliberately** via `/model`, and use `/reasoning` to raise effort | one expensive session beats ten flailing cheap ones |
| A private note you would not send to a hosted model | `/byok` with your own provider, or Freebuff Desktop driving a locally installed Claude Code/Codex | the /byok path is verified present in the CLI |

## Habits that actually save sessions

1. **`/plan` before you build.** A plan turn is cheap; a wrong implementation turn is not.
2. **One bounded task per turn.** Long autonomous loops are where budget and correctness both go.
3. **Durable state in files.** `.agents/ops/{taskboard,progress,decisions}.md` means a session ending
   costs nothing — you resume by reading three files and re-running one command, instead of
   re-deriving the whole situation.
4. **Subagents for noise.** A directory walk, an API dump, or a log window examined by a subagent
   returns a summary instead of filling the main context with raw output.
5. **CLI over MCP.** `curl | head -c 800` costs a fraction of what a tool schema plus a full JSON
   response costs, and it gives you a real exit code. MCP earns its context only when you use it often.
6. **`/new` when you change topic.** Carrying an unrelated context forward makes every later turn
   slightly worse.
7. **`/usage` and `/dashboard`** to see where you actually are; `/history` to resume rather than re-do.
8. **Don't re-read what you already know.** Ask for the diff, not the file.
9. **Prefer the unmetered models for grunt work**; save metered sessions for judgement.
10. **Watch for quantized serving.** If a model behaves worse than expected on a task, try another
    before concluding the task is impossible.

## What this pack deliberately leaves out

- **No hooks and no always-on plugin layer.** Verified: Freebuff exposes no documented user hook
  system, and a hook would be a per-turn cost for every user.
- **No broad MCP servers.** A single *arr MCP server can add thousands of tokens of tool schemas
  before you ask anything.
- **No generated "mega" instruction file.** Techniques that make an agent look thorough (a huge
  context file, a swarm of agents) are exactly the ones that inflate cost without improving results.
- **No CI automation.** There is no headless mode, so a "run the agent on every PR" workflow is not
  available and is not pretended here.
