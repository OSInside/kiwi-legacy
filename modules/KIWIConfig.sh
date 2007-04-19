#!/bin/bash
#================
# FILE          : KIWIConfig.sh
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module contains common used functions
#               : for the config.sh image scripts
#               : 
#               :
# STATUS        : Development
#----------------
#======================================
# suseInsertService
#--------------------------------------
function suseInsertService {
	# /.../
	# Recursively insert a service. If there is a service
	# required for this service it will be inserted first
	# -----
	local service=$1
	local result
	while true;do
		result=`/sbin/insserv $service 2>&1`
		if [ $? = 0 ];then
			echo "Service $service inserted"
			break
		else
			result=`echo $result | head -n 1 | cut -f3 -d " "`
			if [ -f /etc/init.d/$result ];then
				suseInsertService /etc/init.d/$result
			else
				echo "$service: required service: $result not found...skipped"
				break
			fi
		fi
	done
}

#======================================
# suseRemoveService
#--------------------------------------
function suseRemoveService {
	# /.../
	# Remove a service and its dependant services
	# using insserv -r
	# ----
	local service=/etc/init.d/$1
	while true;do
		/sbin/insserv -r $service &>/dev/null
		if [ $? = 0 ];then
			echo "Service $service removed"
			break
		else
			result=`/sbin/insserv -r $service 2>&1|tail -n 2|cut -f10 -d " "`
			if [ -f /etc/init.d/$result ];then
				suseRemoveService $result
			else
				echo "$service: $result not found...skipped"
				break
			fi
		fi
	done
}

#======================================
# suseActivateServices
#--------------------------------------
function suseActivateServices {
	# /.../
	# Check all services in /etc/init.d/ and activate them
	# by calling insertService
	# -----
	for i in /etc/init.d/*;do
		if [ -x $i ] && [ -f $i ];then
			echo $i | grep -q skel
			if [ $? = 0 ];then
				continue
			fi
			suseInsertService $i
		fi
	done
}

#======================================
# suseService
#--------------------------------------
function suseService {
	# /.../
	# if a service exist then enable or disable it using chkconfig
	# example : suseService apache2 on
	# example : suseService apache2 off
	# ----
	local service=$1
	local action=$2
	if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$service ];then
		if [ $action = on ];then
			/sbin/chkconfig $service on
		elif [ $action = off ];then
			/sbin/chkconfig $service off
		fi
	fi
}

#======================================
# suseServiceDefaultOn
#--------------------------------------
function suseServiceDefaultOn {
	# /.../
	# Some basic services that needs to be on.
	# ----
	services=(
		boot.rootfsck
		boot.cleanup
		boot.localfs
		boot.localnet
		boot.clock
		policykitd
		haldaemon
		network
		atd
		syslog
		cron
	)
	for i in "${services[@]}";do
		if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$i ];then
			/sbin/chkconfig $i on
		fi
	done
}

#======================================
# baseSetupBoot
#--------------------------------------
function baseSetupBoot {
	if [ -f /linuxrc ];then
		cp linuxrc init
		exit 0
	fi
}

#======================================
# suseConfig
#--------------------------------------
function suseConfig {
	/sbin/SuSEconfig
}

#======================================
# baseCleanMount
#--------------------------------------
function baseCleanMount {
	umount /proc
	umount /dev/pts
	umount /sys
}
