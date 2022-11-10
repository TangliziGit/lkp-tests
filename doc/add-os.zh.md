# 支持一个新OS版本

以下假设您的OS名字为$os (取值举例：debian, openeuler等)

## 新增 distro/$os 脚本

一般来说，新增一个符号链接到debian/centos等已有的OS脚本即可。
如果您的OS足够不同，才需要新增一个脚本。

## 确保 lib/detect-system.sh 能识别您的OS

验证方法：

	$ cd lkp-tests
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
然后按提示git提交包列表文件。注意确认下其中的包数量是否正常。

## 验证

察看pkgmap的输出，是否没有任何报错。

以下是在debian:11容器下的输出样例:

in host: 
	$ git clone https://gitee.com/compass-ci/lkp-tests
	$ docker run -it -v $PWD/lkp-tests:/c/lkp-tests debian:11 bash

in container:
	root@1d1e0607d22c:/# cd c/lkp-tests/
	root@1d1e0607d22c:/c/lkp-tests# sbin/install-dependencies.sh
	root@1d1e0607d22c:/c/lkp-tests# . lib/detect-system.sh
	root@1d1e0607d22c:/c/lkp-tests# detect_system
	root@1d1e0607d22c:/c/lkp-tests# echo $_system_version
	11
	root@1d1e0607d22c:/c/lkp-tests# echo $_system_name
	Debian
	root@1d1e0607d22c:/c/lkp-tests# sbin/pkgmap lkp
	PKGBUILD:
	os: bc gawk time kmod gzip debianutils rsync ntpdate hostname util-linux lvm2 numactl net-tools cpio curl wget binutils
	pip:
	gem:
	root@1d1e0607d22c:/c/lkp-tests# sbin/pkgmap makepkg
	PKGBUILD:
	os: curl gnupg2 gettext ncurses-bin binutils fakeroot libarchive-tools file openssl gawk coreutils findutils grep sed gzip bzip2 xz-utils
	pip:
	gem:
	root@1d1e0607d22c:/c/lkp-tests# sbin/pkgmap stream
	PKGBUILD: stream
	os: gcc libc6-dev libssl-dev
	pip:
	gem:

