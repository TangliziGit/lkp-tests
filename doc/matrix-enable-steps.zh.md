# OS测试矩阵使能步骤

lkp docker命令可以帮您便利的使能新OS和新测试用例。

## 参照LKP文档

基本使能原理:

	https://gitee.com/compass-ci/lkp-tests/blob/master/doc/add-os.zh.md
	https://gitee.com/compass-ci/lkp-tests/blob/master/doc/add-testcase.zh.md

lkp docker基本用法:

	$ lkp docker
	Usage:
		lkp docker [options] build DOCKER_IMAGE
		lkp docker [options] run DOCKER_IMAGE JOB_YAML [key=val ...]

	Example:
		# This creates 'lkp-debian:11' docker image locally with generated
		# ~/.cache/lkp/container/Dockerfile.debian:11
		#       FROM debian:11
		#       COPY lkp-src /c/lkp-tests
		#       RUN /c/lkp-tests/sbin/install-dependencies.sh
		lkp docker -m build debian:11
		# You may now run this to enable/debug tests:
		#       docker run -it -v /c/lkp-tests:/c/lkp-tests debian:11 bash

		# This runs /bin/bash in the above created 'lkp-debian:11'
		lkp docker run debian:11

		# This runs lkp-run.yaml with parameter 'job=stream.yaml'
		# which install-and-runs stream.yaml in 'lkp-debian:11'
		lkp docker -m run debian:11 lkp-run.yaml job=stream.yaml

	Options:
		-m      bind mount /home/wfg/.cache/lkp/result into /root/.cache/lkp/result
		-M      bind mount /home/wfg/.cache/lkp        into /root/.cache/lkp

	Note:
	This script runs JOB_YAML in DOCKER_IMAGE, mounting LKP_SRC to /c/lkp-tests
	Results are stored under /root/.cache/lkp/results in container.

## OS容器镜像清单

该列表可供人工查阅和批量测试

	$ cat $LKP_SRC/etc/docker-images
	archlinux
	openeuler/openeuler
	openeuler/openeuler:20.03-lts-sp3
	openeuler/openeuler:22.03-lts
	openanolis/anolisos
	openanolis/anolisos:7.7-x86_64
	opensuse/leap
	oraclelinux:7
	oraclelinux:8
	rockylinux:8
	centos:7
	centos:8
	fedora:32
	fedora:36
	ubuntu:18.04
	ubuntu:20.04
	ubuntu:22.04
	debian:11

## 在原生镜像中做调试使能

	$ docker run -ti -v $LKP_SRC:/c/lkp-tests openeuler/openeuler bash

## 在LKP镜像中做调试使能

	$ lkp docker build openeuler/openeuler  # 创建lkp-openeuler/openeuler镜像，在其中安装LKP框架依赖
	$ lkp docker run   openeuler/openeuler  # 进入lkp-openeuler/openeuler镜像，做交互调试使能

比如此处您可以注册一个新OS版本。在容器内运行

	[root@58a62218e76a lkp-tests]# sbin/add-distro-packages.sh
	git add distro/package-list/openeuler@22.03:aarch64
	git commit distro/package-list/openeuler@22.03:aarch64 -m 'distro/packages: add openeuler@22.03:aarch64'

在容器外lkp-tests目录下，拷贝粘帖执行上述两个git命令，并向上游仓提交PR。

## 手动安装运行一个job

	~/lkp-tests/programs/stream/jobs# lkp split stream.yaml
	~/lkp-tests/programs/stream/jobs# lkp install ./stream-50000000-10x-100-100%.yaml
	~/lkp-tests/programs/stream/jobs# lkp run ./stream-50000000-10x-100-100%.yaml

## 批量安装运行一组jobs

上述手工步骤，我们做了封装。您可以方便的用如下命令，在一个指定OS容器上跑

	$ lkp docker -m run openeuler/openeuler lkp-run.yaml job=stream.yaml

以便批量执行验证。当去掉最后的job=xxx参数时，它会跑一组预置jobs

	$ lkp docker -m run openeuler/openeuler lkp-run.yaml

## 调试依赖包列表

最大的一类适配问题来自于依赖的缺失。如下命令可方便的调试一个program的依赖是否符合预期。

	$ lkp pkgmap --to-os openeuler@22.03 unixbench
	PKGBUILD: unixbench
	os: perl perl-devel make

	$ lkp pkgmap --to-os openeuler@22.03 netperf
	PKGBUILD:
	os: lksctp-tools ethtool

比如这里的netperf依赖里没有netperf包，需要fix。一般检察下列地方

	programs/netperf/meta.yaml 	# 看其中的depends字段
	programs/netperf/PKGBUILD 	# 看其中的depends*, makedepends*字段
	distro/package-list/		# 看目标OS是否自带netperf相关包
	distro/pkgmap/			# 必要时添加包名映射到目标OS
