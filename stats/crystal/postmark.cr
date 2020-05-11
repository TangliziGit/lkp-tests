#!/usr/bin/env crystal

keys = %w(transactions files_created creation_alone creation_mixed_trans
  files_read files_appended files_deleted deletion_alone
  deletion_mixed_trans data_read data_written)

while (line = STDIN.gets)
  case line
  when /^[0-9. ]+$/
    data = line.split
    data[2..-1].each_with_index do |v, i|
      puts "#{keys[i]}: #{v}"
    end
    exit
  end
end
