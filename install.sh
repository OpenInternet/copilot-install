#!/usr/bin/env bash
#
# This file is part of CoPilot-Install, a installation package for CoPilot.
# Copyright © 2016 seamus tuohy, <code@seamustuohy.com>
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the included LICENSE file for details.

# Setup

#Bash should terminate in case a command or chain of command finishes with a non-zero exit status.
#Terminate the script in case an uninitialized variable is accessed.
#See: https://github.com/azet/community_bash_style_guide#style-conventions
#set -e
#set -u

# TODO remove DEBUGGING
# set -x

# Read Only variables
readonly PROG_DIR=$(readlink -m $(dirname $0))
source "${PROG_DIR}/conf/copilot-image.conf"

# Default platform is Beagle Bone Black
# If you would like another platform use ./bin/setup.sh
readonly platform='bbb'
readonly image_file="copilot-${platform}-${COPILOT_BUILD}.img"

main() {
    printf "\n"
    cat "${PROG_DIR}/conf/copilot_ascii.txt"
    printf "\n\n"
    printf "Installing CoPilot...\n"
    printf "What admin password would you like CoPilot to use?\n"
    printf 'Do not use the following characters "\$@ \n'
    read -sp "Password: " passwd
    write_conf "${PROG_DIR}/conf/copilot-image.conf" "PASSWD" "$passwd"
    printf "Are you using a custom CoPilot Repository?  \n"
    read -p "[y/n] " custom_copilot
    if [[ "${custom_copilot}" == 'y' ]]; then
        printf "What URL should we use to download CoPilot? \n"
        read -p "URL: " custom_copilot
        write_conf "${PROG_DIR}/copilot-fh/etc/opt/copilot" "readonly COPILOT_REPO" "$custom_copilot"
    fi
    printf "Are you using custom plugins?  \n"
    read -p "[y/n] " custom_plugins
    if [[ "${custom_plugins}" == 'y' ]]; then
        printf "What URL should we use for getting the plugins? \n"
        read -p "URL: " plugin_url
        write_conf "${PROG_DIR}/copilot-fh/etc/opt/copilot" "readonly PLUGINS_REPO" "$plugin_url"
        printf "What branch should we use in the plugin repo? (default 'master')\n"
        read -p "Branch: " branch_name
        write_conf "${PROG_DIR}/copilot-fh/etc/opt/copilot" "readonly PLUGINS_BRANCH" "$branch_name"
    fi
    printf "Starting Installation Process...\n\n"
    printf "Deleting any existing vagrant instances\n"
    vagrant destroy
    printf "Creating a new vagrant instance\n"
    vagrant up
    printf "Completed Installation Process...\n"
    install_copilot
}

install_copilot() {
    printf "Would you like to install CoPilot directly onto a SD card? \n"
    read -p "[y/n] " install_check
    if [[ "${install_check}" == 'y' ]]; then
        printf "What is the path to your SD cards device \n"
        read -p "Device Path: " dev_path
        printf "Starting Install... This will take a while. \n"
        sudo dd if="${PROG_DIR}/images/${image_file}" of="${dev_path}"
    fi
}

write_conf() {
    local file="$1"
    local old="$2"
    local new="$3"
    sed -i "s@\(${old}=\).*@\1\"${new}\"@" "$file"
}

cleanup() {
    write_conf "conf/copilot-image.conf" "PASSWD" "copilot"
    write_conf "${PROG_DIR}/copilot-fh/etc/opt/copilot" "readonly PLUGINS_REPO" 'https://github.com/OpenInternet/copilot-plugins'
    write_conf "${PROG_DIR}/copilot-fh/etc/opt/copilot" "readonly PLUGINS_BRANCH" "master"
    write_conf "${PROG_DIR}/copilot-fh/etc/opt/copilot" "readonly COPILOT_REPO" 'https://github.com/openinternet/copilot.git'
    exit 0
}

trap 'cleanup' EXIT


main
