#!/bin/sh
. ${MDD_INCLUDE_DIR}/functions.sh

pwd=$PWD

# Use absolute paths
EMB_BUILD_PATH=$(realpath $EMB_BUILD_PATH)
EMB_UBOOT_PATH=${EMB_BUILD_PATH}/${EMB_UBOOT_NAME}
EMB_KERNEL_PATH=${EMB_BUILD_PATH}/${EMB_KERNEL_NAME}

mkdir -p $EMB_BUILD_PATH
check_result $?

cd $EMB_BUILD_PATH
check_result $?

# Uboot bootloader
if [ ! -z "${EMB_UBOOT_CONFIG}" ]; then
    if [ "$(git --git-dir ${EMB_UBOOT_PATH}/.git remote -v | egrep "origin\s+.*${EMB_UBOOT_NAME}.*")" = "" ]; then
        rm -Rf ${EMB_UBOOT_PATH}
        git clone ${EMB_UBOOT_GIT} ${EMB_UBOOT_PATH}
        (cd ${EMB_UBOOT_PATH} && git checkout ${EMB_UBOOT_TAG} -b ${EMB_UBOOT_LOCAL_BRANCH})
        check_result $?
    else
        (cd $EMB_UBOOT_PATH && git fetch origin)
    fi
    
    cd ${EMB_UBOOT_PATH}
    check_result $?
    if [ ! -f .config ]; then
        make ${EMB_UBOOT_CONFIG}
        check_result $?
    fi
    if [ "${MDD_VERBOSE}" != "0" ]; then
        make menuconfig
        check_result $?
    fi
    make ${EMB_UBOOT_TARGET}
    check_result $?
fi

cd $EMB_BUILD_PATH
check_result $?

# Linux kernel
if [ ! -z "${EMB_KERNEL_CONFIG}" ]; then
    if [ "$(git --git-dir ${EMB_KERNEL_PATH}/.git remote -v | egrep "origin\s+.*${EMB_KERNEL_NAME}.*")" = "" ]; then
        rm -Rf ${EMB_KERNEL_PATH}
        git clone ${EMB_KERNEL_GIT} ${EMB_KERNEL_PATH}
        check_result $?
        (cd ${EMB_KERNEL_PATH} && git checkout ${EMB_KERNEL_TAG} -b ${EMB_KERNEL_LOCAL_BRANCH})
        check_result $?
    else
        (cd $EMB_KERNEL_PATH && git fetch origin)
    fi
    
    cd ${EMB_KERNEL_PATH}
    check_result $?
    if [ ! -f .config ]; then
        make ${EMB_KERNEL_CONFIG}
        check_result $?
    fi
    if [ "${MDD_VERBOSE}" != "0" ]; then
        make menuconfig
        check_result $?
    fi
    make -j$(nproc) ${EMB_KERNEL_TARGET}
    check_result $?
    make INSTALL_MOD_PATH=${MDD_TARGET_DIR} modules_install
    check_result $?
fi

# tty configuration
if [ ! -z "${EMB_TTY}" ]; then
    echo "# ttyS0 - getty
    #
    # This service maintains a getty on ttyS0 from the point the system is
    # started until it is shut down again.
    
    start on stopped rc or RUNLEVEL=[2345]
    stop on runlevel [!2345]
    
    respawn
    exec /sbin/getty -L 115200 ttyS0 vt102" > ${MDD_TARGET_DIR}/etc/init/ttyS0.conf
    check_result $?
fi

# Network configuration
if [ ! -z "${EMB_NETINTERFACE}" ]; then
    echo "auto ${EMB_NETINTERFACE}
    iface ${EMB_NETINTERFACE} inet dhcp" > ${MDD_TARGET_DIR}/etc/network/interfaces.d/${EMB_NETINTERFACE}
    check_result $?
fi

# Add default user
if [ ! -z "${EMB_USERNAME}" ]; then
    ${MDD_CHROOT} userdel ${EMB_USERNAME}
    ${MDD_CHROOT} useradd -d /home/${EMB_USERNAME} -s /bin/bash -m -p `mkpasswd ${EMB_USERNAME}` ${EMB_USERNAME}
    check_result $?
    sed -i "/^${EMB_USERNAME}/d" ${MDD_TARGET_DIR}/etc/sudoers
    check_result $?
    echo "${EMB_USERNAME} ALL=(ALL) ALL" >> ${MDD_TARGET_DIR}/etc/sudoers
    check_result $?
fi

cd $pwd
