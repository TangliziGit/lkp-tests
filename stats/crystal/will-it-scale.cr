#!/usr/bin/env crystal

# will-it-scale.workload is defined as the total number of operation for
# all processes/threads
LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/statistics"

scalability = []
per_process = []
per_thread = []
workload = 0

while (line = STDIN.gets)
  case line
  when /^[a-z_,]+$/
    names = line.split ","
    names.shift
  when /^[0-9.,]+$/
    values = line.split ","
    nr_task = values.shift
    next if nr_task == "0"

    linear = values[-1].to_i
    scalability << values[0].to_f / linear if linear != 0 && nr_task != "1"
    per_process << values[0].to_f / nr_task.to_i
    workload += values[0].to_f
    per_thread << values[2].to_f / nr_task.to_i
    workload += values[2].to_f
    names.each_with_index do |name, i|
      puts nr_task + "." + name + ": " + values[i]
    end
  when /(Assertion .* failed)/
    puts $1.sub(/.*: /, "").tr("^a-zA-Z0-9<>!=", "_").gsub(/__+/, "_") + ": 1"
  end
end

printf "scalability: %f\n", scalability[-1] unless scalability.empty?
printf "per_process_ops: %d\n", per_process.average unless per_process.empty?
printf "per_thread_ops: %d\n", per_thread.average unless per_thread.empty?
printf "workload: %d\n", workload unless workload.zero?
