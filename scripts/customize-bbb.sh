#!/bin/bash
#
# Customisation hook scripts are shell scripts which will be passed
# a single parameter - the directory which represents the root
# directory of the final image. These scripts can use standard shell
# support to include other common functions or call out to utilities
# known to be installed in the outer VM running vmdebootstrap.
# http://git.liw.fi/cgi-bin/cgit/cgit.cgi/vmdebootstrap/tree/doc/live.rst#n79
set -e
set -x

source /root/copilot-install/copilot-fh/etc/opt/copilot
source /root/copilot-install/conf/copilot-image.conf

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

readonly rootdir="$1"
#readonly rootdir="$2"

# Base Vars
readonly ROOT_WEB_DIR="${rootdir}${WEB_DIR}"
readonly ROOT_COPILOT_DIR="${ROOT_WEB_DIR}/copilot"
readonly ROOT_SETUP_DIR="${rootdir}${ROOT_SETUP_DIR}"
# Plugin Configuration Variables
readonly ROOT_COPILOT_PLUGINS_DIRECTORY="${rootdir}${COPILOT_PLUGINS_DIRECTORY}"
# Configuration Directory Variables
readonly ROOT_COPILOT_PROFILE_CONFIG_DIRECTORY="${rootdir}${COPILOT_PROFILE_CONFIG_DIRECTORY}"

# common needs rootdir to already be defined.
source /usr/share/vmdebootstrap/common/customise.lib

# Don't start daemons
# https://media.readthedocs.org/pdf/vmdebootstrap/latest/vmdebootstrap.pdf#page=18
disable_daemons

# === Setup BeagleBone ===

# copy u-boot to the boot partition
cp ${rootdir}/usr/lib/u-boot/am335x_boneblack/MLO ${rootdir}/boot/MLO
cp ${rootdir}/usr/lib/u-boot/am335x_boneblack/u-boot.img ${rootdir}/boot/u-boot.img

# Setup uEnv.txt
kernelVersion=$(basename `dirname $rootdir/usr/lib/*/am335x-boneblack.dtb`)
version=$(echo $kernelVersion | sed 's/linux-image-\(.*\)/\1/')
initRd=initrd.img-$version
vmlinuz=vmlinuz-$version

# uEnv.txt for Beaglebone
# based on https://github.com/beagleboard/image-builder/blob/master/target/boot/beagleboard.org.txt
cat >> $rootdir/boot/uEnv.txt <<EOF
mmcroot=/dev/mmcblk0p2 ro
mmcrootfstype=ext4 rootwait fixrtc

console=ttyO0,115200n8

kernel_file=$vmlinuz
initrd_file=$initRd

loadaddr=0x80200000
initrd_addr=0x81000000
fdtaddr=0x80F80000

initrd_high=0xffffffff
fdt_high=0xffffffff

loadkernel=load mmc \${mmcdev}:\${mmcpart} \${loadaddr} \${kernel_file}
loadinitrd=load mmc \${mmcdev}:\${mmcpart} \${initrd_addr} \${initrd_file}; setenv initrd_size \${filesize}
loadfdt=load mmc \${mmcdev}:\${mmcpart} \${fdtaddr} /dtbs/\${fdtfile}

loadfiles=run loadkernel; run loadinitrd; run loadfdt
mmcargs=setenv bootargs console=tty0 console=\${console} root=\${mmcroot} rootfstype=\${mmcrootfstype}

uenvcmd=run loadfiles; run mmcargs; bootz \${loadaddr} \${initrd_addr}:\${initrd_size} \${fdtaddr}
EOF

mkdir -p $rootdir/boot/dtbs
cp $rootdir/usr/lib/linux-image-*-armmp/* $rootdir/boot/dtbs

# === COPILOT INSTALL ===

# Copy required config files to copilot
# Rsync Directory/file hieratchy to image
rsync -avp copilot-fh/ ${rootdir}/

#Create website Directory
mkdir -p ${ROOT_WEB_DIR}
cd ${ROOT_WEB_DIR}
#Create website Directory
git clone ${COPILOT_REPO}

# ========================== TODO ============================
# TODO REMOVE after debugging
cd copilot
git checkout vmdebootstrap
# ============================================================

#create setup directory
mkdir -p ${ROOT_SETUP_DIR}

# Setup Flask Env
mkdir -p "${ROOT_COPILOT_DIR}/instance"
if [[ $TESTING = true ]]; then
    cp $ROOT_COPILOT_DIR/templates/testing_config.py $ROOT_COPILOT_DIR/instance/config.py
    cp $ROOT_COPILOT_DIR/templates/testing_config.py $ROOT_COPILOT_DIR/instance/bp_config.py
else
    cp $ROOT_COPILOT_DIR/templates/base_config.py $ROOT_COPILOT_DIR/instance/config.py
    cp $ROOT_COPILOT_DIR/templates/base_config.py $ROOT_COPILOT_DIR/instance/bp_config.py
fi

# Get rid of the application root in the bp_config
sed -i '/^APPLICATION_ROOT.*/d' $ROOT_COPILOT_DIR/instance/bp_config.py

# setup copilot db Dir
mkdir -p "${ROOT_COPILOT_PROFILE_CONFIG_DIRECTORY}"

# Plugins
mkdir "${ROOT_COPILOT_PLUGINS_DIRECTORY}"
cd "${ROOT_COPILOT_PLUGINS_DIRECTORY}"
git clone "${PLUGINS_REPO}" "plugins"
cd plugins
git checkout "${PLUGINS_BRANCH}"

# Run copilot installation in chroot
chroot ${rootdir} /usr/local/bin/firstboot_install.sh

remove_daemon_block #|| true

echo "Customize Complete"
