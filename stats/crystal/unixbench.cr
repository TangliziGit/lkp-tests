#!/usr/bin/env crystal
# unixbench.workload is defined as the total operations in unixbench for
# all processes/threads

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "../../lib/log"
require "time"

# Benchmark run time format displayed as below:
# Benchmark Run: Tue Jan 01 2019 15:48:24 - 15:56:36

while (line = STDIN.gets)
  case line
  when /^Benchmark Run: .+ (\d+:\d+:\d+) - (\d+:\d+:\d+)$/
    # We only care about the difference value between end time and start time
    start_time = Time.parse($1).to_f
    end_time = Time.parse($2).to_f
    duration = if end_time > start_time
                 end_time - start_time
               else
                 end_time + 3600 * 24 - start_time # date overflo
               end
  when /^System Benchmarks Partial Index .* INDEX$/
    line = STDIN.gets
    if line
      lines = line.split
      throughput = lines[-2].to_f
    end
  when /^System Benchmarks Index Score .* ([0-9\.]+)$/
    score = $1
  end
end

if duration.nil? || throughput.nil?
  log_error "unixbench: missing duration or throughput"
  exit
end

workload = duration * throughput
if score
  puts "score: " + score
  puts "workload: " + workload.to_s
else
  puts "incomplete_result: 1"
  log_error "unixbench: missing score, check " + ENV["RESULT_ROOT"]
end
