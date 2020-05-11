#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/string_ext"

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  case line
  # queries performed:
  #     read:                            134956458
  #     write:                           0
  #     other:                           19279494
  #     total:                           154235952
  # transactions:                        9639747 (16065.20 per sec.)
  # queries:                             154235952 (257043.25 per sec.)
  when /read:\s+(\d+)/
    puts "read: " + $1
  when /write:\s+(\d+)/
    puts "write: " + $1
  when /other:\s+(\d+)/
    puts "other: " + $1
  when /transactions:\s+(\d+)\s+\(([\d.]+) per sec.\)/
    puts "transactions: " + $1
    puts "transactions/s: " + $2
  when /queries:\s+(\d+)\s+\(([\d.]+) per sec.\)/
    puts "queries: " + $1
    puts "queries/s: " + $2
    #Latency (ms):
    #     min:                                    0.90
    #     avg:                                    1.78
    #     max:                                   57.61
    #     95th percentile:                        2.35
    #     sum:                               239794.59
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
    #Threads fairness:
    #  events (avg/stddev):           33716.7500/24.71
    #  execution time (avg/stddev):   59.9486/0.01
  when /events \(avg\/stddev\):\s+([\d.]+)\/([\d.]+)/
    stddev = $2.to_f * 100 / $1.to_f
    puts "thread_events_stddev%: #{stddev}"
  when /execution time \(avg\/stddev\):\s+([\d.]+)\/([\d.]+)/
    stddev = $2.to_f * 100 / $1.to_f
    puts "thread_time_stddev%: #{stddev}"
  end
end
