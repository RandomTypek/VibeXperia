# WiFi
BOARD_HAS_QCOM_WLAN              := true
BOARD_WLAN_DEVICE                := qcwcn
BOARD_HOSTAPD_DRIVER             := NL80211
BOARD_HOSTAPD_PRIVATE_LIB        := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_DRIVER      := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
# nicki: deliberately DO NOT set WIFI_DRIVER_MODULE_PATH / _NAME. The Prima wlan.ko
# is preloaded as root by rootdir/etc/load_wlan.sh (which also waits for the async
# wcnss firmware and chowns /sys/module/wlan/parameters/fwpath to wifi:wifi, which
# the unprivileged wifi HAL cannot do -- DriverTool::TakeOwnershipOfFirmwareReload()
# is dead code, never called in this HAL). If MODULE_PATH is set, libwifi_hal's
# wifi_unload_driver() rmmods the driver on WiFi-OFF and re-insmods on WiFi-ON; the
# reload recreates fwpath as root:root, the HAL can't chown it, and the sta/ap
# firmware-mode switch fails ("Failed to change firmware mode") -> WiFi won't
# re-enable after being toggled off. Leaving these unset makes the insmod/rmmod
# compile out (#ifdef WIFI_DRIVER_MODULE_PATH), so the HAL leaves the preloaded
# driver alone and toggling WiFi off/on works. FW_PATH_STA/AP stay set so the HAL
# still performs the mode switch (fwpath was pre-chowned by load_wlan.sh).
WIFI_DRIVER_FW_PATH_STA          := "sta"
WIFI_DRIVER_FW_PATH_AP           := "ap"
WPA_SUPPLICANT_VERSION           := VER_0_8_X
