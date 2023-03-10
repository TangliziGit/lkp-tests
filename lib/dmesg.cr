#!/usr/bin/env crystal

LKP_SRC = ENV["LKP_SRC"] || File.dirname(__DIR__)

require "./yaml"
require "./constant"
require "logger"

# /c/linux% git grep '"[a-z][a-z_]\+%d"'|grep -o '"[a-z_]\+'|cut -c2-|sort -u
LINUX_DEVICE_NAMES = File.read("#{LKP_SRC}/etc/linux-device-names").split("\n")
LINUX_DEVICE_NAMES_RE = /\b(#{LINUX_DEVICE_NAMES.join("|")})\d+/.freeze

#require "fileutils"
#require "tempfile"

# dmesg can be below forms
# [    0.298729] Last level iTLB entries: 4KB 512, 2MB 7, 4MB 7
# [    8.898106] system 00:01: [io  0x0400-0x047f] could not be reserved
class DmesgTimestamp
  getter :timestamp

  def initialize(line)
    match = line.match(/.*\[ *(?<timestamp>\d{1,6}\.\d{6})\]/)
    @timestamp = match && match[:timestamp]
  end

  def valid?
    @timestamp != nil
  end

  def <=>(other)
    return 0 unless valid? || other.valid?
    return -1 unless valid?
    return 1 unless other.valid?

    @timestamp.to_f <=> other.timestamp.to_f
  end

  def to_s
    @timestamp
  end

  # put this functionality inside DmesgTimestamp class for now
  # below patterns are required to match in order to detect
  # abnormal sequence that indicates a possible reboot
  # LARGE timestamp
  # LARGE timestamp
  # LARGE timestamp
  # SMALL timestamp
  # SMALL timestamp
  # SMALL timestamp
  class AbnormalSequenceDetector
    def initialize
      @large_dmesg_timestamps = [] of String
      @small_dmesg_timestamps = [] of String
    end

    # dmesg "[ 0.000000]\n[ 1.000000]\n[ 1.000000]\n[ 2.000000]\n
    #        [ 0.000000]\n[ 0.100000]\n[ 0.200000]" is abnormal
    # dmesg "[ 0.000000]\n[ 1.000000]\n[ 1.000000]\n[ 2.000000]\n[ 1.000000]\n
    #        [ 0.100000]\n[ 0.200000]\n[ 0.300000]" is abnormal
    # dmesg "[ 0.000000]\n[ 1.000000]\n[ 0.000000]\n[ 2.000000]\n[ 1.000000]\n
    #        [ 0.100000]\n[ 0.200000]\n[ 0.300000]" is normal
    def detected?(line)
      dmesg_timestamp = DmesgTimestamp.new(line)
      if dmesg_timestamp.valid?
        if @large_dmesg_timestamps.size < 3 || @large_dmesg_timestamps.any? { |large_dmesg_timestamp| large_dmesg_timestamp <= dmesg_timestamp }
          @large_dmesg_timestamps.push(dmesg_timestamp)
          @large_dmesg_timestamps = @large_dmesg_timestamps.drop(1) if @large_dmesg_timestamps.size > 3

          @small_dmesg_timestamps.clear
        else
          @small_dmesg_timestamps.push(dmesg_timestamp)
        end
      end

      @small_dmesg_timestamps.size >= 3
    end
  end
end

def fixup_dmesg(line)
  line.chomp

  # remove absolute path names
  line.sub(%r{/kbuild/src/[^/]+/}, "")

  line.sub(/\.(isra|constprop|part)\.[0-9]+\+0x/, "+0x")

  # break up mixed messages
  if line =~ /^<[0-9]>|^(kern  |user  |daemon):......: /
  elsif line =~ /(.+)(\[ *[0-9]{1,6}\.[0-9]{6}\] .*)/
    line = $1 + "\n" + $2
  end

  line
end

def fixup_dmesg_file(dmesg_file)
  tempfilename = File.dirname(dmesg_file) + ".fixup-dmesg-"
  tmpfile = File.tempfile(tempfilename)
  dmesg_lines = [] of String
  File.open(dmesg_file, "rb") do |f|
    f.each_line do |line|
      line = fixup_dmesg(line)
      dmesg_lines << line
      tmpfile.puts line
    end
  end
  File.chmod(tempfilename, 0o664)
  tmpfile.close
  FileUtils.mv(tmpfile.path, dmesg_file)
  dmesg_lines
end

# "grep -B1 | grep -v" to get the functions called by them,
# which will hopefully be stable and representive.
CALLTRACE_COMMON_CONTEXT = "
  do_one_initcall|
  do_basic_setup|
  kernel_init_freeable|
  kernel_init|
  kthread|
  kernel_thread|
  process_one_work|
  notifier_call_chain|
"

CALLTRACE_PATTERN = /(
  #{CALLTRACE_COMMON_CONTEXT}
  SyS_[a-z0-9_]+
)\+0x/x

CALLTRACE_IGNORE_PATTERN = /(
  #{CALLTRACE_COMMON_CONTEXT}
  worker_thread|
  warn_slowpath_.*
)\+0x/x

OOM1 = "invoked oom-killer: gfp_mask="
OOM2 = "Out of memory and no killable processes..."

def grep_crash_head(dmesg_file)
  grep = if dmesg_file =~ /\.xz$/
           "xzgrep"
           # cat = 'xzcat'
         else
           "grep"
           # cat = 'cat'
         end

  raw_oops = %x[ #{grep} -a -E -e \\\\+0x -f #{LKP_SRC}/etc/oops-pattern #{dmesg_file} |
       grep -v -E -f #{LKP_SRC}/etc/oops-pattern-ignore ]

  return {} of String => String if raw_oops.empty?

  oops_map = {} of String => String | Nil

  oops_re = load_regular_expressions("#{LKP_SRC}/etc/oops-pattern")
  prev_line = nil
  has_oom = false

  add_one_calltrace = ->(line : String) { oops_map["calltrace:" + $1] ||= line }
  
  add = ->(x : Int32, y : Int32) {x + y}
  add.call(1, 2)

  raw_oops.each_line do |line|
    if line =~ oops_re
      oops_map[$1] ||= line
      has_oom = true if line.index(OOM1)
      has_oom = true if line.index(OOM2)
      next
    end

    # Call Trace:
    if line.index "+0x"
      next if line.index " ? "

      if line =~ CALLTRACE_PATTERN
        oops_map["calltrace:" + $1] ||= prev_line unless line.index("SyS_")
        add_one_calltrace.call(line)
        prev_line = nil
      else
        prev_line = line
      end

      next
    end

    log = Logger.new(STDOUT, level: Logger::WARN)
    log.warn("oops pattern mismatch: #{line}")
  end

  oops_map
end

def grep_printk_errors(kmsg_file, kmsg)
  return "" if ENV.fetch("RESULT_ROOT", "").index "/trinity/"
  return "" unless File.exists?("#{KTEST_USER_GENERATED_DIR}/printk-error-messages")

  grep = if kmsg_file =~ /\.xz$/
           "xzgrep"
         else
           "grep"
         end

  if kmsg_file =~ /\bkmsg\b/
    # the kmsg file is dumped inside the running kernel
    oops = `#{grep} -a -E -e '^<[0123]>' -e '^kern  :(err   |crit  |alert |emerg ): ' #{kmsg_file} |
      sed -r 's/\\x1b\\[([0-9;]+m|[mK])//g' |
      grep -a -v -E -f #{LKP_SRC}/etc/oops-pattern |
      grep -a -v -F -f #{LKP_SRC}/etc/kmsg-blacklist`
  else
    # the dmesg file is from serial console
    oops = `#{grep} -a -F -f #{KTEST_USER_GENERATED_DIR}/printk-error-messages #{kmsg_file} |
      grep -a -v -E -f #{LKP_SRC}/etc/oops-pattern |
      grep -a -v -F -f #{LKP_SRC}/etc/kmsg-blacklist`
    if !kmsg.nil?
      oops += `grep -a -E -f #{LKP_SRC}/etc/ext4-crit-pattern #{kmsg_file}` if kmsg.index "EXT4-fs ("
      oops += `grep -a -E -f #{LKP_SRC}/etc/xfs-alert-pattern #{kmsg_file}` if kmsg.index "XFS ("
      oops += `grep -a -E -f #{LKP_SRC}/etc/btrfs-crit-pattern #{kmsg_file}` if kmsg.index "btrfs: "
    end
  end
  oops
end

def common_error_id(line)
  line = line.chomp
  line.gsub(/\b[3-9]\.[0-9]+[-a-z0-9.]+/, "#") # linux version: 3.17.0-next-20141008-g099669ed
  line.gsub(/\b[1-9][0-9]-[A-Z][a-z]+-[0-9]{4}\b/, "#") # Date: 28-Dec-2013
  line.gsub(/\b0x[0-9a-f]+\b/, "#") # hex number
  line.gsub(/\b[a-f0-9]{40}\b/, "#") # SHA-1
  line.gsub(/\b[0-9][0-9.]*/, "#") # number
  line.gsub(/#x\b/, "0x")
  line.gsub(/[\\"$]/, "~")
  line.gsub(/[ \t]/, " ")
  line.gsub(/\ \ +/, " ")
  line.gsub(/([^a-zA-Z0-9])\ /, "\1")
  line.gsub(/\ ([^a-zA-Z])/, "\1")
  line.gsub(/^\ /, "")
  line.gsub(/\  _/, "_")
  line.tr(" ", "_")
  line.gsub(/[-_.,;:#!\[\(]+$/, "")
  line
end

# # <4>[  256.557393] [ INFO: possible circular locking dependency detected ]
#  INFO_possible_circular_locking_dependency_detected: 1

def oops_to_bisect_pattern(line)
  words = line.split
  return "" if words.empty?
  return line if words.size == 1

  patterns = [] of String
  words.each do |w|
    case w
    when /([a-zA-Z0-9_]+)\.(isra|constprop|part)\.[0-9]+\+0x/
      patterns << $1
      break
    when /([a-zA-Z0-9_]+\+0x)/, /([a-zA-Z0-9_]+=)/
      patterns << $1
      break
    when /[^a-zA-Z\/:.()!_-]/
      patterns << ".*" if patterns[-1] != ".*"
    else
      patterns << w
    end
  end
  while patterns[0] == ".*"
    patterns.shift
  end  
  patterns.pop if patterns[-1] == ".*"
  patterns.join(" ")
end

def analyze_error_id(line)
  line = line.sub(/^(kern  |user  |daemon):......: /, "")
  line.sub(/^[^a-zA-Z]+/, "")
  # line.sub!(/^\[ *[0-9]{1,6}\.[0-9]{6}\] )/, '') # the above pattern includes this one

  case line
  when /(INFO: rcu[_a-z]* self-detected stall on CPU)/,
       /(INFO: rcu[_a-z]* detected stalls on CPUs\/tasks:)/,
       /(BUG: unable to handle kernel)/,
       /(BUG: unable to handle kernel) NULL pointer dereference/,
       /(BUG: unable to handle kernel) paging request/,
       /(BUG: scheduling while atomic:)/,
       /(BUG: Bad page map in process)/,
       /(BUG: Bad page state in process)/,
       /(BUG: soft lockup - CPU#\d+ stuck for \d+s!.*)/,
       /(BUG: spinlock .* on CPU#\d+)/,
       /(Out of memory: Kill process) \d+ \(/,
       # old format: "[  122.209638 ] ??? Writer stall state 8 g62150 c62149 f0x2"
       # new format: "[  122.209638 ] ??? Writer stall state RTWS_STUTTER(8) g62150 c62149 f0x2"
       /(Writer stall state \w*).+ g\d+ c\d+ f/,
       /(BUG: workqueue lockup - pool)/,
       /(rcu_sched kthread starved) for \d+ jiffies/,
       /(Could not create tracefs)/,
       /(used greatest stack depth:)/,
       /([A-Z]+[ a-zA-Z]*): [a-f0-9]{4} \[#[0-9]+\] /,
       /(BUG: KASAN: [a-z\-_ ]+ in [a-z])/,
       /(cpu clock throttled)/
    line = $1
    bug_to_bisect = $1
  when /(BUG: ).* (still has locks held)/,
       /(INFO: task ).* (blocked for more than \d+ seconds)/
    line = $1 + $2
    bug_to_bisect = $2
  when /WARNING:.* at .* ([a-zA-Z.0-9_]+\+0x)/
    bug_to_bisect = "WARNING:.* at .* " + $1.sub(/\.(isra|constprop|part)\.[0-9]+\+0x/, "")
    line =~ /(at .*)/
    line = "WARNING: " + $1
  when /(Kernel panic - not syncing: No working init found.)  Try passing init= option to kernel. /,
       /(Kernel panic - not syncing: No init found.)  Try passing init= option to kernel. /
    line = $1
    bug_to_bisect = line
  when /(BUG: key )[0-9a-f]+ (not in .data)/
    line = $1 + $2
    bug_to_bisect = $1 + ".* " + $2
  when /(BUG: using smp_processor_id\(\) in preemptible)/
    line = $1
    bug_to_bisect = oops_to_bisect_pattern line
    # printk(KERN_ERR "BUG: Dentry %p{i=%lx,n=%pd} still in use (%d) [unmount of %s %s]\n"
  when /(BUG: Dentry ).* (still in use) .* \[unmount of /
    line = $1 + $2
    bug_to_bisect = $1 + ".* " + $2
  when /^backtrace:([a-zA-Z0-9_]+)/,
       /^calltrace:([a-zA-Z0-9_]+)/
    bug_to_bisect = $1 + "+0x"
  when /Corrupted low memory at/
    # [   61.268659] Corrupted low memory at ffff880000007b08 (7b08 phys) = 27200c000000000
    bug_to_bisect = oops_to_bisect_pattern line
    line = line.sub(/\b[0-9a-f]+\b phys/, "# phys").sub(/= \b[0-9a-f]+\b/, "= #")
  when /kobject \(([0-9a-f]+|\(_*ptrval_*\))\): tried to init an initialized object/
    # [  512.848747] kobject (ca296866): tried to init an initialized object, something is seriously wrong.
    # [   50.433242] kobject ((ptrval)): tried to init an initialized object, something is seriously wrong.
    # [   36.605689] kobject ((____ptrval____)): tried to init an initialized object, something is seriously wrong.
    bug_to_bisect = oops_to_bisect_pattern line
    line = line.sub(/kobject \(([0-9a-f]+|\(_*ptrval_*\))\)/, "kobject (#)")
  when /BUG: Bad rss-counter state mm:([0-9a-f]+|\(_*ptrval_*\)) idx:/
    # [   70.951419 ] BUG: Bad rss-counter state mm:(____ptrval____) idx:1 val:4
    # [ 2841.215571 ] BUG: Bad rss-counter state mm:000000000fb13173 idx:1 val:-1
    # [   11.380524 ] BUG: Bad rss-counter state mm:(ptrval) idx:1 val:1
    bug_to_bisect = oops_to_bisect_pattern line
    line = line.sub(/BUG: Bad rss-counter state mm:([0-9a-f]+|\(_*ptrval_*\)) idx:/, "BUG: Bad rss-counter state mm:# idx:")
  when /Bad pagetable: [0-9a-f]+ \[#/
    # [   29.493015 ] Bad pagetable: 000f [#1] PTI
    # [    9.167214 ] Bad pagetable: 001d [#1] PTI
    # [    9.170529 ] Bad pagetable: 0009 [#2] PTI
    bug_to_bisect = oops_to_bisect_pattern line
    line = line.sub(/Bad pagetable: [0-9a-f]+ \[#/, "Bad pagetable: # [#")
  when /(INFO: Slab 0x\(____ptrval____\) objects=.*fp=0x).* (flags=.*)/
    # [   16.160017 ] INFO: Slab 0x(____ptrval____) objects=23 used=23 fp=0x          (null) flags=0x10201
    # [   12.344185 ] INFO: Slab 0x(____ptrval____) objects=22 used=11 fp=0x(____ptrval____) flags=0x10201
    bug_to_bisect = oops_to_bisect_pattern line
    line = $1 + "(#) " + $2
  else
    bug_to_bisect = oops_to_bisect_pattern line
  end

  error_id = line

  error_id.gsub(/\ \]$/, "") # [ INFO: possible recursive locking detected ]
  error_id.gsub(/\/c\/kernel-tests\/src\/[^\/]+\//, "")
  error_id.gsub(/\/c\/(wfg|yliu)\/[^\/]+\//, "")
  error_id.gsub(/\/lkp\/[^\/]+\/linux[0-9]*\//, "")
  error_id.gsub(/\/kernel-tests\/linux[0-9]*\//, "")
  error_id.gsub(/\.(isra|constprop|part)\.[0-9]+/, "")

  # [   31.694592] ADFS-fs error (device nbd10): adfs_fill_super: unable to read superblock
  # [   33.147854] block nbd15: Attempted send on closed socket
  # /c/linux-next% git grep -w 'register_blkdev' | grep -o '".*"'
  error_id.gsub(/\b(bcache|blkext|btt|dasd|drbd|fd|hd|jsfd|lloop|loop|md|mdp|mmc|nbd|nd_blk|nfhd|nullb|nvme|pmem|ramdisk|scm|sd|simdisk|sr|ubd|ubiblock|virtblk|xsysace|zram)\d+/, "\1#")

  #error_id.gsub LINUX_DEVICE_NAMES_RE, "\1#"

  error_id.gsub(/\b[0-9a-f]{8}\b/, "#")
  error_id.gsub(/\b[0-9a-f]{16}\b/, "#")
  error_id.gsub(/(=)[0-9a-f]+\b/, "\1#")
  error_id.gsub(/[+\/]0x[0-9a-f]+\b/, "")
  error_id.gsub(/[+\/][0-9a-f]+\b/, "")

  error_id = common_error_id(error_id)

  error_id.gsub(/([a-z]:)[0-9]+\b/, "\1") # WARNING: at arch/x86/kernel/cpu/perf_event.c:1077 x86_pmu_start+0xaa/0x110()
  error_id.gsub(/#:\[<#>\]\[<#>\]/, "") # RIP: 0010:[<ffffffff91906d8d>]  [<ffffffff91906d8d>] validate_chain+0xed/0xe80
  error_id.gsub(/RIP:#:/, "RIP:")       # RIP: 0010:__might_sleep+0x72/0x80

  [error_id, bug_to_bisect]
end

def get_crash_stats(dmesg_file)
  if dmesg_file =~ /\.xz$/
    `xz -d -k #{dmesg_file}`
    uncompressed_dmesg = dmesg_file.gsub(/\.xz$/, "")
    dmesg_file = uncompressed_dmesg
  end

  boot_error_ids = `#{LKP_SRC}/stats/dmesg #{dmesg_file}`

  oops_map = {} of String => String
  id = ""
  new_error_id = false
  boot_error_ids.each_line do |line|
    line.chomp!
    if line =~ /^# /
      new_error_id = true
      next
    end

    if new_error_id
      # WARNING:at_kernel/locking/lockdep.c:#lock_release: 1
      id = line.split(": ")[0..-2].join(": ")
      new_error_id = false
      next
    end

    next unless line =~ /^message:/

    # message:WARNING:at_kernel/locking/lockdep.c:#lock_release: [   11.858566 ] WARNING: CPU: 0 PID: 11 at kernel/locking/lockdep.c:3536 lock_release+0x179/0x3b7
    #
    oops_map[id] = line.split(": ")[1..-1].join(": ")
  end

  FileUtils.rm uncompressed_dmesg if uncompressed_dmesg

  oops_map
end

def get_content(dmesg_file)
  if dmesg_file =~ /\.xz$/
    `xz -d -k #{dmesg_file} --stdout`
  else
    File.read(dmesg_file)
  end
end

CALLTRACE_LIMIT_LEN = 100

def get_crash_calltraces(dmesg_file)
  dmesg_content = get_content(dmesg_file)

  calltraces = [] of String
  index = 0
  line_count = 0
  in_calltrace = false

  dmesg_content.each_line do |line|
    if line =~ / BUG: | WARNING: | INFO: | UBSAN: | kernel BUG at /
      in_calltrace = true
      calltraces[index] ||= ""
      calltraces[index] << line
      line_count = 1
    elsif line.index("---[ end trace ") && in_calltrace
      in_calltrace = false
      calltraces[index] << line
      index += 1
    elsif in_calltrace
      calltraces[index] << line
      line_count += 1
      if line_count > CALLTRACE_LIMIT_LEN
        line_count = 0
        in_calltrace = false
        index += 1
      end
    end
  end

  calltraces
end
