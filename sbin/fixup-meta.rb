#!/usr/bin/ruby

LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

require 'yaml'
require "#{LKP_SRC}/lib/pkgmap"

def fixup_depends(program, meta, path)
  pkgbuild = File.dirname(path) + "/PKGBUILD"
  return false if !File.exist? pkgbuild

  findos = $package_mapper.find_os_with_pkg(program, 'openeuler') ||
           $package_mapper.find_os_with_pkg(program, 'debian') ||
           $package_mapper.find_os_with_pkg(program, '')

  if findos.nil?
    meta['depends'] ||= {} 
    if !meta['depends'].include? 'PKGBUILD'
      return meta['depends']['PKGBUILD'] = Array(program)
    elsif !Array(meta['depends']['PKGBUILD']).include? program
      return meta['depends']['PKGBUILD'] = Array(program).concat(Array(meta['depends']['PKGBUILD']))
    end
  else
    if meta['depends'].nil? or meta['depends'].empty?
      meta['depends'] = {}
      return meta['depends'][findos] = Array(program)
    end
  end
end

$package_mapper = PackageMapper.new
$package_mapper.ospackage_set.delete 'archlinux'

# input: programs/xxx/meta.yaml
ARGV.each do |path|
  program = File.basename(File.dirname(path))
  meta = YAML.load_file(path)

  next unless fixup_depends(program, meta, path)

  if meta['depends'].empty?
     meta['depends'] = nil
  end

  puts path
  yaml = meta.to_yaml.sub(/^---\n/, '')
  File.open(path, 'w') do |file|
    file.write(yaml)
  end
end
