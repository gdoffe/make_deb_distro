#!/bin/bash

#    Copyright (C) 2013 Gilles DOFFE
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

# Generic tool functions to import in external scripts

check_result()
{
    if [ "${1}" != "0" ]; then
        print_ko
    exit 1
    fi
}

print_noln()
{
    if [ "${VERBOSE}" = "0" ]; then
        print_noln_ "${*}" &
        wait $!
        string="${*}"
        str_size=${#string}
    fi
}

print_noln_()
{
    if [ "${VERBOSE}" = "0" ]; then
        exec 1>&6 6>&-
    fi
    printf "${*}"
}

print_out()
{
    print_out_ "${*}" &
    wait $!
}

print_out_()
{
    if [ "${VERBOSE}" = "0" ]; then
        exec 1>&6 6>&-
    fi
    echo  "${*}"
}

print_ok()
{
    if [ "${VERBOSE}" = "0" ]; then
        shift
        print_ok_ &
        wait $!
    fi
}

print_ko()
{
    if [ "${VERBOSE}" = "0" ]; then
        shift
        print_ko_ &
        wait $!
    fi
}

print_ok_()
{
    if [ "${VERBOSE}" = "0" ]; then
        exec 1>&6 6>&-
    fi
    column=$((COLUMNS - str_size))
    printf "%${column}s\n" "[${GREEN}OK${DEFAULT_COLOR}]"
}

print_ko_()
{
    if [ "${VERBOSE}" = "0" ]; then
        exec 1>&6 6>&-
    fi
    column=$((COLUMNS - str_size))
    printf "%${column}s\n" "[${RED}KO${DEFAULT_COLOR}]"
}

prepare_target()
{
    print_noln "Prepare target"

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

    print_ok
}
