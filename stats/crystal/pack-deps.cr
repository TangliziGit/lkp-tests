#!/usr/bin/env crystal

stats_name = "fail: 1"

while (line = STDIN.gets)
  case line
  when /^package uploaded to \S+cgz$/
    stats_name = "pass: 1"
    break
  when /^empty PACKAGE_LIST for .*$/
    stats_name = "skip: 1"
    break
  when /^create symlink for shared package: (.*) -> (.*)/
    puts "symlink.#{$1}: 1"
    puts "target.#{$2}: 1"
    stats_name = "skip: 1"
  end
end

puts stats_name
