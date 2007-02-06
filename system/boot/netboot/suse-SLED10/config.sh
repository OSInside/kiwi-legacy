#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# Install default kernel
#------------------------------------------
smart install kernel-default -y >/dev/null 2>&1

#==========================================
# Copy linuxrc to init
#------------------------------------------
cp linuxrc init

exit 0
