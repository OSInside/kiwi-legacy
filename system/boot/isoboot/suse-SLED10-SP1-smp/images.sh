#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# remove unneded kernel files
#------------------------------------------
suseStripKernel

#==========================================
# setup gfxboot
#------------------------------------------
suseGFXBoot NLD isolinux

#==========================================
# remove unneeded packages
#------------------------------------------
for i in `baseGetPackagesForDeletion`;do
	rpm -q $i &> /dev/null && rpm -e $i --nodeps --noscripts
done

#==========================================
# remove unneeded files
#------------------------------------------
suseStripInitrd

#==========================================
# umount /proc
#------------------------------------------
umount /proc &>/dev/null

exit 0
