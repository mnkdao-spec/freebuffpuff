---
name: proxmox-service-exposure
description: Decide and audit how self-hosted services are reachable - bridges and VLANs, PVE firewall, split DNS, LAN reverse proxy with TLS, Tailscale for private remote, Cloudflare Tunnel vs port forwarding, why PVE UI stays private. Use before opening ports, on unreachable services, remote-access questions, or exposure reviews.
metadata:
  category: proxmox
---

# Service exposure

One question: **who reaches this, from where?** Answer in writing before touching firewalls.

## Pieces
- **`vmbr0`** = LAN bridge; changing the management bridge live locks you out.
- **VLAN-aware bridge + tagged interfaces** for mgmt/services/IoT separation.
- **`pve-firewall` disabled by default**; per-guest rules need the interface firewall flag.
  Check `pve-firewall status`, `cluster.fw`, `ss -tlnp`, container published ports —
  **Docker-published ports can bypass UFW**; test from another host, don't assume.

## Patterns, best to worst
LAN + split DNS + internal proxy (default for Navidrome/*arr/slskd) → **Tailscale** (best private
remote; no public ports) → **Cloudflare Tunnel** (outbound-only; published routes are public —
gate private things) → proxy on 80/443 with forwarding (backends unexposed) → direct app-port
forward (**don't**).
Caddy: readable + auto-HTTPS (wildcards need DNS-01 + provider module). Traefik: routes with
services via labels (protect the socket; keys out of labels). **Never expose 8006.**

## Homelab layout (adopt or justify change)
Website: public (Caddy, static only). Navidrome / *arr / slskd / PVE 8006 / infra: LAN/tailnet
only. slskd has no built-in TLS; *arr UIs hold API keys.

## Verify honestly
LAN `curl` codes; from phone on mobile data expect timeout/refused for private things;
`openssl s_client` TLS expiry on public hosts.

## Hard rules
New forward/tunnel/hostname = APPROVAL-REQUIRED (what, from where, what auth). Never expose
PVE/*arr/slskd/library APIs. Never disable firewall/auth for reachability. No keys in prompts.
