#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2011 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Robert Schweikert
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
suseActivateDefaultServices
suseInsertService boot.device-mapper
suseInsertService sshd

#======================================
# SuSEconfig
#--------------------------------------
baseUpdateSysConfig /etc/sysconfig/bootloader LOADER_LOCATION mbr
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_BIN dhclient
# Disable IPv6
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT6_BIN /bin/false
echo “alias net-pf-10 off” >> /etc/modprobe.conf.local
echo “alias ipv6 off” >> /etc/modprobe.conf.local
sed -i "s/#net.ipv6.conf.all.disable_ipv6 = 1/net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf

echo "option suse-nebula code 239 = ip-address;" >> /etc/dhclient.conf
echo "require suse-nebula;" >> /etc/dhclient.conf
echo "request suse-nebula;" >> /etc/dhclient.conf

suseConfig

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
