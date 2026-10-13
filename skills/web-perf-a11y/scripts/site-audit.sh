#!/usr/bin/env bash
# site-audit.sh - READ-ONLY audit of a BUILT static site directory (dist/, public/, _site/ ...).
# Reads files, never writes, never edits. Optionally checks a live URL (HEAD requests + hash compare).
#
# Catches: publishing blockers (leaked .env/secrets/sourcemaps/.git), invalid JSON-LD, missing or
# malformed social/SEO metadata, images without alt/dimensions, broken internal links, missing
# 404/robots/sitemap/feed, oversized assets and JS budgets, and (with --url) whether the deployed
# page is actually the build you think it is.
#
# Usage: site-audit.sh <dir> [--url https://example.com] [--budget-kb N] [--strict] [--json] [--max-findings N]
# Exit:  0 = report produced, 1 = --strict and a FAIL was found, 2 = usage, 4 = needs Python.
set -uo pipefail

if [ -z "${PY:-}" ]; then
  PY="${PYTHON:-}"
  [ -n "$PY" ] || PY="$(command -v python3 || command -v python || true)"
fi
[ -n "$PY" ] || { echo "site-audit: needs python3 (or python). Set PYTHON=/path/to/python3" >&2; exit 4; }

DIR=""; URL=""; BUDGET=300; STRICT=0; MODE=text; MAXF=0
while [ $# -gt 0 ]; do case "$1" in
  --url) URL="${2:-}"; shift ;;
  --budget-kb) BUDGET="${2:-300}"; shift ;;
  --strict) STRICT=1 ;;
  --json) MODE=json ;;
  --max-findings) MAXF="${2:-0}"; shift ;;
  -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -*) echo "unknown flag: $1" >&2; exit 2 ;;
  *) DIR="$1" ;;
esac; shift; done
[ -n "$DIR" ] || { echo "usage: site-audit.sh <dir> [--url https://example.com] [--budget-kb N] [--strict]" >&2; exit 2; }
[ -d "$DIR" ] || { echo "site-audit: no such directory: $DIR (build the site first)" >&2; exit 2; }

"$PY" - "$DIR" "$URL" "$BUDGET" "$MODE" "$STRICT" "$MAXF" <<'PY'
import gzip, hashlib, json, os, re, subprocess, sys, urllib.parse
from html.parser import HTMLParser

root, base_url, budget_kb, mode, strict, maxf = (
    sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5] == "1", int(sys.argv[6]))
root = os.path.abspath(root)
F = []
def add(level, cid, msg):
    F.append((level, cid, msg))

# ---------------------------------------------------------------- collect files
files = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in (".git",)]
    for fn in filenames:
        p = os.path.join(dirpath, fn)
        rel = os.path.relpath(p, root)
        try:
            files.append((rel, p, os.path.getsize(p)))
        except OSError:
            pass
if not files:
    add("FAIL", "empty", "%s contains no files - did the build run, and is this the right directory?" % root)
    print(json.dumps({"tool": "site-audit", "summary": {"FAIL": 1}, "findings": [{"level": "FAIL", "id": "empty", "message": F[0][2]}]}, indent=2) if mode == "json"
          else "site-audit: FAIL empty: " + F[0][2])
    sys.exit(1 if strict else 0)

rels = {r for r, _, _ in files}
sizes = {r: s for r, _, s in files}
lower = {r.lower(): r for r in rels}

# ------------------------------------------------- publishing blockers (FAIL)
BAD_NAMES = re.compile(r"(^|/)(\.env(\..+)?|\.git|node_modules|\.DS_Store|id_rsa|id_ed25519|"
                       r".+\.pem|.+\.key|.+\.p12|.+\.pfx|\.npmrc|\.netrc|\.htpasswd)$", re.I)
for r in sorted(rels):
    if BAD_NAMES.search(r) or r.lower().endswith(".map") or r.lower().endswith(".sql"):
        add("FAIL", "leak:file", "%s is in the published output. Build output must contain only public assets - remove it, and fix the build/ignore so it cannot come back." % r)

SECRET_PATTERNS = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "a private key block"),
    (re.compile(r"\bsk_live_[0-9a-zA-Z]{10,}"), "a live Stripe-style secret key"),
    (re.compile(r"\b(sk|rk)_(test|live)_[0-9a-zA-Z]{16,}"), "a secret API key"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "an AWS access key id"),
    (re.compile(r"\bghp_[0-9a-zA-Z]{36}\b"), "a GitHub token"),
    (re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{10,}"), "a Slack token"),
    (re.compile(r"""(?i)(api[_-]?key|secret|password|passwd|token)\s*[:=]\s*["'][^"'\s]{12,}["']"""), "a hardcoded credential-looking assignment"),
]
scanned = 0
for r, p, s in files:
    if s > 2_000_000:
        continue
    base = os.path.basename(r).lower()
    if not (r.lower().endswith((".html", ".htm", ".js", ".mjs", ".cjs", ".json", ".css", ".txt", ".xml", ".svg", ".map"))
            or base.startswith(".env") or base.endswith(".env")):
        continue
    try:
        txt = open(p, errors="replace").read()
    except OSError:
        continue
    scanned += 1
    for rx, what in SECRET_PATTERNS:
        m = rx.search(txt)
        if m:
            add("FAIL", "leak:secret", "%s looks like it contains %s (matched %r). Public build output is world-readable - rotate the credential and keep it server-side." % (r, what, m.group(0)[:40]))
            break
add("INFO", "leak:scan", "scanned %d text files for credentials/keys" % scanned)

# ------------------------------------------------- essentials
def present(*cands):
    for c in cands:
        if c in rels or c.lower() in lower:
            return True
    return False
if not any(r.endswith(("index.html", "index.htm")) for r in rels):
    add("FAIL", "essential:index", "no index.html in the output - there is no home page to serve.")
if not present("404.html", "404/index.html", "_404.html", "404.htm"):
    add("WARN", "essential:404", "no 404.html found. Without it a wrong URL depends entirely on the server's default error page (an SPA-fallback server can even return 200 with your home page, which search engines index as a soft 404).")
if not present("robots.txt"):
    add("WARN", "essential:robots", "no robots.txt.")
if not present("sitemap.xml", "sitemap-index.xml", "sitemapindex.xml"):
    add("WARN", "essential:sitemap", "no sitemap.xml - search engines have to discover release and gig pages by crawling.")
if not any(present(n) for n in ("feed.xml", "rss.xml", "atom.xml", "feed/index.xml", "index.xml", "rss/index.xml")):
    add("WARN", "essential:feed", "no RSS/Atom feed found. For a music project a feed is how people subscribe to releases and posts.")

# ------------------------------------------------- parse HTML
class P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = ""; self.in_title = False
        self.lang = ""; self.metas = []; self.canonical = None
        self.h1 = 0; self.imgs = []; self.scripts = []; self.anchors = []
        self.hrefs_ok = True; self.in_ld = False; self.ld = []
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "html" and "lang" in a:
            self.lang = a.get("lang") or ""
        elif tag == "title":
            self.in_title = True
        elif tag == "meta":
            key = (a.get("property") or a.get("name") or "").lower()
            if key:
                self.metas.append((key, a.get("content", "")))
        elif tag == "link" and "canonical" in (a.get("rel") or "").lower():
            self.canonical = a.get("href")
        elif tag == "h1":
            self.h1 += 1
        elif tag == "img":
            self.imgs.append(a)
        elif tag == "script":
            if (a.get("type") or "").lower() == "application/ld+json":
                self.in_ld = True
            if a.get("src"):
                self.scripts.append(a["src"])
        elif tag == "link" and (a.get("rel") or "").lower() in ("stylesheet", "preload"):
            if a.get("href"):
                self.scripts.append(a["href"])
        elif tag == "a" and a.get("href"):
            self.anchors.append(a["href"])
    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
        elif tag == "script" and self.in_ld:
            self.in_ld = False
    def handle_data(self, data):
        if self.in_title:
            self.title += data
        if self.in_ld:
            self.ld.append(data)

html_files = sorted(r for r in rels if r.lower().endswith((".html", ".htm")))
pages = {}
for r in html_files:
    p = P()
    try:
        p.feed(open(os.path.join(root, r), errors="replace").read())
    except Exception as e:
        add("WARN", "html:parse", "%s could not be parsed (%s)" % (r, e))
        continue
    pages[r] = p

# ------------------------------------------------- per-page metadata + a11y
no_og = []; no_canon = []; no_desc = []; long_title = []; bad_h1 = []; no_lang = []
img_no_alt = []; img_no_dims = []; ld_blocks = 0
for r in sorted(pages):
    p = pages[r]
    meta = dict(p.metas)
    if not p.title.strip():
        add("WARN", "meta:title", "%s has no <title>." % r)
    elif len(p.title.strip()) > 65:
        long_title.append("%s (%d chars)" % (r, len(p.title.strip())))
    if not meta.get("description"):
        no_desc.append(r)
    elif len(meta["description"]) > 165:
        add("WARN", "meta:description", "%s has a %d-character description; search results truncate around 160." % (r, len(meta["description"])))
    if not p.canonical and not os.path.basename(r).startswith(("404", "_404")):
        no_canon.append(r)
    if not p.lang:
        no_lang.append(r)
    if p.h1 != 1:
        bad_h1.append("%s (h1 x%d)" % (r, p.h1))
    is404 = os.path.basename(r).startswith(("404", "_404"))
    missing = [k for k in ("og:title", "og:description", "og:image", "og:url") if not meta.get(k)]
    if missing and not is404:   # social cards on an error page are pointless
        no_og.append("%s (%s)" % (r, ",".join(missing)))
    ogi = meta.get("og:image")
    if ogi and not ogi.startswith(("http://", "https://")):
        add("WARN", "meta:og", "%s: og:image is not an absolute URL (%s) - most crawlers will not resolve it." % (r, ogi[:60]))
    for a in p.imgs:
        if "alt" not in a:
            img_no_alt.append("%s -> %s" % (r, (a.get("src") or "?")[:60]))
        if not a.get("width") or not a.get("height"):
            img_no_dims.append("%s -> %s" % (r, (a.get("src") or "?")[:60]))
    for block in p.ld:
        block = block.strip()
        if not block:
            continue
        ld_blocks += 1
        try:
            data = json.loads(block)
        except Exception as e:
            add("FAIL", "ldjson:invalid", "%s has a JSON-LD block that is not valid JSON (%s). Broken JSON-LD is worse than none - validators and crawlers both give up." % (r, e))
            continue
        items = data if isinstance(data, list) else [data]
        for it in items:
            if not isinstance(it, dict):
                continue
            ctx = str(it.get("@context", ""))
            if "schema.org" not in ctx:
                add("WARN", "ldjson:context", "%s: a JSON-LD item has no schema.org @context (%r)." % (r, ctx[:40]))
            t = it.get("@type")
            types = t if isinstance(t, list) else [t]
            required = {
                "MusicGroup": ["name"], "MusicAlbum": ["name", "byArtist"], "MusicRecording": ["name", "byArtist"],
                "MusicEvent": ["name", "startDate", "location"], "Event": ["name", "startDate", "location"],
                "BlogPosting": ["headline", "datePublished"], "Article": ["headline", "datePublished"],
                "WebSite": ["name", "url"], "Person": ["name"],
            }
            for ty in types:
                if ty in required:
                    miss = [k for k in required[ty] if not it.get(k)]
                    if miss:
                        add("WARN", "ldjson:props", "%s: %s is missing %s." % (r, ty, ", ".join(miss)))
                    if ty in ("MusicEvent", "Event") and it.get("startDate") and not re.search(r"(Z|[+-]\d{2}:?\d{2})$", str(it["startDate"])):
                        add("WARN", "ldjson:tz", "%s: MusicEvent startDate %r has no timezone offset - the date is ambiguous in other regions." % (r, it["startDate"]))

if ld_blocks == 0:
    add("WARN", "ldjson:none", "no JSON-LD found in any page. Artist/release/event markup is what powers search and social previews.")
else:
    add("INFO", "ldjson", "%d JSON-LD block(s) parsed and checked." % ld_blocks)
for lst, cid, msg in ((no_og, "meta:og", "pages missing Open Graph tags (title/description/image/url)"),
                      (no_canon, "meta:canonical", "pages with no <link rel=canonical>"),
                      (no_desc, "meta:description", "pages with no meta description"),
                      (no_lang, "html:lang", "pages with no <html lang>"),
                      (long_title, "meta:title", "page titles longer than ~65 characters")):
    if lst:
        add("WARN", cid, "%s: %d - %s" % (msg, len(lst), "; ".join(lst[:6]) + ("..." if len(lst) > 6 else "")))
if bad_h1:
    add("WARN", "a11y:h1", "pages without exactly one <h1>: %d - %s" % (len(bad_h1), "; ".join(bad_h1[:6]) + ("..." if len(bad_h1) > 6 else "")))
if img_no_alt:
    add("WARN", "a11y:alt", "%d <img> without alt (artwork needs real alt text): %s" % (len(img_no_alt), "; ".join(img_no_alt[:5])))
if img_no_dims:
    add("WARN", "perf:cls", "%d <img> without width/height - this is the usual cause of layout shift (CLS): %s" % (len(img_no_dims), "; ".join(img_no_dims[:5])))

# ------------------------------------------------- internal links
def resolve(href):
    href = href.split("#")[0].split("?")[0]
    if not href or href.startswith(("http://", "https://", "mailto:", "tel:", "data:", "//", "javascript:")):
        return None
    href = urllib.parse.unquote(href)
    if href.startswith("/"):
        target = href.lstrip("/")
    else:
        target = href  # treated relative to root of output; good enough for a static site check
    if target == "" or target.endswith("/"):
        target = target + "index.html"
    if "." not in os.path.basename(target):
        target = target.rstrip("/") + ".html"
    return target

broken = []
checked = 0
for r in sorted(pages):
    for href in pages[r].anchors:
        t = resolve(href)
        if t is None:
            continue
        checked += 1
        if t in rels or t.lower() in lower or (t.endswith("index.html") and t in rels):
            continue
        # allow an extension-less pretty URL backed by <path>/index.html
        alt = t[:-5] + "/index.html" if t.endswith(".html") else t
        if alt in rels:
            continue
        broken.append("%s (from %s)" % (href, r))
if broken:
    add("WARN", "links:internal", "%d internal link(s) do not resolve to a file in the output: %s" % (len(broken), "; ".join(broken[:8]) + ("..." if len(broken) > 8 else "")))
else:
    add("OK", "links:internal", "all %d internal links resolve inside the output directory." % checked)

# ------------------------------------------------- asset weight
def gz(path):
    try:
        with open(path, "rb") as fh:
            return len(gzip.compress(fh.read(), 6))
    except OSError:
        return 0
js = [(r, sizes[r], gz(os.path.join(root, r))) for r, _, _ in files if r.lower().endswith((".js", ".mjs", ".cjs"))]
css = [(r, sizes[r], gz(os.path.join(root, r))) for r, _, _ in files if r.lower().endswith(".css")]
js_gz = sum(x[2] for x in js); css_gz = sum(x[2] for x in css)
add("INFO", "weight:js", "%d JS file(s): %.0f KB gzipped (budget %d KB)" % (len(js), js_gz / 1024.0, budget_kb))
if js_gz / 1024.0 > budget_kb:
    add("WARN", "weight:budget", "JS is %.0f KB gzipped, over the %d KB budget. A mostly-static music site should need very little JavaScript - look for a framework runtime that is shipping when it need not." % (js_gz / 1024.0, budget_kb))
if css_gz:
    add("INFO", "weight:css", "%d CSS file(s): %.0f KB gzipped" % (len(css), css_gz / 1024.0))
total = sum(sizes.values())
add("INFO", "weight:total", "%d files, %.1f MB total output" % (len(files), total / 1048576.0))
big = sorted(((s, r) for r, _, s in files if s > 1_500_000), reverse=True)
for s, r in big[:8]:
    add("WARN", "weight:file", "%s is %.1f MB. Serve sized variants (srcset/AVIF/WebP) and keep release audio as short previews." % (r, s / 1048576.0))

# ------------------------------------------------- live URL checks (optional)
if base_url:
    b = base_url.rstrip("/")
    def curl(args):
        try:
            out = subprocess.run(["curl", "-sS", "--max-time", "15", "-o", "/dev/null", "-w", "%{http_code}", *args],
                                 capture_output=True, text=True, timeout=25)
            return out.stdout.strip() or "000"
        except Exception:
            return "000"
    code = curl([b + "/"])
    if code == "200":
        add("OK", "live:home", "%s/ answered 200" % b)
    else:
        add("FAIL", "live:home", "%s/ answered %s (expected 200)." % (b, code))
    # is the deployed home page really this build?
    idx = next((r for r in ("index.html",) if r in rels), None)
    if idx:
        try:
            got = subprocess.run(["curl", "-sS", "--compressed", "--max-time", "20", b + "/"], capture_output=True, timeout=30).stdout
            local = open(os.path.join(root, idx), "rb").read()
            h = lambda data: hashlib.sha256(data).hexdigest()[:16]
            if h(got) == h(local):
                add("OK", "live:hash", "the deployed / is byte-identical to %s (sha256 %s...)" % (idx, h(got)))
            else:
                add("WARN", "live:hash", "deployed / does NOT match %s: local %s (sha256 %s...) vs served %s (sha256 %s...). Either the deploy is stale, a CDN is serving a cached copy, or the server rewrites HTML. Verify before announcing." % (idx, len(local), h(local), len(got), h(got)))
        except Exception as e:
            add("INFO", "live:hash", "could not compare the deployed page (%s)" % e)
    miss = curl([b + "/definitely-not-a-real-path-1234/"])
    if miss == "404":
        add("OK", "live:404", "unknown paths return a real 404")
    elif miss == "200":
        add("WARN", "live:404", "unknown paths return 200 - a catch-all/SPA fallback serves your home page for every wrong URL. Search engines index that as a soft 404.")
    else:
        add("INFO", "live:404", "unknown path returned %s" % miss)
    for extra in ("/robots.txt", "/sitemap.xml"):
        if extra.strip("/") in rels or extra.strip("/") in lower:
            c = curl([b + extra])
            add("OK" if c == "200" else "WARN", "live" + extra, "%s%s answered %s" % (b, extra, c))
    if present("robots.txt"):
        try:
            rb = open(os.path.join(root, "robots.txt"), errors="replace").read()
            if re.search(r"(?im)^\s*Disallow:\s*/\s*$", rb):
                add("FAIL", "robots:blocking", "robots.txt contains 'Disallow: /' - that tells crawlers to ignore the entire site.")
        except OSError:
            pass

# ------------------------------------------------- output
order = {"FAIL": 0, "WARN": 1, "OK": 2, "INFO": 3}
F.sort(key=lambda f: order.get(f[0], 9))
counts = {}
for lvl, _, _ in F:
    counts[lvl] = counts.get(lvl, 0) + 1
if maxf:
    F = F[:maxf]

if mode == "json":
    print(json.dumps({"tool": "site-audit", "dir": root, "url": base_url, "summary": counts,
                      "findings": [{"level": l, "id": i, "message": m} for l, i, m in F]}, indent=2))
else:
    print("site-audit - read-only (nothing was changed)")
    print("  dir: %s%s" % (root, (" | live: " + base_url) if base_url else ""))
    print("  %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(counts.items(), key=lambda kv: order.get(kv[0], 9))))
    print("")
    for lvl, cid, msg in F:
        print("[%s] %s: %s" % (lvl, cid, msg))
    print("")
    print("[FAIL] = do not publish until fixed. [WARN] = fix before announcing. [OK]/[INFO] = context.")
    print("This is a static check: it cannot see runtime behaviour, real Core Web Vitals, or how a")
    print("player behaves with a keyboard. Test those in a browser.")

sys.exit(1 if (strict and counts.get("FAIL")) else 0)
PY
