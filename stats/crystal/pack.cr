#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.reapath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/string_ext"

stats_name = "fail: 1"

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?

  case line
  when /^rsync error/
    break
  when /^total size is \S+  speedup is \S+$/
    stats_name = "pass: 1"
    break
  end
end

puts stats_name
