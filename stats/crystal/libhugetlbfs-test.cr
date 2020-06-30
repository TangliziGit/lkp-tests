#!/usr/bin/env crystal

result = Hash(String, Int32).new

while (line = STDIN.gets)
  case line
  when /(32|64)\):\s+(PASS|FAIL|ignored by lkp)/
    name = "#{$1}bit.#{line.split("(")[0].rstrip.tr("[ .]", "_")}".downcase
    res = $2.tr(" ", "_").downcase
    ret = name + "." + res
    ret = name + "_again" + "." + res if (line =~ /[xB|xBDT]\.linkshare/) && result.has_key?(ret)
    result[ret] = 1
  when /(32|64)\):\s+Bad/
    ret = "#{$1}bit.#{line.split("(")[0].rstrip.tr("[ .]", "_")}.bad_configuration".downcase
    result[ret] = 1
  when /(32|64)\):\s+/
    ret = "#{$1}bit.#{line.split("(")[0].rstrip.tr("[ .]", "_")}.killed_by_signal".downcase
    result[ret] = 1
  end
end

result["total_test"] = result.size

result.each do |k, v|
  puts "#{k}: #{v}"
end
