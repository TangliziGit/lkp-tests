#!/usr/bin/env crystal

require "../../lib/string_ext"

keys = %w(read_ios read_merges read_sectors read_ticks
          write_ios write_merges write_sectors write_ticks
          in_flight io_ticks time_in_queue)

STDIN.each_line do |line|
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  if line =~ /^time: /
    puts line
    next
  end

  data = line.to_s.split
  next if data.size != keys.size + 3

  dev_name = data[2]
  data[3..-1].each_with_index do |v, i|
    puts keys[i] + "." + dev_name + ": " + v
  end
end
