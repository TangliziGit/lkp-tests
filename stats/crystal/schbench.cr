#!/usr/bin/env crystal

$stdin.each_line do |line|
  case line
  when /50.0000th/
    puts "latency_50%_us: " + line.split[1]
  when /75.0000th/
    puts "latency_75%_us: " + line.split[1]
  when /90.0000th/
    puts "latency_90%_us: " + line.split[1]
  when /95.0000th/
    puts "latency_95%_us: " + line.split[1]
  when /99.0000th/
    puts "latency_99%_us: " + line.split[1]
  when /99.5000th/
    puts "latency_99.5%_us: " + line.split[1]
  when /99.9000th/
    puts "latency_99.9%_us: " + line.split[1]
  when /min/
    line = line.tr(",", " ")
    puts "latency_" + line.split[0].gsub(/=/, "_us: ")
    puts "latency_" + line.split[1].gsub(/=/, "_us: ")
  end
end
