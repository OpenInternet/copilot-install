#!/bin/bash
#
# Modified from lepidopter https://github.com/TheTorProject/lepidopter

set -e
# set -x

source /root/copilot-install/conf/copilot-image.conf
USER=`whoami`

function usage() {
    echo "usage: setup.sh -p <platform> [options]"
    echo "with no options the script installs the dependencies and builds" \
            "copilot image"
    echo "-c compress copilot image with xz or zip compression (eg. -c xz)"
    echo "-t create a torrent file of the image and the digests"
    echo "-p The platform to build copilot for."
    echo "   Available platforms = [bbb, rpi2]"
    echo "     - bbb = Beagle Bone Black"
    echo "     - rpi2 = Raspberry Pi Ver. 2"
}

get_arch() {
    if [[ ${platform} == "bbb" ]];
    then
        ARCH="armhf"
    elif [[ ${platform} == "rpi2" ]];
    then
        ARCH="armel"
        echo "Platform not supported"
        usage
        exit 1
    else
        echo "Platform not supported"
        usage
        exit 1
    fi
}

main() {
    install_dependencies
    get_cliapp
    get_vmdebootstrap
    # Add loop kernel module required to mount loop devices
    modprobe loop

    create_image
    echo "created image"

    # Compression
    if [ "${#compression_method[@]}" -ne 0 ] ; then
        for cmp in "${compression_method[@]}"; do
            ${cmp}_archive
        done
    fi

    # make torrent file
    if [ "$build_torrent" = true ] ; then
        mk_torrent
    fi

    echo "removing device mappings"
    # Remove all device mappings
    dmsetup remove_all
    echo "device mappings removed"
}


# Create a torrent of the xz image file
mk_torrent() {
    apt-get install -y mktorrent bittornado
    cd images && \
        mktorrent -a 'udp://tracker.torrent.eu.org:451' \
                  -a 'udp://tracker.coppersurfer.tk:6969' \
                  -n ${image_file:-4} SHA* ${image_file}.xz
    btshowmetainfo ${image_file:-4}.torrent
}

# Compress copilot img
xz_archive() {
    apt-get install -y pxz
    pxz --keep --verbose -D 12 images/${image_file}
}

zip_archive() {
    apt-get install -y zip
    zip --verbose -9 images/${image_file}.zip images/${image_file}
}


install_dependencies() {
    apt-get update -q
    apt-get install -y python-setuptools debootstrap qemu-utils qemu-user-static extlinux parted mbr kpartx python-distro-info dosfstools rsync
    apt-get install -y git
}

get_cliapp() {
    # get cliapp
    cd $HOME
    git clone git://git.liw.fi/cliapp
    cd cliapp
    git checkout tags/cliapp-1.20150829
    #cp vmdebootstrap /usr/sbin/vmdebootstrap
    python setup.py install
}

get_vmdebootstrap() {
# Get vmdebootstrap
    cd $HOME
    git clone git://git.liw.fi/vmdebootstrap
    cd vmdebootstrap
    git checkout tags/vmdebootstrap-1.5
    #cp vmdebootstrap /usr/sbin/vmdebootstrap
    python setup.py install

    # Put the customize lib where customize scripts can grab it
    mkdir -p /usr/share/vmdebootstrap/common/
    cp ./common/customise.lib /usr/share/vmdebootstrap/common/customise.lib

    cd $HOME
    mkdir copilot_vmdebootstrap
    cp -fr copilot-install copilot_vmdebootstrap/copilot-install
    cd copilot_vmdebootstrap
    chown root:root copilot-install
}

create_image() {
    cd copilot-install/

    vmdebootstrap \
        --owner ${USER} --verbose \
        --root-password="${PASSWD}" \
        --mirror http://httpredir.debian.org/debian \
        --log beaglebone-black.log --log-level debug \
        --hostname "${HOSTNAME_IMG}" \
        --arch "${ARCH}" \
        --foreign /usr/bin/qemu-arm-static \
        --enable-dhcp \
        --configure-apt \
        --no-extlinux \
        --size=4G \
        --package u-boot \
        --package dosfstools \
        --package libffi-dev \
        --distribution jessie \
        --serial-console-command "'/sbin/getty -L ttyO0 115200 vt100'" \
        --customize "/root/copilot-install/scripts/customize-${platform}.sh" \
        --bootsize 100mib --boottype vfat \
        --image ${image_file}

    echo "Completed vmdebootsrap"

    #./copilot-vmdebootstrap_build.sh --image copilot.img
    mkdir -p /root/copilot-install/images/
    cp "${image_file}" /root/copilot-install/images/"${image_file}"
}

while getopts "p:c:ht" opt; do
    case $opt in
      p)
          platform=("$OPTARG")
          get_arch
        ;;
      c)
        compression_method+=("$OPTARG")
        ;;
      t)
        build_torrent=true
        ;;
      h)
        usage
        exit 0
        ;;
     \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
      :)
        echo "Option -$OPTARG requires an argument." >&2
        usage
        exit 1
    esac
done

readonly image_file="copilot-${platform}-${COPILOT_BUILD}.img"

main
