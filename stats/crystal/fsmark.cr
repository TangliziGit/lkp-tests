#!/usr/bin/env crystal

require "../../lib/statistics"
require "../../lib/log"

# skip none-result data
while (line = STDIN.gets)
  break if line =~ /^FSUse/
end

files_per_sec = []
app_overhead = []
while (line = STDIN.gets)
  iteration = line.split
  if iteration.size != 5
    log_error "WARNING: unexpected fsmark output: #{line}"
    next
  end
  files_per_sec << iteration[3].to_f
  app_overhead << iteration[4].to_f
end

puts "files_per_sec: " + files_per_sec.average.to_s
puts "app_overhead: " + app_overhead.average.to_s
