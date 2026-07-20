#!/system/bin/sh
# nicki: the vendor netmgrd blob's compiled physical-link list includes an SDIO
# transport (rmnet_sdio0..7) that this SMD/BAM-only target never creates. netmgrd
# SIGABRTs on the first missing iface -> crash-loops -> dsi_init never completes
# the netmgr-ready handshake -> mobile data never comes up. Provide harmless dummy
# stubs so netmgrd initializes them and proceeds to the real BAM links (rmnet0..7).
for i in 0 1 2 3 4 5 6 7; do
    /system/bin/ip link add rmnet_sdio$i type dummy 2>/dev/null
    /system/bin/ip link set rmnet_sdio$i up 2>/dev/null
done
