LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := nicki_sensorprobe
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := sensortest.cpp
LOCAL_SHARED_LIBRARIES := libdl libcutils liblog libhardware
LOCAL_CFLAGS := -Wall -Wno-unused-parameter
LOCAL_PROPRIETARY_MODULE := true
include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)
LOCAL_MODULE := nicki_sensorpoll
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := sensorpoll.cpp
LOCAL_SHARED_LIBRARIES := libandroid liblog
LOCAL_CFLAGS := -Wall -Wno-unused-parameter
include $(BUILD_EXECUTABLE)
