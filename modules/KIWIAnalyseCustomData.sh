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
function checkEnv {
	# check if all tools used in this code exists
	for tool in find tr sort split cut cat grep rpm diff;do
		if ! type -p $tool &>/dev/null;then
			echo "Required tool $tool not found"
			exit 1
		fi
	done
}

function fileName {
	# global location for runtime and result files
	echo -n /tmp/$1
}

function sortUniq {
	# sort and uniq the given stream
	sort -u $1 -o $1
}

function filter_items {
	# files and directories matching here are filtered out
	echo -n "^/(\$|tmp|dev|proc|sys|run|lost\+found|var\/run)"
}

function filter_filesystem {
	# filesystems with the given blockid are filtered out
	for fs in nfs tmpfs proc sysfs devtmpfs devpts;do
		echo -n "-not -fstype $fs "
	done
}

function inputFromFile {
	# turn lines from file into space separated argument list
	local data=$(cat $1 | grep -v -E "$(filter_items)" | tr '\n' ' ')
	echo $data
}

function quote {
	# translate '\n' with '\a' leave all other characters untouched
	# translate '\0' to '\n' to get our lines back
	tr "\n" "\a" | tr "\0" "\n"
}

function getRPMManagedData {
	# lookup rpm database for all files and directories
	local cur_dir
	local rpm_all_names=$(fileName rpm_all_names)
	local rpm_dir_names=$(fileName rpm_dir_names)
	local rpm_dump=$(fileName rpm_dump)
	if [ ! -e $rpm_dump ];then
		echo "Failed to dump data from RPM database"
		exit 1
	fi
	# directories start with mode 040...
	grep ' 040' $rpm_dump | sed -e "s@ [0-9].*@@" |\
		grep -v -E "$(filter_items)" > $rpm_all_names
	cp $rpm_all_names $rpm_dir_names
	# all other items different from dir mode
	grep -v ' 040' $rpm_dump | sed -e "s@ [0-9].*@@" >> $rpm_all_names
	# remove rpm dump file
	rm -f $rpm_dump
	# sort and uniq result files
	sortUniq $rpm_all_names
	sortUniq $rpm_dir_names
	# strip rpm directory list to minimal list for later
	# recursive search in a find call
	rm -f ${rpm_dir_names}.stripped
	while read dir; do
		if [ ! -z "$cur_dir" ] && [[ $dir =~ ^$cur_dir ]];then
			continue
		fi
		cur_dir=$dir
		echo $dir >> ${rpm_dir_names}.stripped
	done < $rpm_dir_names
	mv ${rpm_dir_names}.stripped $rpm_dir_names
	return 0
}

function searchRootFSData {
	# search files and directories of this system. The search
	# method is based on the managed RPM directories. This is
	# faster than recursively searching through the entire '/'
	# filesystem. This method could skip some of the files
	# in a way that e.g only /music is detected but not all
	# files stored inside /music. If something like that happens
	# depends on the structure of the RPM managed items as well
	# as on the location people put custom files in. The goal
	# is not to find each and every custom file but at least
	# one target to cover all areas where custom files are
	# stored
	local rpm_find_names=$(fileName rpm_find_names)
	local rpm_dir_names=$(fileName rpm_dir_names)
	# perform the search in root(/) with no recursion (maxdepth 0)
	find /* -maxdepth 0 -type d -print0 | quote |\
		grep -v -E "$(filter_items)" > $rpm_find_names
	# perform search in junks, but don't leave this machine
	split -l 1000 $rpm_dir_names ${rpm_dir_names}_part
	for part in ${rpm_dir_names}_part*;do
		find_options="$(inputFromFile $part)"
		find_options="$find_options $(filter_filesystem)"
		find_options="$find_options -print0"
		echo $find_options | xargs -x find 2>/dev/null | quote |\
			grep -v -E "$(filter_items)" >> $rpm_find_names
	done
	# sort and uniq result files
	sortUniq $rpm_find_names
	# remove rpm directory and split part files
	rm -f $rpm_dir_names
	rm -f ${rpm_dir_names}_part*
}

function getUnmanagedData {
	# unmanaged files are the diff between the items in the
	# RPM database compared to the result of the find call
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
checkEnv
if getRPMManagedData;then
	searchRootFSData
	getUnmanagedData
fi

