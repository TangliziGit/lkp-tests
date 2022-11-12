#!/bin/bash
# Usage:
# $ docker run -ti -v /c/lkp-tests:/c/lkp-tests ubuntu:22.04 bash
# root@4f87b1825220:/# cd /c/lkp-tests/
# root@4f87b1825220:/c/lkp-tests# sbin/add-distro-packages.sh
#
# You may need enable more repos
# For oracle/rocky etc.
# # sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/*
# For debian,
# # sed -i 's/main$/main non-free contrib/' /etc/apt/sources.list

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
export LKP_SRC=$(dirname $SCRIPT_DIR)

. $LKP_SRC/lib/detect-system.sh
detect_system
get_system_arch

[ -n "$_system_arch" ] || exit

test -e $LKP_SRC/distro/$_system_name_lowercase || {
	echo "Your OS is not registered yet, please create $LKP_SRC/distro/$_system_name_lowercase first"
	exit 1
}

. $LKP_SRC/distro/$_system_name_lowercase || exit

if [ "$_system_arch" = x86_64 ]; then
	file=distro/package-list/$_system_name_lowercase@$_system_version
else
	file=distro/package-list/$_system_name_lowercase@$_system_version:$_system_arch
fi

cd $LKP_SRC

if [ -s "$file" -a "$1" != '--force' ]; then
	echo "$0: found existing $file"
	exit 0
fi

ospkg_update
ospkg_list > $file
echo git add $file
echo git commit $file -m \'"distro/packages: add $(basename $file)"\'
