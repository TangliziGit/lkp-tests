#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/statistics"
require "#{LKP_SRC}/lib/log"

while (line = STDIN.gets)
  case line
  when /\s*\d+:\s*(\d+) bytes\s+\d+ times -->\s+([0-9.]+) Mbps in\s+([0-9.]+) usec/
    if $1.to_i < (8 * 1024)
      less_8k_usec ||= []
      less_8k_usec << $3.to_f
    elsif $1.to_i > (5 * 1024 * 1024)
      bigger_5m_mbps ||= []
      bigger_5m_mbps << $2.to_f
    end
  end
end

if less_8k_usec.nil? || bigger_5m_mbps.nil?
  log_error "no less_8k_usec or bigger_5m_mbps in the STDIN"
  exit
end
puts "less_8K_usec.avg: #{less_8k_usec.average}"
puts "bigger_5M_Mbps.avg: #{bigger_5m_mbps.average}"
