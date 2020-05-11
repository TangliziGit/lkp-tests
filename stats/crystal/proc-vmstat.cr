#!/usr/bin/env crystal

STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  else
    key, value = line.split
    puts "#{key.chomp(":")}: #{value}"
  end
end
