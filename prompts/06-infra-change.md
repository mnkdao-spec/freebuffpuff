# 06 — Infra change (one thing, reversible, verified)

For hypervisor/guest/storage/service changes. `/plan` first; this is the execution contract.

```
Change: <one sentence — two changes means two turns.> Target: <host/guest/storage/service>
Why: <what breaks today without it>

- ONE change. Quote current state first (pct config, compose config, file lines) — the "before" is the rollback.
- State the rollback BEFORE applying anything.
- State what becomes NOT backed up (bind mounts aren't in vzdump; extra mounts excluded by default).
- Read-only checks first (pve-doctor / lxc-audit / compose-doctor / site-audit).
- Propose exact command(s) and STOP. Wait for approval.

After approval: apply exactly as proposed; verify (service answers, guests start, storage active,
data where expected — command + output); on failure roll back and report.

Report: changed | command | evidence | still unverified | rollback.
```
