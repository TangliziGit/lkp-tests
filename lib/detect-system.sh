#!/bin/sh

# This script is simplifed from detect_system from rvm, and to make it work with /bin/sh:
# https://github.com/wayneeseguin/rvm/blob/master/scripts/functions/detect_system
# ----
#Copyright (c) 2009-2011 Wayne E. Seguin
#Copyright (c) 2011-2015 Michal Papis
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

[ -n "$LKP_SRC" ] || LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))
. $LKP_SRC/lib/env.sh

safe_grep()
{
	GREP_OPTIONS="" command grep "$@"
}

parse_executable_arch()
{
	case "$1" in
		*[xX]86-64)
			_system_arch=x86_64;;
		*80[3456]86)
			_system_arch=i386;;
		*AArch64|*aarch64)
			_system_arch=aarch64;;
		*ARM)
			_system_arch=arm;;
		*RISC-V)
			_system_arch=riscv;;
		*)
			_system_arch=unknown
			return 1;;
	esac
	return 0
}

detect_arch_by_readelf()
{
	has_cmd readelf || return

	parse_executable_arch "$(readelf -h $1 | safe_grep -m1 '  Machine:')"
}

detect_arch_by_file()
{
	has_cmd file || return

	parse_executable_arch "$(file -b $1 | cut -f2 -d,)"
}

detect_executable_arch()
{
	local executable
	for executable
	do
		[ -L $executable ] && continue
		[ -x $executable ] || continue
		detect_arch_by_readelf $executable && return
		detect_arch_by_file $executable && return
	done

	[ "$_system_arch" != "unknown"  ]
}

detect_system_arch()
{
	local rootfs=${1:-/}

	export _system_arch='unknown'

	detect_executable_arch $rootfs/sbin/init		&& return
	detect_executable_arch $rootfs/lib/systemd/systemd	&& return
	detect_executable_arch $rootfs/bin/sh		&& return
	detect_executable_arch $rootfs/bin/bash		&& return
	detect_executable_arch $rootfs/bin/dash		&& return
	detect_executable_arch $rootfs/sbin/*		&& return
	detect_executable_arch $rootfs/bin/*		&& return
	detect_executable_arch $rootfs/usr/sbin/*		&& return
	detect_executable_arch $rootfs/usr/bin/*		&& return
}

detect_libc_version()
{
	local rootfs=${1:-/}
	local libc_version

	local file
	for file in $rootfs/lib/libc-*.*.so $rootfs/lib/*-linux-gnu/libc-*.*.so
	do
		[ -x "$file" ] || continue
		libc_version=${file#*/libc-}
		libc_version=${libc_version%.so}
		_system_version=libc-$libc_version
		return 0
	done
	return 1
}

detect_system()
{
	local rootfs=${1:-/}

	detect_system_arch $rootfs

	export _system_name="unknown"
	export _system_name_lowercase="unknown"
	export _system_version="unknown"

	if
		[ -f ${rootfs}/etc/lsb-release ] &&
			safe_grep "DISTRIB_ID=Ubuntu"    ${rootfs}/etc/lsb-release >/dev/null
	then
		_system_name="Ubuntu"
		_system_version="$(awk -F'=' '$1=="DISTRIB_RELEASE"{print $2}' ${rootfs}/etc/lsb-release | head -n 1)"
	elif
		[ -f ${rootfs}/etc/lsb-release ] &&
			safe_grep "DISTRIB_ID=LinuxMint" ${rootfs}/etc/lsb-release >/dev/null
	then
		_system_name="Mint"
		_system_version="$(awk -F'=' '$1=="DISTRIB_RELEASE"{print $2}' ${rootfs}/etc/lsb-release | head -n 1)"
	elif
		[ -f ${rootfs}/etc/altlinux-release ]
	then
		_system_name="ArchLinux"
		detect_libc_version $rootfs
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep 'ID="opensuse-leap"' ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="OpenSuSE-LEAP"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"");print $2}' ${rootfs}/etc/os-release | head -n 1)" #'
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=opensuse" ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="OpenSuSE"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"");print $2}' ${rootfs}/etc/os-release | head -n 1)" #'
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep 'ID="sles"' ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="SLES"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"");print $2}' ${rootfs}/etc/os-release | head -n 1)" #'
	elif
		[ -f ${rootfs}/etc/SuSE-release ]
	then
		_system_name="SuSE"
		_system_version="$(
		\command \awk -F'=' '{gsub(/ /,"")} $1~/VERSION/ {version=$2} $1~/PATCHLEVEL/ {patch=$2} END {print version"."patch}' < ${rootfs}/etc/SuSE-release
		)"
	elif
		[ -f ${rootfs}/etc/gentoo-release ]
	then
		_system_name="Gentoo"
		_system_version="base-$(\command \cat ${rootfs}/etc/gentoo-release | \command \awk 'NR==1 {print $NF}' | \command \awk -F. '{print $1"."$2}' | head -n 1)"
	elif
		[ -f ${rootfs}/etc/arch-release ]
	then
		_system_name="ArchLinux"
		detect_libc_version $rootfs
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=Exaleap-riscv-linux" ${rootfs}/etc/os-release >/dev/null
	then
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{print $2}'  ${rootfs}/etc/os-release | head -n 1)"
		_system_name="Exaleap-riscv-linux"
	elif
		[ -f ${rootfs}/etc/fedora-release ]
	then
		_system_name="Fedora"
		_system_version="$(safe_grep -Eo '[0-9]+' ${rootfs}/etc/fedora-release | head -n 1)"
	elif
		[ -f ${rootfs}/etc/oracle-release ]
	then
		_system_name="Oracle"
		_system_version="$(safe_grep -Eo '[0-9\.]+' ${rootfs}/etc/oracle-release  | \command \awk -F. '{print $1}' | head -n 1)"
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=\"eywa\"" ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="Eywa"
		_system_version="$(safe_grep 'VERSION_ID=' ${rootfs}/etc/os-release | cut -d '=' -f 2)"
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=\"openEuler\"" ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="openEuler"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"",$2);print $2}' ${rootfs}/etc/os-release)"
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=\"anolis\"" ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="anolis"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"",$2);print $2}' ${rootfs}/etc/os-release)"
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "^ID=\"uos\"" ${rootfs}/etc/os-release >/dev/null
	then
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"",$2);print $2}' ${rootfs}/etc/os-release)"
		if safe_grep -q '^PRETTY_NAME=.*Desktop' ${rootfs}/etc/os-release; then
			_system_name=uos-deb
		elif safe_grep -q '^VERSION_CODENAME="kongzi"' ${rootfs}/etc/os-release; then
			_system_name=uos-rpm-a
		else
			_system_name=uos-rpm-e
		fi
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=\"rocky\"" ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="rocky"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"",$2);print $2}' ${rootfs}/etc/os-release)"
	elif
		[ -f ${rootfs}/etc/redhat-release ] && [ ! -f ${rootfs}/etc/oracle-release ]
	then
		_system_name="$(
		safe_grep -Eo 'CentOS|ClearOS|Mageia|PCLinuxOS|Scientific|ROSA Desktop|OpenMandriva' ${rootfs}/etc/redhat-release 2>/dev/null | \command \head -n 1 | \command \sed "s/ //"
		)"
		_system_name="${_system_name:-RedHat}"
		_system_version="$(safe_grep -Eo '[0-9\.]+' ${rootfs}/etc/redhat-release  | \command \awk -F. 'NR==1{print $1}' | head -n 1)"
	elif
		[ -f ${rootfs}/etc/centos-release ]
	then
		_system_name="CentOS"
		_system_version="$(safe_grep -Eo '[0-9\.]+' ${rootfs}/etc/centos-release  | \command \awk -F. '{print $1}' | head -n 1)"
	elif
		[ -f ${rootfs}/etc/debian_version ]
	then
		_system_name="Debian"
		_system_version="$(\command \cat ${rootfs}/etc/debian_version | \command \awk -F. '{print $1}' | cut -f2 -d/ | head -n 1)"
	elif
		[ -f ${rootfs}/etc/os-release ] &&
			safe_grep "ID=debian" ${rootfs}/etc/os-release >/dev/null
	then
		_system_name="Debian"
		_system_version="$(awk -F'=' '$1=="VERSION_ID"{gsub(/"/,"");print $2}' ${rootfs}/etc/os-release | \command \awk -F. '{print $1}' | head -n 1)" #'
	elif
		[ -f ${rootfs}/etc/os-release ]
	then
		_system_name="$(safe_grep '^ID=' ${rootfs}/etc/os-release | cut -d '=' -f 2 | tr -d '"')"
		_system_version="$(safe_grep '^VERSION_ID=' ${rootfs}/etc/os-release | cut -d '=' -f 2 | tr -d '"')"
	elif
		has_cmd hostnamectl
	then
		_system_name=$(hostnamectl status | safe_grep 'Operating System' | awk '{print $3}')
		[ "$_system_name" = "Clear" ] && _system_version=$(swupd info | head -1 | awk '{print $3}')
	else
		detect_libc_version $rootfs
	fi
	_system_name=$(printf '%s\n' "$_system_name" | sed 's/[ \/]/_/g')  #"${_system_name//[ \/]/_}"

	# shellcheck disable=SC1012 # \t is just literal 't' here. For tab, use "$(printf '\t')" instead
	_system_name_lowercase="$(echo ${_system_name} | \command \tr '[A-Z]' '[a-z]')"
	_system_version=$(printf '%s\n' "$_system_version" | sed 's/[ \/]/_/g')  #${_system_version//[ \/]/_}"
}

get_system_arch()
{
	if [[ -n "$1" ]]; then
		# this may fail if file/readelf is not installed
		detect_system_arch $1
	else
		_system_arch=$(command arch)
	fi
	echo $_system_arch
}
