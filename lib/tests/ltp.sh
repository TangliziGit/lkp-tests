#!/bin/bash

split_syscalls()
{
	local cmdfile="runtest/syscalls"
	[ -f "$cmdfile" ] || return 0
	# syscalls_partN file exists, abort splitting
	[ -f "${cmdfile}_part1" ] && return 0

	local timer_tests=$(grep -lr "sample = sample_fn" ./)
	local timer_file="runtest/syscalls_timer"
	for timer_test in $timer_tests; do
		timer_test=${timer_test##*/}
		timer_test=${timer_test%%.*}
		grep "^$timer_test" "$cmdfile" >> "$timer_file"
	done

	i=1
	n=1
	test_num=""
	grep -v -f "$timer_file" "$cmdfile" | sed -e '/^$/ d' -e 's/^[ ,\t]*//' -e '/^#/ d' | while read line
	do
		if [ "$i" = "2" ]; then
			test_num=250
		elif [ "$i" = "3" ]; then
			test_num=50
		else
			test_num=300
		fi

		if [ $n -gt $test_num ];then
			i=$(($i+1))
			n=1
		fi

		if [[ "$line" =~ "tgkill" ]];then
			echo "$line" >> "runtest/syscalls_tgkill"
		else
			echo "$line" >> "runtest/syscalls_part${i}"
			n=$(($n+1))
		fi
	done

	echo "Splitting syscalls to syscalls_part1, ..., syscalls_part$i"
}

rearrange_dio()
{
	[ -f "dio" ] || return

	sed -e "s/^#.*//g" dio | awk '{if (length !=0) print $0}' >> diocase || return
	sed -n "1,20p" diocase >> dio-00 || return
	sed -n "21,25p" diocase >> dio-01 || return
	sed -n "26,28p" diocase >> dio-02 || return
	sed -n "29,\$p" diocase >> dio-03 || return
	rm diocase || return
}

rearrange_case()
{
	cd ./runtest || return

	# re-arrange the case dio
	rearrange_dio || return

	# re-arrange the case fs_readonly
	[ -f "fs_readonly" ] || return
	split -d -l15 fs_readonly fs_readonly- || return

	# re-arrange the case fs
	sed -e "s/^#.*//g" fs | awk '{if (length !=0) print $0}' > fscase || return
	split -d -l20 fscase fs- || return

	# re-arrange the case crashme
	sed -e "s/^#.*//g" crashme | awk '{if (length !=0) print $0}' > crashmecase || return
	split -d -l2 crashmecase crashme- || return

	# re-arrange the case mm
	grep -e oom -e min_free_kbytes mm > mm-00 || return
	cat mm | grep -v oom | grep -v min_free_kbytes > mm-01 || return

	# re-arrange the case net_stress.appl
	grep "http4" net_stress.appl > net_stress.appl-00 || return
	grep "http6" net_stress.appl > net_stress.appl-01 || return
	grep "ftp4-download" net_stress.appl > net_stress.appl-02 || return
	grep "ftp6-download" net_stress.appl > net_stress.appl-03 || return
	cat net_stress.appl | grep -v "http[4|6]" | grep -v "ftp[4|6]-download" > net_stress.appl-04 || return

	# re-arrange the case syscalls-ipc
	sed -e "s/^#.*//g" syscalls-ipc | awk '{if (length !=0) print $0}' > syscalls-ipc-case || return
	cat syscalls-ipc-case | grep -v "msgstress04" > syscalls-ipc-00
	cat syscalls-ipc-case | grep "msgstress04" > syscalls-ipc-01

	# re-arrange the case scsi_debug.part1
	sed -e "s/^#.*//g" scsi_debug.part1 | awk '{if (length !=0) print $0}' > scsi_debug.part1-case || return
	split -d -l90 scsi_debug.part1-case scsi_debug.part1- || return

	cd ..
}

rebuild()
{
	[ -d "$1" ] || return
	local build_dir=$1
	local current_dir=$(pwd)

	cd $build_dir && {
		make clean || return
		make || return
		cd $current_dir
	}
}

build_ltp()
{
	split_syscalls
	rearrange_case || return
	make autotools
	./configure --prefix=$1
	make || return

	# fix rpc test cases, linking to libtirpc-dev will make the tests failed in debian
	sed -i "s/^LDLIBS/#LDLIBS/" testcases/network/rpc/rpc-tirpc/tests_pack/Makefile.inc || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_createdestroy_svc_destroy || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_createdestroy_svcfd_create || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_regunreg_xprt_register || return
	rebuild testcases/network/rpc/rpc-tirpc/tests_pack/rpc_suite/rpc/rpc_regunreg_xprt_unregister
}

install_ltp()
{
	make install
	cp testcases/commands/tpm-tools/tpmtoken/tpmtoken_import/tpmtoken_import_openssl.cnf $1/testcases/bin/
	cp testcases/commands/tpm-tools/tpmtoken/tpmtoken_protect/tpmtoken_protect_data.txt  $1/testcases/bin/
}

check_ignored_cases()
{
	test=$1
	local ignored_by_lkp=$LKP_SRC/pkg/ltp-addon/ignored_by_lkp
	cp $ignored_by_lkp ./ignored_by_lkp

	# regex match
	for regex in $(cat "$ignored_by_lkp" | grep -v '^#' | grep -w ^${test}:.*:regex$ | awk -F: 'NF == 3 {print $2}')
	do
		echo "# regex: $regex generated" >> ./ignored_by_lkp
		cat runtest/$test | awk '{print $1}' | grep -G "$regex" | awk -v prefix=$test":" '$0=prefix$0' >> ./ignored_by_lkp
	done

	orig_test=$(echo "$test" | sed 's/-[0-9]\{2\}$//')
	for i in $(cat ./ignored_by_lkp | grep -v '^#' | grep -w ^$orig_test | awk -F: 'NF == 2')
	do
		ignore=$(echo $i | awk -F: '{print $2}')
		grep -q "^${ignore}" runtest/${test} || continue
		sed -i "s/^${ignore} /#${ignore} /g" runtest/${test}
		echo "<<<test_start>>>"
		echo "tag=${ignore}"
		echo "${ignore} 0 ignored_by_lkp"
		echo "<<<test_end>>>"
	done
}

workaround_env()
{
	# some LTP sh scripts actually need bash. Fixes
	# > netns_childns.sh: 38: .: cmdlib.sh: not found
	[ "$(cmd_path bash)" = '/bin/bash' ] && [ $(readlink -e /bin/sh) != '/bin/bash' ] &&
	ln -fs bash /bin/sh

	# install mkisofs which is linked to genisoimage
	command -v mkisofs || {
		genisoimage=$(command -v genisoimage)
		if [ -n "$genisoimage" ]; then
			log_cmd ln -sf "$genisoimage" /usr/bin/mkisofs
		else
			echo "can not install mkisofs"
		fi
	}
}

specify_tmpdir()
{
	[ -z "$partitions" ] && return 1
	ltp_partition="${partitions%% *}"
	mount_point=/fs/$(basename $ltp_partition)

	mkdir -p $mount_point/tmpdir || return 1
	tmpdir_opt="-d $mount_point/tmpdir"

	return 0
}

test_setting()
{
	case "$test" in
	cpuhotplug)
		mkdir -p /usr/src/linux/
		;;
	fs_readonly-0*)
		[ -z "$fs" ] && exit
		[ -z "$partitions" ] && exit
		big_dev="${partitions%% *}"
		umount $big_dev
		big_dev_opt="-Z $fs -z $big_dev"
		;;
	fs_ext4)
		[ -z "$partitions" ] && exit
		big_dev="${partitions%% *}"
		big_dev_opt="-z $big_dev"
		# match logic of check_ignored_cases
		sed -i "s/\t/ /g" runtest/fs_ext4
		;;
	mm-00)
		local pid_job="$(cat $TMP/run-job.pid)"
		echo 0 > /proc/$pid_job/oom_score_adj
		;;
	mm-01)
		[ -z "$partitions" ] && exit
		swap_partition="${partitions%% *}"
		mkswap $swap_partition 2>&1 || exit 1
		swapon $swap_partition
		;;
	tpm_tools)
		[ $USER ] || USER=root
		rm -rf /var/lib/opencryptoki/tpm/$USER
		cd tpm-emulater
		find . -maxdepth 1 -type d -name "TPM_Emulator*" -exec rm -rf {} \;
		unzip $(ls TPM_Emulator*.zip | head -1)
		rsync -av $(ls -l . | awk '/^d/ {print $NF}' | head -1)"/" /
		cd ..
		killall tpmd > /dev/null 2>&1
		tpmd -f -d clear > /dev/null 2>&1 &
		killall tcsd > /dev/null 2>&1
		tcsd -e -f > /dev/null 2>&1 &
		sleep 5
		export LTPROOT=${PWD}
		export LTPBIN=$LTPROOT/testcases/bin
		export OWN_PWD="HELLO1"
		export NEW_OWN_PWD="HELLO2"
		export SRK_PWD="HELLO3"
		export NEW_SRK_PWD="HELLO4"
		export P11_SO_PWD="HELLO5"
		export NEW_P11_SO_PWD="HELLO6"
		export P11_USER_PWD="HELLO7"
		export NEW_P11_USER_PWD="HELLO8"
		;;
	ltp-aiodio.part[24]|syscalls_part[14]|dio-0*|io)
		specify_tmpdir || exit
		;;
	syscalls-ipc-01)
		# avoid soft_timeout by reducing the max number of message
		# queues to 10000(default is 32000)
		echo 10000 > /proc/sys/kernel/msgmni
		;;
	syscalls_part2)
		export LTP_TIMEOUT_MUL=5
		specify_tmpdir || exit
		relatime=$(mount | grep /tmp | grep relatime)
		noatime=$(mount | grep /tmp | grep noatime)
		if [ "$relatime" != "" ] || [ "$noatime" != "" ]; then
			mount -o remount,strictatime /tmp
		fi
		;;
	syscalls_part5)
		specify_tmpdir || exit
		echo "#\$SystemLogSocketName /run/systemd/journal/syslog" > /etc/rsyslog.d/listen.conf
		systemctl restart rsyslog || exit
		[ -f /var/log/maillog ] || {
			touch /var/log/maillog && chmod 600 /var/log/maillog
		}
		[ -e /dev/log ] && rm /dev/log
		ln -s /run/systemd/journal/dev-log /dev/log
		;;
	net.ipv6_lib)
		iface=$(ifconfig -s | awk '{print $1}' | grep ^eth | head -1)
		[ -n "$iface" ] && export LHOST_IFACES=$iface
		sed -i "1s/^/::1 ${HOSTNAME}\n/" /etc/hosts
		sed -i "1s/^/127.0.0.1 ${HOSTNAME}\n/" /etc/hosts
		;;
	net.rpc)
		systemctl start openbsd-inetd || exit
		cp netkit-rusers/bin/rup /usr/bin/
		;;
	net_stress.appl-0*)
		[ -d /srv/ftp ] && export FTP_DOWNLOAD_DIR=/srv/ftp
		sed -i '/\/usr\/sbin\/named {/a\\/tmp\/** rw,' /etc/apparmor.d/usr.sbin.named || exit
		systemctl start bind9 || exit
		systemctl list-units | grep -wq apparmor.service && (systemctl reload-or-restart apparmor || exit)
		;;
	scsi_debug.part1-*)
		# fix 'Unable to make dir /test/growfiles/XXX' error
		mkdir -p /test/growfiles
		;;
	esac
}

cleanup_ltp()
{
	[ "$test" = "mm-00" ] && {
		dmesg -C || exit
	}

	[ "$test" = "syscalls_part2" ] && {
		[ "$relatime" != "" ] && mount -o remount,relatime /tmp
		[ "$noatime" != "" ] && mount -o remount,noatime /tmp
	}
}
