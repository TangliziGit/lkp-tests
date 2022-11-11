# 添加测试用例

## 样例

如下目录中的文件，完整的添加了一个典型的测试用例memtier:

	programs/memtier/jobs/memtier-dcpmm.yaml	# 在job YAML里指定想跑的programs/params
	programs/memtier/jobs/memtier.yaml		# 可以预定义很多的jobs
	programs/memtier/meta.yaml			# memtier描述文件
	programs/memtier/PKGBUILD			# memtier下载编译
	programs/memtier/run				# memtier运行脚本
	programs/memtier/parse				# memtier结果解析

如果加的program type属于monitor/setup脚本，则需要放到对应的monitors/, setup/目录下，而非programs/目录。
集中存放monitor/setup脚本，有利于他人查找和复用。

其中jobs/下的YAML文件，定义了memtier的各种常见运行参数、及与其它脚本的组合。
用户要跑其中的一个测试组合，典型步骤如下

	# 把job YAML从矩阵描述形式分解为一系列原子任务
	$ lkp split memtier-dcpmm.yaml
	jobs/memtier-dcpmm.yaml => ./memtier-dcpmm-1-cs-localhost-0-8-1-1-65535-never-never.yaml
	jobs/memtier-dcpmm.yaml => ./memtier-dcpmm-1-cs-localhost-0-24-1-1-65535-never-never.yaml

	# 安装依赖，包括安装meta.yaml里depends字段描述的软件包，以及调用PKGBUILD
	$ lkp install ./memtier-dcpmm-1-cs-localhost-0-8-1-1-65535-never-never.yaml

	# 运行任务，会调用其中指定的各run脚本，结果保存到/lkp/result/下一个新建的目录里
	# 结束后自动运行各parse脚本，提取各结果指标并汇集到stats.json
	$ lkp run ./memtier-dcpmm-1-cs-localhost-0-8-1-1-65535-never-never.yaml

## 概述

一个测试用例一般涉及如下部分

	1) 基本信息说明			# meta.yaml metadata部分
	2) 安装哪些依赖			# meta.yaml depends字段
	3) 下载编译一些程序		# PKGBUILD脚本
	4) 对所在环境做哪些设置		# run脚本 (type=setup)
	5) 监控系统的一些状态		# run脚本 (type=monitor)
	6) 运行哪些程序，以什么参数运行	# run脚本 (type=workload)
	7) 怎么解析结果，抽取度量指标	# parse脚本

为了实现最大的灵活性、可复用性，我们以job-program-param三层模型来组织测试用例。
一个job YAML的典型内容为

	monitor_program1:
	monitor_program2:
	...
	setup_program1:
		param1:
		param2:
	setup_program2:
		param1:
	...
	workload_program1:
		param1:
	workload_program2:
		param1:
		param2:

其中每个脚本只做一件事，这样组合起来会很灵活和强大。monitor/setup programs的可复用性就很好。

用户跑一个用例的入口是job，可以自己书写job，也可以使用jobs/目录下预定义的job。
当运行一个job时，lkp会找到job中指定的各类programs，以指定的params key/val为环境变量，执行各program。
确切的规则如下

	# job YAML 内容

		$program:
		   param1: val1
		   param2: val2

	# lkp install job 执行的伪代码

		find programs/$program/meta.yaml or
		     programs/**/meta-$program.yaml

		for each package in meta YAML's depends field:
			check install package RPM/DEB
			if OS has no such package:
				find programs/$package/PKGBUILD or
				     programs/**/PKGBUILD-$package
				makepkg for the first found one

	# lkp run job 执行的 shell 伪代码

		# run
		export param1=val1
		export param2=val2
		find programs/$program/run or
		     programs/**/run-$program
		run the first found one, redirecting stdout/stderr to $RESULT_ROOT/$program
		# parse
		run its parse script < $RESULT_ROOT/$program | dump-stat to $RESULT_ROOT/$program.json
		unite all $RESULT_ROOT/$program.json to $RESULT_ROOT/stats.json

## 添加meta.yaml描述文件

一个meta.yaml文件描述一个program，其结构如下

	metadata:
		name: 		# 程序名
		summary: 	# 单行描述
		description: 	# 多行/多段详细描述
		homepage: 	# 脚本所调用程序的上游项目的主页URL
	type: 			# monitor|setup|daemon|workload
	monitorType: 		# one-shot|no-stdout|plain
	depends:
		gem: 			# ruby gem 依赖
		pip: 			# python pip 依赖
		ubuntu@22.04: 		# ubuntu 22.04的DEB包依赖
		openeuler@22.03:	# openeuler 22.03的RPM包依赖
	pkgmap: # 各OS之间的包名映射，这样我们可以在depends里指定一个OS的完整依赖列表，通过少量包名映射来支持其它OS
	        archlinux..debian@10:
		debian@10..openeuler@22.03: # 以下为两个样例
			dnsutils: bind-utils
			cron: cronie
	params: # run脚本可以接受的环境变量参数，以下为样例
		runtime:
			type: timedelta
			doc: length of time, with optional human readable time unit suffix
			example: 1d/1h/10m/600s
		ioengine:
			type: str
			values: sync libaio posixaio mmap rdma
	results: # parse脚本可以从结果中提取的metrics，以下为样例
		write_bw_MBps:
			doc: average write bandwidth
			kpi: 1 # weight for computing performance index; negative means the larger the worse

## 添加job YAML

一般我们需要主要跑一个type=workload的program，同时再跑一些type=monitor/setup/daemon的programs，加上它们的参数，构成一个完整的测试用例。
我们用一个个的job YAML来描述这些测试用例。

所以预定义job YAML大体上可以按workload来组织，放在路径下

	programs/$workload/jobs/xxx.yaml

当然也可以按更大粒度来组织，比如场景、测试类型等分类，此时可以放在路径下

	jobs/$test_scene/xxx.yaml
	jobs/$test_class/xxx.yaml

以上预定义jobs的搜索路径，lkp框架代码都支持。具体path glob pattern是

	programs/*/jobs/*.yaml
	jobs/**/*.yaml

## 添加程序

Job YAML中引用的programs，需要您预先写好，lkp会在如下路径搜索其文信息/脚本：

	1st search path				2nd search path
	programs/$program/meta.yaml		programs/**/meta-$program.yaml
	programs/$program/{run,parse} 		programs/**/{run,parse}-$program
	programs/$package/PKGBUILD 		programs/**/PKGBUILD-$package

程序一般添加到 programs/$program/ 目录下，具体添加以下几个脚本

	programs/$program/meta.yaml	# 描述文件
	programs/$program/run		# 接收/转换环境变量传过来的参数，运行目标程序
	programs/$program/parse		# 解析结果(一般是run的stdout)，输出metrics (YAML key/val)
	programs/$program/PKGBUILD	# 下载编译安装run调用的目标程序

其中PKGBUILD仅必要时添加。parse一般在program type=monitor/workload时才需要。

一般一个program一个目录。但有时候client/server类型的测试，把workload+daemon programs放在一起比较方便。
此时可以参照sockperf，把sockperf-server daemon以如下方式添加到sockperf workload目录下：

	programs/sockperf/meta-sockperf-server.yaml
	programs/sockperf/run-sockperf-server

## 添加依赖

一个program的依赖表述为

        programs/$program/meta.yaml
                depends:
                        debian@10:
			- $package1
			- $package2
		pkgmap:
			debian@10..centos@8: # centos 8不自带$package2，映射为空
				$package2:

        programs/$program/PKGBUILD-$package1
        programs/$program/PKGBUILD-$package2

这里定义了两类依赖 1) OS自带的包 2) 需要从源码下载编译的包
当OS包含package1/package2时，lkp框架可自动安装对应的rpm/deb;
如果没有，再使用PKGBUILD-xxx构建出包。

例如，在debian 10中，lkp install会执行

	apt-get install $package1 $package2

在在centos 8中，lkp install会执行

	yum install $package1
	makepkg PKGBUILD-$package2 # 从源码下载编译

如您希望强制从源码编译下载，无论所在OS是否包含RPM/DEB包，那么可以通过指定PKGBUILD依赖

	depends:
		PKGBUILD:
		- $package1

那么lkp install会无条件编译$package1

注意，PKGBUILD语义上对应一个$package，而不是对应$program。
这两者语义上不同，虽然很多时候两者内容是一样的。当内容一样时，比如

        programs/$program/PKGBUILD-$package

也可以写为简化形式

        programs/$program/PKGBUILD # when $package=$program

注意，PKGBUILD文件名及其内部depends/makedepends字段里的$package使用的是archlinux包名。
所以其它OS缺失此包，或者有此包，但是名字不一样的话，需要配置对应的pkgmap包名映射，或者加上OS后缀，比如

	makedepends_debian_11=(lam4-dev libopenmpi-dev libmpich-dev pvm-dev)
