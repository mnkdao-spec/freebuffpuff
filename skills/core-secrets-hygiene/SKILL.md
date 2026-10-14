---
name: core-secrets-hygiene
description: Handle credentials safely in a repository that contains API keys, .env files and private data - read variable names instead of values, avoid printing or committing secrets, use placeholder examples, and know what Freebuff itself can and cannot be trusted with. Use before reading config, when a task involves an API key or token, when adding a new integration, or when auditing a repo that may contain secrets.
metadata:
  category: core
---

# Secrets hygiene

Freebuff prompts may be analysed to personalise ads, and models labelled
"may use data for AI training" may retain submissions. Treat every prompt as
potentially public. `docs/threat-model.md` has the full picture.

## Rules
1. **Never read or print secret values.** Not `.env`, not `*.key`, not `config.xml` API keys,
   not `slskd.yml` credentials. Read `.env.example`, or `grep -o '^[A-Z_]*=' .env` for
   variable *names* only.
2. **Never echo a key into a command** you then run, or into a report, or into a commit.
   Use the environment: `curl -H "X-Api-Key: $LIDARR_API_KEY" ...`.
3. **Never commit** `.env`, key files, or config files containing tokens. Check
   `.gitignore` before adding a new config file to the repo.
4. **Placeholders in examples.** `your-token-here`, never a real-looking value.
5. If a secret has already been printed in this conversation, say so plainly and recommend
   rotating it. Do not try to hide it.

## Checking a repo without exposing it
```bash
# variable NAMES only, no values
grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' .env 2>/dev/null | tr -d '='

# is a path ignored by git and by the agent?
git check-ignore -v .env secrets/api.key
grep -nE '^(\.env|secrets/|\*\*/secrets/)' .codebuffignore

# is anything secret already tracked? (names only)
git ls-files | grep -iE '\.(env|key|pem|p12|pfx)$|secret|credential' || echo "clean"
```

## When a task needs a credential
Do not ask for the value. Ask the human to export it in their shell, then reference it by
name. If an MCP server needs it, note that `mcp.json` supports `$VAR` references — and that
a **missing** variable makes Freebuff skip that entire `mcp.json`, so tell the user to
export it before launching.

## Freebuff trust model, in one line
Cloning a repo does not run its `.agents/mcp.json` or `.agents/*.ts` without a prompt that
shows the exact commands — but **`.agents/skills/*/SKILL.md` loads with no prompt at all**,
so never install skills from a repository you have not read.
