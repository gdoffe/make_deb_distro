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

# Depends on realpath whois qemu-kvm-extras-static squashfs-tools extlinux mbr

# Init all script variables
init()
{
    # Final target will be burn read only if different of 0.
    READ_ONLY=0

    # Script is verbose if different of 0.
    VERBOSE=0

    # Only do debootstrap and dpkg work if different of 0.
    ONLY_ROOTFS=0

    # Target roots filesystem
    TARGET_DIR="${PWD}/../targetdir"
    
    # Target architecture
    ARCH=$(dpkg --print-architecture)
    
    # Debian-like distribution
    DEBIAN_DISTRO=$(lsb_release -i | cut -d ':' -f2 | tr -d '\t' | tr 'A-Z' 'a-z')
    
    # Debian-like version
    DEBIAN_VERSION=$(lsb_release -c | cut -d ':' -f2 | tr -d '\t')
    
    # Configuration directory
    CONF_DIR=./make_distro.d
    
    # Partition label
    PARTITION_LABEL=${RANDOM}
    
    # Apt options
    #APT_INSTALL_OPTIONS="--no-install-recommends"
    # HTTP proxy for apt
    #APT_HTTP_PROXY="http://<USERNAME>:<PASSWORD>@<IP>:<PORT>/"
    # apt repo branch
    APT_REPO_BRANCH=${DEBIAN_VERSION}
    
    APT_REPO_SECTIONS="main restricted universe multiverse"
    
    # Display variables
    COLUMNS=$(tput cols)
    DEFAULT_COLOR=$(tput sgr0)
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    
    # Syslog configuration
    SYSLOG_LABEL="make_distro"
    SYSLOG_SERVICE="user"
}

# Init all scripts internal commands
init_commands()
{
    CHROOT="chroot ${TARGET_DIR}"
}

check_result()
{
    if [ "${1}" != "0" ]; then
        print_ko
    exit 1
    fi
}

print_noln()
{
    print_noln_ "${*}" &
    wait $!
    string="${*}"
    str_size=${#string}
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

create_rootfs()
{
    print_noln "Create Rootfs ( may take a while... let's have a coffee ;) )"

    # Build minimal rootfs
    if [ ! -d ${TARGET_DIR} ]; then
        logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Build minimal rootfs"

        if [ "" != "${APT_REPO_SECTIONS}" ]; then
                components_option="--components=$(echo ${APT_REPO_SECTIONS} | tr ' ' ',')"
        fi
        if [ "" != "${PACKAGES_MANDATORY}" ] || [ "" != "${PACKAGES_WANTED}" ]; then
                include_option="--include=$(echo ${PACKAGES_WANTED} ${PACKAGES_MANDATORY} | tr ' ' ',')"
        fi
        if [ "" != "${PACKAGES_EXCLUDED}" ]; then
                exclude_option="--exclude=$(echo ${PACKAGES_EXCLUDED} | tr ' ' ',')"
        fi

        #actualvt=$(fgconsole)
        #chvt `fgconsole --next-available` && chvt ${actualvt}
        qemu-debootstrap --arch ${ARCH} ${components_option} ${include_option} ${exclude_option} ${DEBIAN_VERSION} ${TARGET_DIR}
        check_result $?

        TARGET_DIR=`realpath ${TARGET_DIR}`
    fi

    print_ok
}

prepare_rootfs()
{
    print_noln "Prepare rootfs"

    # Mount proc and sys and pts
    logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Mount /proc"
    ${CHROOT} mount -t proc   none /proc
    check_result $?

    logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Mount /sys"
    ${CHROOT} mount -t sysfs  none /sys
    check_result $?

    logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Mount /dev/pts"
    ${CHROOT} mount -t devpts none /dev/pts
    check_result $?

    # Create /etc/mtab
    logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Create /etc/mtab"
    grep -v rootfs ${TARGET_DIR}/proc/mounts > ${TARGET_DIR}/etc/mtab
    check_result $?

    # Allow kernel initrd creation
    logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Allow kernel initrd creation"
    sed '/do_initrd/d' ${TARGET_DIR}/etc/kernel-img.conf > ${TARGET_DIR}/etc/kernel-img.conf
    check_result $?
    echo "do_initrd=yes" >> ${TARGET_DIR}/etc/kernel-img.conf
    check_result $?

    if [ "1" != ${READ_ONLY} ]; then
        ${CHROOT} userdel ubuntu
        ${CHROOT} useradd -d /home/ubuntu -s /bin/bash -m -p `mkpasswd ubuntu` ubuntu
        check_result $?
        sed '/^ubuntu/d' ${TARGET_DIR}/etc/sudoers > ${TARGET_DIR}/etc/sudoers
        check_result $?
        echo "ubuntu ALL=(ALL) ALL" >> ${TARGET_DIR}/etc/sudoers
        check_result $?
    fi

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

    print_ok
}

apt_dpkg_work()
{
    print_noln "Install packages ( may take a while... let's have an other coffee ^^)"

    # Set apt proxy
    if [ "" != "${APT_HTTP_PROXY}" ]; then
    logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Set apt proxy"
        echo "Acquire::http::proxy \"${APT_HTTP_PROXY}\";" >> ${TARGET_DIR}/etc/apt/apt.conf
        check_result $?
    fi

    # Install packages from .deb
    if [ "" != "${PACKAGES_DEB}" ]; then
        logger -t ${SYSLOG_LABEL} -p ${SYSLOG_SERVICE}.info "Install other debian packages"
        cp ${PACKAGES_DEB} ${TARGET_DIR}/
        check_result $?
        for package in ${PACKAGES_DEB};
        do
            DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C ${CHROOT} dpkg -r $(${CHROOT} dpkg-deb -W --showformat '${Package}' /$(basename ${package}))
            DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C ${CHROOT} dpkg -i /$(basename ${package})
            check_result $?
            rm ${TARGET_DIR}/$(basename ${package})
            check_result $?
        done
    fi

    # Add updates
    # TODO make next step dynamic
    #(echo "deb http://archive.ubuntu.com/ubuntu ${APT_REPO_BRANCH}-updates main restricted universe multiverse" >> ${TARGET_DIR}/etc/apt/sources.list)
    #check_result $?
    #DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C ${CHROOT} apt-get update
    #check_result $?
    #DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C ${CHROOT} apt-get upgrade -y
    #check_result $?

    # Disable apt-cdrom in initramfs since it is not an installation distrib
    if [ "1" = ${READ_ONLY} ]; then
        if [[ -x ${TARGET_DIR}/usr/share/initramfs-tools/scripts/casper-bottom/41apt_cdrom ]]; then 
            chmod a-x ${TARGET_DIR}/usr/share/initramfs-tools/scripts/casper-bottom/41apt_cdrom
            check_result $?
        fi
    fi

    # Update all initrd in /boot
    ls -1 ${TARGET_DIR}/boot/vmlinuz*
    if [ $? -eq 0 ]; then
        ${CHROOT} update-initramfs -c -k all
    	check_result $?
    fi

    print_ok
}

prepare_ro_image()
{
    print_noln "Prepare ro image"

    # Loopback
    touch ${TARGET_DIR}_loop
    check_result $?

    # Create loopback mountpoint
    mkdir ${TARGET_DIR}_image/
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
    cp ${CONF_DIR}/extlinux/* ${TARGET_DIR}_image/boot/extlinux/
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

    mkdir ${TARGET_DIR}_image/.disk
    #touch ${TARGET_DIR}_image/.disk/base_installable
    #echo "full_cd/single" > ${TARGET_DIR}_image/.disk/cd_type
    echo "${DEBIAN_VERSION}" > ${TARGET_DIR}_image/.disk/info
    echo "http//geonobot-wiki.toile-libre.org" > ${TARGET_DIR}_image/.disk/release_notes_url

    # Compress rootfs
    mksquashfs ${TARGET_DIR} ${TARGET_DIR}_image/casper/filesystem.squashfs -noappend
    check_result $?

    # Copy README.diskdefines
    cp ${CONF_DIR}/README.diskdefines ${TARGET_DIR}_image/
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
    readlink -f /sys/block/$(basename ${TARGET_DEVICE}) | grep -oq usb
    check_result $?

    print_ok
}

burn_ro_image()
{
    print_noln "Burn ro image"

    # Compress loopback
    gzip -c ${TARGET_DIR}_loop > geonobot.gz
    check_result $?

    # Umount all on the target device
    umount ${TARGET_DEVICE}*

    # Prepare target device
    echo ",,L,*" | sfdisk -f ${TARGET_DEVICE}
    check_result $?

    # Install MBR
    install-mbr ${TARGET_DEVICE}
    check_result $?

    # Uncompress filesystem in target device
    zcat geonobot.gz > ${PARTITION_DEVICE}
    check_result $?

    print_ok
}

prepare_rw_image()
{
    print_noln "Prepare rw image"

    # Create extlinux directory
    mkdir -p ${TARGET_DIR}/boot/extlinux
    check_result $?

    # Boot entries
    cp -f ${CONF_DIR}/extlinux/* ${TARGET_DIR}/boot/extlinux/
    check_result $?
    
    echo "${CONF_DIR}/extlinux/* ${TARGET_DIR}/boot/extlinux/"

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

    # Check that target device is on USB bus
    readlink -f /sys/block/$(basename ${TARGET_DEVICE}) | grep -oq -e usb -e mmc_host
    check_result $?

    print_ok
}

burn_rw_image()
{
    print_noln "Burn rw image"

    mount_point=/tmp/${RANDOM}

    # Umount target if already mounted
    umount ${TARGET_DEVICE}*
    for swap_partition in $(swapon -s | grep ${TARGET_DEVICE} | cut -d ' ' -f1);
    do
        swapoff ${swap_partition}
        check_result $?
    done

    # Prepare target device
    (echo "0,512,S,
    ,,L,*,
    ;
    ;" | sfdisk -fuM ${TARGET_DEVICE})
    check_result $?

    # Install MBR
    install-mbr ${TARGET_DEVICE}
    check_result $?

    # Format target
    mkfs.ext3 -F -L ${RANDOM} -m 0 ${PARTITION_DEVICE}
    check_result $?
    mkswap ${SWAP_DEVICE}
    check_result $?

    # Set partition label for kernel mount
    e2label ${PARTITION_DEVICE} ${PARTITION_LABEL}
    check_result $?

    # Mount target
    mkdir -p ${mount_point}
    check_result $?
    mount ${PARTITION_DEVICE}  ${mount_point} -t ext3
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

    print_ok
}

umount_all_in_rootfs()
{
    print_noln "Umount all in rootfs"

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
    create_rootfs



    # Prepare rootfs
    prepare_rootfs

    # Configure apt and finish packages install
    apt_dpkg_work

    # Clean chroot environment
    clean_rootfs
 
    # Umount all
    umount_all_in_rootfs

    if [ "${ONLY_ROOTFS}" == 0 ]; then
        if [ "1" = ${READ_ONLY} ]; then
            # Prepare image
            prepare_ro_image

            # Burn image
            burn_ro_image
        else
            # Prepare image
            prepare_rw_image

            # Burn image
            burn_rw_image
        fi
    fi
}

uninstall()
{
    if [[ -d ${TARGET_DIR} ]]; then
        TARGET_DIR=`realpath ${TARGET_DIR}`
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
        (-a|--action)            <action>               Action : "install" or "uninstall".
        (-b|--target-device)     <device>               Target device
        (-f|--only-rootfs)                              Build rootfs only
        (-h|--help)                                     Display this help message
        (-d|--target-dir)        <path>                 Bootstrap path
        (-o|--deb-packages)      \"<deb_packages>\"       Local .deb packages. List must be quoted.
        (-p|--packages)          \"<packages>\"           Distro packages to use. List must be quoted.
        (-r|--read-only)                                Read only distro
        (-t|--target)            <target>               Target achitecture (same as host by default)
        (-u|--excluded-packages) \"<unwanted_packages>\"  Packages to exclude from bootstrap process. List must be quoted.
        (-v|--verbose)                                  Verbose mode
        "
}

parse_options()
{
    ARGS=$(getopt -o "a:b:d:fhk:o:p:ru:t:vw" -l "action:,deb-packages:,device:,excluded-packages:,help,only-rootfs,packages:,read-only,target:,target-device:,target-dir:,verbose" -n "make_distro.sh" -- "$@")

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

            -d|--target-dir)
                TARGET_DIR="$2"
                if [ "?" = "${TARGET_DIR}" ] || [ ":" = "${TARGET_DIR}" ] || [ "" = "${TARGET_DIR}" ]; then
                    echo "Wrong destination directory. Exiting."
                    exit 1
                fi
                shift 2
                ;;

            -e|--excluded-packages)
                echo $2 | grep "^-" > /dev/null
                while [ $? -ne 0 ]; do
                    PACKAGES_EXCLUDED="$PACKAGES_EXCLUDED $2"
                    shift
                    echo $2 | grep "^-" > /dev/null
                done
                shift 
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

            -o|--deb-packages)
                echo $2 | grep "^-" > /dev/null
                while [ $? -ne 0 ]; do
                    PACKAGES_DEB="$PACKAGES_DEB $2"
                    shift
                    echo $2 | grep "^-" > /dev/null
                done
                shift 
                ;;

            -p|--packages)
                echo $2 | grep "^-" > /dev/null
                while [ $? -ne 0 ]; do
                    PACKAGES_WANTED="$PACKAGES_WANTED $2"
                    shift
                    echo $2 | grep "^-" > /dev/null
                done
                shift 
                ;;

            -r|--read-only)
                READ_ONLY=1
                shift
                ;;

            -t|--target)
                ARCH="$2"
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

# Init internal commands
init_commands

# Determines apt repository according to distro
case ${DEBIAN_DISTRO} in
    "ubuntu")
        if [ "1" = ${READ_ONLY} ]; then
                PACKAGES_MANDATORY="casper discover laptop-detect"
        fi
        ;;
    "debian")
        PACKAGES_MANDATORY="initramfs-tools"
        ;;
    *)
        echo "Error : Bad Debian-like distro..."
        exit 1
        ;;
esac

# Check target device
if [ ! -b ${TARGET_DEVICE} ]; then
    echo "Error : Target device does not exist..."
    exit 2
fi

# Select partition
if [ "$(echo ${TARGET_DEVICE} | grep '.*[0-9]$')" != "" ]; then
    SWAP_DEVICE=${TARGET_DEVICE}p1
    PARTITION_DEVICE=${TARGET_DEVICE}p2
else
    SWAP_DEVICE=${TARGET_DEVICE}1
    PARTITION_DEVICE=${TARGET_DEVICE}2
fi

# If verbose, display command output
if [ "${VERBOSE}" = "0" ]; then
    exec 6>&1
    exec 7>&2

    exec 1>$(dirname ${TARGET_DIR})/$(basename ${TARGET_DIR}).log
    exec 2>&1
fi

print_out "Starting. Please wait..."

# Check action to perform
if [ "uninstall" = "${action}" ]; then
    uninstall
    exit 0
elif [ "install" = "${action}" ]; then
    trap    "umount_all_in_rootfs;umount_image"        EXIT
    #uninstall
    generate_distro
    exit 0
else
    echo "Wrong action or bad one. Check -a option. Exiting." > /dev/stderr
fi

