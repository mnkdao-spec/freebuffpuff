# Homelab inventory (fill this in once — agents read it instead of guessing)

> This file is context, not documentation for strangers. Keep it factual and short. It exists so an
> agent does not scan blindly or invent paths. No secrets: names, ids and paths only.

## Proxmox host
- Hostname / LAN IP: <EDIT pve.lan 10.0.0.10>
- Proxmox version (as of writing): <EDIT PVE 9.2>
- Access method for agents: <EDIT e.g. "ssh root@pve.lan (key only)" or "not reachable — paste output manually">
- Management UI: 8006, reachable from <EDIT LAN only / tailnet only>
- Repositories in use: <EDIT pve-no-subscription (enterprise disabled)>
- Backup: <EDIT job name, schedule, mode, target — PBS at 10.0.0.11 or directory /mnt/backup>
- PBS/backup host: <EDIT>
- Known good restore test: <EDIT date + guest id you actually restored>

## Guests
| ID | Kind | Name | Purpose | Docker? | Notes |
|---|---|---|---|---|---|
| <EDIT 120> | LXC | music-stack | Navidrome, Lidarr, Prowlarr, slskd | yes | unprivileged, nesting+keyctl |
| <EDIT 121> | LXC | site | Caddy serving the built site | no | |
| <EDIT 200> | VM | docker-vm | <optional second Docker host> | yes | |

## Storage
| Name | Type | Mounted where | Holds | In vzdump backups? |
|---|---|---|---|---|
| <EDIT tank> | ZFS pool | /tank | media library + downloads | no (bind mount) — protected by <EDIT> |
| <EDIT local-lvm> | LVM-thin | — | guest rootfs | yes |
| <EDIT pbs-store> | PBS | — | guest backups | n/a |

## Media paths (as the guest sees them)
- Library root: <EDIT /data/media/Music>
- Download/staging: <EDIT /data/downloads/soulseek>  (same filesystem as the library? <EDIT yes/no>)
- One shared mount inside the containers: <EDIT /tank/media:/data>

## Website
- Domain: <EDIT kinetic.example>
- Repo: <EDIT path or URL>   Build: <EDIT npm run build>   Output: <EDIT dist/>
- Served by: <EDIT Caddy in LXC 121, /srv/site/current>
- Deploy: <EDIT rsync + symlink swap from GitHub Actions, or manual>
- Newsletter: <EDIT provider / self-hosted>   Analytics: <EDIT self-hosted Umami in CT 122>
- Public surface: <EDIT only 80/443 to Caddy; everything else LAN/tailnet>

## Exposure rules for this lab
- Public: the artist website only.
- LAN/tailnet only: Navidrome, Lidarr, Prowlarr, slskd UI, Proxmox UI, PBS, analytics.
- Never public: Proxmox UI (8006), any *arr admin UI, slskd UI/API.

## Hard rules for agents
1. Read-only by default on the hypervisor. No `qm`/`pct set`, no storage or firewall changes, no
   restarts, without an explicit instruction in that message.
2. Never read or print secrets (`/etc/pve/priv`, API tokens, `.env`, `/etc/apt/auth.conf.d`).
3. Anything that changes a mount, a privilege, a port forward or a backup setting is
   APPROVAL-REQUIRED: propose the exact command, state the rollback, then stop.
4. Do not install anything on the PVE host. Services belong in a guest.
