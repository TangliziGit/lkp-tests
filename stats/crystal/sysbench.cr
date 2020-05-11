#!/usr/bin/env crystal


# sysbench 1.0.12 (using bundled LuaJIT 2.1.0-beta2)
# Running the test with following options:
# Number of threads: 1
# Initializing random number generator from current time
# Running memory speed test with the following options:
#   block size: 1KiB
#   total size: 1024MiB
#   operation: write
#   scope: global
# Initializing worker threads...
# Threads started!
# Total operations: 1048576 (3875949.22 per second)
# 1024.00 MiB transferred (3785.11 MiB/sec)
# General statistics:
#     total time:                          0.2671s
#     total number of events:              1048576
# Latency (ms):
#          min:                                  0.00
#          avg:                                  0.00
#          max:                                  0.01
#          95th percentile:                      0.00
#          sum:                                121.17
# Threads fairness:
#     events (avg/stddev):           1048576.0000/0.00
#     execution time (avg/stddev):   0.1212/0.00

$results_total = {}
$results_avg = {}
$results_min = {}
$results_max = {}

def add_result(results, key, val)
  results[key] ||= []
  results[key] << val
end

$stdin.each_line do |line|
  case line
  when /Total operations:\s+\d+\s+\(([0-9.]+)\s+.+\)/
    add_result($results_total, "throughput_ops/s", $1.to_f)
  when /.+\s+transferred\s+\(([0-9.]+)\s+.+\)/
    add_result($results_total, "throughput_MB/s", $1.to_f)
  when /total number of events:\s+(\d+)/
    add_result($results_total, "workload", $1.to_f)
  when /events\/s \(eps\):\s+([0-9.]+)/
    add_result($results_avg, "throughput_events/s", $1.to_f)
  when /time elapsed:\s+([0-9.]+)/
    add_result($results_avg, "throughput_time", $1.to_f)
  when /min:\s+([0-9.]+)/
    add_result($results_min, "latency_ms.min", $1.to_f)
  when /avg:\s+([0-9.]+)/
    add_result($results_avg, "latency_ms.avg", $1.to_f)
  when /max:\s+([0-9.]+)/
    add_result($results_max, "latency_ms.max", $1.to_f)
  when /95th percentile:\s+([0-9.]+)/
    add_result($results_avg, "latency_ms.95th", $1.to_f)
  when /events\s+\(avg\/stddev\):\s+([0-9.]+)\/([0-9.]+)/
    add_result($results_avg, "events/thread.avg", $1.to_f)
    add_result($results_avg, "events/thread.stddev", $2.to_f)
  when /execution time.+:\s+([0-9.]+)\/([0-9.]+)/
    add_result($results_avg, "runtime/thread.avg", $1.to_f)
    add_result($results_avg, "runtime/thread.stddev", $2.to_f)
  end
end

$results_total.each do |key, vals|
  puts "#{key}: #{vals.inject(0.0, :+)}"
end

$results_avg.each do |key, vals|
  puts "#{key}: #{vals.inject(0.0, :+) / vals.size}"
end

$results_min.each do |key, vals|
  puts "#{key}: #{vals.min}"
end

$results_max.each do |key, vals|
  puts "#{key}: #{vals.max}"
end
