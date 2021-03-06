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

print_noln "Burn ro image"

# Compress loopback
gzip -c ${TARGET_DIR}_loop > geonobot.gz
check_result $?

# Uncompress filesystem in target device
zcat geonobot.gz > ${ROOTFS_DEVICE}
check_result $?

print_ok
