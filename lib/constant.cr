#!/usr/bin/env crystal

require "./run_env"

DEVEL_HOURLY_KCONFIGS = %w(x86_64-rhel-7.6).freeze
GIT_ROOT_DIR = "/lkp/repo".freeze

TESTCASE_AXIS_KEY = "testcase".freeze
COMMIT_AXIS_KEY = "commit".freeze
TBOX_GROUP_AXIS_KEY = "tbox_group".freeze

KERNEL_ROOT = "/pkg/linux".freeze
KTEST_USER_GENERATED_DIR = "/lkp/user-generated"
KTEST_DATA_DIR = "/lkp/data".freeze
KTEST_PATHS_DIR = "/lkp/paths".freeze
RESULT_ROOT_DIR = "/lkp/result".freeze
