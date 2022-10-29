#!/usr/bin/env ruby

class KernelTag
  include Comparable
  attr_reader :kernel_tag

  def initialize(kernel_tag)
    @kernel_tag = kernel_tag
  end

  # Convert kernel_tag to number, major *1000 + minor * 100 + prerelease
  # If kernel is not a rc version. Set prerelease as 99.
  # E.g. kernel_tag: v5.7-rc3 ==> 5 * 10000 + 7 * 100 + 3 = 50703
  # kernel_tag: v5.7 ==> 5 * 10000 + 7 *100 + 99 = 50799
  # kernel_tag: v4.20-rc2 ==> 4 * 10000 + 20 * 100 + 2 = 42002
  def numerize_kernel_tag(kernel_tag)
    match = kernel_tag.match(/v(?<major_version>[0-9])\.(?<minor_version>\d+)\.?(?:-rc(?<prerelease_version>\d+))?/)
    prerelease_version = if match[:prerelease_version]
                           match[:prerelease_version].to_i
                         else
                           99
                         end
    match[:major_version].to_i * 10_000 + match[:minor_version].to_i * 100 + prerelease_version
  end

  def <=>(other)
    numerized_kernel_version1 = numerize_kernel_tag(@kernel_tag)
    numerized_kernel_version2 = numerize_kernel_tag(other.kernel_tag)

    numerized_kernel_version1 <=> numerized_kernel_version2
  end
end

def kernel_match_version?(kernel_version, expected_kernel_versions)
  kernel_version = KernelTag.new(kernel_version)

  expected_kernel_versions.all? do |expected_kernel_version|
    match = expected_kernel_version.match(/(?<operator>==|!=|<=|>|>=)?\s*(?<kernel_tag>v[0-9]\.\d+(?:-rc\d+)*)/)
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
