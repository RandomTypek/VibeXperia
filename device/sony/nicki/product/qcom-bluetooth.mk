# Bluetooth permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:system/etc/permissions/android.hardware.bluetooth_le.xml

# Bluetooth HAL
# nicki: use the BINDERIZED service (own process) instead of relying on the bare
# passthrough @1.0-impl. In passthrough the impl loads INSIDE com.android.bluetooth
# and its initialize() calls cb->linkToDeath() on a same-process callback, which
# aborts on Pie -> com.android.bluetooth SIGABRTs in hci_thread every ~0.8s
# (crash-loop that starves this dual-A5 CPU and ANRs SystemUI/SetupWizard). Oreo
# 15.1 tolerated passthrough; Pie does not. The -service binary does
# defaultPassthroughServiceImplementation<IBluetoothHci>() = it dlopens the SAME
# @1.0-impl.so but re-serves it over hwbinder from /vendor/bin/hw, so the callback
# is cross-process and linkToDeath works. Keep @1.0-impl (the service loads it) +
# libbt-vendor. Declared hwbinder in manifest.xml.
PRODUCT_PACKAGES += \
    libbt-vendor \
    android.hardware.bluetooth@1.0-impl \
    android.hardware.bluetooth@1.0-service
