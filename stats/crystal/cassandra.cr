#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

# Example output of Cassandra:
# Results:
# Op rate                   :      683 op/s  [insert: 364 op/s, range1: 319 op/s]
# Partition rate            :    9,647 pk/s  [insert: 9,328 pk/s, range1: 319 pk/s]
# Row rate                  :   14,445 row/s [insert: 9,328 row/s, range1: 5,117 row/s]
# Latency mean              :    1.0 ms [insert: 1.2 ms, range1: 0.7 ms]
# Latency median            :    0.8 ms [insert: 1.1 ms, range1: 0.6 ms]
# Latency 95th percentile   :    1.7 ms [insert: 1.9 ms, range1: 1.1 ms]
# Latency 99th percentile   :    3.1 ms [insert: 3.6 ms, range1: 1.7 ms]
# Latency 99.9th percentile :    7.7 ms [insert: 5.9 ms, range1: 6.1 ms]
# Latency max               :   20.5 ms [insert: 12.0 ms, range1: 20.5 ms]
# Total partitions          :     48,484 [insert: 46,880, range1: 1,604]
# Total errors              :          0 [insert: 0, range1: 0]
# Total GC count            : 1
# Total GC memory           : 1.231 GiB
# Total GC time             :    0.0 seconds
# Avg GC time               :   20.0 ms
# StdDev GC time            :    0.0 ms
# Total operation time      : 00:00:05

$stdin.each_line do |line|
  case line
  # Parse the entry beginning with "Op rate"
  when /^Op rate\s+:\s+(\d+) op\/s\s+\[(.+)\]$/
    puts "Op.rate: #{$1}"
    subops = $2
    subops.split(",").each do |item|
      key = item.split(":")[0].lstrip
      value = item.split[1]
      puts "Op.#{key}.rate: #{value}"
    end
  end
end
