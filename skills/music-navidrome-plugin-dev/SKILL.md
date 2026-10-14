---
name: music-navidrome-plugin-dev
description: Build, test and review a Navidrome WASM plugin - scaffold manifest and capability functions, keep permissions minimal, build the .ndp package, validate with the plugin CLI. Use when adding a metadata agent, scrobbler, lyrics or similarity provider, scheduled task, or reviewing a downloaded plugin before enabling.
metadata:
  category: music
  stack: navidrome, wasm, extism
---

# Navidrome plugin development

`.ndp` ZIPs (`manifest.json` + `plugin.wasm`), Extism-sandboxed. Go/TinyGo demoed; any Extism PDK works.
**Filename = plugin ID**, not the manifest display name.

## Capabilities vs permissions (different things)
Capabilities come from **exported functions** (metadata agents, scrobblers, lyrics, similarity,
task workers, scheduler, lifecycle, websocket events). Permissions come from the **manifest**,
granted by an **admin**: HTTP allowlist, WebSocket, scheduler, cache, KV, storage, task queue,
library, matcher, artwork URLs, Subsonic API, user access, scrobble history.

1. **Request only what's needed.** 2. **Network allowlists enforced incl. private/loopback** —
   explicit IP/CIDR entries; localhost assumed nothing. 3. **Metadata agents: empty/no-error on
   "no match"**; errors only for real failures (miss-errors cause host retries).

## Build/test loop
`make setup && make build` (navidrome repo) → `navidrome.toml` test folder → `make dev`;
plugins in `Plugins.Folder`, `Plugins.AutoReload` on; `plugin validate/info/rescan/enable <id>`.

## Reviewing third-party plugins
Check exports vs claimed capabilities; permissions vs apparent behavior; HTTP allowlist;
library reads; credential storage. Can't read source → say so, recommend sandbox. Supply-chain decision.

## Contributions
Issue first, no dup PRs, branch, conventional commits, **DCO sign-off**. Forum for support,
not issues. No published AI policy at writing ≠ skip review. Test/lint: `make test`,
`make test-race`, `make lintall`, `make pre-push`.

## Output
```
PLUGIN / SCAFFOLD / BUILD (cmd → result) / LOAD (validate/info/enable verbatim) / BEHAVIOUR / PERMISSIONS (why each; what excluded) / NOT VERIFIED
```

## Never
Broad permissions to save time; unreviewed third-party plugins on prod; plugins as
workarounds for tag/path problems (fix the data).
