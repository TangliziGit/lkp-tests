#!/usr/bin/env crystal

stats = []

while (line = STDIN.gets)
  case line
  when /^(.*): (fail|crash|timeout|warn|dmesg-warn|dmesg-fail|pass|skip|ignored_by_lkp)/
    stats_type = $2
    stats << $1.tr(" /", "_.") + ".#{stats_type}: 1"
  end
end

stats.uniq.each { |stat| puts stat }
