# Homelab inventory (fill this in once — agents read it instead of guessing)

> Context, not documentation for strangers. Factual and short. No secrets: names, ids, paths only.

## Proxmox host
- Hostname / LAN IP: <EDIT pve.lan 10.0.0.10>
- Proxmox version: <EDIT PVE 9.2>
- Access for agents: <EDIT e.g. "ssh root@pve.lan (key only)" or "not reachable — paste output manually">
- Management UI: 8006, reachable from <EDIT LAN only / tailnet only>
- Repositories: <EDIT pve-no-subscription (enterprise disabled)>
- Backup: <EDIT job name, schedule, mode, target>
- Known good restore test: <EDIT date + guest id actually restored>

## Guests
| ID | Kind | Name | Purpose | Docker? | Notes |
|---|---|---|---|---|---|
| <EDIT 120> | LXC | music-stack | Navidrome, Lidarr, Prowlarr, slskd | yes | unprivileged, nesting+keyctl |
| <EDIT 121> | LXC | site | Caddy serving the built site | no | |

## Storage
| Name | Type | Mounted where | Holds | In vzdump backups? |
|---|---|---|---|---|
| <EDIT tank> | ZFS pool | /tank | media library + downloads | no (bind mount) |
| <EDIT local-lvm> | LVM-thin | — | guest rootfs | yes |

## Media paths (as the guest sees them)
- Library root: <EDIT /data/media/Music>
- Download/staging: <EDIT /data/downloads/soulseek> (same filesystem? <EDIT yes/no>)
- One shared mount: <EDIT /tank/media:/data>

## Website
- Domain: <EDIT kinetic.example> - Repo: <EDIT path/URL> - Build: <EDIT npm run build> - Output: <EDIT dist/>
- Served by: <EDIT Caddy in LXC 121, /srv/site/current>
- Newsletter: <EDIT provider/self-hosted> - Analytics: <EDIT self-hosted>
- Public surface: <EDIT only 80/443 to Caddy; rest LAN/tailnet>

## Exposure rules
- Public: the artist website only.
- LAN/tailnet only: Navidrome, Lidarr, Prowlarr, slskd UI, Proxmox UI, PBS, analytics.
- Never public: Proxmox UI (8006), *arr admin UIs, slskd UI/API.

## Hard rules for agents
1. Read-only by default on the hypervisor. No `qm`/`pct set`, no storage/firewall changes, no
   restarts, without explicit instruction in that message.
2. Never read or print secrets.
3. Mount/privilege/port/backups changes are APPROVAL-REQUIRED with rollback stated.
4. Do not install anything on the PVE host. Services belong in a guest.
