#!/usr/bin/env crystal

# the workload of ebizzy is defined as the total number of records for all
# threads

require "../../lib/statistics"

workload = 0

while (line = STDIN.gets)
  case line
  when /^(\d+) records\/s(.*)$/
    puts "throughput: " + $1
    throughput = $1.to_i
    data = $2.split.map(&.to_i)

    puts "throughput.per_thread.min: " + data.min.to_s
    puts "throughput.per_thread.max: " + data.max.to_s
    puts "throughput.per_thread.stddev_percent: " + (100.0 * data.standard_deviation / throughput).to_s
  when /^real\ +(\d+.\d+) s/
    puts "time.real: " + $1
    time = $1.to_f
    throughput = $1.to_i
    workload += throughput * time
  when /^user\ +(\d+.\d+) s/
    puts "time.user: " + $1
  when /^sys\ +(\d+.\d+) s/
    puts "time.sys: " + $1
  end
end

puts "workload: " + workload.to_s
