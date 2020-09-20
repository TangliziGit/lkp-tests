#!/bin/sh

. $LKP_SRC/lib/env.sh

has_rsync_server()
{
	[ -n "$RSYNC_SERVER" ] && return
	[ -e $LKP_SRC/etc/trustable-lkp-server ] || return

	echo "$LKP_SERVER" | grep -q -E -f $LKP_SRC/etc/trustable-lkp-server
}

upload_files_rsync()
{
	[ -n "$RSYNC_SERVER" ] || local RSYNC_SERVER=$LKP_SERVER

	[ -n "$target_directory" ] && {

		local current_dir=$(pwd)
		local tmpdir=$(mktemp -d)
		cd "$tmpdir"
		mkdir -p ${target_directory}

		rsync -a --no-owner --no-group \
			--chmod=D775,F664 \
			--ignore-missing-args \
			--min-size=1 \
			${target_directory%%/*} rsync://$RSYNC_SERVER$JOB_RESULT_ROOT/

		local JOB_RESULT_ROOT=$JOB_RESULT_ROOT/$target_directory

		cd $current_dir
		rm -fr "$tmpdir"
	}

	rsync -a --no-owner --no-group \
		--chmod=D775,F664 \
		--ignore-missing-args \
		--min-size=1 \
		"$@" rsync://$RSYNC_SERVER$JOB_RESULT_ROOT/
}

upload_files_lftp()
{
	local file
	local dest_file
	local ret=0
	local LFTP_TIMEOUT='set net:timeout 2; set net:reconnect-interval-base 2; set net:max-retries 2;'
	local UPLOAD_HOST="http://$LKP_SERVER:${RESULT_WEBDAV_PORT:-3080}"

	[ -n "$target_directory" ] && {
		local JOB_RESULT_ROOT=$JOB_RESULT_ROOT/$target_directory
		lftp -c "$LFTP_TIMEOUT; open '$UPLOAD_HOST'; mkdir -p '$JOB_RESULT_ROOT'"
	}

	for file
	do
		if [ -d "$file" ]; then
			[ "$(ls -A $file)" ] && lftp -c "$LFTP_TIMEOUT; open '$UPLOAD_HOST'; mirror -R '$file' '$JOB_RESULT_ROOT/'" || ret=$?
		else
			[ -s "$file" ] || continue
			dest_file=$JOB_RESULT_ROOT/$(basename $file)

			lftp -c "$LFTP_TIMEOUT; open '$UPLOAD_HOST'; put -c '$file' -o '$dest_file'" || ret=$?
		fi
	done

	return $ret
}

upload_one_curl()
{
	local src=$1
	local dest=$2
	local http_url="http://$LKP_SERVER:${RESULT_WEBDAV_PORT:-3080}$dest"

	if [ -d "$src" ]; then
		(
			cd $(dirname "$1")
			dir=$(basename "$1")
			if [ -n "$access_key" ]; then
				find "$dir" -type d -exec curl -sSf -X MKCOL "$http_url/{}" --cookie "ACCESSKEY=$access_key" \;
				find "$dir" -type f -size +0 -exec curl -sSf -T '{}' "$http_url/{}" --cookie "ACCESSKEY=$access_key" \;
			else
				find "$dir" -type d -exec curl -sSf -X MKCOL "$http_url/{}" \;
				find "$dir" -type f -size +0 -exec curl -sSf -T '{}' "$http_url/{}" \;
			fi
		)
	else
		[ -s "$src" ] || return
		if [ -n "$$access_key" ]; then
			curl -sSf -T "$src" $http_url/ --cookie "ACCESSKEY=$access_key"
		else
			curl -sSf -T "$src" $http_url/
		fi
	fi
}

upload_files_curl()
{
	local file
	local ret=0
	local http_host="http://$LKP_SERVER:${RESULT_WEBDAV_PORT:-3080}"

	# "%" character as special character not be allowed in the URL when use curl command to transfer files, details can refer to below:
	# https://www.werockyourweb.com/url-escape-characters/
	local job_result_root=$(echo $JOB_RESULT_ROOT | sed 's/%/%25/g')

	[ -n "$target_directory" ] && {
		local dir
		for dir in $(echo $target_directory | tr '/' ' ')
		do
			job_result_root=$job_result_root/$dir/
			if [ -n "$$access_key" ]; then
				curl -sSf -X MKCOL "$http_host$job_result_root" --cookie "ACCESSKEY=$access_key"  >/dev/null
			else
				curl -sSf -X MKCOL "$http_host$job_result_root"  >/dev/null
			fi
		done
	}

	for file
	do
		upload_one_curl "$file" "$job_result_root" >/dev/null || ret=$?
	done

	return $ret
}

upload_files_copy()
{
	local RESULT_ROOT="$RESULT_ROOT/$target_directory"


	mkdir -p $RESULT_ROOT

	if [ "$LKP_LOCAL_RUN" != "1" ]; then
		[ -n "$target_directory" ] && {
			chown -R lkp.lkp $RESULT_ROOT
			chmod -R g+w $RESULT_ROOT
		}

		chown -R lkp.lkp "$@"
		chmod -R ug+w "$@"
	fi

	local copy="cp -a"
	local file
	local ret=0

	for file
	do
		[ -s "$file" ] || continue
		[ "$LKP_LOCAL_RUN" = "1" ] && chmod ug+w "$file"
		$copy "$file" $RESULT_ROOT/ || {
			ls -l "$@" $RESULT_ROOT 2>&1
			ret=$?
		}
	done

	return $ret
}

upload_files()
{
	if [ "$1" = "-t" ]; then
		local target_directory="$2"

		shift 2
	fi

	[ $# -ne 0 ] || return

	# NO_NETWORK is empty: means network is avaliable
	# VM_VIRTFS is empty: means it's not a 9p fs(used by lkp-qemu)
	if [ -z "$NO_NETWORK$VM_VIRTFS" ]; then
		[ -z "$JOB_RESULT_ROOT" -a "$LKP_LOCAL_RUN" = "1" ] && { # bin/run-local.sh
			upload_files_copy "$@"
			return
		}
		if has_cmd rsync && has_rsync_server && [ -z "$access_key" ]; then
			upload_files_rsync "$@"
			return
		fi

		if has_cmd lftp && [ -z "$access_key" ]; then
			upload_files_lftp "$@"
			return
		fi

		if has_cmd curl; then
			upload_files_curl "$@"
			return
		fi

		if [ -z "$NO_NETWORK" ]; then
			# NFS is the last resort -- it seems unreliable, either some
			# content has not reached NFS server during post processing, or
			# some files occasionally contain some few '\0' bytes.
			upload_files_copy "$@"
			return
		fi
	else
		# 9pfs, copy directly
		upload_files_copy "$@"
		return
	fi
}
