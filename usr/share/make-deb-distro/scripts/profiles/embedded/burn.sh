#!/bin/bash

. ${MDD_INCLUDE_DIR}/functions.sh

pwd=$PWD

# Use absolute paths
EMB_BUILD_PATH=$(realpath $EMB_BUILD_PATH)
EMB_UBOOT_PATH=${EMB_BUILD_PATH}/${EMB_UBOOT_NAME}
EMB_KERNEL_PATH=${EMB_BUILD_PATH}/${EMB_KERNEL_NAME}

boot_mount_point=/tmp/${RANDOM}

mkdir -p ${boot_mount_point}
check_result $?

cd $EMB_BUILD_PATH
check_result $?

mount ${MDD_VFAT_DEVICE} ${boot_mount_point}
check_result $?

# Copy device tree from linux kernel on bootloader partition
dtb_kernel_file=$(echo $EMB_KERNEL_TARGET | egrep -o "([[:alnum:]]|-|_)+\.dtb")
if [ ! -z "${dtb_kernel_file}" ]; then
    cp -f $EMB_KERNEL_PATH/arch/${ARCH}/boot/dts/${dtb_kernel_file} ${boot_mount_point}/
    check_result $?
fi

# Copy Linux kernel on bootloader partition
kernel_file=$(echo $EMB_KERNEL_TARGET | egrep -o "(u|z)Image")
if [ ! -z "${kernel_file}" ]; then
    cp -f $EMB_KERNEL_PATH/arch/${ARCH}/boot/${kernel_file} ${boot_mount_point}/ 
    check_result $?
fi

# Copy U-Boot spl on bootloader partition
if [ -f ${EMB_UBOOT_PATH}/spl/u-boot-spl.bin ]; then
    cp -f ${EMB_UBOOT_PATH}/spl/u-boot-spl.bin ${boot_mount_point}/
    check_result $?
fi

# Copy U-Boot image on bootloader partition
if [ -f ${EMB_UBOOT_PATH}/u-boot.img ]; then
    cp -f ${EMB_UBOOT_PATH}/u-boot.img ${boot_mount_point}/
    check_result $?
fi

sync
check_result $?

# Umount and delete bootloader partition mountpoint 
umount ${boot_mount_point}
check_result $?
rmdir ${boot_mount_point}
check_result $?

root_mount_point=/tmp/${RANDOM}

# Set partition label for kernel mount 
e2label ${MDD_ROOTFS_DEVICE} ${MDD_ROOTFS_PARTITION_LABEL}
check_result $?

# Mount rootfs partition
mkdir -p ${root_mount_point}
check_result $?
mount ${MDD_ROOTFS_DEVICE}  ${root_mount_point}
check_result $?

# Copy rootfs
cp -Rf --preserve=all ${MDD_TARGET_DIR}/* ${root_mount_point}/
check_result $?

# Umount and delete rootfs partition mountpoint 
umount ${root_mount_point}/
check_result $?
rmdir ${root_mount_point}/
check_result $?

cd $pwd
