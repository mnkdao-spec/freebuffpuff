---
name: web-analytics
description: Measure a music site without surveillance - privacy-friendly self-hosted analytics (Umami, Plausible CE, GoatCounter) versus hosted, what to track on release and smart-link pages, how to wire outbound provider-click tracking, and the maintenance cost of adding another service to the homelab. Use when asked how many people listened, when adding analytics to a site, when choosing between self-hosted and hosted analytics, or when reviewing tracking on an existing site.
metadata:
  category: web
---

# Analytics

## Choose with the maintenance cost in view
| Option | Where it runs | Notes |
|---|---|---|
| **Umami** | self-hosted (Compose + a database) | simple dashboard, Docker-native; you own the database backup |
| **Plausible CE** | self-hosted | open source and self-hostable; self-hosting means owning upgrades, backups and availability |
| **GoatCounter** | hosted or self-hosted | privacy-friendly counts, light footprint |
| Third-party tag managers / pixels | someone else's servers | more data, more scripts, more disclosure - and it slows the site |

Self-hosting analytics costs a container, a database, **a backup**, and a monthly update - it is a
service, not a snippet. If a band site needs pageview counts, a hosted privacy-friendly option may
be the honest choice. Privacy-friendly tooling reduces tracking; it does not by itself make any
setup compliant in every jurisdiction - don't claim that.

## What is actually worth measuring for a music project
- Release page views and **which provider link people click** (Bandcamp vs streaming) - that is
  the number that tells you where to point the CTA.
- `/listen/<slug>/` outbound clicks per release.
- Newsletter signups per source (page, smart link, social).
- Referrers that are not spam. Ignore vanity metrics; there are no ads to optimise.

## Wiring it up
```html
<!-- one small script, defer, self-hosted or a hosted privacy-friendly endpoint -->
<script defer data-website-id="<id>" src="/stats/script.js"></script>
```
- Load it **deferred/async** so it cannot delay first paint (`web-perf-a11y`).
- Track outbound clicks explicitly (a click handler or a link attribute), because provider links
  are the conversion you care about.
- Add a short, accurate privacy note on the site and a way to opt out if your tooling requires it.
- Self-hosted: serve it from your own domain (or a subdomain) and **back up the database** like any
  other service. Note that a separate upload endpoint for public traffic usually means exposing
  that service - keep it on the same origin behind your proxy, not on a new public port.

## Hard rules
- No tracking pixels, no session recording, no fingerprinting, and nothing that loads before the
  content does.
- Never claim "no data is collected"; describe exactly what is collected and where it is stored.
- If analytics lives on the homelab, it inherits the homelab's backup obligations - say so.
