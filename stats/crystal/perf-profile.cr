#!/usr/bin/env crystal
# First line of perf report:
#
# with --header argument:
#   # ========
#   # captured on: Fri Aug  9 11:08:46 2013
#   ...
#
# without --header argument:
#   # To display the perf.data header info, please use --header/--header-only options.
#   #
#   # Samples: 1M of event 'cpu-cycles'
#   Event count (approx.): 793779025152
#   ...
#
exit unless STDIN.gets =~ /^# ========$| --header/

def fixup_symbol_name(symbol)
  symbol.gsub(/\.(isra|constprop|part)\.[0-9]+/, "")
end

# Bypass lines before cs records:
#   ... <BYPASS> ...
#   # Events: 342  context-switches
#   #
#   # Overhead          Command      Shared Object                     Symbol
#   # ........  ...............  .................  .........................
#   #

cur_event = ""

while (line = STDIN.gets)
  # Events: 1K cycles
  # Events: 825  cache-misses
  # Samples: 5K of event 'cycles'
  # Samples: 489  of event 'cache-misses'
  next unless line =~ /^# Events: \d+[KMG ]\s+(.*)$/ || line =~ /^# Samples: \d+[KMG ] of event (.*)$/

  # cur_event = $'.tr(":", "-").tr('\'', "")
  cur_event = $1.tr(":", "-").tr("\\", "")
  # cur_event = $'.tr(':', '-').tr('\'', '').chomp
  break
end

results = Hash.new(0)

while (line = STDIN.gets)
  case line

  # Bypass lines before record begin:
  #   ... <BYPASS> ...
  #       0.38%  qemu-system-x86  [kernel.kallsyms]         [k] _spin_lock_irqsave
  #
  when /^\# /
    next
  when /^\# Events: \d+[KMG ]\s+/,
       /^# Samples: \d+[KMG ] of event /
    cur_event = $'.tr(":", "-").tr('\'', "")

    # 93.48%    93.48%  [kernel.kallsyms]   [k] clear_page_c_e
    # 96.02%     0.20%  [kernel.kallsyms]   [k] entry_SYSCALL_64_after_hwframe      -      -
  when /^\s*(\d+\.\d+)%\s+(\d+\.\d+)%\s+\S+\s+\S+\s+(\S+)(\s+\S+\s+\S+)?\s*$/
    symbol = fixup_symbol_name $3
    results["children." + "#{cur_event}.#{symbol}"] += $1.to_f
    results["self." + "#{cur_event}.#{symbol}"] += $2.to_f

    # 0.10% entry_SYSCALL_64_fastpath;__write_nocancel;run_builtin;main;__libc_start_main
  when /^(\d+\.\d+)%\s+(\S+)$/

    # base_percent  is like 0.10
    # symbol_name is like entry_SYSCALL_64_fastpath.__write_nocancel.run_builtin;main.__libc_start_main
    base_percent = $1.to_f

    # We only record max 5 leves of call stack
    function_names = $2.split(";")[0, 5].map { |s| fixup_symbol_name s }
    symbol_name = "calltrace.#{cur_event}.#{function_names.join(".")}"
    results[symbol_name] += base_percent
  end
end

results = results.sort_by do |k, v|
  fields = k.split "."
  [fields[1], fields[0], -v]
end
results.each do |record, percent|
  puts "#{record}: #{format("%.2f", percent)}" if percent >= 0.05
end
