#!/system/bin/sh
# nicki: publish the modem firmware (baseband) version into gsm.version.baseband,
# which Settings reads as "Baseband version". The closed modem answers
# GENERIC_FAILURE to RIL_REQUEST_BASEBAND_VERSION, so the framework leaves the
# property empty and Settings shows "Unknown". Recover the genuine modem RTOS
# build string ("BLAST Kernel ver.: NN.NN...") embedded in the modem firmware
# image and publish that instead.
#
# (The previous body grepped /dev/block/bootdevice/by-name/modem for an
# "M8930B-AAAATAZM" build id -- a leftover from an MSM8930 device. nicki is
# MSM8227 and has no by-name/modem partition, so it set nothing.)

ver=$(strings /firmware/image/modem.b02 2>/dev/null | grep -m1 "BLAST Kernel ver" | sed -e 's/.*ver\.: *//' -e 's/[^0-9.].*//')
[ -n "$ver" ] && setprop gsm.version.baseband "$ver"
