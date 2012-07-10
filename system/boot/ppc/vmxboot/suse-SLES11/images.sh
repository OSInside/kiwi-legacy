#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

#==========================================
# pack boot includes
#------------------------------------------
basePackBootIncludes

#==========================================
# remove unneded kernel files
#------------------------------------------
suseStripKernel

#==========================================
# setup gfxboot
#------------------------------------------
suseGFXBoot SLES lilo 

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
# unpack boot includes
#------------------------------------------
baseUnpackBootIncludes

#==========================================
# remove unneded kernel files
#------------------------------------------
suseStripModules
suseStripFirmware

#==========================================
# umount /proc
#------------------------------------------
umount /proc &>/dev/null

exit 0
