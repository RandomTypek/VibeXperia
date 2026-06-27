ifneq ($(TARGET_NEEDS_CAMERA_WRAPPER),false)
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    CameraWrapper.cpp

LOCAL_C_INCLUDES := \
    framework/native/include \
    system/media/camera/include

LOCAL_SHARED_LIBRARIES := \
    libhardware \
    liblog \
    libcamera_client \
    libgui \
    libhidltransport \
    libsensor \
    libutils \
    android.hidl.token@1.0-utils

LOCAL_STATIC_LIBRARIES := \
    libarect

# nicki: was `LOCAL_MODULE_PATH := hw` which is malformed in the Oreo build
# system - it installed camera.qcom.so to out/.../hw/ instead of /system/lib/hw/,
# so hw_get_module("camera") (ro.hardware=qcom -> camera.qcom.so) found nothing
# and cameraserver reported 0 cameras. Correct directive installs to system/lib/hw.
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_MODULE := camera.qcom
LOCAL_MODULE_TAGS := optional
include $(BUILD_SHARED_LIBRARY)
endif
