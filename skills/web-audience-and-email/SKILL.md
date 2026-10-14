---
name: web-audience-and-email
description: Build and operate the audience side - newsletter signup with double opt-in and consent records, deliverable release emails (SPF/DKIM/DMARC), spam-resistant contact forms without leaked keys, and the small server endpoint a static site needs. Use for mailing lists, announcements, contact/booking forms, missing/spam-folder signups, or fan-notification questions.
metadata:
  category: web
---

# Audience and email

## Shapes (pick deliberately)
Hosted provider (form + account; least maintenance; their list; tier limits) | own list + sending
API (full control; you implement consent/confirm/unsub/suppression) | self-hosted manager, e.g.
Listmonk (no third party; you own upgrades/backups/placement). Static sites need **one small
server-side endpoint** (Worker/function/proxy-side lines — not a framework migration).

## Honest robust signup
What + how often, stated. One field. No pre-ticked boxes. **Double opt-in** (confirm by email;
recommended practice + consent evidence — keep timestamp + source). One-click unsubscribe every
message; bounce suppression. **Never** purchased/scraped lists. Privacy notice must describe reality.

## The endpoint (get right)
`POST /api/subscribe { email }`: server-side validate/normalise; IP+address rate limits;
honeypot + **server-validated** challenge token (client widget alone ≠ protection); API key in
server env only; store/forward then neutral response (no subscribed-or-not leak). Contact forms:
same handling; never interpolate raw input as HTML into mail.

## Deliverability (why release emails vanish)
**SPF** + **DKIM** + **DMARC** on a verified sending subdomain; test to Gmail AND Outlook
(same-domain self-tests prove nothing).

## Announcement procedure
Live+verified page first (OG + feed) → one CTA (release or `/listen/<slug>/`) → phone-rendered
subject/preview → opted-in list only → watch bounces/unsubs. Same content to feed + socials.

## Hard rules
No keys/list exports/subscriber data in repo or build. No silent sharing or buried clauses.
No "healthy list / successful send" claims without provider numbers. Legal framing = factual
description (consent/opt-in/unsub), jurisdiction-dependent — not advice.
