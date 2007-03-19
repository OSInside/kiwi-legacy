#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."
#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	info smart python-xml perl-gettext perl-Bootloader openslp \
	rpm-python suse-build-key python perl xscreensaver \
	yast2-hardware-detection yast2-xml samba-client \
	yast2-pkg-bindings yast2 yast2-core docbook_4 docbook_3 \
	docbook-xsl-stylesheets docbook-dsssl-stylesheets \
	rpm
do
	rpm -e $i --nodeps
done

#==========================================
# remove unneeded files
#------------------------------------------
rm -rf `find -type d | grep .svn`
rm -rf /usr/share/info
rm -rf /usr/share/man
rm -rf /usr/share/locale
rm -rf /usr/lib/locale
rm -rf /usr/share/doc/packages
rm -rf /var/lib/smart
rm -rf /usr/share/wallpapers
rm -rf /usr/lib/python*
rm -rf /usr/lib/perl*
rm -rf /usr/share/sounds
rm -rf /lib/modules/*/kernel/drivers/video
rm -rf /lib/modules/*/kernel/drivers/media/video
rm -rf /lib/modules/*/kernel/drivers/isdn
rm -rf /lib/modules/*/kernel/sound
rm -rf /usr/bin/Xdmx
rm -rf /usr/bin/Xnest
rm -rf /usr/lib/xorg/modules/extensions
rm -rf /usr/share/icons
rm -rf /usr/share/libtool
rm -rf /usr/share/alsa
rm -rf /usr/lib/X11/xserver/C/print/models
rm -rf /usr/share/YaST2
rm -rf /usr/share/susehelp
rm -rf /usr/share/fonts/100dpi
rm -rf /usr/share/fonts/Type1
rm -rf /usr/share/fonts/Speedo
rm -rf /usr/lib/dri
rm -rf /usr/lib/YaST2
rm -rf /usr/share/gnome/help

#==========================================
# remove local kernel and boot data
#------------------------------------------
# rm -rf /boot/*

#==========================================
# remove RPM database
#------------------------------------------
rm -rf /var/lib/rpm
rm -rf /usr/lib/rpm

#==========================================
# remove unneeded X drivers
#------------------------------------------
find /usr/lib/xorg/modules/drivers/* | grep -v via | xargs rm -f

#==========================================
# remove unneeded X11 fonts
#------------------------------------------
find /usr/share/fonts/misc/*.pcf.gz -type f |\
	grep -v 6x13-I | grep -v cursor | xargs rm -f

#==========================================
# remove unneeded console fonts
#------------------------------------------
find /usr/share/kbd/consolefonts/ -type f |\
	grep -v default | grep -v lat9w-16 | xargs rm -f

#==========================================
# remove X11 locales except C locale
#------------------------------------------
for i in /usr/share/X11/locale/*;do
	if [ ! -d $i ];then
		continue
	fi
	if [ $i = '/usr/share/X11/locale/C' ];then
		continue
	fi
	if [ $i = '/usr/share/X11/locale/lib' ];then
		continue
	fi
	rm -rf $i
done

#==========================================
# umount /proc
#------------------------------------------
umount /proc

exit 0
