# Display properties
PRODUCT_PROPERTY_OVERRIDES += \
    persist.debug.wfd.enable=1 \
    persist.hwc.mdpcomp.enable=true \
    persist.sys.wfd.virtual=0 \
    ro.sf.lcd_density=240

# nicki: disable hwui EGL partial-update (eglSetDamageRegionKHR) path. The legacy
# Adreno 305 EGL blob does not account for the buffer pre-rotation transform that
# the framework uses for landscape app surfaces (buffer is swapped to 480x854 +
# tagged ROT_270). With partial updates on, redraw-heavy apps (browser, files,
# scrolling lists) only repaint a clipped 480px-wide region -> landscape shows the
# app content squished into a portrait-width strip with a black bar on the side.
# Static/full-redraw apps (e.g. Settings) happened to look fine. Forcing full
# redraws makes every app rotate correctly. (Buffer-age can stay on.)
PRODUCT_PROPERTY_OVERRIDES += \
    debug.hwui.use_partial_updates=false
