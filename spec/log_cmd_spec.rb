require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'shellwords'
require "#{LKP_SRC}/lib/bash"

describe 'log_cmd' do
  let(:log_cmd) { "#{LKP_SRC}/bin/log_cmd " }
  before(:all) do
    @pwd = Dir.pwd
    @tmp_dir = Dir.mktmpdir
    FileUtils.chmod 'go+rwx', @tmp_dir
    ENV['TMP_RESULT_ROOT'] = @tmp_dir
    Dir.chdir(@tmp_dir)
  end

  it 'creates multi dirs' do
    was_good = Bash.call2("#{log_cmd}mkdir a b")
    expect(was_good).to be_truthy
    expect(Dir).to be_exist('a')
    expect(Dir).to be_exist('b')
    Dir.delete('a')
    Dir.delete('b')
  end

  it 'creates dir with space' do
    was_good = Bash.call2("#{log_cmd}mkdir \"a b\"")
    expect(was_good).to be_truthy
    expect(Dir).to be_exist('a b')
    Dir.delete('a b')
  end

  it 'creates dir with single quote' do
    dir = '"a'
    was_good = Bash.call2("#{log_cmd}mkdir #{Shellwords.escape(dir)}")
    expect(was_good).to be_truthy
    expect(Dir).to be_exist('"a')
    Dir.delete('"a')
  end

  it 'creates dir with space and double quotes' do
    dir = '"a b"'
    was_good = Bash.call2("#{log_cmd}mkdir #{Shellwords.escape(dir)}")
    expect(was_good).to be_truthy
    expect(Dir).to be_exist('"a b"')
    Dir.delete('"a b"')
  end

  it 'parses echo reserve parameter' do
    was_good = Bash.call2("#{log_cmd}ls -n")
    expect(was_good).to be_truthy
  end

  it 'execute built-in command' do
    was_good = Bash.call2("#{log_cmd}cd .")
    expect(was_good).to be_truthy
  end

  after(:all) do
    FileUtils.rm_rf(@tmp_dir)
    Dir.chdir(@pwd)
  end
end
