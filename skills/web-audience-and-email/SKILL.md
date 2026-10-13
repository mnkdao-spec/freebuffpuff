---
name: web-audience-and-email
description: Build and operate the audience side of a music site - newsletter signup with double opt-in and consent records, release-announcement emails that actually arrive (SPF/DKIM/DMARC), contact forms that resist spam without leaking keys, and the small server-side endpoint a static site needs for all of it. Use when adding a mailing list, sending a release announcement, wiring a contact or booking form, when signups are not arriving or land in spam, or when asked how fans should be notified about a release.
metadata:
  category: web
---

# Audience and email

## Two shapes - pick deliberately
| Shape | What you run | Trade-off |
|---|---|---|
| **Hosted newsletter provider** (list + sending + unsubscribe handled) | a form and a provider account | least maintenance; provider holds your list; free tiers have limits |
| **Your own list + a sending API** | a small subscriber table/endpoint + an email API | full control; you implement consent, confirmation, unsubscribe and suppression correctly |
| **Self-hosted list manager** (e.g. Listmonk) | a container, a database, and DNS for deliverability | no third party in the loop; *you* own upgrades, backups and inbox placement |

A static site cannot do any of this alone: it needs **one small server-side endpoint**. Keep it
tiny (a Worker, a function, or a few lines in the same container as the reverse proxy) - do not
migrate the whole site to a framework to add a form. See `web-selfhost-deploy`.

## Signup that is honest and robust
- Say **what** subscribers will get and how often. One field. No pre-ticked boxes.
- **Double opt-in**: confirm by email before anyone is added. (MailerLite's own documentation notes
  it is *recommended*, not a universal GDPR requirement - treat it as strong anti-abuse practice
  and as your consent evidence, and keep the consent record with timestamp and source.)
- Unsubscribe in one click, in every message, honoured immediately. Bounced addresses suppressed.
- **Never** use purchased or scraped lists.
- The privacy notice must actually describe this.

## The endpoint (what an agent must get right)
```
POST /api/subscribe   { email }
  - validate/normalise server-side; reject obviously invalid input
  - rate limit by IP and by address
  - honeypot field + a challenge token verified SERVER-SIDE (a client-side widget alone is not
    protection - Cloudflare Turnstile tokens must be validated on the server)
  - API key lives in the server env, never in the browser bundle or the repo
  - store/forward to the provider, then respond with a neutral message (do not leak whether an
    address was already subscribed)
```
Contact/booking forms: same server-side handling, plus never interpolate raw user input into an
email template as HTML.

## Deliverability (the reason release emails vanish)
Email from "your own domain" lands in spam unless the domain is set up for it:
- **SPF** TXT record authorising the sender,
- **DKIM** signing key published at the provider's selector,
- **DMARC** policy so receivers know what to do when authentication fails.
Verify your **sending subdomain** with the provider, and send the test to a Gmail and an Outlook
address - not just to yourself on the same domain.

## Release-announcement procedure
1. The release page is live and verified (`web-release-page`), including OG tags and the feed.
2. One clear call to action - the release or `/listen/<slug>/` page, not five links.
3. Subject line and preview text written for a phone; check rendering on a real phone.
4. Send to opted-in subscribers only. Then watch bounces and unsubscribes rather than assuming.
5. Post the same content to the feed and socials - the newsletter is not the only channel.

## Hard rules
- No API key, no list export and no subscriber data in the site repo or the build output.
- No silent list sharing, no "we may share your address with partners" buried in a footer.
- Do not report a list as healthy or a send as successful without checking the provider's numbers
  (delivered vs bounced vs unsubscribed).
- Keep the legal framing factual: describe what the setup does (consent, opt-in, unsubscribe) and
  say that specific legal compliance depends on jurisdiction - it is not advice.
