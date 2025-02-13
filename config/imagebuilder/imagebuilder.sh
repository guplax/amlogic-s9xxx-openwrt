#!/bin/bash
#================================================================================================
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the make OpenWrt for Amlogic s9xxx tv box
# https://github.com/ophub/amlogic-s9xxx-openwrt
#
# Description: Build OpenWrt with Image Builder
# Copyright (C) 2021~ https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021~ https://github.com/ophub/amlogic-s9xxx-openwrt
# Copyright (C) 2021~ https://downloads.openwrt.org/releases
# Copyright (C) 2023~ https://downloads.immortalwrt.org/releases
#
# Download from: https://downloads.openwrt.org/releases
#                https://downloads.immortalwrt.org/releases
#
# Documentation: https://openwrt.org/docs/guide-user/additional-software/imagebuilder
# Instructions:  Download OpenWrt firmware from the official OpenWrt,
#                Use Image Builder to add packages, lib, theme, app and i18n, etc.
#
# Command: ./config/imagebuilder/imagebuilder.sh <source:branch>
#          ./config/imagebuilder/imagebuilder.sh openwrt:21.02.3
#
#======================================== Functions list ========================================
#
# error_msg               : Output error message
# download_imagebuilder   : Downloading OpenWrt ImageBuilder
# adjust_settings         : Adjust related file settings
# custom_packages         : Add custom packages
# custom_config           : Add custom config
# custom_files            : Add custom files
# rebuild_firmware        : rebuild_firmware
#
#================================ Set make environment variables ================================
#
# Set default parameters
make_path="${PWD}"
openwrt_dir="imagebuilder"
imagebuilder_path="${make_path}/${openwrt_dir}"
custom_files_path="${make_path}/config/imagebuilder/files"
custom_config_file="${make_path}/config/imagebuilder/config"

# Set default parameters
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#================================================================================================

# Encountered a serious error, abort the script execution
error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# Downloading OpenWrt ImageBuilder
download_imagebuilder() {
    cd ${make_path}
    echo -e "${STEPS} Start downloading OpenWrt files..."

    # Determine the target system (Imagebuilder files naming has changed since 23.05.0)
    if [[ "${op_branch:0:2}" -ge "23" && "${op_branch:3:2}" -ge "05" ]]; then
        target_system="armsr/armv8"
        target_name="armsr-armv8"
        target_profile=""
    else
        target_system="armvirt/64"
        target_name="armvirt-64"
        target_profile="Default"
    fi

    if [[ "${op_branch:0:2}" -ge "24" && "${op_branch:3:2}" -ge "10" ]]; then
        archive_format="zst"
    else
        archive_format="xz"
    fi

    # Downloading imagebuilder files
    download_file="https://downloads.${op_sourse}.org/releases/${op_branch}/targets/${target_system}/${op_sourse}-imagebuilder-${op_branch}-${target_name}.Linux-x86_64.tar.${archive_format}"
    curl -fsSOL ${download_file}
    [[ "${?}" -eq "0" ]] || error_msg "Download failed: [ ${download_file} ]"

    # Unzip and change the directory name
    if [[ "${op_branch:0:2}" -ge "24" && "${op_branch:3:2}" -ge "10" ]]; then
        tar -x --zstd -f *-imagebuilder-* && sync && rm -f *-imagebuilder-*.tar.zst
    else
        tar -xJf *-imagebuilder-* && sync && rm -f *-imagebuilder-*.tar.xz
    fi
    mv -f *-imagebuilder-* ${openwrt_dir}

    sync && sleep 3
    echo -e "${INFO} [ ${make_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Adjust related files in the ImageBuilder directory
adjust_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adjusting .config file settings..."

    # For .config file
    if [[ -s ".config" ]]; then
        # Root filesystem archives
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        # Root filesystem images
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|# CONFIG_TARGET_ROOTFS_EXT4FS is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
        # default-settings-chn packages
        sed -i "s|CONFIG_DEFAULT_default-settings-chn=.*|# CONFIG_DEFAULT_default-settings-chn is not set|g" .config
        sed -i "s|CONFIG_MODULE_DEFAULT_default-settings-chn=.*|# CONFIG_MODULE_DEFAULT_default-settings-chn is not set|g" .config
        sed -i "s|CONFIG_PACKAGE_default-settings-chn=.*|# CONFIG_PACKAGE_default-settings-chn is not set|g" .config
    else
        echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
        error_msg "There is no .config file in the [ ${download_file} ]"
    fi

    # For other files
    # ......

    sync && sleep 3
    echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages
# If there is a custom package or ipk you would prefer to use create a [ packages ] directory,
# If one does not exist and place your custom ipk within this directory.
custom_packages() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom packages..."

    # Create a [ packages ] directory
    [[ -d "packages" ]] || mkdir packages
    cd packages

    # Download luci-app-amlogic
    amlogic_api="https://api.github.com/repos/ophub/luci-app-amlogic/releases"
    #
    amlogic_file="luci-app-amlogic"
    amlogic_file_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_name}.*.ipk" | head -n 1)"
    curl -fsSOJL ${amlogic_file_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_file} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_file} ] is downloaded successfully."
    #
    amlogic_i18n="luci-i18n-amlogic"
    amlogic_i18n_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_i18n}.*.ipk" | head -n 1)"
    curl -fsSOJL ${amlogic_i18n_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_i18n} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_i18n} ] is downloaded successfully."

    # Download other luci-app-xxx
    # ......

    # Copy ipk
    cp -vf "${make_path}/config/ipk"/*.ipk .

    sync && sleep 3
    echo -e "${INFO} [ packages ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages, lib, theme, app and i18n, etc.
custom_config() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom config..."

    config_list=""
    if [[ -s "${custom_config_file}" ]]; then
        config_list="$(cat ${custom_config_file} 2>/dev/null | grep -E "^CONFIG_PACKAGE_.*=y" | sed -e 's/CONFIG_PACKAGE_//g' -e 's/=y//g' -e 's/[ ][ ]*//g' | tr '\n' ' ')"
        echo -e "${INFO} Custom config list: \n$(echo "${config_list}" | tr ' ' '\n')"
    else
        echo -e "${INFO} No custom config was added."
    fi
}

# Add custom files
# The FILES variable allows custom configuration files to be included in images built with Image Builder.
# The [ files ] directory should be placed in the Image Builder root directory where you issue the make command.
custom_files() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom files..."

    if [[ -d "${custom_files_path}" ]]; then
        # Copy custom files
        [[ -d "files" ]] || mkdir -p files
        cp -rf ${custom_files_path}/* files

        sync && sleep 3
        echo -e "${INFO} [ files ] directory status: $(ls files -al 2>/dev/null)"
    else
        echo -e "${INFO} No customized files were added."
    fi
}

# Rebuild OpenWrt firmware
rebuild_firmware() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start building OpenWrt with Image Builder..."

    # Selecting default packages, lib, theme, app and i18n, etc.
    my_packages="\
        attendedsysupgrade-common autocore automount base-files blkid block-mount busybox ca-bundle cgi-io default-settings -default-settings-chn dnsmasq-full dropbear e2fsprogs firewall4 fstools fwtool getrandom grub2-efi-arm jshn jsonfilter kernel kmod-acpi-mdio kmod-amazon-ena kmod-asn1-decoder kmod-atlantic kmod-bcmgenet kmod-crypto-acompress kmod-crypto-aead kmod-crypto-arc4 kmod-crypto-crc32 kmod-crypto-crc32c kmod-crypto-ctr kmod-crypto-ecb kmod-crypto-gcm kmod-crypto-geniv kmod-crypto-gf128 kmod-crypto-ghash kmod-crypto-hash kmod-crypto-hmac kmod-crypto-manager kmod-crypto-null kmod-crypto-rng kmod-crypto-seqiv kmod-crypto-sha1 kmod-crypto-sha3 kmod-crypto-sha512 kmod-crypto-user kmod-dwmac-imx kmod-dwmac-rockchip kmod-dwmac-sun8i kmod-e1000 kmod-e1000e kmod-fixed-phy kmod-fs-exfat kmod-fs-ext4 kmod-fsl-dpaa1-net kmod-fsl-dpaa2-net kmod-fsl-enetc-net kmod-fsl-fec kmod-fsl-mc-dpio kmod-fsl-pcs-lynx kmod-fsl-xgmac-mdio kmod-fs-ntfs3 kmod-fs-vfat kmod-gpio-pca953x kmod-hwmon-core kmod-i2c-core kmod-i2c-mux kmod-i2c-mux-pca954x kmod-lib-crc16 kmod-lib-crc32c kmod-lib-crc-ccitt kmod-lib-lzo kmod-libphy kmod-lib-textsearch kmod-macsec kmod-macvlan kmod-marvell-mdio kmod-mdio-bcm-unimac kmod-mdio-bus-mux kmod-mdio-devres kmod-mdio-gpio kmod-mdio-thunder kmod-mii kmod-mppe kmod-mvneta kmod-mvpp2 kmod-net-selftests kmod-nf-conntrack kmod-nf-conntrack6 kmod-nf-conntrack-netlink kmod-nf-flow kmod-nf-log kmod-nf-log6 kmod-nf-nat kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nfnetlink kmod-nf-reject kmod-nf-reject6 kmod-nft-core kmod-nft-fib kmod-nft-fullcone kmod-nft-nat kmod-nft-offload kmod-nls-base kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 kmod-octeontx2-net kmod-of-mdio kmod-pcs-xpcs kmod-phy-aquantia kmod-phy-broadcom kmod-phylib-broadcom kmod-phylink kmod-phy-marvell kmod-phy-marvell-10g kmod-phy-realtek kmod-phy-smsc kmod-ppp kmod-pppoe kmod-pppox kmod-pps kmod-ptp kmod-regmap-core kmod-regmap-i2c kmod-renesas-net-avb kmod-rtc-rx8025 kmod-scsi-core kmod-sfp kmod-slhc kmod-stmmac-core kmod-thunderx-net kmod-usb-core kmod-usb-storage kmod-usb-storage-extras kmod-usb-storage-uas kmod-vmxnet3 kmod-wdt-sp805 libc libgcc libiwinfo-data liblucihttp-lua liblucihttp-ucode libopenssl libpthread librt libubus-lua libudebug logd lua luci luci-app-attendedsysupgrade luci-app-firewall luci-app-package-manager luci-base luci-compat luci-i18n-base-zh-cn luci-lib-base luci-lib-ip luci-lib-ipkg luci-lib-jsonc luci-lib-nixio luci-light luci-lua-runtime luci-mod-admin-full luci-mod-network luci-mod-status luci-mod-system luci-proto-ipv6 luci-proto-ppp luci-theme-bootstrap mkf2fs mtd netifd nftables-json ntfs3-mount odhcp6c odhcpd-ipv6only openwrt-keyring opkg partx-utils ppp ppp-mod-pppoe procd procd-seccomp procd-ujail rpcd rpcd-mod-file rpcd-mod-iwinfo rpcd-mod-luci rpcd-mod-rpcsys rpcd-mod-rrdns rpcd-mod-ucode shellsync ubox ubus ubusd uci uclient-fetch ucode ucode-mod-fs ucode-mod-html ucode-mod-lua ucode-mod-math ucode-mod-ubus ucode-mod-uci uhttpd uhttpd-mod-ubus urandom-seed urngd usign \
        \
        jansson libblkid libblobmsg-json libcomerr libe2p libext2fs libf2fs libgmp libiwinfo libjson-c libjson-script liblua liblucihttp libmnl libnetfilter-conntrack libnettle libnfnetlink libnftnl libnl-tiny libsmartcols libss libubox libubus libuci libuclient libucode libustream-openssl libuuid luci-i18n-attendedsysupgrade-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn \
        \
        libzstd btrfs-progs fdisk losetup lsblk parted perl uuidgen \
        \
        perl-http-date perlbase-file perlbase-getopt perlbase-time perlbase-unicode perlbase-utf8 \
        \
        attr chattr lsattr dosfstools f2fs-tools f2fsck xfs-fsck xfs-mkfs \
        bsdtar pigz bash gawk getopt tar acpid luci-theme-material \
        \
        kmod-brcmfmac kmod-brcmutil kmod-cfg80211 kmod-mac80211 \
        \
        wpa-cli wpad-openssl iw openssh-sftp-server adguardhome \
        \
        modemmanager luci-proto-modemmanager \
        uqmi luci-proto-qmi qmi-utils \
        kmod-usb-serial kmod-usb-serial-wwan kmod-usb-serial-option kmod-usb-serial-qualcomm kmod-usb-serial-sierrawireless \
        kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan \
	\
	luci-app-amlogic luci-i18n-amlogic-zh-cn \
        "

    # Rebuild firmware
    make image PROFILE="" PACKAGES="${my_packages}" FILES="files"

    sync && sleep 3
    echo -e "${INFO} [ ${openwrt_dir}/bin/targets/*/* ] directory status: $(ls bin/targets/*/* -al 2>/dev/null)"
    echo -e "${SUCCESS} The rebuild is successful, the current path: [ ${PWD} ]"
}

# Show welcome message
echo -e "${STEPS} Welcome to Rebuild OpenWrt Using the Image Builder."
[[ -x "${0}" ]] || error_msg "Please give the script permission to run: [ chmod +x ${0} ]"
[[ -z "${1}" ]] && error_msg "Please specify the OpenWrt Branch, such as [ ${0} openwrt:22.03.3 ]"
[[ "${1}" =~ ^[a-z]{3,}:[0-9]+ ]] || error_msg "Incoming parameter format <source:branch>: openwrt:22.03.3"
op_sourse="${1%:*}"
op_branch="${1#*:}"
echo -e "${INFO} Rebuild path: [ ${PWD} ]"
echo -e "${INFO} Rebuild Source: [ ${op_sourse} ], Branch: [ ${op_branch} ]"
echo -e "${INFO} Server space usage before starting to compile: \n$(df -hT ${make_path}) \n"
#
# Perform related operations
download_imagebuilder
adjust_settings
custom_packages
custom_config
custom_files
rebuild_firmware
#
# Show server end information
echo -e "Server space usage after compilation: \n$(df -hT ${make_path}) \n"
# All process completed
wait
