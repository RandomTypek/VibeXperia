# Media codecs
# nicki: use a device-local google_video_le list with the SW-only VP8/VP9/HEVC
# decoders removed (no HW decoder on MSM8227) so web players serve HW-decodable
# H.264 instead of software-decoded VP9 -- see configs/media_codecs_google_video_le.xml.
PRODUCT_COPY_FILES += \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:system/etc/media_codecs_google_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:system/etc/media_codecs_google_telephony.xml \
    $(LOCAL_PATH)/configs/media_codecs_google_video_le.xml:system/etc/media_codecs_google_video_le.xml

# OMX packages
PRODUCT_PACKAGES += \
    libOmxAacEnc \
    libOmxAmrEnc \
    libOmxCore \
    libOmxEvrcEnc \
    libOmxQcelp13Enc \
    libOmxVdec \
    libOmxVenc \
    libc2dcolorconvert \
    libdivxdrmdecrypt \
    libmm-omxcore \
    libstagefrighthw

# OMX properties
PRODUCT_PROPERTY_OVERRIDES += \
    persist.media.treble_omx=false

# DRM packages
PRODUCT_PACKAGES += \
    android.hardware.drm@1.0-impl \
    com.google.widevine.software.drm

# DRM properties
PRODUCT_PROPERTY_OVERRIDES += \
    drm.service.enabled=true \
    media.stagefright.legacyencoder=true \
    media.stagefright.less-secure=true \
    qcom.hw.aac.encoder=true
