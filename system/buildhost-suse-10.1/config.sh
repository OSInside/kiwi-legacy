#!/bin/sh

echo "Configure image: [buildhost-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# Activate Services
#------------------------------------------
for i in \
	acpid dbus boot.loadmodules boot.localfs boot.xen random \
	resmgr boot.cleanup boot.localnet haldaemon network syslog \
	portmap kbd sshd boot.clock nscd cron boot.rootfsck \
	boot.device-mapper boot.lvm xend ntp bsworker bsmd
do
	/sbin/insserv /etc/init.d/$i
done

#==========================================
# Deactivate Services
#------------------------------------------
for i in irq_balancer
do
	/sbin/insserv -r /etc/init.d/irq_balancer
done

#==========================================
# Call SuSEconfig
#------------------------------------------
/sbin/SuSEconfig

#==========================================
# Setup ssh permissions
#------------------------------------------
cd /etc/ssh
chmod og-r *_key

umount /proc
umount /dev/pts
umount /sys

exit 0
