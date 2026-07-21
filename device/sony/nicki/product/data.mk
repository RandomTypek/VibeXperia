# Mobile-data bring-up (netmgrd link sizing).
#
# The vendor netmgrd blob's compiled physical-link table is [0..7]=rmnet0..7 (the
# real BAM data links on this SMD/BAM target, CONFIG_MSM_RMNET_BAM=y) followed by
# [8..]=rmnet_sdio0..7, an SDIO transport this target never creates. Unbounded,
# netmgrd walks the whole table, hits SIOCGIFFLAGS rmnet_sdio0 = ENODEV at iface[8]
# ("netmgr_kif_reset_link: cannot init iface[8]") and SIGABRTs -> crash-loops ->
# dsi_init never completes the netmgr-ready handshake -> mobile data never comes up.
#
# netmgrd reads persist.data_netmgrd_nint to size how many physical links it manages.
# Pin it to 8 so netmgrd manages exactly the 8 BAM links (rmnet0..7) and never
# touches the phantom rmnet_sdio links. Cleaner than stubbing dummy rmnet_sdio
# netdevs (the earlier approach) -- no fake interfaces to pollute dsi's link map.
PRODUCT_PROPERTY_OVERRIDES += \
    persist.data_netmgrd_nint=8
