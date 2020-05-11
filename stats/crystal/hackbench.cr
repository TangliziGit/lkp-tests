#!/usr/bin/env crystal

# hackbench.workload is defined as the total messages for all
# processes/threads
time = 0.0
kb = 0
workload = 0

while (line = gets)
  case line
  when /^Running in .* mode with (\d+) groups using (\d+) file descriptors each \(== (\d+) tasks\)/
    tasks = $3.to_i
  when /^Each sender will pass (\d+) messages of (\d+) bytes/
    messages = $1.to_i
    bytes = $2.to_i
  when /^Each sender passed (\d+) messages of (\d+) bytes in average/
    messages = $1.to_i
    bytes = $2.to_i
  when /^Time:/
    _name, seconds = line.split
    time += seconds.to_f
    kb += tasks * messages * bytes >> 10
    workload += tasks * messages
  end
end

puts "throughput: #{kb / time}"
puts "workload: #{workload}"
