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

# Include generic functions
export INCLUDE_DIR=/usr/share/make-deb-distro/scripts/include
. ${INCLUDE_DIR}/functions.sh

# Init all script variables
init()
{
    # Script is verbose if different of 0.
    VERBOSE=0

    # Only do debootstrap and dpkg work if different of 0.
    ONLY_ROOTFS=0

    # Target roots filesystem
    export TARGET_DIR="${PWD}/../targetdir"

    # Target device
    export TARGET_DEVICE=
    
    # Target architecture
    ARCH=$(dpkg --print-architecture)
    
    # Debian-like distribution
    DISTRO_NAME=$(lsb_release -i | cut -d ':' -f2 | tr -d '\t' | tr 'A-Z' 'a-z')
    
    # Debian-like version
    DISTRO_VERSION=$(lsb_release -c | cut -d ':' -f2 | tr -d '\t')
    
    # Partition label
    export PARTITION_LABEL=${RANDOM}
    
    # Apt options
    #APT_INSTALL_OPTIONS="--no-install-recommends"
    # HTTP proxy for apt
    #APT_HTTP_PROXY="http://<USERNAME>:<PASSWORD>@<IP>:<PORT>/"
    # apt repo branch
    APT_REPO_BRANCH=${DISTRO_VERSION}
    
    APT_REPO_SECTIONS="main"
    
    # Display variables
    COLUMNS=$(tput cols)
    DEFAULT_COLOR=$(tput sgr0)
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    ORANGE=$(tput setaf 3)
    
    # Syslog configuration
    SYSLOG_LABEL="make_distro"
    SYSLOG_SERVICE="user"

    # Default profile directory
    export PROFILE_DIR=/usr/share/make-deb-distro/scripts/profiles/default
    DEFAULT_SCRIPT_ROOTFS=${PROFILE_DIR}/rootfs.sh
    DEFAULT_SCRIPT_PREPARE=${PROFILE_DIR}/prepare.sh
    DEFAULT_SCRIPT_BURN=${PROFILE_DIR}/burn.sh
    SCRIPT_ROOTFS=$DEFAULT_SCRIPT_ROOTFS
    SCRIPT_PREPARE=$DEFAULT_SCRIPT_PREPARE
    SCRIPT_BURN=$DEFAULT_SCRIPT_BURN
}

# Init all scripts internal commands
init_commands()
{
    export DEBIAN_FRONTEND=noninteractive
    export DEBCONF_NONINTERACTIVE_SEEN=true
    export LC_ALL=C
    export CHROOT="chroot ${TARGET_DIR}"
}

create_rootfs()
{
    if [ ! -d ${TARGET_DIR} ]; then
        print_noln "Create Rootfs ( may take a while... let's have a coffee ;) )"
        # Build minimal rootfs
        logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Build minimal rootfs"
    else
        print_noln "Rootfs already exist but no stamp file, trying to fix ( may take a while... let's have a coffee ;) )"
        # Broken rootfs, try to fix
        logger -t "${SYSLOG_LABEL} WARNING" -p ${SYSLOG_SERVICE}.warning -s "Target directory already exists but missing stamp file"
    fi

    qemu-debootstrap --arch ${ARCH} ${DISTRO_VERSION} ${TARGET_DIR}
    check_result $?

    print_ok
}

prepare_rootfs()
{
    print_noln "Prepare rootfs"

    # Change policy to not start daemons
    echo "#!/bin/sh
exit 101" > ${TARGET_DIR}/usr/sbin/policy-rc.d
    check_result $?
    chmod a+x ${TARGET_DIR}/usr/sbin/policy-rc.d
    check_result $?

    # Mount proc and sys and pts
    logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Mount /proc"
    ${CHROOT} mount -t proc   none /proc
    check_result $?

    logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Mount /sys"
    ${CHROOT} mount -t sysfs  none /sys
    check_result $?

    logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Mount /dev/pts"
    ${CHROOT} mount -t devpts none /dev/pts
    check_result $?

    # Create /etc/mtab
    logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Create /etc/mtab"
    grep -v rootfs ${TARGET_DIR}/proc/mounts > ${TARGET_DIR}/etc/mtab
    check_result $?

    # Allow kernel initrd creation
    logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Allow kernel initrd creation"
    sed '/do_initrd/d' ${TARGET_DIR}/etc/kernel-img.conf > ${TARGET_DIR}/etc/kernel-img.conf
    check_result $?
    echo "do_initrd=yes" >> ${TARGET_DIR}/etc/kernel-img.conf
    check_result $?

    print_ok
}

clean_rootfs()
{
    print_noln "Clean rootfs"

    # Clean apt
    ${CHROOT} apt-get -y clean
    check_result $?

    # Delete temporary files
    rm ${TARGET_DIR}/tmp/* -Rf
    check_result $?

    # Change policy to allow daemons to start
    rm -f ${TARGET_DIR}/usr/sbin/policy-rc.d
    check_result $?

    print_ok
}

apt_dpkg_work()
{
    print_noln "Install packages ( may take a while... let's have an other coffee ^^)"

    # Set apt proxy
    if [ "" != "${APT_HTTP_PROXY}" ]; then
    logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Set apt proxy"
        echo "Acquire::http::proxy \"${APT_HTTP_PROXY}\";" >> ${TARGET_DIR}/etc/apt/apt.conf
        check_result $?
    fi

    # Generate /etc/apt/sources.list
    rm -f ${TARGET_DIR}/etc/apt/sources.list
    echo "deb $APT_MIRROR $DISTRO_VERSION $APT_REPO_SECTIONS
deb $APT_MIRROR ${DISTRO_VERSION}-backports $APT_REPO_SECTIONS
deb $APT_MIRROR ${DISTRO_VERSION}-updates $APT_REPO_SECTIONS
deb $APT_MIRROR ${DISTRO_VERSION}-security $APT_REPO_SECTIONS

deb-src $APT_MIRROR $DISTRO_VERSION $APT_REPO_SECTIONS
deb-src $APT_MIRROR ${DISTRO_VERSION}-backports $APT_REPO_SECTIONS
deb-src $APT_MIRROR ${DISTRO_VERSION}-updates $APT_REPO_SECTIONS
deb-src  $APT_MIRROR ${DISTRO_VERSION}-security $APT_REPO_SECTIONS" > ${TARGET_DIR}/etc/apt/sources.list
    check_result $?

    # Repair potentially broken packages
    ${CHROOT} dpkg --configure -a
    check_result $?

    # Update package list
    ${CHROOT} apt-get update
    check_result $?

    # Install packages from .deb
    if [ "" != "${PACKAGES_DEB}" ]; then
        logger -t "${SYSLOG_LABEL} INFO" -p ${SYSLOG_SERVICE}.info "Install other debian packages"
        # Clean previous .deb packages
        rm ${TARGET_DIR}/*.deb -f
        check_result $?
        cp ${PACKAGES_DEB} ${TARGET_DIR}/
        check_result $?
        for package in ${PACKAGES_DEB}; do
            # Dependencies could be missing so do not check dpkg return but check apt result
            ${CHROOT} dpkg -i /$(basename $package)
            ${CHROOT} apt-get install -y -f
            check_result $?
            # If all is ok, remove .deb package
            rm ${TARGET_DIR}/$(basename $package) -f
        done
        check_result $?
    fi

    # Upgrade already installed packages
    ${CHROOT} apt-get upgrade -y
    check_result $?

    # Install packages from repository. Will install only missing packages.
    if [ "" != "${PACKAGES}" ]; then
        ${CHROOT} apt-get install ${PACKAGES} -y -f
        check_result $?
    fi

    # Remove unwanted packages.
    if [ "" != "${PACKAGES_EXCLUDED}" ]; then
        ${CHROOT} apt-get purge ${PACKAGES_EXCLUDED} -y
        check_result $?
    fi

    # Autoremove unused packages
    ${CHROOT} apt-get autoremove --purge -y

    # Update all initrd in /boot
    ls -1 ${TARGET_DIR}/boot/vmlinuz*
    if [ $? -eq 0 ]; then
        ${CHROOT} update-initramfs -c -k all
        check_result $?
    fi

    print_ok
}

umount_all_in_rootfs()
{
    print_noln "Umount all in rootfs"

    sync

    # Umount all filesystems mounted in the chroot environment
    if [ "" != "$(${CHROOT} mount | grep /dev/pts)" ]; then
        umount ${TARGET_DIR}/dev/pts
    fi
    if [ "" != "$(${CHROOT} mount | grep /proc)" ]; then
        umount ${TARGET_DIR}/proc
    fi
    if [ "" != "$(${CHROOT} mount | grep /sys)" ]; then
        umount ${TARGET_DIR}/sys
    fi

    echo "" > ${TARGET_DIR}/etc/mtab

    print_ok
}

umount_image()
{
    print_noln "Umount image directory"

    if mount | grep ${TARGET_DIR}_image > /dev/null; then
        umount ${TARGET_DIR}_image
        check_result $?
    fi

    print_ok
}

generate_distro()
{
    # Create rootfs
    if [ ! -f ${TARGET_DIR}/.stamp_rootfs ]; then
        create_rootfs
        echo ${DISTRO_NAME}_${DISTRO_VERSION}_${ARCH} > ${TARGET_DIR}/.stamp_rootfs
    else
        print_noln "Rootfs already exist, creation skipped"
        print_warn

        print_noln "Checking rootfs"
        grep -q ${DISTRO_NAME}_${DISTRO_VERSION}_${ARCH} ${TARGET_DIR}/.stamp_rootfs
        check_result $? "Rootfs already exists but distro name, version or arch are different"
        print_ok
    fi

    # Prepare rootfs
    prepare_rootfs

    # Configure apt and finish packages install
    apt_dpkg_work

    # Execute script after rootfs is created
    if [ "${SCRIPT_ROOTFS}" != "" ]; then
        print_noln "Execute '${SCRIPT_ROOTFS}' script"
        sh ${SCRIPT_ROOTFS}
        check_result $?
        print_ok
    fi

    # Clean chroot environment
    clean_rootfs
 
    # Umount all
    umount_all_in_rootfs

    if [ "${ONLY_ROOTFS}" = "0" ]; then
        # Execute script to prepare target
        print_noln "Execute '${SCRIPT_PREPARE}' script"
        bash ${SCRIPT_PREPARE}
        check_result $?
        print_ok

        # Burn target
        print_noln "Execute '${SCRIPT_BURN}' script"
        bash ${SCRIPT_BURN}
        check_result $?
        print_ok
    fi
}

uninstall()
{
    if [[ -d ${TARGET_DIR} ]]; then
        # Umount all
        umount_all_in_rootfs
    
        umount_image
    
        # Delete all
        print_noln "Delete ${TARGET_DIR}"
        rm ${TARGET_DIR} -Rf
        check_result $?
        print_ok
    fi
    if [[ -d ${TARGET_DIR}_image ]]; then
        print_noln "Delete ${TARGET_DIR}_image"
        rm ${TARGET_DIR}_image -Rf
        check_result $?
        print_ok
    fi
    if [[ -f ${TARGET_DIR} ]]; then
        print_noln "Delete ${TARGET_DIR}_loop"
        rm ${TARGET_DIR}_loop
        check_result $?
        print_ok
    fi
    
    print_noln "Uninstall"
    print_ok
}

print_usage()
{
    echo "This script build custom Ubuntu/Debian distributions.

./$(basename ${0}) [-a <action>] [OPTIONS]

Options:
        (-a|--action)            <action>                Action : "install" or "uninstall".
        (-b|--target-device)     <device>                Target device
        (-c|--configuration)     <file>                  Configuration file
        (-d|--target-dir)        <path>                  Bootstrap path
        (-e|--excluded-packages) \"<excluded-packages>\"   Packages to exclude from bootstrap process. List must be quoted.
        (-f|--only-rootfs)                               Build rootfs only
        (-h|--help)                                      Display this help message
        (-n|--distro-version)    <distro-name>           Debian/Ubuntu distribution name (same as host by default).
        (-o|--deb-packages)      \"<deb-packages>\"        Local .deb packages. List must be quoted.
        (-p|--packages)          \"<packages>\"            Distro packages to use. List must be quoted.
        (--script-rootfs)        <script>                Launch your script after rootfs is created and all package installed.
        (--script-prepare)       <script>                Launch your script to prepare the target device.
                                                         (${DEFAULT_SCRIPT_PREPARE} by default)
        (--script-burn)          <script>                Launch your script to burn rootfs on target device.
                                                         (${DEFAULT_SCRIPT_BURN} by default)
        (-t|--target)            <target>                Target achitecture (same as host by default).
        (-v|--verbose)                                   Verbose mode
        "
}

parse_options()
{
    ARGS=$(getopt -o "a:b:c:d:e:fhk:n:N:o:p:t:u:vw" -l "action:,configuration:,deb-packages:,device:,distro-name:,distro-version,excluded-packages:,help,only-rootfs,packages:,script-prepare:,script-rootfs:,script-burn:,target:,target-device:,target-dir:,verbose" -n "make_distro.sh" -- "$@")

    #Bad arguments
    if [ $? -ne 0 ]; then
        exit 1
    fi

    eval set -- "${ARGS}"

    while true; do
        case "$1" in
            -a|--action)
                action=$2
                shift 2
                ;;

            -b|--target-device)
                TARGET_DEVICE="$2"
                shift 2
                ;;

            -c|--configuration)
                . $2
                shift 2
                ;;

            -d|--target-dir)
                TARGET_DIR="$2"
                if [ "?" = "${TARGET_DIR}" ] || [ ":" = "${TARGET_DIR}" ] || [ "" = "${TARGET_DIR}" ]; then
                    echo "Wrong destination directory. Exiting."
                    exit 1
                fi
                shift 2
                ;;

            -e|--excluded-packages)
                PACKAGES_EXCLUDED="$PACKAGES_EXCLUDED $2"
                echo $PACKAGES_EXCLUDED
                shift 2
                ;;

            -f|--only-rootfs)
                ONLY_ROOTFS=1
                shift
                ;;

            -h|--help)
                print_usage
                exit 0
                shift
                ;;

            -n|--distro-name)
                DISTRO_NAME=$2
                shift 2
                ;;

            -N|--distro-version)
                DISTRO_VERSION=$2
                shift 2
                ;;

            -o|--deb-packages)
                PACKAGES_DEB="$PACKAGES_DEB $2"
                echo $PACKAGES_DEB
                shift 2
                ;;

            -p|--packages)
                PACKAGES="$PACKAGES $2"
                echo $PACKAGES
                shift 2
                ;;

            --script-rootfs)
                SCRIPT_ROOTFS=$2
                shift 2
                ;;

            --script-prepare)
                SCRIPT_PREPARE=$2
                shift 2
                ;;

            --script-burn)
                SCRIPT_BURN=$2
                shift 2
                ;;

            -t|--target)
                ARCH=$2
                shift 2
                ;;

            -v|--verbose)
                VERBOSE=1
                shift
                ;;

            -|--)
                shift
                break
                ;;

            *)
                print_usage
                exit 1
                shift
                break
                ;;
        esac
    done
}

########## MAIN ##########

# Init function
init

# Parse options
parse_options "${@}"

# Set paths to absolute
TARGET_DIR=$(realpath $(dirname $TARGET_DIR))/$(basename $TARGET_DIR)
PROFILE_DIR=$(realpath $PROFILE_DIR)

# Init internal commands
init_commands

# Determines apt repository according to distro
case ${DISTRO_NAME} in
    "ubuntu")
        case ${ARCH} in
            amd64|i386)
              APT_MIRROR="http://archive.ubuntu.com/ubuntu"
              ;;
            *)
              APT_MIRROR="http://ports.ubuntu.com/ubuntu-ports"
              ;;
        esac
        APT_REPO_SECTIONS="${APT_REPO_SECTIONS} restricted universe multiverse"
        ;;
    "debian")
        APT_MIRROR="http://ftp.us.debian.org/debian"
        ;;
    *)
        echo "Error : Bad Debian-like distro..."
        exit 1
        ;;
esac

# Check target device
if [ ${ONLY_ROOTFS} = "0" ] && ( [ -z ${TARGET_DEVICE} ] || [ ! -b ${TARGET_DEVICE} ] ); then
    echo "Error : Target device does not exist or not set..."
    exit 2
fi

# Select partition
if [ "$(echo ${TARGET_DEVICE} | grep '.*[0-9]$')" != "" ]; then
    export VFAT_DEVICE=${TARGET_DEVICE}p1
    export ROOTFS_DEVICE=${TARGET_DEVICE}p2
else
    export VFAT_DEVICE=${TARGET_DEVICE}1
    export ROOTFS_DEVICE=${TARGET_DEVICE}2
fi

# If verbose, display command output
if [ "${VERBOSE}" = "0" ]; then
    exec 6>&1
    exec 7>&2

    exec 1>${TARGET_DIR%/}.log
    exec 2>&1
fi

print_out "Starting. Please wait..."

# Check action to perform
if [ "uninstall" = "${action}" ]; then
    uninstall
    exit 0
elif [ "install" = "${action}" ]; then
    trap    "umount_all_in_rootfs;umount_image"        EXIT
    generate_distro
    exit 0
else
    print_out "Wrong action or bad one. Check -a option. Exiting."
fi

