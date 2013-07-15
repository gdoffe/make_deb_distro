#!/bin/bash

#    Copyright (C) 2011 Gilles DOFFE
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
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
. ${INCLUDE_DIR}/functions.sh

##### BOOTLOADER #####
# Create extlinux directory
mkdir -p ${TARGET_DIR}/boot/extlinux
check_result $?

# Boot entries
cp -f ${PROFILE_DIR}/tools/extlinux/* ${TARGET_DIR}/boot/extlinux/
check_result $?

for kernel in ${TARGET_DIR}/boot/vmlinuz*;
do
    kernel=$(basename ${kernel})
    initrd=$(echo ${kernel} | sed s/vmlinuz/initrd.img/)
    echo "LABEL ${kernel}" >> ${TARGET_DIR}/boot/extlinux/extlinux.conf
    echo "  menu label ^Start with kernel ${kernel}" >> ${TARGET_DIR}/boot/extlinux/extlinux.conf
    echo "  kernel /boot/${kernel}" >> ${TARGET_DIR}/boot/extlinux/extlinux.conf
    if [ -f ${TARGET_DIR}/boot/${initrd} ]; then
            echo "  append init=/sbin/init --verbose root=/dev/disk/by-label/${PARTITION_LABEL} initrd=/boot/${initrd} console=ttyS0,115200n8 console=tty0" >> ${TARGET_DIR}/boot/extlinux/extlinux.conf
    else
            echo "  append root=/dev/disk/by-label/${PARTITION_LABEL} quiet splash console=ttyS0,115200n8 console=tty0" >> ${TARGET_DIR}/boot/extlinux/extlinux.conf
    fi
done

##### PREPARE TARGET #####
# Check that target device is on USB bus
readlink -f /sys/block/$(basename ${TARGET_DEVICE}) | grep -oq -e usb -e mmc_host
check_result $?

# Umount target if already mounted
umount ${TARGET_DEVICE}*

# Erase partition table
dd if=/dev/zero of=${TARGET_DEVICE} bs=1M count=1

# Prepare target device
(echo "0,64,0b,
,,L,*,
;
;" | sfdisk -fuM --no-reread ${TARGET_DEVICE})
check_result $?

partprobe ${TARGET_DEVICE}
check_result $?

# Install MBR
install-mbr ${TARGET_DEVICE}
check_result $?

# Format target
mkfs.vfat $VFAT_DEVICE
check_result $?
mkfs.ext4 -F -L ${RANDOM} -m 0 ${ROOTFS_DEVICE}
check_result $?
