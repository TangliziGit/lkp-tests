#!/usr/bin/ruby

LKP_SRC = ENV['LKP_SRC'] || File.dirname(File.dirname(File.realpath($PROGRAM_NAME)))

$added = {}

def add_one(pkg, path)
  dfile = "#{LKP_SRC}/distro/depends/#{pkg}-dev"
  return unless File.exist? dfile
  return if $added.include? path
  $added[path] = true
  puts "rm #{dfile}"

  deps = File.read(dfile).split
  newline = "makedepends_debian_11=(#{deps.join ' '})"
  system("sed -i 's/^source=/#{newline}\\nsource=/' #{path}")
end

Dir.glob("#{LKP_SRC}/pkg/*/PKGBUILD").each do |path|
  pkg = File.basename(File.dirname(path))
  add_one pkg, path
end

Dir.glob("#{LKP_SRC}/{monitors,setup,programs}/*/PKGBUILD").each do |path|
  pkg = File.basename(File.dirname(path))
  add_one pkg, path
end
