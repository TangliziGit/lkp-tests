#!/usr/bin/env crystal


require "../../lib/statistics"
require "../../lib/string_ext"

stats = []
testname = nil
mqueue_speed = {}
tests_stats = Hash.new { |h, k| h[k] = {} }

def futex_stat_result(futex, result, stats)
  stats << if futex["argument"] && !(futex["argument"].includes? "none")
    "futex.#{futex["subtest"]}.#{futex["argument"]}.#{result.downcase}: 1"
  else
    "futex.#{futex["subtest"]}.#{result.downcase}: 1"
  end
  futex["argument"] = nil
end

def futex_stat(line, futex, stats)
  case line
  when /^(futex.+): /, /# (futex.+): /
    futex["subtest"] = $1
  when /^\s+Arguments: (.+)/, /^# \s+Arguments: (.+)/
    futex["argument"] = $1.tr(" ", "_")
  when /Result\:\s+(PASS|FAIL)/, /^selftests\:.*(PASS|FAIL)/, /^(ok|not ok) \d+/
    result = $1 == "ok" || $1 == "PASS" ? "PASS" : "FAIL"
    futex_stat_result(futex, result, stats)
  end
end

def memory_hotplug_stat(line, memory_hotplug, stats)
  case line
  when /selftests.*: (.+\.sh)/
    memory_hotplug["subtest"] = $1
  when /^\.\/(.+\.sh).+selftests: memory-hotplug/ # for kernel < v4.18-rc1
    memory_hotplug["subtest"] = $1
  when /^*selftests.*: memory-hotplug \[FAIL\]/
    stats << "memory-hotplug.#{memory_hotplug["subtest"]}.fail: 1"
    memory_hotplug["subtest"] = nil
  when %r{make: Leaving directory .*/(.*)'}
    stats << "memory-hotplug.#{memory_hotplug["subtest"]}.pass: 1" if memory_hotplug["subtest"]
  end
end

# for kernel < v4.18-rc1
def mount_stat(line, mount, stats)
  case line
  when %r{if .* then ./(.*) ; else echo}
    mount["subtest"] = $1
  when /^WARN\: No \/proc\/self\/uid_map exist, test skipped/
    stats << "mount.#{mount["subtest"]}.skip: 1"
    mount["subtest"] = nil
  when /(^(MS.+|Default.+) malfunctions$)|(^Mount flags unexpectedly changed after remount$)/
    stats << "mount.#{mount["subtest"]}.fail: 1"
    mount["subtest"] = nil
  when %r{make: Leaving directory .*/(.*)'}
    stats << "mount.#{mount["subtest"]}.pass: 1" if mount["subtest"]
  end
end

def x86_stat(line, _x86, stats)
  case line
  when /can not run MPX tests/
    @pmx = "skip"
  when /^*selftests.*: (.*) .*(PASS|FAIL)/
    test_name = $1.strip
    result = $2
    if test_name =~ /mpx-mini-test/ && @pmx
      stats << "x86.#{test_name}.#{@pmx}: 1"
    else
      stats << "x86.#{test_name}.#{result.downcase}: 1"
      @pmx = nil
    end
  end
end

def vm_stat(line, _vm, stats)
  case line
  when /^*running (.*)/
    @vm_subname = $1.strip.tr(" ", "_")
  when /^\[(PASS|FAIL|ignored_by_lkp)\]/
    stats << "vm.#{@vm_subname}.#{$1.downcase}: 1" if @vm_subname
    @vm_subname = nil
  end
end

def resctrl_stat(line, _resctrl, stats)
  if line =~ /^not ok (.*)/
    test_content = $1.strip.tr(": ", "_")
    stats << "resctrl.#{test_content}.fail: 1"
  end
end

while (line = STDIN.gets)
  line = line.remediate_invalid_byte_sequence(replace: "_") unless line.valid_encoding?

  case line
  when %r{make: Entering directory .*/(.*)'}
    testname = Regexp.last_match[1]
  when /^ok kernel supports resctrl filesystem/
    testname = "resctrl"
  when %r{make: Leaving directory .*/(.*)'}
    if testname == "memory-hotplug"
      memory_hotplug_stat(line, tests_stats["memory-hotplug"], stats)
    elsif testname == "mount"
      mount_stat(line, tests_stats["mount"], stats)
    else
      # rli9 FIXME: consider the input has messed text like Entering doesn't match with Leaving
      testname = nil
    end
  when /^*selftests.*: (.*) .*(\[|\[ )(PASS|FAIL|SKIP)/
    if testname == "futex"
      futex_stat(line, tests_stats["futex"], stats)
    elsif testname == "memory-hotplug"
      memory_hotplug_stat(line, tests_stats["memory-hotplug"], stats)
    elsif testname == "x86"
      x86_stat(line, tests_stats["x86"], stats)
    elsif testname == "vm"
      vm_stat(line, tests_stats["vm"], stats)
    else
      stats << "#{testname}.#{Regexp.last_match[1].strip}.#{Regexp.last_match[3].downcase}: 1"
    end
  when /Test #([1-9].*):/
    mqueue_test = Regexp.last_match[1]
  when /(Send|Recv) msg:/
    io = Regexp.last_match[1]
  when %r{(\d+) nsec/msg}
    mqueue_speed[mqueue_test + "." + io] = Regexp.last_match[1].to_i
  when /: recipe for target.+failed$/
    next unless testname

    # do not count make fail in nr_test, which is for sub test number
    stats << "#{testname}.make_fail: 1"
  when /^ignored_by_lkp (.*) test/
    stats << "#{$1}.ignored_by_lkp: 1"
  when /^(ok|not ok) \d+ selftests: (\S*): (\S*)( # SKIP)?/
    testname = $2 + "." + $3
    result = $4 =~ /SKIP/ ? "skip" : "fail"
    result = "pass" if $1 == "ok"
    stats << "#{testname}.#{result}: 1"
  else
    if testname == "futex"
      futex_stat(line, tests_stats["futex"], stats)
    elsif testname == "memory-hotplug"
      memory_hotplug_stat(line, tests_stats["memory-hotplug"], stats)
    elsif testname == "mount"
      mount_stat(line, tests_stats["mount"], stats)
    elsif testname == "x86"
      x86_stat(line, tests_stats["x86"], stats)
    elsif testname == "vm"
      vm_stat(line, tests_stats["vm"], stats)
    elsif testname == "resctrl"
      resctrl_stat(line, tests_stats["resctrl"], stats)
    end
  end
end

stats << "mqueue.nsec_per_msg: #{mqueue_speed.values.average.to_i}" unless mqueue_speed.empty?
if testname == "resctrl"
  stats << "resctrl.resctrl_tests.pass: 1" unless stats.any? { |stat| stat =~ /resctrl\..+\.fail: 1/ }
end
stats.uniq.each { |stat| puts stat }
nr_test = stats.size { |k, _v| k !~ /\.make_fail|\.ignored_by_lkp/ }
