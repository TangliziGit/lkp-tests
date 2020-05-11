#!/usr/bin/env crystal

STDIN.gets
STDIN.gets

num_objs = 0
num_pages = 0

while (line = STDIN.gets)
  v = line.split
  pagesperslab = v[5].to_i
  num_slabs = v[14].to_i
  num_pages += num_slabs * pagesperslab
  num_objs += v[2].to_i
end

puts "num_objs: " + num_objs.to_s
puts "num_pages: " + num_pages.to_s
