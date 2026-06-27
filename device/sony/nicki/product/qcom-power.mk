# Power package
PRODUCT_PACKAGES += \
    android.hardware.power@1.0-impl \
    power.qcom

# vendor.lineage.power HAL: lets LineageOS 15.1 PerformanceManager see the
# performance-profile support (Battery > profile picker). The legacy passthrough
# power HAL still handles profile switching via IPower::powerHint(SET_PROFILE).
PRODUCT_PACKAGES += \
    vendor.lineage.power@1.0-service.nicki

# QCOM-perf properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.extension_library=libqti-perfd-client.so
