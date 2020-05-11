#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line.chomp!
  when /^\s*\d+\.\d+ MB \/\s+\d+\.\d+ sec =\s+(\d+\.\d+) Mbps/
    puts "throughput_Mbps: " + $1
  end
end
