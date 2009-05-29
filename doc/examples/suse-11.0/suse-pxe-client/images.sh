#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."
#==========================================
# remove unneeded packages
#------------------------------------------
for i in \
	info smart python-xml perl-gettext perl-Bootloader openslp \
	rpm-python suse-build-key python perl xscreensaver \
	yast2-hardware-detection yast2-xml samba-client \
	yast2-pkg-bindings yast2 yast2-core docbook_4 docbook_3 \
	docbook-xsl-stylesheets docbook-dsssl-stylesheets avahi \
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
rm -rf /usr/bin/Xdmx
rm -rf /usr/bin/Xnest
rm -rf /usr/lib/xorg/modules/extensions
rm -rf /usr/share/icons
rm -rf /usr/share/libtool
rm -rf /usr/lib/X11/xserver/C/print/models
rm -rf /usr/share/YaST2
rm -rf /usr/share/susehelp
rm -rf /usr/share/fonts/100dpi
rm -rf /usr/share/fonts/Type1
rm -rf /usr/share/fonts/Speedo
rm -rf /usr/lib/dri
rm -rf /usr/lib/YaST2
rm -rf /usr/share/gnome/help
rm -rf /etc/gconf
rm -rf /usr/lib/gconv
rm -rf /etc/NetworkManager
rm -rf /usr/lib/gcc
rm -rf /usr/lib/firefox/extensions
rm -rf /usr/include/GL
rm -rf /usr/include/X11
rm -rf /usr/share/kbd/keymaps/mac
rm -rf /usr/share/kbd/keymaps/sun
rm -rf /usr/share/themes
rm -rf /usr/share/pixmaps
rm -rf /usr/lib/gconv
rm -rf /usr/share/misc
rm -rf /usr/lib/ldscripts
rm -rf /usr/share/cracklib

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
# remove unneeded X drivers
#------------------------------------------
find /usr/lib/xorg/modules/drivers/* | grep -v via | xargs rm -f

#==========================================
# remove unneeded X11 fonts
#------------------------------------------
rm -rf /usr/share/fonts/cyrillic
rm -rf /usr/share/fonts/75dpi
find /usr/share/fonts/misc/*.pcf.gz -type f |\
	grep -v 6x13-I | grep -v cursor | xargs rm -f

#==========================================
# remove unneeded console fonts
#------------------------------------------
find /usr/share/kbd/consolefonts/ -type f |\
	grep -v default | grep -v lat9w-16 | xargs rm -f

#==========================================
# remove unneeded kernel drivers
#------------------------------------------
for driver in `find /lib/modules -name "*.ko"`;do
	found=0
	base=`basename $driver`
	for need in \
		ipv6 af_packet edd processor loop usbhid hid ff-memless \
		parport_pc parport i2c-viapro rtc-cmos rtc-core rtc-lib \
		i2c-core ehci-hcd uhci-hcd usbcore yenta_socket rsrc_nonstatic \
		pcmcia_core via-agp agpgart shpchp pci_hotplug sg jbd \
		mbcache sd_mod via-rhine mii via82cxxx generic ide-core \
		pata_via libata scsi_mod ext2 snd-via82xx gameport snd-ac97-codec \
		ac97_bus snd-pcm snd-timer snd-page-alloc snd-mpu401-uart \
		snd-rawmidi snd-seq-device snd soundcore snd-mixer-oss \
		snd-seq-oss snd-pcm-oss snd-seq
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
# remove unneeded tools in /usr/bin
#------------------------------------------
for file in `find /usr/bin`;do
	found=0
	base=`basename $file`
	for need in \
		cut mkfifo locale find grep xargs tail head \
		file which firefox ssh-keygen xterm Xorg X xdm \
		xauth xsetroot xinit xargs dirname basename \
		md5sum genpref icesh icewm icewm-session icewmbg \
		icewmhint xrdb setsid xrandr hal-find-by-property \
		scp xset xpmroot Xmodmap setxkbmap xmessage \
		BackGround sessreg xkbcomp gettext getopt id \
		dialog expr clear less alsamixer lessopen.sh cpp \
		xmodmap
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

#==========================================
# umount /proc
#------------------------------------------
umount /proc

exit 0
