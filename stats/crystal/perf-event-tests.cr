#!/usr/bin/env crystal

stats = Hash(String, String).new
item = nil
while (line = STDIN.gets)
  case line
  when /^[ ]+\+ \S+\/(\S+)$/
    item = $1
  when /\.\.\.[ ]+([\S\s]+)$/
    stats[item] = $1.strip.to_s.tr(" ", "_").downcase if item
  when /^(ignored_by_lkp)\s+(.*)\s+/
    stats[$2] = $1
  end
end

stats.each do |k, v|
  puts "#{k}." + v + ": 1"
end
