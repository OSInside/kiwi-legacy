#!/bin/sh

echo "Configure image: [minimal-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# remove all non mixer files from applets
#------------------------------------------
rpm -ql gnome-applets | grep -v mixer | xargs rm -rf

#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	info smart python-xml python-elementtree \
	perl-gettext perl-Bootloader openslp rpm-python \
	suse-build-key python perl perl-XML-Parser \
	xscreensaver yast2-theme-NLD yast2-theme-SuSELinux \
	yast2-hardware-detection yast2-power-management \
	yast2-xml samba-client yast2-pkg-bindings \
	yast2 yast2-core \
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
rm -rf /usr/X11R6/lib/modules/dri
rm -rf /usr/share/sounds
rm -rf /lib/modules/*/kernel/drivers/video
rm -rf /lib/modules/*/kernel/drivers/media/video
rm -rf /lib/modules/*/kernel/drivers/isdn
rm -rf /lib/modules/*/kernel/drivers/scsi
rm -rf /lib/modules/*/kernel/sound
rm -rf /usr/X11R6/bin/Xdmx
rm -rf /usr/X11R6/bin/Xnest
rm -rf /usr/X11R6/lib/modules/extensions
rm -rf /usr/share/icons
rm -rf /usr/share/libtool
rm -rf /usr/share/alsa
rm -rf /etc/X11/xserver/C/print/models
rm -rf /usr/share/YaST2

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
find /usr/X11R6/lib/modules/drivers/ | grep -v vesa | xargs rm -f

#==========================================
# remove unneeded Gnome files
#------------------------------------------
rm -rf /opt/gnome/share/locale
rm -rf /opt/gnome/include
rm -rf /opt/gnome/share/galeon

#==========================================
# remove unneeded Gnome themes
#------------------------------------------
for i in \
	AgingGorilla Atlanta Clean ColorStep Crux Emacs Esco Glider \
	Grand-Canyon LighthouseBlue Mac2 Metabox Metal Mist NewPsychicAbilities \
	Notif Ocean-Dream Pixmap Raleigh Redmond Redmond95 Sandwish Simple \
	Smokey SphereCrystal Step Synchronicity ThinIce Traditional \
	XenoThin Xenophilia Xfce*
do
	rm -rf /opt/gnome/share/themes/$i
done

#==========================================
# remove unneeded Gnome icons
#------------------------------------------
for i in \
	"Flat Blue" SphereCrystal Sandy GnomeCrystal
do
	rm -rf /opt/gnome/share/icons/$i
done

#==========================================
# remove Gnome help files except C locale
#------------------------------------------
for i in /opt/gnome/share/gnome/help/*;do
	pushd $i &>/dev/null
	for n in *;do
		if [ $n = 'C' ];then
			continue
		fi
		rm -rf $n
	done
	popd &>/dev/null
done

#==========================================
# remove X11 locales except C locale
#------------------------------------------
for i in /usr/lib/X11/locale/*;do
	if [ ! -d $i ];then
		continue
	fi
	if [ $i = '/usr/lib/X11/locale/C' ];then
		continue
	fi
	if [ $i = '/usr/lib/X11/locale/lib' ];then
		continue
	fi
	rm -rf $i
done

exit 0
