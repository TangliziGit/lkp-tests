#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "json"
require "#{LKP_SRC}/lib/log"

begin
  obj = JSON.load STDIN
rescue JSON::ParserError => e
  log_error "error: malformed iperf result"
  log_error e.message[0..300]
  log_error e.backtrace.join('\n')
  exit
end

exit if obj["end"].empty?

puts "tcp.sender.bps: " + obj["end"]["streams"][0]["sender"]["bits_per_second"].to_s if obj["end"]["streams"][0]["sender"]
puts "tcp.receiver.bps: " + obj["end"]["streams"][0]["receiver"]["bits_per_second"].to_s if obj["end"]["streams"][0]["receiver"]
puts "udp.bps: " + obj["end"]["streams"][0]["udp"]["bits_per_second"].to_s if obj["end"]["streams"][0]["udp"]
