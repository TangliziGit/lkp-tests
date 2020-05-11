#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "#{LKP_SRC}/lib/statistics"

results = {}

while (line = STDIN.gets)
  case line
  when /^(.*):[\t\s]+([\d.]+)( (\S+))?/
    value = $2
    unit = "_" + $4 if $4
    unit ||= ""
    key = $1.tr(" ", "_") + unit
    results[key] ||= []
    results[key] << value.to_f
  end
end

results.each { |k, v| puts "#{k}: #{v.average}" }
