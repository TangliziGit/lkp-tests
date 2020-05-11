#!/usr/bin/env crystal

sockperf = {}
while (line = STDIN.gets)
  case line.chomp!
  when /^sockperf: subcommand (.+) (.+)$/
    subcommand = $1
    protocol = $2
  when /^sockperf:.+avg-lat=\s*(\d+\.\d+) \(std-dev=\s*(\d+\.\d+)\)/
    sockperf[subcommand + "." + protocol + "." + "avg-lat"] = $1
    sockperf[subcommand + "." + protocol + "." + "std-dev"] = $2
  when /^sockperf: Summary: Message Rate is (\d+) \[msg\/sec\]$/
    sockperf[subcommand + "." + protocol + "." + "msg_per_sec"] = $1
  when /^sockperf: Summary: BandWidth is (\d+\.\d+) MBps \(\d+\.\d+ Mbps\)$/
    sockperf[subcommand + "." + protocol + "." + "BandWidth_MBps"] = $1
  end
end
sockperf.each { |k, v| puts k + ": " + v }
