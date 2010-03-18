#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

#==========================================
# remove unneded kernel files
#------------------------------------------
rhelStripKernel

#==========================================
# setup gfxboot
#------------------------------------------
rhelGFXBoot SLES isolinux

#==========================================
# remove unneeded packages
#------------------------------------------
rpm -e --nodeps --noscripts \
	$(rpm -q `baseGetPackagesForDeletion` | grep -v "is not installed")

#==========================================
# remove unneeded files
#------------------------------------------
rhelStripInitrd

#==========================================
# umount /proc
#------------------------------------------
umount /proc &>/dev/null

exit 0
