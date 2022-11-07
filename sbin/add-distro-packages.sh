#!/bin/bash
# Usage:
# $ docker run -ti -v /c/lkp-tests:/c/lkp-tests ubuntu:22.04 bash
# root@4f87b1825220:/# cd /c/lkp-tests/
# root@4f87b1825220:/c/lkp-tests# sbin/add-distro-packages.sh

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
export LKP_SRC=$(dirname $SCRIPT_DIR)

. $LKP_SRC/lib/detect-system.sh
detect_system
arch=$(arch)

test -e $LKP_SRC/distro/$_system_name_lowercase || {
	echo "Your OS is not registered yet, please create $LKP_SRC/distro/$_system_name_lowercase first"
	exit 1
}

. $LKP_SRC/distro/$_system_name_lowercase || exit

if [ $arch = x86_64 ]; then
	file=distro/package-list/$_system_name_lowercase@$_system_version
else
	file=distro/package-list/$_system_name_lowercase@$_system_version:$arch
fi

cd $LKP_SRC

ospkg_update
ospkg_list > $file
echo git add $file
echo git commit $file -m \'"distro/packages: add $(basename $file)"\'
