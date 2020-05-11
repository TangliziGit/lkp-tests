#!/usr/bin/env crystal

total = {}
while (line = STDIN.gets)
  _i, _start_addr, _end_addr, bytes, type = line.split ","
  next if type.to_s.empty?

  total[type] ||= 0
  total[type] += bytes.to_i
end

total.each do |types, byte|
  printf "%s: %d\n", types.tr(" ", "_"), byte >> 10
end
