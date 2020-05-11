#!/usr/bin/env crystal


require "../../lib/statistics"

samples = {}

def show_samples(samples)
  samples.each do |k, v|
    puts k + ": " + v.sum.to_s
  end
  samples.clear
end

STDIN.each_line do |line|
  case line
  when /^time: /
    show_samples samples
  when /(^zone\d): (.*)/
    samples[$1] ||= []
    samples[$1] << $2.to_i
  when /(^cdev\d): (.*)/
    samples[$1] ||= []
    samples[$1] << $2.to_i
  end
end

show_samples samples
