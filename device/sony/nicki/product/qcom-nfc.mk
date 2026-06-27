# NFC permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.nfc.xml:system/etc/permissions/android.hardware.nfc.xml \
    frameworks/native/data/etc/com.android.nfc_extras.xml:system/etc/permissions/com.android.nfc_extras.xml

# NFC packages
# NFC HAL (android.hardware.nfc@1.0-impl/-service) disabled: no working nfc_nci
# blob for the pn544 on this port (hw_get_module nfc_nci -> -2), so the HAL
# service SIGABRT-crash-loops. Also removed from manifest.xml. The Nfc app
# stays inert (no HAL declared -> NFC unavailable, no crash).
PRODUCT_PACKAGES += \
    com.android.nfc_extras \
    libnfc \
    libnfc_jni \
    Nfc \
    Tag

# NFC FW
PRODUCT_PACKAGES += \
    libpn544_fw
