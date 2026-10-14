# Website notes — what the research found, and what this pack does with it

For a **music project's site** on a self-hosted box. Sources inline; version-sensitive claims are
flagged and should be re-checked against the project's own docs before you build on them.

## 1. The framework question (and why the answer is boring on purpose)
An artist site is mostly release pages, dates, a bio and journal posts. That is a **content** site,
so pre-render it and add JavaScript only where a page is interactive.

| Framework | Fit here |
|---|---|
| **Astro** (default) | content collections with typed schemas + islands; static by nature. Astro 6's announcement pairs it with **Node 22+** - check `engines` yourself. [collections](https://docs.astro.build/en/guides/content-collections/) · [islands](https://docs.astro.build/en/concepts/islands/) · [Astro 6](https://astro.build/blog/astro-6/) |
| **Eleventy** | simplest template-shaped option (3.1.x stable at the time of research); RSS plugin included. [docs](https://www.11ty.dev/docs/) · [RSS plugin](https://www.11ty.dev/docs/plugins/rss/) |
| **Next.js** (16, Oct 2025) | pick only if this is really a React app; static export excludes ISR/SSR/API routes. [static export](https://nextjs.org/docs/pages/guides/static-exports) |
| **Nuxt** (4, Jul 2025) | if you prefer Vue; `nuxt generate` prerenders. [prerendering](https://nuxt.com/docs/4.x/getting-started/prerendering) |
| **SvelteKit** | `adapter-static` works; the 3.x release candidate was still an RC during research - verify before adopting. [adapter-static](https://svelte.dev/docs/kit/adapter-static) |

Version-sensitive claims to re-check: framework majors, Node requirements, and anything about
static-export limits. `npm view <pkg> version engines` beats a blog post.

## 2. Content model beats page-building
Releases, tracks, gigs and posts are **data**; pages are renderings of it. One file per release with
a schema (title, slug, date, artwork, formats, tracks, credits, links, description, ISRC) gives you
the page, the sitemap entry, the feed item and the structured data from a single source - and it is
what makes the site workable for an agent.
Keep the canonical release/date/link on **your** domain; treat players, ticketing and smart-link
services as integrations. (Bandsintown offers an artist widget/API; Songkick's API page says API use
is licensed and that it is **not approving hobbyist requests** - do not build on it without checking
access. [Bandsintown](https://www.artist.bandsintown.com/widget-api) · [Songkick](https://www.songkick.com/developer))

## 3. Deployment: three honest options
1. **Static files + Caddy in an LXC/VM on your Proxmox box** - fastest to ship if the box already
   exists, and you own everything. You also own TLS, uptime, ISP reliability and recovery.
   Caddy's automatic HTTPS needs 80/443 reachable (HTTP/TLS-ALPN); **wildcards need DNS-01** plus a
   Caddy build containing your DNS provider module. [Caddy HTTPS](https://caddyserver.com/docs/automatic-https)
2. **Docker Compose + reverse proxy** (Traefik with labels, or Caddy + the caddy-docker-proxy
   plugin). Useful when many services change; protect Docker socket access and keep credentials out
   of labels. [Traefik Docker](https://doc.traefik.io/traefik/v3.3/routing/providers/docker/)
3. **Managed static hosting** (Cloudflare Pages/Workers, Netlify, Vercel) - no self-hosting
   maintenance, previews per branch. Cloudflare Pages' free-plan limits (20,000 files, 25 MiB per
   asset, 500 builds/month at the time of research) are plan-sensitive - check them before relying
   on them. [Pages limits](https://developers.cloudflare.com/pages/platform/limits/) · [Netlify atomic deploys](https://docs.netlify.com/deploy/deploy-overview/)

Two facts that cause the classic "the release did not appear":
- **Cloudflare's default cache does not cache HTML.** If you add a Cache Rule that does, you must
  purge on release day. [cache](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
- **`rsync --delete` into the live directory is not a deploy.** Visitors get a mix of old HTML and
  new assets. Build to a new release directory and swap a `current` symlink atomically.

A **Cloudflare Tunnel** gives a public hostname with **no inbound ports** (outbound-only
`cloudflared`), which is attractive behind CGNAT - but the public route is public: use access
controls for anything meant to stay private. [Tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)

## 4. Music-specific web concerns
- **Structured data**: `MusicGroup`, `MusicAlbum`, `MusicRecording`, `MusicEvent`.
  [MusicGroup](https://schema.org/MusicGroup) · [MusicAlbum](https://schema.org/MusicAlbum) · [MusicRecording](https://schema.org/MusicRecording) · [MusicEvent](https://schema.org/MusicEvent)
- **Valid markup is not a rich result.** Google's Event feature wants *a unique page focused on one
  event* with accurate date/location; a tour-overview page listing many shows does not meet that
  page-focus guidance, and Google may decline a rich result anyway. Say this out loud instead of
  promising one. [Event structured data](https://developers.google.com/search/docs/appearance/structured-data/event) · [policies](https://developers.google.com/search/docs/appearance/structured-data/sd-policies)
- **Embeds are third-party data disclosure.** Assume any player iframe talks to its provider;
  lazy-load below the fold, reserve dimensions, never autoplay. [web.dev embed guidance](https://web.dev/articles/embed-best-practices)
  (Bandcamp/SoundCloud/Apple Music embed terms could not be verified from official pages during
  research - check each provider's own docs before relying on one.)
- **Owned smart links**: a `/listen/<slug>/` page beats a third-party link-in-bio - you keep the
  traffic, the analytics and the uptime.
- **Pre-release previews**: Navidrome's **share** feature gives a link to selected tracks/albums,
  but the current docs describe a share as an **unauthenticated public link** - there is no
  documented password/recipient protection, so the URL *is* the secret. Treat "private" as
  "unguessable", send it individually, and let it expire; for anything that must actually require
  authentication, use a separate preview store or a scoped library user behind your own proxy.
  Never an admin credential or a token in browser code.
  [Subsonic API](https://www.navidrome.org/docs/developers/subsonic-api/) · [sharing](https://www.navidrome.org/docs/usage/features/sharing/)
- **Feeds**: ship RSS/Atom for releases and posts; podcast-style feeds only if you actually publish
  episodic audio (Apple Podcasts requires RSS 2.0 with enclosures, stable GUIDs and byte-range/HEAD
  support). [Apple feed requirements](https://podcasters.apple.com/support/823-podcast-requirements)
- **EPK**: a public `/press` page with short+long bio, selected music/video, hi-res photos, artwork,
  quotes and a booking contact is a convention, not a standard - keep downloads clearly labelled.

## 5. Email and audience
- Two shapes: a hosted newsletter provider (list + sending handled) or your own list plus a sending
  API (you implement consent, confirmation, unsubscribe, suppression). Self-hosting a list manager
  (e.g. Listmonk) removes the third party and adds a database you must back up. [Listmonk concepts](https://listmonk.app/docs/concepts/)
- **Double opt-in**: MailerLite's own docs say it is recommended but **not required by GDPR** - use
  it as strong anti-abuse practice and as consent evidence (keep timestamp + source).
  [MailerLite double opt-in](https://www.mailerlite.com/help/how-to-use-double-opt-in-when-collecting-subscribers)
- A static site needs **one small server-side endpoint**. Keys stay server-side; a client-side
  Turnstile/hCaptcha widget alone is not protection - tokens must be validated on the server.
  [Turnstile validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)
- Deliverability, not design, is what loses release emails: **SPF + DKIM + DMARC** on a verified
  sending subdomain, then a real test to Gmail/Outlook (not just to yourself).

## 6. Performance and accessibility
- Core Web Vitals targets at the **75th percentile**: LCP <= 2.5 s, INP <= 200 ms, CLS <= 0.1.
  [CWV](https://developers.google.com/search/docs/appearance/core-web-vitals) · [web.dev vitals](https://web.dev/articles/vitals)
- The reliable wins: sized responsive images with explicit dimensions, self-hosted subset fonts with
  `font-display`, deferred third-party scripts, and a small JavaScript budget.
- **Automated accessibility scans find only a fraction of real problems.** Playwright says so
  explicitly; keyboard and screen-reader behaviour needs a human pass. [Playwright a11y](https://playwright.dev/docs/accessibility-testing)
- Lighthouse CI turns a budget into a regression test. [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)
- Privacy-friendly analytics: Umami, Plausible CE, GoatCounter (self-hosting any of them means
  another service with a database to back up). [Umami](https://docs.umami.is/docs/install) · [Plausible CE](https://plausible.io/self-hosted-web-analytics) · [GoatCounter](https://goatcounter.com/)

## 7. What this pack does, and what it does not
**Does:** ships `web-site-architect`, `web-release-page`, `web-structured-data`,
`web-selfhost-deploy`, `web-perf-a11y` (+`site-audit.sh`), `web-audience-and-email`,
`web-analytics`, a read-only `Site QA` agent, a website runbook and workflow prompt 07.

**Honest limits:**
- `site-audit.sh` is a **static** check. It cannot see runtime behaviour, real Core Web Vitals, or
  how a player behaves under keyboard navigation. It resolves relative links against the output
  root, which fits most static generators but can false-positive on unusual layouts.
- No browser automation was available: nothing in this pack has actually rendered a page, run
  Lighthouse, or driven a keyboard. Those are your checks.
- Framework versions, CDN limits and provider terms move. The pack tells you *how* to check.
