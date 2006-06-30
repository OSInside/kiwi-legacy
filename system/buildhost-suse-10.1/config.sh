#!/bin/sh

echo "Configure image: [buildhost-suse-10.1]..."
test -f /.profile && . /.profile

#==========================================
# Install SMP kernel
#------------------------------------------
smart install kernel-default -y >/dev/null 2>&1

#==========================================
# Activate Services
#------------------------------------------
for i in \
	acpid dbus boot.loadmodules boot.localfs random resmgr \
	boot.cleanup boot.localnet haldaemon network syslog \
	portmap kbd sshd boot.clock nscd cron
do
	insserv /etc/init.d/$i
done

#==========================================
# Deactivate Services
#------------------------------------------
for i in irq_balancer
do
	insserv -r /etc/init.d/irq_balancer
done

#==========================================
# Call SuSEconfig
#------------------------------------------
/sbin/SuSEconfig

umount /proc
umount /dev/pts
umount /sys

exit 0
