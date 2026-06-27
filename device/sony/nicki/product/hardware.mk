# Hardware permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/handheld_core_hardware.xml:system/etc/permissions/handheld_core_hardware.xml

# Hardware configurations
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.qcom.baseband.sh:system/etc/init.qcom.baseband.sh \
    $(LOCAL_PATH)/rootdir/init.class_main.sh:root/init.class_main.sh

# Lights package
PRODUCT_PACKAGES += \
    android.hardware.light@2.0-impl \
    lights.msm8960
