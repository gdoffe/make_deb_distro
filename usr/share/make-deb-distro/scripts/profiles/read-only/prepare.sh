#!/bin/bash

# Copyright (C) 2013 Gilles DOFFE <gdoffe@gmail.com>

# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public
# License along with this package; if not,
# see <http://www.gnu.org/licenses/>.
# 
# On Debian systems, the full text of the GNU General Public
# License version 3 can be found in the file
# /usr/share/common-licenses/GPL-3.

###########################################################################
#
# This script will be executed in the same path than make_distro.sh
#
#
# Script variables :
#
# TARGET_DIR : Rootfs directory
# TARGET_DEVICE : Device where rootfs and bootloader will be burned
# 
###########################################################################

# Import generic functions.
. ${MDD_INCLUDE_DIR}/functions.sh

# Loopback
touch ${TARGET_DIR}_loop
check_result $?

# Create loopback mountpoint
mkdir -p ${TARGET_DIR}_image/
check_result $?

# Create filesystem
dd if=/dev/zero of=${TARGET_DIR}_loop bs=1 count=1 seek=1G
check_result $?
mkfs.ext2 -F -L rescue -m 0 ${TARGET_DIR}_loop
check_result $?

# Mount loopback
mount -o loop ${TARGET_DIR}_loop ${TARGET_DIR}_image
check_result $?

# Create casper needed directories
mkdir -p ${TARGET_DIR}_image/{casper,boot,boot/extlinux,install}
check_result $?

# Copy kernel and initrd for casper
cp ${TARGET_DIR}/boot/vmlinuz* ${TARGET_DIR}_image/casper/
check_result $?
cp ${TARGET_DIR}/boot/initrd.img* ${TARGET_DIR}_image/casper/
check_result $?

# Boot entries
cp ${PROFILE_DIR}/tools/extlinux/* ${TARGET_DIR}_image/boot/extlinux/
check_result $?

for kernel in ${TARGET_DIR}_image/casper/vmlinuz*;
do
    kernel=$(basename ${kernel})
    initrd=$(echo ${kernel} | sed s/vmlinuz/initrd.img/)
    echo "LABEL ${kernel}" >> ${TARGET_DIR}_image/boot/extlinux/extlinux.conf
    echo "  menu label ^Start with kernel ${kernel}" >> ${TARGET_DIR}_image/boot/extlinux/extlinux.conf
    echo "  kernel /casper/${kernel}" >> ${TARGET_DIR}_image/boot/extlinux/extlinux.conf
    if [ -f ${TARGET_DIR}_image/casper/${initrd} ]; then
            echo "  append boot=casper initrd=/casper/${initrd} toram quiet splash --" >> ${TARGET_DIR}_image/boot/extlinux/extlinux.conf
    else
            echo "  append boot=casper toram quiet splash --" >> ${TARGET_DIR}_image/boot/extlinux/extlinux.conf
    fi
done

# Create manifest files
${CHROOT} dpkg-query -W --showformat='${Package} ${Version}\n' > ${TARGET_DIR}_image/casper/filesystem.manifest
check_result $?

touch ${TARGET_DIR}_image/ubuntu

mkdir -p ${TARGET_DIR}_image/.disk
echo "${DISTRO_VERSION}" > ${TARGET_DIR}_image/.disk/info
echo "http//geonobot-wiki.toile-libre.org" > ${TARGET_DIR}_image/.disk/release_notes_url

# Compress rootfs
mksquashfs ${TARGET_DIR} ${TARGET_DIR}_image/casper/filesystem.squashfs -noappend
check_result $?

# Copy README.diskdefines
cp ${PROFILE_DIR}/tools/README.diskdefines ${TARGET_DIR}_image/
check_result $?

# Calculate MD5 Sum
(cd ${TARGET_DIR}_image && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)
check_result $?

# Install bootloader
(cd ${TARGET_DIR}_image && extlinux --install boot/extlinux/)
check_result $?

# Umount loopback
umount ${TARGET_DIR}_image
check_result $?

# delete image mount point
rmdir ${TARGET_DIR}_image
check_result $?

# Check that target device is on USB bus
readlink -f /sys/block/$(basename ${TARGET_DEVICE}) | grep -oq -e usb -e mmc_host
check_result $?
