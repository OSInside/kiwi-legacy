#!/bin/sh

echo "Configure image: [netboot-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	perl glibc-locale man info smart python \
	python-xml python-elementtree perl-gettext \
	perl-Bootloader pam-modules gawk gnome-filesystem \
	openslp rpm-python suse-build-key permissions \
	fillup pam expat suse-release libxml2 openldap2-client \
	logrotate diffutils cpio bzip2 insserv ash gdbm rpm
do
	rpm -e $i --nodeps
done

#==========================================
# remove unneeded files
#------------------------------------------
rm -rf /usr/share/misc
rm -rf /usr/share/info
rm -rf /usr/share/man
rm -rf /usr/share/cracklib
rm -rf /usr/lib/python*
rm -rf /usr/lib/perl*
rm -rf /usr/share/locale
rm -rf /usr/share/doc/packages
rm -rf /boot/* /opt/*

exit 0
