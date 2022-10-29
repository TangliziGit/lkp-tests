#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(File.dirname(__dir__))

require 'git'
require "#{LKP_SRC}/lib/string_ext"

module Git
  class Lib
    def command_lines(cmd, opts = [], _redirect = '', chdir: true)
      command_lines = command(cmd, opts, chdir: chdir)

      # to deal with "GIT error: cat-file ["commit", "9f86262dcc573ca195488de9ec6e4d6d74288ad3"]: invalid byte sequence in US-ASCII"
      # - one possibility is the encoding of string is wrongly set (due to unknown reason), e.g. UTF-8 string's encoding is set as US-ASCII
      #   thus to force_encoding to utf8_string and compare to error check of utf8_string, if same, will consider as wrong encoding info
      command_lines.resolve_invalid_bytes
                   .split("\n")
    end

    public :command_lines
    public :command

    alias orig_command command

    ENV_VARIABLE_NAMES = %w(GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_SSH).freeze unless defined? ENV_VARIABLE_NAMES

    def command(cmd, opts = [], redirect = '', chdir: true, &block)
      system_env_variables = Hash[ENV_VARIABLE_NAMES.map { |name| [name, ENV[name]] }]

      orig_command(cmd, opts, chdir, redirect, &block)
    ensure
      system_env_variables.each { |name, value| ENV[name] = value }
    end
  end
end
