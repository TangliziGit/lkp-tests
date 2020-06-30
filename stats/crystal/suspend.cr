#!/usr/bin/env crystal

cycle = 1
srhash = {} of String => String | Float64 | Int32
srmaxhash = {} of String => String | Int32
phase = "none"
while (line = STDIN.gets)
  case line
  when /^ *.* \[\d{3}\] .... *(\d{1,6}\.\d{6}): suspend_resume: (.*)\[(\d*)\] (.*)/
    timestamp = $1
    step = $2
    id = $3
    stage = $4

    next if step == "timekeeping_freeze"

    # use CPU_ON/OFF + cpu_id as the hash key to avoid bogus duplicate
    step = "#{step}_#{id}" if %w(CPU_ON CPU_OFF).includes? step

    k = "#{step}_#{cycle}"

    if stage == "begin"
      srhash[k] = timestamp
    else
      cost = (timestamp.to_f - srhash[k].to_f) * 1000
      srhash[k] = cost
    end

    case step
    when "suspend_enter"
      srhash["suspend_overall_#{cycle}"] = timestamp if stage == "begin"
    when "machine_suspend"
      if stage == "begin"
        cost = (timestamp.to_f - srhash["suspend_overall_#{cycle}"].to_f) * 1000
        srhash["suspend_overall_#{cycle}"] = cost.to_i
      else
        srhash["resume_overall_#{cycle}"] = timestamp
      end
    when "thaw_processes"
      if stage == "end"
        cost = (timestamp.to_f - srhash["resume_overall_#{cycle}"].to_f) * 1000
        srhash["resume_overall_#{cycle}"] = cost.to_i
        cycle += 1
      end
    when /^dpm_(.*)$/
      phase = if stage == "begin"
                $1
              else
                "none"
              end
    end
  when /^ *.* \[\d{3}\] .... *(\d{1,6}\.\d{6}): device_pm_callback_start: (.*) (.*), parent: .*$/
    timestamp = $1
    bus = $2
    device = $3
    id = "#{bus}_#{device}".tr(" ", "_")
    k = "#{id}_#{phase}_#{cycle}"
    srhash[k] = if srhash.has_key?(k)
                  -1
                else
                  timestamp
                end
  when /^ *.* \[\d{3}\] .... *(\d{1,6}\.\d{6}): device_pm_callback_end: (.*) (.*), err=(\d?)/
    timestamp = $1
    bus = $2
    device = $3.strip
    id = "#{bus}_#{device}".tr(" ", "_")
    kmax = "#{id}_#{phase}"
    k = "#{kmax}_#{cycle}"
    if srhash[k] != -1
      cost = (timestamp.to_f - srhash[k].to_f) * 1000
      srhash[k] = cost.to_i
      srmaxhash[kmax] = 0 if srmaxhash[kmax].nil?
      srmaxhash[kmax] = cost.to_i if srmaxhash[kmax].to_i < cost.to_i
    end
  else
    next
  end
end

srhash.each do |kk, vv|
  case kk
  when /(.*)_\d*/
    kmax = $1
    next if srmaxhash.has_key?(kmax) && srmaxhash[kmax].to_i < 50

    puts "#{kmax}: #{vv}"
  end
end
