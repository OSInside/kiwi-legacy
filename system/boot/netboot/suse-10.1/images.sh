#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# setup gfxboot
#------------------------------------------
suseGFXBoot SuSE grub

#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	perl glibc-locale man info smart python \
	python-xml python-elementtree perl-gettext \
	perl-Bootloader pam-modules gawk gnome-filesystem \
	openslp rpm-python suse-build-key permissions \
	fillup pam expat suse-release libxml2 openldap2-client \
	logrotate diffutils cpio bzip2 insserv ash gdbm \
	gfxboot fribidi make
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
