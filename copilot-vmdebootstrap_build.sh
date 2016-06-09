#!/bin/bash
set -exa

source copilot-fh/etc/default/copilot
source conf/copilot-image.conf

vmdebootstrap \
    --arch ${ARCH} \
    --log `pwd`/images/copilot-build-${COPILOT_BUILD}-${ARCH}.log \
    --distribution ${DEB_RELEASE} \
    --apt-mirror ${APT_MIRROR} \
    --mirror ${MIRROR} \
    --image `pwd`/images/copilot-${COPILOT_BUILD}-${ARCH}.img \
    --size 3950M \
    --bootsize 64M \
    --boottype vfat \
    --log-level debug \
    --verbose \
    --no-extlinux \
    --roottype ext4 \
    --lock-root-password \
    --no-kernel \
    --user ${USER}/${PASSWD} \
    --sudo \
    --hostname ${HOSTNAME_IMG} \
    --enable-dhcp \
    --package netbase \  # Base Packages for Arm Systems
    --package ca-certificates \
    --package git-core \
    --package ntp \
    --package binutils \
    --package wget \
    --package kmod \
    --package usbmount \ # Copilot Install Starts Here
    --package python-dev \ #Install Flask dependencies
    --package curl \
    --package python2.7-dev
    --package python-pysqlite2 \
    --package build-essential \ # Bcrypt Dependencies
    --package libffi-dev \
    --package nginx \ # install wsgi
    --package supervisor \
    --package python-pip \
    --package avahi \ # avahi-daemon
    --configure-apt \
    --customize `pwd`/customize \
    "$@"
