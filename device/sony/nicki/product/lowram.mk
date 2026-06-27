# Android Go / low-RAM optimizations for nicki (MSM8227, ~880 MB usable RAM).
# Adapted from build/make/target/product/go_defaults_common.mk. zRAM (~400 MB
# compressed swap) is already configured, so this layer adds the framework-level
# low-RAM mode and the dexopt/lmkd tuning that goes with it. We intentionally do
# NOT inherit go_defaults wholesale (it strips apps / forces GMS-Go choices we
# don't want on an unofficial build) -- only the memory-relevant knobs.

# Framework low-RAM mode: ActivityManager.isLowRamDevice() -> true. Shrinks the
# cached-process limit, drops force_highendgfx, trims SystemUI/launcher caches
# and zygote preloading. The single biggest RAM win on a 1 GB device.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.low_ram=true

# lmkd: react sooner under memory pressure (Go-recommended vmpressure tuning).
PRODUCT_PROPERTY_OVERRIDES += \
    ro.lmk.critical_upgrade=true \
    ro.lmk.upgrade_pressure=40

# dexopt: downgrade unused apps to save storage, and quicken (not speed) shared
# APKs to trade clean-for-dirty pages -- less RAM for shared code across procs.
PRODUCT_PROPERTY_OVERRIDES += \
    pm.dexopt.downgrade_after_inactive_days=10 \
    pm.dexopt.shared=quicken

# Cap dex2oat peak heap so on-device compilation (app install/update, first
# boot) doesn't spike RAM on the 880 MB device. image-dex2oat is the boot.oat
# compile; the smaller dex2oat-* bounds per-app compiles. Ported from 14.1.
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.dex2oat-Xms=8m \
    dalvik.vm.dex2oat-Xmx=128m \
    dalvik.vm.image-dex2oat-Xms=64m \
    dalvik.vm.image-dex2oat-Xmx=64m

# Speed-profile the system server to cut its resident footprint.
PRODUCT_SYSTEM_SERVER_COMPILER_FILTER := speed-profile
