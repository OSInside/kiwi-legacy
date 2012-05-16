#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Robert Scwheikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : OpenNebula cloud node
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
suseInsertService libvirtd
suseInsertService nfs
suseInsertService nodesetup
suseInsertService rpcbind
suseInsertService sshd


#======================================
# SuSEconfig
#--------------------------------------
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_BIN dhclient
# Disable IPv6
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT6_BIN /bin/false
echo "alias net-pf-10 off" >> /etc/modprobe.conf.local
echo "alias ipv6 off" >> /etc/modprobe.conf.local
sed -i "s/#net.ipv6.conf.all.disable_ipv6 = 1/net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf
# Configure libvirt settings
sed -i "s/#listen_tcp = 1/listen_tcp = 1/" /etc/libvirt/libvirtd.conf
sed -i "s/#dynamic_ownership = 1/dynamic_ownership = 0/" /etc/libvirt/qemu.conf
sed -i "s/#user = \"root\"/user = \"oneadmin\"/" /etc/libvirt/qemu.conf
sed -i "s/#group = \"root\"/group = \"cloud\"/" /etc/libvirt/qemu.conf

suseConfig

#======================================
# Misc
#--------------------------------------
ln -s /usr/bin/qemu-kvm /usr/bin/kvm

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
