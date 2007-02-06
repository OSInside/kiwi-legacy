#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
    PolicyKit audit-libs blocxx cpio cyrus-sasl db \
    diffutils expat fillup gawk gdbm glib2 glibc-locale gnome-filesystem \
    gpg info insserv iproute2 irqbalance libxcrypt libxml2 \
    libzio limal limal-bootloader limal-perl logrotate mdadm mingetty \
    openSUSE-release openldap2-client openslp pam pam-modules pcre \
    perl perl-Bootloader perl-gettext permissions pm-utils pmtools \
    python python-xml resmgr rpm-python smart suse-build-key udev
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
