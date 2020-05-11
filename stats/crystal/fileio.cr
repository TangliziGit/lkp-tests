#!/usr/bin/env crystal


require "../../lib/string_ext"

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence unless line.valid_encoding?
  case line
  # Throughput:
  #      read:  IOPS=3211265.07 50176.02 MiB/s (52613.37 MB/s)
  #      write: IOPS=0.00 0.00 MiB/s (0.00 MB/s)
  #      fsync: IOPS=0.00
  when /read:  IOPS=([\d.]+) ([\d.]+) MiB\/s \(([\d.]+) MB\/s\)/
    puts "read_operations/s: " + $1
    puts "read_bytes_MiB/s: " + $2
    puts "read_bytes_MB/s: " + $3
  when /write: IOPS=([\d.]+) ([\d.]+) MiB\/s \(([\d.]+) MB\/s\)/
    puts "write_operations/s: " + $1
    puts "write_bytes_MiB/s: " + $2
    puts "write_bytes_MB/s: " + $3
  when /fsync: IOPS=([\d.]+)/
    puts "fsync_operations/s: " + $1
    # Latency (ms):
    #      min:                                  0.00
    #      avg:                                  0.65
    #      max:                                367.57
    #      95th percentile:                      0.86
    #      sum:                            1194054.52
  when /max:\s+([\d.]+)/
    puts "latency_max_ms: " + $1
  when /min:\s+([\d.]+)/
    puts "latency_min_ms: " + $1
  when /avg:\s+([\d.]+)/
    puts "latency_avg_ms: " + $1
  when /95th percentile:\s+([\d.]+)/
    puts "latency_95th_ms: " + $1
  when /sum:\s+([\d.]+)/
    puts "latency_sum_ms: " + $1
  end
end
