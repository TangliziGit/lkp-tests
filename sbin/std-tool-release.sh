#!/bin/bash

[ -n "$LKP_SRC" ] || LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))

SRCDEST=$HOME/.cache/lkp/sources/
TMP_DIR=/tmp/std-tool
OUT_TARBALL=/tmp/std-tool-`date +%F`.tgz

handle_program()
{
	local pdir=$1
	local program=$(basename $pdir)
	[[ $pdir =~ /lkp-tests|makepkg/ ]] && return
	[[ -f $pdir/PKGBUILD ]] || return 0
	#  [[ $program = stream ]] || return 0

	(
		cd "$pdir" || exit
		"$LKP_SRC/sbin/makepkg" --config "$LKP_SRC/etc/makepkg.conf" --skippgpcheck --nodeps --nobuild || exit

		for lfile in $(find src -maxdepth 1  -type l)
		do
			file=$(basename $lfile)
			test -f $file && continue
			# the downloaded source
			cp $lfile .
			sed -i 's/\(source=([''"]\).*\//\1/'	PKGBUILD
		done
		if grep -q 'source=.*\.git' PKGBUILD; then
			repo=$(grep -o 'source=.*\.git' PKGBUILD | sed -e 's:.*/::' -e 's/\.git$//')
			sed -i "s/^source=([^ ]*\.git['"\""]/source=('$repo.tgz'/" PKGBUILD
			git clone src/$repo	# clear possible patches
			tar czf $repo.tgz $repo
			rm -fr $repo
		fi
		rm -fr src
	)
}

handle_programs()
{
	for d in $TMP_DIR/programs/$program/*/
	do
		handle_program $d
	done
}


rm -fr "$TMP_DIR"
mkdir -p $TMP_DIR
rsync -ar "$LKP_SRC" --files-from=$LKP_SRC/etc/std-tool-files $TMP_DIR/

cd "$TMP_DIR"

handle_programs

tar czf $OUT_TARBALL $TMP_DIR

echo "Created $OUT_TARBALL"
