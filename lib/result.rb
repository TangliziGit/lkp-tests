#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'set'
require "#{LKP_SRC}/lib/lkp_git"
require "#{LKP_SRC}/lib/run_env"
require "#{LKP_SRC}/lib/constant"
require "#{LKP_SRC}/lib/lkp_path"

def tbox_group(hostname)
  # special case 1: $tbox_group contains -N-
  #   hostname: daixiang-HP-ProBook-450-G3-0
  #   return:   daixiang-HP-ProBook-450-G3
  # special case 2: $vm_tbox_group--$host_testbox-$seqno
  #   hostname: vm-hi1620-2p8g--taishan200-2280-2s64p-256g-3-0
  #   return:   vm-hi1620-2p8g--taishan200-2280-2s64p-256g
  hostname.sub(/(-\d+)+$/, '')
end

def tbox_group?(hostname)
  return nil unless hostname.is_a?(String) && !hostname.empty?

  Dir[LKP::Path.src('hosts', hostname)][0]
end

class ResultPath < Hash
  MAXIS_KEYS = %w[tbox_group suite path_params rootfs kconfig compiler commit].freeze
  AXIS_KEYS = (MAXIS_KEYS + ['run']).freeze

  PATH_SCHEME = {
    'default' => %w[path_params tbox_group rootfs kconfig compiler commit run],
    'kvm:default' => %w[path_params tbox_group rootfs kconfig compiler commit run],
    'health-stats' => %w[path_params run],
    'lkp-bug' => %w[path_params run],
    'hwinfo' => %w[tbox_group run],
    'build-dpdk' => %w[rootfs dpdk_config commit dpdk_compiler dpdk_commit run],
    'build-qemu' => %w[rootfs qemu_config qemu_commit run],
    'build-llvm_project' => %w[rootfs llvm_project_commit run],
    'deploy-clang' => %w[rootfs llvm_project_commit run],
    'build-nvml' => %w[rootfs nvml_commit run],
    'build-ltp' => %w[rootfs ltp_commit run],
    'build-acpica' => %w[acpica_commit test run],
    'build-ceph' => %w[ceph_commit run],
    'kvm-unit-tests-qemu' => %w[path_params tbox_group rootfs kconfig compiler commit qemu_config qemu_commit run],
    'kvm-kernel-boot-test' => %w[tbox_group kconfig commit qemu_config qemu_commit linux_commit run],
    'build-perf_test' => %w[perf_test_commit run]
  }.freeze

  def path_scheme
    if self['suite'] =~ /^kvm:/
      PATH_SCHEME[self['suite']] || PATH_SCHEME['kvm:default']
    else
      PATH_SCHEME[self['suite']] || PATH_SCHEME['default']
    end
  end

  def parse_result_root(rt, is_local_run: false)
    dirs = rt.sub(/^.*#{RESULT_ROOT_DIR}/, '').split('/')
    dirs.shift if dirs[0] == ''

    self['suite'] = dirs.shift
    ps = path_scheme

    ndirs = dirs.size
    ps.each do |key|
      self[key] = dirs.shift
    end

    if self['path_params']
      ucode = self['path_params'][/ucode=0x[0-9a-z]*/]
      self['ucode'] = ucode.split('=').last if ucode

      self['unified_path_params'] = self.class.unified_path_params self['path_params']
    end

    if ps.include?('commit')
      each_commit do |_type, commit|
        return false unless self[commit]
        return false if !is_local_run && !sha1_40?(self[commit])
      end
    end

    # for rt and _rt
    ps.size == ndirs || ps.size == ndirs + 1
  end

  def assemble_result_root(skip_keys = nil)
    dirs = [
      "#{ENV['RESULT_ROOT_DIR_PREFIX']}#{RESULT_ROOT_DIR}",
      self['suite']
    ]

    path_scheme.each do |key|
      next if skip_keys && skip_keys.include?(key)

      dirs << self[key]
    end

    dirs.join '/'
  end

  def _result_root
    assemble_result_root ['run'].to_set
  end

  def result_root
    assemble_result_root
  end

  def test_desc_keys(dim, dim_not_a_param)
    dim = /^#{dim}$/ if dim.instance_of? String

    keys = ['suite'] + path_scheme
    keys.delete_if { |key| key =~ dim } if dim_not_a_param

    default_removal_pattern = /compiler|^rootfs$|^kconfig$/
    keys.delete_if { |key| key =~ default_removal_pattern && key !~ dim }

    keys
  end

  def test_desc(dim, dim_not_a_param)
    keys = test_desc_keys(dim, dim_not_a_param)

    keys.map { |key| self[key] }.compact.join '/'
  end

  def parse_test_desc(desc, dim: 'commit', dim_not_a_param: true)
    values = desc.split('/')
    keys = test_desc_keys dim, dim_not_a_param
    kv = {}
    keys.each.with_index do |k, i|
      kv[k] = values[i]
    end
    kv
  end

  def params_file
    [
      "#{ENV['RESULT_ROOT_DIR_PREFIX']}#{RESULT_ROOT_DIR}",
      self['suite'],
      'params.yaml'
    ].join '/'
  end

  def each_commit
    return enum_for(__method__) unless block_given?

    path_scheme.each do |axis|
      case axis
      when 'commit'
        yield 'linux', axis
      when /_commit$/
        yield axis.sub(/_commit$/, ''), axis
      end
    end
  end

  class << self
    def maxis_keys(test_case)
      PATH_SCHEME[test_case].reject { |key| key == 'run' }
    end

    #
    # code snippet from MResultRootCollection
    # FIXME rli9 refactor MResultRootCollection to embrace different maxis keys
    #
    def grep(test_case, options = {})
      pattern = ["#{ENV['RESULT_ROOT_DIR_PREFIX']}#{RESULT_ROOT_DIR}", test_case, PATH_SCHEME[test_case].map { |key| options[key] || '.*' }].flatten.join('/')

      cmdline = "grep -he '#{pattern}' #{KTEST_PATHS_DIR}/*/????-??-??-* | sed -e 's#[0-9]\\+/$##' | sort | uniq"
      `#{cmdline}`
    end

    def unified_path_params(path)
      path.sub(/-?ucode=[a-zA-Z0-9]{0,10}/, '')
    end
  end
end

class << ResultPath
  def parse(rt)
    rp = new
    rp.parse_result_root(rt)
    rp
  end

  def new_from_axes(axes)
    rp = new
    rp.update(axes)
    rp
  end

  def rectify(path)
    # remove extra '/'
    # //result/rcuscale/300s-rcu/vm-snb/debian-i386-20191205.cgz/i386-randconfig-a001-20201231/gcc-9/b1ca223e5ea73f2fea3551685f38ec35a372400a/
    path.split('/').reject(&:empty?).map { |field| "/#{field}" }.join
  end
end
