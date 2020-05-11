#!/usr/bin/env crystal

# Input example:
# [   20.504916] rcu-perf:--- Start of test: nreaders=2 nwriters=2 verbose=1 shutdown=0
# [   20.521488] rcu-perf: rcu_perf_reader task started
# [   20.526468] rcu-perf: rcu_perf_reader task started
# [   20.536483] rcu-perf: rcu_perf_writer task started
# [   20.541467] rcu-perf: rcu_perf_writer task started
# [   31.728409] rcu-perf: rcu_perf_writer 0 has 100 measurements
# [   31.730422] rcu-perf: rcu_perf_writer 1 has 100 measurements
# [   31.744797] rcu-perf: Test complete
# [  320.627980] rcu-perf: writer 0 gps: 101
# [  320.637100] rcu-perf: writer 1 gps: 100
# [  320.640206] rcu-perf: start: 30396186972 end: 31136206117 duration: 740019145 gps: 201 batches: 207
# ...

result = "unknown"
type = "unknown"

while (line = STDIN.gets)
  case line
  when /^\[.*\] ([A-Za-z]+)-perf: Test complete/
    type = $1
    result = "completed"
    break
  end
end

stat = type + "." + result
puts "#{stat}: 1"
