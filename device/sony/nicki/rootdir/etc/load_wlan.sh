#!/system/bin/sh
# Load the Prima wlan.ko early in boot so the WiFi framework's auto-enable
# (which happens well before sys.boot_completed) finds the driver ready.
# The android.hardware.wifi@1.0-service runs as the unprivileged 'wifi' uid
# and cannot insmod the module (no CAP_SYS_MODULE), so init (root) loads it.
# Retry the insmod until wlan0 actually appears, so we don't depend on exact
# wcnss-ready timing, then publish wlan.driver.status=ok (so the HAL's
# is_wifi_driver_loaded() short-circuits) and make the firmware-mode param
# (fwpath) writable by 'wifi' for the HAL's sta/ap switch.
i=0
while [ $i -lt 120 ]; do
    if [ -d /sys/class/net/wlan0 ]; then
        chown wifi.wifi /sys/module/wlan/parameters/fwpath 2>/dev/null
        chmod 0660 /sys/module/wlan/parameters/fwpath 2>/dev/null
        setprop wlan.driver.status ok
        exit 0
    fi
    insmod /vendor/lib/modules/wlan.ko 2>/dev/null
    sleep 0.25
    i=$((i + 1))
done
exit 0
