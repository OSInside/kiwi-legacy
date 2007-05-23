#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# setup gfxboot
#------------------------------------------
export PATH=$PATH:/usr/sbin
mkdir /image/loader
cd /usr/share/gfxboot
make -C themes/SLES prep
make -C themes/SLES
cp themes/SLES/install/* /image/loader
bin/unpack_bootlogo /image/loader
for i in init languages log;do
	rm -f /image/loader/$i
done
mv /usr/share/syslinux/isolinux.bin /image/loader
mv /boot/memtest.bin /image/loader/memtest
make -C themes/SLES clean

#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	perl glibc-locale man info smart python \
	python-xml python-elementtree perl-gettext \
	perl-Bootloader pam-modules gawk gnome-filesystem \
	openslp rpm-python suse-build-key permissions \
	fillup pam expat suse-release libxml2 openldap2-client \
	logrotate diffutils cpio bzip2 insserv ash gdbm rpm \
	syslinux gfxboot make memtest86
do
	rpm -e $i --nodeps
done

#==========================================
# remove unneeded files
#------------------------------------------
rm -rf `find -type d | grep .svn`
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

exit 0
