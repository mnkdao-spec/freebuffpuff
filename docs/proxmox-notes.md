# Proxmox notes — what the research found, and what this pack does with it

Sources are linked inline. Everything here was checked against the official docs where a doc exists.
**Verification status of this pack's Proxmox tooling is at the bottom.**

## 1. Version and repository reality
- The current line is **PVE 9.x**, based on Debian 13 "Trixie" (9.0 Aug 2025, 9.1 Nov 2025,
  9.2 May 2026). **PVE 8.4** security/critical support ran to **August 2026**.
  [FAQ/support table](https://pve.proxmox.com/pve-docs/chapter-pve-faq.html)
- **8 -> 9 is not a routine `apt upgrade`**: Debian release change (Bookworm -> Trixie). Run
  `pve8to9 --full`, have a tested backup, `/` needs >=5 GB (recommends >10 GB).
  [Upgrade guide](https://pve.proxmox.com/wiki/Upgrade_from_8_to_9)
- Without a subscription, disable `pve-enterprise` and use `pve-no-subscription`.
  [Package repos](https://pve.proxmox.com/pve-docs/pve-package-repos-plain.html)
- **Never mix Debian suites** across sources files. `pve-doctor.sh` fails loudly on mixed suites.

## 2. API and automation
- The API is `https://<host>:8006/api2/json`; `pvesh` is the host-side CLI.
  [API viewer](https://pve.proxmox.com/pve-docs/api-viewer/index.html)
- **Prefer API tokens to passwords.** With **privilege separation** effective permissions are the
  **intersection** of the user's and the token's rights. The secret is shown once.
- For monitoring there is a **read-only `PVEAuditor` role**; grant to user and token.
- **Why the pack's MCP server has no Proxmox tools:** a PVE token is hypervisor-wide read.
  The read-only shell scripts are narrower and visible.

## 3. VM vs LXC for the Docker stack
- Proxmox's FAQ says **do not run Docker on the PVE host**; a QEMU **VM** for orchestration/live
  migration/strong isolation. [FAQ](https://pve.proxmox.com/pve-docs/chapter-pve-faq.html)
- An **unprivileged LXC with `nesting=1,keyctl=1`** works well. Per `pct.conf(5)`,
  `keyctl` is *"required to use docker inside a container"*.
- **cgroup v2 is the only option on PVE 9** (v1 removed).
- **Nested Docker inherits host risk.** Late-2025 `runc` AppArmor breakage was fixed by `lxc-pve`
  6.0.5-2, **not** by `unconfined` AppArmor.

## 4. Mounts, snapshots and backups — the data-loss surface
- *"By default additional mount points besides the Root Disk mount point are
  not included in backups. For volume mount points you can set the Backup option."*
- *"When creating a new mount point in the GUI, this option is enabled by
  default."* — a **hand-edited config is where `backup=1` goes missing**.
- *"Device and bind mounts are never backed up."*
- PVE backups are **always full**; PBS deduplicates. Keep PBS on a **separate failure domain**,
  schedule verification, do a real restore drill.
- A PVE snapshot is **not** a backup.

## 5. Storage
- **Single-disk ZFS = no redundancy.** Checksums detect; they cannot repair without a good copy.
- **ARC**: PVE >=8.1 defaults to ~**10% of RAM capped at 16 GiB**.
- Thin pools need monitoring of **both** data and metadata.

## 6. Hardlinks across Proxmox
**Two ZFS datasets in the same pool are two filesystems.** Fix: **one** dataset/share for
 downloads+library, **one** mount into the guest (`mp0: /tank/media,mp=/data`), same `/data`
 path for every container. Verify: `stat -c '%d %i %n'` both sides, same device id.

## 7. GPU / transcoding
- **LXC**: share the device node (`dev0: /dev/dri/renderD128,mode=...,gid=...`). Prefer a
  **specific gid** over `mode=0666`.
- **VM**: full PCIe passthrough needs IOMMU; host loses the device; no live-migrate.

## 8. Network and exposure
- **`pve-firewall` is disabled by default.**
- **Never expose the PVE UI/API (8006).** VPN/tailnet for private; Caddy/Traefik or Tunnel for public.

## 9. What this pack does, and what it does not
**Does:** `proxmox-stack-map`, `proxmox-guest-placement` (+`lxc-audit.sh`),
 `proxmox-storage-and-mounts`, `proxmox-backup-and-restore`, `proxmox-gpu-transcode`,
 `proxmox-upgrade-safety`, `proxmox-service-exposure`, two read-only scripts, a read-only
 `Proxmox Auditor` agent, a runbook, an inventory template and prompt 06.

**Honest limits:** validated against **fixtures and a shimmed `pvesh`**, not a live host.
 `pve-doctor.sh` needs `python3`/`python` on the host. None of it changes state.
