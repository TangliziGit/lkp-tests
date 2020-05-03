#!/usr/bin/env crystal


require "fileutils"
require "../../lib/statistics"

RESULT_ROOT = ENV["RESULT_ROOT"]
results = {}
results["test"] = ""
results["val"] = []

exit unless File.exist?("#{RESULT_ROOT}/kmsg")

def show_one(new_test, results)
  printf "%s: %d\n", results["test"], results["val"].average unless results["test"].empty? || results["val"].empty?
  results["test"] = new_test
  results["val"] = []
end

File.foreach("#{RESULT_ROOT}/kmsg") do |line|
  case line
  when /testing speed of (.*)$/
    show_one($1.tr(" ", "."), results)
  when /\d+ operations in (\d+) seconds \((\d+) bytes\)/
    bps = $2.to_i / $1.to_i
    results["val"] << bps
  when /\d+ opers\/sec, +(\d+) bytes\/sec/
    bps = $1.to_i
    results["val"] << bps
  end
end

show_one("", results)
