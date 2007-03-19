#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."
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
	yast2 yast2-core cracklib hal dbus \
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
# remove unneeded files
#------------------------------------------
rm -rf /opt/gnome/bin
rm -rf /opt/gnome/include
rm -rf /opt/gnome/sbin
rm -rf /opt/gnome/share
rm -rf /usr/lib/gcc
rm -rf /usr/include
rm -rf /etc/opt/gnome/sound
rm -rf /etc/opt/gnome/gconf
rm -rf /etc/opt/gnome/gnome-vfs-2.0
rm -rf /etc/opt/kde3
rm -rf /etc/NetworkManager
rm -rf /usr/lib/gconv
rm -rf /usr/X11R6/lib/X11/icons
rm -rf /usr/share/mime
rm -rf /usr/share/susehelp
rm -rf /usr/lib/X11/fonts/Type1
rm -rf /opt/gnome/lib/libIDL*
rm -rf /opt/gnome/lib/libORBit*
rm -rf /opt/gnome/lib/libbonobo*
rm -rf /opt/gnome/lib/libgconf*
rm -rf /opt/gnome/lib/libgnome*
rm -rf /usr/lib/ldscripts
rm -rf /usr/share/pci.ids
rm -rf /usr/share/kbd/consoletrans
rm -rf /usr/share/kbd/unimaps

#==========================================
# remove local kernel and boot data
#------------------------------------------
rm -rf /boot/*

#==========================================
# remove RPM database
#------------------------------------------
rm -rf /var/lib/rpm
rm -rf /usr/lib/rpm

#==========================================
# remove unneeded X11 fonts
#------------------------------------------
find /usr/X11R6/lib/X11/fonts/misc/*.pcf.gz |\
	grep -v 6x13-I | grep -v cursor | xargs rm -f

#==========================================
# remove unneeded console fonts
#------------------------------------------
find /usr/share/kbd/consolefonts/ |\
	grep -v default | grep -v lat9w-16 | xargs rm -f

#==========================================
# remove unneeded X drivers
#------------------------------------------
find /usr/X11R6/lib/modules/drivers/ |\
	grep -v via_drv | grep -v radeon_drv | xargs rm -f

#==========================================
# remove unneeded x tools
#------------------------------------------
find /usr/X11R6/bin/x* |\
	grep -v xdm | grep -v xauth | grep -v xsetroot |\
	grep -v xinit | grep -v xkb | xargs rm -f

#==========================================
# remove unneeded kernel drivers
#------------------------------------------
for driver in `find /lib/modules -name "*.ko"`;do
	found=0
	base=`basename $driver`
	for need in \
		loop usbhid shpchp pci_hotplug yenta_socket uhci-hcd \
		ehci-hcd via-agp agpgart rsrc_nonstatic pcmcia_core usbcore \
		i2c-viapro i2c-core parport_pc parport sd_mod scsi_mod ide-disk \
		via82cxxx generic ide-core ipv6 af_packet via-rhine mii
	do
		if [ "$base" = "$need.ko" ];then
			found=1
			break
		fi
	done
	if [ $found = 0 ];then
		rm -f $driver
	fi
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

#==========================================
# remove unneeded tools in /usr/bin
#------------------------------------------
for file in `find /usr/bin`;do
	found=0
	base=`basename $file`
	for need in \
		cut mkfifo locale find grep xargs tail head \
		file which firefox ssh-keygen
	do
		if [ $base = $need ];then
			found=1
			break
		fi
	done
	if [ $found = 0 ];then
		rm -f $file
	fi
done

exit 0
