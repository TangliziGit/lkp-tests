#!/usr/bin/env crystal

require "../../lib/array_ext"

set_sum = 0
set_num = 0
set_avg = 0
get_sum = 0
get_num = 0
get_avg = 0
is_set = true
set_latencies = [] of Hash(Int32, Float64)
get_latencies = [] of Hash(Int32, Float64)
proc_set_latencies = {} of Int32 => Float64
proc_get_latencies = {} of Int32 => Float64
set_time = 0
set_time_sum = 0
set_time_num = 0
get_time = 0
get_time_sum = 0
get_time_num = 0

PERCENTILE_STRS = ["90", "95", "99", "99.9"].freeze
PERCENTILES = PERCENTILE_STRS.map(&.to_f)

#$stdin.each_line do |line|
STDIN.each_line do |line|
  case line
  when /PING_INLINE: (\d+).(\d+) requests per second$/
    puts "PING_INLINE: #{$1}.#{$2}"
  when /PING_BULK: (\d+).(\d+) requests per second$/
    puts "PING_BULK: #{$1}.#{$2}"
  when /====== SET ======$/
    is_set = true
    #proc_set_latencies = [] of Float64

  when /====== GET ======$/
    is_set = false
    #proc_get_latencies = [] of Float64
  when /^(\d+\.\d+) requests per second$/
    if is_set
      set_sum += $1.to_f
      set_num += 1
      set_latencies << proc_set_latencies
    else
      get_sum += $1.to_f
      get_num += 1
      get_latencies << proc_get_latencies
    end
  when /requests completed in (\d+\.\d+) seconds$/
    if is_set
      set_time_sum += $1.to_f
      set_time_num += 1
    else
      get_time_sum += $1.to_f
      get_time_num += 1
    end
  when /^(\d+\.\d+)% <= (\d+) milliseconds$/
    ms = $2.to_i
    if is_set
      proc_set_latencies[ms] = $1.to_f
    else
      proc_get_latencies[ms] = $1.to_f
    end
  when /INCR: (\d+).(\d+) requests per second$/
    puts "INCR: #{$1}.#{$2}"
  when /LPUSH: (\d+).(\d+) requests per second$/
    puts "LPUSH: #{$1}.#{$2}"
  when /RPUSH: (\d+).(\d+) requests per second$/
    puts "RPUSH: #{$1}.#{$2}"
  when /LPOP: (\d+).(\d+) requests per second$/
    puts "LPOP: #{$1}.#{$2}"
  when /RPOP: (\d+).(\d+) requests per second$/
    puts "RPOP: #{$1}.#{$2}"
  when /SADD: (\d+).(\d+) requests per second$/
    puts "SADD: #{$1}.#{$2}"
  when /HSET: (\d+).(\d+) requests per second$/
    puts "HSET: #{$1}.#{$2}"
  when /SPOP: (\d+).(\d+) requests per second$/
    puts "SPOP: #{$1}.#{$2}"
  when /LPUSH .needed to benchmark LRANGE.: (\d+).(\d+) requests per second$/
    puts "LPUSH_LRANGE: #{$1}.#{$2}"
  when /LRANGE_100 .first 100 elements.: (\d+).(\d+) requests per second$/
    puts "LRANGE_100: #{$1}.#{$2}"
  when /LRANGE_300 .first 300 elements.: (\d+).(\d+) requests per second$/
    puts "LRANGE_300: #{$1}.#{$2}"
  when /LRANGE_500 .first 450 elements.: (\d+).(\d+) requests per second$/
    puts "LRANGE_500: #{$1}.#{$2}"
  when /LRANGE_600 .first 600 elements.: (\d+).(\d+) requests per second$/
    puts "LRANGE_600: #{$1}.#{$2}"
  when /MSET .10 keys.: (\d+).(\d+) requests per second$/
    puts "MSET: #{$1}.#{$2}"
  end
end
set_avg = set_sum / set_num
get_avg = get_sum / get_num
set_time = set_time_sum / set_time_num
get_time = get_time_sum / get_time_num
puts "set_total_throughput_rps: #{set_sum}"
puts "get_total_throughput_rps: #{get_sum}"
puts "set_total_time_sec: #{set_time_sum}"
puts "get_total_time_sec: #{get_time_sum}"
puts "set_avg_throughput_rps: #{set_avg}"
puts "get_avg_throughput_rps: #{get_avg}"
puts "set_avg_time_sec: #{set_time}"
puts "get_avg_time_sec: #{get_time}"

def normalize_latencies(latencies)
  maxcol = latencies.map(&.size).max
  latencies.each do |proc_latencies|
    prev = 0
    (0...maxcol).map do |i|
      percent = proc_latencies[i]
      percent ||= prev
      prev = percent
      proc_latencies[i] = percent.to_f
    end
  end
end

def show_latencies(latencies, name)
  pi = 0
  #latencies.transpose.each_with_index do |ps, i|
  latencies.transpose.each_with_index do |(k,v), i|
    ps = {k=>v}
    sum = ps.sum
    next if sum == 0

    avg = sum.to_f / ps.size
    puts "#{name}_latency_#{i}ms%: #{avg}"
    while pi < PERCENTILES.size && avg > PERCENTILES[pi]
      puts "#{name}_latency_#{PERCENTILE_STRS[pi]}%_ms: #{i}"
      pi += 1
    end
    break if avg > PERCENTILES[-1]
  end
end

normalize_latencies(set_latencies)
normalize_latencies(get_latencies)

#show_latencies(set_latencies, "set")
#show_latencies(get_latencies, "get")
