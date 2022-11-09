#!/usr/bin/ruby

require 'yaml'

LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

def load_summary(meta, program)
  desc = ''
  stop_record = false
  lines = %x(apt-cache show #{program} 2>/dev/null)
  lines.each_line do |line|
    case line
    when /^Description-en: (.*)/
      desc = ''
      meta['summary'] = $1
    when /^Description-md5/, /^\s*\.\s*$/
      stop_record = true
    when /^Homepage: (.*)$/
      meta['homepage'] = $1
      break
    else
      desc += line.strip unless stop_record
    end
  end
  meta['description'] = desc if !desc.empty?
end

def load_params(hash, path)
  %x(cat #{path} | #{LKP_SRC}/bin/program-options).each_line do |line|
    k = line.split[1]
    puts line
    hash['params'][k] = nil
  end
  if hash['params'].empty?
     hash['params'] = nil
  end
end

def load_depends(depends, program)
  file = "#{LKP_SRC}/distro/depends/#{program}"
  return unless File.exist? file
  depends['debian@11'] ||= []
  File.open(file).each_line do |line|
    next if line =~ /^#/
    depends['debian@11'].concat(line.sub(/#.*/, '').split)
  end
end

# input example: tests/fio
ARGV.each do |path|
  program = File.basename(path)

  dir = File.basename(File.dirname(path))
  case dir
  when 'tests'
    type = 'workload'
    dir = 'programs'
  when 'setup'
    type = 'setup'
  when 'monitors'
    type = 'monitor'
  else
    type = 'monitor'
    monitor_type = dir
  end

  dir = 'programs' # mkdir: cannot create directory ‘/c/lkp-tests/monitors/cpuidle/’: File exists
  dest = "#{LKP_SRC}/#{dir}/#{program}/meta.yaml"

  hash = {}
  hash['metadata'] = {}
  hash['metadata']['name'] = program
  hash['metadata']['summary'] = nil
  hash['metadata']['description'] = nil
  hash['metadata']['homepage'] = nil
  hash['type'] = type
  hash['monitorType'] = monitor_type if monitor_type
  hash['depends'] = {}
  hash['params'] = {}
  hash['results'] = nil

  load_params(hash, path)
  load_depends(hash['depends'], program)
  load_summary(hash['metadata'], program)

  if hash['depends'].empty?
     hash['depends'] = nil
  end

  puts "#{path} => #{dest}"
  yaml = hash.to_yaml.sub(/^---\n/, '')
  File.open(dest, 'w') do |file|
    file.write(yaml)
  end
end
