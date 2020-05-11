#!/usr/bin/env crystal

# The result line in input is in format:
# [time] $type-torture:--- End of test: $result: arg=value arg=value ...
#
# $type and $result are essential for a test.
# And for now, we care about the value of arg onoff_interval
# which represents doing cpuhotplugs or not.
#
# Now, there are three results here, 'RCU_HOTPLUG' and
# 'FAILURE' both represent the test failed.

# Input example:
# [  317.442785] rcu-torture: Free-Block Circulation:  17263 17263 17262 17261 17259 17258 17256 17253 17252 17251 0
# [  317.445385] rcu-torture:--- End of test: RCU_HOTPLUG: nreaders=1 nfakewriters=4 stat_interval=60 verbose=1 test_no_idle_hz=1 shuffle_interval=3 stutter=5 irqreader=1
# fqs_dura tion=0 fqs_holdoff=0 fqs_stutter=3 test_boost=1/0 test_boost_interval=7 test_boost_duration=4 shutdown_secs=0 stall_cpu=0 stall_cpu_holdoff=10 stall_cpu_irqsoff=0
# n_barrier_cbs=0 onoff_interval=0 onoff_holdoff=0
#

result = "unknown"
type = "unknown"
cpuhotplug = false

while (line = STDIN.gets)
  case line
  when /^\[.*\] ([A-Za-z_]+)-torture.*End of test: (.*):.*onoff_interval=([0-9]+).*/
    type = $1
    result = $2.downcase
    cpuhotplug = true unless $3 == "0"
    break
  end
end

stat = (cpuhotplug ? "cpuhotplug-" : "") + type + "." + result
puts "#{stat}: 1"
