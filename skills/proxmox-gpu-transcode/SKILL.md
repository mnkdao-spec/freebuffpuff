---
name: proxmox-gpu-transcode
description: Give a Proxmox guest hardware transcoding - Intel iGPU/Arc via /dev/dri into unprivileged LXC versus PCIe passthrough to a VM - device permissions, gid mapping, IOMMU prerequisites, codec verification. Use for Jellyfin/Navidrome/ffmpeg hardware transcoding setup, silent CPU fallback, post-restart GPU loss, or LXC-vs-VM media server questions.
metadata:
  category: proxmox
---

# GPU / iGPU for transcoding

| | LXC sharing `/dev/dri` | VM PCIe passthrough |
|---|---|---|
| Host keeps GPU | yes | **no** (device leaves host) |
| Effort | low (`dev0` + gid) | IOMMU + vfio-pci + Q35/OVMF |
| Migration | CT can move | passthrough VMs can't live-migrate |

**GVT-g/mdev**: only older Intel gens (5th-7th + named E3) — not current iGPUs.
**SR-IOV** needs device+platform+driver; NVIDIA vGPU is licensed territory.

## LXC path
`ls -l /dev/dri`; `getent group render video` (host gid);
`pct set <id> --dev0 /dev/dri/renderD128,mode=0660,gid=<host-gid>`.
Prefer **specific gid** over `mode=0666` (world-writable nodes get flagged).
**Host/container gids differ** in unprivileged CTs — mismatch, not driver, is the usual cause.
**Verify as the service user, not root** (`vainfo`, `ffmpeg -hwaccels`, real codec encode test).
Passthrough isn't backed up; host kernel/driver updates can break it — retest after upgrades.

## VM path
IOMMU on (VT-d/AMD-Vi) → device in own group → detach host driver → vfio-pci bind.
Check `dmesg | grep -i iommu`, `/sys/kernel/iommu_groups/`, `lspci -nnk`.
Passed device leaves host and other guests.

## "Doesn't work" order
1. Node exists in guest (mode/gid)? 2. Service user can open it? 3. Userspace/VA-API libs
   present (node alone transcodes nothing)? 4. Codec exists on that GPU gen? 5. App configured
   for HW, logs show no software fallback?

## Hard rules
Never 0666/unconfined/privileged to "fix" GPU (fix the gid); never move GPU host↔guest
silently; re-verify after PVE/kernel/firmware changes.
