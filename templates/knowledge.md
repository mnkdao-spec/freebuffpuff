# Homelab: music stack + personal knowledge base

> Keep this file short. It is loaded into every session. Procedures belong in
> `.agents/skills/`; this file holds only facts the agent cannot infer.

## What this repo is
Declarative config for a self-hosted music stack and a personal knowledge base.
<EDIT: one line — "this is the repo I run my Docker Compose stack from", or "this is my
fork of Navidrome", etc. Say which.>

## Services (host <EDIT: hostname/ip>, Compose project `<EDIT>`)
| Service | Role | Port | Config file |
|---|---|---|---|
| Navidrome | music server (Subsonic/OpenSubsonic API) | <EDIT 4533> | `navidrome/navidrome.toml` |
| Lidarr | library manager (MusicBrainz release groups) | <EDIT 8686> | `lidarr/config.xml` |
| Prowlarr | indexer manager, syncs indexers to Lidarr | <EDIT 9696> | `prowlarr/config.xml` |
| slskd | Soulseek client (REST API `/api/v0`) | <EDIT 5030> | `slskd/slskd.yml` |
| <EDIT: beets / Feishin / Owntone / etc.> | | | |

## Paths (host -> container). Change these and the docs are wrong, so change them here.
- Library root: `<EDIT /srv/media/media/Music>` -> `/data/media/Music` in containers
- Download/staging: `<EDIT /srv/media/downloads/soulseek>` -> `/data/downloads/soulseek`
- Config/appdata: `<EDIT /srv/media/appdata>`
- Agent scratch (reports, staging, backups — the ONLY place agents write): `<EDIT ~/music-lab-work>`
- Knowledge base vault: `<EDIT ~/vault>` (notes are plain Markdown; `_inbox/` is the only
  folder an agent may write to, and only with `status: draft` frontmatter)

## Exact commands — use these, do not invent them
```bash
docker compose config -q                     # validate compose (syntax only, not runtime)
docker compose ps                            # what is actually up
curl -s "http://localhost:4533/rest/ping?u=<EDIT>&t=<EDIT>&s=<EDIT>&v=1.16.1&c=agent&f=json"
curl -s -H "X-Api-Key: $LIDARR_API_KEY" http://localhost:8686/api/v1/health
curl -s -H "X-API-Key: $SLSKD_API_KEY"   http://localhost:5030/api/v0/session
beet -c beets/config.yaml import --pretend <dir>   # never run a real import unattended
flac -t <file>                               # integrity check (does NOT prove lossless origin)
ffprobe -v error -show_entries format=format_name,bit_rate -of json <file>
```
Credentials live in `<EDIT .env>`. Never print them. They are in `.gitignore` and
`.codebuffignore`; do not read, echo, or copy them into a prompt, a report, or a commit.

## Hard rules
1. **Never write to the music library** (`media/Music`) or to the vault's permanent notes.
   Report first; produce a patch or a dry-run command the human applies.
2. **Never delete or move anything.** No `rm`, no `beet move`, no `*-clean`, no
   `duplicates --delete`, no bulk rename, no `docker compose down -v`.
3. **Never mutate service state** (add artists, trigger searches, delete playlists, change
   settings) without an explicit instruction in that message. Read-only by default.
4. **Never switch Lidarr to a nightly/develop branch or install a Lidarr plugin.** Plugin
   support needs a different branch and a DB schema change; that is a human decision.
5. Run one bounded task per turn, then stop. Write findings to
   `<scratch>/reports/YYYY-MM-DD-<topic>.md` and link them here in your reply.
6. Anything that touches tags, paths, or metadata: **preview with a dry run and state the
   exact command** before proposing a real run.
7. Do not paste secrets, `.env` contents, API keys, or full personal notes into a prompt.
   Freebuff prompts may be analysed to personalise ads and some models retain submissions.

## Verification habits
- Read-only probe first (`docker compose ps`, `*/health`, `flac -t`, `beet --pretend`).
- State what you did NOT verify. "It should work" is not a result.
- Cite the file and line for every claim about config.

## Where the procedures live
`.agents/skills/` — run `/skill:` in the TUI to list them. Notable:
- `music-stack-map`, `music-lidarr-match-doctor`, `music-path-and-hardlink-doctor`
- `music-navidrome-tagging-doctor`, `music-navidrome-nsp-author`, `music-slskd-ops`
- `music-musicbrainz-lookup`, `music-beets-preview`, `music-library-audit`
- `core-verify-loop`, `core-plan-then-build`, `core-handoff`, `core-secrets-hygiene`
- `pkm-*` for the knowledge base
