#!/usr/bin/env crystal

def parse(fin)
  fin.each_line do |line|
    case line
    when /RawSize:\s+([\d.]+)\s+/
      puts "workload: #{$1}"
    when /\s+([\d.]+)\s*micros\/op\s*([\d.]+)\s*ops\/sec/
      puts "us/op: #{$1}"
      puts "ops/s: #{$2}"
    end
  end
end

parse STDIN
