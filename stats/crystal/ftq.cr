#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))
RESULT_ROOT = ENV["RESULT_ROOT"]

require "../../lib/common"
require "../../lib/log"

PDEL = 10

data = []
files = Dir["#{RESULT_ROOT}/results/ftq_*.dat*"]
if files.empty?
  log_error "can not find any log file at #{RESULT_ROOT}/results/"
  exit
end
files.each do |file|
  zopen(file) do |f|
    rdata = f.read
    n = (rdata =~ /^[^#]/)
    rdata.slice!(0, n)
    sfdata = rdata.split
    sfdata.select!.with_index { |_x, i| i.odd? }
    n = sfdata.size
    ndel = n * PDEL / 100
    sfdata.slice!(n - ndel, ndel)
    sfdata.slice!(0, ndel)
    data.concat(sfdata.map(&.to_i))
  end
end

data.sort!
mean = data[data.size / 2]
max = data.last
samples = data.size

printf "max: %d\n", max
printf "mean: %d\n", mean

perf_levels = [1, 25, 50, 75, 95, 98]

start = 0
perf_num_levels = perf_levels.each_with_index.map do |level, _i|
  lc = mean * level / 100
  nstart = data.bsearch_index { |n| n >= lc }
  nstart ||= samples
  num = nstart * 1_000_000.0 / samples
  start = nstart
  [level, num]
end

perf_num_levels.each do |level, num|
  printf "noise.%d%%: %g\n", 100 - level, num
end
