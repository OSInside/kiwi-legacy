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
# Basic configuration
#--------------------------------------
baseUpdateSysConfig /etc/sysconfig/kernel INITRD_MODULES "xenblk jbd ext4"
echo 'SUBSYSTEM=="net", ACTION=="add", DRIVERS="?*", ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="eth*", NAME="eth0"' >> /etc/udev/rules.d/70-persistent-net.rules

#======================================
# Activate services
#--------------------------------------
suseActivateDefaultServices
suseInsertService sshd
suseInsertService cloud-init-local
suseInsertService cloud-init
suseInsertService cloud-config
suseInsertService cloud-final
suseRemoveService boot.efivars
suseRemoveService boot.lvm
suseRemoveService boot.md
suseRemoveService boot.multipath
suseRemoveService kbd
suseRemoveService acpid 

#======================================
# Let the DHCP server set the hostname
#--------------------------------------
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_SET_HOSTNAME yes

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
