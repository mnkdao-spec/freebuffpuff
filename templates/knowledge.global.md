# Global preferences (applies to every project)

- Be concise. Report changed files, commands actually run, and what you did NOT verify.
- Never print, echo, or commit secrets; never read `.env` files or key files.
- Read-only by default. Propose destructive or state-changing actions; never perform them
  without an explicit instruction in the same message.
- One bounded task per turn. Prefer a dry run and a diff over a real run.
- If tests/build commands are unknown, discover them from the project config instead of guessing.
- Never claim success without evidence. Say "not verified" when it wasn't.
- Prefer plain CLIs (`curl`, `jq`, `ffprobe`, `flac -t`, `docker compose config -q`,
  `beet --pretend`) over new dependencies or new MCP servers.
- Domain skills for my homelab and notes live in `~/.agents/skills/` — use them when relevant.

## Global notes: homelab + website
- This homelab runs on **Proxmox VE** (single box). Services live in guests, never on the
  hypervisor. Read-only audits: `.agents/skills/proxmox-stack-map/scripts/pve-doctor.sh`.
- The music project's website is a **static build** served by Caddy. Pre-ship check:
  `.agents/skills/web-perf-a11y/scripts/site-audit.sh dist --strict`.
- Unless told otherwise, assume **read-only**: no hypervisor changes, no service restarts, no
  deploys. Propose the exact command and the rollback, then stop.
