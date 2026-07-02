# Power package
PRODUCT_PACKAGES += \
    android.hardware.power@1.0-impl

# vendor.lineage.power@1.0 service (nicki): RE-ENABLED — it is declared in
# manifest.xml, so LineageOS system_server does a BLOCKING ILineagePower::
# getService() during StartBootPhaseSystemServicesReady. With the service
# disabled the framework waited forever ("Waited one second for
# vendor.lineage.power@1.0::ILineagePower/default. Waiting another...") and boot
# never reached boot_completed. The service (service.cpp) is self-contained —
# it only answers getFeature(SUPPORTED_PROFILES)=3 and does NOT depend on the
# dropped legacy power.h extensions, so it builds cleanly on Pie. This unblocks
# boot; the actual profile-SWITCHING plumbing (powerHint SET_PROFILE ->
# power-8960.c set_power_profile) is a separate Phase-2 re-port. TODO.
PRODUCT_PACKAGES += \
    vendor.lineage.power@1.0-service.nicki

# QCOM-perf properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.extension_library=libqti-perfd-client.so
