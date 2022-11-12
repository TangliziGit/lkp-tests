#!/bin/bash

create_lkp_user() {
	grep -q ^lkp: /etc/passwd && return

	if is_docker || is_virt; then
		# In docker/qemu, we can safely add lkp user.
		input=y
	else
		echo -n "Do you agree to create lkp users for testing? [Y/n] "
		read -t 10 input
	fi

	case $input in
		N|n)
			echo "error: lkp user is required to run lkp tests"
			exit 1
		;;
		*)
			useradd -m -s /bin/bash lkp
			if [ $? -eq 0 ]; then
				echo "Create lkp user successfully."
			else
				echo "Create lkp user failed."
				exit 1
			fi
		;;
	esac
}
