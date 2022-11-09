#!/usr/bin/ruby

require 'yaml'

LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

def fixup_params(hash, params)
  params.each do |p, v|
    case v
    when Array
      hash['params'][p] = { 'values' => v }
    when String
      if v.include? ' '
        hash['params'][p] = { 'doc' => v }
      else
        hash['params'][p] = { 'example' => v }
      end
    end
  end
end

def fixup_results(results, program)
  keys = results.keys
  keys.each do |k|
    if k.start_with? program + '.'
      new_key = k.delete_prefix program + '.'
      results[new_key] = results.delete k
    end
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

Dir.glob("#{LKP_SRC}/{monitors,setup,programs}/*/meta.yaml").each do |path|
# ARGV.each do |path|
  program = File.basename(File.dirname(path))
  meta = YAML.load_file(path)

  next if meta['metadata']

  hash = {}
  hash['metadata'] = {}
  hash['metadata']['name'] = program
  hash['metadata']['summary'] = (meta['short_description'] || '').gsub(/\s+\z/m, '')
  hash['metadata']['description'] = (meta['description'] || '').gsub(/\s+\z/m, '')
  hash['metadata']['homepage'] = meta['homepage']
  hash['type'] = 'workload'
  hash['depends'] = meta['depends'] || {}
  hash['params'] = meta['parameters'] || {}
  hash['results'] = meta['results'] || {}

  fixup_params(hash, meta['parameters'] || {})
  fixup_results(hash['results'], program)
  load_depends(hash['depends'], program)

  puts path
  yaml = hash.to_yaml.sub(/^---\n/, '')
  File.open(path, 'w') do |file|
    file.write(yaml)
  end
end
