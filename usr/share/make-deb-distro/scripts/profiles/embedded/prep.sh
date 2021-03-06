#!/bin/bash

. ${MDD_INCLUDE_DIR}/functions.sh

# Umount target if already mounted
umount ${MDD_TARGET_DEVICE}*
for swap_partition in $(swapon -s | grep ${MDD_TARGET_DEVICE} | cut -d ' ' -f1);
do
    swapoff ${swap_partition}
    check_result $?
done

# Erase partition table
dd if=/dev/zero of=${MDD_TARGET_DEVICE} bs=1024 count=1024
check_result $?

# Compute partitions size
disk_size=$(fdisk -l ${MDD_TARGET_DEVICE} | head -1 | tail -1 | egrep "[0-9]+" -o | tail -1 | head -1)
disk_start=2048

misc_start=$disk_start
fat_size=1048576

# Compute extended partitions size
current_start=$disk_start
extra_size=2048
for current in $(printenv | grep MDD_EXTRA_PARTITION_ | cut -d'=' -f1); do
    current_size=$(eval "echo \${${current}} | cut -d' ' -f1")
    extra_size=$(( extra_size + current_size + 2048  ))
done

# Optional extra primary partition
if [ -n "${MDD_EXTRA_PRIMARY_PARTITION}" ]; then
    misc_size=$(echo ${MDD_EXTRA_PRIMARY_PARTITION} | cut -d' ' -f1)
else
    misc_size=0
fi

extended_size=$(( extra_size + 2048 ))
linux_size=$(( disk_size - fat_size - misc_size - extended_size))

fat_start=$(( misc_start + misc_size ))
linux_start=$(( fat_start + fat_size ))
extended_start=$(( linux_start + linux_size ))

# Create sfdisk parameters
# Mandatory partitions :
#     * FAT32 partition for bootloader
#     * Linux partition for rootfs
#     * Extended partition for extra partitions
if [ -n "${MDD_EXTRA_PRIMARY_PARTITION}" ]; then
    misc_type=$(echo ${MDD_EXTRA_PRIMARY_PARTITION} | cut -d' ' -f2)
fi
sfdisk_input="# partition table of ${MDD_TARGET_DEVICE}
unit: sectors

${MDD_VFAT_DEVICE} : start= ${fat_start}, size=   ${fat_size}, type=b, bootable
${MDD_ROOTFS_DEVICE} : start= ${linux_start}, size= ${linux_size}, type=83"
if [ -n "${MDD_EXTRA_PRIMARY_PARTITION}" ]; then
    sfdisk_input="${sfdisk_input}
${MDD_PARTITION_PREFIX}3 : start= ${misc_start}, size= ${misc_size}, type=${misc_type}"
fi
sfdisk_input="${sfdisk_input}
${MDD_PARTITION_PREFIX}4 : start= ${extended_start}, size= ${extended_size}, type=5"

# Add extra partitions
index=5
current_start=$(( extended_start + 2048 ))
for current in $(printenv | grep MDD_EXTRA_PARTITION_ | cut -d'=' -f1); do
    current_size=$(( $(eval "echo \${${current}} | cut -d' ' -f1") + 2048 ))
    current_type=$(eval "echo \${${current}} | cut -d' ' -f2")
    sfdisk_input="${sfdisk_input}
${MDD_PARTITION_PREFIX}${index} : start=    ${current_start}, size=    ${current_size}, type=${current_type}"
    current_start=$(( current_start + current_size + 2048))
    index=$(( index + 1 ))
done

# Launch sfdisk
printf "$sfdisk_input\n" | sfdisk ${MDD_TARGET_DEVICE}
check_result $?

# Re-read partitions table
partprobe ${MDD_TARGET_DEVICE}
check_result $?

# Check partitions table is readable
fdisk -l ${MDD_TARGET_DEVICE}
check_result $?

# Format mandatory partition :
#     * vfat for bootloader partition
#     * ext4 for rootfs partition
# TODO: Make mandatory partition filesystem configurable
mkfs.vfat -n UBOOT ${MDD_VFAT_DEVICE}
check_result $?
mkfs.ext4 -F -L ${RANDOM} ${MDD_ROOTFS_DEVICE}
check_result $?

# Format extra primary partition if needed
if [ -n "${MDD_EXTRA_PRIMARY_PARTITION}" ]; then
    misc_fs=$(echo ${MDD_EXTRA_PRIMARY_PARTITION} | cut -d' ' -f3)
    if [ -n "${misc_fs}" ]; then
        mkfs -t ${misc_fs} ${MDD_PARTITION_PREFIX}3
    fi
fi

# Format extra partitions
index=5
for current in $(printenv | grep MDD_EXTRA_PARTITION_ | cut -d'=' -f1); do
    current_fs=$(eval "echo \${${current}} | cut -d' ' -f3")
    if [ -n ${current_fs} ]; then
        mkfs -t ${current_fs} ${MDD_PARTITION_PREFIX}${index}
    fi
    index=$(( index + 1 ))
done
