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

# nicki: latch producer buffers whose acquire fence has not signalled yet. The
# Adreno 305 render fences are slow to signal on the weak dual-A5, so SF often
# finds a buffer's acquire fence still SIGNAL_TIME_PENDING at VSYNC-latch and
# skips the update = a dropped/janky frame. Latching anyway (the GPU is virtually
# always done by scanout) removes those stalls: measured janky frames 45.8% ->
# 17.4% on a Settings fling, and the device feels markedly snappier. (Not the
# cause of the residual display flicker -- verified with it off; see the idletime
# note below.)
PRODUCT_PROPERTY_OVERRIDES += \
    debug.sf.latch_unsignaled=1

# nicki: disable MDPComp idle-fallback (the idle invalidator). By default the
# msm8960 HWC drops ALL layers to GPU/GLES composition after the display is idle
# for a moment (to let the MDP overlay pipes power down) and re-evaluates lazily,
# so in practice the UI is almost always composited by GLES into a single
# framebuffer (dumpsys SurfaceFlinger: `mdpCount 0 fbCount 3`). That GLES
# framebuffer is the surface that gets reused while the MDP is still scanning it
# out to the video-mode DSI panel (the present/retire fence is unusable as a
# release gate on this HWC1-via-HWC2On1Adapter, so it is released immediately) ->
# TEARING + glitching, worst during slow scrolling (idle-fallback flip-flopping).
# Setting the idle timeout to -1 disables the IdleInvalidator entirely
# (hwc_mdpcomp.cpp:126) so MDPComp keeps the layers on hardware overlay pipes
# (`mdpCount N fbCount 0`) -- the MDP then composites + page-flips them in
# hardware at vsync, with no reused GLES framebuffer to tear. Costs a little
# idle/standby power (overlay pipes stay up when idle) but is the better config
# for this weak Adreno 305 anyway: full MDP composition offloads ALL compositing
# off the GPU (fbCount 0). Kept for that GPU-offload perf/thermal win.
#
# NOTE: this converts the framebuffer TEARING into a residual per-layer FLICKER
# (worst on slow scroll) -- it does NOT fully fix the display artifact. Both
# tearing and flicker share one unfixed root: on this HWC1-via-HWC2On1Adapter the
# present/retire fence never signals usefully on Pie (it does on Oreo/15.1 with
# the identical blob+kernel), so SF cannot pace/synchronise buffer release to the
# panel scanout. disable_backpressure (above) is required or the display
# black-screens, but it removes SF's pacing throttle -> SF runs ahead -> flicker.
# The real fix is a deep Oreo->Pie SF/HWC2On1Adapter present-fence regression
# (parked). Every attempt to honour the fence hard-freezes the device.
PRODUCT_PROPERTY_OVERRIDES += \
    debug.mdpcomp.idletime=-1

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
