#!/usr/bin/env crystal

exit unless STDIN.gets =~ /lock_stat version 0.[34]/
exit unless STDIN.gets =~ /---------------------/

names = STDIN.gets.to_s.split
names.shift
names.shift

contentions = {} of String => Int32
lock_stat = {} of String => Int32|Float64
lock = ""
while (line = STDIN.gets)
  line = line.sub(%r{/c/kernel-tests/src/[^/]+/}, "")
  line = line.sub(%r{/kbuild/src/[^/]+/}, "")
  case line
  when / +(.+): +([0-9.]+ +[0-9.]+ +[0-9.]+ +.*)/
    lock = $1.tr(" ", "")
    values = $2.split
    values.each_with_index do |value, i|
      lock_stat[lock + "." + names[i]] ||= 0
      lock_stat[lock + "." + names[i]] += names[i] =~ /time/ ? value.to_f : value.to_i
    end
  when / +(\d+) +\[<[0-9a-f]+>\] ([a-zA-Z0-9_]+)/
    contentions[$2] ||= 0
    contentions[$2] += $1.to_i
  when /^$/
    unless contentions.empty?
      lock = lock.chomp
      contentions.each do |key, val|
        lock_stat[lock + ".contentions." + key] ||= 0
        lock_stat[lock + ".contentions." + key] += val
      end
      contentions.clear
    end
  end
end

lock_stat.each do |k, v|
  puts k + ": " + v.to_s
end
