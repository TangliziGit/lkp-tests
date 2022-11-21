# 支持一个新OS版本

主要有两步，结果作为两个patch提交：
1) 改进 lib/detect-system.sh 以识别您的OS。一般做一次即可
2) 运行 sbin/add-distro-packages.sh 新增特定OS版本的包列表到 distro/package-list/ 目录。第一次是必需的，以后每次有新的OS版本，都建议跑一下，以便pkgmap运行结果更准确。

以下假设您的OS名字为$os (取值举例：debian, openeuler等)

## 新增 distro/$os 脚本

一般来说，新增一个符号链接到与您OS同源的debian/centos等已有的OS脚本即可。
如果您的OS足够不同，才需要新增一个脚本。例如:

	$ cd lkp-tests
	$ ln -s distro/debian distro/$os

## 修改 lib/detect-system.sh文件，增加对您OS的识别字段，确保 lib/detect-system.sh 能识别您的OS

验证方法：

	$ cd lkp-tests
	$ LKP_SRC=$(pwd)
	$ . lib/detect-system.sh
	$ detect_system
	$ echo $_system_name_lowercase
	debian
	$ echo $_system_version
	11

如果输出结果 `$_system_name_lowercase` 与 `$os` 不匹配，那么可以这样调试

	$ set -x # 开始调试，打印shell执行log
	$ detect_system
	$ set +x # 关闭调试，从后往前看log

## 新增特定OS版本的包列表到 distro/package-list/ 目录

在目标OS环境下，执行如下语句

	$ cd lkp-tests
	$ sbin/add-distro-packages.sh

然后按提示git提交包列表文件。提交前注意确认下 distro/package-list/$os 文件中包数量是否正常。

## 验证

察看pkgmap的输出，是否没有任何报错。

以下是在debian:11 OS下的输出样例:

	root@1d1e0607d22c:/# cd c/lkp-tests/
	root@1d1e0607d22c:/c/lkp-tests# sbin/install-dependencies.sh
	root@1d1e0607d22c:/c/lkp-tests# LKP_SRC=$(pwd)
	root@1d1e0607d22c:/c/lkp-tests# . lib/detect-system.sh
	root@1d1e0607d22c:/c/lkp-tests# detect_system
	root@1d1e0607d22c:/c/lkp-tests# echo $_system_version
	11
	root@1d1e0607d22c:/c/lkp-tests# echo $_system_name
	Debian
	root@1d1e0607d22c:/c/lkp-tests# sbin/add-distro-packages.sh
	git add distro/package-list/debian@11
	git commit distro/package-list/debian@11 -m 'distro/packages: add debian@11'
	root@1d1e0607d22c:/c/lkp-tests# bin/lkp pkgmap lkp-tests
	PKGBUILD:
	os: bc gawk time kmod gzip debianutils rsync ntpdate hostname util-linux lvm2 numactl net-tools cpio curl wget binutils procps
	pip:
	gem:
	root@1d1e0607d22c:/c/lkp-tests# bin/lkp pkgmap makepkg
	PKGBUILD:
	os: libarchive-tools curl gnupg2 gettext ncurses-bin binutils fakeroot file openssl gawk coreutils findutils grep sed gzip bzip2 xz-utils gcc g++ autoconf automake make
	pip:
	gem:
	root@1d1e0607d22c:/c/lkp-tests# bin/lkp pkgmap stream
	PKGBUILD: stream
	os: gcc libc6-dev libssl-dev
	pip:
	gem:

