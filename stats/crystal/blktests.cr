#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "../../lib/string_ext"

results = Hash.new { |h, k| h[k] = [] }

def stat_line(line, results)
  case line
  when /^(.+? ).*\[passed\]/
    results["passes"] += $1.rstrip.tr("/", ".").split
  when /^(.+? ).*\[failed\]/
    results["failures"] += $1.rstrip.tr("/", ".").split
  when /^(.+? ).*\[not run\]/
    results["skips"] += $1.rstrip.tr("/", ".").split
  when /^(.+?\/\*\*\*).*\[not run\]/
    results["skips"] += $1.tr("/", ".").split
  when /^(.+? ).*\[ignored by lkp\]/
    puts "#{$1.rstrip.tr("/", ".")}.ignored_by_lkp: 1"
  end
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  stat_line(line, results)
end

results["passes"].each { |seq| puts "#{seq}.pass: 1" }
results["skips"].each { |seq| puts "#{seq}.skip: 1" }
results["failures"].each { |seq| puts "#{seq}.fail: 1" }
