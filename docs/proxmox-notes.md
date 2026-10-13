# Proxmox notes — what the research found, and what this pack does with it

Sources are linked inline. Everything here was checked against the official docs where a doc exists;
community reports are labelled as such. **Verification status of this pack's Proxmox tooling is at
the bottom — read that section before trusting a script's output on your host.**

## 1. Version and repository reality
- The current line is **PVE 9.x**, based on Debian 13 "Trixie" (9.0 in Aug 2025, 9.1 in Nov 2025,
  9.2 in May 2026). **PVE 8.4** security/critical support ran to **August 2026**. If you are on 8.x,
  plan the move rather than treating it as a long-term endpoint. [FAQ/support table](https://pve.proxmox.com/pve-docs/chapter-pve-faq.html)
- **8 -> 9 is not a routine `apt upgrade`**: it is a Debian release change (Bookworm -> Trixie). Run
  `pve8to9 --full`, have a tested backup, check third-party packages, and make sure `/` has space
  (the guide requires >=5 GB, recommends >10 GB). [Upgrade guide](https://pve.proxmox.com/wiki/Upgrade_from_8_to_9)
- **Repository choice** is separate from the subscription *banner*. Without a subscription, disable
  `pve-enterprise` and use `pve-no-subscription`; `pve-test` is not a daily driver. There is no
  supported way to hide the login notice, and patching PVE's web files gets overwritten by updates.
  [Package repos](https://pve.proxmox.com/pve-docs/pve-package-repos-plain.html) · [forum thread on nags](https://forum.proxmox.com/threads/how-do-you-turn-off-the-annoying-subscription-nags.161909/)
- **Never mix Debian suites** across sources files - it is how a PVE host ends up in an unsupported
  package state. `pve-doctor.sh` fails loudly when it sees more than one suite.

## 2. API and automation
- The API is `https://<host>:8006/api2/json`; `pvesh` is the host-side CLI for the same endpoints.
  The [API viewer](https://pve.proxmox.com/pve-docs/api-viewer/index.html) documents them.
- **Prefer API tokens to passwords.** A token belongs to a user, is revocable, can expire, and with
  **privilege separation** its effective permissions are the **intersection** of the user's and the
  token's rights. The secret is shown once.
  [User management](https://pve.proxmox.com/pve-docs/pveum-plain.html) · [pveum(1)](https://pve.proxmox.com/pve-docs/pveum.1.html)
- For monitoring there is a **read-only `PVEAuditor` role**; grant it to both the user and the
  separated token, then check what it can actually do with `pveum user permissions`.
- Tokens cannot reach endpoints that provide VM/system console access - fine for inventory and
  routine automation, not a substitute for interactive administration.
- **Why the pack's MCP server has no Proxmox tools on purpose:** a PVE token is hypervisor-wide
  read. Running the pack's read-only shell scripts is narrower (you see the exact commands), and it
  keeps the "missing `$VAR` drops the whole `mcp.json`" failure mode out of the infrastructure path.

## 3. VM vs LXC for the Docker stack
- Proxmox's own FAQ says **do not run Docker on the PVE host**, and steers orchestration/live
  migration/strong isolation toward a QEMU **VM**. [FAQ](https://pve.proxmox.com/pve-docs/chapter-pve-faq.html)
- An **unprivileged LXC with `nesting=1,keyctl=1`** is widely used and works well. Per `pct.conf(5)`,
  `keyctl` is *"required to use docker inside a container"* and `nesting` exposes procfs/sysfs (and
  is required by systemd to isolate services). [pct.conf(5)](https://pve.proxmox.com/pve-docs/pct.conf.5.html)
- `fuse=1` is only if you actually use FUSE; Proxmox **discourages FUSE mounts inside containers**
  for snapshot/suspend backups. `mknod` is experimental. Do not copy a "kitchen sink" feature list.
- **cgroup v2 is the only option on PVE 9** (v1 removed). Guest OSes need systemd that supports it.
- **Nested Docker inherits host risk.** In late 2025 a `runc` AppArmor change broke Docker inside
  unprivileged containers; Proxmox shipped a fixed `lxc-pve` (6.0.5-2). The documented fix was the
  package, **not** `unconfined` AppArmor or downgrading runc.
  [runc issue](https://github.com/opencontainers/runc/issues/4968) · [forum report](https://forum.proxmox.com/threads/cve-2025-52881-breaks-docker-lxc-containers.175827/)
- **OverlayFS on a ZFS-backed root** is the murky one: newer ZFS (2.2+, PVE 8.1+) reportedly works
  with `overlay2` for some users, others still hit errors and use `fuse-overlayfs` (with `fuse=1`).
  There is **no universal answer** - check `docker info`, test the real workloads, and prefer a VM if
  you want to stop thinking about it. [forum thread](https://forum.proxmox.com/threads/lxc-zfs-docker-overlay2-driver.122621/) · [community discussion](https://github.com/nextcloud/all-in-one/discussions/1490) (community, includes outdated claims)

## 4. Mounts, snapshots and backups — the data-loss surface
Verbatim from the current docs, because this is where homelabs silently lose data:
- Backup and Restore: *"By default additional mount points besides the Root Disk mount point are
  not included in backups. For volume mount points you can set the Backup option to include the
  mount point in the backup."*
- Container Toolkit: *"When creating a new mount point in the GUI, this option is enabled by
  default."* - so **a hand-edited config is exactly where `backup=1` goes missing**.
- Backup and Restore: *"Device and bind mounts are never backed up as their content is managed
  outside the Proxmox VE storage library."*
- Container Toolkit: *"The contents of bind mount points are not backed up when using vzdump."*
- Container Toolkit on bind mounts: *"you cannot make snapshots or deal with quotas from inside the
  container."*
- Snapshot mode *"requires that all backed up volumes are on a storage that supports snapshots"*.
  [Backup and Restore](https://pve.proxmox.com/pve-docs/chapter-vzdump.html) · [Container Toolkit](https://pve.proxmox.com/pve-docs/chapter-pct.html) · [pct.conf(5)](https://pve.proxmox.com/pve-docs/pct.conf.5.html)
- PVE backups are **always full**; PBS deduplicates so subsequent runs store only changed chunks.
  Pruning removes metadata first and GC frees chunks later. Keep PBS on a **separate failure domain**,
  and schedule verification - then do a real restore drill. [Maintenance](https://pbs.proxmox.com/docs/maintenance.html)
- A PVE snapshot is **not** a backup, and internal qcow2 snapshots on large/network storage can block
  a running VM. [Storage guide](https://pve.proxmox.com/pve-docs/chapter-pvesm.html)

## 5. Storage
- **Single-disk ZFS = no redundancy.** Checksums detect corruption; they cannot repair it without a
  good copy. `ashift` is fixed at pool creation. [ZFS on Linux](https://pve.proxmox.com/wiki/ZFS_on_Linux)
- **ARC**: PVE >=8.1 defaults to ~**10% of RAM capped at 16 GiB**; older installs may have much
  higher limits. Rule of thumb in the guide: >=2 GiB + 1 GiB per TiB. Check `zfs_arc_max`, don't
  guess.
- `recordsize` is per-dataset; a larger record for large sequential media is a reasonable *test*,
  not a rule for a database or small-file dataset.
- Thin pools (LVM-thin) need monitoring of **both** data and metadata - filling them damages guests.
- For the media library itself, three honest options: a host ZFS dataset bind-mounted into the guest,
  an NFS/SMB share mounted on the host and bind-mounted in, or a dedicated storage VM. The first is
  simplest; all three mean the library is outside the guest backup.

## 6. Hardlinks across Proxmox
The Servarr guide's rule survives the move to Proxmox with a twist: **two ZFS datasets in the same
pool are two filesystems**, and two separate bind mounts look like two filesystems inside Docker.
Hardlinks then fail and the import degrades to copy+delete (slow, double I/O, breaks seeding).
[Servarr Docker guide](https://wiki.servarr.com/docker-guide)
Fix: **one** dataset/share for downloads+library, **one** mount into the guest (`mp0: /tank/media,mp=/data`),
and the same `/data` path for every container. Verify inside the guest, as the service user:
`stat -c '%d %i %n' <file>` on both sides must show the same device id.
`lxc-audit.sh --paths A:B` automates the check.

## 7. GPU / transcoding
- **LXC**: share the device node (`dev0: /dev/dri/renderD128,mode=...,gid=...`; older configs use
  `lxc.cgroup2.devices.allow` + `lxc.mount.entry`). Prefer a **specific gid** over `mode=0666`; the
  host and an unprivileged container can disagree about gids, which is the usual reason it "works as
  root".
- **VM**: full PCIe passthrough needs IOMMU (Intel VT-d / AMD-Vi) and a usable IOMMU group; the host
  loses the device and the VM cannot live-migrate. [PCI(e) Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)
- **GVT-g/mdev is not general**: the guide documents it only for specific older Intel generations.
  **SR-IOV** needs device+platform+driver support; NVIDIA vGPU is licensed product/driver territory.
- Passing a device configures nothing: the app still needs the VA-API userspace libraries and the
  requested codec must exist on that GPU.

## 8. Network and exposure
- `vmbr0` is a Linux bridge to your LAN. Changing the management bridge live is how people lock
  themselves out.
- **`pve-firewall` is disabled by default**, and per-guest rules only apply when that interface's
  firewall option is enabled. Some VNet/forwarding rules exist only in the nftables-based
  `proxmox-firewall`. [Firewall](https://pve.proxmox.com/pve-docs/chapter-pve-firewall.html)
- **Docker-published ports can bypass UFW** - do not assume a deny rule covers them.
- **Never expose the PVE UI/API (8006).** Use VPN/tailnet for private services; Caddy/Traefik on
  80/443 or a Cloudflare Tunnel for the public site. [Network](https://pve.proxmox.com/pve-docs/pve-network-plain.html) · [SDN](https://pve.proxmox.com/pve-docs/chapter-pvesdn.html)

## 9. IaC, and how much of it you need
- `bpg/terraform-provider-proxmox`: community-maintained, targets PVE 9.x, still **0.x**, and a few
  operations require SSH (the README warns broad sudo is effectively root). [repo](https://github.com/bpg/terraform-provider-proxmox)
- `community.proxmox` (Ansible) is community-maintained; HashiCorp's Packer integration is
  community-maintained and slow-moving.
- Native path: **cloud-init templates** (`qm`/`pct` clone) - the supported way to make repeatable
  guests. Use IaC when you rebuild guests often; not for a three-guest homelab.

## 10. Failure modes worth memorising
| Symptom | What it usually is |
|---|---|
| External disk/NFS not mounted | data landed on `/`; root filesystem fills |
| Storage shows `active: 0` | it is not mounted at all |
| `nobody`-owned files in an unprivileged CT | uid/gid mapping vs the host mount |
| Two-node cluster loses quorum | `/etc/pve` goes read-only; HA wants >=3 nodes (QDevice for 2). Don't cluster a one-box homelab |
| Backup task "locked" | a backup is still running; do not force-unlock blindly |
| APT broken after "one small install" | foreign repos/Docker on the host; PVE has its own kernel and package set |
| USB passthrough unreliable | device identity/power management; not a library-storage design |

## 11. What this pack does, and what it does not
**Does:** ships `proxmox-stack-map` (host inventory), `proxmox-guest-placement` (+`lxc-audit.sh`),
`proxmox-storage-and-mounts`, `proxmox-backup-and-restore`, `proxmox-gpu-transcode`,
`proxmox-upgrade-safety`, `proxmox-service-exposure`, two read-only scripts, a read-only
`Proxmox Auditor` agent, a runbook, an inventory template and workflow prompt 06.

**Honest limits:** the scripts were validated against **fixtures and a shimmed `pvesh`**, not on a
live PVE host - the sandbox has no hypervisor. Expect to confirm the JSON shape of `pvesh get`
endpoints on your version; the scripts report what they could not read rather than inventing it.
`pve-doctor.sh` needs `python3` or `python` on the host (or set `PYTHON=`). None of it changes state.
