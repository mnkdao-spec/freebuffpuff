# Freebuff Homelab Pack - User Guide

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Getting Started](#getting-started)
5. [Skills Reference](#skills-reference)
6. [Agents Reference](#agents-reference)
7. [Scripts Reference](#scripts-reference)
8. [Testing & Verification](#testing--verification)
9. [Troubleshooting](#troubleshooting)
10. [Security & Safety](#security--safety)
11. [Windows 11 Usage](#windows-11-usage)
12. [Contributing & Extending](#contributing--extending)
13. [Handoff Guide for New Agents](#handoff-guide-for-new-agents)
14. [Limitations & Known Issues](#limitations--known-issues)

## Overview

The Freebuff Homelab Pack is a collection of production-ready skills, agents, and scripts designed for self-hosted homelab environments. It covers:

- **Music stack**: Navidrome, Lidarr, MusicBrainz integration, library auditing
- **Proxmox VE**: Host management, backups, container operations, upgrade safety
- **Web development**: Static sites with Astro, release pages, structured data
- **PKM (Personal Knowledge Management)**: Obsidian workflows, RAG design, sync choices
- **Safety-first design**: Read-only scripts, non-destructive installer, comprehensive verification

All scripts are designed to be read-only by construction. The installer is non-destructive and won't overwrite your existing configuration files.

## Prerequisites

Before installing, ensure you have:

- **Freebuff CLI/Codebuff** environment (for skills and agents)
- **Bash 4+** (available on Linux, macOS, WSL, Git Bash on Windows)
- **Basic CLI tools**: `jq`, `curl` (for some scripts), `python3` (for verification)
- **Git** (for version control)

For specific domains:

- **MusicBrainz lookup**: Requires internet access; respects rate limiting (1 request/second)
- **Proxmox operations**: Should be run on/against actual Proxmox hosts (tests here used fixtures)
- **Web development**: Node.js if using Astro tooling

## Installation

### Standard Installation

```bash
# Clone the repository
git clone https://github.com/mnkdao-spec/freebuffpuff.git
cd freebuffpuff

# Install to current directory
./install.sh

# Install globally (writes to ~/.config/codebuff/pack)
./install.sh --global

# Dry run to preview changes
./install.sh --dry-run
```

### Installation Options

```bash
# Show help
./install.sh --help

# Verify integrity of installed pack
./install.sh --verify
```

The installer:
- Is non-destructive by default
- Never overwrites `knowledge.md` or `.codebuffignore`
- Creates backups when needed
- Validates all skills and agents before installing
- Works in paths containing spaces and special characters

## Getting Started

After installation:

1. **Verify installation**: Run `./install.sh --verify` - should show all skills and agents as valid
2. **Run the test suites**: See [Testing & Verification](#testing--verification)
3. **Review the safety rules**: All scripts are read-only; no destructive operations
4. **Check the user checklist**: See `probe/USER-CHECKLIST.md` for environment-specific checks

## Skills Reference

The pack includes 39 skills organized by domain. Each skill has a `SKILL.md` with YAML frontmatter, instructions, and safety constraints.

### Music Stack (music-*)

- **music-library-audit**: Audit music libraries for completeness, missing tags, duplicates
- **music-navidrome-nsp-author**: Author Navidrome smart playlists (`.nsp` files)
- **music-musicbrainz-lookup**: Look up releases/albums on MusicBrainz with rate limiting
- **music-lidarr-ops**: Lidarr operational guidance
- **music-slskd-ops**: slskd download operations

**Key Notes**: Navidrome smart playlist operators are validated against current docs. Mixing `all`+`any` at top level is rejected. Shares are public links, not private.

### Proxmox (proxmox-*)

- **proxmox-host-health**: Check host health, disk space, services
- **proxmox-backup-and-restore**: Safe backup/restore procedures with vzdump
- **proxmox-upgrade-safety**: Pre-checks and safe upgrade paths (PVE 8.x -> 9.x)

**Key Notes**: Targets PVE 9.2+, cgroup v1 removed in PVE 9. ARC defaults documented (10%/16 GiB since 8.1). Scripts validated with fixtures, not live hosts.

### Web (web-*)

- **web-site-architect**: Design static sites with content collections
- **web-release-page**: Create music release pages with structured data
- **web-performance-audit**: Core Web Vitals (LCP, INP, CLS) guidance

**Key Notes**: User Astro content collections (defineCollection pattern). CWV thresholds match current web.dev guidance.
