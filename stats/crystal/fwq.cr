#!/usr/bin/env crystal

RESULT_ROOT = ENV["RESULT_ROOT"]

LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))
require "../../lib/noise"

PDEL = 10

data = []
files = Dir["#{RESULT_ROOT}/results/fwq_*_times.dat"]
files.each do |file|
  sfdata = File.read(file).split
  n = sfdata.size
  ndel = n * PDEL / 100
  sfdata.slice!(n - ndel, ndel)
  sfdata.slice!(0, ndel)
  data.concat(sfdata.map(&.to_i))
end

exit if data.empty?

n = Noise.new("fwq", data)
n.analyse
n.log
