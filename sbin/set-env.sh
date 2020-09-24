#!/bin/sh

. lib/env.sh

write_shellrc()
{
	echo "export LKP_SRC=$PWD" >> $(shell_profile)
	echo "export PATH=\$PATH:$PWD/sbin:$PWD/bin" >> $(shell_profile)
}

write_host()
{
	if is_system "Linux"; then
             nr_cpu=$(nproc)
             memory_total=$(cat /proc/meminfo |grep MemTotal | awk '{print $2}')
        else
             nr_cpu=$(sysctl -n hw.logicalcpu)
             memory_total=$(top -l 1 | grep MemRegions | awk '{print $2}')
        fi
        memory_new=$(awk 'BEGIN{printf "%0.2f", '$memory_total'/1024/1024}')
        memory=$(echo $memory_new | awk '{print int($0)+1}')G

	cat > hosts/$(hostname) <<-EOF
	nr_cpu: $nr_cpu
	memory: $memory
	hdd_partitions:
	ssd_partitions:
	EOF
}

write_shellrc
write_host
