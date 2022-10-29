require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/job"

describe 'filter/need_kernel_version.rb' do
  before(:each) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
    FileUtils.chmod 'go+rwx', @tmp_dir
  end

  after(:each) do
    FileUtils.remove_entry @tmp_dir
  end

  def generate_context(compiler, kernel_version)
    dir = File.join(@tmp_dir, compiler)
    FileUtils.mkdir_p(dir)
    FileUtils.touch("#{dir}/vmlinuz")
    File.open(File.join(dir, 'context.yaml'), 'w') do |f|
      f.write({ 'rc_tag' => kernel_version }.to_yaml)
    end
  end

  def generate_job(compiler, contents = "\n")
    job_file = "#{@tmp_dir}/job.yaml"

    File.open(job_file, 'w') do |f|
      f.puts contents
      f.puts "kernel: #{@tmp_dir}/#{compiler}/vmlinuz"
    end

    # Job.open can filter comments (e.g. # support kernel xxx)
    Job.open(job_file)
  end

  context 'kernel is not satisfied' do
    { 'v4.16' => 'gcc', 'v5.11' => 'clang' }.each do |version, compiler|
      it "filters the job built with #{compiler}" do
        generate_context(compiler, version)
        job = generate_job compiler, <<~EOF
              need_kernel_version:
              - '>= v4.17, gcc'
              - '>= v5.12, clang'
        EOF
        expect { job.expand_params }.to raise_error Job::ParamError
      end
    end
  end

  context 'kernel is satisfied' do
    { 'v5.0' => 'gcc', 'v5.12' => 'clang' }.each do |version, compiler|
      it "does not filters the job built with #{compiler}" do
        generate_context(compiler, version)
        job = generate_job compiler, <<~EOF
              need_kernel_version:
              - '>= v4.17, gcc'
              - '>= v5.12, clang'
        EOF
        job.expand_params
      end
    end
  end
end
