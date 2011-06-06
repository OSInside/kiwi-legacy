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
suseActivateDefaultServices
suseInsertService amazon
suseInsertService amazon-late
suseInsertService boot.device-mapper
suseInsertService sshd

#======================================
# Let the DHCP server set the hostname
#--------------------------------------
baseUpdateSysConfig /etc/sysconfig/network/dhcp DHCLIENT_SET_HOSTNAME yes

#======================================
# Set a random strong root password
#--------------------------------------
echo "Setting a random root password"
head -c 200 /dev/urandom | tr -cd '[:graph:]' | head -c 40 | passwd --stdin root

#======================================
# Change SSH policies
#--------------------------------------
echo "Changing SSH policies"
sed -r -i -e 's@^#?PermitRootLogin[[:space:]].*@PermitRootLogin without-password@;s@^#?UseDNS[[:space:]].*@UseDNS no@' /etc/ssh/sshd_config

#======================================
# Update inittab tty setup
#--------------------------------------
# The inittab needs to run getty on the appropriate consoles
echo "Updating inittab: disabling mingetty"
awk '{
	if ($0 ~ /^[^#].*mingetty/) {
		print "# $0"
	} else {
		print
	}
}' /etc/inittab > /etc/inittab.new
cat /etc/inittab.new > /etc/inittab
rm /etc/inittab.new

grep -E -q '^x0:' /etc/inittab
if [ $? -eq 0 ]; then
	echo "Updating inittab: resetting agetty"
	sed -i -e 's@^x0:.*@x0:12345:respawn:/sbin/agetty -L 9600 xvc0 vt102@' /etc/inittab
else
	echo "Updating inittab: enabling agetty"
	awk '{
		if ($0 ~/\/agetty/) {
			print $0 "\nx0:12345:respawn:/sbin/agetty -L 9600 xvc0 vt102"
		} else {
			print
		}
	}' /etc/inittab > /etc/inittab.new
	cat /etc/inittab.new > /etc/inittab
	rm /etc/inittab.new
fi

#======================================
# SuSEconfig
#--------------------------------------
suseConfig

#======================================
# clone runlevel 3 to 4
#--------------------------------------
suseCloneRunlevel 4

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
