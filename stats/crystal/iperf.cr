#!/usr/bin/env crystal

require "json"
require "../../lib/log"

begin
  obj = JSON.parse(STDIN)
rescue e : JSON::Error
  log_error "error: malformed iperf result"
  log_error e if e
  exit
end

exit if obj["end"].as_s.empty?

puts "tcp.sender.bps: " + obj["end"]["streams"][0]["sender"]["bits_per_second"].to_s if obj["end"]["streams"][0]["sender"]
puts "tcp.receiver.bps: " + obj["end"]["streams"][0]["receiver"]["bits_per_second"].to_s if obj["end"]["streams"][0]["receiver"]
puts "udp.bps: " + obj["end"]["streams"][0]["udp"]["bits_per_second"].to_s if obj["end"]["streams"][0]["udp"]
