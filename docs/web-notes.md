# Website notes — research findings for a music project's self-hosted site

Sources inline; version-sensitive claims flagged — re-check before building on them.

## 1. Framework (boring on purpose)
Artist site = release pages, dates, bio, posts. A **content** site: pre-render, JS only where interactive.

| Framework | Fit |
|---|---|
| **Astro** (default) | content collections + islands; static by nature. Astro 6 pairs with **Node 22+**. |
| **Eleventy** | simplest template option; RSS plugin included. |
| **Next.js** | only if really a React app; static export excludes ISR/SSR/API routes. |
| **Nuxt** | if you prefer Vue; `nuxt generate` prerenders. |

`npm view <pkg> version engines` beats a blog post.

## 2. Content model beats page-building
Releases/tracks/gigs/posts are **data**; pages render it. One file per release (title, slug, date,
artwork, formats, tracks, credits, links, description, ISRC) gives page + sitemap + feed + structured
data from one source. Canonical release/date/link on **your** domain; players/ticketing as integrations.

## 3. Deployment: three honest options
1. **Static + Caddy in LXC/VM on your Proxmox box** — you own TLS, uptime, recovery.
2. **Compose + reverse proxy** (Traefik/Caddy). Protect the Docker socket; keys out of labels.
3. **Managed static hosting** (Pages/Netlify/Vercel) — previews per branch, plan limits apply.

- **Cloudflare default cache does not cache HTML.** Cache Rules that do need a purge on release day.
- **`rsync --delete` into live is not a deploy.** Build to a new dir, swap a `current` symlink atomically.
- **Tunnel** = public hostname, no inbound ports — but the route is public: gate private things.

## 4. Music-specific concerns
- **Structured data**: `MusicGroup`, `MusicAlbum`, `MusicRecording`, `MusicEvent`.
- **Valid markup is not a rich result.** Google Event wants *one page per event*; tour-overview pages don't qualify.
- **Embeds disclose to providers.** Lazy-load, reserve dimensions, never autoplay.
- **Owned smart links**: `/listen/<slug>/` beats link-in-bio — you keep traffic/analytics/uptime.
- **Pre-release previews**: Navidrome **share** = **unauthenticated public link** — URL *is* the secret.
  "Private" means "unguessable"; expire it. Auth-required previews need a separate store/proxy.
  Never admin credentials in browser code.
- **Feeds**: RSS/Atom for releases/posts.
- **EPK**: public `/press` with bios, music, photos, quotes, booking contact.

## 5. Email and audience
- Hosted newsletter provider vs own list + sending API. Self-hosting (Listmonk) = another DB to back up.
- **Double opt-in** as anti-abuse + consent evidence (timestamp + source).
- Static site needs **one server-side endpoint**; keys server-side; validate captcha tokens server-side.
- Deliverability: **SPF + DKIM + DMARC** on a verified subdomain; test to Gmail/Outlook.

## 6. Performance and accessibility
- CWV 75th percentile: LCP <= 2.5 s, INP <= 200 ms, CLS <= 0.1.
- Wins: sized responsive images, subset self-hosted fonts, deferred third-party JS, small JS budget.
- **Automated a11y scans catch a fraction.** Keyboard/screen-reader needs a human pass.
- Lighthouse CI turns budget into regression test.

## 7. What this pack does / does not
**Does:** `web-site-architect`, `web-release-page`, `web-structured-data`, `web-selfhost-deploy`,
 `web-perf-a11y` (+`site-audit.sh`), `web-audience-and-email`, `web-analytics`, read-only `Site QA` agent.
**Does not:** render pages, run Lighthouse, or drive a keyboard — those are your checks.
