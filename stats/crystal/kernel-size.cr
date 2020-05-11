#!/usr/bin/env crystal

require "yaml"

RESULT_ROOT = ENV["RESULT_ROOT"]

job = YAML.load_file(RESULT_ROOT + "/job.yaml")
exit unless job

kernel_size_file = "#{File.dirname job["kernel"]}/kernel_size"
exit unless File.exist? kernel_size_file

text, data, bss = `tail -n 1 #{kernel_size_file}`.split

puts "text: #{text}"
puts "data: #{data}"
puts "bss: #{bss}"
