---
name: web-perf-a11y
description: Keep a music site fast and accessible - Core Web Vitals budgets (LCP/INP/CLS), images and fonts, third-party player facades, audio delivery, keyboard-accessible controls, Playwright and Lighthouse CI, static audit of built output. Use pre-ship, on slowness/layout-shift, player/analytics additions, built-site audits, or accessibility questions.
metadata:
  category: web
---

# Performance and accessibility

## Budgets (write down; measure)
CWV 75th percentile: **LCP ≤ 2.5 s**, **INP ≤ 200 ms**, **CLS ≤ 0.1**. Lab = proxy; field = real.
Own limits too (e.g. initial JS ≤ 150-250 KB gzip, no sourcemaps published, sized images, no autoplay).
`site-audit.sh dist [--strict] [--budget-kb 250] [--url <live>]` reads **built** output:
leaked files/creds, invalid JSON-LD, missing OG/canonical/title, un-alt/unsized images, broken
internal links, missing 404/robots/sitemap/feed, JS vs budget, `--url` byte-identity vs build.
(Relative links resolve against output root — fits most generators; unusual layouts may false-positive.)

## Wins, in order
1. **Images** (`srcset`/sizes, AVIF/WebP, explicit dimensions — unsized art = classic CLS).
2. **Third-party players** (own scripts + visitor-data disclosure): lazy-load/facade below fold,
   reserved dimensions, never autoplay. 3. **Fonts** (self-host used weights, subset, preload
   critical, `font-display`). 4. **Audio** (small previews, own domain, byte-ranges for seeking).
5. **JS** (static sites need little; find what's shipping unnecessarily).

## Accessibility
Semantic headings (one h1), descriptive artwork alt, keyboard-operable labelled player controls
with visible focus, captions/transcripts where useful. **No unlicensed lyrics.** Contrast sizing
for phones in daylight.

## Testing
`npx playwright test` (nav/release/ticket/form/player) + axe (flags some, not most) + `lhci autorun`
assertions per page type. Automated scans **cannot** find most real a11y problems — human
keyboard/screen-reader pass per page type, at least once.

## Hard rules
Never claim unmeasured perf/a11y (report cmd + number + lab-vs-field). No first-paint-blocking
third-party scripts. Never "fix" scores by removing the a11y feature that raised them.
