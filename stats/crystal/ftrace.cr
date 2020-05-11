#!/usr/bin/env crystal

require "fileutils"
require "yaml"

RESULT_ROOT = ENV["RESULT_ROOT"]
TIME_DELTA = YAML.load_file(RESULT_ROOT + "/job.yaml")["time_delta"].to_f
FMT_DIR = RESULT_ROOT + "/trace_event/"

KEY_PREFIX_MAPPING = YAML.load_file(File.dirname(__FILE__) + "/../etc/ftrace_key_prefix")
BDI_DEV_MAPPING = YAML.load_file(RESULT_ROOT + "/bdi_dev_mapping") if File.exists? RESULT_ROOT + "/bdi_dev_mapping"

# A hash to make sure we record one event data only
# for each event in 1s unit
records = Hash.new { |h, k| h[k] = {} }

def generate_prefix(event, key_prefix_items, record)
  key_prefix = event
  key_prefix_items.each do |key|
    v = record[key]
    next if v.nil? || v == ""

    if key == "bdi"
      break unless BDI_DEV_MAPPING

      dev = BDI_DEV_MAPPING[v]
      break unless dev

      key_prefix += "." + dev
    else
      key_prefix += "." + key + "." + record[key]
    end
  end
  key_prefix
end

def normlize_record(event, record, key_prefix_items, records)
  key_prefix = generate_prefix event, key_prefix_items, record

  record["time"] = (record["time"].to_f + TIME_DELTA).floor.to_s
  return if records["last_recorded_time"][key_prefix] == record["time"]

  records["last_recorded_time"][key_prefix] = record["time"]

  records["yaml_files"][key_prefix] ||= File.new(RESULT_ROOT + "/" + "ftrace.#{key_prefix}.yaml", "w", 0o664)

  record.each do |k, v|
    next if key_prefix_items.includes? k
    # we store digit only
    next unless v =~ /^-?\d+(\.\d+)?$/

    records["yaml_files"][key_prefix].puts "#{k}: #{v}"
  end
end

def normlize_event_data(event, event_data, records)
  begin
    key_prefix_items = KEY_PREFIX_MAPPING[event].split(" ")
  rescue StandardError
    key_prefix_items = []
  end

  record = {}
  file = File.open(event_data)
  while (line = file.gets)
    if line == "" && !record["time"].nil?
      normlize_record event, record, key_prefix_items, records
      record = {}
      next
    end
    k, v = line.split(": ")
    record[k] = v
  end
  file.close
  File.delete event_data
end

#
# Parse an event in three steps:
# - generate a sed event parser based on event format
# - invoke generated event parser
# - normlize data generated at above step
#
def parse_event(event_fmt, records)
  %x[cat #{event_fmt}] =~ /print fmt: "([^"]*)".*$/
  fmt = $1
  return if fmt.nil?

  event = File.basename(event_fmt, ".fmt")
  pattern = " ([0-9]\+\\.[0-9]\+): #{event}: "
  replace = 'time: \\1\\n'
  index = 2
  while fmt =~ /([a-zA-Z_]+[ =]%(s|l?[ud]):? *)/
    item = $1
    key, = item.split(/[ =]/)
    pattern += item
    replace += "#{key}: $#{index}\\n"
    fmt = fmt.sub(item, "")
    index += 1
  end

  pattern = pattern.gsub("%s", "(.*)")
  pattern = pattern.gsub(/%l?u/, "([0-9]\+)")
  pattern = pattern.gsub(/%l?d/, "(\-?[0-9]\+)")
  replace += '\\n'

  event_parser = FMT_DIR + event + ".sh"
  event_parser_out = FMT_DIR + event + ".out"
  File.open(event_parser, "w") do |file|
    file.puts "grep -F ' #{event}: ' #{ARGV[0]} | perl -pe 's/^.*#{pattern}.*$/#{replace}/' > #{event_parser_out}"
  end

  FileUtils.chmod "+x", event_parser
  system "/bin/bash #{event_parser}"

  normlize_event_data(event, event_parser_out, records)
end

Dir["#{FMT_DIR}/*.fmt"].each do |event_fmt|
  parse_event event_fmt, records
end
