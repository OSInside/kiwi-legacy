#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# setup gfxboot
#------------------------------------------
suseGFXBoot SuSE isolinux

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
    python python-xml resmgr rpm-python smart suse-build-key udev \
	syslinux gfxboot make memtest86+
do
    rpm -e $i --nodeps
done

#==========================================
# remove unneeded files
#------------------------------------------
suseStripInitrd

#==========================================
# umount /proc
#------------------------------------------
umount /proc

exit 0
