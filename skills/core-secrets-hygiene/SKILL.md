---
name: core-secrets-hygiene
description: Handle credentials safely in a repository that contains API keys, .env files and private data - read variable names instead of values, avoid printing or committing secrets, use placeholder examples, and know what Freebuff itself can and cannot be trusted with. Use before reading config, when a task involves an API key or token, when adding a new integration, or when auditing a repo that may contain secrets.
metadata:
  category: core
---

# Secrets hygiene

Treat every prompt as potentially public. `docs/threat-model.md` has the full picture.

## Rules
1. **Never read or print secret values.** Not `.env`, `*.key`, `config.xml` keys, `slskd.yml`
   credentials. Read `.env.example`, or `grep -o '^[A-Z_]*=' .env` for names only.
2. **Never echo a key** into a command, report, or commit. Use the environment.
3. **Never commit** `.env`, key files, or token-bearing configs. Check `.gitignore` first.
4. **Placeholders in examples.** `your-token-here`, never real-looking values.
5. If a secret was already printed, say so and recommend rotating it.

## Checking a repo without exposing it
```bash
grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' .env 2>/dev/null | tr -d '='
git check-ignore -v .env secrets/api.key
git ls-files | grep -iE '\.(env|key|pem|p12|pfx)$|secret|credential' || echo "clean"
```

## When a task needs a credential
Don't ask for the value. Ask the human to export it, then reference by name. Note
`mcp.json` `$VAR` references — and that a **missing** variable skips the whole file.

## Trust model, one line
`.agents/mcp.json` and `.agents/*.ts` prompt with exact commands — but
**`.agents/skills/*/SKILL.md` loads with no prompt**, so never install unreviewed skills.
