# MCP layer (opt-in, read-only by default)

**Read this before enabling anything here.** Freebuff's warning at the trust prompt:
*"These run with your permissions and can read your environment."*

## Two facts that decide this whole design

1. **A missing `$VAR` drops the entire `mcp.json`** — not one server. Export every variable
   in your shell *before* launch.
2. **MCP config is trust-gated.** First run asks `Load and run these? [y/N]` with exact
   command lines. Skills are *not* gated; `mcp.json` and `.agents/*.ts` are.

## What this pack ships

| Fragment | What it starts | Writes? | Notes |
|---|---|---|---|
| `local-readonly.json` | `mcp/local-readonly/server.js` — 10-tool bridge: Navidrome read, Lidarr health/queue/wanted, slskd session/server, MusicBrainz search/lookup | **No.** GET only, host-allowlisted | The safe default. Cannot change state by construction. |

```bash
./install.sh --project . --mcp local-readonly
```
Use a **ReadOnly** slskd key. Installer substitutes its absolute path (`__PACK_DIR__`);
**re-run the installer if you move the pack.**

## Third-party servers: risk-ranked shortlist

**Verify each project's own README before use** — no unverified package names hardcoded here.

| Server | Good for | Risk |
|---|---|---|
| MusicBrainz MCP | read-only metadata lookups | **Low** |
| Last.fm MCP | history/taste analysis | **Low**; higher with Spotify writes |
| Navidrome MCP | search, playlists, ratings, queue | **High with writes on** |
| *arr MCP | list/search/queue/indexer health | **High** — can add artists, trigger searches |
| slskd bots | resolve → search → download | **Very high** — moves files |

Rules: prefer read-only tools; least-privilege credentials, never admin key;
**never expose beyond localhost**; context cost is real — leave out what you don't use.

## Skill vs MCP vs CLI

- **Skill** — procedure. ~100 tokens metadata until used. Default carrier here.
- **CLI** (`curl`, `flac -t`, `beet --pretend`) — mechanical work: small output, real exit codes.
- **MCP** — structured output you'll use often, or no-CLI services. Narrow servers only.
