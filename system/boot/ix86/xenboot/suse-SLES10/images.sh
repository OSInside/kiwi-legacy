#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

#==========================================
# remove unneded kernel files
#------------------------------------------
suseStripKernel

#==========================================
# setup gfxboot
#------------------------------------------
suseGFXBoot SLES grub

#==========================================
# remove unneeded packages
#------------------------------------------
rpm -e --nodeps --noscripts \
	$(rpm -q `baseGetPackagesForDeletion` | grep -v "is not installed")

#==========================================
# remove unneeded files
#------------------------------------------
suseStripInitrd

#==========================================
# remove unneeded files in case of Xen
#------------------------------------------
rm -rf /var
rm -rf /usr/lib/ConsoleKit
rm -rf /usr/share/getopt
rm -rf /usr/share/hwinfo
rm -rf /usr/share/nls
rm -rf /usr/i586-suse-linux
rm -rf /etc/ConsoleKit

#==========================================
# umount /proc
#------------------------------------------
umount /proc &>/dev/null

exit 0
