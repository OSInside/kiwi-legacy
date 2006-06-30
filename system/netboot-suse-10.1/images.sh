#!/bin/sh

echo "Configure image: [netboot-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# remove unneeded packages and files
#------------------------------------------
rpm -e perl --nodeps
rpm -e rpm  --nodeps

rm -rf /usr/share/misc
rm -rf /usr/share/info
rm -rf /usr/share/man
rm -rf /usr/share/cracklib
rm -rf /etc/smart
rm -rf /usr/lib/smart*
rm -rf /var/lib/smart
rm -rf /usr/bin/smart
rm -rf /usr/sbin/smart*
rm -rf /usr/lib/python*
rm -rf /usr/share/doc/packages
rm -rf /usr/share/locale

rm -rf /boot/*
rm -rf /opt/*

exit 0
