# 07 — Release day (site + announcement + library)

Verify in order; stop at first failure before announcing anything broken.

```
Release: <title/slug> Date: <YYYY-MM-DD>
1. Build real artefact: npm ci && npm run build (exit code).
2. Audit: site-audit.sh dist --strict. Fix every FAIL; decide each WARN.
3. Release page: stable URL, sized artwork + alt, per-page OG (absolute og:image),
   valid JSON-LD (MusicAlbum: name, byArtist), tracklist/credits/working provider links, feed+sitemap entry.
4. Deploy atomically (new dir + symlink swap). Never rsync --delete into live.
5. Verify deployment (not the deploy command): --url audit, live:hash match, real 404,
   purge CDN cache if HTML cached.
6. Announce: newsletter + feed + socials, one CTA to release or /listen/<slug>/.
7. Library side: Lidarr import isn't done until Navidrome shows it (move, scan, retag+scan —
   never both at once); verify from a client on a phone, not just web UI.

Report: live+verified | pending | failures (exact command + output).
A step isn't done because the command exited 0.
```
