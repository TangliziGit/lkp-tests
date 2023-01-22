#!/usr/bin/env bash

# A tool to generate initramfs.lkp according to the specific kernel version of modules
#
# Usage: gen-initramfs.sh <modules_path>
# Example: gen-initramfs.sh /srv/mci/os/centos7/lib/modules/3.10.0-1160.el7.x86_64

kver=$(basename "$1")
root=${1%/lib/modules/*}

kernel_modules=/lib/modules/$kver
initrd_output=/boot/initramfs.lkp-${kver}.img

docker run \
    --rm \
    -v "$root/boot":/boot \
    -v "$root/lib/modules":/lib/modules \
    tanglizi/debian:dracut bash -c \
    "dracut --force --kver $kver -k $kernel_modules $initrd_output && chmod 644 $initrd_output"
