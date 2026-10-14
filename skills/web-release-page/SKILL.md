---
name: web-release-page
description: Build or check a release page and its "listen" smart-link page - stable URLs, artwork, credits, tracklist, provider links, lazy players, per-page Open Graph, safe private pre-release streaming. Use on release day, new releases/singles, pre-saves, pre-release streams, or pre-announcement checks.
metadata:
  category: web
---

# Release pages and smart links

## Every release page needs
Stable URL (`/releases/<slug>/`, plus `/listen/<slug>/` as link-in-bio replacement); title/date/
formats/short description; **artwork** (sized `srcset`, explicit dimensions, real alt);
tracklist + durations + credits (+ISRCs); provider links (one primary, rest secondary);
per-page OG + JSON-LD; journal/feed + sitemap entries.

## Owned smart links
`/listen/<slug>/` with direct provider links + purchase option. You keep traffic/analytics/uptime;
survives service changes; no account needed. Third-party smart-links = convenience, not foundation.

## Players: lazy, facades, no autoplay
Third-party iframes contact providers (visitor data). Lazy-load below fold or facade-gate;
**reserve dimensions** (CLS); **never autoplay**. Self-hosted previews: small files, own domain,
byte-range support for seeking.

## Pre-release streaming (safest first)
1. **Separate preview store** (small MP3s, unguessable dir, noindex, unlinked; delete after).
2. **Navidrome share** — an **unauthenticated public link** (no password/recipient check):
   *unguessable*, not *private*. URL = only secret. Send individually, expire it.
   Auth-required previews → pattern 1 or 3.
3. **Scoped library user** behind server-side proxy (allowlist + rate limit).
Never: admin creds in browser code, enumerable tokens, public Navidrome exposure.

## Release-day procedure
Build artefact (not dev server) → `site-audit.sh dist --strict` → curl OG/JSON-LD/title →
status/headers check → phone check → feed/sitemap contains it → click every provider link →
**purge CDN cache if HTML cached** → announce after verification (`web-audience-and-email`).

## Hard rules
No unlicensed lyrics/full tracks (previews of own material only). No library/admin exposure for
previews. Not live until page + links + OG + feed verified from the public URL.
