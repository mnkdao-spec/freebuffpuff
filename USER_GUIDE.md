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
git clone https://github.com/freebuffpuff/freebuffpuff.git
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
- **proxmox-upgrade-safety**: Pre-checks and safe upgrade paths (PVE 8.x → 9.x)

**Key Notes**: Targets PVE 9.2+, cgroup v1 removed in PVE 9. ARC defaults documented (10%/16 GiB since 8.1). Scripts validated with fixtures, not live hosts.

### Web (web-*)

- **web-site-architect**: Design static sites with content collections
- **web-release-page**: Create music release pages with structured data
- **web-performance-audit**: Core Web Vitals (LCP, INP, CLS) guidance

**Key Notes**: Uses Astro content collections (defineCollection pattern). CWV thresholds match current web.dev guidance.

### PKM (pkm-*)

- **pkm-vault-conventions**: Obsidian vault organization and conventions
- **pkm-obsidian-plugin-dev**: Plugin development guidance (manifest must include `author`)
- **pkm-rag-design**: Local RAG design with embedding limits and chunking
- **pkm-sync-choice**: Sync strategy (Obsidian Sync merges Markdown; conflict handling)

**Key Notes**: Plugin manifest requires `author` field. Embedding models have token limits (e.g., MiniLM truncates ~256 tokens). Obsidian Sync merges Markdown files rather than treating them as pure binary.

## Agents Reference

5 opt-in custom agents (Tier 3). Each agent is defined as a TypeScript file in `agents/*.ts` exporting a default agent object.

Available agents:
- `agents/cleanup.ts` - Cleanup operations
- `agents/library-auditor.ts` - Music library auditing
- `agents/release-notes-writer.ts` - Release notes generation
- `agents/tech-writer.ts` - Technical writing assistance
- `agents/verifier.ts` - Verification and validation

**Important Notes**:
- Agent `toolNames` use only documented tool vocabulary (no fictional tools)
- `model` field is documented as required by the CLI, but omitted by design in this pack. This is an explicit deviation with verification steps in `agents/README.md`.
- Agents are opt-in and may behave differently depending on your Freebuff/Codebuff tier.

See `agents/README.md` for detailed verification steps and troubleshooting.

## Scripts Reference

All 8 executable scripts are read-only by design:

| Script | Purpose | Exit Codes |
|---|---|---|
| `skills/music-library-audit/scripts/lib-audit.sh` | Audit music library | 0=ok, 1=usage, 2=IO, 3=invalid arg |
| `skills/music-navidrome-nsp-author/scripts/nsp-lint.sh` | Lint Navidrome `.nsp` files | 0=valid, 1=usage, 2=IO, 3=invalid JSON/schema |
| `skills/music-musicbrainz-lookup/scripts/mb-lookup.sh` | MusicBrainz lookup with rate limiting | 0=ok, 1=usage, 2=network/IO, 3=not found |
| `skills/proxmox-backup-and-restore/scripts/pve-backup-check.sh` | Verify backup configs | 0=ok, 2=IO, 3=config issue |
| `skills/proxmox-host-health/scripts/pve-health.sh` | Host health checks | 0=ok, 2=IO, 3=issue |
| `skills/proxmox-upgrade-safety/scripts/pve-precheck.sh` | Pre-upgrade validation | 0=ok, 2=IO, 3=blocked |
| `skills/web-release-page/scripts/release-validate.sh` | Validate release metadata | 0=ok, 2=IO, 3=invalid |
| `skills/web-site-architect/scripts/site-lint.sh` | Lint site structure | 0=ok, 2=IO, 3=invalid |

All scripts:
- Never write files unless explicitly called with `--out` to a new path (and `lib-audit` refuses directories)
- Hash inputs before/after to prove read-only behavior
- Have proper exit code handling with pipefail considerations
- Work with paths containing spaces and `&`

## Testing & Verification

Two comprehensive test suites are included:

### 1. Core Behavior Tests (`tests/run.sh`)
Validates script behavior with fixtures. Includes:
- Basic functionality for each script
- Edge cases and error handling
- Exit code correctness
- Input validation

```bash
cd /path/to/freebuffpuff
bash tests/run.sh
```

**Expected**: 83 passed, 0 failed

### 2. Invariants Tests (`tests/invariants.sh`)
Validates pack-level invariants (what the README asserts):
- File count matches documentation
- Frontmatter contract (unique names, descriptions, required fields)
- **Read-only by construction**: Hashes every input before and after all 8 scripts run (any change fails)
- Agent allowlists contain only documented, non-writing tools
- Installer safety (dry-run, non-destructive, scope isolation)
- CRLF/BOM handling
- Paths with spaces and special characters
- MCP server safety (only GET requests)

```bash
cd /path/to/freebuffpuff
bash tests/invariants.sh
```

**Expected**: 54 passed, 0 failed

### Full Verification

```bash
# Verify pack integrity
./install.sh --verify

# Run all tests
bash tests/run.sh && bash tests/invariants.sh
```

All tests must pass. If any fail, do not proceed without investigating the root cause.

## Troubleshooting

### Tests fail with environment differences

Some tests require specific tools (`jq`, etc.). Install missing dependencies:

```bash
# Debian/Ubuntu
sudo apt-get install jq python3

# macOS
brew install jq
```

### Agent tier issues

If agents appear "dead" or don't load:
1. Check `agents/README.md` - the pack omits `model` field by design
2. Follow the verification one-liner in the README/agents docs
3. This is the most common environment-dependent issue

### Windows-specific issues

- Use Git Bash (not cmd.exe) - scripts use POSIX syntax
- CRLF is rejected by design in certain contexts; BOM+CRLF is handled
- See [Windows 11 Usage](#windows-11-usage)

### Proxmox scripts on live hosts

The scripts are validated against fixtures with shimmed `pvesh`. For live hosts:
1. Read the runbooks in `ops/runbooks/`
2. Never run destructive operations without understanding impact
3. Test in a non-production environment first

## Security & Safety

### Read-Only Guarantees

- All 8 scripts are read-only by construction
- The invariants test hashes all inputs before and after execution; any byte change causes failure
- `lib-audit --out` refuses directories to prevent accidental overwrites
- Installer never overwrites `knowledge.md` or `.codebuffignore`

### Safety Boundaries

- No network calls in safety-critical paths (MB lookup is explicit and rate-limited)
- Proper exit codes and error handling
- No shell injection vectors in typical usage
- Paths with spaces/special chars handled correctly

### Secrets

- Never commit secrets or credentials
- No hardcoded tokens or keys
- Public links are clearly marked as non-private (e.g., Navidrome shares)

## Windows 11 Usage

- **Required shell**: Git Bash (comes with Git for Windows)
- **Do not use**: cmd.exe or PowerShell for running shell scripts directly
- **Line endings**: The pack enforces LF in script contexts; CRLF causes aborts where appropriate
- **Paths**: Spaces handled correctly; use forward slashes where possible

## Contributing & Extending

When modifying:
1. Run tests before and after changes: `bash tests/run.sh && bash tests/invariants.sh`
2. Update documentation if changing behavior
3. Maintain the safety guarantees (read-only where claimed)
4. Verify with `./install.sh --verify`
5. Follow existing code style and conventions

## Handoff Guide for New Agents

See the comprehensive handoff prompt in [HANDOFF_PROMPT.md](HANDOFF_PROMPT.md) (generated below) for instructions on running environment-specific tests that couldn't run in this containerized environment.

## Limitations & Known Issues

### Environment-Dependent (Cannot Verify Here)

- **Skill auto-selection**: Depends on Freebuff/Codebuff runtime behavior
- **Freebuff registering `.ts` agents**: Desktop/Web parity varies
- **Live host testing**: Proxmox scripts tested with fixtures only
- **Browser rendering**: Web tooling never rendered a page
- **PKM sync conflicts in production**: Real-world sync edge cases depend on provider

### Known Design Tradeoffs

- `model` omitted from agent definitions (documented deviation)
- Some claims softened where upstream docs don't support them (Bases vs Dataview comparison)
- Agent tool allowlists restricted to documented vocabulary

For a complete verification checklist, see `probe/USER-CHECKLIST.md`.
