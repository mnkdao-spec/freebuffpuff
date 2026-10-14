---
name: web-release-page
description: Build or check a release page and its "listen" smart-link page for a music project - stable URLs, artwork, credits, tracklist, provider links, embedded players without hurting performance or privacy, per-page Open Graph, and safe private pre-release streaming (scoped Navidrome share or a separate preview store, never exported credentials). Use on release day, when adding a new release or single, when setting up a pre-save or pre-release stream, or when a release page needs to be announced.
metadata:
  category: web
---

# Release pages and smart links

## What a release page needs (check every item)
- **A stable URL** you will not change: `/releases/<slug>/` (and, if you want a link-in-bio
  replacement, `/listen/<slug>/`).
- Title, release date, the format list, and a **short** description in your own words.
- **Artwork**: correct aspect ratio, sized variants (`srcset`), explicit `width`/`height` to avoid
  layout shift, and real alt text.
- Tracklist with durations, credits, and (if you have them) ISRCs.
- Links to everywhere it actually is: Bandcamp, streaming services, your own store. One prominent
  primary, the rest secondary.
- Per-page Open Graph and JSON-LD (`web-structured-data`).
- An entry in the journal/feed and the sitemap, so a release is discoverable and subscribable.

## Owned smart links instead of a third-party landing page
Your `/listen/<slug>/` page should list the direct provider links plus a purchase option. Reasons:
you keep the traffic and the analytics, the page stays up if a service changes, and it works
without an account. A third-party smart-link service is a convenience, not a foundation - and its
terms/pricing change without asking you.

## Players: lazy, facades, no autoplay
- Assume **any third-party iframe contacts its provider** and can disclose visitor request data.
  Lazy-load players below the fold, or show a lightweight "Play" facade that loads the iframe only
  on interaction.
- **Reserve the player's dimensions** or it will wreck CLS.
- **Never autoplay.**
- If you self-host preview audio, keep files small, serve them from your own domain, and preserve
  byte-range support so seeking works.

## Private pre-release streaming - the safe patterns
Ranked, safest first:
1. **A separate preview store** on your own domain (small MP3s in an unguessable directory,
   noindex, not linked). Simplest, exposes nothing else, easy to delete after release day.
2. **Navidrome's share feature** - a link to selected tracks or albums rather than access to the
   library. Be precise about what it is: the current docs describe a share as an **unauthenticated
   public link**, with no documented password or recipient check. So it is *unguessable*, not
   *private* - the URL is the only secret. Send it individually, set an expiry, and expect that
   anyone who has the URL can listen. If the preview genuinely needs authentication, use pattern 1
   or 3 instead.
3. A **dedicated, narrowly-scoped library user** behind a server-side proxy with an allowlist and
   rate limiting.

Never: an admin account in browser code, an API token that can enumerate the collection, or direct
public exposure of your Navidrome instance. The Subsonic API surface plus open signup is a bad
combination, and a token shipped to a browser is public the moment it ships.

## Release-day procedure
```bash
npm run build                                   # the artefact, not the dev server
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict
curl -sS https://your-domain/releases/<slug>/ | grep -iE 'og:|application/ld\+json|<title>' | head
curl -sSI https://your-domain/releases/<slug>/  # 200, text/html, and the right cache headers
```
Then: check the page on a phone, confirm the feed/sitemap contain the release, click every provider
link, and - if you cache HTML in Cloudflare - **purge the cache or the release will not appear**
(HTML is not cached by default; if you enabled caching, this is on you). Send the announcement
after the page is verified, not before (`web-audience-and-email`).

## Hard rules
- Do not publish lyrics or full tracks you have no right to publish. Previews only, and only of
  your own material.
- Do not expose your library or an admin credential to make a preview work.
- Do not report a release as live until the page, the links, the OG tags and the feed are verified
  from the public URL.
