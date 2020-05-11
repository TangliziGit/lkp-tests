#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line.chomp!
  when /^Total Average\s+:.*= ([0-9.]+) ([a-z]+)$/
    unit = $2
    average = $1
  end
end

puts "total_average_#{unit}: #{average}"
