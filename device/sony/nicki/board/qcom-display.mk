# Display
TARGET_DISPLAY_USE_RETIRE_FENCE := true
TARGET_USES_C2D_COMPOSITION := true

# Enables Adreno RS driver
OVERRIDE_RS_DRIVER := libRSDriver_adreno.so

# Ion
TARGET_USES_ION := true

# nicki: whitelist the QCOM-private gralloc usage bits the msm8960 stack sets.
# Pie's frameworks/native Gralloc2::Mapper::validateBufferDescriptorInfo()
# rejects (BAD_VALUE) any buffer whose usage has bits outside the standard valid
# mask. The msm8960 HW video decoder requests PRIVATE_UNCACHED (1<<25) +
# PRIVATE_IOMMU_HEAP (1<<30) for its tiled-NV12 (0x7FA30C03) output buffers, so
# the allocation failed ("dequeueBuffer failed: Out of memory" -> decoder start
# failed) and HW video decode was dead. Oreo's non-Treble direct-gralloc path
# had no such validation (why 15.1 HW-decodes fine with the same blob). Whitelist
# the full QCOM private range (heap selectors + uncached + camera/external) so
# the decoder and camera buffers pass. Fed to libui via the lineage
# additional_gralloc_10_usage_bits soong var (-DADDNL_GRALLOC_10_USAGE_BITS).
TARGET_ADDITIONAL_GRALLOC_10_USAGE_BITS := 0 | (1ULL << 20) | (1ULL << 21) | (1ULL << 24) | (1ULL << 25) | (1ULL << 27) | (1ULL << 28) | (1ULL << 29) | (1ULL << 30) | (1ULL << 31)

# Shader cache config options
# Maximum size of the  GLES Shaders that can be cached for reuse.
# Increase the size if shaders of size greater than 12KB are used.
MAX_EGL_CACHE_KEY_SIZE := 12*1024

# Maximum GLES shader cache size for each app to store the compiled shader
# binaries. Decrease the size if RAM or Flash Storage size is a limitation
# of the device.
MAX_EGL_CACHE_SIZE := 2048*1024
