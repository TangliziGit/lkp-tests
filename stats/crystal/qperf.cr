#!/usr/bin/env crystal

qperf = Hash(String, String).new
protocol = "protocol" 
while (line = STDIN.gets)
  case line
  when /^(.+):$/
    protocol = $1.split("_")[0]
  when /^\s*([a-z_]+)\s*=\s*([0-9.]+)\s*[a-zA-Z\/]+$/
    qperf[protocol + "." + $1] = $2
  end
end

qperf.each { |k, v| puts k + ": " + v }
