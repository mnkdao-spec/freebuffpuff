# Runbook: the artist website

## Health
```bash
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --url https://<domain>
curl -sSI https://<domain>/ | head -5
readlink -f /srv/site/current                       # which release is live
systemctl status caddy --no-pager | head -20
echo | openssl s_client -connect <domain>:443 -servername <domain> 2>/dev/null | openssl x509 -noout -dates
```

## Deploy a new version
1. `npm ci && npm run build` (exact command from package.json; never a guessed script).
2. `bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict` - fix FAILs first.
3. Upload to `/srv/site/incoming/<sha>/`, verify `index.html` exists, then move into
   `/srv/site/releases/<sha>/` and swap the `current` symlink atomically (`mv -T`).
4. Verify live: `--url`, check `live:hash` matches, check a real 404, purge CDN cache if HTML is cached.
5. Keep the previous 2-3 releases; that is your rollback.

## Roll back
```bash
readlink -f /srv/site/current                       # confirm what is live now
ln -sfn /srv/site/releases/<previous-sha> /srv/site/current.new && mv -T /srv/site/current.new /srv/site/current
```
Then verify with the audit's `--url` mode. Roll the cache back too, or the "fixed" version will not
be what visitors get.

## The release "did not appear"
Order of suspicion: CDN/HTML cache (purge, then re-check) > symlink points at the wrong release >
the build on the server is an older upload > the page was never in the build > DNS/proxy in front.

## TLS/routing broke
- Certificates renew automatically; a failure is usually DNS or a port that stopped being
  reachable (80/443 for HTTP-01, or the DNS-01 credentials for a wildcard).
- Caddy's own logs first: `journalctl -u caddy -n 100 --no-pager`.
- Never "fix" TLS by turning off automatic HTTPS or by skipping verification in the client.

## Audience side
Newsletter signups, bounces and unsubscribes live with the provider - check them after any send
rather than assuming delivery. Key material for any sending API stays server-side, never in the
site repo or the build output. See `web-audience-and-email`.
