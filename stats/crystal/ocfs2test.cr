#!/usr/bin/env crystal

stats = [""]
case_name=""
while (line = STDIN.gets)
  case line
  when /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} ([^\(\)]+)$/
    case_name = $1
  when /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} (PASS|FAIL)ED \(\d+ secs\)/
    stats << case_name.strip.tr(" ", "_") + "." + $1.downcase + ": 1"
  end
end

stats.each { |stat| puts stat }
