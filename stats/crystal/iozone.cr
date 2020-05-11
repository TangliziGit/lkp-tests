#!/usr/bin/env crystal

keys = %w(write rewrite read reread random_read random_write bkwd_read
          record_rewrite stride_read fwrite frewrite fread freread)

per_io_type = Hash(String | String, Int32).new
per_record = Hash(String | String, Int32).new
all_sum = 0
nr_records = 0
while (line = STDIN.gets)
  next unless line =~ /^\s*\d+.*\d+$/

  data = line.split
  data.each_index do |i|
    if data[i].size > 8
      data.insert i + 1, data[i][-8..-1]
      data[i] = data[i][0..-9]
    end
  end
  data[2..-1].each_with_index do |v, i|
    puts data[0] + "KB_" + data[1] + "reclen." + keys[i] + ": " + v
    per_io_type[keys[i]] ||= 0
    per_io_type[keys[i]] += v.to_i
    per_record[data[0] + "KB_" + data[1] + "reclen"] ||= 0
    per_record[data[0] + "KB_" + data[1] + "reclen"] += v.to_i
    all_sum += v.to_i
  end
  nr_records += 1
end
per_io_type.each { |k, v| puts k + "_KBps: " + (v.to_f / keys.size).to_s }
per_record.each { |k, v| puts k + ": " + (v.to_f / nr_records).to_s }
puts "average_KBps: " + (all_sum.to_f / keys.size / nr_records).to_s
