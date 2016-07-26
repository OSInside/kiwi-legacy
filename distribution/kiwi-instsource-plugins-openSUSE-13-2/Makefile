# /.../
# Copyright (c) 2006 SUSE LINUX Products GmbH. All rights reserved.
# Author: Marcus Schaefer <ms@suse.de>, 2006
#
# Makefile for openSUSE - KIWI Image System InstSource Plugins
# ---
buildroot = /
kiwi_prefix = ${buildroot}/usr/share/kiwi/

#============================================
# Variables... 
#--------------------------------------------
KIWIPLUGINVZ  = ${kiwi_prefix}/modules/plugins/suse-13.2

install:
	#============================================
	# Install base directories
	#--------------------------------------------
	install -d -m 755 ${KIWIPLUGINVZ}

	#============================================
	# Install plugins
	#--------------------------------------------
	install -m 644 ./*.pm  ${KIWIPLUGINVZ}
	install -m 644 ./*.ini ${KIWIPLUGINVZ}
