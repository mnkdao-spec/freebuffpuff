# Runbook: the artist website

## Health
```bash
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --url https://<domain>
readlink -f /srv/site/current
systemctl status caddy --no-pager | head -20
```

## Deploy
1. `npm ci && npm run build` (exact package.json script). 2. `site-audit.sh dist --strict` — fix FAILs.
3. Upload to `/srv/site/releases/<sha>/`, swap `current` symlink atomically (`mv -T`).
4. Verify live: `--url`, `live:hash` match, real 404, purge CDN cache if HTML cached.
5. Keep previous 2-3 releases as rollback.

## Roll back
Swap `current` symlink to previous sha; verify with `--url` audit; roll the cache back too.

## Release "did not appear"
Suspicion order: CDN/HTML cache > wrong symlink target > stale upload > never in build > DNS/proxy.

## TLS/routing broke
Check DNS/port reachability, then `journalctl -u caddy`. Never disable HTTPS to "fix" TLS.

## Audience side
Signups/bounces/unsubscribes live with the provider — check after sends. Sending-API keys stay
server-side, never in repo or build output.
