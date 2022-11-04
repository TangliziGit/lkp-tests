#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
PROJECT_DIR=$(dirname $SCRIPT_DIR)

. $PROJECT_DIR/lib/env.sh

[ $(id -u) != 0 ] && SUDO=sudo

# choose install function base on common Package Manager
linux_dep()
{
	get_package_manager

	local common_packages="ruby rubygems make gcc diffutils util-linux lftp hostname sudo gzip git"

	case "$installer" in
	apt-get)
		export DEBIAN_FRONTEND=noninteractive
		$SUDO "$installer" update
		$SUDO "$installer" install -yqm $common_packages ruby-dev libssl-dev g++ uuid-runtime
		;;
	dnf|yum)
		$SUDO "$installer" install -y --skip-broken $common_packages gcc-c++ ruby-devel
		;;
	pacman)
		$SUDO "$installer" -Sy --noconfirm --needed $common_packages
		;;
	zypper)
		$SUDO "$installer" install -y $common_packages gcc-c++ ruby-devel
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
	has_cmd "apt-get" && installer="apt-get" && return
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
}

set_env()
{
	write_host
	write_shell_profile "\
export LKP_SRC=$PWD
export CCI_REPOS=$(dirname $PWD)
export PATH=\$PATH:\$LKP_SRC/sbin:\$LKP_SRC/bin"
}

run
set_env
