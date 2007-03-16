#!/bin/sh
test -f /.profile && . /.profile

echo "Configure image: [$name]..."
#==========================================
# Activate Services
#------------------------------------------
for i in \
	dbus boot.loadmodules boot.localfs random \
	resmgr boot.cleanup boot.localnet haldaemon network syslog \
	portmap kbd sshd boot.clock nscd cron boot.rootfsck xdm
do
	/sbin/insserv /etc/init.d/$i
done

#==========================================
# Call SuSEconfig
#------------------------------------------
/sbin/SuSEconfig

umount /proc
umount /dev/pts
umount /sys

exit 0
