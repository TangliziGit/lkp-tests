#!/usr/bin/env crystal

# netperf.workload is defined as the total transaction number or the total
# packet number depended on transmission protocal used in netperf
throughput = 0
num = 0
thp_index = 0
time_index = 0
pkt_index = 0
pkt_size = 1
iterations = 0
unit = ""
time = 0.0
while (line = STDIN.gets)
  line = line.chomp
  case line
  when /^Iterations/
    iterations += 1
  when /^bytes.*secs.*10\^6bits/
    unit = "Mbps"
  when /^bytes.*secs.\s+per sec/
    unit = "tps"
  when /^Socket.*Elapsed.*/
    lines = line.split
    lines.each_with_index do |word, v|
      pkt_index = v if word == "Message"
      time_index = v if word == "Elapsed"
    end
  when /^Send\s+Recv\s+/
    lines = line.split
    lines.each_with_index do |word, v|
      thp_index = v if word == "Rate"
    end
  when /^Size\s+Size\s+/
    lines = line.split
    lines.each_with_index do |word, v|
      thp_index = v if word == "Throughput"
    end
  when /\d+\s+\d+\s+\d+\s+\d.*$/
    data = line.split
    throughput += data[thp_index].to_f
    time = data[time_index].to_f
    pkt_size = data[pkt_index].to_f if unit == "Mbps"
    num += 1
  end
end

exit if num.zero?

avg_throughput = throughput / num

# We only cares for the average total throughput/workload
# within each iteration.

throughput /= iterations if iterations > 0

workload = throughput * time
workload = workload * 10 ** 6 / 8.0 / pkt_size if unit == "Mbps"
puts "Throughput_" + unit + ": " + avg_throughput.to_s
puts "Throughput_total_" + unit + ": " + throughput.to_s
puts "workload: " + workload.to_s
