# VibeXperia — LineageOS 16.0 (Android 9) for the Sony Xperia M (`nicki`)

An experimental port of **LineageOS 16.0 / Android 9 (Pie)** to the 2013 Sony
Xperia M (codename **nicki**, Qualcomm MSM8227, dual Cortex‑A5, Adreno 305,
~880 MB RAM, Linux 3.4 kernel). Forward‑ported from the working
[15.1 port](https://github.com/RandomTypek/VibeXperia/tree/main).

> Hobby port, **still in bring‑up**. SELinux is **permissive**. The device tree
> still carries boot‑bring‑up diagnostics (forced‑adb, `/cache` boot tracers in
> `init.target.rc`) that should be stripped before any "release" build.

This is the **`lineage-16.0`** branch. The **`main`** branch is the (more
complete) 15.1 port.

## What works

| Area | Status |
|---|---|
| Boot to launcher (Trebuchet), Settings, touch, brightness | ✅ |
| ADB (recovery **and** booted) + USB/PC charging | ✅ |
| Display + compositing (bootanim, keyguard, **popups / notification shade / list scroll**) | ✅ |
| Display free of tearing/flicker (full MDP hardware composition) | ✅ |
| Wi‑Fi (assoc, DNS, autoconnect, **signal bars**) | ✅ |
| Sensors 5/5 (accel, prox, mag, orient, light + fused rotation) | ✅ |
| Auto‑rotate | ✅ |
| Audio | ✅ |
| Hardware video decode (H.264 — local files + browser) | ✅ |
| NFC (chip enables, HCI init OK; tag R/W untested) | ✅ |
| Telephony / RIL (insert a SIM) | ✅ |
| Bluetooth (enable, scan, real Sony BD_ADDR) | ✅ |
| Performance tuning (zram/swappiness, low‑RAM) | ✅ |
| **Camera** | ⚠️ enumerate + open + **live preview** work; **photo save hangs** (blob JPEG‑encode deadlock) |
| SELinux enforcing | ⚠️ permissive (parked) |

## Highlights of what it took (Oreo → Pie on a 3.4 kernel)

Pie carries the 15.1 kernel/graphics work (binder SG/multidev, alarmtimer,
Composer 2.1). The 16.0‑specific bring‑up:

- **SurfaceFlinger, unreliable HWC fences** — the msm8960 HWC1‑via‑`HWC2On1Adapter`
  reports `PresentFenceIsNotReliable`, and almost every Pie display bug on this
  device traces back to how SF handles that. Three stalls, in the order they
  appeared:
  1. `frameMissed` back‑pressure skipped compositing forever → black boot.
     Fixed with `debug.sf.disable_backpressure=1`.
  2. `FramebufferSurface` released its own FB buffer with that unreliable present
     fence → SF stalled ~10 s (`msm_fb_pan_idle`) on any animating surface
     (popup, shade, scroll). Fixed by dropping the fence (`NO_FENCE`) when the
     capability is set.
  3. …but the same `NO_FENCE` reflex had also been applied to the **per‑layer**
     release fence in `postFramebuffer`, which meant producers could overwrite a
     buffer the MDP overlay was still scanning out — a persistent **flicker** on
     slow scroll. This looked unfixable for a long time (honouring the fence
     froze the device) because the fence was *starved*, not broken: SF fed the
     unreliable present fence to `DispSync`, which corrupted the vsync model and
     disabled HW vsync — and the mdp4 **retire** fence that backs
     `getLayerReleaseFence()` only advances while the panel vsync IRQ is armed.
     Fixed by doing all three together, each guarded on the capability: skip
     `addPresentFence`, keep HW vsync permanently enabled, and honour the layer
     release fence again. The fence then signals ~2–3 refreshes late, which the
     triple‑buffered producers absorb.

  See `patches/android_frameworks_native.patch`.
- **Hardware video decode** — Pie's `Gralloc2` mapper validates buffer usage bits
  and rejected the QCOM‑private ones (`PRIVATE_UNCACHED`, `PRIVATE_IOMMU_HEAP`)
  the vidc decoder sets on its tiled‑NV12 output → every allocation failed and HW
  decode was dead (Oreo's direct‑gralloc path had no such validation). Whitelisted
  via `TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS`. (VP8/VP9/WebM stay software —
  the 720p vidc core has no VP8/VP9 block at all.)
- **kernel `commoncap`** — ambient caps were zeroed on a non‑root exec, so init’s
  `capabilities` line never reached HALs (`android.hardware.wifi@1.0-service`
  couldn’t get `NET_ADMIN` → no Wi‑Fi). Fixed in the kernel repo.
- **wificond** — the old prima driver reports TX bitrate in the legacy 16‑bit
  `NL80211_RATE_INFO_BITRATE`; Pie wificond required the 32‑bit variant and
  failed the whole signal poll → RSSI −127 → **no Wi‑Fi signal bars**. Added the
  fallback. See `patches/android_system_connectivity_wificond.patch`.
- **NFC** — `com.android.nfc` crash‑looped (`phHciNfc_Response_Timeout` → abort):
  libnfc `dlopen`ed its firmware from `/vendor/firmware/`, which the NFC app's
  linker namespace forbids, so the FW download was skipped and HCI init timed out.
  Repointed `FW_PATH` to `/vendor/lib/` where the blob actually lives. See
  `patches/android_external_libnfc-nxp.patch`.
- **rild** — a stale `libril.so` blob shadowed the CAF one that defines
  `ril_service_name` (removed in `vendor/`); also `O_TMPFILE` + legacy
  `/dev/android_adb` adbd + recovery‑wipe + audio kernel‑header fixes.

Full blow‑by‑blow in [`16.0-BUILD-NOTES.md`](16.0-BUILD-NOTES.md).

## Repo layout

```
device/sony/nicki/      Device tree (this repo, 16.0)
patches/                Changes to upstream LineageOS repos, one .patch each
local_manifests/        repo manifest fragment (pulls the kernel + vendor blobs)
16.0-BUILD-NOTES.md     Detailed bring-up log
```

Kernel lives in a separate repo:
**[android_kernel_sony_msm8x27](https://github.com/RandomTypek/android_kernel_sony_msm8x27)**
(branch `lineage-15.1-nicki` — shared with 15.1; carries the ambient‑cap and
`O_TMPFILE` fixes).

Proprietary Sony/Qualcomm blobs are **not** included — pull them from
[TheMuppets](https://github.com/TheMuppets/proprietary_vendor_sony)
(`lineage-16.0`). The one vendor change (removing the stale `libril.so` from
`nicki-vendor.mk`) is in `patches/vendor_sony_nicki.patch`.

## Building

```sh
repo init -u https://github.com/LineageOS/android.git -b lineage-16.0
# add local_manifests/nicki.xml, then:
repo sync
# apply patches/ to their respective repos, drop device/sony/nicki in place
source build/envsetup.sh && lunch lineage_nicki-userdebug && mka bacon
```

> Not an official LineageOS build. No warranty. Flashing may brick your device.
