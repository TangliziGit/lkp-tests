#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.reapath(PROGRAM_NAME)))

require "../../lib/string_ext"

results = {}

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?

  case line
  # The output is as below:
  # PASS ap_hs20_network_preference 0.562706 2017-04-25 14:22:28.575753
  # FAIL ap_hs20_proxyarp_enable_dgaf 0.457441 2017-04-25 14:22:34.671422
  # SKIP ap_ht_op_class_115 5.227749 2017-04-25 14:24:59.481133
  when /^(PASS|FAIL|SKIP|ignored_by_lkp)\s+(.*)\s+/
    ret = "#{$2.split[0]}.#{$1}".downcase
    results[ret] = 1
  end
end

results.each do |k, v|
  puts "#{k}: #{v}"
end
