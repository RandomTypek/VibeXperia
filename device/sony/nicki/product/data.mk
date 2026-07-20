# Mobile-data bring-up: the vendor netmgrd blob's compiled physical-link list
# includes an SDIO transport (rmnet_sdio0..7) that this SMD/BAM-only target
# (CONFIG_MSM_RMNET_BAM=y, no rmnet_sdio) never creates. netmgrd SIGABRTs on the
# first missing iface -> crash-loops -> dsi_init never completes the netmgr-ready
# handshake -> mobile data never comes up. A tiny oneshot creates harmless dummy
# rmnet_sdio stubs at 'on post-fs' (before netmgrd, which is class main) so netmgrd
# stays up and the dsi<->netmgr handshake completes. See init.nicki.rmnet_stub.sh.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.nicki.rmnet_stub.sh:system/etc/init.nicki.rmnet_stub.sh \
    $(LOCAL_PATH)/rootdir/etc/init/nicki_rmnet_stub.rc:system/etc/init/nicki_rmnet_stub.rc
