#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
export LKP_SRC=$(dirname $SCRIPT_DIR)

. $LKP_SRC/lib/env.sh
. $LKP_SRC/distro/common

# choose install function base on common Package Manager
linux_dep()
{
	get_package_manager
	source $LKP_SRC/distro/package-manager/$installer

	local common_packages="ruby rubygems make gcc diffutils util-linux lftp hostname sudo gzip git"

	case "$installer" in
	apt)
		ospkg_update_install $common_packages ruby-dev libssl-dev g++ uuid-runtime
		;;
	dnf|yum)
		ospkg_update_install $common_packages gcc-c++ ruby-devel
		;;
	pacman)
		ospkg_update_install $common_packages
		;;
	zypper)
		ospkg_update_install $common_packages gcc-c++ ruby-devel
		;;
	*)
		echo "Unknown Package Manager! please install dependencies manually." && exit 1
		;;
	esac
}

get_package_manager()
{
	has_cmd "yum" && installer="yum"
	has_cmd "dnf" && installer="dnf" && return
	has_cmd "apt" && installer="apt" && return
	has_cmd "pacman" && installer="pacman" && return
	has_cmd "zypper" && installer="zypper" && return
}

mac_dep()
{
	brew install ruby
	write_shell_profile "export PATH=/usr/local/opt/ruby/bin:$PATH"
}

install_gem_pkg()
{
	gem sources -r https://rubygems.org/ -a https://gems.ruby-china.com/
	$SUDO gem install -f git activesupport:6.1.4.4 rest-client faye-websocket md5sum base64
}

run()
{
	if is_system "Linux"; then
		linux_dep
	elif is_system "Darwin"; then
		mac_dep
	else
		echo "$DISTRO not supported!" && exit 1
	fi

	install_gem_pkg

	make -C bin/event wakeup

	$SUDO $LKP_SRC/bin/lkp install
}

set_env()
{
	write_host
	write_shell_profile "\
export LKP_SRC=$PWD
export CCI_REPOS=$(dirname $PWD)
export PATH=\$PATH:\$LKP_SRC/sbin:\$LKP_SRC/bin"
}

symlink_lkp()
{
	if [[ $(id -u) = 0 && "${LKP_SRC}" != "${LKP_SRC#/root}" ]]; then
		local target_dir_bin=/usr/local/bin	# global install
	else
		local target_dir_bin=${HOME}/bin
	fi

	mkdir -p $target_dir_bin
	ln -sf $LKP_SRC/bin/lkp $target_dir_bin/lkp
}

run
set_env
symlink_lkp
