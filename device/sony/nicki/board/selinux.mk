# Device sepolicies
BOARD_SEPOLICY_DIRS += \
    $(DEVICE_PATH)/sepolicy

# QCOM common sepolicy (provides qmux_socket etc. macros + msm8960 types,
# public/private dirs, BOARD_SEPOLICY_VERS) — the device .te files require it.
include device/qcom/sepolicy/sepolicy.mk
