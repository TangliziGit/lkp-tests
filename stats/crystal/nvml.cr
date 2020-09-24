#!/usr/bin/env crystal

require "../../lib/string_ext"

stats = [] of String
test_item = ""
fs_type = ""
build_type = ""

while (line = STDIN.gets)
  line = line.to_s
  line = line.remediate_invalid_byte_sequence unless line.valid_encoding?
  case line
  when %r{^(.+)/TEST[0-9]+: SETUP \(.+/(.+)/(.+)\)$}
    test_item = $1
    fs_type = $2
    build_type = $3
  when %r{^(.+)/(TEST[0-9]+): (PASS|FAIL|SKIP)}
    item = $1
    name = $2
    next unless test_item == item

    stats << item + "_" + name + "_" + fs_type + "_" + build_type + "." + $3.downcase + ": 1"
  when %r{RUNTESTS: stopping: (.+)/(TEST[0-9]+) failed}
    item = $1
    name = $2
    if line =~ /FS=(.+) BUILD=(.+)/
      test_item = item
      fs_type = $1
      build_type = $2
    end
    next unless test_item == item

    stats << item + "_" + name + "_" + fs_type + "_" + build_type + ".fail: 1"
  when %r{RUNTESTS: stopping: (.+)/(TEST[0-9]+) timed out}
    item = $1
    name = $2
    next unless test_item == item

    stats << item + "_" + name + "_" + fs_type + "_" + build_type + ".timeout: 1"
  when %r{^(.+)/(TEST[0-9]+): SKIP}
    item = $1
    name = $2
    stats << item + "_" + name + ".test_skip: 1"
  when /^(ignored_by_lkp)\s+(.*)\s+/
    stats << "#{$2}.#{$1}: 1"
  end
end

stats.uniq.each { |stat| puts stat }
