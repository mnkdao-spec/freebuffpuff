---
name: web-selfhost-deploy
description: Deploy and roll back the music project's website on a self-hosted box - Caddy or Traefik with automatic TLS, DNS and Cloudflare considerations, atomic release directories with a symlink swap, deployment from CI over restricted SSH, cache purging on release, and how to verify the deployed artefact is the one you built. Use when publishing a new version, when TLS or routing breaks, when a release "did not appear", when setting up deploys from GitHub Actions, or when restoring a previous version.
metadata:
  category: web
---

# Self-hosted deploys

## Topology that keeps this simple
```
GitHub Actions (build + test)            or    your laptop (npm run build)
        |                                                   |
        +----------- rsync/scp over restricted SSH ----------+
                              |
                    LXC 121: Caddy  ──serves──>  /srv/site/current -> releases/<sha>
                              ^
                    80/443 from the internet (or a Cloudflare Tunnel; see proxmox-service-exposure)
```
- **Caddy** for one site: a short Caddyfile, automatic HTTPS and renewal. Ordinary ACME needs
  80/443 reachable from the internet; **wildcard certs need DNS-01** and a Caddy build that
  includes your DNS provider module.
- **Traefik** if routes should be declared with the Docker services. Either way, keep the Docker
  socket away from anything unnecessary and keep credentials out of labels.
- A static site needs **no Node runtime in production**. Ship files, not a server.

## Atomic deploys (the only part that matters under load)
```bash
# on the server, once
install -d -o deploy -g deploy /srv/site/releases /srv/site/incoming
# each deploy: build -> upload to a NEW directory -> validate -> swap
rsync -a --delete ./dist/ deploy@srv:/srv/site/incoming/$SHA/
ssh deploy@srv 'set -e; test -f /srv/site/incoming/'"$SHA"'/index.html; \
  mv /srv/site/incoming/'"$SHA"' /srv/site/releases/'"$SHA"'; \
  ln -sfn /srv/site/releases/'"$SHA"' /srv/site/current.new && \
  mv -T /srv/site/current.new /srv/site/current'
```
Why: a visitor mid-page-load must never see a half-copied directory, and the symlink swap is
atomic on the same filesystem. **Never `rsync --delete` straight into the live directory.** Keep
the previous 2-3 releases for rollback and keep old fingerprinted assets around long enough for
open pages to finish.

Rollback is then one command:
```bash
ssh deploy@srv 'ln -sfn /srv/site/releases/<previous-sha> /srv/site/current.new && mv -T /srv/site/current.new /srv/site/current'
```

## CI notes
- Building on a **hosted runner** and uploading the artefact is the safe default. A **self-hosted
  runner executes repository code on your infrastructure** - keep it to trusted repos, minimise
  token permissions, and never run untrusted pull-request code on it.
- Make the deploy step fail closed: verify `index.html` exists in the uploaded directory before
  swapping, and run the site audit **before** uploading.
- **Watchtower is not a deployment mechanism** for static files - it replaces containers, and it
  can interrupt service while doing so.

## Caching, DNS and "the release did not appear"
- Cloudflare's default cache covers common static extensions but **not HTML**. If you add a Cache
  Rule that caches HTML, **purge on release day** or you will serve yesterday's release page.
  Long-lived caching belongs on fingerprinted assets, not on HTML.
- Point DNS at your public IP and forward only 80/443 to the proxy, or use a **Cloudflare Tunnel**
  so nothing needs to be forwarded at all. If Cloudflare proxies the record, check the
  origin-encryption mode rather than assuming HTTPS is end-to-end.
- After a release: purge the cache, then verify the live page - not just that the deploy succeeded.

## Verification (do this, do not assume)
```bash
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --url https://your-domain --strict
curl -sSI https://your-domain/releases/<slug>/ | head -5      # 200, text/html
echo | openssl s_client -connect your-domain:443 -servername your-domain 2>/dev/null | openssl x509 -noout -dates
ssh deploy@srv 'readlink -f /srv/site/current'                 # which release is live
```
The audit's `live:hash` check compares the served bytes with your local build - it is the fastest
way to catch a stale deploy or an aggressive cache.

## Hard rules
- No secrets in the repo or the build output; server-side secrets live in a root-owned env file or
  the service's own store, never in the site directory.
- No `chmod 777`, no running the deploy as root, no shared SSH key for everything.
- Do not publish from an unverified build. `site-audit.sh --strict` gates on leaked files and
  invalid structured data for a reason.
- Report "deployed" and "verified live" as **different** states.
