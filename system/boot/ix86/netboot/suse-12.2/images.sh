#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

#==========================================
# remove unneded kernel files
#------------------------------------------
suseStripKernel

#==========================================
# remove unneeded files
#------------------------------------------
suseStripInitrd

#==========================================
# umount
#------------------------------------------
umount /proc &>/dev/null

exit 0
