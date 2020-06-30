#!/usr/bin/env crystal

stats = Hash(String, String).new

# the log is like:
# ## hdd:ext4:DWAL:2:bufferedio
# # ncpu secs works works/sec real.sec user.sec nice.sec sys.sec idle.sec iowait.sec irq.sec softirq.sec steal.sec guest.sec user.util nice.util sys.util idle.util iowait.util irq.util softirq.util steal.util guest.util
#
# 2 30.009368 3770498.000000 125644.032224 30.0713 0.37 0 9.88 3.55 42.54 0 0.07 0 0 0.615204 0 16.4276 5.90263 70.7318 0 0.11639 0 0

name = Nil

while (line = STDIN.gets)
  case line
  when /^## (hdd|ssd|nvme|mem)(.*)/
    name = line[3..].tr(":", "_")
  when /^# ncpu/
    subname = line[2..].tr(".", "_").split

    datas = STDIN.gets
    break unless datas

    datas = STDIN.gets
    break unless datas

    datas = datas.split
    i = 0
    subname.each do |s|
      stats["#{name}.#{s}"] = datas[i]
      i += 1
    end
  end
end

stats.each do |k, v|
  puts "#{k}: #{v}"
end
