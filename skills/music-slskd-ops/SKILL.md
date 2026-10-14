---
name: music-slskd-ops
description: Operate and inspect slskd safely - read-only API checks for connection and transfer state, share review, VPN/port reasoning, and sharing etiquette and privacy rules. Use when slskd won't download, searches return nothing, transfers stall, VPN sidecar questions, or reviewing shares.
metadata:
  category: music
  stack: slskd, soulseek, gluetun
---

# slskd operations

Default to read-only GETs. Never start/cancel/clear transfers or change shares unless
explicitly asked in the same message.

## Probe first
`bash scripts/slskd-doctor.sh` (needs `SLSKD_URL` + `SLSKD_API_KEY`; use a **ReadOnly** key).
GETs session/application/server/shares/transfers; 404 = "not in this version", not failure.

## Facts preventing wrong diagnoses
- **Not a native Lidarr client on stable.** Routes: **Soularr** bridge, or community plugin
  (needs **develop/nightly** Lidarr + ReadWrite key; branch change = schema change, **no downgrade**).
- **Two ports:** web/API ≠ Soulseek listening port. Unforwarded listening port degrades
  search/browse/downloads, not just uploads.
- **VPN sidecar:** Gluetun owns namespace; `network_mode: service:gluetun`, `SLSKD_VPN=true`,
  provider port-forwarding required. Publish UI port on the **VPN** container.
- **`Connection refused` is ambiguous** (port/listener/mapping/firewall) — don't assert one cause.
- **No universal ratio**, but etiquette applies; "banned/file not shared" = one user's decision.
- **Shares are public** (username browsable). Alias folder names; **never share `/data`, home,
  whole drives, or personal folders.** Mount only the dedicated share folder.
- **Defaults to change:** `slskd`/`slskd` creds; HTTPS self-signed; keys over plain HTTP
  discouraged; remote config off by default — leave it.
- **Legal note only:** share/download only permitted material; VPN changes path, not position.

## "Not downloading" order
1. `/api/v0/server` connected? 2. Queue just waiting? (P2P; uploader decides.)
3. Listening port reachable? 4. Download dir writable (`SLSKD_UMASK`)?
5. Import racing transfer (partial read as complete)? 6. Then Lidarr side.

## Output
```
PROBES / STATE / FINDINGS (ranked + evidence) / RISK NOTES (report, don't change) / RECOMMEND / NOT CHANGED
```

## Never
Cancel/retry/clear transfers to "test"; change shares/creds/exposure; install plugins or switch branches.
