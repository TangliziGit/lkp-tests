#!/usr/bin/env crystal

sub_names = ""
STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  when /^Free pages count per migrate type at order (.*)/,
       /^Number of blocks type (.*)/
    sub_names = $1.split
  when /^(Node *\d+, zone *\S+[a-zA-Z ]+) ([0-9 ]+)/
    values = $2.split
    next if values.size != sub_names.size

    name = $1.gsub(/, (zone|type)/, ".").tr(" ", "")
    values.each_with_index do |value, i|
      puts name + "." + sub_names[i] + ": " + value
    end
  end
end
