#!/usr/bin/env crystal

require "../../lib/string_ext"

# results = Hash.new { |h, k| h[k] = [] of String }

results = Hash(String, Array(String)).new { |h, k| h[k] = [] of String }

def stat_line(line, results)
  case line
  when /^(Ran|Failures): (.*)/
    results[$1.downcase] += $2.tr("/", ".").split
  when /^Not run: (.*)/
    results["skips"] = $1.tr("/", ".").split
  when /^_check_generic_filesystem: filesystem on .+ is inconsistent \(see .+\/([a-z]+)\/([0-9]+)\.full\)/
    puts "#{$1}.#{$2}.inconsistent_fs: 1"
  when /^(ignored by lkp): (.*)/
    puts "#{$2.tr("/", ".")}.ignored_by_lkp: 1"
  when /^(generic|ext4|xfs|btrfs)\/(\d\d\d)\s+(\d+)s/
    test = $1 + "." + $2
    results["passes"].push test
  end
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence unless line.valid_encoding?
  stat_line(line, results)
end

results["passes"].each { |seq| puts "#{seq}.pass: 1" }
results["skips"].each { |seq| puts "#{seq}.skip: 1" }
results["failures"].each { |seq| puts "#{seq}.fail: 1" }
