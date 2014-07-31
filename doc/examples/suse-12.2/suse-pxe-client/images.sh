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
  docbook-xsl-stylesheets docbook-dsssl-stylesheets avahi
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
# umount /proc
#------------------------------------------
umount /proc

exit 0
