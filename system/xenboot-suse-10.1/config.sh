#!/bin/sh

echo "Configure image: [xenboot-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# Install xen kernel
#------------------------------------------
smart install kernel-xen -y >/dev/null 2>&1

#==========================================
# Copy linuxrc to init
#------------------------------------------
cp linuxrc init

exit 0
