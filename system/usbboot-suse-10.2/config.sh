#!/bin/sh

echo "Configure image: [usbboot-suse-10.2]..."
test -f /.profile && . /.profile

#==========================================
# Install default kernel
#------------------------------------------
smart install kernel-default -y >/dev/null 2>&1

#==========================================
# Copy linuxrc to init
#------------------------------------------
cp linuxrc init

exit 0
