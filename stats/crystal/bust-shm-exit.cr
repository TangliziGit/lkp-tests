#!/usr/bin/env crystal

stats_name = "fail: 1"

while (line = STDIN.gets)
  case line
  when /^bust_shm_exit test done/
    stats_name = "pass: 1"
    break
  end
end

puts stats_name
