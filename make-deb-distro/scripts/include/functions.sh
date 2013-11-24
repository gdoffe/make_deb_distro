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

