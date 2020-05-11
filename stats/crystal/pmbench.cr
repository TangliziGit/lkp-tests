#!/usr/bin/env crystal

res = 0.0
histo_r = Array.new(24, 0)
histo_w = Array.new(24, 0)
histo_details_r = [] of Int32
histo_details_w = [] of Int32
latencies = [] of Float32
throughput = 0
init_times = [] of Float32
sum_r = 0.0
sum_w = 0.0
mode = nil
READ = :read
WRITE = :write

@@stdin.each_line do |line|
  case line
  when /^Read:/
    mode = READ
  when /^Write:/
    mode = WRITE
  when /^  Page latency during benchmark \(inc. gen\): (\d+\.\d+) us \(\d+ clks\)/
    latencies << $1.to_f
  when / Benchmark done - took (\d+\.\d+) sec for (\d+) page access/
    throughput += $2.to_f / $1.to_f
  when /nitialization took (\d+\.\d+) ms/
    init_times << $1.to_f / 1000
  when /^2\^\((\d+),(\d+)\) ns: (\d+)  \[(.*)\]/
    end_n = $2.to_i
    cnt = $3.to_i
    p = end_n - 8
    data = $4.split(", ")
    data.each_with_index do |v, i|
      if mode == READ
        histo_details_r[p] ||= [] of Int32
        histo_details_r[p][i] ||= 0
        histo_details_r[p][i] += v.to_i
      else
        histo_details_w[p] ||= [] of Int32
        histo_details_w[p][i] ||= 0
        histo_details_w[p][i] += v.to_i
      end
    end
    if mode == READ
      sum_r += cnt
      histo_r[p] += cnt
    else
      sum_w += cnt
      histo_w[p] += cnt
    end
  when /^2\^\((\d+),(\d+)\) ns: (\d+)/
    end_n = $2.to_i
    cnt = $3.to_i
    p = if end_n < 32
          end_n - 8
        else
          end_n - 9
        end
    if mode == READ
      sum_r += cnt
      histo_r[p] += cnt
    else
      sum_w += cnt
      histo_w[p] += cnt
    end
  end
end

def format_power2(num)
  p = 0
  unit = ["", "K", "M", "G"]
  while num > 9
    num -= 10
    p += 1
  end
  (1 << num).to_s + unit[p]
end

def gen_output(mode, i, res)
  if i.zero?
    puts "#{mode}.latency.ns.0-256%: #{res}"
  elsif i == 23
    puts "#{mode}.latency.ns.1G-inf%: #{res}"
  else
    puts "#{mode}.latency.ns.#{format_power2(i + 7)}-#{format_power2(i + 8)}%: #{res}"
  end
end

percentile_strs = %w(90 95 99)
percentiles = percentile_strs.map(&.to_f)

[[histo_r, histo_details_r, sum_r, READ], [histo_w, histo_details_w, sum_w, WRITE]].each do |histo, histo_details, sum, mode|
  pi = 0
  hist_cum = 0
  (0..23).each do |i|
    next if sum == 0.0

    res = histo[i] / sum * 100
    gen_output(mode, i, res)
    if histo_details[i]
      histo_details[i].each_with_index do |v, j|
        res = v / sum * 100
        hist_cum += res
        while pi < percentiles.size && hist_cum >= percentiles[pi]
          puts "#{mode}.latency.#{percentile_strs[pi]}%.ns: #{2 ** (i + 8) + j * 2 ** (i + 4)}"
          pi += 1
        end
      end
    else
      hist_cum += res
      while pi < percentiles.size && hist_cum >= percentiles[pi]
        puts "#{mode}.latency.#{percentile_strs[pi]}%.ns: #{2 ** (i + 8)}"
        pi += 1
      end
    end
  end
end

unless latencies.empty?
  latency_avg = latencies.reduce(:+) / latencies.size
  puts "latency.ns.average: #{latency_avg * 1000}"
end

puts "throughput.aps: #{throughput}"

unless init_times.empty?
  init_time_avg = init_times.reduce(:+) / init_times.size
  puts "init_time.avg: #{init_time_avg}"
end
