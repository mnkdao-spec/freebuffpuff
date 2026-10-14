# MCP layer (opt-in, read-only by default)

**Read this before enabling anything here.** Freebuff's own warning, shown at the trust prompt, is:
*"These run with your permissions and can read your environment."*

## Two facts that decide this whole design

1. **A missing `$VAR` makes Freebuff drop the entire `mcp.json`** — not just that one server.
   Every variable referenced in a `mcp.json` must be exported in your shell *before* launch.
2. **MCP config is trust-gated.** The first run in a repo asks `Load and run these? [y/N]` and
   prints the exact command lines it would start. `.agents/skills/*` is *not* gated this way, but
   `mcp.json` and `.agents/*.ts` are. Non-interactive runs skip untrusted dirs entirely.

## What this pack ships

| Fragment | What it starts | Writes? | Trust needed | Notes |
|---|---|---|---|---|
| `local-readonly.json` | `mcp/local-readonly/server.js` — our own 10-tool bridge: Navidrome read, Lidarr health/queue/wanted, slskd session/server, MusicBrainz search/lookup | **No.** GET only, host-allowlisted, no filesystem, no shell | yes (it's `mcp.json`) | The safe default. Nothing in it can change state by construction. |

Install it with:

```bash
./install.sh --project . --mcp local-readonly      # writes .agents/mcp.json
export ND_USER=... ND_TOKEN=... ND_SALT=... LIDARR_API_KEY=... SLSKD_API_KEY=... \
       MB_USER_AGENT="freebuff-homelab-pack/1.0 (you@example.com)"   # put these in ~/.bashrc
# Optional, both for tightening/testing rather than normal use:
#   MB_URL=https://musicbrainz.example.org      # a MusicBrainz mirror
#   MCP_ALLOWED_HOSTS=music.lan:4533,mb.lan     # replaces the derived host allowlist entirely
```
Use a **ReadOnly** slskd API key here. The installer substitutes its own absolute path into the
fragment (`__PACK_DIR__`), so **if you move the pack directory, re-run the installer**.

### What "read-only" is enforced to mean

The bridge is not read-only because its tool list looks harmless. Four properties are enforced in
code, and the two a real homelab can never exercise are asserted against a local fixture by
`tests/run.sh`:

| Property | Enforced by | Proven by |
|---|---|---|
| only `GET` is ever issued | one `fetch()` call site, hardcoded `method: 'GET'`, `redirect: 'error'` | `tests/invariants.sh` compares the call sites |
| every request is built through the allowlist | `httpGet()` resolves the URL via `assertAllowed()` | `tests/invariants.sh` + a refusal that must open **no** socket |
| response size is bounded | the body is read in chunks and the stream cancelled at 6000 bytes | `tests/run.sh`: a 20 MiB body is cut and ~0.6 MB reaches the wire |
| upstream failures are errors | any non-2xx response throws, so the call returns `isError` | `tests/run.sh`, against a fixture that answers `500` |

`MCP_ALLOWED_HOSTS` replaces the derived allowlist outright. That is what makes the refusal path
reachable at all (`MCP_ALLOWED_HOSTS=example.invalid` must refuse every tool), and it is how you
tighten the list after moving a service behind a proxy. Search terms sent to MusicBrainz are escaped
as Lucene phrases, so a quote in an artist name cannot rewrite the query into something else and
return silently wrong results.

## Third-party servers: a risk-ranked shortlist

These are real, community-maintained projects. **Verify the package/launch command from each
project's own README before use** — this pack deliberately does not hardcode npm package names it
has not verified.

| Server | Good for | Risk |
|---|---|---|
| MusicBrainz MCP (`zas/mcp-musicbrainz`) | read-only metadata lookups, local caching | **Low** — query only |
| Last.fm MCP (`sptmru/lastfm-mcp`) | listening history and taste analysis | **Low by default**; higher if you enable Spotify writes |
| Navidrome MCP (`Blakeem/Navidrome-MCP`) | library search, analytics, playlists, ratings, queue, playback | **High with write tools on** — it can edit playlists, ratings, favourites, saved queue |
| *arr MCP (`aplaceforallmystuff/mcp-arr`) | Lidarr/Prowlarr: list artists/albums, search, queue, indexer health | **High** — it can add artists and trigger searches, i.e. cause downloads |
| slskd bots (`GeiserX/telegram-slskd-local-bot`) | resolve → search → download workflows, library sweeps | **Very high** — transfers files and can modify your library |

Rules if you add one:
- Prefer read-only tools; if a server exposes both, configure it to expose only reads.
- Use a least-privilege credential, and never the admin key.
- **Never expose a local MCP/HTTP endpoint beyond localhost.** These interfaces hold credentials
  and control downloads.
- Context cost is real: a handful of servers can consume tens of thousands of tokens of tool
  schemas before any work starts. If you are unsure something is needed, leave it out and use the
  CLI instead.

## Skill vs MCP vs CLI — when to use which

- **Skill** — instructions and procedure. Costs ~100 tokens of metadata until used. This is the
  pack's default carrier for knowledge.
- **CLI** (`curl`, `docker compose config -q`, `flac -t`, `ffprobe`, `beet --pretend`) — best for
  mechanical work: small output, verifiable exit codes, no trust prompt. Preferred here.
- **MCP** — worth it when a tool call needs structured output and you will use it often, or when a
  service has no CLI. Pay for it with a narrow server, and re-read the trust prompt the first time.
