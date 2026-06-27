# GPS permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.location.gps.xml:system/etc/permissions/android.hardware.location.gps.xml

# GPS packages
PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0-impl \
    gps.msm8960 \
    gps.conf \
    sap.conf \
    izat.conf
