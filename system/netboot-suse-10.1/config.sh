#!/bin/sh

echo "Configure image: [netboot-suse-10.1]..."
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
