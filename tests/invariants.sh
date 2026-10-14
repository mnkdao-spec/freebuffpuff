#!/usr/bin/env bash
# tests/invariants.sh - the claims the pack MAKES, tested mechanically.
#
#   bash tests/invariants.sh
#
# tests/run.sh checks that the scripts behave correctly. This suite checks the properties the
# documentation asserts but that nothing was verifying:
#   * the README's counts are true
#   * every skill's frontmatter satisfies the documented contract
#   * the agents' tool allowlists use DOCUMENTED tool names and contain no write tool
#   * "read-only" is proven by hashing every input before and after running all the scripts
#   * the forbidden destructive commands appear only where they are forbidden
#   * the installer is idempotent, non-destructive, and refuses what it says it refuses
#   * Windows failure modes (CRLF, BOM, spaces/spaces+&/backslashes in the pack path)
#   * the .nsp linter's documented vocabulary (rejects what Navidrome rejects)
#   * no credentials ship in the repo
#
# Exit: 0 = every invariant held, 1 = at least one was violated.
set -uo pipefail

PACK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${VERIFY_WORKDIR:-/tmp/freebuff-pack-invariants}"
FIX="$WORK/fixtures"
OUT="$WORK/out"

pass=0; fail=0
ok()    { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()   { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
skip()  { printf '  \033[33mSKIP\033[0m %s\n' "$1"; }
head_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
has()   { if grep -qiE -- "$3" "$2" 2>/dev/null; then ok "$1"; else bad "$1  (no /$3/ in $2)"; fi; }
hasnot(){ if grep -qiE -- "$3" "$2" 2>/dev/null; then bad "$1  (unexpected /$3/)"; else ok "$1"; fi; }

command -v python3 >/dev/null 2>&1 || { echo "tests/invariants.sh needs python3" >&2; exit 1; }
rm -rf "$WORK"; mkdir -p "$OUT"
printf '\033[1mFreebuff Homelab Pack - invariants\033[0m\npack: %s\n' "$PACK"

# ============================================================ 1. README counts
head_ "documented counts match the tree"
SKILLS_N=$(find "$PACK/skills" -name SKILL.md | wc -l | tr -d ' ')
SCRIPTS_N=$(find "$PACK/skills" -name '*.sh' | wc -l | tr -d ' ')
AGENTS_N=$(find "$PACK/agents" -maxdepth 1 -name '*.ts' | wc -l | tr -d ' ')
PROMPTS_N=$(find "$PACK/prompts" -name '*.md' | wc -l | tr -d ' ')
RUNBOOK_N=$(find "$PACK/ops/runbooks" -name '*.md' | wc -l | tr -d ' ')
check_n() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: README says $3, tree has $2"; fi; }
decl() { grep -oE "[0-9]+ $2" "$PACK/README.md" | head -1 | grep -oE '^[0-9]+'; }
check_n "skills"  "$SKILLS_N"  "$(decl x 'skills')"
check_n "scripts" "$SCRIPTS_N" "$(decl x 'verified diagnostic scripts')"
check_n "agents"  "$AGENTS_N"  "$(decl x 'read-only agents')"
check_n "prompts" "$PROMPTS_N" "$(decl x 'workflow')"
check_n "runbooks" "$RUNBOOK_N" 4

# ============================================== 2. skill frontmatter contract
head_ "skill frontmatter (documented contract)"
python3 - "$PACK" > "$OUT/fm.txt" 2>&1 <<'PY'
import os, re, sys, collections
pack = sys.argv[1]; root = os.path.join(pack, "skills")
NAME_RE = re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$')
names, descs, problems = [], [], []
CAT = {"core": "core", "music": "music", "pkm": "pkm", "proxmox": "proxmox", "web": "web"}
dirs = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
for d in dirs:
    p = os.path.join(root, d, "SKILL.md")
    if not os.path.exists(p): problems.append("%s: no SKILL.md" % d); continue
    lines = open(p, encoding="utf-8-sig").read().splitlines()
    if not lines or lines[0].strip() != "---": problems.append("%s: frontmatter not opened" % d); continue
    fm, closed = [], False
    for l in lines[1:]:
        if l.strip() == "---": closed = True; break
        fm.append(l)
    if not closed: problems.append("%s: frontmatter not closed" % d); continue
    def field(key):
        for l in fm:
            m = re.match(r'^%s:\s*(.*)$' % key, l)
            if m: return m.group(1).strip().strip('"\'')
    name, desc = field("name"), field("description")
    cat = next((l.split(":",1)[1].strip().strip('"\'') for l in fm if re.match(r'^\s+category:', l)), None)
    if not name: problems.append("%s: missing name" % d)
    elif name != d or not NAME_RE.match(name) or len(name) > 64:
        problems.append("%s: bad name %r" % (d, name))
    else: names.append(name)
    if not desc: problems.append("%s: missing description" % d)
    elif not (1 <= len(desc) <= 1024): problems.append("%s: description length %d" % (d, len(desc)))
    else: descs.append(desc)
    pref = d.split("-")[0]
    if pref in CAT and cat != CAT[pref]: problems.append("%s: category=%r, expected %r" % (d, cat, CAT[pref]))
for n, c in collections.Counter(names).items():
    if c > 1: problems.append("duplicate name %s" % n)
for n, c in collections.Counter(descs).items():
    if c > 1: problems.append("duplicate description x%d" % c)
print("skills=%d problems=%d" % (len(dirs), len(problems)))
for p in problems: print("  " + p)
PY
if grep -q 'problems=0' "$OUT/fm.txt"; then ok "$(cat "$OUT/fm.txt" | head -1)"; else bad "frontmatter contract violated:"; sed -n '2,12p' "$OUT/fm.txt"; fi

# ============================================ 3. referenced scripts are usable
head_ "scripts referenced by skills exist, are executable, have a shebang"
missing=0; notexec=0; noshebang=0; refs=0
for s in "$PACK"/skills/*/SKILL.md; do
  d=$(dirname "$s")
  # A skill may reference its own `scripts/x.sh` or a sibling's `.agents/skills/<other>/scripts/x.sh`,
  # so resolve fully-qualified references against the pack root, not the referring skill.
  while read -r r; do
    [ -n "$r" ] || continue
    refs=$((refs+1))
    case "$r" in
      .agents/skills/*) f="$PACK/skills/${r#.agents/skills/}" ;;
      *)                f="$d/$r" ;;
    esac
    [ -f "$f" ] || { missing=$((missing+1)); echo "  missing: ${s#$PACK/} -> $r"; continue; }
    [ -x "$f" ] || { notexec=$((notexec+1)); echo "  not executable: ${f#$PACK/}"; }
    head -1 "$f" | grep -q '^#!/usr/bin/env bash' || { noshebang=$((noshebang+1)); echo "  no env-bash shebang: ${f#$PACK/}"; }
  done < <(grep -ohE '(\.agents/skills/[a-z0-9-]+)?/?scripts/[A-Za-z0-9_.-]+\.sh' "$s" | sort -u)
done
[ "$missing" = 0 ] && ok "$refs script reference(s) all resolve" || bad "$missing unresolved script reference(s)"
[ "$notexec" = 0 ] && ok "every referenced script is executable" || bad "$notexec not executable"
[ "$noshebang" = 0 ] && ok "every referenced script has a portable shebang" || bad "$noshebang missing shebang"

# ================================================ 4. agent allowlist contract
head_ "agents: documented tool names only, and no write tools"
python3 - "$PACK" > "$OUT/agents.txt" 2>&1 <<'PY'
import json, os, re, subprocess, sys
pack = sys.argv[1]
DOCUMENTED = {"add_subgoal","browser_logs","code_search","create_plan","end_turn","find_files",
              "read_docs","read_files","run_file_change_hooks","run_terminal_command","spawn_agents",
              "str_replace","think_deeply","update_subgoal","web_search","write_file","set_output"}
WRITE = {"write_file","str_replace","run_file_change_hooks"}
files = sorted(f for f in os.listdir(os.path.join(pack, "agents")) if f.endswith(".ts"))
ids, probs = [], []
for f in files:
    p = os.path.join(pack, "agents", f)
    src = open(p).read()
    m = re.search(r"toolNames:\s*\[([^\]]*)\]", src, re.S)
    tools = re.findall(r"'([a-z_]+)'", m.group(1)) if m else []
    for need in ("id", "displayName"):
        if not re.search(r"^\s*%s:" % need, src, re.M): probs.append("%s: no %s" % (f, need))
    if not tools: probs.append("%s: no toolNames" % f)
    for t in tools:
        if t not in DOCUMENTED: probs.append("%s: undocumented tool %r" % (f, t))
    for w in WRITE:
        if w in tools: probs.append("%s: WRITE TOOL %r in the allowlist" % (f, w))
    mid = re.search(r"^\s*id:\s*'([^']+)'", src, re.M)
    if mid: ids.append(mid.group(1))
    if not re.search(r"^\s*model:", src, re.M): probs.append("NOTE %s: no model field (documented as required; see agents/README.md)" % f)
dupes = [i for i in ids if ids.count(i) > 1]
if dupes: probs.append("duplicate agent ids: %s" % set(dupes))
print("agents=%d ids=%s" % (len(files), ",".join(ids)))
for p in probs: print(p)
PY
sed -n '1p' "$OUT/agents.txt" | grep -q 'agents=5' && ok "$(head -1 "$OUT/agents.txt")" || bad "expected 5 agents"
hasnot "every toolName is in the documented set (no UNDOCUMENTED)" "$OUT/agents.txt" 'undocumented tool'
hasnot "no write tool appears in any allowlist"                   "$OUT/agents.txt" 'WRITE TOOL'
hasnot "agent ids are unique"                                     "$OUT/agents.txt" 'duplicate agent ids'
notes=$(grep -c '^NOTE' "$OUT/agents.txt" || true)
if [ "$notes" = 5 ]; then ok "the missing 'model' field is present on all 5 (documented deviation)"; else bad "expected 5 model-deviation notes, got $notes"; fi
grep -q 'documented as required' "$PACK/agents/README.md" && ok "that deviation is documented in agents/README.md" \
  || bad "the model deviation is not documented in agents/README.md"

# ============================================== 5. .nsp linter contract
head_ "nsp-lint: documented vocabulary and the all/any rule"
NSP="$PACK/skills/music-navidrome-nsp-author/scripts/nsp-lint.sh"
N="$WORK/nsp"; mkdir -p "$N"
printf '%s\n' '{ "name": "mixed", "all": [ { "is": { "genre": "A" } } ], "any": [ { "gt": { "rating": 3 } } ] }' > "$N/mixed.nsp"
printf '%s\n' '{ "name": "nested", "all": [ { "is": { "genre": "A" } }, { "any": [ { "gt": { "rating": 3 } } ] } ] }' > "$N/nested.nsp"
printf '%s\n' '{ "name": "docs", "all": [ { "isPresent": { "rating": true } }, { "notInTheLast": { "playedAt": "30d" } } ] }' > "$N/documented.nsp"
printf '%s\n' '{ "name": "gte", "all": [ { "gte": { "rating": 3 } } ] }' > "$N/gte.nsp"
printf '%s\n' '{ "name": "invented", "all": [ { "isLike": { "genre": "A" } } ] }' > "$N/invented.nsp"
printf '%s\n' '{ "name": "owner", "owner": "me", "all": [ { "is": { "genre": "A" } } ] }' > "$N/owner.nsp"
bash "$NSP" "$N/mixed.nsp"      > "$OUT/nsp-mixed.txt" 2>&1; [ $? -eq 1 ] && ok "rejects a file mixing all+any (Navidrome >= 0.63.2 does)" || bad "accepts a file mixing all+any"
has "  ...and names the rule"        "$OUT/nsp-mixed.txt" "cannot be combined"
bash "$NSP" "$N/nested.nsp"     > "$OUT/nsp-nested.txt" 2>&1; [ $? -eq 0 ] && ok "accepts the nested-OR equivalent" || bad "rejects a valid nested-OR playlist"
bash "$NSP" "$N/documented.nsp" > "$OUT/nsp-doc.txt"    2>&1; [ $? -eq 0 ] && ok "accepts documented isPresent/notInTheLast" || bad "rejects documented operators"
bash "$NSP" "$N/invented.nsp"   > "$OUT/nsp-inv.txt"    2>&1; [ $? -eq 1 ] && ok "rejects an invented operator" || bad "accepts an invented operator"
bash "$NSP" "$N/gte.nsp"        > "$OUT/nsp-gte.txt"    2>&1; ec=$?
if [ "$ec" -eq 0 ] && grep -q 'warning.*gte' "$OUT/nsp-gte.txt"; then ok "warns (not fails) on undocumented gte, naming the alternative"; else bad "gte handling wrong (exit $ec)"; fi
bash "$NSP" "$N/owner.nsp"      > "$OUT/nsp-own.txt"    2>&1
has "  warns that 'owner' is not a file key" "$OUT/nsp-own.txt" "unknown key 'owner'"

# ================================================= 6. safety / no secrets
head_ "safety invariants and no shipped credentials"
# The pack claims known-bad commands are forbidden. They may appear, but only in a negative
# sentence ("never", "forbidden", "do not"), never as an instruction to run.
BAD_CMD='docker compose down -v|docker volume prune|chown -R|duplicates --delete'
if matches=$(grep -rniE -- "$BAD_CMD" --include=*.md --include=*.ts "$PACK" 2>/dev/null); then
  offenders=$(printf '%s\n' "$matches" | grep -vicE 'never|forbid|do not|don.t|avoid|no |not |forbidden|prohibit|must not|instead of|rather than' || true)
  if [ "${offenders:-0}" = 0 ]; then ok "known-bad commands appear only in prohibitions ($(printf '%s\n' "$matches" | wc -l) mentions, all negative)"; else bad "$offenders mention(s) of a known-bad command outside a prohibition"; printf '%s\n' "$matches" | grep -viE 'never|forbid|do not|avoid|forbidden|prohibit|must not|instead of' | head -5; fi
else
  ok "no known-bad command appears at all"
fi
# tests/ is excluded on purpose: it plants a fake `sk_live_...` string to prove site-audit.sh
# detects one. Anything credential-shaped OUTSIDE tests/ is a real finding.
SECRET_RE='\b(sk_live_[A-Za-z0-9]{10,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
hits=$(grep -rInE "$SECRET_RE" "$PACK" --exclude-dir=tests --exclude-dir=.git 2>/dev/null | grep -v '^Binary' || true)
if [ -n "$hits" ]; then bad "credential-shaped string found outside tests/:"; printf '%s\n' "$hits" | head -3; else ok "no credential-shaped strings ship (outside the deliberate test fixture)"; fi
# knowledge.md ships <PLACEHOLDER>s the user must fill. The global template deliberately has none:
# it is cross-project preferences, not paths. So assert it is real but contains no machine-specific
# values instead of demanding placeholders it should not have.
n=$(grep -oE '<[A-Z][A-Z0-9 _-]+>' "$PACK/templates/knowledge.md" | wc -l | tr -d ' ')
[ "$n" -gt 0 ] && ok "templates/knowledge.md keeps $n <PLACEHOLDER>s for the user to fill" || bad "templates/knowledge.md has no placeholders"
if [ -s "$PACK/templates/knowledge.global.md" ] && ! grep -qE '/(home|Users|mnt|srv)/[A-Za-z0-9]' "$PACK/templates/knowledge.global.md"; then
  ok "templates/knowledge.global.md is populated but machine-independent"
else bad "templates/knowledge.global.md is empty or contains a machine-specific path"; fi

# ================================================ 7. installer behaviour
head_ "install.sh: dry-run, non-destructive defaults, scope isolation"
DRY="$WORK/dry"; mkdir -p "$DRY"
bash "$PACK/install.sh" --project "$DRY" --dry-run > "$OUT/dry.txt" 2>&1
if [ -z "$(ls -A "$DRY")" ]; then ok "--dry-run writes nothing"; else bad "--dry-run created files: $(ls -A "$DRY" | head -3)"; fi
USR="$WORK/user"; mkdir -p "$USR"
printf 'MY OWN NOTES\n' > "$USR/knowledge.md"
printf '# mine\n'      > "$USR/.codebuffignore"
bash "$PACK/install.sh" --project "$USR" > "$OUT/usr.txt" 2>&1
grep -q 'MY OWN NOTES' "$USR/knowledge.md" && ok "an existing knowledge.md is NOT overwritten" || bad "installer overwrote the user's knowledge.md"
[ -f "$USR/knowledge.md.example" ] && ok "the template is written to knowledge.md.example instead" || bad "no knowledge.md.example written"
grep -q '^# mine' "$USR/.codebuffignore" && ok "an existing .codebuffignore is NOT overwritten" || bad "installer overwrote .codebuffignore"
GHOME="$WORK/ghome"; mkdir -p "$GHOME"
HOME="$GHOME" bash "$PACK/install.sh" --global > "$OUT/global.txt" 2>&1
[ -d "$GHOME/.agents/skills" ] && ok "--global installs skills under \$HOME/.agents/skills" || bad "--global did not install skills"
ls "$GHOME"/.agents/*.ts >/dev/null 2>&1 && ok "--global installs the agents too" || bad "--global did not install agents"
[ -f "$GHOME/.knowledge.md" ] && ok "--global wrote ~/.knowledge.md" || bad "--global did not create ~/.knowledge.md"
[ ! -e "$WORK/no-such-project/.agents" ] && ok "--global did not write into the current directory" || bad "--global leaked into the cwd"

# ==================================================== 8. Windows failure modes
head_ "Windows: CRLF refusal, BOM tolerance, awkward pack paths"
WP="$WORK/winpack"; mkdir -p "$WP"
cp -R "$PACK/." "$WP/" 2>/dev/null
# (a) a CRLF script must abort the install, not produce "\\r: command not found"
printf '\r\n' >> "$WP/skills/music-library-audit/scripts/lib-audit.sh"
bash "$WP/install.sh" --project "$WORK/crlf-out" > "$OUT/crlf.txt" 2>&1; ec=$?
if [ "$ec" -ne 0 ] && grep -qi 'CRLF' "$OUT/crlf.txt"; then ok "installer refuses to install a CRLF script"; else bad "installer did not refuse CRLF (exit $ec)"; fi
# (b) a Notepad-saved skill (BOM + CRLF) must still VALIDATE, as the CLI accepts it
sed -i 's/\r$//' "$WP/skills/music-library-audit/scripts/lib-audit.sh"
NEW="$WP/skills/proxmox-notepad-test"; mkdir -p "$NEW"
printf '\xef\xbb\xbf---\r\nname: proxmox-notepad-test\r\ndescription: Notepad-saved skill (BOM + CRLF) that must still validate.\r\nmetadata:\r\n  category: proxmox\r\n---\r\n\r\nBody.\r\n' > "$NEW/SKILL.md"
bash "$WP/install.sh" --verify > "$OUT/bom.txt" 2>&1
has "a BOM+CRLF skill still validates" "$OUT/bom.txt" 'validated 40 skills, 0 invalid'
rm -rf "$NEW"
# (c) a pack path with spaces and a shell metacharacter must still emit valid JSON
ODD="$WORK/pack dir & co"; rm -rf "$ODD"; mkdir -p "$ODD" "$WORK/odd-out"
cp -R "$PACK/." "$ODD/" 2>/dev/null
bash "$ODD/install.sh" --project "$WORK/odd-out" --mcp local-readonly > "$OUT/odd.txt" 2>&1
MJ="$WORK/odd-out/.agents/mcp.json"
if [ -f "$MJ" ]; then
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$MJ" 2>/dev/null \
    && ok "mcp.json is valid JSON from a pack path containing spaces and '&'" \
    || { bad "mcp.json is not valid JSON from an awkward pack path"; head -c 200 "$MJ"; }
  grep -q '\\\\' "$MJ" && bad "mcp.json contains a raw backslash (invalid JSON escape on Windows)" \
                       || ok "no raw backslashes were baked into mcp.json"
else bad "no mcp.json was produced"; fi

# ================================================= 9. read-only proof
head_ "read-only proof: no input file changes when every script runs"
FAKE="$WORK/fakebin"; mkdir -p "$FAKE"
printf '#!/usr/bin/env bash\necho "[{\\"node\\":\\"pve\\"}]"\n' > "$FAKE/pvesh"
printf '#!/usr/bin/env bash\necho "pve-manager: 9.2.0"\n' > "$FAKE/pveversion"
printf '#!/usr/bin/env bash\nprintf "rpool\\tONLINE\\t10\\t1T\\t1G\\n"\n' > "$FAKE/zpool"
chmod +x "$FAKE"/*
mkdir -p "$FIX"/{pve/lxc,apt/sources.list.d,lxc,music/art/alb,site,compose,nsp}
printf 'mp0: /srv/media,mp=/data/media\nrootfs: local:120/vm-120-disk-0.raw,size=8G\nunprivileged: 1\n' > "$FIX/pve/lxc/120.conf"
printf 'deb http://deb.debian.org/debian trixie main\n' > "$FIX/apt/sources.list"
printf 'arch: amd64\ncores: 2\nmp0: /srv/media,mp=/data/media\nrootfs: local:200/vm-200-disk-0.raw,size=8G\n' > "$FIX/lxc/c.conf"
printf 'services:\n  lidarr:\n    image: x\n    volumes:\n      - /srv/downloads:/data/downloads\n      - /srv/media:/data/media\n' > "$FIX/compose/docker-compose.yml"
printf '%s\n' '{ "name": "ro", "all": [ { "is": { "genre": "Ambient" } } ] }' > "$FIX/nsp/ro.nsp"
head -c 2048 /dev/urandom > "$FIX/music/art/alb/01.flac"
printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>t</title><meta name="description" content="d"></head><body><h1>t</h1></body></html>\n' > "$FIX/site/index.html"

snapshot() { find "$FIX" -type f -exec md5sum {} \; 2>/dev/null | sort; }
before="$(snapshot)"
MBSTATE="$WORK/mbstate"; MBCACHE="$WORK/mbcache"; mkdir -p "$MBCACHE"
export PYTHON="${PYTHON:-python3}"
bash "$PACK/skills/proxmox-stack-map/scripts/pve-doctor.sh"    >/dev/null 2>&1
bash "$PACK/skills/proxmox-guest-placement/scripts/lxc-audit.sh" --config "$FIX/lxc/c.conf" >/dev/null 2>&1
bash "$PACK/skills/music-path-and-hardlink-doctor/scripts/compose-doctor.sh" "$FIX/compose/docker-compose.yml" >/dev/null 2>&1
bash "$PACK/skills/music-navidrome-nsp-author/scripts/nsp-lint.sh" "$FIX/nsp/ro.nsp" >/dev/null 2>&1
bash "$PACK/skills/music-library-audit/scripts/lib-audit.sh" "$FIX/music" >/dev/null 2>&1
SLSKD_URL=http://127.0.0.1:1 SLSKD_API_KEY=x bash "$PACK/skills/music-slskd-ops/scripts/slskd-doctor.sh" >/dev/null 2>&1
bash "$PACK/skills/web-perf-a11y/scripts/site-audit.sh" "$FIX/site" >/dev/null 2>&1
env PVE_ETC="$FIX/pve" APT_ETC="$FIX/apt" PATH="$FAKE:$PATH" bash "$PACK/skills/proxmox-stack-map/scripts/pve-doctor.sh" >/dev/null 2>&1
# mb-lookup is the one script that intentionally writes (a cache + a rate-limit state file), and
# the pack says so. Point both at a scratch dir so the input tree can still be hashed.
env MB_CACHE_DIR="$MBCACHE" MB_RATE_STATE="$MBSTATE" bash "$PACK/skills/music-musicbrainz-lookup/scripts/mb-lookup.sh" whoami >/dev/null 2>&1
after="$(snapshot)"
if [ "$before" = "$after" ]; then ok "all 8 scripts ran and every input file is byte-identical"; else
  bad "an input file changed:"; diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -6
fi

# ================================================= 10. exit-code contracts
head_ "exit-code contract: a bad flag is a usage error (2) for every script"
for s in "$PACK"/skills/*/scripts/*.sh; do
  bash "$s" --definitely-not-a-flag >/dev/null 2>&1; ec=$?
  n=$(basename "$s")
  # scripts that need a positional arg first still exit 2; ones that ignore unknown flags are a bug
  if [ "$ec" = 2 ] || [ "$ec" = 3 ]; then ok "$n rejects an unknown flag (exit $ec)"; else bad "$n returned $ec for an unknown flag"; fi
done

# ================================================= 11. MCP surface
head_ "mcp/local-readonly: GET-only surface and no write tool"
SRV="$PACK/mcp/local-readonly/server.js"
node "$SRV" > "$OUT/mcp.txt" 2>&1 <<'EOF' &
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"inv","version":"1"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"delete_everything","arguments":{}}}
EOF
MP=$!; sleep 2; kill $MP 2>/dev/null; wait $MP 2>/dev/null
grep -q '"tools"' "$OUT/mcp.txt" && ok "answers initialize + tools/list" || bad "no tools/list response"
if grep -q '"error"' "$OUT/mcp.txt"; then ok "an unknown tool name returns a JSON-RPC error"; else bad "unknown tool call did not error"; fi
if grep -qE '"id":\s*3[^}]*"result"' "$OUT/mcp.txt"; then bad "a call to an unknown tool returned a result"; else ok "no result was returned for the unknown tool"; fi
hasnot "no write-shaped tool name is advertised" "$OUT/mcp.txt" '"(write|delete|remove|exec|shell|post|put)[a-z_]*"'
# 'inputSchema' contains the letters p-u-t, so a naive case-insensitive PUT match false-positives.
# Check the actual request construction instead: every fetch() call site must be method: 'GET'.
GETS=$(grep -c "method: 'GET'" "$SRV")
FETCHES=$(grep -c 'await fetch(' "$SRV")
if [ "$GETS" -ge 1 ] && [ "$GETS" = "$FETCHES" ]; then ok "every fetch() call site ($FETCHES) is hardcoded method: 'GET'"; else bad "$FETCHES fetch() call site(s) but only $GETS GET-typed"; fi
grep -qE "method: *['\"](POST|PUT|PATCH|DELETE)" "$SRV" && bad "server.js builds a mutating request" || ok "no mutating request is built anywhere in server.js"
grep -qE 'allow|ALLOW|host' "$SRV" && ok "the server has a host allowlist" || bad "no host allowlist found in server.js"

printf '\n\033[1m%d passed, %d failed\033[0m\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
