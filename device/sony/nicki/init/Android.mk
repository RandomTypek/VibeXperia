LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional
# Oreo's system/core/init/util.h includes <selinux/label.h>; add libselinux headers
LOCAL_C_INCLUDES := system/core/init external/selinux/libselinux/include
LOCAL_SRC_FILES := init_nicki.cpp
LOCAL_MODULE := libinit_nicki
# Android 9's system/core/init headers (result.h/util.h) require C++17
# (std::is_same_v, std::monostate, Result/Success/Error).
LOCAL_CPPFLAGS += -std=gnu++17

LOCAL_STATIC_LIBRARIES := libbase libselinux

include $(BUILD_STATIC_LIBRARY)
