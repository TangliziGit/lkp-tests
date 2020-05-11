#!/usr/bin/env ruby

LKP_SRC ||= ENV["LKP_SRC"] || File.dirname(__DIR__)

require "set"
require "./lkp_git"
require "./run_env"
require "./constant"

DEFAULT_COMPILER = "gcc-7".freeze

def tbox_group(hostname)
  if hostname =~ /.+-\d+$/
    hostname.sub(/-\d+$/, "").sub(/-\d+-/, "-")
  else
    hostname
  end
end

def tbox_group?(hostname)
  return nil unless hostname.is_a?(String) && !hostname.empty?

  Dir[LKP_SRC + "/hosts/" + hostname][0]
end

class ResultPath < Hash
  MAXIS_KEYS = %w[tbox_group testcase path_params rootfs kconfig compiler commit].freeze
  AXIS_KEYS = (MAXIS_KEYS + ["run"]).freeze

  PATH_SCHEME = {
    "default" => %w[path_params tbox_group rootfs kconfig compiler commit run],
    "kvm:default" => %w[path_params tbox_group rootfs kconfig compiler commit run],
    "health-stats" => %w[path_params run],
    "lkp-bug" => %w[path_params run],
    "hwinfo" => %w[tbox_group run],
    "build-dpdk" => %w[rootfs dpdk_config commit dpdk_compiler dpdk_commit run],
    "build-qemu" => %w[rootfs qemu_config qemu_commit run],
    "build-llvm_project" => %w[rootfs llvm_project_commit run],
    "deploy-clang" => %w[rootfs llvm_project_commit run],
    "build-nvml" => %w[rootfs nvml_commit run],
    "build-ltp" => %w[rootfs ltp_commit run],
    "build-acpica" => %w[acpica_commit test run],
    "build-ceph" => %w[ceph_commit run],
    "build-sof" => %w[sof_config sof_commit soft_commit run],
    "kvm-unit-tests-qemu" => %w[path_params tbox_group rootfs kconfig compiler commit qemu_config qemu_commit run],
    "kvm-kernel-boot-test" => %w[tbox_group kconfig commit qemu_config qemu_commit linux_commit run],
    "build-perf_test" => %w[perf_test_commit run],
  }.freeze

  def path_scheme
    if self["testcase"] =~ /^kvm:/
      PATH_SCHEME[self["testcase"]] || PATH_SCHEME["kvm:default"]
    else
      PATH_SCHEME[self["testcase"]] || PATH_SCHEME["default"]
    end
  end

  def parse_result_root(rt, is_local_run = false)
    dirs = rt.sub(/#{RESULT_ROOT_DIR}/, "").split("/")
    dirs.shift if dirs[0] == ""

    self["testcase"] = dirs.shift
    ps = path_scheme

    ndirs = dirs.size
    ps.each do |key|
      self[key] = dirs.shift
    end

    if self["path_params"]
      ucode = self["path_params"][/ucode=0x[0-9a-z]*/]
      self["ucode"] = ucode.split("=").last if ucode
    end

    if ps.includes?("commit")
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
      RESULT_ROOT_DIR,
      self["testcase"],
    ]

    path_scheme.each do |key|
      next if skip_keys && skip_keys.includes?(key)

      dirs << self[key]
    end

    dirs.join "/"
  end

  def _result_root
    assemble_result_root ["run"].to_set
  end

  def result_root
    assemble_result_root
  end

  def test_desc_keys(dim, dim_not_a_param)
    dim = /^#{dim}$/ if dim.instance_of? String

    keys = ["testcase"] + path_scheme
    keys.delete_if { |key| key =~ dim } if dim_not_a_param

    default_removal_pattern = /compiler|^rootfs$|^kconfig$/
    keys.delete_if { |key| key =~ default_removal_pattern && key !~ dim }

    keys
  end

  def test_desc(dim, dim_not_a_param)
    keys = test_desc_keys(dim, dim_not_a_param)

    keys.map { |key| self[key] }.compact.join "/"
  end

  def parse_test_desc(desc, dim = "commit", dim_not_a_param = true)
    values = desc.split("/")
    keys = test_desc_keys dim, dim_not_a_param
    kv = {}
    keys.each.with_index do |k, i|
      kv[k] = values[i]
    end
    kv
  end

  def params_file
    [
      RESULT_ROOT_DIR,
      self["testcase"],
      "params.yaml",
    ].join "/"
  end

  def each_commit
    return enum_for(__method__) unless block_given?

    path_scheme.each do |axis|
      case axis
      when "commit"
        yield "linux", axis
      when /_commit$/
        yield axis.sub(/_commit$/, ""), axis
      end
    end
  end

  class << self
    def maxis_keys(test_case)
      PATH_SCHEME[test_case].reject { |key| key == "run" }
    end

    #
    # code snippet from MResultRootCollection
    # FIXME rli9 refactor MResultRootCollection to embrace different maxis keys
    #
    def grep(test_case, options = {})
      pattern = [RESULT_ROOT_DIR, test_case, PATH_SCHEME[test_case].map { |key| options[key] || ".*" }].flatten.join("/")

      cmdline = "grep -he '#{pattern}' #{KTEST_PATHS_DIR}/????-??-??-* | sed -e 's#[0-9]\\+/$##' | sort | uniq"
      `#{cmdline}`
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
end
