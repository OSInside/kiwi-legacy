#!/bin/sh

echo "Configure image: [full-suse-10.2]..."
test -f /.profile && . /.profile

#==========================================
# Activate Services
#------------------------------------------
for i in \
	boot.udev boot.rootfsck boot.loadmodules boot.preload_early boot.scpm \
	boot.device-mapper boot.md boot.lvm boot.localfs boot.apparmor \
	boot.cleanup boot.clock boot.cycle boot.klog boot.proc boot.sysctl \
	boot.udev_retry boot.videobios boot.crypto boot.ipconfig boot.localnet \
	boot.preload boot.swap boot.ldconfig
do
	if [ -f /etc/init.d/$i ];then
		/sbin/insserv /etc/init.d/$i
	fi
done

for i in \
	acpid dbus fbset irq_balancer random resmgr policykitd haldaemon \
	network syslog auditd portmap splash_early nfs nfsboot alsasound \
	cups kbd microcode novell-zmd powersaved running-kernel \
	splash sshd ypbind autofs nscd postfix cron xdm
do
	if [ -f /etc/init.d/$i ];then
		/sbin/insserv /etc/init.d/$i
	fi
done

#==========================================
# Call SuSEconfig
#------------------------------------------
/sbin/SuSEconfig

umount /proc
umount /dev/pts
umount /sys

exit 0
