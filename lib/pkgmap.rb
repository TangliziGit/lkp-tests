#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'json'
require 'set'
require 'pp'
require 'open3'

def parse_os_spec(os_spec)
  tmp, arch = os_spec.split(':')
  os_name, os_version = tmp.split('@')
  raise 'empty os_name' unless os_name

  {
    'arch' => arch || 'x86_64',
    'os_name' => os_name,
    'os_version' => os_version
  }
end

def parse_bashx(script)
  hash = {}
  output = %x(PATH= /bin/bash -x #{script} 2>&1)
  # this won't work
  # Open3.popen2e(['/usr/bin/env', 'PATH=', '/bin/bash', '-x', script]) { |i, o|
  #   output = o.read
  # }
  output.each_line do |line|
    case line
    when /^\+ depends=\((.*)\)/, /^\+ makedepends=\((.*)\)/
      hash['depends'] ||= []
      hash['depends'].concat($1.split.map { |a| a.sub(/^["']/, '').sub(/['"]$/, '').sub(/[>=<].*$/, '') })
    end
  end
  hash['depends']
end

def hset_merge_one(h1, h2, k)
  return unless h2[k]

  h1[k] ||= Set.new
  h1[k].merge h2[k]
end

def show_hset(h)
  h.each do |k, v|
    puts "#{k}: #{v.join ' '}"
  end
end

class PackageMapper
  # EXPAND_DIMS = %w(kconfig commit rootfs ltp_commit nvml_commit blktests_commit qemu_commit perf_test_commit linux_commit).freeze

  # attr_reader :referenced_programs
  # attr_accessor :overrides

  def initialize
    @ospackage_set = {}       # [os_spec] = pkg set
    @pkgbuild_set = Set.new   # pkg set
    @ospkgmap = {}            # [os2os][pkg] = "pkg1 pkg2 ..." (whitespace separated string)
    @pkgmap = {}              # [pkg] = pkg set
    @pkgmap2 = {}             # [pkg] = pkg set
    @depends = {}             # [program][os_spec] = pkg array
    @depends_dev = {}
    @pkgbuild_depends = {}
    load_package_list
    load_meta
    load_depends
    load_pkgmap
  end

  def load_package_list
    Dir.glob("#{LKP_SRC}/distro/package-list/*").each do |path|
      os_spec = File.basename(path)
      @ospackage_set[os_spec] = File.read(path).split.to_set
    end
    add_pkgbuild_pkgs
  end

  def load_pkgmap
    Dir.glob("#{LKP_SRC}/distro/pkgmap/*..*").each do |path|
      os2os = File.basename(path)
      @ospkgmap[os2os] ||= {}
      @ospkgmap[os2os].merge! YAML.load_file(path)
    end
    check_pkgmap
    add_reverse_pkgmap
    add_global_pkgmap
    add_global_pkgmap2
  end

  def add_global_pkgmap
    @ospkgmap.each do |_os2os, pkgmap|
      pkgmap.each do |src_pkg, dst_pkgs|
        next if dst_pkgs.nil?
        next if dst_pkgs.include? ' '
        next if dst_pkgs.include? "\t"

        @pkgmap[src_pkg] ||= Set.new
        @pkgmap[src_pkg].add dst_pkgs
      end
    end
  end

  def add_global_pkgmap2
    @pkgmap2 = {}
    @pkgmap.each do |src_pkg, pkgs|
      @pkgmap2[src_pkg] = pkgs.clone
      pkgs.each do |pkg|
        next unless @pkgmap.include? pkg

        @pkgmap2[src_pkg].merge @pkgmap[pkg]
      end
    end
  end

  def add_reverse_pkgmap
    keys = @ospkgmap.keys # keep the variable to avoid robocup warning
    keys.each do |os2os|
      from_os, to_os = os2os.split('..')
      o2o = "#{to_os}..#{from_os}"
      @ospkgmap[o2o] ||= {}
    end

    @ospkgmap.each do |os2os, pkgmap|
      from_os, to_os = os2os.split('..')
      o2o = "#{to_os}..#{from_os}"
      pkgmap.each do |src_pkg, dst_pkgs|
        next if dst_pkgs.nil?
        next if dst_pkgs.include? ' '
        next if dst_pkgs.include? "\t"

        if @ospkgmap[o2o][dst_pkgs]
          if @ospkgmap[o2o][dst_pkgs] != src_pkg
            # puts "warning: pkgmap mismatch: #{os2os} #{src_pkg}=>#{dst_pkgs} != #{o2o} #{dst_pkgs}=>#{@ospkgmap[o2o][dst_pkgs]}"
          end
          next
        end
        @ospkgmap[o2o][dst_pkgs] = src_pkg
      end
    end
  end

  def load_meta_depends(depends, program)
    return unless depends

    @depends[program] ||= {}
    depends.each do |os, pkgs|
      @depends[program][os] ||= []
      case pkgs
      when Array
        @depends[program][os].concat(pkgs)
      when String
        next if pkgs =~ /^#/

        @depends[program][os].concat(pkgs.sub(/#.*/, '').split)
      when Nil
        # no warn
      else
        puts "warning: unknown depends.#{os}: #{pkgs} for #{program}"
      end
    end
  end

  def load_meta_pkgmap(pkgmap)
    return unless pkgmap

    pkgmap.each do |os2os, map|
      @ospkgmap[os2os] ||= {}
      @ospkgmap[os2os].merge! map
    end
  end

  def load_meta_yaml(file, program)
    meta = YAML.load_file(file)
    if meta['metadata'].nil?
      puts "warning: #{file} metadata field is empty"
    elsif program != meta['metadata']['name']
      puts "warning: #{file} metadata.name '#{meta['metadata']['name']}' != #{program}"
    end

    load_meta_depends(meta['depends'], program)
    load_meta_pkgmap(meta['pkgmap'])
  end

  def load_meta
    # new layout
    Dir.glob("#{LKP_SRC}/{monitors,setup,programs}/*/meta.yaml").each do |path|
      load_meta_yaml path, File.basename(File.dirname(path))
    end
    Dir.glob("#{LKP_SRC}/{monitors,setup,programs}/*/meta-*.yaml").each do |path|
      load_meta_yaml path, path.sub(/.*meta-/, '').delete_suffix('.yaml')
    end
  end

  def load_depends
    # legacy global layout
    Dir.glob("#{LKP_SRC}/distro/depends/*").each do |path|
      next unless File.file? path

      program = File.basename(path)
      if program =~ /-dev$/ # obsolete, won't use
        @depends_dev[program[0..-5]] = YAML.load_file(path)
      else
        @depends[program] ||= {}
        @depends[program]['debian@11'] ||= []
        File.open(path).each_line do |line|
          next if line =~ /^#/

          @depends[program]['debian@11'].concat(line.sub(/#.*/, '').split)
        end
      end
    end
    check_depends
  end

  def check_depends
    @depends.each do |program, hash|
      hash.each do |os, pkgs|
        next unless @ospackage_set.include? os

        pkgs.each do |pkg|
          next if @ospackage_set[os].include? pkg
          next if pkg.include? ':' # don't warn on libc6-dev:i386

          puts "warning: #{program} depended on package '#{pkg}' not in #{os}"
        end
      end
    end
  end

  def map_pkg_direct(pkgname, src_os, dst_os)
    # puts "map_pkg_direct(#{pkgname}, #{src_os}, #{dst_os})"
    # try 1: find direct mapping
    os2os = "#{src_os}..#{dst_os}"
    return @ospkgmap[os2os][pkgname] if @ospkgmap.include?(os2os) && @ospkgmap[os2os].include?(pkgname)

    # try 2: find mapping from previous OS versions
    os1 = parse_os_spec(src_os)
    os2 = parse_os_spec(dst_os)
    @ospkgmap.each do |os2os, pkgmap|
      next unless pkgmap.include? pkgname
      next unless @ospackage_set.include? pkgmap[pkgname] # this cannot handle multi-packages separated by space

      o1, o2 = os2os.split('..')
      if o1.start_with?(os1['os_name']) && (o1 >= src_os) &&
         o2.start_with?(os2['os_name']) && (o2 >= dst_os)
        return pkgmap[pkgname]
      end
    end

    # try 3: match by name
    if @ospackage_set.include?(dst_os) &&
       @ospackage_set[dst_os].include?(pkgname)
      return pkgname
    end

    # try 4: global mapping
    if @pkgmap.include?(pkgname) && @ospackage_set.include?(dst_os)
      @pkgmap[pkgname].each do |pkg|
        return pkg if @ospackage_set[dst_os].include? pkg
      end
    end

    # try 5: global indirect mapping
    if @pkgmap2.include?(pkgname) && @ospackage_set.include?(dst_os)
      @pkgmap2[pkgname].each do |pkg|
        return pkg if @ospackage_set[dst_os].include? pkg
      end
    end

    nil
  end

  # output hash:
  #   PKGBUILD: build pkg set (pkg not found in to_os)
  #   os:     install pkg set (pkg is found in to_os)
  def map_pkg(pkgname, from_os, to_os)
    # try 1: direct mapping
    dp = map_pkg_direct(pkgname, from_os, to_os)
    return { 'os' => dp.split } if dp

    dp = map_pkg_direct(pkgname, from_os, 'archlinux')
    return { 'PKGBUILD' => dp.split } if @pkgbuild_set.include? dp

    puts "Failed to map package #{pkgname} from #{from_os} to #{to_os}, please add pkgmap for it."
    {}
  end

  def map_pkgs(pkgs, from_os, to_os)
    mapping = {}
    pkgs.each do |pkg|
      h = map_pkg(pkg, from_os, to_os)
      hset_merge_one(mapping, h, 'os')
      hset_merge_one(mapping, h, 'PKGBUILD')
    end
    mapping
  end

  # meta.yaml config:
  #   depends.debian@11: pkgs for debian@11
  #   depends.PKGBUILD: pkgs to build from source
  # output hash:
  #   PKGBUILD: build pkg set
  #   os: install pkg set
  #   pip: python pkg array
  #   gem: python pkg array
  def map_program(program, dst_os)
    depends = @depends[program]
    unless depends
      # puts "#{program}: depends is empty"
      # pp @depends
      return {}
    end

    pip_pkgs = depends.delete 'pip'
    gem_pkgs = depends.delete 'gem'
    # explicit custom build packages
    pkgbuild_pkgs = depends.delete 'PKGBUILD'
    pkgbuild_pkgs ||= Set.new
    os_pkgs = Set.new
    depends.each do |src_os, pkgs|
      h = map_pkgs(pkgs, src_os, dst_os)
      os_pkgs.merge        h['os'] if h['os']
      pkgbuild_pkgs.merge  h['PKGBUILD'] if h['PKGBUILD']
    end
    h = get_pkgbuild_depends(pkgbuild_pkgs, dst_os)
    os_pkgs.merge        h['os'] if h['os']
    pkgbuild_pkgs.merge  h['PKGBUILD'] if h['PKGBUILD']
    # assume no multi-level PKGBUILD depends, let's stop here
    {
      'PKGBUILD' => pkgbuild_pkgs,
      'os' => os_pkgs,
      'pip' => pip_pkgs,
      'gem' => gem_pkgs
    }
  end

  def map_programs(programs, dst_os)
    hash = {}
    programs.each do |program|
      h = map_program(program, dst_os)
      # puts program, h
      hset_merge_one(hash, h, 'PKGBUILD')
      hset_merge_one(hash, h, 'os')
      hset_merge_one(hash, h, 'pip')
      hset_merge_one(hash, h, 'gem')
    end
    hash
  end

  def get_pkgbuild_depends(pkgs, dst_os)
    pkgbuild_depends = Set.new
    pkgs.each do |pkg|
      pkgbuild_depends.merge @pkgbuild_depends[pkg] if @pkgbuild_depends[pkg]
    end
    map_pkgs(pkgbuild_depends, 'archlinux', dst_os)
  end

  def add_pkgbuild_pkgs
    # legacy layout
    Dir.glob("#{LKP_SRC}/pkg/*/PKGBUILD").each do |path|
      pkg = File.basename(File.dirname(path))
      @pkgbuild_set.add pkg
      @pkgbuild_depends[pkg] = parse_bashx(path)
    end
    # new layout
    Dir.glob("#{LKP_SRC}/{monitors,setup,programs}/*/PKGBUILD").each do |path|
      pkg = File.basename(File.dirname(path))
      @pkgbuild_set.add pkg
      @pkgbuild_depends[pkg] = parse_bashx(path)
    end
    Dir.glob("#{LKP_SRC}/{monitors,setup,programs}/*/PKGBUILD-*").each do |path|
      pkg = path.sub(/.*PKGBUILD-/, '')
      @pkgbuild_set.add pkg
      @pkgbuild_depends[pkg] = parse_bashx(path)
    end
    @ospackage_set['archlinux'].merge @pkgbuild_set
  end

  # ensure that pkgmap src/dst packages shall be in the corresponding OS package list
  def check_pkgmap
    @ospkgmap.each do |os2os, pkgmap|
      from_os, to_os = os2os.split('..')
      pkgmap.each do |src_pkg, dest_pkgs|
        puts "warning: distro/pkgmap/#{os2os}: invalid key #{src_pkg}" if @ospackage_set.include?(from_os) && !(@ospackage_set[from_os].include? src_pkg)
        next unless dest_pkgs && @ospackage_set.include?(to_os)

        dest_pkgs.split.each do |dest_pkg|
          puts "warning: distro/pkgmap/#{os2os}: invalid val #{dest_pkg}" unless @ospackage_set[to_os].include? dest_pkg
        end
      end
    end
  end
end
