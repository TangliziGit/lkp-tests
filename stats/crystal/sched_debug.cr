#!/usr/bin/env crystal


require "../../lib/statistics"

prefix = nil
no = nil
@sample = {}

def statistics
  return unless @sample

  @sample.each do |k, v|
    puts "#{k}.max: #{v.max}"
    puts "#{k}.min: #{v.min}"
    puts "#{k}.avg: #{v.average}"
    puts "#{k}.stddev: #{v.standard_deviation}"
  end
end

while (line = STDIN.gets)
  case line
  when /^time:/
    statistics
    puts line
    prefix = ""
    @sample = {}
  when /^Sched Debug Version:/
    next
  when /^\s*(\S+)\s*:\s+([0-9.-]+)/
    next if prefix.index ":/autogroup-"

    key = prefix + $1
    if no && !no.strip.empty?
      puts "#{key}.#{no}: #{$2}"
      @sample[key] ||= []
      @sample[key] << $2.to_f
    else
      puts "#{key}: #{$2}"
    end
  when /^runnable tasks:/
    next
  else
    values = line.split
    next if values.empty?

    prefix = values[0].tr(",", "")
    case prefix
    when /^(.*)#([0-9]+)$/
      prefix = $1
      no = $2
    when /^(.*)\[([0-9]+)\](.*)$/
      prefix = $1 + $3
      no = $2
    else
      prefix = prefix
      no = nil
    end
  end
end

statistics
