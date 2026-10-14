# 06 — Infra change (one thing, reversible, verified)

For anything that touches the hypervisor, a guest's config, storage, or a running service. Use
`/plan` first; this prompt is the execution contract.

```
Change to make: <one sentence. If it is two changes, do them in two turns.>
Target: <host / guest id / storage / service>
Why: <what breaks today without it>

Rules for this turn:
- ONE change. No opportunistic extra edits.
- Read the current state and quote it first (pct config <id>, docker compose config, the exact file
  lines). The "before" is the rollback, so capture it verbatim.
- State the rollback command BEFORE applying anything.
- State what this change makes NOT backed up, if anything (a bind mount is not in vzdump;
  additional container mount points are excluded by default).
- Read-only checks first: pve-doctor.sh / lxc-audit.sh / compose-doctor.sh / site-audit.sh.
- Then propose the exact command(s) and STOP. Wait for approval before running them.

After approval:
1. Apply exactly what was proposed. If the command differs from the proposal, stop and say so.
2. Verify: the service answers, the guests start, the storage is active, the data is where you
   expect. Name the command and its output.
3. If verification fails, roll back with the stated command and report what happened.

Report: what changed | the command | evidence it worked | what is still unverified | the rollback.
```
