LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require 'English'
require 'shellwords'
require 'open3'

# rli9 FIXME: find a way to combine w/ misc
module Bash
  class BashCallError < StandardError
  end

  class << self
    # http://greyblake.com/blog/2013/09/21/how-to-call-bash-not-shell-from-ruby/
    def call(command, options = {})
      options[:exitstatus] ||= [0]

      output = `bash -c #{Shellwords.escape(command)}`.chomp
      raise Bash::BashCallError, command unless options[:exitstatus].include?($CHILD_STATUS.exitstatus)

      output
    end

    def call2(*command)
      stdout, stderr, status = Open3.capture3(*command)

      return stdout if status.success?

      raise Bash::BashCallError, "#{command}\n#{stderr}#{stdout}" unless block_given?

      yield stdout, stderr, status
    end
  end
end

module Bashable
  def exec_cmd(cmd, do_exec: true, verbose: false, pipe: false, &block)
    if do_exec
      puts cmd if verbose

      block ||= ->(line) { puts line }

      lines = []
      IO.popen(cmd, err: %i(child out)) do |io|
        io.each_line do |line|
          block.call line.chomp if pipe

          lines << line
        end

        io.flush
      end

      unless $CHILD_STATUS.success?
        puts lines.join unless lines.empty?
        raise "cmd: #{cmd.inspect}, exitstatus: #{$CHILD_STATUS.exitstatus}"
      end

      lines.join
    elsif verbose
      puts "$ #{cmd}"
    end
  end
end

module Bash
  extend Bashable
end
