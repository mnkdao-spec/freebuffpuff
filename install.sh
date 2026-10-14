#!/usr/bin/env bash
# Freebuff Homelab Pack installer (see repo for full source).
# NOTE: full install.sh is 14.7KB; pushed in parts due to API limits.
set -euo pipefail
PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Freebuff Homelab Pack installer - see USER_GUIDE.md for usage."
echo "Usage: ./install.sh [--project DIR] [--global] [--both] [--mcp NAME] [--force] [--dry-run] [--verify]"
