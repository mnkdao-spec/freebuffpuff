---
name: music-navidrome-plugin-dev
description: Build, test and review a Navidrome WASM plugin - scaffold the manifest and exported capability functions, keep permissions minimal, build the .ndp package, and use the plugin CLI to validate and load it. Use when adding a metadata agent, scrobbler, lyrics provider, sonic-similarity provider or scheduled task to Navidrome, or when reviewing a downloaded plugin before enabling it.
metadata:
  category: music
  stack: navidrome, wasm, extism
---

# Navidrome plugin development

Navidrome plugins are **`.ndp` ZIP packages** containing `manifest.json` and a compiled
`plugin.wasm`, sandboxed through Extism/WebAssembly. The README demonstrates Go with TinyGo,
but any Extism PDK language works.

## Structure
```
myplugin.ndp            (zip of the two files below, at the archive root)
manifest.json           name, author, version required; description, website,
                        plugin configuration schema + UI schema, permissions optional
plugin.wasm             exports the functions for each capability you implement
```
**The filename determines the plugin ID**, not the display name in the manifest.

## Capabilities vs permissions — they are different things
Capabilities are discovered from the **exported functions**: metadata agents (artist/album
info, biographies, images, similar artists/songs, top songs), scrobblers (authorize,
now-playing, scrobble, playback report), lyrics providers, sonic-similarity providers, task
workers, scheduler callbacks, lifecycle init, and websocket event callbacks.

Permissions are declared in the **manifest** and granted/configured by an **administrator**:
HTTP (with an allowlist of hosts), WebSocket, scheduler, cache, persistent KV store, storage,
task queue, library access, matcher, artwork URLs, internal Subsonic API access, user access,
scrobble-history retrieval.

Rules that follow from that split:
1. **Request only what you need.** A scrobbler needs user permission; reading library files
   needs the library permission. An admin who reads the permission list should be able to say
   "yes, that is all it needs".
2. **Network allowlists are enforced, including private/loopback targets.** Calling a service
   on your LAN requires an explicit IP/CIDR entry — do not assume localhost works.
3. **Metadata agents must return empty/no-error for "no match"**, and reserve errors for real
   failures such as an unavailable upstream API. Returning an error for a miss can make the
   host retry misses.

## Build and test loop
```bash
make setup && make build            # in the navidrome repo, for a dev server
# navidrome.toml: small test MusicFolder + DevAutoCreateAdminPassword
make dev
# plugins: enable auto-reload and plugin logging during development, then:
navidrome plugin validate <file>.ndp
navidrome plugin info     <plugin-id>
navidrome plugin rescan   <plugin-id>     # metadata-agent changes
navidrome plugin enable   <plugin-id>
```
Put development plugins in `Plugins.Folder`. Enable `Plugins.AutoReload` to iterate without
restarting. Add plugin log output to your diagnosis instead of guessing.

## Reviewing someone else's plugin before enabling it
You are about to run third-party code with real permissions. Check: the exported functions
against the capabilities they claim; the permission list against what the code appears to do;
any HTTP host allowlist entries; whether it reads library files; and whether it stores
credentials. If you cannot read the source, say so and recommend a sandbox — this is a
supply-chain decision, not a config tweak.

## Contribution note
Navidrome's contribution guide asks for: an existing or new issue first, no duplicate PRs,
a branch, conventional commits, **DCO sign-off** (`git commit --signoff`), and the issue linked
in the PR. Support questions go to the discussion forum, not the issue tracker. There was no
published AI/LLM policy at the time of writing — that is not permission to skip review, and it
does not guarantee a maintainer will accept a generated PR. Your contribution must be tested,
understood and defensible. Checks: `make test`, `make test-race`, `make lintall`, `make pre-push`.

## Output format
```
PLUGIN:      id (from filename), capability being added, required permissions
SCAFFOLD:    files created/modified, one line each
BUILD:       exact command -> result
LOAD:        validate/info/rescan/enable output, verbatim
BEHAVIOUR:   the observed effect on the dev instance
PERMISSIONS: why each one is needed; what you deliberately did NOT request
NOT VERIFIED: what you could not exercise (e.g. required a real external API)
```

## Never
- Request broad permissions (whole-library access, arbitrary HTTP) to save time.
- Enable an unreviewed third-party plugin on a production instance.
- Add a plugin as a workaround for a tagging or path problem — fix the data instead.
