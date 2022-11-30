#!/usr/bin/env ruby
#
# https://www.bcg.wisc.edu/webteam/support/ruby/standard_deviation

# Add methods to Enumerable, which makes them available to Array

require 'active_support/core_ext/enumerable'

module Enumerable
  def average
    sum / length.to_f
  end

  def sorted
    s = sort
    s.shift while s[0] == -1 # -1 means empty data point
    s
  end

  def mean_sorted
    s = sorted
    if s.size <= 2
      [s.average, s]
    else
      [s[s.size / 2], s]
    end
  end

  def sample_variance
    avg = average
    sum = inject(0) { |acc, i| acc + (i - avg)**2 }
    1 / length.to_f * sum
  end

  def standard_deviation
    Math.sqrt(sample_variance)
  end

  def relative_stddev
    standard_deviation * 100 / average
  end

  def harmonic_mean
    inv_sum = inject(0) { |res, i| res + 1 / i }
    length / inv_sum
  end

  def geometry_mean
    log_sum = inject(0) { |res, i| res + Math.log(i) }
    Math.exp(log_sum / length)
  end

end
