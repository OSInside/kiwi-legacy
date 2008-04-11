#================
# FILE          : KIWILinuxRC.sh
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module contains common used functions
#               : for the suse linuxrc and preinit boot image
#               : files
#               : 
#               :
# STATUS        : Development
#----------------
#======================================
# Exports (General)
#--------------------------------------
export ELOG_FILE=/var/log/boot.kiwi
export ELOG_CONSOLE=/dev/tty3
export KLOG_CONSOLE=4
export PARTITIONER=sfdisk
export TRANSFER_ERRORS_FILE=/tmp/transfer.errors

#======================================
# Debug
#--------------------------------------
function Debug {
	# /.../
	# print message if variable DEBUG is set to 1
	# -----
	if test "$DEBUG" = 1;then
		echo "+++++> $1"
	fi
}
#======================================
# Echo
#--------------------------------------
function Echo {
	# /.../
	# print a message to the controling terminal
	# ----
	if test "$1" = "-n";then
		echo $1 "-----> $2"
	elif test "$1" = "-b";then
		echo "       $2"
	else
		echo "-----> $1"
	fi
}
#======================================
# WaitKey
#--------------------------------------
function WaitKey {
	# /.../
	# if DEBUG is set wait for any key to continue
	# ----
	if test "$DEBUG" = 1;then
		Echo -n "Press any key to continue..."
		read
	fi
}
#======================================
# closeKernelConsole
#--------------------------------------
function closeKernelConsole {
	# /.../
	# close the kernel console, set level to 1
	# ----
	klogconsole -l 1
}
#======================================
# openKernelConsole
#--------------------------------------
function openKernelConsole {
	# /.../
	# move the kernel console to tty3 as you can't see the messages
	# now directly it looks like the kernel console is switched off
	# but it isn't really. If DEBUG is set the logging remains on
	# the first console
	# ----
	if test "$DEBUG" = 0;then
		Echo "Kernel logging enabled on: /dev/tty$KLOG_CONSOLE"
		setctsid /dev/tty$KLOG_CONSOLE \
			klogconsole -l 7 -r$KLOG_CONSOLE
	fi
}
#======================================
# reopenKernelConsole
#--------------------------------------
function reopenKernelConsole {
	# /.../
	# reopen kernel console to be able to see kernel messages
	# while the system is booting
	# ----
	Echo "Kernel logging enabled on: /dev/tty1"
	klogconsole -l 7 -r1
}
#======================================
# importFile
#--------------------------------------
function importFile {
	# /.../
	# import the config.<MAC> style format. the function
	# will export each entry of the file as variable into
	# the current shell environment
	# ----
	IFS="
	"
	while read line;do
		echo $line | grep -qi "^#" && continue
		key=`echo "$line" | cut -d '=' -f1`
		item=`echo "$line" | cut -d '=' -f2- | tr -d "\'" | tr -d "\""`
		if [ -z "$key" ] || [ -z "$item" ];then
			continue
		fi
		Debug "$key=$item"
		eval export "$key\=\"$item\""
	done
}
#======================================
# systemException
#--------------------------------------
function systemException {
	# /.../
	# print a message to the controling terminal followed
	# by an action. Possible actions are reboot, wait
	# and opening a shell
	# ----
	set +x
	local what=$2
	if [ $what = "reboot" ];then
		if cat /proc/cmdline | grep -qi "kiwidebug=1";then
			what="shell"
		fi
	fi
	Echo "$1"
	case "$what" in
	"reboot")
		Echo "rebootException: error consoles at Alt-F3/F4"
		Echo "rebootException: reboot in 120 sec..."; sleep 120
		/sbin/reboot -f -i >/dev/null
	;;
	"wait")
		Echo "waitException: waiting for ever..."
		while true;do sleep 100;done
	;;
	"shell")
		Echo "shellException: providing shell..."
		setctsid /dev/tty1 /bin/bash
	;;
	*)
		Echo "unknownException..."
	;;
	esac
}
#======================================
# copyDevices
#--------------------------------------
function copyDeviceNodes {
	local search=$1
	local prefix=$2
	local dtype
	local major
	local minor
	local perms
	if [ -z "$search" ];then
		search=/dev
	fi
	pushd $search >/dev/null
	for i in *;do
		if [ -e $prefix/$i ];then
			continue
		fi
		if [ -b $i ];then
			dtype=b
		elif [ -c $i ];then
			dtype=c
		elif [ -p $i ];then
			dtype=p
		else
			continue
		fi
		info=`stat $i -c "0%a:0x%t:0x%T"`
		major=`echo $info | cut -f2 -d:`
		minor=`echo $info | cut -f3 -d:`
		perms=`echo $info | cut -f1 -d:`
		if [ $dtype = "p" ];then
			mknod -m $perms $prefix/$i $dtype
		else
			mknod -m $perms $prefix/$i $dtype $major $minor
		fi
	done
	popd >/dev/null
}
#======================================
# copyDevices
#--------------------------------------
function createInitialDevices {
	local prefix=$1
	mkdir -p $prefix
	if [ ! -d $prefix ];then
		return
	fi
	if [ -e $prefix/null ];then
		rm -f $prefix/null
	fi
	test -c $prefix/tty      || mknod -m 0666 $prefix/tty      c 5 0
	test -c $prefix/tty1     || mknod -m 0666 $prefix/tty1     c 4 1
	test -c $prefix/tty2     || mknod -m 0666 $prefix/tty2     c 4 2
	test -c $prefix/tty3     || mknod -m 0666 $prefix/tty3     c 4 3
	test -c $prefix/tty4     || mknod -m 0666 $prefix/tty4     c 4 4
	test -c $prefix/console  || mknod -m 0600 $prefix/console  c 5 1
	test -c $prefix/ptmx     || mknod -m 0666 $prefix/ptmx     c 5 2
	exec < $prefix/console > $prefix/console
	test -c $prefix/null     || mknod -m 0666 $prefix/null     c 1 3
	test -c $prefix/kmsg     || mknod -m 0600 $prefix/kmsg     c 1 11
	test -c $prefix/snapshot || mknod -m 0660 $prefix/snapshot c 10 231
	test -c $prefix/random   || mknod -m 0666 $prefix/random   c 1 8
	test -c $prefix/urandom  || mknod -m 0644 $prefix/urandom  c 1 9
	test -b $prefix/loop0    || mknod -m 0640 $prefix/loop0    b 7 0
	test -b $prefix/loop1    || mknod -m 0640 $prefix/loop1    b 7 1
	test -b $prefix/loop2    || mknod -m 0640 $prefix/loop2    b 7 2
	mkdir -p -m 0755 $prefix/pts
	mkdir -p -m 1777 $prefix/shm
	test -L $prefix/fd     || ln -s /proc/self/fd $prefix/fd
	test -L $prefix/stdin  || ln -s fd/0 $prefix/stdin
	test -L $prefix/stdout || ln -s fd/1 $prefix/stdout
	test -L $prefix/stderr || ln -s fd/2 $prefix/stderr
}
#======================================
# mountSystemFilesystems
#--------------------------------------
function mountSystemFilesystems {
	mount -t proc  proc   /proc
	mount -t sysfs sysfs  /sys
	mount -t tmpfs -o mode=0755 udev /dev
	createInitialDevices /dev
	mount -t devpts devpts /dev/pts
}
#======================================
# umountSystemFilesystems
#--------------------------------------
function umountSystemFilesystems {
	umount /dev/pts >/dev/null
	umount /sys     >/dev/null
	umount /proc    >/dev/null
}
#======================================
# createFramebufferDevices
#--------------------------------------
function createFramebufferDevices {
	if [ -f /proc/fb ]; then
		Echo "Creating framebuffer devices"
		while read fbnum fbtype; do
			if [ $(($fbnum < 32)) ] ; then
				[ -c /dev/fb$fbnum ] || mknod -m 0660 /dev/fb$fbnum c 29 $fbnum
			fi
		done < /proc/fb
	fi
}
#======================================
# errorLogStart
#--------------------------------------
function errorLogStart {
	# /.../
	# Log all errors up to now to /dev/tty3
	# ----
	Echo "Boot-Logging enabled on $ELOG_CONSOLE"
	if [ ! -f $ELOG_FILE ];then
		echo "KIWI Log:" >$ELOG_FILE
	else
		echo "KIWI PreInit Log" >>$ELOG_FILE
	fi
	setctsid -f $ELOG_CONSOLE /bin/bash -c "tail -f $ELOG_FILE" &
	exec 2>>$ELOG_FILE
	set -x 1>&2
}
#======================================
# udevStart
#--------------------------------------
function udevStart {
	#======================================
	# start udev
	#--------------------------------------
	echo "Creating device nodes with udev"
	# disable hotplug helper, udevd listens to netlink
	echo "" > /proc/sys/kernel/hotplug
	# don't let udev load modules
	rm -f /etc/udev/rules.d/*-drivers.rules
	# start udevd
	udevd --daemon udev_log="debug"
	/sbin/udevtrigger
	/sbin/udevsettle --timeout=30
}
#======================================
# udevKill
#--------------------------------------
function udevKill {
	killproc /sbin/udevd
	rm -f /var/log/boot.msg
	umount -t devpts /mnt/dev/pts
	mkdir -p /mnt/var/log
	cp /mnt/dev/shm/initrd.msg /mnt/var/log/boot.msg
	cp -f /var/log/boot.kiwi /mnt/var/log/boot.kiwi
}
#======================================
# startBlogD
#--------------------------------------
function startBlogD {
	REDIRECT=$(showconsole 2>/dev/null)
	if test -n "$REDIRECT" ; then
		> /dev/shm/initrd.msg
		ln -sf /dev/shm/initrd.msg /var/log/boot.msg
		mkdir -p /var/run
		/sbin/blogd $REDIRECT
	fi
}
#======================================
# killBlogD
#--------------------------------------
function killBlogD {
	# /.../
	# kill blogd on /dev/console
	# ----
	local umountProc=0
	if [ ! -e /proc/mounts ];then
		mount -t proc proc /proc
		umountProc=1
	fi
	Echo "Stopping boot logging"
	killall -9 blogd
	if [ $umountProc -eq 1 ];then
		umount /proc
	fi
}
#======================================
# installGrub
#--------------------------------------
function installBootLoaderGrub {
	# /.../
	# install the grub according to the contents of
	# /etc/grub.conf and /boot/grub/menu.lst
	# ----
	if [ -x /usr/sbin/grub ];then
		Echo "Installing boot loader..."
		/usr/sbin/grub --batch --no-floppy < /etc/grub.conf >/dev/null
		if [ ! $? = 0 ];then
			Echo "Failed to install boot loader"
		fi
	else
		Echo "Image doesn't have grub installed"
		Echo "Can't install boot loader"
	fi
}
#======================================
# setupSUSEInitrd
#--------------------------------------
function setupSUSEInitrd {
	# /.../
	# call mkinitrd on suse systems to create the distro initrd
	# based on /etc/sysconfig/kernel
	# ----
	grubOK=1
	local umountProc=0
	local umountSys=0
	local systemMap=0
	for i in `find /boot -name "System.map*"`;do
		systemMap=1
	done
	if [ $systemMap -eq 1 ];then
		if [ ! -e /proc/mounts ];then
			mount -t proc proc /proc
			umountProc=1
		fi
		if [ ! -e /sys/block ];then
			mount -t sysfs sysfs /sys
			umountSys=1
		fi
		if [ -f /etc/init.d/boot.device-mapper ];then
			/etc/init.d/boot.device-mapper start
		fi
		mkinitrd
		if [ -f /etc/init.d/boot.device-mapper ];then
			/etc/init.d/boot.device-mapper stop
		fi
		if [ $umountSys -eq 1 ];then
			umount /sys
		fi
		if [ $umountProc -eq 1 ];then
			umount /proc
		fi
	else
		Echo "Image doesn't include kernel system map"
		Echo "Can't create initrd"
		systemIntegrity=unknown
		grubOK=0
	fi
}
#======================================
# callSUSEInitrdScripts
#--------------------------------------
function callSUSEInitrdScripts {
	# /.../
	# create initrd with mkinitrd and extract the run_all.sh script
	# after that call the script in /lib/mkinitrd. The mkinitrd
	# package must be installed in the system image to do that
	# ----
	local prefix=$1
	if [ ! -d $prefix/lib/mkinitrd ];then
		Echo "No mkinitrd package installed"
		Echo "Can't call initrd scripts"
		return
	fi
	mkinitrd >/dev/null
	if [ ! -f $prefix/boot/initrd ];then
		Echo "No initrd file found"
		Echo "Can't call initrd scripts"
		return
	fi
	mkdir $prefix/tmp/suse
	cd $prefix/tmp/suse && gzip -cd $prefix/boot/initrd | cpio -i
	if [ ! -f $prefix/tmp/suse/run_all.sh ];then
		Echo "No run_all.sh script in initrd"
		Echo "Can't call initrd scripts"
		return
	fi
	Echo "Calling SUSE initrd scripts"
	chroot . bash ./run_all.sh
}
#======================================
# installGrub
#--------------------------------------
function setupBootLoaderGrub {
	# /.../
	# create grub.conf and menu.lst file used for
	# installing the bootloader
	# ----
	local mountPrefix=$1  # mount path of the image
	local destsPrefix=$2  # base dir for the config files
	local gnum=$3         # grub boot partition ID
	local rdev=$4         # grub root partition
	local gfix=$5         # grub title postfix
	local swap=$6         # optional swap partition
	local menu=$destsPrefix/boot/grub/menu.lst
	local conf=$destsPrefix/etc/grub.conf
	local dmap=$destsPrefix/boot/grub/device.map
	local console=""
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for grub device
	#--------------------------------------
	if test -z $gnum;then
		gnum=1
	fi
	#======================================
	# check for grub title postfix
	#--------------------------------------
	if test -z $gfix;then
		gfix="unknown"
	fi
	#======================================
	# check for boot TIMEOUT
	#--------------------------------------
	if test -z $KIWI_BOOT_TIMEOUT;then
		KIWI_BOOT_TIMEOUT=10;
	fi
	#======================================
	# check for UNIONFS_CONFIG
	#--------------------------------------
	if [ ! -z "$UNIONFS_CONFIG" ] && [ $gnum -gt 0 ]; then
		rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
		gnum=`echo $rwDevice | sed -e "s/\/dev.*\([0-9]\)/\\1/"`
		gnum=`expr $gnum - 1`
	fi
	#======================================
	# create directory structure
	#--------------------------------------
	for dir in $menu $conf $dmap;do
		dir=`dirname $dir`; mkdir -p $dir
	done
	#======================================
	# setup grub device node
	#--------------------------------------
	gdev="(hd0,$gnum)"
	#======================================
	# create menu.lst file
	#--------------------------------------
	echo "timeout $KIWI_BOOT_TIMEOUT"  > $menu
	if [ -f /image/loader/message ] || [ -f /boot/message ];then
		echo "gfxmenu $gdev/boot/message" >> $menu
	fi
	IFS="," ; for i in $KERNEL_LIST;do
		if test ! -z "$i";then
			#======================================
			# create standard entry
			#--------------------------------------
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			if [ -z "$name" ];then
				echo "title $kernel [ $gfix ]"  >> $menu
			else
				echo "title $name [ $gfix ]"    >> $menu
			fi
			if [ $kernel = "vmlinuz-xen" ];then
				echo " root $gdev"                     >> $menu
				echo " kernel /boot/xen.gz"            >> $menu
				echo -n " module /boot/$kernel"        >> $menu
				echo -n " root=$rdev $console"         >> $menu
				echo -n " vga=0x314 splash=silent"     >> $menu
				if [ ! -z "$swap" ];then
					echo -n " resume=$swap"            >> $menu
				fi
				echo -n " $KIWI_INITRD_PARAMS"         >> $menu
				echo " $KIWI_KERNEL_OPTIONS showopts"  >> $menu
				echo " module /boot/$initrd"           >> $menu
			else
				echo -n " kernel $gdev/boot/$kernel"   >> $menu
				echo -n " root=$rdev $console"         >> $menu
				echo -n " vga=0x314 splash=silent"     >> $menu
				if [ ! -z "$swap" ];then
					echo -n " resume=$swap"            >> $menu
				fi
				echo -n " $KIWI_INITRD_PARAMS"         >> $menu
				echo " $KIWI_KERNEL_OPTIONS showopts"  >> $menu
				echo " initrd $gdev/boot/$initrd"      >> $menu
			fi
			#======================================
			# create failsafe entry
			#--------------------------------------
			if [ -z "$name" ];then
				echo "title Failsafe -- $kernel [ $gfix ]"  >> $menu
			else
				echo "title Failsafe -- $name [ $gfix ]"    >> $menu
			fi
			if [ $kernel = "vmlinuz-xen" ];then
				echo " root $gdev"                       >> $menu
				echo " kernel /boot/xen.gz"              >> $menu
				echo -n " module /boot/$kernel"          >> $menu
				echo -n " root=$rdev $console"           >> $menu
				echo -n " vga=0x314 splash=silent"       >> $menu
				echo -n " $KIWI_INITRD_PARAMS"           >> $menu
				echo -n " $KIWI_KERNEL_OPTIONS showopts" >> $menu
				echo -n " ide=nodma apm=off acpi=off"    >> $menu
				echo -n " noresume selinux=0 nosmp"      >> $menu
				echo " noapic maxcpus=0 edd=off"         >> $menu
				echo " module /boot/$initrd"             >> $menu
			else
				echo -n " kernel $gdev/boot/$kernel"     >> $menu
				echo -n " root=$rdev $console"           >> $menu
				echo -n " vga=0x314 splash=silent"       >> $menu
				echo -n " $KIWI_INITRD_PARAMS"           >> $menu
				echo -n " $KIWI_KERNEL_OPTIONS showopts" >> $menu
				echo -n " ide=nodma apm=off acpi=off"    >> $menu
				echo -n " noresume selinux=0 nosmp"      >> $menu
				echo " noapic maxcpus=0 edd=off"         >> $menu
				echo " initrd $gdev/boot/$initrd"        >> $menu
			fi
		fi
	done
	#======================================
	# create grub.conf file
	#--------------------------------------
	gnum=`echo $rdev | sed -e "s/\/dev.*\([0-9]\)/\\1/"`
	gnum=`expr $gnum - 1`
	echo -en "root (hd0,$gnum)\ninstall"     > $conf
	echo -n " --stage2=/boot/grub/stage2"   >> $conf
	echo -n " /boot/grub/stage1 d (hd0)"    >> $conf
	echo -n " /boot/grub/stage2 0x8000"     >> $conf
	echo " $gdev/boot/grub/menu.lst"        >> $conf
	echo "quit"                             >> $conf
	#======================================
	# create grub device map
	#--------------------------------------
	rdisk=`echo $rdev | sed -e s"@[0-9]@@g"`
	echo "(hd0) $rdisk" > $dmap
}
#======================================
# setupDefaultPXENetwork
#--------------------------------------
function setupDefaultPXENetwork {
	# /.../
	# create the /sysconfig/network file according to the PXE
	# boot interface.
	# ----
	local prefix=$1
	local niface=$prefix/etc/sysconfig/network/ifcfg-$PXE_IFACE
	mkdir -p $prefix/etc/sysconfig/network
	cat > $niface < /dev/null
	echo "BOOTPROTO='dhcp'"    >> $niface
	echo "STARTMODE='ifplugd'" >> $niface
	echo "USERCONTROL='no'"    >> $niface
}
#======================================
# setupDefaultFstab
#--------------------------------------
function setupDefaultFstab {
	# /.../
	# create a new /etc/fstab file with the default entries
	# ----
	local prefix=$1
	local nfstab=$prefix/etc/fstab
	mkdir -p $prefix/etc
	cat > $nfstab < /dev/null
	echo "devpts  /dev/pts   devpts  mode=0620,gid=5 0 0"   >> $nfstab
	echo "proc    /proc      proc    defaults 0 0"          >> $nfstab
	echo "sysfs   /sys       sysfs   noauto 0 0"            >> $nfstab
}
#======================================
# updateRootDeviceFstab
#--------------------------------------
function updateRootDeviceFstab {
	# /.../
	# add one line to the fstab file for the root device
	# ----
	local prefix=$1
	local rdev=$2
	local nfstab=$prefix/etc/fstab
	if [ -z "$UNIONFS_CONFIG" ]; then
		echo "$rdev / $FSTYPE defaults 0 0" >> $nfstab
	fi
}
#======================================
# updateSwapDeviceFstab
#--------------------------------------
function updateSwapDeviceFstab {
	# /.../
	# add one line to the fstab file for the swap device
	# ----
	local prefix=$1
	local sdev=$2
	local nfstab=$prefix/etc/fstab
	echo "$sdev swap swap pri=42 0 0" >> $nfstab
}
#======================================
# updateOtherDeviceFstab
#--------------------------------------
function updateOtherDeviceFstab {
	# /.../
	# check the contents of the $PART_MOUNT variable and
	# add one line to the fstab file for each partition
	# to mount.
	# ----
	local prefix=$1
	local nfstab=$prefix/etc/fstab
	local index=0
	IFS=":" ; for i in $PART_MOUNT;do
		if test ! -z "$i";then
			count=0
			IFS=":" ; for n in $PART_DEV;do
				device=$n
				if test $count -eq $index;then
					break
				fi
				count=`expr $count + 1`
			done
			index=`expr $index + 1`
			if test ! $i = "/" && test ! $i = "x";then
				probeFileSystem $device
				echo "$device $i $FSTYPE defaults 1 1" >> $nfstab
			fi
		fi
	done
}
#======================================
# setupKernelModules
#--------------------------------------
function setupKernelModules {
	# /.../
	# create sysconfig/kernel file which includes the
	# kernel modules to become integrated into the initrd
	# if created by the distro mkinitrd tool
	# ----
	local prefix=$1
	mkdir -p $prefix/etc/sysconfig
	syskernel=$prefix/etc/sysconfig/kernel
	echo "INITRD_MODULES=\"$INITRD_MODULES\""       > $syskernel
	echo "DOMU_INITRD_MODULES=\"$DOMURD_MODULES\"" >> $syskernel
}
#======================================
# kernelCheck
#--------------------------------------
function kernelCheck {
	# /.../
	# Check this running kernel against the kernel
	# installed in the image. If the version does not 
	# match we need to reboot to activate the system
	# image kernel.
	# ----
	kactive=`uname -r`
	kreboot=1
	prefix=$1
	for i in $prefix/lib/modules/*;do
		if [ ! -d $i ];then
			continue
		fi
		kinstname=${i##*/}
		if [ $kinstname = $kactive ];then
			kreboot=0
			break
		fi
	done
	if [ $kreboot = 1 ];then
		Echo "Kernel versions do not match rebooting in 5 sec..."
		REBOOT_IMAGE="yes"
		sleep 5
	fi
}
#======================================
# probeFileSystem
#--------------------------------------
function probeFileSystem {
	# /.../
	# probe for the filesystem type. The function will
	# read the first 128 kB of the given device and check
	# the filesystem header data to detect the type of the
	# filesystem
	# ----
	FSTYPE=unknown
	dd if=$1 of=/tmp/filesystem-$$ bs=128k count=1 >/dev/null
	data=$(file /tmp/filesystem-$$) && rm -f /tmp/filesystem-$$
	case $data in
		*ext3*)     FSTYPE=ext3 ;;
		*ext2*)     FSTYPE=ext2 ;;
		*ReiserFS*) FSTYPE=reiserfs ;;
		*Squashfs*) FSTYPE=squashfs ;;
		*)
			FSTYPE=unknown
		;;
	esac
	export FSTYPE
}
#======================================
# getSystemIntegrity
#--------------------------------------
function getSystemIntegrity {
	# /.../
	# check the variable SYSTEM_INTEGRITY which contains
	# information about the status of all image portions
	# per partition. If a number is given as parameter only
	# the information from the image assigned to this partition
	# is returned
	# ----
	if [ -z "$SYSTEM_INTEGRITY" ];then
		echo "clean"
	else
		echo $SYSTEM_INTEGRITY | cut -f$1 -d:
	fi
}
#======================================
# getSystemMD5Status
#--------------------------------------
function getSystemMD5Status {
	# /.../
	# return the md5 status of the given image number.
	# the function works similar to getSystemIntegrity
	# ----
	echo $SYSTEM_MD5STATUS | cut -f$1 -d:
}
#======================================
# probeUSB
#--------------------------------------
function probeUSB {
	IFS="%"
	local module=""
	local stdevs=""
	local hwicmd="/usr/sbin/hwinfo"
	for i in \
		`$hwicmd --usb | grep "Driver [IA]" | 
		sed -es"@modprobe\(.*\)\"@\1%@" | tr -d "\n"`
	do
		if echo $i | grep -q "#0";then
			module=`echo $i | cut -f2 -d"\"" | tr -d " "`
			module=`echo $module | sed -es"@modprobe@@g"`
			IFS=";"
			for m in $module;do
				if ! echo $stdevs | grep -q $m;then
					stdevs="$stdevs $m"
				fi
			done
		fi
	done
	IFS="%"
	for i in \
		`$hwicmd --usb-ctrl | grep "Driver [IA]" | 
		sed -es"@modprobe\(.*\)\"@\1%@" | tr -d "\n"`
	do
		if echo $i | grep -q "#0";then
			module=`echo $i | cut -f2 -d"\"" | tr -d " "`
			module=`echo $module | sed -es"@modprobe@@g"`
			IFS=";"
			for m in $module;do
				if ! echo $stdevs | grep -q $m;then
					stdevs="$stdevs $m"
				fi
			done
		fi
	done
	IFS=$IFS_ORIG
	stdevs=`echo $stdevs`
	for module in $stdevs;do
		Echo "Probing module: $module"
		modprobe $module >/dev/null
	done
}
#======================================
# probeDevices
#--------------------------------------
function probeDevices {
	Echo "Including required kernel modules..."
	IFS="%"
	local module=""
	local stdevs=""
	local hwicmd="/usr/sbin/hwinfo"
	for i in \
		`$hwicmd --storage | grep "Driver [IA]" | 
		sed -es"@modprobe\(.*\)\"@\1%@" | tr -d "\n"`
	do
		if echo $i | grep -q "#0";then
			module=`echo $i | cut -f2 -d"\"" | tr -d " "`
			module=`echo $module | sed -es"@modprobe@@g"`
			IFS=";"
			for m in $module;do
				if ! echo $stdevs | grep -q $m;then
					stdevs="$stdevs $m"
				fi
			done
		fi
	done
	IFS=$IFS_ORIG
	stdevs=`echo $stdevs`
	if [ ! -z "$kiwikernelmodule" ];then
		for module in $kiwikernelmodule;do
			Echo "Probing module (cmdline): $module"
			INITRD_MODULES="$INITRD_MODULES $module"
			modprobe $module >/dev/null
		done
	fi
	for module in $stdevs;do
		loadok=1
		for broken in $kiwibrokenmodule;do
			if [ $broken = $module ];then
				Echo "Prevent loading module: $module"
				loadok=0; break
			fi
		done
		if [ $loadok = 1 ];then
			Echo "Probing module: $module"
			INITRD_MODULES="$INITRD_MODULES $module"
			modprobe $module >/dev/null
		fi
	done
	hwinfo --block &>/dev/null
	# /.../
	# older systems require ide-disk to be present at any time
	# for details on this crappy call see bug: #250241
	# ----
	modprobe ide-disk
	modprobe rd &>/dev/null
	probeUSB
}
#======================================
# CDDevice
#--------------------------------------
function CDDevice {
	# /.../
	# detect CD/DVD device. The function use the information
	# from hwinfo --cdrom to activate the drive
	# ----
	local count=0
	for module in usb-storage sr_mod cdrom ide-cd BusLogic;do
		/sbin/modprobe $module
	done
	while true;do
		cddevs=`/usr/sbin/hwinfo --cdrom | grep "Device File:" | cut -f2 -d:`
		cddevs=`echo $cddevs | sed -e "s@(.*)@@"`
		for i in $cddevs;do
			if [ -b $i ];then
				test -z $cddev && cddev=$i || cddev=$cddev:$i
			fi
		done
		if [ ! -z $cddev ] || [ $count -eq 6 ]; then
			break
		else
			Echo "Drive not ready yet... waiting"
			sleep 1
		fi
		count=`expr $count + 1`
	done
	if [ -z $cddev ];then
		systemException \
			"Failed to detect CD drive !" \
		"reboot"
	fi
}
function USBStickDevice {
	stickFound=0
	for redo in 1 2 3 4 5;do
		for device in /sys/bus/usb/drivers/usb-storage/*;do
			if [ ! -L $device ];then
				continue
			fi
			descriptions=$device/host*/target*/*/block*
			for description in $descriptions;do
				if [ ! -d $description ];then
					continue
				fi
				isremovable=$description/removable
				storageID=`echo $description | cut -f1 -d: | xargs basename`
				devicebID=`basename $description | cut -f2 -d:`
				if [ $devicebID = "block" ];then
					devicebID=`ls -1 $description`
					isremovable=$description/$devicebID/removable
				fi
				serial="/sys/bus/usb/devices/$storageID/serial"
				device="/dev/$devicebID"
				if [ ! -b $device ];then
					continue;
				fi
				if [ ! -f $isremovable ];then
					continue;
				fi
				if ! sfdisk -s $device >/dev/null;then
					continue;
				fi
				if [ ! -f $serial ];then
					serial="USB Stick (unknown type)"
				else
					serial=`cat $serial`
				fi
				removable=`cat $isremovable`
				if [ $removable -eq 1 ];then
					stickFound=1
					stickRoot=$device
					stickDevice="$device"2
					stickSerial=$serial
					return
				fi
			done
		done
		Echo "Waiting for USB devices to settle..."
		sleep 2
	done
}
#======================================
# CDMount
#--------------------------------------
function CDMount {
	# /.../
	# search all CD/DVD drives and use the one we can find
	# the CD configuration on
	# ----
	local count=0
	mkdir -p /cdrom
	while true;do
		CDDevice
		IFS=":"; for i in $cddev;do
			mount $i /cdrom >/dev/null
			if [ -f $LIVECD_CONFIG ];then
				cddev=$i; return
			fi
			umount $i >/dev/null
		done
		IFS=$IFS_ORIG
		if [ $count -eq 6 ]; then
			break
		else
			echo "Drive not ready yet... waiting"
			sleep 1
		fi
		count=`expr $count + 1`
	done
	systemException \
		"Couldn't find CD image configuration file" \
	"reboot"
}
#======================================
# CDUmount
#--------------------------------------
function CDUmount {
	# /.../
	# umount the CD device
	# ----
	umount $cddev
}
#======================================
# CDEject
#--------------------------------------
function CDEject {
	eject $cddev
}
#======================================
# searchSwapSpace
#--------------------------------------
function searchSwapSpace {
	# /.../
	# search for a type=82 swap partition
	# ----
	if [ ! -z $kiwinoswapsearch ];then
		return
	fi
	local hwapp=/usr/sbin/hwinfo
	local diskdevs=`$hwapp --disk | grep "Device File:" | cut -f2 -d:`
	diskdevs=`echo $diskdevs | sed -e "s@(.*)@@"`
	for diskdev in $diskdevs;do
		for disknr in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15;do
			id=`/sbin/sfdisk --print-id $diskdev $disknr`
			if [ "$id" = "82" ];then
				echo $diskdev$disknr
				return
			fi
		done
	done
}
#======================================
# searchDiskSpace
#--------------------------------------
function searchDiskSpace {
	# /.../
	# search for a free non swap partition
	# ----
	if [ ! -z $kiwinoswapsearch ];then
		return
	fi
	local hwapp=/usr/sbin/hwinfo
	local diskdevs=`$hwapp --disk | grep "Device File:" | cut -f2 -d:`
	diskdevs=`echo $diskdevs | sed -e "s@(.*)@@"`
	for diskdev in $diskdevs;do
		for disknr in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15;do
			id=`/sbin/sfdisk --print-id $diskdev $disknr`
			if [ -z $id ];then
				id=0
			fi
			if [ "$id" -ne 82 ] && [ "$id" -ne 0 ];then
				echo $diskdev$disknr
				return
			fi
		done
	done
}
#======================================
# updateMTAB
#--------------------------------------
function updateMTAB {
	prefix=$1
	umount=0
	if [ ! -e /proc/mounts ];then
		mount -t proc proc /proc
		umount=1
	fi
	cat /proc/mounts > $prefix/etc/mtab
	if [ $umount -eq 1 ];then
		umount /proc
	fi
}
#======================================
# probeNetworkCard
#--------------------------------------
function probeNetworkCard {
	# /.../
	# use hwinfo to probe for all network devices. The
	# function will check for the driver which is needed
	# to support the card and returns the information in
	# the networkModule variable
	# ----
	IFS="%"
	local module=""
	local hwicmd="/usr/sbin/hwinfo"
	for i in \
		`$hwicmd --netcard | grep "Driver [IA]" | 
		sed -es"@modprobe\(.*\)\"@\1%@" | tr -d "\n"`
	do
		if echo $i | grep -q "#0";then
			module=`echo $i | cut -f2 -d"\"" | tr -d " "`
			module=`echo $module | sed -es"@modprobe@@g"`
			IFS=";"
			for m in $module;do
				if ! echo $networkModule | grep -q $m;then
					if [ ! -z "$networkModule" ];then
						networkModule="$networkModule:$m"
					else
						networkModule=$m
					fi
				fi
			done
		fi
	done
	IFS=$IFS_ORIG
	networkModule=`echo $networkModule`
}
#======================================
# setupNetwork
#--------------------------------------
function setupNetwork {
	# /.../
	# probe for the existing network interface names and
	# hardware addresses. Match the BOOTIF address from PXE
	# to the correct linux interface name. Setup the network
	# interface using a dhcp request. On success the dhcp
	# info file is imported into the current shell environment
	# and the nameserver information is written to
	# /etc/resolv.conf
	# ----
	IFS="
	"
	local MAC=0
	local DEV=0
	local mac_list=0
	local dev_list=0
	local index=0
	local hwicmd=/usr/sbin/hwinfo
	local iface=eth0
	for i in `$hwicmd --netcard`;do
		IFS=$IFS_ORIG
		if echo $i | grep -q "HW Address:";then
			MAC=`echo $i | sed -e s"@HW Address:@@"`
			MAC=`echo $MAC`
			mac_list[$index]=$MAC
			index=`expr $index + 1`
		fi
		if echo $i | grep -q "Device File:";then
			DEV=`echo $i | sed -e s"@Device File:@@"`
			DEV=`echo $DEV`
			dev_list[$index]=$DEV
		fi
	done
	if [ -z $BOOTIF ];then
		# /.../
		# there is no PXE boot interface information. We will use
		# the first detected interface as fallback solution
		# ----
		iface=${dev_list[0]}
	else
		# /.../
		# evaluate the information from the PXE boot interface
		# if we found the MAC in the list the appropriate interface
		# name is assigned. if not eth0 is used as fallback
		# ----
		index=0
		BOOTIF=`echo $BOOTIF | cut -f2- -d - | tr "-" ":"`
		for i in ${mac_list[*]};do
			if [ $i = $BOOTIF ];then
				iface=${dev_list[$index]}
			fi
			index=`expr $index + 1`
		done
	fi
	export PXE_IFACE=$iface
	dhcpcd $PXE_IFACE 2>&1
	if test $? != 0;then
		systemException \
			"Failed to setup DHCP network interface !" \
		"reboot"
	fi
	ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
	for i in 1 2 3 4 5 6 7 8 9 0;do
		[ -s /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info ] && break
		sleep 5
	done
	importFile < /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info
	echo "search $DOMAIN" > /etc/resolv.conf
	IFS="," ; for i in $DNS;do
		echo "nameserver $i" >> /etc/resolv.conf
	done
}
#======================================
# updateNeeded
#--------------------------------------
function updateNeeded {
	# /.../
	# check the contents of the IMAGE key and compare the
	# image version file as well as the md5 sum of the installed
	# and the available image on the tftp server
	# ----
	SYSTEM_INTEGRITY=""
	SYSTEM_MD5STATUS=""
	count=0
	IFS="," ; for i in $IMAGE;do
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) field=1 ;;
			1) imageName=$n   ; field=2 ;;
			2) imageVersion=$n; field=3 ;;
			3) imageServer=$n ; field=4 ;;
			4) imageBlkSize=$n
		esac
		done
		atversion="$imageName-$imageVersion"
		versionFile="/mnt/etc/ImageVersion-$atversion"
		IFS=" "
		if [ -f "$versionFile" ];then
			read installed sum2 < $versionFile
		fi
		imageMD5s="image/$imageName-$imageVersion.md5"
		[ -z "$imageServer" ]  && imageServer=$SERVER
		[ -z "$imageBlkSize" ] && imageBlkSize=8192
		if [ ! -f /etc/image.md5 ];then
			fetchFile $imageMD5s /etc/image.md5 uncomp $imageServer
		fi
		read sum1 blocks blocksize < /etc/image.md5
		if [ ! -z "$sum1" ];then
			SYSTEM_MD5STATUS="$SYSTEM_MD5STATUS:$sum1"
		else
			SYSTEM_MD5STATUS="$SYSTEM_MD5STATUS:none"
		fi
		if [ ! -z "$1" ];then
			continue
		fi
		if test "$count" = 1;then
		if test "$SYSTEM_INTEGRITY" = ":clean";then
			Echo "Main OS image update needed"
			Echo -b "Forcing download for multi image session"
			RELOAD_IMAGE="yes"
		fi
		fi
		count=$(($count + 1))
		Echo "Checking update status for image: $imageName"
		if test ! -z $RELOAD_IMAGE;then
			Echo -b "Update forced via RELOAD_IMAGE..."
			Echo -b "Update status: Clean"
			SYSTEM_INTEGRITY="$SYSTEM_INTEGRITY:clean"
			continue
		fi
		if test ! -f $versionFile;then
			Echo -b "Update forced: /etc/ImageVersion-$atversion not found"
			Echo -b "Update status: Clean"
			SYSTEM_INTEGRITY="$SYSTEM_INTEGRITY:clean"
			RELOAD_IMAGE="yes"
			continue
		fi
		Echo -b "Current: $atversion Installed: $installed"
		if test "$atversion" = "$installed";then
			if test "$sum1" = "$sum2";then
				Echo -b "Update status: Fine"
				SYSTEM_INTEGRITY="$SYSTEM_INTEGRITY:fine"
				continue
			fi
			Echo -b "Image Update for image [ $imageName ] needed"
			Echo -b "Image version equals but md5 checksum failed"
			Echo -b "This means the contents of the new image differ"
			RELOAD_IMAGE="yes"
		else
			Echo -b "Image Update for image [ $imageName ] needed"
			Echo -b "Name and/or image version differ"
			RELOAD_IMAGE="yes"
		fi
		Echo -b "Update status: Clean"
		SYSTEM_INTEGRITY="$SYSTEM_INTEGRITY:clean"
	done
	SYSTEM_INTEGRITY=`echo $SYSTEM_INTEGRITY | cut -f2- -d:`
	SYSTEM_MD5STATUS=`echo $SYSTEM_MD5STATUS | cut -f2- -d:`
}
#======================================
# cleanSweep
#--------------------------------------
function cleanSweep {
	# /.../
	# zero out a the given disk device
	# ----
	diskDevice=$1
	dd if=/dev/zero of=$diskDevice bs=32M >/dev/null
}
#======================================
# createFileSystem
#--------------------------------------
function createFileSystem {
	# /.../
	# create a filesystem on the specified partition
	# if the partition is of type LVM a volume group
	# is created
	# ----
	diskPartition=$1
	diskID=`echo $diskPartition | sed -e s@[^0-9]@@g`
	diskPD=`echo $diskPartition | sed -e s@[0-9]@@g`
	diskPartitionType=`sfdisk -c $diskPD $diskID`
	if test "$diskPartitionType" = "8e";then
		Echo "Creating Volume group [systemvg]"
		pvcreate $diskPartition >/dev/null
		vgcreate systemvg $diskPartition >/dev/null
	else
		# .../
		# There is no need to create a filesystem on the partition
		# because the image itself contains the filesystem
		# ----
		# mke2fs $diskPartition >/dev/null
		# if test $? != 0;then
		#   systemException \
		#       "Failed to create filesystem on: $diskPartition !" \
		#   "reboot"
		# fi
		:
	fi
}
#======================================
# sfdiskPartitionCount
#--------------------------------------
function sfdiskPartitionCount {
	# /.../
	# calculate the number of partitions to create. If the
	# number is more than 4 an extended partition needs to be
	# created.
	# ----
	IFS="," ; for i in $PART;do
		PART_NUMBER=`expr $PART_NUMBER + 1`
	done
	if [ $PART_NUMBER -gt 4 ];then
		PART_NEED_EXTENDED=1
	fi
	PART_NUMBER=`expr $PART_NUMBER + 1`
	PART_NEED_FILL=`expr $PART_NUMBER / 8`
	PART_NEED_FILL=`expr 8 - \( $PART_NUMBER - $PART_NEED_FILL \* 8 \)`
}
#======================================
# checkExtended
#--------------------------------------
function checkExtended {
	# /.../
	# check the IMAGE system partition and adapt if the index
	# was increased due to an extended partition
	# ----
	local iDevice=""
	local iNumber=""
	local iNewDev=""
	local iPartNr=""
	IFS="," ; for i in $PART;do
		iPartNr=`expr $iPartNr + 1`
	done
	if [ $iPartNr -gt 4 ];then
		iDevice=`echo $IMAGE | cut -f1 -d";" | cut -f2 -d=`
		iNumber=`echo $iDevice | tr -d "a-zA-Z\/"`
		if [ $iNumber -ge 4 ];then
			iNumber=`expr $iNumber + 1`
			iNewDev=$DISK$iNumber
			IMAGE=`echo $IMAGE | sed -e s@$iDevice@$iNewDev@`
		fi
	fi
}
#======================================
# sfdiskFillPartition
#--------------------------------------
function sfdiskFillPartition {
	# /.../
	# in case of an extended partition the number of input lines
	# must be a multiple of 4, so this function will fill the input
	# with empty lines to make sfdisk happy
	# ----
	while test $PART_NEED_FILL -gt 0;do
		echo >> $PART_FILE
		PART_NEED_FILL=`expr $PART_NEED_FILL - 1`
	done
}
#======================================
# sfdiskCreateSwap
#--------------------------------------
function sfdiskCreateSwap {
	# /.../
	# create the sfdisk input line for setting up the
	# swap space
	# ----
	IFS="," ; for i in $PART;do
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		if test $partID = "82" -o $partID = "S";then
			echo "0,$partSize,$partID,-" > $PART_FILE
			PART_COUNT=`expr $PART_COUNT + 1`
			return
		fi
	done
}
#======================================
# sfdiskCreatePartition
#--------------------------------------
function sfdiskCreatePartition {
	# /.../
	# create the sfdisk input lines for setting up the
	# partition table except the swap space
	# ----
	devices=1
	IFS="," ; for i in $PART;do
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		if test $partID = "82" -o $partID = "S";then
			continue
		fi
		if test $partSize = "x";then
			partSize=""
		fi
		if [ $PART_COUNT -eq 1 ];then
			echo ",$partSize,$partID,*" >> $PART_FILE
		else
			echo ",$partSize,$partID,-" >> $PART_FILE
		fi
		PART_COUNT=`expr $PART_COUNT + 1`
		if [ $PART_NEED_EXTENDED -eq 1 ];then
		if [ $PART_COUNT -eq 3 ];then
			echo ",,E" >> $PART_FILE
			NO_FILE_SYSTEM=1
		fi
		fi
		devices=`expr $devices + 1`
		if test -z "$PART_MOUNT";then
			PART_MOUNT="$partMount"
			PART_DEV="$DISK$devices"
		else
			PART_MOUNT="$PART_MOUNT:$partMount"
			if [ $NO_FILE_SYSTEM -eq 2 ];then
				devices=`expr $devices + 1`
				NO_FILE_SYSTEM=0
			fi
			PART_DEV="$PART_DEV:$DISK$devices"
		fi
		if [ $NO_FILE_SYSTEM -eq 1 ];then
			NO_FILE_SYSTEM=2
		fi
	done
	if [ $PART_NEED_EXTENDED -eq 1 ];then
		sfdiskFillPartition
	fi
	export PART_MOUNT
	export PART_DEV
}
#======================================
# partedCreatePartition
#--------------------------------------
function partedCreatePartition {
	# /.../
	# create the parted input data for setting up the
	# partition table
	# ----
	p_stopp=0
	dd if=/dev/zero of=$DISK bs=512 count=1 >/dev/null && \
		/usr/sbin/parted -s $DISK mklabel msdos
	if [ $? -ne 0 ];then
		systemException \
			"Failed to clean partition table on: $DISK !" \
			"reboot"
	fi
	p_opts="-s $DISK unit s print"
	p_size=`/usr/sbin/parted $p_opts | grep "^Disk" | cut -f2 -d: | cut -f1 -ds`
	p_size=`echo $p_size`
	p_size=`expr $p_size - 1`
	p_cmd="/usr/sbin/parted -s $DISK unit s"
	p_idc="/sbin/sfdisk -c $DISK"
	p_ids="true"
	IFS="," ; for i in $PART;do
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n ; field=1 ;;
			1) partID=$n   ; field=2 ;;
			2) partMount=$n;
		esac
		done
		PART_COUNT=`expr $PART_COUNT + 1`
		if test $partSize = "x";then
			partSize=$p_size
		else
			partSize=`expr $partSize \* 2048`
		fi
		if test $partID = "82" -o $partID = "S";then
			partedGetSectors 63 $partSize
			p_cmd="$p_cmd mkpartfs primary linux-swap $p_start $p_stopp"
			continue
		fi
		if [ $p_stopp = 0 ];then
			systemException \
				"Invalid partition setup: $PART !" \
				"reboot"
		fi
		partedGetSectors $p_stopp $partSize
		if [ $PART_COUNT -le 3 ];then
			p_cmd="$p_cmd mkpart primary $p_start $p_stopp"
			p_ids="$p_ids && $p_idc $PART_COUNT $partID"
		else
			if [ $PART_COUNT -eq 4 ];then
				p_cmd="$p_cmd mkpart extended $p_start $p_size"
				p_ids="$p_ids && $p_idc $PART_COUNT 85"
				PART_COUNT=`expr $PART_COUNT + 1`
				NO_FILE_SYSTEM=1
			fi
			p_start=`expr $p_start + 1`
			p_cmd="$p_cmd mkpart logical $p_start $p_stopp"
			p_ids="$p_ids && $p_idc $PART_COUNT $partID"
		fi
		if test -z "$PART_MOUNT";then
			PART_MOUNT="$partMount"
			PART_DEV="$DISK$devices"
		else
			PART_MOUNT="$PART_MOUNT:$partMount"
			if [ $NO_FILE_SYSTEM -eq 2 ];then
				NO_FILE_SYSTEM=0
			fi
			PART_DEV="$PART_DEV:$DISK$devices"
		fi
		if [ $NO_FILE_SYSTEM -eq 1 ];then
			NO_FILE_SYSTEM=2
		fi
	done
	export PART_MOUNT
	export PART_DEV
	p_cmd="$p_cmd set 2 boot on"
}
#======================================
# partedGetSectors
#--------------------------------------
function partedGetSectors {
	# /.../
	# calculate start/end sector for given
	# sector size
	# ---
	p_start=$1
	if [ $p_start -gt 63 ];then
		p_start=`expr $p_start + 1`
	fi
	p_stopp=`expr $p_start + $2`
	if [ $p_stopp -gt $p_size ];then
		p_stopp=$p_size
	fi
}
#======================================
# partedWritePartitionTable
#--------------------------------------
function partedWritePartitionTable {
	# /.../
	# write the partition table using parted
	# ----
	diskDevice=$1

	eval $p_cmd
	if test $? != 0;then
		systemException \
			"Failed to create partition table on: $diskDevice !" \
			"reboot"
	fi
	eval $p_ids >/dev/null
	if test $? != 0;then
		systemException \
			"Failed to setup partition IDs on: $diskDevice !" \
			"reboot"
	fi
}
#======================================
# sfdiskWritePartitionTable
#--------------------------------------
function sfdiskWritePartitionTable {
	# /.../
	# write the partition table using PART_FILE as
	# input for sfdisk
	# ----
	diskDevice=$1

	dd if=/dev/zero of=$diskDevice bs=512 count=1 >/dev/null
	sfdisk -uM --force $diskDevice < $PART_FILE >/dev/null
	if test $? != 0;then
		systemException \
			"Failed to create partition table on: $diskDevice !" \
			"reboot"
	fi

	verifyOutput=`sfdisk -V $diskDevice`
	if test $? != 0;then
		systemException \
			"Failed to verify partition table on $diskDevice: $verifyOutput" \
			"reboot"
	fi
	
	rm -f $PART_FILE
}
#======================================
# partitionCount
#--------------------------------------
function partitionCount {
	if [ $PARTITIONER = "sfdisk" ];then
		sfdiskPartitionCount
	fi
}
#======================================
# createSwap
#--------------------------------------
function createSwap {
	if [ $PARTITIONER = "sfdisk" ];then
		sfdiskCreateSwap
	fi
}
#======================================
# createPartition
#--------------------------------------
function createPartition {
	if [ $PARTITIONER = "sfdisk" ];then
		sfdiskCreatePartition
	else
		partedCreatePartition
	fi
}
#======================================
# writePartitionTable
#--------------------------------------
function writePartitionTable {
	if [ $PARTITIONER = "sfdisk" ];then
		sfdiskWritePartitionTable $1
	else
		partedWritePartitionTable $1
	fi
}
#======================================
# linuxPartition
#--------------------------------------
function linuxPartition {
	# /.../
	# check for a linux partition on partition number 2
	# using the given disk device. On success return 0
	# ----
	diskDevice=$1
	diskPartitionType=`sfdisk -c $diskDevice 2`
	if test "$diskPartitionType" = "83";then
		return 0
	fi
	return 1
}
#======================================
# kernelList
#--------------------------------------
function kernelList {
	# /.../
	# check for all installed kernels whether there are valid
	# links to the initrd and kernel files. The function will
	# save the valid linknames in the variable KERNEL_LIST
	# ----
	prefix=$1
	KERNEL_LIST=""
	kcount=0
	for i in $prefix/lib/modules/*;do
		if [ ! -d $i ];then
			continue
		fi
		name=${i##*/}
		if [ ! -f $prefix/boot/vmlinux-$name.gz ];then
			continue
		fi
		KERNEL_PAIR=""
		for n in $prefix/boot/*;do
			if [ ! -L $n ];then
				continue
			fi
			real=`readlink $n`
			if [ $real = vmlinuz-$name ];then
				kernel=${n##*/}
				kcount=$((kcount+1))
			fi
			if [ $real = initrd-$name ];then
				initrd=${n##*/}
			fi
			KERNEL_PAIR=$kernel:$initrd
		done
		if [ $kcount = 1 ];then
			KERNEL_LIST=$KERNEL_PAIR
		elif [ $kcount -gt 1 ];then
			KERNEL_LIST=$KERNEL_LIST,$KERNEL_PAIR
		fi
	done
	if [ -z "$KERNEL_LIST" ];then
		if [ -e $prefix/boot/vmlinuz ] && [ -e $prefix/boot/initrd ];then
			# /.../
			# the system image doesn't provide the kernel and initrd but
			# there is a downloaded kernel and initrd from the KIWI_INITRD
			# setup. the kernelList function won't find initrds that get
			# downloaded over tftp so make sure the vmlinuz/initrd combo
			# gets added
			# ----
			KERNEL_LIST="vmlinuz:initrd"
		fi
	fi
	export KERNEL_LIST
}
#======================================
# validateSize
#--------------------------------------
function validateSize {
	# /.../
	# check if the image fits into the requested partition.
	# An information about the sizes is printed out
	# ----
	haveBytes=`sfdisk -s $imageDevice`
	haveBytes=`expr $haveBytes \* 1024`
	haveMByte=`expr $haveBytes / 1048576`
	needBytes=`expr $blocks \* $blocksize`
	needMByte=`expr $needBytes / 1048576`
	Echo "Have size: $imageDevice -> $haveBytes Bytes [ $haveMByte MB ]"
	Echo "Need size: $needBytes Bytes [ $needMByte MB ]"
	if test $haveBytes -gt $needBytes;then
		return 0
	fi
	return 1
}
#======================================
# validateTarSize
#--------------------------------------
function validateTarSize {
	# /.../
	# this function requires a destination directory which
	# could be a tmpfs mount and a compressed tar source file.
	# The function will then check if the tar file could be
	# unpacked according to the size of the destination
	# ----
	local tsrc=$1
	local haveKByte=0
	local haveMByte=0
	local needBytes=0
	local needMByte=0
	haveKByte=`cat /proc/meminfo | grep MemFree | cut -f2 -d: | cut -f1 -dk`
	haveMByte=`expr $haveKByte / 1024`
	needBytes=`du --bytes $tsrc | cut -f1`
	needMByte=`expr $needBytes / 1048576`
	Echo "Have size: proc/meminfo -> $haveMByte MB"
	Echo "Need size: $tsrc -> $needMByte MB [ uncompressed ]"
	if test $haveMByte -gt $needMByte;then
		return 0
	fi
	return 1
}
#======================================
# validateBlockSize
#--------------------------------------
function validateBlockSize {
	# /.../
	# check the block size value. atftp limits to a maximum of
	# 32768 blocks, so the block size must be checked according
	# to the size of the image
	# ----
	isize=`expr $blocks \* $blocksize`
	isize=`expr $isize / 65535`
	if [ $isize -gt $imageBlkSize ];then
		imageBlkSize=`expr $isize + 1024`
	fi
	if [ $imageBlkSize -gt 65464 ];then
		systemException \
			"Maximum blocksize for atftp protocol exceeded" \
		"reboot"
	fi
}
#======================================
# loadOK
#--------------------------------------
function loadOK {
	# /.../
	# check the output of the atftp command, unfortunately
	# there is no useful return code to check so we have to
	# check the output of the command
	# ----
	for i in "File not found" "aborting" "no option named" "unknown host" ; do
		if echo "$1" | grep -q  "$i" ; then
			return 1
		fi
	done
	return 0
}
#======================================
# includeKernelParameters
#--------------------------------------
function includeKernelParameters {
	# /.../
	# include the parameters from /proc/cmdline into
	# the current shell environment
	# ----
	IFS=$IFS_ORIG
	for i in `cat /proc/cmdline`;do
		if ! echo $i | grep -q "=";then
			continue
		fi
		kernelKey=`echo $i | cut -f1 -d=`
		kernelVal=`echo $i | cut -f2 -d=`
		eval $kernelKey=$kernelVal
	done
	if [ ! -z "$kiwikernelmodule" ];then
		kiwikernelmodule=`echo $kiwikernelmodule | tr , " "`
	fi
	if [ ! -z "$kiwibrokenmodule" ];then
		kiwibrokenmodule=`echo $kiwibrokenmodule | tr , " "`
	fi
}
#======================================
# checkServer
#--------------------------------------
function checkServer {
	# /.../
	# check the kernel commandline parameter kiwiserver.
	# If it exists its contents will be used as
	# server address stored in the SERVER variabe
	# ----
	if [ ! -z $kiwiserver ];then
		Echo "Found server in kernel cmdline"
		SERVER=$kiwiserver
	fi

	if [ ! -z $kiwiservertype ]; then
		Echo "Found server type in kernel cmdline"
		SERVERTYPE=$kiwiservertype
	else
		SERVERTYPE=tftp
	fi
}
#======================================
# umountSystem
#--------------------------------------
function umountSystem {
	local retval=0
	local OLDIFS=$IFS
	local mountPath=/mnt
	IFS=$IFS_ORIG
	if test ! -z $UNIONFS_CONFIG;then
		roDir=/read-only
		rwDir=/read-write
		xiDir=/xino
		if ! umount $mountPath >/dev/null;then
			retval=1
		fi
		for dir in $roDir $rwDir $xiDir;do
			if ! umount $dir >/dev/null;then
				retval=1
			fi
		done
	elif test ! -z $COMBINED_IMAGE;then
		rm -f /read-only >/dev/null
		rm -f /read-write >/dev/null
		umount /mnt/read-only >/dev/null || retval=1
		umount /mnt/read-write >/dev/null || retval=1
		umount /mnt >/dev/null || retval=1
	else
		if ! umount $mountPath >/dev/null;then
			retval=1
		fi
	fi
	IFS=$OLDIFS
	return $retval
}
#======================================
# mountSystemUnified
#--------------------------------------
function mountSystemUnified {
	local roDir=/read-only
	local rwDir=/read-write
	local xiDir=/xino
	for dir in $roDir $rwDir $xiDir;do
		mkdir -p $dir
	done
	local rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
	local roDevice=`echo $UNIONFS_CONFIG | cut -d , -f 2`
	local unionFST=`echo $UNIONFS_CONFIG | cut -d , -f 3`
	#======================================
	# check read/write device location
	#--------------------------------------
	echo $rwDevice | grep -q ram
	if [ $? = 0 ];then
		# /.../
		# write part is a ram location, use tmpfs for ram
		# disk data storage
		# ----
		if ! mount -t tmpfs tmpfs $rwDir >/dev/null;then
			return 1
		fi
	else
		# /.../
		# write part is not a ram disk, create ext2 filesystem on it
		# check and mount the filesystem
		# ----
		if [ $LOCAL_BOOT = "no" ] && [ $systemIntegrity = "clean" ];then
			if [ "$RELOAD_IMAGE" = "yes" ] || \
				! mount $rwDevice $rwDir >/dev/null
			then
				Echo "Checking filesystem for RW data on $rwDevice..."
				e2fsck -y -f $rwDevice >/dev/null
				if [ "$RELOAD_IMAGE" = "yes" ] || \
					! mount $rwDevice $rwDir >/dev/null
				then
					Echo "Creating filesystem for RW data on $rwDevice..."
					if ! mke2fs $rwDevice >/dev/null;then
						Echo "Failed to create ext2 filesystem"
						return 1
					fi
					tune2fs -m 0 $rwDevice >/dev/null
					Echo "Checking EXT2 write extend..."
					e2fsck -y -f $rwDevice >/dev/null
				fi
			else
				umount $rwDevice
			fi
		fi
		if ! mount $rwDevice $rwDir >/dev/null;then
			Echo "Failed to mount read/write filesystem"
			return 1
		fi
	fi
	#======================================
	# mount read only device
	#--------------------------------------
	if [ -z $FSTYPE ] || [ $FSTYPE = "unknown" ];then
		FSTYPE="auto"
	fi
	if ! mount -t $FSTYPE $roDevice $roDir >/dev/null;then
		Echo "Failed to mount read only filesystem"
		return 1
	fi
	#======================================
	# setup overlay mount
	#--------------------------------------
	if [ $unionFST = "aufs" ];then
		mount -t tmpfs tmpfs $xiDir >/dev/null || retval=1
		mount -t aufs \
			-o dirs=$rwDir=rw:$roDir=ro,xino=$xiDir/.aufs.xino none /mnt \
		>/dev/null || return 1
	else
		mount -t unionfs \
			-o dirs=$rwDir=rw:$roDir=ro none /mnt
		>/dev/null || return 1
	fi
	usleep 500000
	return 0
}
#======================================
# mountSystemCombined
#--------------------------------------
function mountSystemCombined {
	local mountDevice=$1
	local roDevice=$mountDevice
	local rwDevice=`getNextPartition $mountDevice`
	mkdir /read-only >/dev/null
	# /.../
	# mount the read-only partition to /read-only and use
	# mount option -o ro for this filesystem
	# ----
	if ! mount -o ro $roDevice /read-only >/dev/null;then
		return 1
	fi
	# /.../
	# mount a tmpfs as /mnt which will become the root fs (/) later on
	# and extract the rootfs tarball with the RAM data and the read-only
	# and read-write links into the tmpfs.
	# ----
	local rootfs=/read-only/rootfs.tar
	if [ ! -f $rootfs ];then
		systemException \
			"Can't find rootfs tarball" \
		"reboot"
	fi
	# /.../
	# count inode numbers for files in rootfs tarball
	# ----
	local inr=`tar -tf $rootfs | wc -l`
	inr=`expr $inr \* 11 / 10 / 1024`
	inr=$inr"k"
	# /.../
	# mount tmpfs, reserve max 512MB for the rootfs data
	# ----
	mount -t tmpfs tmpfs -o size=512M,nr_inodes=$inr /mnt >/dev/null || return 1
	if ! validateTarSize $rootfs;then
		systemException \
			"Not enough RAM space available for temporary data" \
		"reboot"
	fi
	cd /mnt && tar xf $rootfs >/dev/null && cd /
	# /.../
	# create a /mnt/read-only mount point and move the /read-only
	# mount into the /mnt root tree. After that remove the /read-only
	# directory and create a link to /mnt/read-only instead
	# /read-only -> /mnt/read-only
	# ----
	mkdir /mnt/read-only >/dev/null
	mount --move /read-only /mnt/read-only >/dev/null
	rm -rf /read-only >/dev/null
	ln -s /mnt/read-only /read-only >/dev/null || return 1
	if ! echo $rwDevice | grep -q loop;then
		if sfdisk -s $rwDevice &>/dev/null;then
			# /.../
			# mount the read-write partition to /mnt/read-write and create
			# a link to it: /read-write -> /mnt/read-write 
			# ----
			mkdir /mnt/read-write >/dev/null
			mount $rwDevice /mnt/read-write >/dev/null
			rm -f /read-write >/dev/null
			ln -s /mnt/read-write /read-write >/dev/null
		fi
	fi
}
#======================================
# mountSystemStandard
#--------------------------------------
function mountSystemStandard {
	local mountDevice=$1
	if [ ! -z $FSTYPE ] && [ ! $FSTYPE = "unknown" ] && [ ! $FSTYPE = "auto" ]
	then
		mount -t $FSTYPE $mountDevice /mnt >/dev/null
	else
		mount $mountDevice /mnt >/dev/null
	fi
	return $?
}
#======================================
# mountSystem
#--------------------------------------
function mountSystem {
	local retval=0
	local OLDIFS=$IFS
	IFS=$IFS_ORIG
	#======================================
	# load not autoloadable fs modules
	#--------------------------------------
	modprobe squashfs >/dev/null 2>&1
	#======================================
	# set primary mount device
	#--------------------------------------
	local mountDevice=$imageRootDevice
	if test ! -z $1;then
		mountDevice=$@
	fi
	#======================================
	# check root tree type
	#--------------------------------------
	if test ! -z $COMBINED_IMAGE;then
		mountSystemCombined "$mountDevice"
		retval=$?
	elif test ! -z $UNIONFS_CONFIG;then
		mountSystemUnified
		retval=$?
	else
		mountSystemStandard "$mountDevice"
		retval=$?
	fi
	IFS=$OLDIFS
	return $retval
}
#======================================
# cleanDirectory
#--------------------------------------
function cleanDirectory {
	local directory=$1
	shift 1
	local save=$@
	local tmpdir=`mktemp -d`
	for saveItem in $save;do
		mv $directory/$saveItem $tmpdir >/dev/null
	done
	rm -rf $directory/*
	mv $tmpdir/* $directory
	rm -rf $tmpdir
}
#======================================
# cleanInitrd
#--------------------------------------
function cleanInitrd {
	cp /usr/bin/chroot /bin
	cp /usr/sbin/klogconsole /bin
	cp /sbin/killproc /bin
	cp /sbin/halt /bin/reboot
	for dir in /*;do
		case "$dir" in
			"/lib")   continue ;;
			"/lib64") continue ;;
			"/bin")   continue ;;
			"/mnt")   continue ;;
			"/read-only") continue ;;
			"/read-write") continue ;;
			"/xino")  continue ;;
			"/dev")   continue ;;
		esac
		rm -rf $dir/* &>/dev/null
	done
	if test -L /read-only;then
		rm -f /read-only
	fi
	if test -L /read-write;then
		rm -f /read-write
	fi
	# mount opens fstab so we give them one
	touch /etc/fstab
	hash -r
}
#======================================
# searchAlternativeConfig
#--------------------------------------
function searchAlternativeConfig {
	# Check config.IP in Hex (pxelinux style)
	localip=$IPADDR
	hexip1=`echo $localip | cut -f1 -d'.'`
	hexip2=`echo $localip | cut -f2 -d'.'`
	hexip3=`echo $localip | cut -f3 -d'.'`
	hexip4=`echo $localip | cut -f4 -d'.'`
	hexip=`printf "%02X" $hexip1 $hexip2 $hexip3 $hexip4`
	STEP=8
	while [ $STEP -gt 0 ]; do
		hexippart=`echo $hexip | cut -b -$STEP`
		Echo "Checking for config file: config.$hexippart"
		fetchFile KIWI/config.$hexippart $CONFIG
		if test -s $CONFIG;then
			break
		fi
		let STEP=STEP-1
	done
	# Check config.default if no hex config was found
	if test ! -s $CONFIG;then
		Echo "Checking for config file: config.default"
		fetchFile KIWI/config.default $CONFIG
	fi
}
#======================================
# runHook
#--------------------------------------
function runHook {
	HOOK="/hooks/$1.sh"
	if [ -e $HOOK ]; then
		. $HOOK
	fi
}
#======================================
# getNextPartition
#--------------------------------------
function getNextPartition {
	part=$1
	nextPart=`echo $part | sed -e "s/\(.*\)[0-9]/\1/"`
	nextPartNum=`echo $part | sed -e "s/.*\([0-9]\)/\1/"`
	nextPartNum=`expr $nextPartNum + 1`
	nextPart="${nextPart}${nextPartNum}"
	echo $nextPart
}
#======================================
# startShell
#--------------------------------------
function startShell {
	# /.../
	# start a debugging shell on tty2
	# ----
	Echo "Starting boot shell on tty2"
	setctsid -f /dev/tty2 /bin/bash
}
#======================================
# killShell
#--------------------------------------
function killShell {
	# /.../
	# kill debugging shell on tty2
	# ----
	local umountProc=0
	if [ ! -e /proc/mounts ];then
		mount -t proc proc /proc
		umountProc=1
	fi
	Echo "Stopping boot shell"
	fuser -k /dev/tty2 >/dev/null
	if [ $umountProc -eq 1 ];then
		umount /proc
	fi
}
#======================================
# waitForStorageDevice
#--------------------------------------
function waitForStorageDevice {
	# /.../
	# function to check access on a storage device
	# which could be a whole disk or a partition.
	# the function will wait until the size of the
	# storage device could be obtained or the check
	# counter equals 4
	# ----
	local device=$1
	local check=0
	while true;do
		sfdisk -s $device &>/dev/null
		if [ $? = 0 ] || [ $check -eq 4 ];then
			break
		fi
		Echo "Waiting for device $device to settle..."
		check=`expr $check + 1`
		sleep 2
	done
}

#======================================
# waitForBlockDevice
#--------------------------------------
function waitForBlockDevice {
	# /.../
	# function to check if the given block device
	# exists. If not the function will wait until the
	# device appears or the check counter equals 4
	# ----
	local device=$1
	local check=0
	while true;do
		if [ -b $device ] || [ $check -eq 4 ];then
			break
		fi
		Echo "Waiting for device $device to settle..."
		check=`expr $check + 1`
		sleep 2
	done
}

#======================================
# fetchFile
#--------------------------------------
function fetchFile {
	# /.../
	# the generic fetcher which is able to use different protocols
	# tftp,ftp, http, https. fetchFile is used in the netboot linuxrc
	# and uses curl and atftp to download files from the network
	# ----
	local path=$1
	local dest=$2
	local izip=$3
	local host=$4
	local type=$5
	if test -z "$path"; then
		systemException "No path specified" "reboot"
	fi
	if test -z "$host"; then
		if test -z "$SERVER"; then
			systemException "No server specified" "reboot"
		fi
		host=$SERVER
	fi
	if test -z "$type"; then
		if test -z "$SERVERTYPE"; then
			type="tftp"
		else
			type="$SERVERTYPE"
		fi
	fi
	if test "$izip" = "compressed"; then
		path="$path.gz"
	fi
	case "$type" in
		"http")
			if test "$izip" = "compressed"; then
				curl -f http://$host/$path 2>$TRANSFER_ERRORS_FILE |\
					gzip -d > $dest 2>>$TRANSFER_ERRORS_FILE
			else
				curl -f http://$host/$path > $dest 2> $TRANSFER_ERRORS_FILE
			fi
			loadCode=$?
			;;
		"https")
			if test "$izip" = "compressed"; then
				curl -f -k https://$host/$path 2>$TRANSFER_ERRORS_FILE |\
					gzip -d > $dest 2>>$TRANSFER_ERRORS_FILE
			else
				curl -f -k https://$host/$path > $dest 2> $TRANSFER_ERRORS_FILE
			fi
			loadCode=$?
			;;
		"ftp")
			if test "$izip" = "compressed"; then
				curl ftp://$host/$path 2>$TRANSFER_ERRORS_FILE |\
					gzip -d > $dest 2>>$TRANSFER_ERRORS_FILE
			else
				curl ftp://$host/$path > $dest 2> $TRANSFER_ERRORS_FILE
			fi
			loadCode=$?
			;;
		"tftp")
			validateBlockSize
			if test "$izip" = "compressed"; then
				atftp \
					--option "multicast $multicast" \
					--option "blksize $imageBlkSize" -g -r $path \
					-l /dev/stdout $host 2>$TRANSFER_ERRORS_FILE |\
					gzip -d > $dest 2>>$TRANSFER_ERRORS_FILE
			else
				atftp \
					--option "multicast $multicast"  \
					--option "blksize $imageBlkSize" \
					-g -r $path -l $dest $host &> $TRANSFER_ERRORS_FILE
			fi
			loadCode=$?
			;;
		*)
			systemException "Unknown download type: $type" "reboot"
			;;
	esac
	loadStatus=`cat $TRANSFER_ERRORS_FILE`
	return $loadCode
}

#======================================
# putFile
#--------------------------------------
function putFile {
	# /.../
	# the generic putFile function is used to upload boot data on
	# a server. Supported protocols are tftp, ftp, http, https
	# ----
	local path=$1
	local dest=$2
	local host=$3
	local type=$4
    if test -z "$path"; then
		systemException "No path specified" "reboot"
	fi
	if test -z "$host"; then
		if test -z "$SERVER"; then
			systemException "No server specified" "reboot"
		fi
		host=$SERVER
	fi
	if test -z "$type"; then
		if test -z "$SERVERTYPE"; then
			type="tftp"
		else
			type="$SERVERTYPE"
		fi
	fi
	case "$type" in
		"http")
			curl -f -T $path http://$host/$dest > $TRANSFER_ERRORS_FILE 2>&1
			return $?
			;;
		"https")
			curl -f -T $path https://$host/$dest > $TRANSFER_ERRORS_FILE 2>&1
			return $?
			;;
		"ftp")
			curl -T $path ftp://$host/$dest  > $TRANSFER_ERRORS_FILE 2>&1
			return $?
			;;
		"tftp")
            atftp -p -l $path -r $dest $host >/dev/null 2>&1
            return $?
			;;
		*)
			systemException "Unknown download type: $type" "reboot"
			;;
	esac
}

#======================================
# importBranding
#--------------------------------------
function importBranding {
	# /.../
	# include possible custom boot loader and bootsplash files
	# to the system to allow to use them persistently
	# ----
	if [ -f /image/loader/message ];then
		mv /image/loader/message /mnt/boot
	fi
	if [ -f /image/loader/branding/logo.mng ];then
	if [ -d /etc/bootsplash/themes ];then
		for theme in /etc/bootsplash/themes/*;do
			cp /image/loader/branding/logo.mng  $theme/images
			cp /image/loader/branding/logov.mng $theme/images
			cp /image/loader/branding/*.jpg $theme/images
			cp /image/loader/branding/*.cfg $theme/config
		done	
	fi
	fi
}

#======================================
# validateRootTree
#--------------------------------------
function validateRootTree {
	# /.../
	# after the root of the system image has been mounted we should
	# check whether that mount is a valid system tree or not. Therefore
	# some sanity checks are made here
	# ----
	if [ ! -x /mnt/sbin/init ];then
		systemException "/sbin/init no such file or not executable" "reboot"
	fi
}
