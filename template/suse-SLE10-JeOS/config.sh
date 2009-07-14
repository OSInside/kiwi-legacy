#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : operating systems
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
suseInsertService sshd
suseInsertService boot.device-mapper
suseRemoveService avahi-dnsconfd
suseRemoveService avahi-daemon

#==========================================
# remove unneeded packages
#------------------------------------------
rpm -e --nodeps --noscripts \
	$(rpm -q `baseGetPackagesForDeletion` | grep -v "is not installed")

#==========================================
# remove package docs
#------------------------------------------
rm -rf /usr/share/doc/packages/*
rm -rf /usr/share/doc/manual/*
rm -rf /opt/kde3

#======================================
# SuSEconfig
#--------------------------------------
suseConfig

#======================================
# Add 10.1 repo
#--------------------------------------
baseRepo="ftp://ftp.suse.com/pub/suse/i386/10.1/SUSE-Linux10.1-GM-Extra"
baseName="suse-10.1"
zypper sa $baseRepo $baseName

#======================================
# Remove unneeded packages
#--------------------------------------
rpm -qa | grep yast | xargs rpm -e --nodeps

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
