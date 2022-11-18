[ -n "$LKP_SRC" ] || export LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))

build_os()
{
	for os
	do
		lkp docker build $os
	done
}

install_programs()
{
	local os=$1
	shift

	for program
	do
		lkp docker run $os lkp-install.yaml program=$program
	done
}

run_jobs()
{
	local os=$1
	shift

	if [ -z "$1" ]; then
		lkp docker run $os lkp-run.yaml
		return
	fi

	for job
	do
		lkp docker run $os lkp-run.yaml job=$job
	done
}

# openEuler镜像列表
# https://gitee.com/openeuler/openeuler-docker-images
docker_images=$(<$LKP_SRC/etc/docker-images)
programs=$(ls $LKP_SRC/programs/)

# Example test matrix, please adjust to fit your target
build_os $docker_images
install_programs openeuler/openeuler:22.03-lts $programs
install_programs debian:11 $programs
run_jobs debian:11 stream.yaml netperf-small-threads.yaml
