#!/usr/bin/env crystal

titles = nil
STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  when /^\s*[^\s]+:/
    values = line.split
    sum = 0
    titles.each_with_index do |title, i|
      puts title + "." + values[0] + " " + values[i + 1]
      sum += values[i + 1].to_i
    end
    puts values[0] + " " + sum.to_s
  else
    titles = line.split
  end
end
