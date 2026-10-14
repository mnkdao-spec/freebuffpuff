---
name: proxmox-service-exposure
description: Decide and audit how self-hosted services are reachable - Proxmox bridges and VLANs, the PVE firewall, split DNS, a LAN reverse proxy with automatic TLS, Tailscale for private remote access, Cloudflare Tunnel instead of port forwarding, and why the PVE web UI must never be public. Use before opening a port, when a service is unreachable from another device, when asked how to access the music server or the site remotely, or when reviewing what is actually exposed to the internet.
metadata:
  category: proxmox
---

# Service exposure

Every decision here answers one question: **who can reach this, from where?** Write the answer down
before changing a firewall.

## The pieces
- **`vmbr0`** is the Linux bridge to your physical LAN; guests attached to it behave like machines
  on that LAN. Changing the management bridge live is how people lock themselves out of the UI.
- **VLAN-aware bridge + tagged interfaces** if you want to separate management, services and IoT.
  PVE's SDN core is supported; IPAM/DHCP and more complex features are marked preview in the docs.
- **`pve-firewall`** is **disabled by default**. Per-guest rules only apply when that interface has
  its firewall option enabled. Some newer VNet/forwarding rules only exist in the nftables-based
  `proxmox-firewall`, so do not assume a rule works under the legacy engine.
```bash
pve-firewall status
cat /etc/pve/firewall/cluster.fw 2>/dev/null
bridge link; ip -br addr
ss -tlnp                                    # what is actually listening
docker ps --format '{{.Names}}\t{{.Ports}}'  # published ports - Docker can bypass UFW rules
```
A Docker-published bridge port does **not** necessarily respect UFW. If you think "UFW blocks it",
test from another host rather than assuming.

## Exposure patterns, best to worst
| Pattern | Reachable from | Notes |
|---|---|---|
| LAN + split DNS + internal reverse proxy | your network only | the default for Navidrome, Lidarr, Prowlarr, slskd UI |
| **Tailscale** (client on the device, or a subnet router) | your tailnet only | best private remote access; no public ports |
| **Cloudflare Tunnel** (`cloudflared`) | the public internet, via Cloudflare | outbound-only connection; no port forwarding or public IP needed. Publishing a tunnel route makes that service public - use access controls for anything meant to stay private |
| Reverse proxy on 80/443 with port forwarding | the public internet | forward only the proxy's ports; backends stay unexposed |
| App port forwarded directly | the public internet | don't |

- **Caddy** for a small self-hosted site: readable config, automatic HTTPS/renewal. Ordinary ACME
  needs 80/443 reachable from the internet; **wildcard certificates require DNS-01**, and the DNS
  provider support comes from a Caddy module - check your build includes it.
- **Traefik** when routes should live with the Docker services (labels). Either way, protect access
  to the Docker socket, and keep credentials out of routing labels.
- Never expose the PVE management UI/API (**port 8006**) to the internet. Keep it on the LAN or
  reachable only through a VPN/tailnet.

## What this homelab should look like (adopt or justify a change)
| Service | Reachability | Why |
|---|---|---|
| Artist website | public | it is your public presence; served by Caddy, static files only |
| Navidrome | LAN/tailnet only | a personal library, weak-ish client auth, no reason to be public |
| Lidarr / Prowlarr / slskd UI | LAN/tailnet only | admin surfaces with API keys; slskd has no built-in TLS |
| Proxmox UI (8006) | LAN/tailnet only, never forwarded | hypervisor control plane |
| Grafana/PBS/analytics | LAN/tailnet only | infrastructure plumbing |

## Verifying reachability (honest checks, no scanning tools needed)
```bash
# from the LAN
curl -sS -o /dev/null -w '%{http_code} %{remote_ip}\n' https://site.example
curl -sS -o /dev/null -w '%{http_code}\n' http://10.0.0.120:4533/rest/ping
# is it really private? test from a phone on mobile data (not the home Wi-Fi) -
curl -sS -o /dev/null -w '%{http_code}\n' --max-time 8 http://<public-ip>:4533/
# a timeout/refused from outside is the expected, correct result
```
Also check TLS expiry on anything public:
`echo | openssl s_client -connect site.example:443 -servername site.example 2>/dev/null | openssl x509 -noout -dates`

## Hard rules
- Every new port forward, tunnel route or public hostname is an APPROVAL-REQUIRED change: state
  exactly what becomes reachable, from where, with what authentication.
- Never expose the PVE UI, an *arr admin UI, the slskd UI, or a library API to the internet.
- Never disable the firewall or authentication to make something reachable. Fix the route.
- Do not paste API keys or tunnel credentials into a prompt; they belong in the service's own
  secret store.
