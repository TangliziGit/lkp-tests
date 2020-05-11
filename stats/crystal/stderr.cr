#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require "#{LKP_SRC}/lib/dmesg"
require "#{LKP_SRC}/lib/string_ext"
require "#{LKP_SRC}/lib/log"

error_ids = {}

@ignore_patterns = []
Dir["#{LKP_SRC}/etc/ignore-stderr/*"].each do |f|
  File.open(f).each_line do |line|
    line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
    @ignore_patterns << Regexp.new("^" + line + "$")
  end
end

def should_ignore_stderr(line)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  @ignore_patterns.any? do |re|
    # ERR in `match': invalid byte sequence in US-ASCII (ArgumentError)
    # treat unrecognized line as "can't be ignored"
    begin
      re.match line
    rescue StandardError
      nil
    end
  end
end

while (line = gets)
  next if should_ignore_stderr(line)

  # ERR: lib/dmesg.rb:151:in `gsub!': invalid byte sequence in US-ASCII (ArgumentError)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?
  line = line.strip_nonprintable_characters
  id = common_error_id(line)

  next if id.size < 3

  # Don't treat the lines starting with
  # Date/Num/Hex Num/SHA as comments
  id.gsub!(/^#/, "_#") if line[0] != "#"

  error_ids[id] = line
end

error_ids.each do |id_, line_|
  puts "# " + line_
  puts id_ + ": 1"
  puts
end

puts "has_stderr: 1" unless error_ids.empty?

log_warn "noisy stderr, check #{ENV["RESULT_ROOT"]}/stderr" if error_ids.size > 100
