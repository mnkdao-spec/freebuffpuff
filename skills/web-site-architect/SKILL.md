---
name: web-site-architect
description: Choose and set up the architecture for a music project's website - static-first frameworks, typed content collections for releases/tracks/events/journal, static vs server rendering, deployment topology. Use at the start of any website task, when adding content/page types, "how should this be built", or file-vs-embed decisions.
metadata:
  category: web
---

# Site architecture

## Default: static site with a real content model
Release pages are headings, artwork, text, links — no browser framework needed. **Pre-render**;
JS only where genuinely interactive (player/filter/form — islands model; hence **Astro** default:
content collections + typed schemas + opt-in components). Eleventy for template preference;
Next/SvelteKit/Nuxt only if truly an app. Check engine requirements from the framework itself
(`npm view <pkg> engines version`; Astro 6 ≈ Node 22+). **Content-collections API moved:**
current Astro = `src/content.config.ts` with `defineCollection({ loader: glob(...) })`; old
`src/content/config.ts` is legacy (shim removed in Astro 6). Most tutorials show the old path.

## Model content, not pages
Releases/events/posts = data; pages render it. Schema once (title/slug/date/artwork/formats/
tracks/credits/links/description/isrc), render page + sitemap + feed + structured data from it.
**Own canonical data** (players/ticketing = integrations). One stable URL per release/event.
Fixtures per content type in repo. Prefer build-time collections over live data.

## Topology (pick one, in writing)
Static + Caddy in LXC/VM (you own TLS/uptime/backups) | Compose + proxy (proxy to maintain) |
Managed static host (vendor builds/previews/CDN). Self-hosting fits (box exists) but owns power/
ISP/certs/recovery — bad week for proxy debugging is not release week.

## Agent-workable repo
`content/` (data) / `src/` (pages/layouts/components) / `public/` (assets) / `scripts/` (helpers).
**Site repo separate from media-stack repo** (different cadence, blast radius).

## Verification agents can run
`npm ci` → `npm run build` (real artefact, not dev server) → `npm run preview` (click the
PRODUCTION build) → `site-audit.sh dist --strict`. Dev-server rendering proves nothing about
shipped HTML (hides missing alt/OG/unhashed assets).

## Hard rules
No server runtime for static sites (smallest endpoint for forms/newsletters, not framework
migration). No secrets in repo/build (public builds have no private half). Always state build
command + audit result.
