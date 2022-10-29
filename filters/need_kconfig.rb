#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'yaml'
require "#{LKP_SRC}/lib/kernel_tag"
require "#{LKP_SRC}/lib/log"

def load_kernel_context
  context_file = File.expand_path '../context.yaml', kernel
  raise Job::ParamError, "context.yaml doesn't exist: #{context_file}" unless File.exist?(context_file)

  YAML.load(File.read(context_file))
end

def read_kernel_kconfigs
  kernel_kconfigs = File.expand_path '../.config', kernel
  raise Job::ParamError, ".config doesn't exist: #{kernel_kconfigs}" unless File.exist?(kernel_kconfigs)

  File.read kernel_kconfigs
end

def kernel_match_arch?(kernel_arch, expected_archs)
  expected_archs.include? kernel_arch
end

def kernel_match_kconfig?(kernel_kconfigs, expected_kernel_kconfig)
  case expected_kernel_kconfig
  when /^([A-Z0-9_]+)=n$/
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /# #{config_name} is not set/ || kernel_kconfigs !~ /^#{config_name}=[ym]$/
  when /^([A-Z0-9_]+=[ym])$/, /^([A-Z0-9_]+=[0-9]+)$/
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /^#{config_name}$/
  when /^([A-Z0-9_]+)$/, /^([A-Z0-9_]+)=$/
    # /^([A-Z0-9_]+)$/ is for "CRYPTO_HMAC"
    # /^([A-Z0-9_]+)=$/ is for "DEBUG_INFO_BTF: v5.2"
    config_name = $1
    config_name = "CONFIG_#{config_name}" unless config_name =~ /^CONFIG_/

    kernel_kconfigs =~ /^#{config_name}=(y|m)$/
  else
    raise Job::SyntaxError, "Wrong syntax of kconfig: #{expected_kernel_kconfig}"
  end
end

def check_all(kernel_kconfigs)
  uncompiled_kconfigs = []

  context = load_kernel_context
  kernel_version = context['rc_tag']
  kernel_arch = context['kconfig'].split('-').first

  $___.each do |e|
    if e.instance_of? Hashugar
      config_name, config_options = e.to_hash.first
      # to_s is for "CMA_SIZE_MBYTES: 200"
      config_options = config_options.to_s.split(',').map(&:strip)

      expected_archs, config_options = config_options.partition { |option| option =~ /^(i386|x86_64)$/ }
      next unless expected_archs.empty? || kernel_match_arch?(kernel_arch, expected_archs)

      expected_kernel_versions, config_options = config_options.partition { |option| option =~ /v\d+\.\d+/ }
      # ignore the check of kconfig type if kernel is not within the valid range
      next if expected_kernel_versions && !kernel_match_version?(kernel_version, expected_kernel_versions)

      # \d+ is for "CMA_SIZE_MBYTES: 200"
      types, config_options = config_options.partition { |option| option =~ /^(y|m|n|\d+)$/ }
      raise Job::SyntaxError, "Wrong syntax of kconfig setting: #{e.to_hash}" if types.size > 1

      raise Job::SyntaxError, "Wrong syntax of kconfig setting: #{e.to_hash}" unless config_options.size.zero?

      expected_kernel_kconfig = "#{config_name}=#{types.first}"
    else
      expected_kernel_kconfig = e
    end

    next if kernel_match_kconfig?(kernel_kconfigs, expected_kernel_kconfig)

    uncompiled_kconfig = expected_kernel_kconfig
    uncompiled_kconfig += " supported by kernel (#{expected_kernel_versions.join(', ').gsub('"', '')})" if expected_kernel_versions
    uncompiled_kconfigs.push uncompiled_kconfig
  end

  return nil if uncompiled_kconfigs.empty?

  kconfigs_error_message = "#{File.basename __FILE__}: #{uncompiled_kconfigs.uniq} has not been compiled by this kernel (#{kernel_version} based)"
  raise Job::ParamError, kconfigs_error_message.to_s unless __FILE__ =~ /suggest_kconfig/

  puts "suggest kconfigs: #{uncompiled_kconfigs.uniq}"
end

def check_arch_constraints
  model = self['model']
  rootfs = self['rootfs']
  kconfig = self['kconfig']

  case model
  when /^qemu-system-x86_64/
    case rootfs
    when /-x86_64/
      # Check kconfig to find mismatches earlier, in cases
      # when the exact kernel is still not available:
      # - commit=BASE|HEAD|CYCLIC_BASE|CYCLIC_HEAD late binding
      # - know exact commit, however yet to compile the kernel
      raise Job::ParamError, "32bit kernel cannot run 64bit rootfs: '#{kconfig}' '#{rootfs}'" if kconfig =~ /^i386-/

      $___ << 'X86_64=y'
    when /-i386/
      $___ << 'IA32_EMULATION=y' if kconfig =~ /^x86_64-/
    end
  when /^qemu-system-i386/
    case rootfs
    when /-x86_64/
      raise Job::ParamError, "32bit QEMU cannot run 64bit rootfs: '#{model}' '#{rootfs}'"
    when /-i386/
      raise Job::ParamError, "32bit QEMU cannot run 64bit kernel: '#{model}' '#{kconfig}'" if kconfig =~ /^x86_64-/

      $___ << 'X86_32=y'
    end
  end
end

if self['kernel']
  $___ = Array(___)

  check_arch_constraints

  check_all(read_kernel_kconfigs)
end
