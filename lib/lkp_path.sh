#!/bin/bash

lkp_src()
{
	local lkp_src="$LKP_SRC"

	local str
	for str in "$@"
	do
		lkp_src="$lkp_src/$str"
	done

	echo "$lkp_src"
}

find_job()
{
	local job="$1"

	if [ -f $job ]; then
		job_file=$job
		return
	fi

	job_file=($LKP_SRC/programs/*/jobs/$job)
	[ -f "$job_file" ] && return

	job_file=($LKP_SRC/jobs/$job)
	[ -f "$job_file" ] && return

	job_file=($LKP_SRC/jobs/*/$job)
	[ -f "$job_file" ] && return

	echo "Failed to find job $job"
	return 1
}
