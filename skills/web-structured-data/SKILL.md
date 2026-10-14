---
name: web-structured-data
description: Add and validate schema.org JSON-LD and social metadata for a music project - MusicGroup, MusicAlbum, MusicRecording and MusicEvent - plus Open Graph/Twitter cards, canonical URLs and title/description hygiene. Use when publishing or editing a release or gig page, when search or social previews look wrong, before announcing a release, or when asked to make the site more discoverable.
metadata:
  category: web
---

# Structured data and social metadata

## Types and the properties that matter
| Type | Use on | Key properties |
|---|---|---|
| `MusicGroup` | the artist/project page | `name`, `url`, `image`, `sameAs[]` (streaming/social), `genre`, `member` |
| `MusicAlbum` | a release page | `name`, `byArtist`, `datePublished`, `image`, `numTracks`, `albumReleaseType`, `track[]` |
| `MusicRecording` | a track, or inside `track[]` | `name`, `byArtist`, `duration` (ISO 8601, e.g. `PT3M42S`), `isrcCode`, `inAlbum` |
| `MusicEvent` | one gig page | `name`, `startDate` **with timezone offset**, `location` (`Place` with `name` + `address`), `performer`, `offers`, `eventStatus` |

Rules that keep the markup honest:
- **Only mark up what is visible on the page.** Structured data that contradicts the page is a
  policy problem, not a clever trick.
- Put JSON-LD in the **built HTML**. Markup injected by client-side JavaScript is not reliably seen.
- `startDate` needs the offset (`2026-11-03T20:00:00+01:00`), or the date is ambiguous.
- Past gigs: keep the page and set `eventStatus`/dates honestly rather than deleting it.

## The gap between "valid" and "shows a rich result"
Important, and routinely over-promised: the schema.org vocabulary being correct does not make a
page eligible for a Google rich result. Google's Event feature wants **a unique page focused on one
event** with accurate date and location - a tour-overview listing many shows does not meet that
page-focus guidance. Google may decline to show a rich result even for valid markup, and structured
data does not by itself raise rankings. Say this out loud instead of promising rich results.

## Social preview metadata (per page)
```html
<title>Release title — Artist (<= ~60 chars)</title>
<meta name="description" content="One honest sentence.">
<link rel="canonical" href="https://your-domain/releases/<slug>/">
<meta property="og:title" content="..."><meta property="og:description" content="...">
<meta property="og:image" content="https://your-domain/art/<slug>-og.jpg">  <!-- absolute URL -->
<meta property="og:url" content="https://your-domain/releases/<slug>/">
<meta property="og:type" content="music.album">
<meta name="twitter:card" content="summary_large_image">
```
Use a dedicated social image (roughly 1200x630, JPG/PNG) - not the square cover art, which crops
badly in most previews.

## Verify, don't assume
```bash
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist          # parses every JSON-LD block
curl -sS https://your-domain/releases/<slug>/ | grep -o 'application/ld+json' | wc -l
```
Then use Google's Rich Results Test and the schema.org validator on the **public URL**, and check
the live page in Search Console later. Record which validator you used - "valid" claims need a
source.

## Hard rules
- Never claim a rich result. Report "markup validates" and "not eligible for the Event feature
  because the page lists many events" as different findings.
- Do not fabricate `aggregateRating`, reviews, ISRCs or release dates to satisfy a validator.
- One canonical URL per page; do not leave two pages competing for the same release.
