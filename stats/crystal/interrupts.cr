#!/usr/bin/env crystal

require "set"

cpus = [] of String

STDIN.each_line do |line|
  case line
  when /^time:/
    puts line
  when /^( +CPU[0-9]+ +)+$/
    #            CPU0       CPU1       CPU2       CPU3
    cpus = line.split
  when /^\s*[^\s]+:/
    values = line.split
    if values.size == 2
      # ERR:          0
      # MIS:          0
      puts values[0] + " " + values[1]
    else
      key = if values[0] =~ /^ *[0-9]+:$/
              #   0:         20          0          0          0  IR-IO-APIC-edge      timer
              #   1:     643896          0          0          0  IR-IO-APIC-edge      i8042
              values[0] + values[(cpus.size + 1)..-1].join(".").gsub(",.", ",")
            else
              # NMI:       3706      12681      27809       7041   Non-maskable interrupts
              # LOC:   55868703   55172274   59522354   57162831   Local timer interrupts
              values[0] + values[(cpus.size + 1)..-1].join("_")
            end
      sum = 0
      cpus.each_with_index do |cpu, i|
        val = values[i + 1].to_i
        sum += val
        puts cpu.to_s + "." + key + ": " + values[i + 1]
      end
      puts key + ": " + sum.to_s
    end
  end
end
