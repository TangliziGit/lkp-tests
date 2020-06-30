#!/usr/bin/env crystal

require "../../lib/log"
require "../../lib/string_ext"

# skip invalid line
while (line = STDIN.gets)
  break if line =~ /Total/
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  case line
  # Connection rate: 991.1 conn/s (1.0 ms/conn <= 12 concurrent connections)
  when /^(Connection|Request|Response) rate: (.*.) (.*\/s)/
    type = $1.downcase
    val = $2
    unit = $3
    puts "#{type}_rate_#{unit}: #{val}"
  when /^(Connection|Connect|Response|Request|CPU) (time|size) \[(ms|B|s)\]:(( \w* \d*.\d*){2,})/
    type = $1.downcase
    object = $2
    unit = $3
    test_object = "#{type}_#{object}"
    $4.gsub(/(\w+) (\d+.\d+)/) { puts "#{test_object}_#{$1}_#{unit}: #{$2}" }
  when /^Net I\/O: bytes (\d+.\d+) (.*) (\d+.\d+)/
    io_bytes = $1
    io_rate = $3
    puts "net_io_bytes: #{io_bytes}"
    puts "net_io_rate_kb/s: #{io_rate}"
  end
end
