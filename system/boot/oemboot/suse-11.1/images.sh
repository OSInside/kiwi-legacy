#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

#==========================================
# setup config.oempartition if required
#------------------------------------------
baseSetupOEMPartition

#==========================================
# remove unneded kernel files
#------------------------------------------
suseStripKernel

#==========================================
# setup gfxboot
#------------------------------------------
suseGFXBoot openSUSE grub

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
# umount /proc
#------------------------------------------
umount /proc &>/dev/null

exit 0
