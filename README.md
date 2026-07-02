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
| Wi‑Fi (assoc, DNS, autoconnect, **signal bars**) | ✅ |
| Sensors 5/5 (accel, prox, mag, orient, light + fused rotation) | ✅ |
| Audio | ✅ |
| NFC | ✅ |
| Telephony / RIL (insert a SIM) | ✅ |
| Performance tuning (zram/swappiness, low‑RAM) | ✅ |
| **Bluetooth** | ⚠️ HAL up, radio doesn't (chip rejects a controller‑init cmd) |
| **Camera** | ⚠️ 0 devices (HAL1 fixes from 15.1 not yet ported) |
| SELinux enforcing | ⚠️ permissive (parked) |

## Highlights of what it took (Oreo → Pie on a 3.4 kernel)

Pie carries the 15.1 kernel/graphics work (binder SG/multidev, alarmtimer,
Composer 2.1). The 16.0‑specific bring‑up:

- **SurfaceFlinger, unreliable HWC fences** — the msm8960 HWC1‑via‑`HWC2On1Adapter`
  reports `PresentFenceIsNotReliable`. Two Pie‑only stalls followed:
  1. `frameMissed` back‑pressure skipped compositing forever → black boot.
     Fixed with `debug.sf.disable_backpressure=1`.
  2. `FramebufferSurface` released its own FB buffer with that unreliable present
     fence → SF stalled ~10 s (`msm_fb_pan_idle`) on any animating surface
     (popup, shade, scroll). Fixed by dropping the fence (`NO_FENCE`) when the
     capability is set. See `patches/android_frameworks_native.patch`.
- **kernel `commoncap`** — ambient caps were zeroed on a non‑root exec, so init’s
  `capabilities` line never reached HALs (`android.hardware.wifi@1.0-service`
  couldn’t get `NET_ADMIN` → no Wi‑Fi). Fixed in the kernel repo.
- **wificond** — the old prima driver reports TX bitrate in the legacy 16‑bit
  `NL80211_RATE_INFO_BITRATE`; Pie wificond required the 32‑bit variant and
  failed the whole signal poll → RSSI −127 → **no Wi‑Fi signal bars**. Added the
  fallback. See `patches/android_system_connectivity_wificond.patch`.
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
