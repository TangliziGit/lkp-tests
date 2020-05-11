#!/usr/bin/env crystal

while (line = STDIN.gets)
  case line.chomp!
  # packetdrill/tests/linux/packetdrill/socket_wrong_err.pkt failed
  when /^(.*)\.pkt failed/
    puts "#{$1}.fail: 1"
  when /^(.*)\.pkt pass/
    puts "#{$1}.pass: 1"
    # Match the output of tcp tests
    # FAIL [/lkp/benchmarks/packetdrill/gtests/net/tcp/notsent_lowat/notsent-lowat-sysctl.pkt (ipv4-mapped-v6)]
  when /^FAIL\s+\[(.*)\.pkt \((.*)\)\]/
    puts "#{$1}_#{$2}.fail: 1".sub("/lkp/benchmarks/", "")
    # OK   [/lkp/benchmarks/packetdrill/gtests/net/tcp/zerocopy/fastopen-server.pkt (ipv6)]
  when /^OK\s+\[(.*)\.pkt \((.*)\)\]/
    puts "#{$1}_#{$2}.pass: 1".sub("/lkp/benchmarks/", "")
  end
end
