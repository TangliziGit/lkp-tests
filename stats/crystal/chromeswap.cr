#!/usr/bin/env crystal

STDIN.each_line do |line|
  case line
  when /^throughput_swap_(.*)_(cycles_per_second.*)/
    puts "throughput_swap_#{$2}"
  end
end
