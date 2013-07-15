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

mount_point=/tmp/${RANDOM} 

# Set partition label for kernel mount 
e2label ${ROOTFS_DEVICE} ${PARTITION_LABEL} 
check_result $? 

# Mount target 
mkdir -p ${mount_point} 
check_result $? 
mount ${ROOTFS_DEVICE}  ${mount_point} 
check_result $? 

# Copy rootfs to target 
cp -Rf --preserve=all ${TARGET_DIR}/* ${mount_point}/ 
check_result $? 

# Install bootloader 
(cd ${mount_point}/ && extlinux --install boot/extlinux/) 
check_result $? 

# Umount and delete mountpoint 
umount ${mount_point}/ 
check_result $? 
rmdir ${mount_point}/ 
check_result $? 
