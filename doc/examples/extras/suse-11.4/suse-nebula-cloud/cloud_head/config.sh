#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Robert Scwheikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : OpenNebula cloud head node
#               :
#               :
# STATUS        : BETA
#----------------
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#======================================
# Setup baseproduct link
#--------------------------------------
suseSetupProduct

#======================================
# Activate services
#--------------------------------------
suseActivateDefaultServices
suseInsertService boot.device-mapper
suseInsertService nfsserver
suseInsertService sshd

#======================================
# SuSEconfig
#--------------------------------------
baseUpdateSysConfig /etc/sysconfig/firstboot FIRSTBOOT_WELCOME_DIR /usr/share/susenebula
# Disable IPv6
echo “alias net-pf-10 off” >> /etc/modprobe.conf.local
echo “alias ipv6 off” >> /etc/modprobe.conf.local
suseConfig

#======================================
# Cloud specific settings
#--------------------------------------
# Directory for authentication file must exist such that YaST module can
# write the file
mkdir /var/lib/one/.one
# Set the desired permissions
chown oneadmin:cloud /var/lib/one/.one
# The permissions for the testcase
chown -R oneadmin:cloud /home/ctester

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
