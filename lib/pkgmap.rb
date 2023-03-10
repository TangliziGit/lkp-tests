#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'
require 'json'
require 'set'
require 'pp'
require 'open3'
require 'active_support/core_ext/object/deep_dup'

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

def parse_bash_array(str)
  str.split.map do |a|
    a.sub(/^["']/, '').
      sub(/['"]$/, '').
      sub(/[>=<].*$/, '')
  end
end

def parse_bashx(script)
  bb = {}
  output = %x(PATH= /bin/bash -x #{script} 2>&1)
  # this won't work
  # Open3.popen2e(['/usr/bin/env', 'PATH=', '/bin/bash', '-x', script]) { |i, o|
  #   output = o.read
  # }
  output.each_line do |line|
    case line
    when /^\+ depends=\((.*)\)/, /^\+ makedepends=\((.*)\)/
      bb['archlinux'] ||= []
      bb['archlinux'].concat(parse_bash_array($1))
    when /^\+ depends_(.*)=\((.*)\)/, /^\+ makedepends_(.*)=\((.*)\)/
      os = @os4bash[$1]
      if os
        bb[os] ||= []
        bb[os].concat(parse_bash_array($2))
      else
        puts @os4bash
        puts "warning: #{script}: unknown depends for #{$1}"
      end
    end
  end
  bb
end

def hset_merge_one(h1, h2, k)
  return unless h2[k]

  h1[k] ||= Set.new
  h1[k].merge h2[k]
end

def show_hset(h)
  h.each do |k, v|
    puts "#{k}: #{v.to_a.join ' '}"
  end
end

class PackageMapper

  attr_reader :ospackage_set

  def initialize
    @ospackage_set = {}       # [os_spec] = pkg set
    @pkgbuild_set = Set.new   # pkg set
    @ospkgmap = {}            # [os2os][pkg] = "pkg1 pkg2 ..." (whitespace separated string)
    @pkgmap = {}              # [pkg] = pkg set
    @pkgmap2 = {}             # [pkg] = pkg set
    @depends = {}             # [program][os_spec] = pkg array
    @depends_dev = {}
    @pkgbuild_depends = {}    # [program][os_spec] = pkg array
    @os4bash = {}             # [openeuler_22_03] = openeuler@22.03
    load_package_list
    link_package_list
    load_meta
    load_depends
    load_pkgmap
    add_pkgbuild_pkgs
    check_pkgmap
    add_reverse_pkgmap
    add_global_pkgmap
    add_global_pkgmap2
  end

  def init_one_os4bash(os_spec)
    return if @os4bash.include? os_spec
    bash_var = os_spec.gsub(/[^a-zA-Z0-9]/, '_')
    @os4bash[bash_var] = os_spec
  end

  def init_os4bash
    init_one_os4bash('PKGBUILD')
    @ospackage_set.keys.each do |os_spec|
      init_one_os4bash(os_spec)
    end
    @ospkgmap.keys.each do |o2o|
      os1, os2 = o2o.split('..')
      init_one_os4bash(os1)
      init_one_os4bash(os2)
    end
  end

  def load_package_list
    Dir.glob("#{LKP_SRC}/distro/package-list/*").each do |path|
      os_spec = File.basename(path)
      @ospackage_set[os_spec] = File.read(path).split.to_set
    end
  end

  # e.g. openeuler@22.03 -> openeuler@22.03:aarch64
  def link_package_list
    @ospackage_set.keys.each do |os_spec|
      noarch = os_spec.sub(/:.*$/, '')
      @ospackage_set[noarch] ||= @ospackage_set[os_spec]
    end
  end

  def link_os_spec(os)
    return os if @ospackage_set.include?(os)
    os.sub!(/:.*$/, '')
    return os if @ospackage_set.include?(os)

    os_prefix = os.sub(/@.*$/, '@')
    last_os = @ospackage_set.keys.select {|o| !o.include?(':') and o.start_with?(os_prefix) and o < os }.sort.last
    if last_os
      puts "info: reuse last OS version #{LKP_SRC}/distro/package-list/#{last_os}"
      return last_os
    end

    puts "warning: cannot find #{LKP_SRC}/distro/package-list/#{os}"
    return os
  end

  def load_pkgmap
    Dir.glob("#{LKP_SRC}/distro/pkgmap/*..*").each do |path|
      os2os = File.basename(path)
      @ospkgmap[os2os] ||= {}
      @ospkgmap[os2os].merge! YAML.load_file(path)
    end
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
      load_meta_yaml path, path.sub(/.*meta-/, '').sub(/.yaml$/, '')
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
    @depends.each do |program, o2p|
      o2p.each do |os, pkgs|
        next unless @ospackage_set.include? os

        pkgs.each do |pkg|
          next if @ospackage_set[os].include? pkg
          next if pkg.include? ':' # don't warn on libc6-dev:i386

          puts "warning: #{program} depended on package '#{pkg}' not in #{os}"
        end
      end
    end
  end

  def match_name_variants(pkgset, pkgname)
    return pkgname if pkgset.include?(pkgname)
    name = pkgname.sub(/-dev$/, '-devel')
    return name if pkgset.include?(name)
    name = pkgname.sub(/-devel$/, '-dev')
    return name if pkgset.include?(name)
    return nil
  end

  def map_pkg_direct(pkgname, src_os, dst_os)
    # try 1: find direct mapping
    os2os = "#{src_os}..#{dst_os}"
    return @ospkgmap[os2os][pkgname] if @ospkgmap.include?(os2os) && @ospkgmap[os2os].include?(pkgname)

    # puts "map_pkg_direct(#{pkgname}, #{src_os}, #{dst_os})"
    # try 2: find mapping from previous OS versions
    os1 = parse_os_spec(src_os)
    os2 = parse_os_spec(dst_os)
    findpkg = nil
    last_os = nil
    @ospkgmap.each do |os2os, pkgmap|
      next unless pkgmap.include? pkgname
      next unless @ospackage_set.include?(dst_os) and
                  @ospackage_set[dst_os].include? pkgmap[pkgname] # this cannot handle multi-packages separated by space

      o1, o2 = os2os.split('..')
      if o1.start_with?(os1['os_name']) && (o1 <= src_os) &&
         o2.start_with?(os2['os_name']) && (o2 <= dst_os)
        if last_os
          findpkg = pkgmap[pkgname] if o2 > last_os
        else
          findpkg = pkgmap[pkgname]
        end
        last_os = o2
      end
    end

    return findpkg if findpkg

    # try 3: match by name
    if @ospackage_set.include?(dst_os) &&
        similar_name = match_name_variants(@ospackage_set[dst_os], pkgname)
      return similar_name
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
    dp = map_pkg_direct(pkgname, from_os, to_os)
    return { 'os' => dp.split } if dp

    return { 'pip' => [$1] } if pkgname =~ /^python3-(.*)$/
    return { 'gem' => [$1] } if pkgname =~ /^ruby-(.*)$/

    dp = map_pkg_direct(pkgname, from_os, 'archlinux')
    return { 'PKGBUILD' => dp.split } if @pkgbuild_set.include? dp

    puts "Failed to map package #{pkgname} from #{from_os} to #{to_os}, please add pkgmap for it."
    {}
  end

  def map_pkgs(pkgs, from_os, to_os)
    mapping = {}
    pkgs.each do |pkg|
      h = map_pkg(pkg, from_os, to_os)
      hset_merge_depends(mapping, h)
    end
    mapping
  end

  def hset_merge_depends(hh, h)
      hset_merge_one(hh, h, 'PKGBUILD')
      hset_merge_one(hh, h, 'os')
      hset_merge_one(hh, h, 'pip')
      hset_merge_one(hh, h, 'gem')
  end

  def add_depends(in_depends, dst_depends, dst_os)
    pkgbuilds_queue = []
    loop do
      return unless in_depends
      in_depends = in_depends.deep_dup
      # PKGBUILD means explicit custom build packages
      pkgbuilds_queue.concat(in_depends['PKGBUILD'].to_a)
      dst_depends['PKGBUILD'].merge(in_depends.delete('PKGBUILD') || [])
      dst_depends['pip'].merge(in_depends.delete('pip') || [])
      dst_depends['gem'].merge(in_depends.delete('gem') || [])

      in_depends.each do |src_os, pkgs|
        h = map_pkgs(pkgs, src_os, dst_os)
        pkgbuilds_queue.concat  h['PKGBUILD'].to_a if h['PKGBUILD']
        hset_merge_depends(dst_depends, h)
      end

      in_depends = @pkgbuild_depends[pkgbuilds_queue.shift]
    end
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
    dst_depends = {}
    dst_depends['pip'] = Set.new
    dst_depends['gem'] = Set.new
    dst_depends['os'] = Set.new
    dst_depends['PKGBUILD'] = Set.new
    add_depends(@depends[program], dst_depends, dst_os)
    dst_depends
  end

  def map_programs(programs, dst_os)
    dst_os = link_os_spec(dst_os)
    hh = {}
    programs.each do |program|
      h = map_program(program, dst_os)
      # puts program, h
      hset_merge_depends(hh, h)
    end
    hh
  end

  def get_pkgbuild_depends(pkgs, dst_os)
    pkgbuild_depends = Set.new
    pkgs.each do |pkg|
      pkgbuild_depends.merge @pkgbuild_depends[pkg] if @pkgbuild_depends[pkg]
    end
    map_pkgs(pkgbuild_depends, 'archlinux', dst_os)
  end

  def add_pkgbuild_pkgs
    init_os4bash
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
    @ospackage_set['archlinux'] ||= Set.new
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

  def find_os_with_pkg(pkg, prefer_os)
    ospackage_set.each do |os, pkgs|
      next unless os.start_with? (prefer_os || '')
      return os if pkgs.include?(pkg)
    end
    return nil
  end

end
