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
