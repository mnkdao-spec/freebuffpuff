# Your 10-minute checklist (Phase 0b)

The sandbox probe verified the CLI's mechanics. These four things can only be checked on **your**
machine, signed in, with your services running. Tick them off; anything that fails just moves the
corresponding pack tier to "disabled" — nothing else depends on it.

## Setup
```bash
cd <the repo where you installed the pack>
./install.sh --project . --dry-run      # confirm it sees your skills
./install.sh --project .                # install (idempotent; never overwrites)
freebuff                                 # answer y at the trust prompt ONLY if you read mcp.json
```

## 1. Does the agent read `knowledge.md`?
Type: `Without reading any file, tell me: what is our library root path, and what are you never
allowed to touch?`
- [ ] It answers from `knowledge.md` (the hard rules + your `<EDIT>`-filled paths).
- [ ] If it does not, your `<ANGLE BRACKETS>` may still be unfilled — those are yours to fill.

## 2. Do skills load, and does one auto-select?
Type: `/skill:` — the autocomplete should list 25 skills (or however many you installed).
- [ ] The list appears.
Then run the real test, which is *automatic* selection:
`A Lidarr album is stuck in the queue and will not import. Diagnose it, read-only.`
- [ ] It uses `music-lidarr-match-doctor` (or at least mentions the release-group MBID trap and the
      similarity thresholds) without you naming the skill.
- [ ] If it does not auto-select, invoke explicitly with `/skill:music-lidarr-match-doctor`. A skill
      that needs naming is a *description* problem — tighten the description, and tell me.

## 3. Are your local APIs reachable from inside the project directory?
```bash
curl -s "http://localhost:4533/rest/ping?u=$ND_USER&t=$ND_TOKEN&s=$ND_SALT&v=1.16.1&c=agent&f=json"
curl -s -H "X-Api-Key: $LIDARR_API_KEY" http://localhost:8686/api/v1/health | head -c 400
curl -s -H "X-API-Key: $SLSKD_API_KEY"  http://localhost:5030/api/v0/server | head -c 400
```
- [ ] All three answer from your shell. (They will, if your shell can reach them — but confirm the
      ports and that the tokens are exported, because **a missing `$VAR` silently disables the whole
      `mcp.json`**.)
- [ ] Ask the agent: "using only read-only calls, list Lidarr's health warnings." It should use the
      CLI or the `localReadonly` MCP tools, and change nothing.

## 4. Desktop parity (only if you use Freebuff Desktop)
- [ ] Open the same repo in Desktop and check that the same skills appear (`/skill:`).
- [ ] Confirm Desktop also shows the trust prompt for `.agents/mcp.json` on first run.
- [ ] If Desktop sees a *different* set, note which surface missed what — that is a real limitation to
      report, not something to work around.

## 5. Optional: the risky tier
- [ ] Copy `agents/*.ts` into `.agents/` (and `agents/types/agent-definition.d.ts` into
      `.agents/types/`), restart, then type `@` — the display names `Repo Cartographer`, `Verifier`
      and `Library Auditor` should autocomplete. **This is the tier that was not verifiable in the
      sandbox.** If they do not appear, delete `.agents/*.ts`; you lose only this tier.

## What to send back
Anything that failed, plus:
- the output of `/skill:` (which skills were listed),
- which model was selected (`/model`),
- whether the trust prompt appeared and what it listed.

That is enough to fix the pack against the real thing rather than against the docs.
