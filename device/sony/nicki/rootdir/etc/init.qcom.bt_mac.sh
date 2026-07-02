#!/system/bin/sh
# nicki: provision a genuine Sony-OUI Bluetooth address into /persist/.bt_nv.bin.
#
# The nicki tree has no mechanism to seed the BT controller address from the
# factory TA partition, so btnvtool (config_bt_addr) generates a placeholder on
# first boot with a non-Sony OUI (observed 08:00:00:..). Wi-Fi, by contrast,
# gets its genuine Sony MAC (e.g. 44:d4:e0:..) from the factory-provisioned
# /persist/WCNSS_qcom_wlan_nv.bin. To give Bluetooth a real, stable,
# device-unique Sony address (LineageOS charter "matching MAC address"), derive
# the BT address from the factory Wi-Fi MAC -- Wi-Fi minus 1 in the low octet,
# the convention Sony's own device trees use -- and write it in the QC NV format
# btnvtool/bluedroid expect.
#
# Idempotent: only rewrites when the existing BT OUI does not already match the
# Wi-Fi OUI, so it never clobbers a genuine factory BT address and only acts
# once. Runs as a root oneshot before 'config_bt_addr' in init.qcom.rc.

BT_NV=/persist/.bt_nv.bin
WLAN_NV=/persist/WCNSS_qcom_wlan_nv.bin

# Publish the controller BD_ADDR from the NV to the property the AOSP Bluetooth
# HAL actually reads. bluetooth_address.cc::get_local_address() only accepts an
# ASCII "AA:BB:CC:DD:EE:FF" from ro.bt.bdaddr_path / ro.boot.btmacaddr /
# persist.service.bdroid.bdaddr -- it does NOT parse the binary .bt_nv.bin (the
# controller NV). With none of them set, vendor_interface.cc does
# LOG_ALWAYS_FATAL("Open: No Bluetooth Address!") and android.hardware.bluetooth
# @1.0-service crash-loops (~every 0.8s), which starves this dual-A5 and ANRs the
# UI. config_bt_addr provisions the NV but never bridged it to the HAL (Oreo
# 15.1 had the same gap; it only surfaced on Pie once BT ran binderized). Read
# the 6 address bytes at NV offset 3 (stored LSB-first) and export them as ASCII.
# Runs every boot -- including when the provisioning below is an idempotent no-op.
publish_bdaddr() {
    [ -f "$BT_NV" ] || return
    _raw=$(dd if="$BT_NV" bs=1 skip=3 count=6 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ ${#_raw} -eq 12 ] || return
    _mac="${_raw:10:2}:${_raw:8:2}:${_raw:6:2}:${_raw:4:2}:${_raw:2:2}:${_raw:0:2}"
    case "$_mac" in 00:00:00:00:00:00|ff:ff:ff:ff:ff:ff) return ;; esac
    setprop persist.service.bdroid.bdaddr "$_mac"
}
publish_bdaddr

[ -f "$WLAN_NV" ] || exit 0

# Factory Wi-Fi MAC: 6 bytes in display order at offset 10 of the WCNSS NV.
WMAC=$(dd if="$WLAN_NV" bs=1 skip=10 count=6 2>/dev/null | od -An -tx1 | tr -d ' \n')
[ ${#WMAC} -eq 12 ] || exit 0

# Bail if the Wi-Fi MAC itself looks like a default/invalid value.
case "$WMAC" in
    000af58989ff|000000000000|ffffffffffff) exit 0 ;;
esac

WOUI=${WMAC%??????}        # first 3 octets (6 hex chars)

# Current BT address: bytes 3..8 of the NV, stored LSB-first; reverse to display.
if [ -f "$BT_NV" ]; then
    BRAW=$(dd if="$BT_NV" bs=1 skip=3 count=6 2>/dev/null | od -An -tx1 | tr -d ' \n')
    if [ ${#BRAW} -eq 12 ]; then
        BOUI="${BRAW:10:2}${BRAW:8:2}${BRAW:6:2}"
        # Already a Sony (== Wi-Fi OUI) address: nothing to do.
        [ "$BOUI" = "$WOUI" ] && exit 0
    fi
fi

# Derive BT address = Wi-Fi MAC with the low octet decremented (Sony convention).
LO=$((0x${WMAC#??????????}))
if [ "$LO" -eq 0 ]; then
    LO=1
else
    LO=$((LO - 1))
fi
LOhex=$(printf '%02x' "$LO")
BMAC="${WMAC%??}${LOhex}"  # display-order BT MAC, e.g. 44d4e04608fe

# QC NV layout: id 01 00, len 06, then the 6 address bytes LSB-first.
B0=${BMAC:0:2}; B1=${BMAC:2:2}; B2=${BMAC:4:2}
B3=${BMAC:6:2}; B4=${BMAC:8:2}; B5=${BMAC:10:2}
printf "\\x01\\x00\\x06\\x${B5}\\x${B4}\\x${B3}\\x${B2}\\x${B1}\\x${B0}" > "$BT_NV"

chown bluetooth.bluetooth "$BT_NV" 2>/dev/null
chmod 0660 "$BT_NV" 2>/dev/null
restorecon "$BT_NV" 2>/dev/null

# Drop the bluedroid address cache so the stack repopulates it from the (now
# genuine) controller BD_ADDR on the next enable instead of reusing the stale
# placeholder. Only happens on this one migration boot -- the OUI guard above
# makes subsequent boots a no-op, so real pairing data is never wiped after.
rm -f /data/misc/bluedroid/bt_config.conf /data/misc/bluedroid/bt_config.bak 2>/dev/null

# Hand off to the stock NV validation step. btnvtool -O leaves an existing,
# valid-format .bt_nv.bin untouched, so our provisioned address persists. This
# runs as part of the config_bt_addr oneshot so provisioning is guaranteed to
# complete before btnvtool (and thus before bluedroid) reads the NV.
/system/bin/btnvtool -O

# Re-publish now that the NV holds the freshly provisioned Sony address (the
# top-of-script publish ran before this migration wrote it).
publish_bdaddr
