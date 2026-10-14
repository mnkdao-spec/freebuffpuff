---
name: web-site-architect
description: Choose and set up the architecture for a music project's website - static-first frameworks (Astro, Eleventy, Next, SvelteKit, Nuxt), typed content collections for releases/tracks/events/journal, static versus server rendering, and the deployment topology (self-hosted static + Caddy, or managed static hosting). Use at the start of any website task, when adding a new content type or page type, when asked "how should this site be built", or when deciding what is a file in the repo versus a third-party embed.
metadata:
  category: web
---

# Site architecture

## The default: a static site with a real content model
A release page is headings, artwork, text and links. It does not need a browser framework. So:
- **Pre-render to HTML**; add JavaScript only where a page is genuinely interactive (a player, a
  filter, a form). That is the islands model, and it is why **Astro** is the default here: content
  collections with typed schemas, plus opt-in interactive components.
- **Eleventy** is a good fit if you prefer templates over components. **Next.js / SvelteKit / Nuxt**
  are for when this is actually an application; a static-only site gains nothing from their runtime.
- Version-sensitive: check the framework's own engine requirement before installing rather than
  trusting a blog post (e.g. Astro 6's announcement pairs it with Node 22+; Nuxt 4 and Next 16 are
  the recent majors). `npm view <pkg> engines version` answers it in one line - pin in the lockfile.
- **The content-collections API moved.** Current Astro uses `src/content.config.ts` with
  `defineCollection({ loader: glob({...}), schema })`; the older `src/content/config.ts` path is
  legacy and Astro 6 removed the automatic compatibility shim. Most tutorials you will find are
  written against the old path, so check the file name against the docs before copying an example.
  [content collections](https://docs.astro.build/en/guides/content-collections/)

## Model the content, not the pages
Releases, events and posts are data. Define them once with a schema and render pages from it:
```
release: title, slug, date, cover(image), formats[], tracks[], credits[], links[], description, isrc?
track:   title, duration, sequence, credits[], preview?, isrc?
event:   startDate(+timezone), venue(name,address), ticketUrl, status, pageUrl
post:    title, date, summary, image, body
```
Rules that keep this from rotting:
- **You own the canonical data**; Bandcamp/Spotify/Bandsintown are integrations, never the only
  place a date or link exists.
- One page per performance/release with a **stable URL** - it is what you will link to forever.
- Keep representative fixtures for each content type in the repo. An agent (and a test) can then
  see the real shape instead of inventing one.
- Prefer build-time collections unless you truly need live data.

## Deployment topology - pick one, in writing
| Topology | Cost | Who maintains it |
|---|---|---|
| **Static + Caddy in an LXC/VM on your Proxmox box** | your hardware | you: TLS, uptime, backups, updates (`web-selfhost-deploy`) |
| Docker Compose + reverse proxy, same box | your hardware | you, plus a proxy to maintain |
| **Managed static host** (Cloudflare Pages/Workers, Netlify, Vercel) | free tiers | the vendor: builds, previews, CDN |

Self-hosting is a reasonable choice here because the box already exists - but be honest that it
means owning power, ISP reliability, certificate renewal, and recovery. If a release is due the
same week, that is a bad week to be debugging a reverse proxy.

## Repo shape that an agent can work in
```
content/            releases/*.mdx, events/*.yml, posts/*.mdx   <- the data
src/                pages, layouts, components
public/             static assets (artwork, audio previews, fonts)
scripts/            build + audit helpers
```
Keep the **site repo separate from the media-stack repo**: one is deployed, the other is
infrastructure. Different change cadence, different blast radius.

## Verification an agent can actually run
```bash
npm ci                       # exact, from the lockfile
npm run build                # the real artefact - not the dev server
npm run preview              # serve the PRODUCTION build locally and click through it
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict
```
Always verify the **built output**. A dev server that renders correctly proves nothing about the
shipped HTML, and it hides missing alt text, broken OG tags and unhashed assets.

## Hard rules
- Do not introduce a server runtime for a site that is static. If a feature needs a server
  (a newsletter endpoint, a form), add the smallest one - not a framework migration.
- Do not put secrets in the site repo or the build output; a public build has no private half.
- Do not hand-back a build without stating which command produced it and what the audit said.
