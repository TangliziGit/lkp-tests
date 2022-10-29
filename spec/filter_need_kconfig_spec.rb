require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require "#{LKP_SRC}/lib/job"

describe 'filter/need_kconfig.rb' do
  before(:each) do
    @tmp_dir = Dir.mktmpdir(nil, '/tmp')
    FileUtils.chmod 'go+rwx', @tmp_dir

    File.open(File.join(@tmp_dir, 'context.yaml'), 'w') do |f|
      f.write({ 'rc_tag' => 'v5.0-rc1', 'kconfig' => 'i386-randconfig' }.to_yaml)
    end

    File.open(File.join(@tmp_dir, '.config'), 'w') do |f|
      f.write("CONFIG_X=y\nCONFIG_Y=200\nCONFIG_Z1=m\nCONFIG_Z2=y")
    end
  end

  after(:each) do
    FileUtils.remove_entry @tmp_dir
  end

  def generate_job(contents = "\n")
    job_file = "#{@tmp_dir}/job.yaml"

    File.open(job_file, 'w') do |f|
      f.puts contents
      f.puts "kernel: #{@tmp_dir}/vmlinuz"
    end

    # Job.open can filter comments (e.g. # support kernel xxx)
    Job.open(job_file)
  end

  context 'when X is disabled in kernel' do
    it 'filters the job' do
      job = generate_job <<~EOF
              need_kconfig:
              - X: n
      EOF
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end

  context 'when X is required to be n on x86_64' do
    it 'does not filter the i386 job' do
      job = generate_job <<~EOF
              need_kconfig:
              - X: n, x86_64
      EOF

      job.expand_params
    end
  end

  context 'when X is required to be n on i386' do
    it 'filters the i386 job' do
      job = generate_job <<~EOF
              need_kconfig:
              - X: n, i386
      EOF
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end

  context 'when Z does not set n/m/y or version' do
    it 'does not filters the job' do
      job = generate_job <<~EOF
              need_kconfig:
              - Z1
              - Z2
      EOF
      job.expand_params
    end
  end

  context 'when Z does not set n/m/y' do
    it 'does not filters the job' do
      job = generate_job <<~EOF
              need_kconfig:
              - Z1: v4.9 # support kernel >=v4.9
      EOF
      job.expand_params
    end
  end

  context 'when X needs to set value' do
    it 'filters the job' do
      job = generate_job <<~EOF
              need_kconfig:
              - X: 200
      EOF
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end

  context 'when the value of Y is the same as kconfig' do
    it 'does not filters the job' do
      job = generate_job <<~EOF
              need_kconfig:
              - Y: 200
      EOF
      job.expand_params
    end
  end

  context 'when the value of Y is not the same as kconfig' do
    it 'filters the job' do
      job = generate_job <<~EOF
              need_kconfig:
              - Y: 100
      EOF
      expect { job.expand_params }.to raise_error Job::ParamError
    end
  end

  context 'when syntax is wrong' do
    it 'raises syntax error' do
      job = generate_job <<~EOF
              need_kconfig:
              - X=y ~ '>= v5.1-rc1' # support kernel >=v5.1-rc1
      EOF

      expect { job.expand_params }.to raise_error Job::SyntaxError
    end
  end

  context 'when X is built-in in kernel' do
    context 'when kernel version meets the constraints' do
      it 'does not filter the job' do
        job = generate_job <<~EOF
          need_kconfig:
            - X: y, v4.9, <= v5.0  # support kernel <=v5.0
        EOF

        job.expand_params
      end
    end

    context 'when kernel version does not meet the constraints' do
      it 'does not filter the job' do
        job = generate_job <<~EOF
                need_kconfig:
                - X: y, >= v5.1-rc1 # support kernel >=v5.1-rc1
        EOF

        job.expand_params
      end
    end

    context 'when kernel version limit is not defined' do
      it 'does not filter the job' do
        # old syntax with
        job = generate_job <<~EOF
                need_kconfig: X=y
        EOF

        job.expand_params

        job = generate_job <<~EOF
                need_kconfig: X
        EOF

        job.expand_params

        job = generate_job <<~EOF
                need_kconfig:
                - X: y
        EOF

        job.expand_params

        job = generate_job <<~EOF
                need_kconfig:
                - X
        EOF

        job.expand_params
      end
    end
  end

  context 'when Y is not built in kernel' do
    context 'when kernel version is within the range' do
      it 'filters the job' do
        job = generate_job <<~EOF
          need_kconfig:
          - Y: m, <= v5.0, v4.9 # support kernel <=v5.0
        EOF

        expect { job.expand_params }.to raise_error Job::ParamError
      end
    end

    context 'when kernel version is not within the range' do
      it 'does not filter the job' do
        job = generate_job <<~EOF
          need_kconfig:
          - Y: m, v5.1-rc1, <= v5.1-rc2 # support kernel >=v5.1-rc1 and <=v5.1-rc2
        EOF

        job.expand_params
      end
    end

    context 'when there is no kernel version constraints' do
      it 'filters the job' do
        job = generate_job <<~EOF
          need_kconfig: Y=m
        EOF

        expect { job.expand_params }.to raise_error Job::ParamError
      end
    end

    context 'when Y is not defined' do
      it 'does not filter the job' do
        job = generate_job

        job.expand_params
      end
    end
  end
end
