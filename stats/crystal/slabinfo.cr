#!/usr/bin/env crystal

require "../../lib/log"

sub_names = nil
STDIN.each_line do |line|
  case line
  when /slabinfo - version:/
    unless line =~ /2.1/
      log_error "version #{line} is not 2.1"
      exit
    end
  when /^time:/
    puts line
  when /^# name/
    sub_names = line.split
    sub_names.shift
    sub_names.shift
  else
    if sub_names.nil?
      log_error "fail to parse slabinfo"
      exit
    end
    values = line.split
    name = values.shift
    next if values.size != sub_names.size

    values.each_with_index do |value, i|
      next unless sub_names[i][0] == "<"

      case sub_names[i]
      when "<active_objs>",
           "<num_objs>",
           "<active_slabs>",
           "<num_slabs>"
        puts name + "." + sub_names[i][1..-2] + ": " + value
      end
    end
  end
end
