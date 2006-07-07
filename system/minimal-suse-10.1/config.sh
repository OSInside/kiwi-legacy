#!/bin/sh

echo "Configure image: [minimal-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# Install default kernel
#------------------------------------------
smart install kernel-default -y >/dev/null 2>&1

#==========================================
# Activate Services
#------------------------------------------
for i in \
	acpid dbus boot.loadmodules boot.localfs boot.xen fbset random \
	resmgr boot.cleanup boot.localnet haldaemon network syslog \
	boot.apparmor portmap kbd powersaved sshd boot.clock nscd cron \
	boot.rootfsck boot.device-mapper boot.lvm
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
