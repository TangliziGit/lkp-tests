#!/bin/bash

# Usage:
#
# $0 [jobs...]

nr_run=3

jobs="$*"
[ -n "$jobs" ] ||
jobs="
fio-basic-benchmark.yaml
iozone-bs.yaml
libmicro.yaml
lmbench-performance.yaml
netperf-send_size.yaml
stream-onejob.yaml
unixbench-tuning.yaml
"

[ $(id -u) = 0 ] || {
	echo "Please run as root"
	exit
}

[[ -n "$LKP_SRC" ]] || LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))

. $LKP_SRC/lib/lkp_path.sh

cd $LKP_SRC || exit
sbin/install-dependencies.sh

check_install_job()
{
	find_job "$1" || return

	local atomic_jobs=$(lkp split --any -o /tmp $job_file | cut -f3 -d' ')
	local atomic_job
	local i=0
	local j
	for atomic_job in $atomic_jobs
	do
		[ $i = 0 ] &&
		lkp install $atomic_job
		i=1

		for j in $(seq $nr_run)
		do
			lkp run $atomic_job
		done
	done
}

for job in $jobs
do
	check_install_job "$job"
done
