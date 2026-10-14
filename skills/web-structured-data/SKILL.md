---
name: web-structured-data
description: Add and validate schema.org JSON-LD and social metadata - MusicGroup, MusicAlbum, MusicRecording, MusicEvent - plus Open Graph/Twitter cards, canonical URLs, title/description hygiene. Use when publishing/editing release or gig pages, when previews look wrong, before announcements, or discoverability work.
metadata:
  category: web
---

# Structured data and social metadata

| Type | Page | Key props |
|---|---|---|
| `MusicGroup` | artist page | `name`, `url`, `image`, `sameAs[]`, `genre`, `member` |
| `MusicAlbum` | release page | `name`, `byArtist`, `datePublished`, `image`, `numTracks`, `albumReleaseType`, `track[]` |
| `MusicRecording` | track / inside `track[]` | `name`, `byArtist`, `duration` (ISO8601 `PT3M42S`), `isrcCode`, `inAlbum` |
| `MusicEvent` | one gig page | `name`, `startDate` **with offset**, `location` (Place+address), `performer`, `offers`, `eventStatus` |

- **Mark up only visible content.** Contradicting markup = policy problem.
- JSON-LD in **built HTML** (client-injected markup isn't reliably seen).
- `startDate` needs offset (`2026-11-03T20:00:00+01:00`). Past gigs: keep page, honest status.

## Valid ≠ rich result
Correct vocabulary ≠ Google rich-result eligibility. Event feature wants **one page per event**
(tour overviews don't qualify); Google may decline anyway; markup alone doesn't rank. Say so aloud.

## Social metadata (per page)
`<title>` (≤~60 chars), description (one honest sentence), `canonical`, `og:title/description/image`
(**absolute** image URL)/`og:url`/`og:type`, `twitter:card`. Dedicated 1200x630 social image —
square covers crop badly.

## Verify
`site-audit.sh dist` (parses every JSON-LD block) + Rich Results Test + schema validator on the
**public URL** + Search Console later. Record which validator — "valid" needs a source.

## Hard rules
Never promise rich results ("validates" ≠ "eligible"). Never fabricate ratings/reviews/ISRCs/dates.
One canonical URL per page.
