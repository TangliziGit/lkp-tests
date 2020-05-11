#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /^[0-9\.e\- ]+(pass|fail)$/
    puts "GFlops: " + line.split[4]
  end
end
