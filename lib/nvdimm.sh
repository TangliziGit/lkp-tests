# nvdimm functions

configure_namespace()
{
	ns=$1
	bns=$(basename $ns)
	rmode=$(cat "$ns/mode")
	rsize=$(cat "$ns/size")
	[ "$rsize" -eq 0 ] && return
	rmode=$(echo -n $rmode)
	mode=$(echo -n $mode)
	[ "$rmode" = "$mode" ] && return
	/lkp/benchmarks/bin/ndctl create-namespace --reconfig=$bns \
					--force --mode="$mode" || exit 1
}

configure_nvdimm()
{
	if [ -n "$ns_id" ]; then
		ns=/sys/bus/nd/devices/namespace$ns_id.0
		configure_namespace $ns
	else
		for ns in $(ls -d /sys/bus/nd/devices/namespace*); do
			configure_namespace $ns
		done
	fi
}
