#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line
  when /^[read|update|op_q]/
    type, avg, std, min, n5th, n10th, n90th, n95th, n99th = line.split
    puts "#{type}.avg: #{avg}"
    puts "#{type}.std: #{std}"
    puts "#{type}.min: #{min}"
    puts "#{type}.5th: #{n5th}"
    puts "#{type}.10th: #{n10th}"
    puts "#{type}.90th: #{n90th}"
    puts "#{type}.95th: #{n95th}"
    puts "#{type}.99th: #{n99th}"
  when /^Total/
    parts = line.split
    totalqps = parts[3].to_f
    totalqpstotal = parts[4][1..].to_f
    totalqpstime = parts[6].to_f
    puts "totalqps: #{totalqps}"
    puts "totalqps.total: #{totalqpstotal}"
    puts "totalqps.time: #{totalqpstime}"
  when /^Misses = (\d+) \((\d+)\.(\d+)%\)/
    puts "misses.num: #{$2}"
    puts "misses.percent: #{$2}.#{$3}"
  when /^Skipped TXs = (\d+) \((\d+)\.(\d+)%\)/
    puts "skipped.num: #{$1}"
    puts "skipped.percent: #{$2}.#{$3}"
  when /^RX\s+(\d+)\s+bytes\s+:\s+(\d+).(\d+) MB\/s/
    puts "rx.bytes: #{$1}"
    puts "rx.speed: #{$2}.#{$3}"
  when /^TX\s+(\d+)\s+bytes\s+:\s+(\d+).(\d+) MB\/s/
    puts "tx.bytes: #{$1}"
    puts "tx.speed: #{$2}.#{$3}"
  end
end
