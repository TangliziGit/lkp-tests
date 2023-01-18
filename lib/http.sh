#!/bin/sh

. $LKP_SRC/lib/env.sh

escape_cgi_param()
{
	local uri="$1"
	# uri=${uri//%/%25} # must be the first one
	# uri=${uri//+/%2B}
	# uri=${uri//&/%26}
	# uri=${uri//\?/%3F}
	# uri=${uri//@/%40}
	# uri=${uri//:/%3A}
	# uri=${uri//;/%3D}
	echo "$uri" |
	sed -r	-e 's/%/%25/g' \
		-e 's/\+/%2B/g' \
		-e 's/&/%26/g' \
		-e 's/#/%23/g' \
		-e 's/\?/%3F/g' \
		-e 's/ /%20/g'
}

reset_broken_ipmi()
{
	[ -f "$RESULT_MNT/.IPMI-reset/$HOSTNAME" ] || return
	[ -x '/usr/sbin/bmc-device' ] || return

	bmc-device --cold-reset
	mv -f $RESULT_MNT/.IPMI-reset/$HOSTNAME $RESULT_MNT/.IPMI-reset/.$HOSTNAME
}

#
# job handling at client is finished, tell server to do some
# post handling, such as delete the job file, process all
# monitors data, and so on
#
trigger_post_process()
{
	local query_str=job_file=$(escape_cgi_param "$job")
	query_str="${query_str}&$(escape_cgi_param "job_id=$id")"

	http_get_cgi "cgi-bin/lkp-post-run?$query_str"

	reset_broken_ipmi
}

jobfile_append_var()
{
	[ -n "$job" ] || return

	# input example: "var1=value1" "var2=value2 value_with_space" ....
	[ -z "$*" ] && LOG_ERROR "no paramter specified at $FUNCTION" && return

	local query_str=job_file=$(escape_cgi_param "$job")
	query_str="${query_str}&$(escape_cgi_param "job_id=$id")"
	for assignment in "$@"; do
		query_str="${query_str}&$(escape_cgi_param "$assignment")"
	done

	http_get_cgi "cgi-bin/lkp-jobfile-append-var?$query_str"
}

plan_set_kernel()
{
	# input example: "/xxx/yyy/bzImage-xxx"
	query_str="$(escape_cgi_param "plan_id=$plan")&$(escape_cgi_param "path=$1")"
	http_get_cgi "cgi-bin/lkp-plan-kernel?$query_str"
}

plan_append_packages()
{
	# input example: "/xxx/yyy/zzz.cgz"
	query_str="$(escape_cgi_param "plan_id=$plan")&$(escape_cgi_param "path=$1")"
	http_get_cgi "cgi-bin/lkp-plan-append-packages?$query_str"
}

exit_with_job_state()
{
	local exit_code=$?
	set_job_state "$1"
	exit $exit_code
}

set_job_state()
{
	[ -n "$1" ] || return
	jobfile_append_var "job_state=$1"
}

set_job_stage()
{
	[ -n "$1" ] || return

	url="cgi-bin/set-job-stage?job_stage=$1&job_id=$id"
	[ -n "$2" ] && url="${url}&timeout=$2"

	http_get_cgi $url
}

set_tbox_wtmp()
{
	local tbox_state="$1"
	[ -n "$tbox_state" ] || return

	http_get_cgi "cgi-bin/lkp-wtmp?tbox_name=$HOSTNAME&tbox_state=$tbox_state&mac=$PUB_MAC&ip=$PUB_IP&job_id=$id"
}

report_ssh_port()
{
	local ssh_port="$1"
	[ -n "$ssh_port" ] || return

	http_get_cgi "cgi-bin/report_ssh_port?tbox_name=$HOSTNAME&job_id=$id&ssh_port=$ssh_port"
}

report_ssh_info()
{
	local ssh_port="$1"
	local message="$2"

	content='{"tbox_name": "'$HOSTNAME'", "job_id": "'$id'", "ssh_port": "'$ssh_port'", "message": "'$message'"}'
	curl -XPOST "http://$LKP_SERVER:${LKP_CGI_PORT:-3000}/~lkp/cgi-bin/report_ssh_info" -d "$content"
}

####################################################

http_escape_request()
{
	local path="$(escape_cgi_param "$1")"
	shift
	http_do_request "$path" "$@"
}

http_do_request()
{
	local path="$1"
	shift

	[ -n "$NO_NETWORK$VM_VIRTFS" -o -z "$LKP_SERVER$HTTP_PREFIX" ] && {
		echo skip http request: $path "$@"
		return
	}

	([ "${path#http://}" != "$path" ] || [ "${path#https://}" != "$path" ]) && {
		echo \
		$http_client_cmd "$path" "$@"
		$http_client_cmd "$path" "$@"
		return
	}

	# $ busybox wget http://XXX:/
	# wget: bad port spec 'XXX:'
	local http_prefix

	if [ -n "$HTTP_PREFIX" ]; then
		http_prefix="$HTTP_PREFIX"
	else
		http_prefix="http://$LKP_SERVER:${LKP_CGI_PORT:-3000}/~$LKP_USER"
	fi

	echo \
	$http_client_cmd "$http_prefix/$path" "$@"
	$http_client_cmd "$http_prefix/$path" "$@"
}

http_setup_client()
{
	[ -n "$http_client_cmd" ] && return

	. $LKP_SRC/lib/wget.sh	&& return
	. $LKP_SRC/lib/curl.sh	&& return
	. $LKP_SRC/lib/wget_busybox.sh	&& return

	echo "Cannot find wget/curl." >&2
	return 1
}

check_create_base_dir()
{
	[ -z "$1" ] && return

	local path="$(dirname "$1")"
	[ -d "$path" ] || mkdir -p "$path"
}

http_get_newer_can_skip()
{
	[ -s "$2" ] || return

	# versioned files can be safely cached without checking timestamp
	[ "${1%-????-??-??.cgz}" != "$1" ] && return
	[ "${1%_????-??-??.cgz}" != "$1" ] && return
}

http_get_file()
{
	http_setup_client && http_get_file "$@"
}

http_get_directory()
{
	http_setup_client && http_get_directory "$@"
}

http_get_newer()
{
	http_setup_client && http_get_newer "$@"
}

http_get_cgi()
{
	http_setup_client && http_get_cgi "$@"
}
