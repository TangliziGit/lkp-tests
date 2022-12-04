# 调试方法

## 从错误定位到代码

当遇到一个错误消息时，如果判断是个通用问题，那么可以抽取关键信息输入google搜索。
如果判断是lkp框架代码的错误消息，那么抽取其中的固定字符串，在代码里搜索：

	$ git grep "错误消息字符串"
	$ git grep "关键字"

因为非常常用，我建了以下两个快捷命令：

	alias gg='git grep --color -n'
	egg () {
		local search="${@: -1}"
		search="${search//\//\\/}"
		vim +/"${search}" $(git grep -l "$@")
	}

平时一般先搜索确认，然后快速打开相关文件编辑：

	$ gg "关键字"
	$ egg "关键字"

## shell调试

如果问题所在代码是shell脚本，那么可以在其前方/调用栈上，打开调试选项

	set -x # 打开调试
	待调试代码段
	set +x # 关闭调试

然后重新执行，即可看到此代码段的详细执行过程，变量/命令内容。

LKP框架对您写的run/setup等shell测试脚本，会用`$LKP_DEBUG`调用。
所以您可以在需要时设置这一参数。以下是若干方式：

	$ lkp run some-job.yaml LKP_DEBUG=1
	$ LKP_DEBUG=1 lkp run some-job.yaml

有时候，可以直接在job YAML里加上这一行

	LKP_DEBUG: 1
