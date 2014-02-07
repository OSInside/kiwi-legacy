#!/bin/bash
#================
# FILE          : KIWIAnalyseCustom.sh
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2014 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This script find custom files and directories
#               : which does not belong to any RPM package
#               :
#               :
# STATUS        : Development
#----------------
#======================================
# work in POSIX environment
#--------------------------------------
export LANG=C
export LC_ALL=C

#======================================
# Functions
#--------------------------------------
function fileName {
	echo -n /var/run/$1
}

function sortUniq {
	sort -u $1 -o $1
}

function inputFromFile {
	local data=$(cat $1 | tr '\n' ' ')
	echo $data
}

function prune_rpm {
	# when searching for names in the rpm database always
	# ignore special filesystems tmp and root(/)
	echo -n "^/(\$|tmp|dev|proc|sys|run|lost+found)"
}

function prune_find {
	# when searching for files via the find command always
	# ignore special filesystems and tmp
	local ignore="/tmp /dev /proc /sys /run lost+found"
	for i in $ignore;do
		if [[ $i =~ ^/ ]];then
			echo -n "-not -path $i "
		else
			echo -n "-not -name $i "
		fi
	done
}

function getRPMManagedData {
	local dirs_count=0
	local rpm_all_names=$(fileName rpm_all_names)
	local rpm_dir_names=$(fileName rpm_dir_names)
	local rpm_dump=$(fileName rpm_dump)
	if [ ! -e $rpm_dump ];then
		return 1
	fi
	# directories start with mode 040...
	grep ' 040' $rpm_dump | sed -e "s@ [0-9].*@@" |\
		grep -v -E "$(prune_rpm)" > $rpm_all_names
	cp $rpm_all_names $rpm_dir_names
	# all other items different from dir mode
	grep -v ' 040' $rpm_dump | sed -e "s@ [0-9].*@@" >> $rpm_all_names
	rm -f $rpm_dump
	sortUniq $rpm_all_names
	return 0
}

function searchRootFSData {
	local rpm_find_names=$(fileName rpm_find_names)
	local rpm_dir_names=$(fileName rpm_dir_names)
	# perform search, but don't leave this machine
	echo $(inputFromFile $rpm_dir_names) -not -fstype nfs $(prune_find) |\
		xargs find 2>/dev/null > $rpm_find_names
	# perform the search in root(/) with no recursion (maxdepth 0)
	find /* -maxdepth 0 -type d $(prune_find) >> $rpm_find_names
	sortUniq $rpm_find_names
	rm -f $rpm_dir_names
}

function getUnmanagedData {
	local rpm_unmanaged=$(fileName rpm_unmanaged)
	local rpm_find_names=$(fileName rpm_find_names)
	local rpm_all_names=$(fileName rpm_all_names)
	rm -f $rpm_unmanaged
	diff -u $rpm_find_names $rpm_all_names \
		| grep ^-/ | cut -c2- > $rpm_unmanaged
	rm -f $rpm_find_names
	rm -f $rpm_all_names
}

#======================================
# main
#--------------------------------------
if getRPMManagedData;then
	searchRootFSData
	getUnmanagedData
fi

