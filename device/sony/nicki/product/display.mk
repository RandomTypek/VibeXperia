# Display properties
PRODUCT_PROPERTY_OVERRIDES += \
    persist.debug.wfd.enable=1 \
    persist.hwc.mdpcomp.enable=true \
    persist.sys.wfd.virtual=0 \
    ro.sf.lcd_density=240

# nicki: disable SurfaceFlinger frame-missed backpressure. The legacy msm8960
# HWC1 (wrapped by HWC2On1Adapter) advertises HWC2::Capability::
# PresentFenceIsNotReliable -> its per-frame present fence never signals. Pie's
# SurfaceFlinger::onMessageReceived(INVALIDATE) computes frameMissed from
# mPreviousPresentFence->getSignalTime()==SIGNAL_TIME_PENDING WITHOUT honoring
# that capability, so on this device frameMissed is true forever; with
# mPropagateBackpressure (default on) SF does signalLayerUpdate()+break, skipping
# ALL composition indefinitely. Result: after the first Device-composited frame
# SF stops compositing -> never latches/releases buffers -> every GLES producer
# (bootanimation, SystemUI, all apps) blocks in eglSwapBuffers->dequeueBuffer ->
# bootanim hangs black + never exits, SystemUI ANRs = "dead display". Oreo did
# not have this backpressure path, which is why 8.1 worked with identical blobs.
# Disabling backpressure lets SF composite every frame -> buffers cycle. Verified
# live: bootanim exits, keyguard/UI renders, SF binder responsive.
PRODUCT_PROPERTY_OVERRIDES += \
    debug.sf.disable_backpressure=1

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
