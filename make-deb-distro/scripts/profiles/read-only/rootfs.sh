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
. include/functions.sh

# Disable apt-cdrom in initramfs since it is not an installation distrib
if [ "1" = "${READ_ONLY}" ]; then
    if [[ -x ${TARGET_DIR}/usr/share/initramfs-tools/scripts/casper-bottom/41apt_cdrom ]]; then 
        chmod a-x ${TARGET_DIR}/usr/share/initramfs-tools/scripts/casper-bottom/41apt_cdrom
        check_result $?
    fi
fi

