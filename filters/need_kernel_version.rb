#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'yaml'
require "#{LKP_SRC}/lib/kernel_tag"
require "#{LKP_SRC}/lib/log"

def check_kernel_version
  context_file = File.join(File.dirname(File.realpath(self['kernel'])), 'context.yaml')
  raise Job::ParamError, "context.yaml doesn't exist: #{context_file}" unless File.exist?(context_file)

  context = YAML.load(File.read(context_file))
  kernel_version = context['rc_tag']
  raise Job::ParamError, "kernel version not satisfied: #{kernel_version}" if kernel_version && !kernel_match_version?(kernel_version, Array(self['need_kernel_version']))
end

check_kernel_version if self['need_kernel_version'] && self['kernel']
