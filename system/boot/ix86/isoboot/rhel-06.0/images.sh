#!/bin/sh
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

echo "Configure image: [$kiwi_iname]..."

#==========================================
# remove unneded kernel files
#------------------------------------------
rhelStripKernel

#==========================================
# remove unneeded files
#------------------------------------------
rhelStripInitrd

#==========================================
# umount
#------------------------------------------
baseCleanMount

exit 0
