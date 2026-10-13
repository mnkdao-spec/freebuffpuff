---
name: web-perf-a11y
description: Keep a music site fast and accessible - Core Web Vitals budgets (LCP/INP/CLS), image and font handling, third-party player embeds and facades, audio delivery, keyboard-accessible player controls, Playwright and Lighthouse CI checks, and a static audit of the built output. Use before shipping a release page, when the site feels slow or shifts on load, when adding a player or analytics snippet, when auditing a built site, or when asked whether the site is accessible.
metadata:
  category: web
---

# Performance and accessibility

## Budgets (write them down; measure them)
Google's current Core Web Vitals targets are at the **75th percentile**: **LCP <= 2.5 s**,
**INP <= 200 ms**, **CLS <= 0.1**. Lab scores are a proxy - field data is the real number.
Add your own hard limits, for example: initial JS <= 150-250 KB gzipped, no sourcemaps in the
published output, every image has width/height, no autoplay.

```bash
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict --budget-kb 250
bash .agents/skills/web-perf-a11y/scripts/site-audit.sh dist --url https://your-domain
```
The script reads the **built** output: publishing blockers (leaked `.env`, `.map`, `node_modules`,
credentials), invalid JSON-LD, missing OG/canonical/title, images without `alt`/dimensions, broken
internal links, missing 404/robots/sitemap/feed, JS weight versus budget, and - with `--url` -
whether the deployed page is byte-identical to the build you just made. Note it resolves relative
links against the output root, which matches most static generators but can false-positive on
unusual layouts.

## The usual wins, in order
1. **Images**: sized variants (`srcset`/`sizes`), modern formats (AVIF/WebP), and explicit
   `width`/`height`. Unsized artwork is the classic cause of CLS.
2. **Third-party players**: they load their own scripts and network requests, and they set the
   visitor's browser talking to someone else. Lazy-load below-the-fold players, reserve their
   dimensions, or use a click-to-load facade. Never autoplay.
3. **Fonts**: self-host only the weights you use, subset them, preload just the critical one, and
   use `font-display` so text is never invisible.
4. **Audio**: keep previews small, serve from your own domain, and keep byte-range support so
   seeking works.
5. **JavaScript**: a mostly-static site should need very little. If the bundle is large, find out
   what is shipping that does not need to.

## Accessibility for a media site
- Semantic headings, one `h1` per page, descriptive alt text on artwork (what it shows, not
  "cover").
- Player controls reachable and operable **by keyboard**, with visible focus and labelled buttons
  (play/pause/seek/volume), not icon-only divs.
- Captions for spoken video, transcripts where useful. **Do not publish lyrics you have no right
  to publish.**
- Contrast and text sizing matter more on a phone in daylight than on your monitor.

## Testing
```bash
npx playwright test                     # core flows: nav, release page, ticket link, form, player
npx @axe-core/cli dist/index.html       # or @axe-core/playwright inside the suite
npx lhci autorun                        # Lighthouse CI with assertions per page type
```
Playwright's own documentation is explicit that automated accessibility scans **cannot** find most
real problems - they flag some. Keyboard and screen-reader behaviour needs a human, at least once
per page type. Lighthouse CI with assertions is what turns "we care about performance" into a
regression test.

## Hard rules
- Never claim a performance or accessibility property you did not measure. Report the command, the
  number, and what it measured (lab vs field).
- Do not add an analytics or embedding script that blocks the first paint.
- Do not "fix" a low score by removing the accessibility feature that raised it.
