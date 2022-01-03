#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'yaml'
require "#{LKP_SRC}/lib/kernel_tag"
require "#{LKP_SRC}/lib/log"

def read_kernel_version_from_context
  context_file = File.expand_path '../context.yaml', kernel
  raise Job::ParamError, "context.yaml doesn't exist: #{context_file}" unless File.exist?(context_file)

  context = YAML.load(File.read(context_file))
  context['rc_tag']
end

def read_kernel_kconfigs
  kernel_kconfigs = File.expand_path '../.config', kernel
  raise Job::ParamError, ".config doesn't exist: #{kernel_kconfigs}" unless File.exist?(kernel_kconfigs)

  File.read kernel_kconfigs
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

def kernel_match_version?(kernel_version, expected_kernel_versions)
  kernel_version = KernelTag.new(kernel_version)

  expected_kernel_versions.all? do |expected_kernel_version|
    match = expected_kernel_version.match(/(?<operator>==|!=|<=|>|>=)?\s*(?<kernel_tag>v[0-9]\.\d+(-rc\d+)*)/)
    raise Job::SyntaxError, "Wrong syntax of kconfig setting: #{expected_kernel_versions}" if match.nil? || match[:kernel_tag].nil?

    operator = match[:operator] || '>='

    # rli9 FIXME: hack code to handle <=
    # Take below example, MEMORY_HOTPLUG_SPARSE is moved in 5.16-rc1, thus we configure
    # as <= 5.15. But we use rc_tag to decide the kernel of commit, 50f9481ed9fb or other
    # commit now use kernel v5.15 to compare. This matches the <= and expects MEMORY_HOTPLUG_SPARSE
    # is y, which leads to job filtered wrongly on these commits.
    #
    # fa55b7dcdc43 ("Linux 5.16-rc1")
    # c55a04176cba ("Merge tag 'char-misc-5.16-rc1' ...")
    # 50f9481ed9fb ("mm/memory_hotplug: remove CONFIG_MEMORY_HOTPLUG_SPARSE")
    # 8bb7eca972ad ("Linux 5.15")
    #
    # To workaround this, change operator to < to mismatch the kernel
    operator = '<' if operator == '<='

    kernel_version.method(operator).call(KernelTag.new(match[:kernel_tag]))
  end
end

def check_all(kernel_kconfigs)
  uncompiled_kconfigs = []

  kernel_version = read_kernel_version_from_context

  $___.each do |e|
    if e.instance_of? Hashugar
      config_name, config_options = e.to_hash.first
      # to_s is for "CMA_SIZE_MBYTES: 200"
      config_options = config_options.to_s.split(',').map(&:strip)

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
