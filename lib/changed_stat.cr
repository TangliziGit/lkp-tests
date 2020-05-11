#!/usr/bin/env ruby

LKP_SRC = ENV["LKP_SRC"] || File.dirname(__DIR__)

require "ostruct"
require "./lkp_git"
require "./yaml"
require "./result"
require "./bounds"
require "./constant"
require "./statistics"
require "./log"
require "./tests"

module LKP
  class ChangedStat
    getter :cs, :options

    def initialize(stat, sorted_a, sorted_b, options)
      min_b, mean_b, max_b = get_min_mean_max sorted_b
      min_a, mean_a, max_a = get_min_mean_max sorted_a

      @cs = OpenStruct.new sorted_a: sorted_a, min_a: min_a, mean_a: mean_a, max_a: max_a,
                           sorted_b: sorted_b, min_b: min_b, mean_b: mean_b, max_b: max_b,
                           stat: stat
      @options = options
    end

    %w(sorted_a min_a mean_a max_a sorted_b min_b mean_b max_b stat).each do |name|
      define_method(name) do
        cs[name]
      end
    end

    def failure?
      @failure ||= options["force_" + stat] || is_failure(stat)
    end

    def latency?
      @latency ||= is_latency(stat)
    end

    def change?
      if options["distance"]
        if max_a.is_a?(Integer) && (min_a - max_b == 1 || min_b - max_a == 1)
          log_cause "min_a - max_b == 1 || min_b - max_a == 1"
          log_debug "not cs | cs: #{cs}" if options["trace_cause"] == stat

          return false
        end

        if sorted_a.size < 3 || sorted_b.size < 3
          len_a = max_a - min_a
          len_b = max_b - min_b
          min_gap = [len_a, len_b].max * options["distance"]

          return true if min_b - max_a > min_gap
          log_cause "NOT: min_b - max_a > min_gap (#{min_gap})"

          return true if min_a - max_b > min_gap
          log_cause "NOT: min_a - max_b > min_gap (#{min_gap})"
        else
          return true if min_b > max_a && (min_b - max_a) > (mean_b - mean_a) / 2
          log_cause "NOT: min_b > max_a && (min_b - max_a) > (mean_b - mean_a) / 2"

          return true if min_a > max_b && (min_a - max_b) > (mean_a - mean_b) / 2
          log_cause "NOT: min_a > max_b && (min_a - max_b) > (mean_a - mean_b) / 2"
        end
      else
        return true if min_b > mean_a && mean_b > max_a
        log_cause "NOT: min_b > mean_a && mean_b > max_a"

        return true if min_a > mean_b && mean_a > max_b
        log_cause "NOT: min_a > mean_b && mean_a > max_b"
      end

      log_debug "not cs | cs: #{cs}" if options["trace_cause"] == stat
      false
    end

    def to_s
      cs.to_s
    end

    def log_cause(cause)
      return unless options["trace_cause"] == stat

      %w(sorted_a min_a mean_a max_a sorted_b min_b mean_b max_b stat).each do |name|
        cause = cause.gsub(name, "#{name} (#{eval name})")
      end

      log_debug "not cs | cause: #{cause}"
    end
  end
end
