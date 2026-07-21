# Power package: the @1.0 passthrough wrapper + the legacy power.qcom.so it loads.
# Without power.qcom (built from device/sony/nicki/power/power-nicki.c) the
# passthrough falls back to the generic no-op power.default.so and performance-
# profile SWITCHING does nothing. power.qcom implements it via cpufreq-direct.
PRODUCT_PACKAGES += \
    android.hardware.power@1.0-impl \
    power.msm8960

# vendor.lineage.power@1.0 service (nicki): RE-ENABLED — it is declared in
# manifest.xml, so LineageOS system_server does a BLOCKING ILineagePower::
# getService() during StartBootPhaseSystemServicesReady. With the service
# disabled the framework waited forever ("Waited one second for
# vendor.lineage.power@1.0::ILineagePower/default. Waiting another...") and boot
# never reached boot_completed. The service (service.cpp) is self-contained —
# it only answers getFeature(SUPPORTED_PROFILES)=3 and does NOT depend on the
# dropped legacy power.h extensions, so it builds cleanly on Pie. The actual
# profile-SWITCHING plumbing (powerHint SET_PROFILE -> set_power_profile) is now
# provided by the power.qcom module above (cpufreq-direct, ported from 15.1).
PRODUCT_PACKAGES += \
    vendor.lineage.power@1.0-service.nicki

# QCOM-perf properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.vendor.extension_library=libqti-perfd-client.so
