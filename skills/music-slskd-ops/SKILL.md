---
name: music-slskd-ops
description: Operate and inspect a slskd (Soulseek) instance safely - read-only API checks for connection and transfer state, share configuration review, VPN and port-forwarding reasoning, and the etiquette and privacy rules that come with sharing. Use when slskd is not downloading, when searches return nothing, when transfers stall, when checking whether a VPN sidecar is configured correctly, or when reviewing what the instance is sharing.
metadata:
  category: music
  stack: slskd, soulseek, gluetun
---

# slskd operations

Default to read-only GETs. Never start, cancel or clear transfers, and never change shares,
unless the human explicitly asked for that action in the same message.

## Start with the read-only probe
```bash
bash scripts/slskd-doctor.sh          # next to this SKILL.md; needs SLSKD_URL + SLSKD_API_KEY
```
It GETs `/api/v0/session`, `/application`, `/server`, `/shares`, `/transfers/downloads`,
`/transfers/uploads` and prints each HTTP status. Use a **ReadOnly** API key for this. Report
404s as "not available in this version", not as failures.

## Facts that prevent wrong diagnoses
- **slskd is not a native Lidarr download client on the stable branch.** Two supported routes:
  the external **Soularr** bridge (its own `config.ini`; Lidarr must be able to see the slskd
  download folder), or a **community Lidarr plugin** which needs a **develop/nightly Lidarr
  build** and an slskd API key with the **ReadWrite** role. Plugins require both halves to be
  registered — an indexer *and* a download client. Install neither without explicit approval:
  changing Lidarr branches means a database schema change, and **downgrading requires a
  database restore**.
- **Two different ports.** The web/API port is not the Soulseek listening port. A client can
  connect and still be hard for peers to reach. Symptoms of an unforwarded listening port
  include poor search results and failures to browse or retrieve from some users — and this
  affects downloads too, not just uploads.
- **VPN via sidecar.** The common pattern is a Gluetun container owning the network namespace
  and slskd using `network_mode: service:gluetun`, with `SLSKD_VPN=true`,
  `SLSKD_VPN_PORT_FORWARDING=true` and the provider's port-forwarding enabled
  (`VPN_PORT_FORWARDING=on`). The provider must actually support port forwarding. Publish the
  web UI port on the **VPN** container, and never expose the Gluetun control server.
- **`Connection refused` is ambiguous.** It means nothing accepted the connection at that
  address/port — could be a wrong port, wrong listener, missing mapping, or a firewall. Do not
  assert a single cause.
- **Soulseek is not a private tracker.** There is no universal enforced ratio. Share files you
  are genuinely comfortable making public; do not hammer searches; do not queue repeatedly from
  a peer who has restricted you. "Banned" / "file not shared" in a transfer response is one
  user's decision, not a server suspension.
- **Shares are public.** Other users can see your username and browse the folders you share. A
  folder-name alias can avoid leaking a revealing local path. **Never share `/data`, your home
  directory, a whole drive, or a folder holding unrelated personal files.** Mount only the
  dedicated share folder into slskd.
- **Security defaults to check.** The web UI ships with a default username *and* password
  (`slskd`/`slskd`) — both must be changed. It does have an HTTPS listener (self-signed by
  default), but API keys over plain HTTP are discouraged; the docs say so explicitly. Remote
  configuration is disabled by default; leave it that way. Scope an integration key to the
  minimum role and, where available, restrict by CIDR rather than reusing the admin key.
- **Legal.** Share and download only material you are permitted to. A VPN changes the network
  path, not the legal position, and it is not a privacy guarantee if the traffic is not
  actually routed through it. Keep this to a plain factual note in your report; do not advise.

## Diagnosing "slskd isn't downloading"
1. `/api/v0/server` — is the client connected/logged in at all?
2. Are transfers queued and simply waiting? Soulseek is peer-to-peer; the uploader decides when
   to serve. A long queue is normal, not broken.
3. Is the listening port reachable? Cross-check the forwarded port reported by the VPN
   provider against slskd's configured listening port.
4. Is the download folder writable by the container's umask/user (`SLSKD_UMASK`)?
5. Is anything moving files out of the download folder concurrently (Soularr / Lidarr import
   racing the transfer)? Check for an in-progress transfer being read as "complete".
6. Only then look at Lidarr's side (`music-lidarr-match-doctor`).

## Output format
```
PROBES:     endpoint -> status -> key fields (from slskd-doctor.sh)
STATE:      connected? transfers queued/completed? shares configured?
FINDINGS:   ranked, each with its evidence
RISK NOTES: public-share exposure, default credentials, plain-HTTP keys - report, do not change
RECOMMEND:  the next read-only step, or the exact action for a human to take
NOT CHANGED: explicitly state that no transfer, share or setting was modified
```

## Never
- Cancel, retry or clear transfers to "see if that helps".
- Change shares, credentials, or expose the UI/API more broadly.
- Install a Lidarr plugin or switch Lidarr branches.
