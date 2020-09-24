#!/usr/bin/env crystal
# reference: linux/mm/vmstat.c

tag = ""

def puts_vals(tag, node, zone, line)
  vals = line.split
  if tag == "pages" && vals.size >= 2
    puts "node#{node}.#{zone}.pages.#{vals[vals.size - 2]}: #{vals[vals.size - 1]}"
  elsif tag == "node" && vals.size >= 2
    puts "node#{node}.#{vals[vals.size - 2]}: #{vals[vals.size - 1]}"
  elsif line =~ /\s*([a-zA-Z].*):\s*([0-9]+)/
    puts "node#{node}.#{zone}.#{$1.tr(" ", "_")}: #{$2}"
  end
end

node = ""
zone = ""
while (line = STDIN.gets)
  case line
  when /^time:/
    puts line
  when /^Node ([^\s]+), zone\s*([a-zA-Z0-9]+)/
    node = $1
    zone = $2
  when /protection:\s*\((.+)\)/
    vals = $1.split ","
    vals.each_with_index do |value, idx|
      puts "node#{node}.#{zone}.protection.#{idx}: #{value.tr(" ", "")}"
    end
  when /cpu:\s*([0-9]+)/
    cpu = $1
    (1..4).each do |_i|
      if STDIN.gets =~ /\s*([a-zA-Z].*):\s*([0-9]+)/
        puts "node#{node}.#{zone}.pagesets.cpu#{cpu}.#{$1.tr(" ", "_")}: #{$2}"
      end
    end
    tag = ""
  when /pages free\s*([0-9]+)/
    tag = "pages"
    puts "node#{node}.#{zone}.pages.free: #{$1}"
  when /per-node/
    tag = "node"
  else
    puts_vals(tag, node, zone, line)
  end
end
