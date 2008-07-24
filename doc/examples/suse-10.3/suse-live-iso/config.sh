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
# Load sound drivers by default
#--------------------------------------
perl -ni -e 'm,^blacklist snd-, || print;' \
	/etc/modprobe.d/blacklist

# and unmute their mixers.
perl -pi -e 's,/sbin/alsactl -F restore,/bin/set_default_volume -f,;' \
	/etc/udev/rules.d/40-alsa.rules

#======================================
# Activate services
#--------------------------------------
suseActivateServices

#======================================
# Deactivate services
#--------------------------------------
suseRemoveService boot.multipath
suseRemoveService boot.device-mapper
suseRemoveService mdadmd
suseRemoveService multipathd
suseRemoveService rpmconfigcheck
suseRemoveService waitfornm
suseRemoveService smb
suseRemoveService xfs
suseRemoveService nmb
suseRemoveService autofs
suseRemoveService rpasswdd
suseRemoveService boot.scsidev
suseRemoveService boot.md
suseService boot.rootfsck off
# these two we want to disable for policy reasons
chkconfig sshd off
chkconfig cron off

# these are disabled because kiwi enables them without being default
chkconfig aaeventd off
chkconfig autoyast off
chkconfig boot.sched off
chkconfig dvb off
chkconfig esound off
chkconfig fam off
chkconfig festival off
chkconfig hotkey-setup off
chkconfig ipxmount off
chkconfig irda off
chkconfig java.binfmt_misc off
chkconfig joystick off
chkconfig lirc off
chkconfig lm_sensors off
chkconfig nfs off
chkconfig ntp off
chkconfig openct off
chkconfig pcscd off
chkconfig powerd off
chkconfig raw off
chkconfig saslauthd off
chkconfig spamd off
chkconfig xinetd off
chkconfig ypbind off

# enable create_xconf
chkconfig create_xconf on

cd /
patch -p0 < /tmp/config.patch
patch -p0 < /tmp/config-$profiles.patch
rm /tmp/config.patch
rm /tmp/config-$profiles.patch

tar xvf /tmp/gpg-pubkey.tgz
rm /tmp/gpg-pubkey.tgz
for i in gpg*.asc; do 
   rpm --import $i && rm $i
done

insserv 

: > /var/log/zypper.log
rm -rf /var/cache/zypp/raw/*

zypper addrepo http://download.opensuse.org/repositories/openSUSE:10.3/standard/ 10.3-oss
zypper addrepo http://download.opensuse.org/distribution/10.3/repo/non-oss/ 10.3-non-oss

#======================================
# /etc/sudoers hack to fix #297695 
# (Installation Live CD: no need to ask for password of root)
#--------------------------------------
sed -e "s/ALL ALL=(ALL) ALL/ALL ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers > /tmp/sudoers && mv /tmp/sudoers /etc/sudoers
chmod 0440 /etc/sudoers

# delete passwords
passwd -d root
passwd -d linux
# empty password is ok
pam-config -a --nullok

mkdir /var/lib/zypp/db/products/
if [ `eval baseGetProfilesUsed` != "KDE" ]; then
   sed -e "s,@NAME@,openSUSE-10.3-Live-Gnome," /tmp/zypp.product > /var/lib/zypp/db/products/aae0a680f12121130067466712844104
else
   sed -e "s,@NAME@,openSUSE-10.3-Live-KDE," /tmp/zypp.product > /var/lib/zypp/db/products/aae0a680f12121130067466712844104
fi
rm /tmp/zypp.product
: > /var/log/zypper.log

#======================================
# SuSEconfig
#--------------------------------------
mount -o bind /lib/udev/devices /dev
suseConfig
umount /dev

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

#!/bin/sh

rpm -e smart
rpm -e rpm-python
# needed, at least in GNOME!
if [ `eval baseGetProfilesUsed` == "KDE" ]; then
  rpm -e python-xml
  rpm -e python
fi

rm -rf /var/lib/smart

exit 0
