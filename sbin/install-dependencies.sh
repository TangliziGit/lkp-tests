#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))
PROJECT_DIR=$(dirname $SCRIPT_DIR)

. $PROJECT_DIR/lib/env.sh

# choose install function base on common Package Manager
linux_dep()
{
	get_package_manager

	case "$installer" in
	apt-get)
		export DEBIAN_FRONTEND=noninteractive
		sudo "$installer" install -yqm ruby-dev libssl-dev gcc g++ uuid-runtime
		;;
	dnf|yum)
		sudo "$installer" install -y --skip-broken ruby rubygems gcc gcc-c++ make ruby-devel git lftp util-linux
		;;
	pacman)
		sudo "$installer" -Sy --noconfirm --needed ruby rubygems gcc make git lftp util-linux
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
}

mac_dep()
{
	brew install ruby
	write_shell_profile "export PATH=/usr/local/opt/ruby/bin:$PATH"
}

install_gem_pkg()
{
	gem sources -r https://rubygems.org/ -a https://gems.ruby-china.com/
	sudo gem install -f git activesupport rest-client faye-websocket
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
	write_shell_profile "export LKP_SRC=$PWD"
	write_shell_profile "export PATH=\$PATH:\$LKP_SRC/sbin:\$LKP_SRC/bin"
}

set_env
run
