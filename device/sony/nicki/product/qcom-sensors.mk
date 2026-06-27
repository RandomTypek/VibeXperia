# Sensors permissions

# Sensors HAL: the legacy nicki blob (sensors.default.so) is a complete,
# functional HAL (proximity/light/accel/mag/orientation, verified delivering
# real data) but reports device API version 0. We wrap it with the in-tree
# multihal (sensors.msm8960.so) which presents API 1.4 to the framework and
# guards all version-0 forwarding (batch->setDelay, flush->-EINVAL). multihal
# loads the blob per _hals.conf. Run it BINDERIZED (own process) rather than
# passthrough so a HAL crash is catchable (handleHidlDeath) and can't take down
# system_server. The earlier crash was a multihal NULL-deref of sub_hw_versions
# in get_sensors_list (now guarded in multihal.cpp).
PRODUCT_PACKAGES += \
    sensors.msm8960 \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.sensor.light.xml:system/etc/permissions/android.hardware.sensor.light.xml \
    frameworks/native/data/etc/android.hardware.sensor.proximity.xml:system/etc/permissions/android.hardware.sensor.proximity.xml \
    device/sony/nicki/rootdir/system/etc/_hals.conf:system/vendor/etc/sensors/_hals.conf
