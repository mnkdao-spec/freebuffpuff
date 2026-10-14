# Handoff Prompt: Run Environment-Specific Tests on User's Machine

Copy and paste this entire prompt to an agent running on your local machine (where you have access to Freebuff Desktop, a Proxmox host if applicable, browser, etc.).

---

```text
You are taking over verification of the freebuffpuff homelab pack on the user's local machine. This pack was already reviewed and tested in a sandboxed environment, but several tests could not be run there due to environment constraints. Your job is to run those remaining tests and report back.

## Context

The pack is at: https://github.com/mnkdao-spec/freebuffpuff
Branch: main (after pushing)
Location on user's machine: wherever they clone it

What was verified in sandbox:
- tests/run.sh: 83/83 passed
- tests/invariants.sh: 54/54 passed  
- install.sh --verify: 39 skills, 5 agents valid
- All scripts are read-only by construction
- Agent tool allowlists corrected to documented vocabulary
- PKM/music/web/Proxmox docs fact-checked against current sources

What could NOT be verified in sandbox (needs local machine):

1. Skill auto-selection behavior in Freebuff/Codebuff runtime
2. Freebuff Desktop registering .ts agent files
3. Desktop/Web parity
4. Live Proxmox host testing (scripts only tested with fixtures)
5. Browser rendering of web tooling (Astro content, release pages)
6. Real-world PKM sync conflict behavior

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/mnkdao-spec/freebuffpuff.git
   cd freebuffpuff
   ```

2. Verify the pack installs cleanly in this environment:
   ```bash
   ./install.sh --verify
   bash tests/run.sh
   bash tests/invariants.sh
   ```

All three must pass before proceeding.

## Required Tests

### 1. Agent Registration & Loading (Critical)

Check the "model field omitted by design" case. The pack intentionally omits `model` from agent definitions. Verify agents still load correctly.

From agents/README.md, run the verification one-liner for your environment. Also manually verify:
- All 5 agents in agents/*.ts load without errors
- Freebuff Desktop recognizes them (if using Desktop)
- No "missing model" errors

Report any errors with full stack traces.

### 2. Skill Auto-Selection

Test that skills are triggered appropriately by description matching. This is environment-dependent on the Freebuff/Codebuff runtime. Try:
- Triggering music-navidrome-nsp-author with "write a navidrome smart playlist"
- Triggering proxmox-backup-and-restore with "check proxmox backup"
- Triggering web-release-page with "create release page"
- Triggering pkm-obsidian-plugin-dev with "obsidian plugin"

Note: Results depend on your tier and runtime. Document what happens.

### 3. Desktop vs Web Parity (If Both Available)

If you use both Freebuff Desktop and Web:
- Test the same agent/skill in both
- Compare behavior
- Note any discrepancies

### 4. Proxmox Live Host Testing (HIGH RISK - Optional)

ONLY if you have a non-production Proxmox host to test against. 
READ ops/runbooks/proxmox.md FIRST.

Never run destructive operations. Focus on read-only checks:
- pve-health.sh against real host (if adapted to query your host)
- pve-backup-check.sh against actual vzdump configs
- pve-precheck.sh in dry-run mode

If you don't have a Proxmox host, skip and note "not tested - no accessible host".

### 5. Browser Rendering Tests

For web skills:
- Use web-site-architect to scaffold a minimal Astro site
- Use web-release-page to create a sample release page
- Render/preview if possible (npm run dev/build)
- Verify structured data is valid
- Check Core Web Vitals guidance is applicable

### 6. PKM Real-World Testing

- Test obsidian-plugin-dev guidance against actual Obsidian plugin structure
- Validate pkm-rag-design chunking with real note sizes
- Test pkm-sync-choice against your actual sync provider (if using)
- Note: "different plugin versions corrupt .obsidian" claim was softened - see if you can reproduce

## Follow the User Checklist

Complete everything in probe/USER-CHECKLIST.md:
- [ ] Install in fresh location
- [ ] Run all tests
- [ ] Verify agents load
- [ ] Check skill discovery
- [ ] Desktop parity (if applicable)
- [ ] Optional: Proxmox on live host (with extreme caution)
- [ ] Optional: End-to-end web build

## Report Back

Return a concise report with:
1. Environment: OS, shell (bash/zsh), Freebuff client (Desktop/Web/both), versions
2. Baseline tests: all pass/fail
3. Each of the 6 test areas: results, errors, observations
4. Any discrepancies from sandbox behavior
5. Recommendations/fixes if any issues found
6. Updated probe/USER-CHECKLIST.md with your results (commit if changes)

Do not modify the safety guarantees (read-only scripts). Do not weaken assertions just to pass.

Start by cloning and running the baseline verification.
```