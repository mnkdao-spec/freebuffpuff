---
name: web-selfhost-deploy
description: Deploy and roll back the website on a self-hosted box - Caddy/Traefik with TLS, DNS and Cloudflare considerations, atomic release dirs with symlink swap, CI over restricted SSH, cache purging, verifying the deployed artefact matches the build. Use for publishes, TLS/routing breakage, missing releases, GitHub Actions deploys, or rollbacks.
metadata:
  category: web
---

# Self-hosted deploys

Build on runner/laptop → rsync/scp over restricted SSH → LXC 121 Caddy → `/srv/site/current`
→ `releases/<sha>`. Static = **no Node runtime in prod**; ship files, not a server.
Caddy: short Caddyfile + auto-HTTPS (wildcards need DNS-01 + provider module). Traefik: routes
via labels (protect socket; keys out of labels).

## Atomic deploys (the part that matters)
Build → upload to NEW dir → validate (`index.html` exists) → symlink swap (`mv -T`, same
filesystem = atomic). **Never `rsync --delete` into live.** Keep 2-3 previous releases;
keep old fingerprinted assets for open pages. Rollback = one symlink command.

## CI notes
Hosted runner + artefact upload = safe default. Self-hosted runners execute repo code on your
infra (trusted repos only, minimal tokens, never untrusted PR code). Fail closed (verify before
swap; audit **before** upload). **Watchtower ≠ static deploy mechanism.**

## Caching/DNS/"didn't appear"
Cloudflare default cache skips HTML; HTML-caching Cache Rules need **release-day purges**.
Long cache = fingerprinted assets only. DNS → public IP, forward 80/443 only — or **Tunnel**
(no forwarding; check origin-encryption mode). After release: purge, then verify live (not just
deploy success).

## Verify (do, don't assume)
`site-audit.sh dist --url <domain> --strict` (`live:hash` catches stale deploys/caches) +
status/headers curl + TLS dates + `readlink` live target.

## Hard rules
No secrets in repo/build (server secrets in root-owned env/service store). No 777/root deploys/
shared keys. No unverified-build publishes. "Deployed" ≠ "verified live" — report separately.
