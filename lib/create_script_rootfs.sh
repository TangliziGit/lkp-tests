#!/bin/sh

SCRIPT_DIR=$(dirname $(realpath $0))
# PROJECT_DIR=$(dirname $SCRIPT_DIR)

create_rootfs()
{
	for i in "$LKP_SRC"/rootfs/tests/$1/.*
	do
		cp -rd $i /
	done
}
