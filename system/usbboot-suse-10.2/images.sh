#!/bin/sh

echo "Configure image: [usbboot-suse-10.2]..."
test -f /.profile && . /.profile

#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	PolicyKit atftp audit-libs bind-libs bind-utils blocxx \
	cpio cyrus-sasl db dbus-1 dbus-1-glib device-mapper \
	dhcpcd diffutils expat fillup gawk gdbm glib2 glibc-locale \
	gnome-filesystem gpg hal hwinfo info insserv iproute2 \
	irqbalance libnscd libxcrypt libxml2 libzio limal \
	limal-bootloader limal-perl logrotate lvm2 man mdadm mingetty \
	mkinitrd net-tools netcfg openSUSE-release openldap2-client \
	openslp openssl pam pam-modules pcre perl perl-Bootloader \
	perl-gettext permissions pm-utils pmtools python python \
	python-elementtree python-xml resmgr rpm-python smart \
	suse-build-key tcpd udev gzip
do
	rpm -e $i --nodeps
done

#==========================================
# remove unneeded files
#------------------------------------------
rpm -e popt bzip2 --nodeps
rm -rf `find -type d | grep .svn`
rm -rf /usr/share/misc
rm -rf /usr/share/info
rm -rf /usr/share/man
rm -rf /usr/share/cracklib
rm -rf /usr/lib/python*
rm -rf /usr/lib/perl*
rm -rf /usr/share/locale
rm -rf /usr/share/doc/packages
rm -rf /var/lib/rpm
rm -rf /usr/lib/rpm
rm -rf /var/lib/smart
rm -rf /boot/* /opt/*

#==========================================
# umount /proc
#------------------------------------------
umount /proc

exit 0
