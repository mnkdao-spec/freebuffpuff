#!/usr/bin/env bash
# Freebuff Homelab Pack — installer
# Installs skills into .agents/skills (project) and/or ~/.agents/skills (global).
# Idempotent, non-destructive by default, and validates every skill before copying.
set -euo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$PACK_DIR/skills"
SCOPE=""; PROJECT_DIR=""; DO_GLOBAL=0; DO_PROJECT=0
MCP_NAME=""; FORCE=0; DRY=0; VERIFY_ONLY=0
NAME_RE='^[a-z0-9]+(-[a-z0-9]+)*$'

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
act() { if [ "$DRY" = 1 ]; then say "  [dry-run] $*"; else say "  $*"; fi; }

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  cat <<'USAGE'
Scopes (default: --project .):
  --project [DIR]   install into DIR (default: current directory)
  --global          install into $HOME (skills -> ~/.agents/skills)
  --both            install into both the current directory and $HOME
Options:
  --mcp NAME        install mcp/NAME.json as .agents/mcp.json (never overwrites)
  --force           overwrite existing skill files
  --dry-run         print what would happen, change nothing
  --verify          validate the pack's skills only (frontmatter, naming, description)
  -h, --help        this message
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project) DO_PROJECT=1; if [ $# -ge 2 ] && [ "${2#--}" = "$2" ]; then PROJECT_DIR="$2"; shift; fi ;;
    --global)  DO_GLOBAL=1 ;;
    --both)    DO_PROJECT=1; DO_GLOBAL=1 ;;
    --mcp)     [ $# -ge 2 ] || die "--mcp needs a name (see mcp/README.md)"; MCP_NAME="$2"; shift ;;
    --force)   FORCE=1 ;;
    --dry-run) DRY=1 ;;
    --verify)  VERIFY_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$PWD"
[ "$DO_PROJECT" = 1 ] || [ "$DO_GLOBAL" = 1 ] || { DO_PROJECT=1; PROJECT_DIR="$PWD"; }

# --- skill validation -------------------------------------------------------
# Mirrors the CLI's own rules: YAML frontmatter, name matches directory,
# name is 1-64 lowercase alnum with single hyphens, description present (<=1024).
validate_skill() {
  local dir="$1" base name desc problems=""
  base="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || { echo "$base: missing SKILL.md"; return 1; }
  head -1 "$dir/SKILL.md" | grep -q '^---[[:space:]]*$' || problems="$problems frontmatter-does-not-start-with---;"
  local close
  close="$(awk 'NR>1 && /^---[[:space:]]*$/{print NR; exit}' "$dir/SKILL.md")"
  [ -n "$close" ] || problems="$problems frontmatter-not-closed;"
  name="$(awk 'NR>1 && /^---[[:space:]]*$/{exit} /^name:/{sub(/^name:[[:space:]]*/,""); gsub(/^["'"'"']|["'"'"'][[:space:]]*$/,""); print; exit}' "$dir/SKILL.md")"
  desc="$(awk 'NR>1 && /^---[[:space:]]*$/{exit} /^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$dir/SKILL.md")"
  [ -n "$name" ] || problems="$problems missing-name;"
  [ -n "$desc" ] || problems="$problems missing-description;"
  if [ -n "$name" ]; then
    case "$name" in *[!a-z0-9-]*) problems="$problems name-has-invalid-chars;" ;; esac
    echo "$name" | grep -Eq "$NAME_RE" || problems="$problems name-regex;" 
    [ "${#name}" -le 64 ] || problems="$problems name-too-long;"
    [ "$name" = "$base" ] || problems="$problems name($name)!=dirname($base);"
  fi
  if [ -n "$desc" ] && [ "${#desc}" -gt 1024 ]; then problems="$problems description-too-long;"; fi
  if [ -n "$problems" ]; then echo "$base:$problems"; return 1; fi
  return 0
}

verify_pack() {
  local bad=0 total=0 f
  while IFS= read -r -d '' f; do
    total=$((total+1))
    if ! out="$(validate_skill "$(dirname "$f")")"; then bad=$((bad+1)); say "  INVALID $out"; fi
  done < <(find "$SKILLS_SRC" -name SKILL.md -print0 | sort -z)
  say "validated $total skills, $bad invalid"
  [ "$bad" = 0 ]
}

# --- installers -------------------------------------------------------------
copy_skill() {
  local src="$1" dest_root="$2" name dest
  name="$(basename "$src")"; dest="$dest_root/$name"
  if [ -d "$dest" ] && [ "$FORCE" != 1 ]; then act "skip (exists): $dest"; return 0; fi
  act "install skill: $name"
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
}

install_skills() {
  local dest_root="$1" f
  act "skills -> $dest_root"
  [ "$DRY" = 1 ] || mkdir -p "$dest_root"
  while IFS= read -r -d '' f; do copy_skill "$(dirname "$f")" "$dest_root"; done \
    < <(find "$SKILLS_SRC" -name SKILL.md -print0 | sort -z)
}

install_support() {
  local ops_dir="$1" prompts_dir="$2" f d
  act "support files -> $ops_dir and $prompts_dir"
  [ "$DRY" = 1 ] && return 0
  mkdir -p "$ops_dir/runbooks" "$prompts_dir"
  for f in "$PACK_DIR"/ops/*.md; do [ -e "$ops_dir/$(basename "$f")" ] || cp "$f" "$ops_dir/"; done
  for f in "$PACK_DIR"/ops/runbooks/*.md; do [ -e "$ops_dir/runbooks/$(basename "$f")" ] || cp "$f" "$ops_dir/runbooks/"; done
  for f in "$PACK_DIR"/prompts/*.md; do [ -e "$prompts_dir/$(basename "$f")" ] || cp "$f" "$prompts_dir/"; done
}

install_knowledge() {
  local target="$1" template="$2"
  if [ -e "$target" ]; then
    act "keep existing $(basename "$target") (template written to $target.example — merge manually)"
    [ "$DRY" = 1 ] || [ -e "$target.example" ] || cp "$template" "$target.example"
  else
    act "create $target from template"
    [ "$DRY" = 1 ] || cp "$template" "$target"
  fi
}

install_agents_symlink() {
  local dir="$1"
  if [ -L "$dir/AGENTS.md" ] || [ -e "$dir/AGENTS.md" ]; then act "keep existing $dir/AGENTS.md"; return 0; fi
  if [ ! -e "$dir/knowledge.md" ]; then act "skip AGENTS.md symlink (no knowledge.md in $dir)"; return 0; fi
  act "symlink $dir/AGENTS.md -> knowledge.md"
  [ "$DRY" = 1 ] || ln -s knowledge.md "$dir/AGENTS.md"
}

install_codebuffignore() {
  local dir="$1"
  local src="$PACK_DIR/templates/codebuffignore"
  local target="$dir/.codebuffignore"
  local missing=0
  local line
  if [ ! -e "$target" ]; then act "create $dir/.codebuffignore"; [ "$DRY" = 1 ] || cp "$src" "$target"; return 0; fi
  say "  .codebuffignore exists — checking for missing entries:"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    if ! grep -qxF "$line" "$target" 2>/dev/null; then say "    missing: $line"; missing=$((missing+1)); fi
  done < "$src"
  [ "$missing" = 0 ] && say "    nothing missing" || say "    add the lines above yourself (not modifying your file)"
}

install_mcp() {
  local dest_dir="$1"
  [ -n "$MCP_NAME" ] || return 0
  local src=""
  for cand in "$PACK_DIR/mcp/$MCP_NAME.json" "$PACK_DIR/mcp/$MCP_NAME.readonly.json"; do
    [ -f "$cand" ] && { src="$cand"; break; }
  done
  if [ -z "$src" ]; then
    say "no such mcp fragment: $MCP_NAME"
    say "available fragments:"
    for f in "$PACK_DIR"/mcp/*.json; do [ -f "$f" ] && say "  $(basename "$f" .json)"; done
    die "see mcp/README.md"
  fi
  if [ -e "$dest_dir/mcp.json" ]; then
    act "keep existing $dest_dir/mcp.json — merge by hand (fragment follows):"
    [ "$DRY" = 1 ] || sed "s|__PACK_DIR__|$PACK_DIR|g; s/^/    /" "$src"
  else
    act "install $dest_dir/mcp.json (from mcp/$MCP_NAME.readonly.json)"
    if [ "$DRY" != 1 ]; then mkdir -p "$dest_dir"; sed "s|__PACK_DIR__|$PACK_DIR|g" "$src" > "$dest_dir/mcp.json"; fi
    case "$src" in
      *local-readonly*)
        say "    NOTE: every \$VAR this fragment references must be exported before launch,"
        say "          or Freebuff will skip the whole mcp.json:"
        say "          ND_USER ND_TOKEN ND_SALT LIDARR_API_KEY SLSKD_API_KEY MB_USER_AGENT"
        say "    NOTE: path is baked in as $PACK_DIR — re-run the installer if you move the pack." ;;
    esac
  fi
}

# --- run --------------------------------------------------------------------
if [ "$VERIFY_ONLY" = 1 ]; then verify_pack; exit $?; fi

say "Freebuff Homelab Pack -> $PACK_DIR"
say ""
say "validate:"
verify_pack || die "pack validation failed; nothing installed"
say ""

if [ "$DO_PROJECT" = 1 ]; then
  say "PROJECT scope: $PROJECT_DIR"
  [ -d "$PROJECT_DIR" ] || die "project dir does not exist: $PROJECT_DIR"
  install_skills "$PROJECT_DIR/.agents/skills"
  install_support "$PROJECT_DIR/.agents/ops" "$PROJECT_DIR/.agents/prompts"
  install_knowledge "$PROJECT_DIR/knowledge.md" "$PACK_DIR/templates/knowledge.md"
  install_agents_symlink "$PROJECT_DIR"
  install_codebuffignore "$PROJECT_DIR"
  install_mcp "$PROJECT_DIR/.agents"
  say ""
fi

if [ "$DO_GLOBAL" = 1 ]; then
  say "GLOBAL scope: $HOME"
  install_skills "$HOME/.agents/skills"
  install_support "$HOME/.freebuff-pack/ops" "$HOME/.freebuff-pack/prompts"
  install_knowledge "$HOME/.knowledge.md" "$PACK_DIR/templates/knowledge.global.md"
  install_mcp "$HOME/.agents"
  say ""
fi

if [ "$DRY" = 1 ]; then say "dry run: nothing was written."; exit 0; fi

cat <<'NEXT'
Next steps
  1. Edit knowledge.md — fill in every <ANGLE BRACKET> with your real paths, service
     names, ports and commands. This file is the only always-loaded context; keep it short.
  2. Skills under .agents/skills/ need no trust prompt. MCP servers do: the first run asks
     "Load and run these? [y/N]" and shows the exact commands. Only answer y for configs you
     have read. For a scripted/CI-ish run use:  freebuff --trust-agents
     (or export CODEBUFF_TRUST_AGENT_DIRS=1). Decisions persist in
     ~/.config/manicode/trusted-agent-dirs.json.
  3. In the TUI: /skill: to list skills, /plan before big changes, /model and /reasoning to
     control cost, /todo to see the checklist, /history to resume.
  4. Run probe/USER-CHECKLIST.md once to confirm local API reachability and Desktop parity.
NEXT
