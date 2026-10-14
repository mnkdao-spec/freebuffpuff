# 07 — Release day (site + announcement + library)

For the day a release goes live. Verify in order; stop at the first failure rather than announcing
anything broken.

```
Release: <title / slug>  Date: <YYYY-MM-DD>

1. Build the real artefact, not the dev server.
   - npm ci && npm run build     (state the exit code)
2. Audit the output:
   - bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict
   - Fix every FAIL. Decide deliberately on each WARN.
3. Check the release page specifically:
   - stable URL, artwork with width/height and real alt text
   - per-page OG tags, og:image an ABSOLUTE url
   - JSON-LD of the right type with its required properties (MusicAlbum: name, byArtist)
   - tracklist, credits, and every provider link resolving
   - the feed and sitemap contain it
4. Deploy atomically (new release directory, symlink swap). Never rsync --delete into the live dir.
5. Verify the deployment, not the deploy command:
   - bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --url https://<domain> --strict
   - the live:hash check must match the build
   - unknown paths return a real 404
   - if HTML is cached at a CDN, purge it now - otherwise the old page is what people see
6. Announce: newsletter + feed + socials, one primary CTA to the release or /listen/<slug>/.
7. Music side, if the release also lands in the library:
   - Lidarr import is not complete until Navidrome shows it (move, scan, then retag if needed and
     scan again - never both at once)
   - verify from a client, on a phone, not just in the web UI

Report: what is live and verified | what is still pending | anything that failed with the exact
command and output. Do not describe a step as done because the command exited 0.
```
