#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# setup gfxboot
#------------------------------------------
export PATH=$PATH:/usr/sbin
mkdir /image/loader
cd /usr/share/gfxboot
make -C themes/SuSE prep
make -C themes/SuSE
cp themes/SuSE/install/* /image/loader
bin/unpack_bootlogo /image/loader
for i in init languages log;do
	rm -f /image/loader/$i
done
mv /usr/share/syslinux/isolinux.bin /image/loader
mv /boot/memtest.bin /image/loader/memtest
make -C themes/SuSE clean

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
suseStripInitrd

#==========================================
# umount /proc
#------------------------------------------
umount /proc

exit 0
