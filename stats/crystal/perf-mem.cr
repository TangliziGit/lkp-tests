#!/usr/bin/env crystal

# Example perf-mem report result:
# # Samples: 30  of event 'cpu/mem-loads,ldlat=50/P'
# # Total weight : 5275
# # Sort order   : local_weight,mem,sym,dso,symbol_daddr,dso_daddr,snoop,tlb,locked
# #
# #      Samples  Local Weight  Memory access
# # ............  ............  ........................
# #
#              2  66            L1 or L1 hit
#              2  57            LFB or LFB hit
#              1  1238          LFB or LFB hit
#              1  451           L1 or L1 hit
#              1  399           LFB or LFB hit
#              1  252           Local RAM or RAM hit
#              1  240           Local RAM or RAM hit
#              1  228           L3 miss
#              1  210           L1 or L1 hit
#              1  208           LFB or LFB hit
#              1  207           Local RAM or RAM hit
#              1  193           L1 or L1 hit
#              1  128           L1 or L1 hit
#              1  119           L1 or L1 hit
#              1  117           L1 or L1 hit
#              1  112           L1 or L1 hit
#              1  109           L1 or L1 hit
#              1  92            L1 or L1 hit
#              1  89            LFB or LFB hit
#              1  88            L1 or L1 hit
#              1  87            L3 miss
#              1  78            L3 or L3 hit
#              1  76            L1 or L1 hit
#              1  67            L3 or L3 hit
#              1  65            LFB or LFB hit
#              1  63            LFB or LFB hit
#              1  60            L2 or L2 hit
#              1  53            LFB or LFB hit

# # Samples: 34  of event 'cpu/mem-stores/P'
# # Total weight : 34
# # Sort order   : local_weight,mem,sym,dso,symbol_daddr,dso_daddr,snoop,tlb,locked
# #
# #      Samples  Local Weight  Memory access
# # ............  ............  ........................
# #
#             33  0             L1 hit
#              1  0             L1 miss

# Extract perf-mem data from above outputs.
# 1. Read every perf-mem event data, including event name, local weight, samples.
# 2. Output avg_weight_per_mem_access and overall_avg_weight value for every memory access.

PERF_MEM_EVENT = %w(loads stores)

weight = Hash(String|Int32, Int32).new(0)
samples = Hash(String|Int32, Int32).new(0)
event_list = [] of String|Nil
event_name = nil

def get_event_name(str)
  PERF_MEM_EVENT.each do |item|
    return item if str.includes? item
  end
  str
end

def output_result(event_name, weight, samples, event_list)
  total_samples = 0
  total_weight = 0
  unit = "weight"
  unit = "cycles" if PERF_MEM_EVENT.index(event_name)
  weight.each_key do |mem_access|
    total_weight += weight[mem_access]
    total_samples += samples[mem_access]
    if samples[mem_access] > 0
      avg_weight_per_mem_access = weight[mem_access].to_f / samples[mem_access]
      puts "#{event_name}.#{mem_access}.#{unit}: #{avg_weight_per_mem_access}"
    end
  end

  if total_samples > 0
    overall_avg_weight = total_weight.to_f / total_samples
    puts "#{event_name}.overall_avg_#{unit}: #{overall_avg_weight}"
  end
  event_list.push event_name
end

STDIN.each_line do |line|
  case line
  # Samples: 5K of event 'cpu/mem-stores/P'
  # Samples: 25  of event 'cpu/mem-loads,ldlat=50/P'
  when /^#\s+Samples:\s+(\d+)\S?+\s+of\s+event\s+\'(.+)\'/
    if event_name && !weight.empty?
      output_result(event_name, weight, samples, event_list)
      weight.clear
      samples.clear
    end
    str = $2.gsub(/[:\/\\]/, "_")
    event_name = get_event_name(str)

    #             1  292           L1 or L1 hit
  when /\s+(\d+)\s+(\d+)\s+(.+\S)\s+/
    cur_samples = $1.to_i
    local_weight = $2.to_i
    mem_access = $3.gsub(/\s/, "_")
    weight[mem_access] += cur_samples * local_weight
    samples[mem_access] += cur_samples
  end
end

output_result(event_name, weight, samples, event_list) if event_list.index(event_name).nil? && !weight.empty?
