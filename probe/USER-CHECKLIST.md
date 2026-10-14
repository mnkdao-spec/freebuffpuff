# Your 10-minute checklist (Phase 0b)

The sandbox probe verified the CLI's mechanics. These can only be checked on **your**
machine, signed in, with services running.

## Setup
```bash
./install.sh --project . --dry-run
./install.sh --project .
freebuff
```

## 1. Does the agent read `knowledge.md`?
Ask without reading any file: what is the library root, and what is never allowed?
- [ ] Answers from `knowledge.md`. - [ ] Else, `<ANGLE BRACKETS>` may be unfilled.

## 2. Do skills load / auto-select?
`/skill:` should list installed skills.
- [ ] List appears. Then: `A Lidarr album is stuck and will not import. Diagnose read-only.`
- [ ] Uses `music-lidarr-match-doctor` (or names the release-group MBID trap) unprompted.
- [ ] Else invoke `/skill:music-lidarr-match-doctor` explicitly (a description problem).

## 3. Are local APIs reachable?
```bash
curl -s "http://localhost:4533/rest/ping?u=$ND_USER&t=$ND_TOKEN&s=$ND_SALT&v=1.16.1&c=agent&f=json"
curl -s -H "X-Api-Key: $LIDARR_API_KEY" http://localhost:8686/api/v1/health | head -c 400
curl -s -H "X-API-Key: $SLSKD_API_KEY" http://localhost:5030/api/v0/server | head -c 400
```
- [ ] All three answer. (Missing `$VAR` silently disables the whole `mcp.json`.)
- [ ] Agent lists Lidarr health warnings read-only via CLI or `localReadonly` tools.

## 4. Desktop parity (if applicable)
- [ ] Same skills in Desktop (`/skill:`). - [ ] Trust prompt for `.agents/mcp.json`.
- [ ] Note any surface differences.

## 5. The risky tier (agents)
- [ ] `.agents/*.ts` present; `@` autocompletes the five display names after trust prompt.
- [ ] **If rejected/skipped, add the model** (docs list `model` as required; pack omits deliberately):
  ```bash
  MODEL='paste-the-id-from-/model'
  sed -i "s/^\\(\\s*displayName:.*\\)$/\\1\\n  model: '$MODEL',/" .agents/*.ts
  bash install.sh --verify
  ```

## 6. Proxmox scripts on your host?
```bash
bash .agents/skills/proxmox-stack-map/scripts/pve-doctor.sh
bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh <CT id> --paths /data/downloads:/data/media
```
- [ ] Findings (not crash); storage/guest lines match reality.
- [ ] `lxc-audit.sh --paths` agrees with `stat -c '%d'` inside containers.
- [ ] `python3` on host, or `PYTHON=` set.

## 7. Website audit vs your build?
```bash
npm ci && npm run build
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --url https://<domain>
```
- [ ] No false positives (esp. broken-internal-link reports).
- [ ] `live:hash` matched (or flagged genuinely stale deploy).

## What to send back
Failures + `/skill:` output + selected model (`/model`) + whether the trust prompt appeared.
