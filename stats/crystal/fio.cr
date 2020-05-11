#!/usr/bin/env crystal

# fio.workload is defined as the total number of read/wrote IO operation
LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "json"
require "#{LKP_SRC}/lib/log"

workload = 0
OPS = %w(read write).freeze
PERCENTILES = %w(90.000000 95.000000 99.000000).freeze

if ENV["RESULT_ROOT"]
  fn = File.join ENV["RESULT_ROOT"], "fio.output"
elsif ARGV[0]
  fn = ARGV[0]
end

contents = File.read(fn)
idx = contents.index("{")
unless idx
  log_error "#{fn}: maybe it is not a json format file"
  exit
end
contents = contents[idx..-1] # contents should start with '{'
res = JSON.parse(contents)
unless res
  log_error "Invalid/empty fio output"
  exit
end
res_job = res["jobs"].first
OPS.each do |ops|
  res = res_job[ops]
  puts "#{ops}_bw_MBps: #{res["bw"].to_f / 1024}"
  puts "#{ops}_iops: #{res["iops"]}"
  workload += res["total_ios"].to_i
  res_clat = res["clat"] || res["clat_ns"]
  res_clat_percentiles = res_clat["percentile"]
  puts "#{ops}_clat_mean_us: #{res_clat["mean"]}"
  puts "#{ops}_clat_stddev: #{res_clat["stddev"]}"
  if res_clat_percentiles
    PERCENTILES.each do |p|
      sp = p.chomp("0")
      true while sp.chomp!("0")
      sp.chomp!(".")
      puts "#{ops}_clat_#{sp}%_us: #{res_clat_percentiles[p]}"
    end
  end
  res_slat = res["slat"] || res["slat_ns"]
  puts "#{ops}_slat_mean_us: #{res_slat["mean"]}"
  puts "#{ops}_slat_stddev: #{res_slat["stddev"]}"
end

res_latency_us = res_job["latency_us"]
res_latency_us.each do |k, v|
  puts "latency_#{k}us%: #{v}"
end

res_latency_ms = res_job["latency_ms"]
res_latency_ms.each do |k, v|
  puts "latency_#{k}ms%: #{v}"
end

puts "workload: #{workload}"
