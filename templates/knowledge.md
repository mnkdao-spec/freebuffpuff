# Homelab: music stack + personal knowledge base

> Keep this file short. It is loaded into every session. Procedures belong in
> `.agents/skills/`; this file holds only facts the agent cannot infer.

## What this repo is
Declarative config for a self-hosted music stack and a personal knowledge base.
<EDIT: one line — say which repo this is.>

## Services (host <EDIT: hostname/ip>, Compose project `<EDIT>`)
| Service | Role | Port | Config file |
|---|---|---|---|
| Navidrome | music server (Subsonic/OpenSubsonic API) | <EDIT 4533> | `navidrome/navidrome.toml` |
| Lidarr | library manager (MusicBrainz release groups) | <EDIT 8686> | `lidarr/config.xml` |
| Prowlarr | indexer manager, syncs indexers to Lidarr | <EDIT 9696> | `prowlarr/config.xml` |
| slskd | Soulseek client (REST API `/api/v0`) | <EDIT 5030> | `slskd/slskd.yml` |

## Paths (host -> container)
- Library root: `<EDIT /srv/media/media/Music>` -> `/data/media/Music` in containers
- Download/staging: `<EDIT /srv/media/downloads/soulseek>` -> `/data/downloads/soulseek`
- Config/appdata: `<EDIT /srv/media/appdata>`
- Agent scratch (ONLY place agents write): `<EDIT ~/music-lab-work>`
- Vault: `<EDIT ~/vault>` (`_inbox/` is the only folder an agent may write to, as `status: draft`)

## Exact commands — use these, do not invent them
```bash
docker compose config -q
docker compose ps
beet -c beets/config.yaml import --pretend <dir>
flac -t <file>
ffprobe -v error -show_entries format=format_name,bit_rate -of json <file>
```
Credentials live in `<EDIT .env>`. Never print them. Never read, echo, or copy them
into a prompt, report, or commit.

## Hard rules
1. **Never write to the music library** or the vault's permanent notes. Report first.
2. **Never delete or move anything.** No `rm`, `beet move`, `duplicates --delete`,
   bulk rename, or `docker compose down -v`.
3. **Never mutate service state** without explicit instruction in that message.
4. **Never switch Lidarr branches or install plugins.** Human decision.
5. One bounded task per turn, then stop. Findings to `<scratch>/reports/`.
6. Tags/paths/metadata: **preview with a dry run** before proposing a real run.
7. No secrets or full personal notes in prompts.

## Verification habits
- Read-only probe first. State what you did NOT verify.
- Cite file and line for every config claim.

## Hypervisor
- PVE host `<EDIT>`; Docker guests `<EDIT>`. **Never install on the PVE host.**
- Host check: `bash .agents/skills/proxmox-stack-map/scripts/pve-doctor.sh`
- Guest: `bash .agents/skills/proxmox-guest-placement/scripts/lxc-audit.sh <id>`
- Not backed up: `<EDIT>`

## Website
- Repo `<EDIT>` · build `<EDIT>` · output `<EDIT dist/>` · served by `<EDIT Caddy>`
- Pre-ship: `site-audit.sh dist --strict`. Live: `... --url https://<EDIT domain>`.
- Atomic deploys only (new dir + symlink swap). Public surface: **website only.**
