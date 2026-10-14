---
name: web-analytics
description: Measure a music site without surveillance - privacy-friendly self-hosted analytics versus hosted, what to track on release and smart-link pages, outbound provider-click tracking, and the maintenance cost of another homelab service. Use for listen counts, adding analytics, self-hosted vs hosted choices, or tracking reviews.
metadata:
  category: web
---

# Analytics

## Choose with maintenance in view
Umami (Compose + DB; you own backups) | Plausible CE (self-host = own upgrades/backups) |
GoatCounter (hosted or self-hosted, light) | third-party pixels (more data, more disclosure, slower site).
Self-hosting = a container + database + **backup** + monthly updates — a service, not a snippet.
Privacy-friendly ≠ automatically compliant everywhere — don't claim that.

## Worth measuring
Release views + **which provider link gets clicked** (tells you where to point the CTA);
`/listen/<slug>/` outbound clicks; signups per source; non-spam referrers. No ads to optimise —
ignore vanity metrics.

## Wiring
One small deferred script (never blocking first paint); explicit outbound-click tracking
(provider links = the conversion); short accurate privacy note + opt-out if required;
self-hosted on same origin behind proxy (no new public port); **back up its database**.

## Hard rules
No pixels, session recording, fingerprinting, or pre-content loads. Never claim "no data
collected" — state exactly what and where stored. Homelab-hosted analytics inherits backup duties.
