#!/usr/bin/env crystal
# example input:
# 04/02/2013 10:42:02 AM
# avg-cpu:  %user   %nice %system %iowait  %steal   %idle
#          34.78   12.99    6.03    0.40    0.00   45.80
#
# Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
# sda               0.15    12.76    3.02    9.81    63.05   126.27    29.51     0.16   12.72    3.96   15.42   1.55   1.99
# sdd               0.09    34.01    8.43   20.57   189.15   750.68    64.80     0.79   27.07    1.31   37.63   0.45   1.31

require "time"

def normalize_key(key)
  key.sub("%", "")
end

def extract_avg_cpu(line)
  # remove heading avg-cpu item
  title = line.split[1..-1]

  return unless (line = STDIN.gets)

  data = line.split
  (0..data.size - 1).each do |i|
    key = normalize_key "cpu.#{title[i]}"
    puts key + ": " + data[i]
  end
end

def extract_dev_stat(line)
  title = line.split
  while (line = STDIN.gets)
    data = line.split
    break if data.size != title.size

    dev = data[0]
    (1..data.size - 1).each do |i|
      key = normalize_key "#{dev}.#{title[i]}"
      puts key + ": " + data[i]
    end
  end
end

while (line = STDIN.gets)
  if line =~ /^[0-9T:+-]{24}$/ # "2013-04-02T13:58:40+0800", by 'S_TIME_FORMAT=ISO isotat -t'
    time = line.chomp('\n')
    #puts "time: #{Time.parse(time).to_i}"
  elsif line =~ /^avg-cpu:/
    extract_avg_cpu line
  elsif line =~ /^Device:/
    extract_dev_stat line
  end
end
