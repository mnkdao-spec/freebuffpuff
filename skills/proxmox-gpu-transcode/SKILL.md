---
name: proxmox-gpu-transcode
description: Give a Proxmox guest hardware transcoding - sharing an Intel iGPU/Arc via /dev/dri into an unprivileged LXC versus whole-device PCIe (VFIO) passthrough to a VM - including device permissions, gid mapping, IOMMU prerequisites, and how to actually verify the codec works. Use when setting up Jellyfin/Navidrome/ffmpeg hardware transcoding, when transcoding silently falls back to CPU, when a container loses its GPU after a restart, or when asked whether to use an LXC or a VM for the media server.
metadata:
  category: proxmox
---

# GPU / iGPU for transcoding

## Pick the shape first
| | LXC, sharing `/dev/dri` | VM, PCIe passthrough |
|---|---|---|
| Host keeps the GPU | yes - the device node is shared | **no** - the device leaves the host |
| Effort | low (a `dev0` line + a gid) | IOMMU + vfio-pci binding + Q35/OVMF |
| Isolation | container shares the host kernel and driver | strong |
| Migration | CT can move | VMs with passthrough cannot live-migrate |
| Best when | the host may also use the iGPU, or you run the stack in an LXC | the GPU belongs entirely to one VM and you want a hard boundary |

- **GVT-g / mdev** is *not* a general option: the PVE guide documents it only for specific older
  Intel generations (5th-7th gen Core and named E3 Xeons). It is not a promise for current iGPUs.
- **SR-IOV** requires support in the device, the platform and the driver; NVIDIA vGPU is
  product/driver-licensed. Do not assume either.

## LXC path (usual choice on a homelab)
```bash
ls -l /dev/dri                       # renderD128 and/or card0
getent group render video            # note the HOST gid
# modern pct syntax:
pct set 120 --dev0 /dev/dri/renderD128,mode=0660,gid=<host-render-gid>
# older/hand-written configs use the raw form:
# lxc.cgroup2.devices.allow: c 226:* rwm
# lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
pct config 120 | grep -E 'dev0|lxc\.'
```
- Prefer a **specific gid** over `mode=0666`. World-writable device nodes are exactly the kind of
  convenience that turns into a finding later (the pack's scripts flag it for this reason).
- **gids differ between host and an unprivileged container.** If the service user inside cannot
  open the render node, that mismatch - not the driver - is usually the cause.
- **Verify as the service user, not as root.** Root can open almost anything, so a root-only test
  proves nothing:
```bash
pct exec 120 -- docker exec <container> vainfo            # expect VA-API entrypoints
pct exec 120 -- docker exec <container> ffmpeg -hide_banner -hwaccels
# real encode/decode test with the intended codec, then check the process really used the GPU
```
- Device passthrough is not backed up and binds the guest to the host kernel driver. A host kernel
  or driver update can change whether the node works - retest after PVE upgrades.

## VM path (full passthrough)
Prerequisites, in order: firmware **IOMMU enabled** (Intel VT-d / AMD-Vi), the device in its own
usable IOMMU group, host drivers detached, and vfio-pci bound.
```bash
dmesg | grep -i -e DMAR -e IOMMU          # is IOMMU on at all?
find /sys/kernel/iommu_groups/ -type l    # which group is the GPU in?
lspci -nnk | grep -A3 -i vga              # does the host driver currently own it?
```
The PVE PCI(e) Passthrough guide covers module binding, kernel options and the Q35/OVMF
recommendation. Once passed through, the device is unavailable to the host and to other guests.

## When transcoding "does not work"
Check in this order, and state which step you actually verified:
1. Does the device node exist **inside** the guest, with the right mode/gid?
2. Can the **service user** open it?
3. Do the userspace drivers/VA-API libraries exist in that image (a device node alone transcodes nothing)?
4. Does the codec you asked for exist on that GPU generation? Hardware support is per-codec, not per-GPU.
5. Is the app configured to use hardware at all (its own transcode settings), and does the log say
   it fell back to software?

## Hard rules
- Never widen `mode` to 0666, disable AppArmor, or make a container privileged to "fix" the GPU.
  Fix the gid.
- Never move the GPU between host and guest without saying that the host loses it.
- After any PVE/kernel/firmware change, re-verify (1)-(4) rather than assuming it still works.
