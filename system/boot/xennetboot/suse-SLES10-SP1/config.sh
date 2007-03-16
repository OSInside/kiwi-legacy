#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."

#==========================================
# Copy linuxrc to init
#------------------------------------------
cp linuxrc init

exit 0
