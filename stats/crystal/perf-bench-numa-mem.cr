#!/usr/bin/env crystal

keys = {
  "secs_latency" => "secs,\\s*NUMA-convergence-latency",
  "secs_slowest" => "secs,\\s*runtime-max/thread",
  "secs_fastest" => "secs,\\s*runtime-min/thread",
  "secs_avg" => "secs,\\s*runtime-avg/thread",
  "max_avg_diff" => "%,\\s*spread-runtime/thread",
  "GB_per_thread" => "GB,\\s*data/thread",
  "GB_total" => "GB,\\s*data-total",
  "nsecs_byte_thread" => "nsecs,\\s*runtime/byte/thread",
  "GB_sec_thread" => "GB/sec,\\s*thread-speed",
  "GB_sec_total" => "GB/sec,\\s*total-speed",
}

while (line = STDIN.gets)
  keys.each do |k, v|
    puts "#{k}: #{$1}" if line =~ /([\d.]+),\s*#{v}/
  end
end
