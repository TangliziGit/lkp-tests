#!/usr/bin/env crystal
LKP_SRC = ENV["LKP_SRC"] || File.dirname(File.dirname(File.realpath(PROGRAM_NAME)))

require "time"
require "json"
require "fileutils"
require "#{LKP_SRC}/lib/log"

# The below is an example of mpstat output, read it then parse it into hash data.
# {"sysstat": {
#   "hosts": [
#     {
#       "nodename": "haiyan",
#       "sysname": "Linux",
#       "release": "4.19.0",
#       "machine": "x86_64",
#       "number-of-cpus": 4,
#       "date": "2019-02-25",
#       "statistics": [
#           {
#             "timestamp": "15:56:25",
#             "cpu-load": [
#                         {cpu": "-1", "usr": 25.32, "nice": 0.00, "sys": 0.25 ...},
#                         {"cpu": "0", "usr": 100.00, "nice": 0.00, "sys": 0.00 ...},
#                          ...],
#              "node-load": [
#                      {"node": "all", "usr": 25.32, "nice": 0.00, "sys": 0.25,
#                                "iowait": 0.00, "irq": 0.00, "soft": 0.00 ...},
#                      {"node": "0", "usr": 25.32, "nice": 0.00, "sys": 0.25,
#                       "iowait": 0.00, "irq": 0.00, "soft": 0.00, "steal": 0.00 ...}
#                       ...]
#            {
#              "timestamp": "15:56:26",
#              "cpu-load": [ ...]
#               ...
#             },

if ARGV[0]
  mpstat = ARGV[0]
elsif ENV["RESULT_ROOT"]
  RESULT_ROOT = ENV["RESULT_ROOT"]
  mpstat = "#{RESULT_ROOT}/mpstat"
end

# Read the first line of mpstat, check if it is the old format.
# "Linux 5.0.0-rc4 (ivb44) \t2019-02-23 \t_x86_64_\t(48 CPU)\n"
File.open(mpstat) do |file|
  header = file.gets
  if header =~ /Linux\s+\d+\.\d+\.\d+-.* \(.*\) \t\d+-\d+-\d+ \t_.*_.*_\t\(\d+ CPU\)/
    log_error "Mpstat is not JSON format, skip to parse #{mpstat}."
    exit
  end
end

mpstat_json = File.read(mpstat)
begin
  mpstat_hash = JSON.parse(mpstat_json)
rescue JSON::ParserError
  # The mpstat file may meet 2 kinds of uncomplete format:
  # If mpstat file end with string "},", need to delete "," , then complete json format.
  # If mpstat file end with "}", need to complete the missing string
  # "\n\t\t\t\]\n\t\t\}\n\t\]\n\}\}\n".
  begin
    mpstat_update = ENV["RESULT_ROOT"] ? File.join(ENV["RESULT_ROOT"], "mpstat_update") : "/tmp/mpstat_update-#{ENV["USER"]}"

    FileUtils.cp(mpstat, mpstat_update)
    File.open(mpstat_update, "r+") do |io|
      io.seek(-2, IO::SEEK_END)
      str = io.gets
      if str == ",\n"
        io.seek(-2, IO::SEEK_END)
        io.truncate(io.pos)
        io.puts "\n\t\t\t\]\n\t\t\}\n\t\]\n\}\}\n"
      elsif str == "\t\}"
        io.seek(0, IO::SEEK_END)
        io.puts "\n\t\t\t\]\n\t\t\}\n\t\]\n\}\}\n"
      end
    end

    mpstat_json = File.read(mpstat_update)
    FileUtils.rm_f mpstat_update unless ENV["RESULT_ROOT"]
    mpstat_hash = JSON.parse(mpstat_json)
  rescue JSON::ParserError => e
    log_error "Fail to parse #{mpstat}: #{e}"
    exit
  rescue StandardError => e
    log_error "Fail to handle #{mpstat}: #{e}"
    exit
  end
end

results = {}
# Every array data includes some hash type data.
# Such as: "cpu-load" => [{"cpu" => "all", "usr" => 3.06,
#                        "nice" => 0.00, "sys" => 5.87, ... }, {...}, ...]
def get_array_result(prefix, array, results)
  array.each do |item|
    next unless item.class == Hash

    key0, value0 = item.first
    item.each_key do |k_|
      next if k_ == key0

      key = case prefix
            when /node-load/
              "node.#{value0}.#{k_}%"
            when /cpu-load/
              "cpu.#{value0}.#{k_}%"
            else
              "#{prefix}.#{value0}.#{k_}"
            end
      results[key] = item[k_]
    end
  end
end

def get_hash_result(prefix, hash, results)
  hash.each do |k, v|
    key = "#{prefix}.#{k}"
    results[key] = v
  end
end

def display_result(hash)
  hash.each do |key, value|
    next if key.to_s.empty?

    # display key and value as below format:
    # "cpu.all.usr%: 3.06"
    puts "#{key}: #{value}"
  end
end

data = mpstat_hash["sysstat"]["hosts"][0]["date"]
mpstat_hash["sysstat"]["hosts"][0]["statistics"].each do |item|
  item.each do |k, v|
    if v.class == Array
      get_array_result k, v, results
    elsif v.class == Hash
      v.each do |k_, v_|
        if v_.class == Array
          get_array_result k_, v_, results
        elsif v_.class == Hash
          get_hash_result k_, v_, results
        else
          results["#{k}.#{k_}"] = v_
        end
      end
    elsif k == "timestamp"
      time = Time.parse([data, v].join(" ")).to_i
      results["time"] = time
    end
  end
  display_result results
end
