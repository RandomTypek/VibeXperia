# VibeXperia — LineageOS 15.1 (Android 8.1) for the Sony Xperia M (`nicki`)

An experimental, **working** revival of LineageOS 15.1 / Android 8.1.0 on the
2013 Sony Xperia M (codename **nicki**, Qualcomm MSM8227, dual Cortex‑A5, Adreno
305, ~880 MB RAM, Linux 3.4 kernel). The upstream 15.1 device tree compiled but
never booted; this brings it all the way up to a daily‑usable state.

> Hobby port. SELinux is currently **permissive**.

## What works

| Area | Status |
|---|---|
| Boot to launcher (Trebuchet), Settings, touch, brightness | ✅ |
| ADB (recovery **and** booted) + USB/PC charging | ✅ |
| Suspend / resume (instant wake + touch) | ✅ |
| Wi‑Fi (assoc, IPv4/IPv6, DNS, autoconnect, signal bars) | ✅ |
| Audio + video playback | ✅ |
| Sensors 5/5 (accel, prox, mag, orient, light + fused rotation) | ✅ |
| Telephony / RIL (insert a SIM) | ✅ |
| **Camera — enumerate + open + live preview + photo capture** | ✅ |
| Web browser (Jelly / Android WebView) | ✅ |
| Landscape rotation + notification shade | ✅ |
| Notification LED, performance‑profile picker, baseband, BT MAC | ✅ |
| SELinux enforcing | ⚠️ permissive (parked) |
| Microphone ~10 kHz whine | ⚠️ hardware coupling (deferred) |

## Highlights of what it took

Oreo on a 2013 CAF 3.4 kernel needed real kernel work, not just config:

- **binder**: backported multiple `/dev` instances (`hwbinder`/`vndbinder`) **and**
  scatter‑gather (`BINDER_TYPE_PTR/FDA`, `BC_TRANSACTION_SG`) — the make‑or‑break
  for Oreo HIDL.
- **timerfd / alarmtimer**: `CLOCK_BOOTTIME` + `*_ALARM` so wake‑alarms work.
- **PR_CAP_AMBIENT**: ambient capabilities so `crash_dump` produces tombstones.
- **net**: `NL80211_ATTR_MAC` + lenient `rtnetlink` attr parsing to unblock Oreo
  netd routing/DNS.
- **display**: fixed the early‑suspend vs Oreo‑HWC resume deadlock.
- **camera**: 4 fixes in the HAL1 shim (`hardware/interfaces`) — usage
  sign‑extension, gralloc‑lock of preview buffers, registerMemory bypass, and a
  single‑open cookie‑recovery that fixes the snapshot SIGSEGV.

Full blow‑by‑blow in [`15.1-BUILD-NOTES.md`](15.1-BUILD-NOTES.md).

## Repo layout

```
device/sony/nicki/      Device tree (this repo)
patches/                Changes to upstream LineageOS repos, one .patch each
local_manifests/        repo manifest fragment (pulls the kernel + vendor blobs)
15.1-BUILD-NOTES.md     Detailed bring-up log
```

Kernel lives in a separate repo:
**[android_kernel_sony_msm8x27](https://github.com/RandomTypek/android_kernel_sony_msm8x27)**
(branch `lineage-15.1-nicki`).

Proprietary Sony/Qualcomm blobs are **not** included — pull them from
[TheMuppets](https://github.com/TheMuppets/proprietary_vendor_sony) (`lineage-15.1`).

## Building

```bash
# 1. LineageOS 15.1 sources
repo init -u https://github.com/LineageOS/android.git -b lineage-15.1

# 2. add this manifest fragment (kernel + vendor blobs + qcom/sony common)
cp local_manifests/nicki.xml .repo/local_manifests/
repo sync

# 3. drop in the device tree from this repo
cp -a device/sony/nicki <android_root>/device/sony/

# 4. apply the upstream patches (filename = target project path, '_' -> '/')
#    e.g. patches/android_hardware_interfaces.patch -> hardware/interfaces
(cd hardware/interfaces && git apply .../patches/android_hardware_interfaces.patch)
#    ...repeat for each patch

# 5. build
. build/envsetup.sh && brunch nicki
```

Gotchas (see `15.1-BUILD-NOTES.md`): recovery is flashed to the **boot**
partition (`fastboot flash boot recovery.img`); for a clean wipe `mke2fs`
userdata in recovery; the device is non‑Treble (`vendor` under `/system`).

## Credits

Based on the LineageOS 15.1 nicki device tree (droncheg) and the LineageOS
project. Bring‑up by [@RandomTypek](https://github.com/RandomTypek), with
debugging assistance from Claude (Anthropic).
