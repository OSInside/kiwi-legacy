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
export TRANSFER_ERRORS_FILE=/tmp/transfer.errors
export UFONT=/usr/share/fbiterm/fonts/b16.pcf.gz
export HYBRID_PERSISTENT_FS=ext3
export HYBRID_PERSISTENT_ID=83
export HYBRID_PERSISTENT_DIR=/read-write

#======================================
# Exports (General)
#--------------------------------------
test -z "$ELOG_CONSOLE"       && export ELOG_CONSOLE=/dev/tty3
test -z "$ELOG_BOOTSHELL"     && export ELOG_BOOTSHELL=/dev/tty2
test -z "$ELOG_EXCEPTION"     && export ELOG_EXCEPTION=/dev/tty1
test -z "$KLOG_CONSOLE"       && export KLOG_CONSOLE=4
test -z "$KLOG_DEFAULT"       && export KLOG_DEFAULT=1
test -z "$ELOG_STOPPED"       && export ELOG_STOPPED=0
test -z "$PARTITIONER"        && export PARTITIONER=sfdisk
test -z "$DEFAULT_VGA"        && export DEFAULT_VGA=0x314
test -z "$HAVE_MODULES_ORDER" && export HAVE_MODULES_ORDER=1
test -z "$DIALOG_LANG"        && export DIALOG_LANG=ask
test -z "$TERM"               && export TERM=linux
test -z "$LANG"               && export LANG=en_US.utf8
test -z "$UTIMER"             && export UTIMER=0
test -z "$VGROUP"             && export VGROUP=kiwiVG

#======================================
# Start boot timer
#--------------------------------------
if [ -x /usr/bin/utimer ];then
	/usr/bin/utimer
	export UTIMER=$(cat /var/run/utimer.pid)
fi

#======================================
# Dialog
#--------------------------------------
function Dialog {
	local code=1
	export DIALOG_CANCEL=1
	if [ -e /dev/fb0 ];then
		cat > /tmp/fbcode <<- EOF
			dialog \
				--ok-label "$TEXT_OK" \
				--cancel-label "$TEXT_CANCEL" \
				--yes-label "$TEXT_YES" \
				--no-label "$TEXT_NO" \
				--exit-label "$TEXT_EXIT" \
				$@
			echo \$? > /tmp/fbcode
		EOF
		fbiterm -m $UFONT -- bash /tmp/fbcode
		code=$(cat /tmp/fbcode)
	else
		eval dialog \
			--ok-label "$TEXT_OK" \
			--cancel-label "$TEXT_CANCEL" \
			--yes-label "$TEXT_YES" \
			--no-label "$TEXT_NO" \
			--exit-label "$TEXT_EXIT" \
			$@
		code=$?
	fi
	return $code
}
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
	if [ $ELOG_STOPPED = 0 ];then
		set +x
	fi
	if [ ! $UTIMER = 0 ] && kill -0 $UTIMER &>/dev/null;then
		kill -HUP $UTIMER
		local prefix=$(cat /tmp/utimer)
	else
		local prefix="===>"
	fi
	local option=""
	local optn=""
	local opte=""
	while getopts "bne" option;do
		case $option in
			b) prefix="    " ;;
			n) optn="-n" ;;
			e) opte="-e" ;;
			*) echo "Invalid argument: $option" ;;
		esac
	done
	shift $(($OPTIND - 1))
	if [ $ELOG_STOPPED = 0 ];then
		set -x
	fi
	echo $optn $opte "$prefix $1"
	if [ $ELOG_STOPPED = 0 ];then
		set +x
	fi
	OPTIND=1
	if [ $ELOG_STOPPED = 0 ];then
		set -x
	fi
}
#======================================
# WaitKey
#--------------------------------------
function WaitKey {
	# /.../
	# if DEBUG is set wait for ENTER to continue
	# ----
	if test "$DEBUG" = 1;then
		Echo -n "Press ENTER to continue..."
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
	# move the kernel console to terminal 3 as you can't see the messages
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
	Echo "Kernel logging enabled on: /dev/tty$KLOG_DEFAULT"
	klogconsole -l 7 -r$KLOG_DEFAULT
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
		item=`echo "$line" | cut -d '=' -f2-`
		if [ -z "$key" ] || [ -z "$item" ];then
			continue
		fi
		if ! echo $item | grep -E -q "^(\"|')";then
			item="'"$item"'"
		fi
		Debug "$key=$item"
		eval export "$key\=$item"
	done
	if [ ! -z "$ERROR_INTERRUPT" ];then
		Echo -e "$ERROR_INTERRUPT"
		systemException "*** interrupted ****" "shell"
	fi
	IFS=$IFS_ORIG
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
	test -e /proc/splash && echo verbose > /proc/splash
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
		setctsid $ELOG_EXCEPTION /bin/bash -i || /bin/bash -i
	;;
	"user_reboot")
		Echo "reboot triggered by user: consoles at Alt-F3/F4"
		Echo "reboot in 30 sec..."; sleep 30
		/sbin/reboot -f -i >/dev/null
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
}
#======================================
# umountSystemFilesystems
#--------------------------------------
function umountSystemFilesystems {
	umount /dev/pts &>/dev/null
	umount /sys     &>/dev/null
	umount /proc    &>/dev/null
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
# errorLogStop
#--------------------------------------
function errorLogStop {
	set +x
	export ELOG_STOPPED=1
	exec 2>$ELOG_EXCEPTION
}
#======================================
# errorLogContinue
#--------------------------------------
function errorLogContinue {
	exec 2>>$ELOG_FILE
	export ELOG_STOPPED=0
	set -x
}
#======================================
# errorLogStart
#--------------------------------------
function errorLogStart {
	# /.../
	# Log all errors up to now to the terminal specified
	# by ELOG_CONSOLE
	# ----
	if [ ! -f $ELOG_FILE ];then
		echo "KIWI Log:" >> $ELOG_FILE
	else
		killproc tail
		echo "KIWI PreInit Log" >> $ELOG_FILE
	fi
	echo "Boot-Logging enabled on $ELOG_CONSOLE"
	setctsid -f $ELOG_CONSOLE /bin/bash -i -c "tail -f $ELOG_FILE" &
	exec 2>>$ELOG_FILE
	if [ -f .profile ];then
		echo "KIWI .profile contents:" 1>&2
		cat .profile 1>&2
	fi
	set -x 1>&2
}
#======================================
# udevPending
#--------------------------------------
function udevPending {
	local timeout=30
	if [ -x /sbin/udevadm ];then
		/sbin/udevadm trigger
		/sbin/udevadm settle --timeout=$timeout
	else
		/sbin/udevtrigger
		/sbin/udevsettle --timeout=$timeout
	fi
}
#======================================
# udevSystemStart
#--------------------------------------
function udevSystemStart {
	# /.../
	# start udev while in pre-init phase. This means we can
	# run udev from the standard runlevel script
	# ----
	/etc/init.d/boot.udev start
	echo
}
#======================================
# udevStart
#--------------------------------------
function udevStart {
	# /.../
	# start the udev daemon.
	# ----
	echo "Creating device nodes with udev"
	# disable hotplug helper, udevd listens to netlink
	if [ -e /proc/sys/kernel/hotplug ];then
		echo "" > /proc/sys/kernel/hotplug
	fi
	if ! ls /lib/modules/*/modules.order &>/dev/null;then
		# /.../
		# without modules.order in place we prevent udev from loading
		# the storage modules because it does not make a propper
		# choice if there are multiple possible modules available.
		# Example:
		# udev prefers ata_generic over ata_piix but the hwinfo
		# order is ata_piix first which also seems to make more
		# sense.
		# -----
		rm -f /etc/udev/rules.d/*-drivers.rules
		rm -f /lib/udev/rules.d/*-drivers.rules
		HAVE_MODULES_ORDER=0
	fi
	# nodes in a tmpfs
	mount -t tmpfs -o mode=0755 udev /dev
	# static nodes
	createInitialDevices /dev
	# terminal devices
	mount -t devpts devpts /dev/pts
	# start the udev daemon
	udevd --daemon udev_log="debug"
	# wait for pending triggered udev events.
	udevPending
	# start splashy if configured
	startSplashy
}
#======================================
# udevKill
#--------------------------------------
function udevKill {
	killproc /sbin/udevd
}
#======================================
# startSplashy
#--------------------------------------
function startSplashy {
	if [ -x /usr/sbin/splashy ];then
		splashy boot
	fi
}
#======================================
# startBlogD
#--------------------------------------
function startBlogD {
	REDIRECT=$(showconsole 2>/dev/null)
	if test -n "$REDIRECT" ; then
		mkdir -p /var/log
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
# installBootLoader
#--------------------------------------
function installBootLoader {
	# /.../
	# generic function to install the boot loader.
	# The selection of the bootloader happens according to
	# the architecture of the system
	# ----
	local arch=`uname -m`
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)   installBootLoaderGrub ;;
		x86_64-grub) installBootLoaderGrub ;;
		ppc*)        installBootLoaderLilo ;;
		*)
		systemException \
			"*** boot loader install for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# installBootLoaderRecovery
#--------------------------------------
function installBootLoaderRecovery {
	# /.../
	# generic function to install the boot loader into
	# the recovery partition. The selection of the bootloader
	# happens according to the architecture of the system
	# ----
	local arch=`uname -m`
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)   installBootLoaderGrubRecovery ;;
		x86_64-grub) installBootLoaderGrubRecovery ;;
		*)
		systemException \
			"*** boot loader setup for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# installBootLoaderGrub
#--------------------------------------
function installBootLoaderGrub {
	# /.../
	# install the grub according to the contents of
	# /etc/grub.conf and /boot/grub/menu.lst
	# ----
	if [ -x /usr/sbin/grub ];then
		Echo "Installing boot loader..."
		/usr/sbin/grub --batch --no-floppy < /etc/grub.conf 1>&2
		if [ ! $? = 0 ];then
			Echo "Failed to install boot loader"
		fi
	else
		Echo "Image doesn't have grub installed"
		Echo "Can't install boot loader"
	fi
}
#======================================
# installBootLoaderLilo
#--------------------------------------
function installBootLoaderLilo {
	# /.../
	# install the lilo according to the contents of
	# /etc/lilo.conf
	# ----
	if [ -x /sbin/lilo ];then
		Echo "Installing boot loader..."
		/sbin/lilo 1>&2
		if [ ! $? = 0 ];then
			Echo "Failed to install boot loader"
		fi
	else
		Echo "Image doesn't have lilo installed"
		Echo "Can't install boot loader"
	fi
}
#======================================
# installBootLoaderGrubRecovery
#--------------------------------------
function installBootLoaderGrubRecovery {
	# /.../
	# install the grub into the recovery partition.
	# By design the recovery partition is always the
	# fourth primary partition of the disk
	# ----
	local input=/grub.input
	local gdevreco=$(expr $recoid - 1)
	echo "device (hd0) $imageDiskDevice" > $input
	echo "root (hd0,$gdevreco)"  >> $input
	echo "setup (hd0,$gdevreco)" >> $input
	echo "quit"          >> $input
	if [ -x /mnt/usr/sbin/grub ];then
		/mnt/usr/sbin/grub --batch < $input 1>&2
	else
		Echo "Image doesn't have grub installed"
		Echo "Can't install boot loader"
		systemException \
			"recovery grub setup failed" \
		"reboot"
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
	bootLoaderOK=1
	local umountProc=0
	local umountSys=0
	local systemMap=0
	local running
	local rlinux
	local rinitrd
	for i in `find /boot/ -name "System.map*"`;do
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
		if ! mkinitrd;then
			Echo "Can't create initrd"
			systemIntegrity=unknown
			bootLoaderOK=0
		fi
		if [ -f /etc/init.d/boot.device-mapper ];then
			/etc/init.d/boot.device-mapper stop
		fi
		if [ $bootLoaderOK = "1" ];then
			if [ -f /boot/initrd.vmx ];then
				rm -f /boot/initrd.vmx
				rm -f /boot/linux.vmx
				running=$(uname -r)
				rlinux=vmlinuz-$running
				rinitrd=initrd-$running
				ln -s $rlinux  /boot/linux.vmx
				ln -s $rinitrd /boot/initrd.vmx
			fi
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
		bootLoaderOK=0
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
# setupBootLoaderFiles
#--------------------------------------
function setupBootLoaderFiles {
	# /.../
	# generic function which returns the files used for a
	# specific bootloader. The selection of the bootloader
	# happens according to the architecture of the system
	# ----
	local arch=`uname -m`
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)    setupBootLoaderFilesGrub ;;
		x86_64-grub)  setupBootLoaderFilesGrub ;;
		ppc*)         setupBootLoaderFilesLilo ;;
		*)
		systemException \
			"*** boot loader files for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# setupBootLoaderFilesGrub
#--------------------------------------
function setupBootLoaderFilesGrub {
	echo "/boot/grub/menu.lst /etc/grub.conf"
}
#======================================
# setupBootLoaderFilesLilo
#--------------------------------------
function setupBootLoaderFilesLilo {
	echo "/etc/lilo.conf"
}
#======================================
# setupBootLoader
#--------------------------------------
function setupBootLoader {
	# /.../
	# generic function to setup the boot loader configuration.
	# The selection of the bootloader happens according to
	# the architecture of the system
	# ----
	local arch=`uname -m`
	local para=""
	while [ $# -gt 0 ];do
		para="$para \"$1\""
		shift
	done
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)       eval setupBootLoaderGrub $para ;;
		x86_64-grub)     eval setupBootLoaderGrub $para ;;
		i*86-syslinux)   eval setupBootLoaderSyslinux $para ;;
		x86_64-syslinux) eval setupBootLoaderSyslinux $para ;;
		ppc*)            eval setupBootLoaderLilo $para ;;
		*)
		systemException \
			"*** boot loader setup for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# setupBootLoaderRecovery
#--------------------------------------
function setupBootLoaderRecovery {
	# /.../
	# generic function to setup the boot loader configuration
	# for the recovery partition. The selection of the bootloader
	# happens according to the architecture of the system
	# ----
	local arch=`uname -m`
	local para=""
	while [ $# -gt 0 ];do
		para="$para \"$1\""
		shift
	done
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)   eval setupBootLoaderGrubRecovery $para ;;
		x86_64-grub) eval setupBootLoaderGrubRecovery $para ;;
		*)
		systemException \
			"*** boot loader setup for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# setupBootLoaderGrubRecovery
#--------------------------------------
function setupBootLoaderGrubRecovery {
	# /.../
	# create menu.lst file for the recovery boot system
	# ----
	local mountPrefix=$1  # mount path of the image
	local destsPrefix=$2  # base dir for the config files
	local gfix=$3         # grub title
	local menu=$destsPrefix/boot/grub/menu.lst
	local kernel=""
	local initrd=""
	local fbmode=$vga
	local gdevreco=$(expr $recoid - 1)
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	gdev_recovery="(hd0,$gdevreco)"
	rdev_recovery=$OEM_RECOVERY
	diskByID=`getDiskID $rdev_recovery`
	#======================================
	# import grub stages into recovery
	#--------------------------------------
	cp $mountPrefix/boot/grub/stage1 $destsPrefix/boot/grub
	cp $mountPrefix/boot/grub/stage2 $destsPrefix/boot/grub
	#======================================
	# backup current menu.lst
	#--------------------------------------
	mv $menu $menu.system
	#======================================
	# create recovery menu.lst
	#--------------------------------------
	echo "timeout 30" > $menu
	echo "gfxmenu $gdev_recovery/boot/message" >> $menu
	kernel=vmlinuz # this is a copy of the kiwi linux.vmx file
	initrd=initrd  # this is a copy of the kiwi initrd.vmx file
	#======================================
	# create recovery entry
	#--------------------------------------
	if [ ! -z "$OEM_RECOVERY" ];then
		#======================================
		# Make the cancel option default
		#--------------------------------------
		echo "default 2"                                  >> $menu
		#======================================
		# Recovery
		#--------------------------------------
		title=$(makeLabel "Recover/Repair System")
		echo "title $title"                               >> $menu
		if xenServer;then
			echo " root $gdev_recovery"                   >> $menu
			echo " kernel /boot/xen.gz"                   >> $menu
			echo -n " module /boot/$kernel"               >> $menu
			echo -n " root=$diskByID $console"            >> $menu
			if [ ! -z "$imageDiskDevice" ];then
				echo -n " disk=$(getDiskID $imageDiskDevice)" >> $menu
			fi
			echo -n " vga=$fbmode splash=silent"          >> $menu
			echo -n " $KIWI_INITRD_PARAMS"                >> $menu
			echo -n " $KIWI_KERNEL_OPTIONS"               >> $menu
			if [ "$haveLVM" = "yes" ];then
				echo -n " VGROUP=$VGROUP"                 >> $menu
			fi
			echo " KIWI_RECOVERY=$recoid showopts"        >> $menu
			echo " module /boot/$initrd"                  >> $menu
		else
			echo -n " kernel $gdev_recovery/boot/$kernel" >> $menu
			echo -n " root=$diskByID $console"            >> $menu
			if [ ! -z "$imageDiskDevice" ];then
				echo -n " disk=$(getDiskID $imageDiskDevice)" >> $menu
			fi
			echo -n " vga=$fbmode splash=silent"          >> $menu
			echo -n " $KIWI_INITRD_PARAMS"                >> $menu
			echo -n " $KIWI_KERNEL_OPTIONS"               >> $menu
			if [ "$haveLVM" = "yes" ];then
				echo -n " VGROUP=$VGROUP"                 >> $menu
			fi
			echo " KIWI_RECOVERY=$recoid showopts"        >> $menu
			echo " initrd $gdev_recovery/boot/$initrd"    >> $menu
		fi
		#======================================
		# Restore
		#--------------------------------------
		title=$(makeLabel "Restore Factory System")
		echo "title $title"                               >> $menu
		if xenServer;then
			echo " root $gdev_recovery"                   >> $menu
			echo " kernel /boot/xen.gz"                   >> $menu
			echo -n " module /boot/$kernel"               >> $menu
			echo -n " root=$diskByID $console"            >> $menu
			if [ ! -z "$imageDiskDevice" ];then
				echo -n " disk=$(getDiskID $imageDiskDevice)" >> $menu
			fi
			echo -n " vga=$fbmode splash=silent"          >> $menu
			echo -n " $KIWI_INITRD_PARAMS"                >> $menu
			echo -n " $KIWI_KERNEL_OPTIONS"               >> $menu
			if [ "$haveLVM" = "yes" ];then
				echo -n " VGROUP=$VGROUP"                 >> $menu
			fi
			echo " KIWI_RECOVERY=$recoid showopts"        >> $menu
			echo " module /boot/$initrd"                  >> $menu
		else
			echo -n " kernel $gdev_recovery/boot/$kernel" >> $menu
			echo -n " root=$diskByID $console"            >> $menu
			if [ ! -z "$imageDiskDevice" ];then
				echo -n " disk=$(getDiskID $imageDiskDevice)" >> $menu
			fi
			echo -n " vga=$fbmode splash=silent"          >> $menu
			echo -n " $KIWI_INITRD_PARAMS"                >> $menu
			echo -n " $KIWI_KERNEL_OPTIONS"               >> $menu
			if [ "$haveLVM" = "yes" ];then
				echo -n " VGROUP=$VGROUP"                 >> $menu
			fi
			echo -n " KIWI_RECOVERY=$recoid RESTORE=1"    >> $menu
			echo " showopts"                              >> $menu
			echo " initrd $gdev_recovery/boot/$initrd"    >> $menu
		fi
		#======================================
		# Reboot
		#--------------------------------------
		title=$(makeLabel "Cancel/Reboot")
		echo "title $title"                               >> $menu
		echo " reboot"                                    >> $menu
	fi
}
#======================================
# setupBootLoaderSyslinux
#--------------------------------------
function setupBootLoaderSyslinux {
	# /.../
	# create syslinux.cfg used for the
	# syslinux bootloader
	# ----
	local mountPrefix=$1  # mount path of the image
	local destsPrefix=$2  # base dir for the config files
	local gnum=$3         # boot partition ID
	local rdev=$4         # root partition
	local gfix=$5         # syslinux title postfix
	local swap=$6         # optional swap partition
	local conf=$destsPrefix/boot/syslinux/syslinux.cfg
	local sysb=$destsPrefix/etc/sysconfig/bootloader
	local console=""
	local kname=""
	local kernel=""
	local initrd=""
	local title=""
	local fbmode=$vga
	local xencons=$xencons
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	#======================================
	# check for device by ID
	#--------------------------------------
	local diskByID=`getDiskID $rdev`
	local swapByID=`getDiskID $swap`
	#======================================
	# check for boot image .profile
	#--------------------------------------
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for syslinux title postfix
	#--------------------------------------
	if [ -z "$gfix" ];then
		gfix="unknown"
	fi
	#======================================
	# check for boot TIMEOUT
	#--------------------------------------
	if [ -z "$KIWI_BOOT_TIMEOUT" ];then
		KIWI_BOOT_TIMEOUT=100;
	fi
	#======================================
	# create directory structure
	#--------------------------------------
	for dir in $conf $sysb;do
		dir=`dirname $dir`; mkdir -p $dir
	done
	#======================================
	# create syslinux.cfg file
	#--------------------------------------
	echo "DEFAULT vesamenu.c32"         > $conf
	echo "TIMEOUT $KIWI_BOOT_TIMEOUT"  >> $conf
	local count=1
	IFS="," ; for i in $KERNEL_LIST;do
		if test ! -z "$i";then
			#======================================
			# setup syslinux requirements
			#--------------------------------------
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			kname=${KERNEL_NAME[$count]}
			#======================================
			# move to FAT requirements 8+3
			#--------------------------------------
			kernel="linux.$count"
			initrd="initrd.$count"
			if ! echo $gfix | grep -E -q "OEM|USB|VMX|NET|unknown";then
				if [ "$count" = "1" ];then
					title=$(makeLabel "$gfix")
				else
					title=$(makeLabel "$kname [ $gfix ]")
				fi
			elif [ -z "$kiwi_oemtitle" ];then
				title=$(makeLabel "$kname [ $gfix ]")
			else
				if [ "$count" = "1" ];then
					title=$(makeLabel "$kiwi_oemtitle [ $gfix ]")
				else
					title=$(makeLabel "$kiwi_oemtitle-$kname [ $gfix ]")
				fi
			fi
			#======================================
			# create standard entry
			#--------------------------------------
			echo "LABEL Linux" >> $conf
			echo "MENU LABEL $title"                           >> $conf
			if xenServer;then
				systemException \
					"*** syslinux: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "KERNEL /boot/$kernel"                    >> $conf
				echo -n "APPEND initrd=/boot/$initrd"          >> $conf
				echo -n " root=$diskByID $console"             >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
				fi
				echo -n " vga=$fbmode loader=$loader"          >> $conf
				echo -n " splash=silent"                       >> $conf
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"                >> $conf
				fi
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"                >> $conf
				fi
				echo -n " $KIWI_INITRD_PARAMS"                 >> $conf
				echo -n " $KIWI_KERNEL_OPTIONS"                >> $conf
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                  >> $conf
				fi
				echo " showopts"                               >> $conf
			fi
			#======================================
			# create Failsafe entry
			#--------------------------------------
			title=$(makeLabel "Failsafe -- $title")
			echo "LABEL Failsafe"                              >> $conf
			echo "MENU LABEL $title"                           >> $conf
			if xenServer;then
				systemException \
					"*** syslinux: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "KERNEL /boot/$kernel"                    >> $conf
				echo -n "APPEND initrd=/boot/$initrd"          >> $conf
				echo -n " root=$diskByID $console"             >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
				fi
				echo -n " vga=$fbmode loader=$loader"          >> $conf
				echo -n " splash=silent"                       >> $conf
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"                >> $conf
				fi
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"                >> $conf
				fi
				echo -n " $KIWI_INITRD_PARAMS"                 >> $conf
				echo -n " $KIWI_KERNEL_OPTIONS"                >> $conf
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                  >> $conf
				fi
				echo -n " showopts ide=nodma apm=off acpi=off" >> $conf
				echo -n " noresume selinux=0 nosmp"            >> $conf
				echo " noapic maxcpus=0 edd=off"               >> $conf
			fi
			count=`expr $count + 1`
		fi
	done
	#======================================
	# create recovery entry
	#--------------------------------------
	if [ ! -z "$OEM_RECOVERY" ];then
		systemException \
			"*** syslinux recovery chain loading not implemented ***" \
		"reboot"
	fi
	#======================================
	# create sysconfig/bootloader
	#--------------------------------------
	echo "LOADER_TYPE=\"syslinux\""                           > $sysb
	echo "LOADER_LOCATION=\"mbr\""                           >> $sysb
	echo "DEFAULT_VGA=\"$fbmode\""                           >> $sysb 
	echo -n "DEFAULT_APPEND=\"root=$diskByID splash=silent"  >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo " showopts\""                                       >> $sysb
	echo "FAILSAFE_VGA=\"$fbmode\""                          >> $sysb
	echo -n "FAILSAFE_APPEND=\"root=$diskByID splash=silent" >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo -n " showopts ide=nodma apm=off acpi=off noresume"  >> $sysb
	echo "selinux=0 nosmp noapic maxcpus=0 edd=off\""        >> $sysb
}
#======================================
# setupBootLoaderGrub
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
	local sysb=$destsPrefix/etc/sysconfig/bootloader
	local stage=/boot/grub/stage2
	local console=""
	local kname=""
	local kernel=""
	local initrd=""
	local title=""
	local rdisk=""
	local fbmode=$vga
	local xencons=$xencons
	if [ ! -z "$OEM_RECOVERY" ];then
		local gdevreco=$(expr $recoid - 1)
	fi
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	#======================================
	# check for device by ID
	#--------------------------------------
	local diskByID=`getDiskID $rdev`
	local swapByID=`getDiskID $swap`
	#======================================
	# check for boot image .profile
	#--------------------------------------
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for grub device
	#--------------------------------------
	if [ -z "$gnum" ];then
		gnum=1
	fi
	#======================================
	# check for grub title postfix
	#--------------------------------------
	if [ -z "$gfix" ];then
		gfix="unknown"
	fi
	#======================================
	# check for boot TIMEOUT
	#--------------------------------------
	if [ -z "$KIWI_BOOT_TIMEOUT" ];then
		KIWI_BOOT_TIMEOUT=10;
	fi
	#======================================
	# check for UNIONFS_CONFIG
	#--------------------------------------
	if [ "$haveLVM" = "yes" ]; then
		gnum=1
	elif [ "$haveDMSquash" = "yes" ];then
		gnum=2
	elif [ "$haveClicFS" = "yes" ];then
		gnum=2
	elif [ "$haveLuks" = "yes" ];then
		:
	elif [ ! -z "$UNIONFS_CONFIG" ] && [ $gnum -gt 0 ]; then
		rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
		gnum=`echo $rwDevice | sed -e "s/\/dev.*\([0-9]\)/\\1/"`
		gnum=`expr $gnum - 1`
	fi
	#======================================
	# create directory structure
	#--------------------------------------
	for dir in $menu $conf $dmap $sysb;do
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
	local count=1
	IFS="," ; for i in $KERNEL_LIST;do
		if test ! -z "$i";then
			#======================================
			# create grub requirements
			#--------------------------------------
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			kname=${KERNEL_NAME[$count]}
			if ! echo $gfix | grep -E -q "OEM|USB|VMX|NET|unknown";then
				if [ "$count" = "1" ];then
					title=$(makeLabel "$gfix")
				else
					title=$(makeLabel "$kname [ $gfix ]")
				fi
			elif [ -z "$kiwi_oemtitle" ];then
				title=$(makeLabel "$kname [ $gfix ]")
			else
				if [ "$count" = "1" ];then
					title=$(makeLabel "$kiwi_oemtitle [ $gfix ]")
				else
					title=$(makeLabel "$kiwi_oemtitle-$kname [ $gfix ]")
				fi
			fi
			#======================================
			# create standard entry
			#--------------------------------------
			echo "title $title"                                   >> $menu
			if xenServer;then
				echo " root $gdev"                                >> $menu
				echo " kernel /boot/xen.gz"                       >> $menu
				echo -n " module /boot/$kernel"                   >> $menu
				echo -n " root=$diskByID"                         >> $menu
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"     >> $menu
				fi
				echo -n " $console vga=$fbmode splash=silent"     >> $menu
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"                   >> $menu
				fi
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"                   >> $menu
				fi
				echo -n " $KIWI_INITRD_PARAMS"                    >> $menu
				echo -n " $KIWI_KERNEL_OPTIONS"                   >> $menu
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                     >> $menu
				fi
				echo " showopts"                                  >> $menu
				echo " module /boot/$initrd"                      >> $menu
			else
				echo -n " kernel $gdev/boot/$kernel"              >> $menu
				echo -n " root=$diskByID"                         >> $menu
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"     >> $menu
				fi
				echo -n " $console vga=$fbmode splash=silent"     >> $menu
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"                   >> $menu
				fi
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"                   >> $menu
				fi
				echo -n " $KIWI_INITRD_PARAMS"                    >> $menu
				echo -n " $KIWI_KERNEL_OPTIONS"                   >> $menu
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                     >> $menu
				fi
				echo " showopts"                                  >> $menu
				echo " initrd $gdev/boot/$initrd"                 >> $menu
			fi
			#======================================
			# create failsafe entry
			#--------------------------------------
			title=$(makeLabel "Failsafe -- $title")
			echo "title $title"                                   >> $menu
			if xenServer;then
				echo " root $gdev"                                >> $menu
				echo " kernel /boot/xen.gz"                       >> $menu
				echo -n " module /boot/$kernel"                   >> $menu
				echo -n " root=$diskByID"                         >> $menu
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"     >> $menu
				fi
				echo -n " $console vga=$fbmode splash=silent"     >> $menu
				echo -n " $KIWI_INITRD_PARAMS"                    >> $menu
				echo -n " $KIWI_KERNEL_OPTIONS"                   >> $menu
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                     >> $menu
				fi
				echo -n " showopts ide=nodma apm=off acpi=off"    >> $menu
				echo -n " noresume selinux=0 nosmp"               >> $menu
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"                   >> $menu
				fi
				echo " noapic maxcpus=0 edd=off"                  >> $menu
				echo " module /boot/$initrd"                      >> $menu
			else
				echo -n " kernel $gdev/boot/$kernel"              >> $menu
				echo -n " root=$diskByID"                         >> $menu
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"     >> $menu
				fi
				echo -n " $console vga=$fbmode splash=silent"     >> $menu
				echo -n " $KIWI_INITRD_PARAMS"                    >> $menu
				echo -n " $KIWI_KERNEL_OPTIONS"                   >> $menu
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                     >> $menu
				fi
				echo -n " showopts ide=nodma apm=off acpi=off"    >> $menu
				echo -n " noresume selinux=0 nosmp"               >> $menu
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"                   >> $menu
				fi
				echo " noapic maxcpus=0 edd=off"                  >> $menu
				echo " initrd $gdev/boot/$initrd"                 >> $menu
			fi
			count=`expr $count + 1`
		fi
	done
	#======================================
	# create recovery entry
	#--------------------------------------
	if [ ! -z "$OEM_RECOVERY" ];then
		echo "title Recovery"                             >> $menu
		echo " rootnoverify (hd0,$gdevreco)"              >> $menu
		echo " chainloader +1"                            >> $menu
	fi
	#======================================
	# create grub.conf file
	#--------------------------------------
	echo "root $gdev" > $conf
	if dd if=$rdev bs=1 count=512 | file - | grep -q Bootloader;then
		echo "setup --stage2=$stage $gdev" >> $conf
	else
		echo "setup --stage2=$stage (hd0)" >> $conf
	fi
	echo "quit" >> $conf
	#======================================
	# create grub device map
	#--------------------------------------
	rdisk=`echo $rdev | sed -e s"@[0-9]@@g"`
	if [ ! -z "$imageDiskDevice" ];then
		rdisk=$imageDiskDevice
	fi
	echo "(hd0) $rdisk" > $dmap
	#======================================
	# create sysconfig/bootloader
	#--------------------------------------
	echo "LOADER_TYPE=\"grub\""                               > $sysb
	echo "LOADER_LOCATION=\"mbr\""                           >> $sysb
	echo "DEFAULT_VGA=\"$fbmode\""                           >> $sysb  
	echo -n "DEFAULT_APPEND=\"root=$diskByID splash=silent"  >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo " showopts\""                                       >> $sysb
	echo "FAILSAFE_VGA=\"$fbmode\""                          >> $sysb
	echo -n "FAILSAFE_APPEND=\"root=$diskByID splash=silent" >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo -n " showopts ide=nodma apm=off acpi=off noresume"  >> $sysb
	echo "selinux=0 nosmp noapic maxcpus=0 edd=off\""        >> $sysb
}
#======================================
# setupBootLoaderLilo
#--------------------------------------
function setupBootLoaderLilo {
	# /.../
	# create lilo.conf file used for
	# installing the bootloader
	# ----
	local mountPrefix=$1  # mount path of the image
	local destsPrefix=$2  # base dir for the config files
	local lnum=$3         # lilo boot partition ID
	local rdev=$4         # lilo root partition
	local lfix=$5         # lilo title postfix
	local swap=$6         # optional swap partition
	local conf=$destsPrefix/etc/lilo.conf
	local sysb=$destsPrefix/etc/sysconfig/bootloader
	local console=""
	local kname=""
	local kernel=""
	local initrd=""
	local title=""
	local rdisk=""
	local fbmode=$vga
	local xencons=$xencons
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	#======================================
	# check for device by ID
	#--------------------------------------
	local diskByID=`getDiskID $rdev`
	local swapByID=`getDiskID $swap`
	#======================================
	# check for boot image .profile
	#--------------------------------------
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for lilo title postfix
	#--------------------------------------
	if [ -z "$lfix" ];then
		lfix="unknown"
	fi
	#======================================
	# check for boot TIMEOUT
	#--------------------------------------
	if [ -z "$KIWI_BOOT_TIMEOUT" ];then
		KIWI_BOOT_TIMEOUT=10;
	fi
	#======================================
	# check for UNIONFS_CONFIG
	#--------------------------------------
	if [ "$haveLVM" = "yes" ]; then
		lnum=1
	elif [ "$haveDMSquash" = "yes" ];then
		lnum=2
	elif [ "$haveClicFS" = "yes" ];then
		lnum=2
	elif [ "$haveLuks" = "yes" ];then
		:
	elif [ ! -z "$UNIONFS_CONFIG" ] && [ $gnum -gt 0 ]; then
		rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
		lnum=`echo $rwDevice | sed -e "s/\/dev.*\([0-9]\)/\\1/"`
		lnum=`expr $gnum - 1`
	fi
	#======================================
	# setup lilo boot device
	#--------------------------------------
	rdisk=`echo $rdev | sed -e s"@[0-9]@@g"`
	if [ ! -z "$imageDiskDevice" ];then
		rdisk=$imageDiskDevice
	fi
	rdev=$rdisk$lnum
	#======================================
	# create directory structure
	#--------------------------------------
	for dir in $conf $sysb;do
		dir=`dirname $dir`; mkdir -p $dir
	done
	#======================================
	# create lilo.conf file
	#--------------------------------------
	echo "boot=$rdev"                                        >  $conf
	echo "activate"                                          >> $conf
	echo "timeout=`expr $KIWI_BOOT_TIMEOUT \* 10`"           >> $conf
	echo "default=kiwi$count"                                >> $conf
	local count=1
	IFS="," ; for i in $KERNEL_LIST;do
		if test ! -z "$i";then
			#======================================
			# create lilo requirements
			#--------------------------------------
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			kname=${KERNEL_NAME[$count]}
			if ! echo $lfix | grep -E -q "OEM|USB|VMX|NET|unknown";then
				if [ "$count" = "1" ];then
					title=$(makeLabel "$lfix")
				else
					title=$(makeLabel "$kname [ $lfix ]")
				fi
			elif [ -z "$kiwi_oemtitle" ];then
				title=$(makeLabel "$kname [ $lfix ]")
			else
				if [ "$count" = "1" ];then
					title=$(makeLabel "$kiwi_oemtitle [ $lfix ]")
				else
					title=$(makeLabel "$kiwi_oemtitle-$kname [ $lfix ]")
				fi
			fi
			#======================================
			# create standard entry
			#--------------------------------------
			echo "label=\"$title\""                           >> $conf
			if xenServer;then
				systemException \
					"*** lilo: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "image=/boot/$kernel"                    >> $conf
				echo "initrd=/boot/$initrd"                   >> $conf
				echo -n "append=\"quiet sysrq=1 panic=9"      >> $conf
				echo -n " root=$diskByID"                     >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)" >> $conf
				fi
				echo -n " $console vga=$fbmode splash=silent" >> $conf
				if [ ! -z "$swap" ];then                     
					echo -n " resume=$swapByID"               >> $conf
				fi
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"               >> $conf
				fi
				echo -n " $KIWI_INITRD_PARAMS"                >> $conf
				echo -n " $KIWI_KERNEL_OPTIONS"               >> $conf
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                 >> $conf
				fi
				echo " showopts\""                            >> $conf
			fi
			#======================================
			# create failsafe entry
			#--------------------------------------
			title=$(makeLabel "Failsafe -- $title")
			echo "label=\"$title\""                           >> $conf
			if xenServer;then
				systemException \
					"*** lilo: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "image=/boot/$kernel"                    >> $conf
				echo "initrd=/boot/$initrd"                   >> $conf
				echo -n "append=\"quiet sysrq=1 panic=9"      >> $conf
				echo -n " root=$diskByID"                     >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)" >> $conf
				fi
				echo -n " $console vga=$fbmode splash=silent" >> $conf
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"               >> $conf
				fi
				if [ ! -z "$xencons" ]; then
					echo -n " xencons=$xencons"               >> $conf
				fi
				echo -n " $KIWI_INITRD_PARAMS"                >> $conf
				echo -n " $KIWI_KERNEL_OPTIONS"               >> $conf
				if [ "$haveLVM" = "yes" ];then
					echo -n " VGROUP=$VGROUP"                 >> $conf
				fi
				echo -n " showopts ide=nodma apm=off"         >> $conf
				echo " acpi=off noresume selinux=0 nosmp\""   >> $conf
			fi
			count=`expr $count + 1`
		fi
	done
	#======================================
	# create recovery entry
	#--------------------------------------
	if [ ! -z "$OEM_RECOVERY" ];then
		systemException \
			"*** lilo: recovery chain loading not implemented ***" \
		"reboot"
	fi
	#======================================
	# create sysconfig/bootloader
	#--------------------------------------
	echo "LOADER_TYPE=\"lilo\""                               > $sysb
	echo "LOADER_LOCATION=\"mbr\""                           >> $sysb
	echo "DEFAULT_VGA=\"$fbmode\""                           >> $sysb 
	echo -n "DEFAULT_APPEND=\"root=$diskByID splash=silent"  >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo " showopts\""                                       >> $sysb
	echo "FAILSAFE_VGA=\"$fbmode\""                          >> $sysb
	echo -n "FAILSAFE_APPEND=\"root=$diskByID splash=silent" >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo -n " showopts ide=nodma apm=off acpi=off noresume"  >> $sysb
	echo "selinux=0 nosmp noapic maxcpus=0 edd=off\""        >> $sysb
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
	IFS=$IFS_ORIG
	local prefix=$1
	local rdev=$2
	local nfstab=$prefix/etc/fstab
	local diskByID=`getDiskID $rdev`
	if [ ! -z "$NFSROOT" ];then
		local server=`echo $rdev | cut -f3 -d" "`
		local option=`echo $rdev | cut -f2 -d" "`
		echo "$server / nfs $option 0 0" >> $nfstab
		return
	fi
	#======================================
	# check for device by ID
	#--------------------------------------
	if [ -z "$UNIONFS_CONFIG" ]; then
		echo "$diskByID / $FSTYPE defaults 0 0" >> $nfstab
	else
		echo "/dev/root / defaults 0 0" >> $nfstab
	fi
	#======================================
	# check for LVM volume setup
	#--------------------------------------
	if [ "$haveLVM" = "yes" ];then
		for i in /dev/$VGROUP/LV*;do
			if [ ! -e $i ];then
				continue
			fi
			local volume=$(echo $i | cut -f4 -d/ | cut -c3-)
			local mpoint=$(echo $volume | tr _ /)
			if \
				[ ! $volume = "Root" ] && \
				[ ! $volume = "Comp" ] && \
				[ ! $volume = "Swap" ]
			then
				echo "/dev/$VGROUP/LV$volume /$mpoint $FSTYPE defaults 0 0" \
				>> $nfstab
			fi
		done
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
	local diskByID=`getDiskID $sdev`
	local nfstab=$prefix/etc/fstab
	echo "$diskByID swap swap pri=42 0 0" >> $nfstab
}
#======================================
# updateLVMBootDeviceFstab
#--------------------------------------
function updateLVMBootDeviceFstab {
	# /.../
	# add one line to the fstab file for the /lvmboot
	# device partition
	# ----
	local prefix=$1
	local sdev=$2
	local mount=$3
	if [ -z "$mount" ];then
		mount=/lvmboot
	fi
	local diskByID=`getDiskID $sdev`
	local nfstab=$prefix/etc/fstab
	if [ ! -z "$FSTYPE" ];then
		FSTYPE_SAVE=$FSTYPE
	fi
	#======================================
	# probe filesystem
	#--------------------------------------
	probeFileSystem $sdev
	if [ -z $FSTYPE ] || [ $FSTYPE = "unknown" ];then
		FSTYPE="auto"
	fi
	echo "$diskByID $mount $FSTYPE defaults 0 0" >> $nfstab
	if [ ! -z "$FSTYPE_SAVE" ];then
		FSTYPE=$FSTYPE_SAVE
	fi
}
#======================================
# updateDMBootDeviceFstab
#--------------------------------------
function updateDMBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/dmboot"
}
#======================================
# updateClicBootDeviceFstab
#--------------------------------------
function updateClicBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/clicboot"
}
#======================================
# updatePXEBootDeviceFstab
#--------------------------------------
function updatePXEBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/static-boot"
}
#======================================
# updateLuksBootDeviceFstab
#--------------------------------------
function updateLuksBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/luksboot"
}
#======================================
# updateSyslinuxBootDeviceFstab
#--------------------------------------
function updateSyslinuxBootDeviceFstab {
	# /.../
	# add one line to the fstab file for the /syslboot
	# device partition
	# ----
	local prefix=$1
	local sdev=$2
	local diskByID=`getDiskID $sdev`
	local nfstab=$prefix/etc/fstab
	echo "$diskByID /syslboot vfat defaults 0 0" >> $nfstab
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
	local destprefix=$1
	local srcprefix=$2
	if [ -z "$srcprefix" ];then
		srcprefix=/mnt
	fi
	local ktempl=$srcprefix/var/adm/fillup-templates/sysconfig.kernel
	local syskernel=$destprefix/etc/sysconfig/kernel
	mkdir -p $destprefix/etc/sysconfig
	if [ ! -f $ktempl ];then
		systemException \
			"Can't find kernel sysconfig template in system image !" \
		"reboot"
	fi
	cp $ktempl $syskernel
	if [ ! -e $srcprefix/lib/mkinitrd/scripts/boot-usb.sh ];then
		# /.../
		# if boot-usb.sh does not exist we are based on an old
		# mkinitrd version which requires all modules as part of
		# sysconfig/kernel. Therefore we include all USB modules
		# required to support USB storage like USB sticks
		# ----
		local USB_MODULES="ehci-hcd ohci-hcd uhci-hcd usbcore usb-storage sd"
		INITRD_MODULES="$INITRD_MODULES $USB_MODULES"
	fi
	sed -i -e \
		s"@^INITRD_MODULES=.*@INITRD_MODULES=\"$INITRD_MODULES\"@" \
	$syskernel
	sed -i -e \
		s"@^DOMU_INITRD_MODULES=.*@DOMU_INITRD_MODULES=\"$DOMURD_MODULES\"@" \
	$syskernel
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
	# read 128 kB of the given device and check the
	# filesystem header data to detect the type of the
	# filesystem
	# ----
	FSTYPE=unknown
	FSTYPE=$(blkid $1 -s TYPE -o value)
	case $FSTYPE in
		ext4)     FSTYPE=ext4 ;;
		ext3)     FSTYPE=ext3 ;;
		ext2)     FSTYPE=ext2 ;;
		reiserfs) FSTYPE=reiserfs ;;
		squashfs) FSTYPE=squashfs ;;
		luks)     FSTYPE=luks ;;
		vfat)     FSTYPE=vfat ;;
		clicfs)   FSTYPE=clicfs ;;
		*)
			FSTYPE=unknown
		;;
	esac
	if [ $FSTYPE = "unknown" ];then
		dd if=$1 of=/tmp/filesystem-$$ bs=128k count=1 >/dev/null
	fi
	if [ $FSTYPE = "unknown" ];then
		if grep -q ^CLIC /tmp/filesystem-$$;then
			FSTYPE=clicfs
		fi
	fi
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
# waitForUSBDeviceScan
#--------------------------------------
function waitForUSBDeviceScan {
	local devices=0
	if [ ! "$HAVE_USB" = "yes" ];then
		return
	fi
	if [ ! "$SCAN_USB" = "complete" ];then
		Echo -n "Waiting for USB device scan to complete..."
		while \
			[ $(dmesg|grep -c 'usb-storage: device scan complete') -lt 1 ] && \
			[ $devices -lt 15 ]
		do
			echo -n .
			sleep 1
			devices=$(( $devices + 1 ))
		done
		echo
		udevPending
		SCAN_USB=complete
	fi
}
#======================================
# probeUSB
#--------------------------------------
function probeUSB {
	local module=""
	local stdevs=""
	local hwicmd="/usr/sbin/hwinfo"
	export HAVE_USB="no"
	export SCAN_USB="not-started"
	if [ $HAVE_MODULES_ORDER = 0 ];then
		#======================================
		# load host controller modules
		#--------------------------------------
		IFS="%"
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
		#======================================
		# check load status for host controller
		#--------------------------------------
		if [ -z "$stdevs" ];then
			return
		fi
		#======================================
		# manually load storage/input drivers
		#--------------------------------------
		for i in usbhid usb-storage;do
			modprobe $i &>/dev/null
		done
	fi
	stdevs=$(ls -1 /sys/bus/usb/devices/ | wc -l)
	if [ $stdevs -gt 0 ];then
		export HAVE_USB="yes"
	fi
	waitForUSBDeviceScan
}
#======================================
# probeDevices
#--------------------------------------
function probeDevices {
	local skipUSB=$1
	#======================================
	# probe USB devices and load modules
	#--------------------------------------
	if [ -z "$skipUSB" ];then
		probeUSB
	fi
	#======================================
	# probe Disk devices and load modules
	#--------------------------------------
	if [ $HAVE_MODULES_ORDER = 0 ];then
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
		modprobe ide-disk &>/dev/null
	else
		if [ ! -z "$kiwikernelmodule" ];then
			for module in $kiwikernelmodule;do
				Echo "Probing module (cmdline): $module"
				INITRD_MODULES="$INITRD_MODULES $module"
				modprobe $module >/dev/null
			done
		fi
	fi
	#======================================
	# Manual loading of modules
	#--------------------------------------
	for i in rd brd edd dm-mod xennet xenblk;do
		modprobe $i &>/dev/null
	done
}
#======================================
# CDDevice
#--------------------------------------
function CDDevice {
	# /.../
	# detect CD/DVD/USB device(s). The function use the information
	# from hwinfo --cdrom to search for the block device
	# ----
	IFS=$IFS_ORIG
	local count=0
	local h=/usr/sbin/hwinfo
	if [ $HAVE_MODULES_ORDER = 0 ];then
		for module in sg sd_mod sr_mod cdrom ide-cd BusLogic vfat; do
			/sbin/modprobe $module
		done
	fi
	Echo -n "Waiting for CD/DVD device(s) to appear..."
	while true;do
		cddevs=`$h --cdrom | grep "Device File:"|sed -e"s@(.*)@@" | cut -f2 -d:`
		cddevs=`echo $cddevs`
		for i in $cddevs;do
			if [ -b $i ];then
				test -z $cddev && cddev=$i || cddev=$cddev:$i
			fi
		done
		if [ ! -z "$cddev" ] || [ $count -eq 12 ]; then
			break
		else
			echo -n .
			sleep 1
		fi
		count=`expr $count + 1`
	done
	echo
	if [ -z "$cddev" ];then
		USBStickDevice
		if [ $stickFound = 0 ];then
			systemException \
				"Failed to detect CD/DVD or USB drive !" \
			"reboot"
		fi
		cddev=$stickDevice
	fi
}
#======================================
# USBStickDevice
#--------------------------------------
function USBStickDevice {
	stickFound=0
	local mode=$1
	#======================================
	# search for USB removable devices
	#--------------------------------------
	waitForUSBDeviceScan
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
			if ! partitionSize $device >/dev/null;then
				continue;
			fi
			if [ ! -f $serial ];then
				serial="USB Stick (unknown type)"
			else
				serial=`cat $serial`
			fi
			removable=`cat $isremovable`
			# /.../
			# don't check the removable flag, it could be wrong
			# especially for USB hard disks connected via a
			# USB caddy, details in bug: 535113
			# ----
			removable=1
			if [ $removable -eq 1 ];then
				stickRoot=$device
				stickDevice=$(ddn $device 1)
				for devnr in 1 2;do
					dev=$(ddn $stickRoot $devnr)
					if ! kiwiMount "$dev" "/mnt" "-o ro";then
						continue
					fi
					if [ "$mode" = "install" ];then
						# /.../
						# USB stick search for install media
						# created with kiwi
						# ----
						if \
							[ ! -e /mnt/config.isoclient ] && \
							[ ! -e /mnt/config.usbclient ]
						then
							umountSystem
							continue
						fi
					elif [ "$mode" = "kexec" ];then
						# /.../
						# USB stick search for hotfix media
						# with kernel/initrd for later kexec
						# ----
						if \
							[ ! -e /mnt/linux.kexec ] && \
							[ ! -e /mnt/initrd.kexec ]
						then
							umountSystem
							continue
						fi
					else
						# /.../
						# USB stick search for Linux system tree
						# created with kiwi
						# ----
						if [ ! -e /mnt/etc/ImageVersion ]; then
							umountSystem
							continue
						fi
					fi
					stickFound=1
					umountSystem
					break
				done
				if [ "$stickFound" = 0 ];then
					continue
				fi
				stickSerial=$serial
				return
			fi
		done
	done
}
#======================================
# CDMountOption
#--------------------------------------
function CDMountOption {
	# /.../
	# checks for the ISO 9660 extension and prints the
	# mount option required to mount the device in full
	# speed mode
	# ----
	local dev=$1
	local iso="ISO 9660"
	if dd if=$dev bs=42k count=1 2>&1 | file - | grep -q $iso;then
		echo "-t iso9660"
	fi
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
	local ecode=0
	local cdopt
	mkdir -p /cdrom
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for hybrid mbr ID
	#--------------------------------------
	if [ -z "$cdinst" ];then
		searchBIOSBootDevice
		ecode=$?
		if [ ! $ecode = 0 ];then
			if [ $ecode = 2 ];then
				systemException "$biosBootDevice" "reboot"
			fi
			unset kiwi_hybrid
		fi
	else
		unset kiwi_hybrid
	fi
	#======================================
	# walk through media
	#--------------------------------------
	if [ -z "$kiwi_hybrid" ];then
		#======================================
		# search for CD/DVD devices
		#--------------------------------------
		CDDevice
		Echo -n "Mounting live boot drive..."
		while true;do
			IFS=":"; for i in $cddev;do
				cdopt=$(CDMountOption $i)
				if [ -x /usr/bin/driveready ];then
					driveready $i&& eval mount $cdopt -o ro $i /cdrom >/dev/null
				else
					eval mount $cdopt -o ro $i /cdrom >/dev/null
				fi
				if [ -f $LIVECD_CONFIG ];then
					cddev=$i; echo
					#======================================
					# run mediacheck if requested and boot
					#--------------------------------------
					if [ "$mediacheck" = 1 ]; then
						test -e /proc/splash && echo verbose > /proc/splash
						checkmedia $cddev
						Echo -n "Press ENTER for reboot: "; read nope
						/sbin/reboot -f -i >/dev/null
					fi
					#======================================
					# device found go with it
					#--------------------------------------
					IFS=$IFS_ORIG
					return
				fi
				umount $i &>/dev/null
			done
			IFS=$IFS_ORIG
			if [ $count -eq 12 ]; then
				break
			else
				echo -n .
				sleep 1
			fi
			count=`expr $count + 1`
		done
	else
		#======================================
		# search for hybrid device
		#--------------------------------------
		if [ "x$kiwi_hybridpersistent" = "xyes" ]; then
			createHybridPersistent $biosBootDevice
		fi
		Echo -n "Mounting hybrid live boot drive..."
		cddev=$(ddn $biosBootDevice 1)
		kiwiMount "$cddev" "/cdrom" "-o ro"
		if [ -f $LIVECD_CONFIG ];then
			echo
			#======================================
			# run mediacheck if requested and boot
			#--------------------------------------
			if [ "$mediacheck" = 1 ]; then
				test -e /proc/splash && echo verbose > /proc/splash
				checkmedia $cddev
				Echo -n "Press ENTER for reboot: "; read nope
				/sbin/reboot -f -i >/dev/null
			fi
			#======================================
			# search hybrid for a write partition
			#--------------------------------------
			for disknr in 2 3 4;do
				id=`partitionID $biosBootDevice $disknr`
				if [ "$id" = "83" ];then
					export HYBRID_RW=$biosBootDevice$disknr
					break
				fi
			done
			#======================================
			# device found go with it
			#--------------------------------------
			return
		fi
		umount $cddev &>/dev/null
	fi
	echo
	systemException \
		"Couldn't find Live image configuration file" \
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
# searchBIOSBootDevice
#--------------------------------------
function searchBIOSBootDevice {
	# /.../
	# search for the BIOS boot device which is the device
	# with the BIOS id 0x80. The test may fail if the boot
	# device is a CD/DVD drive. If the test fails we search
	# for the MBR disk label and compare it with the kiwi
	# written mbrid file in /boot/grub/ of the system image
	# ----
	IFS=$IFS_ORIG
	local h=/usr/sbin/hwinfo
	local c="Device File:|BIOS id"
	local ddevs=`$h --disk|grep -E "$c"|sed -e"s@(.*)@@"|cut -f2 -d:|tr -d " "`
	local cmpd=/tmp/mbrids
	local ifix=0
	local matched
	local bios
	local file
	local pred
	#======================================
	# Store device with BIOS id 0x80
	#--------------------------------------
	for curd in $ddevs;do
		if [ $curd = "0x80" ];then
			bios=$pred; break
		fi
		pred=$curd
	done
	#======================================
	# Check for OEM ISO installation mode
	#--------------------------------------
	if [ ! -z "$cdinst" ];then
		CDMount
		umount $cddev
		curd=$cddev
		export biosBootDevice=$curd
		return 0
	fi
	#======================================
	# Search and copy all mbrid files 
	#--------------------------------------
	mkdir -p $cmpd
	for curd in $ddevs;do
		if [ ! $(echo $curd | cut -c 1) = "/" ];then
			continue
		fi
		for id in 1 2 3;do
			dev=$(ddn $curd $id)
			if ! mount -o ro $dev /mnt;then
				continue
			fi
			if [ -f /mnt/boot/grub/mbrid ];then
				cp -a /mnt/boot/grub/mbrid $cmpd/mbrid$ifix
				ifix=$(expr $ifix + 1)
				umount /mnt
				break
			fi
			umount /mnt
		done
	done
	#======================================
	# Read mbrid from the newest mbrid file 
	#--------------------------------------
	file=$(ls -1t $cmpd 2>/dev/null | head -n 1)
	if [ -z "$file" ];then
		export biosBootDevice="Failed to find MBR identifier !"
		return 1
	fi
	read mbrI < $cmpd/$file
	#======================================
	# Compare ID with MBR entry 
	#--------------------------------------
	ifix=0
	for curd in $ddevs;do
		if [ ! -b $curd ];then
			continue
		fi
		mbrM=`dd if=$curd bs=1 count=4 skip=$((0x1b8))|hexdump -n4 -e '"0x%x"'`
		if [ "$mbrM" = "$mbrI" ];then
			ifix=1
			matched=$curd
			if [ "$curd" = "$bios" ];then
				export biosBootDevice=$curd
				return 0
			fi
		fi
	done
	if [ $ifix -eq 1 ];then
		export biosBootDevice=$matched
		return 0
	fi
	export biosBootDevice="No devices matches MBR identifier: $mbrI !"
	return 2
}
#======================================
# searchVolumeGroup
#--------------------------------------
function searchVolumeGroup {
	# /.../
	# search for a volume group named $VGROUP and if it can be
	# found activate it while creating appropriate device nodes:
	# /dev/$VGROUP/LVRoot and/or /dev/$VGROUP/LVComp
	# return zero on success
	# ----
	if vgscan 2>&1 | grep -q "$VGROUP"; then
		vgchange -a y $VGROUP
		return $?
	fi
	return 1
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
			id=`partitionID $diskdev $disknr`
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
			id=`partitionID $diskdev $disknr`
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
	dhcpcd -p $PXE_IFACE 1>&2
	if test $? != 0;then
		systemException \
			"Failed to setup DHCP network interface !" \
		"reboot"
	fi
	ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20;do
		[ -s /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info ] && break
		sleep 2
	done
	importFile < /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info
	if [ -z "$DOMAIN" ] && [ -n "$DNSDOMAIN" ];then
		export DOMAIN=$DNSDOMAIN
	fi
	echo "search $DOMAIN" > /etc/resolv.conf
	if [ -z "$DNS" ] && [ -n "$DNSSERVERS" ];then
		export DNS=$DNSSERVERS
	fi
	IFS="," ; for i in $DNS;do
		echo "nameserver $i" >> /etc/resolv.conf
	done
	DHCPCHADDR=`echo $DHCPCHADDR | tr a-z A-Z`
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
	local count=0
	IFS="," ; for i in $IMAGE;do
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) field=1 ;;
			1) imageName=$n   ; field=2 ;;
			2) imageVersion=$n; field=3 ;;
			3) imageServer=$n ; field=4 ;;
			4) imageBlkSize=$n; field=5 ;;
			5) imageZipped=$n ;
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
		read sum1 blocks blocksize zblocks zblocksize < /etc/image.md5
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
	local diskDevice=$1
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
	diskPartitionType=`partitionID $diskPD $diskID`
	if test "$diskPartitionType" = "8e";then
		Echo "Creating Volume group [systemvg]"
		pvcreate $diskPartition >/dev/null
		vgcreate systemvg $diskPartition >/dev/null
	else
		# .../
		# Create partition in case it is not root system and
		# there is no system  already created There is no need to
		# create a filesystem on the root partition
		# ----
		if test $diskID -gt 2; then
			if ! e2fsck -p $diskPartition 1>&2; then
				Echo "Partition $diskPartition is not valid, formating..."
				mke2fs -F -T ext3 -j $diskPartition 1>&2
				if test $? != 0; then
					systemException \
						"Failed to create filesystem on: $diskPartition !" \
					"reboot"
				fi
			else
				Echo "Partition $diskPartition is valid, leave it untouched"
			fi
		fi
	fi
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
# sfdiskGetPartitionID
#--------------------------------------
function sfdiskGetPartitionID {
	# /.../
	# prints the partition ID for the given device and number
	# ----
	sfdisk -c $1 $2
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
# sfdiskWritePartitionTable
#--------------------------------------
function sfdiskWritePartitionTable {
	# /.../
	# write the partition table using PART_FILE as
	# input for sfdisk
	# ----
	local diskDevice=$1
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
# partedGetPartitionID
#--------------------------------------
function partedGetPartitionID {
	# /.../
	# prints the partition ID for the given device and number
	# ----
	local disk=`echo $1 | sed -e s"@[0-9]@@g"`
	parted -m -s $disk print | grep ^$2: | cut -f10 -d, | cut -f2 -d=
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
			p_cmd="$p_cmd set $PART_COUNT type 0x$partID"
		else
			if [ $PART_COUNT -eq 4 ];then
				p_cmd="$p_cmd mkpart extended $p_start $p_size"
				p_cmd="$p_cmd set $PART_COUNT type 0x85"
				PART_COUNT=`expr $PART_COUNT + 1`
				NO_FILE_SYSTEM=1
			fi
			p_start=`expr $p_start + 1`
			p_cmd="$p_cmd mkpart logical $p_start $p_stopp"
			p_cmd="$p_cmd set $PART_COUNT type 0x$partID"
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
	local diskDevice=$1
	eval $p_cmd
	if test $? != 0;then
		systemException \
			"Failed to create partition table on: $diskDevice !" \
		"reboot"
	fi
}
#======================================
# partitionID
#--------------------------------------
function partitionID {
	local diskDevice=$1
	local diskNumber=$2
	if [ $PARTITIONER = "sfdisk" ];then
		sfdiskGetPartitionID $diskDevice $diskNumber
	else
		partedGetPartitionID $diskDevice $diskNumber
	fi
}
#======================================
# partitionSize
#--------------------------------------
function partitionSize {
	local diskDevice=$1
	if [ -z "$diskDevice" ] || [ ! -e "$diskDevice" ];then
		return 1
	fi
	expr $(blockdev --getsize64 $diskDevice) / 1024
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
	local diskDevice=$1
	local diskPartitionType=`partitionID $diskDevice 2`
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
	local prefix=$1
	local kcount=0
	local kname=""
	local kernel=""
	local initrd=""
	KERNEL_LIST=""
	KERNEL_NAME=""
	for i in $prefix/lib/modules/*;do
		if [ ! -d $i ];then
			continue
		fi
		unset KERNEL_PAIR
		unset kernel
		unset initrd
		kname=`basename $i`
		for k in $prefix/boot/vmlinu[zx]-${i##*/}; do
			if [ -f $k ];then
				kernel=${k##*/}
				initrd=initrd-${i##*/}
			fi
		done
		if [ -z $kernel ];then
			continue
		fi
		kcount=$((kcount+1))
		KERNEL_PAIR=$kernel:$initrd
		KERNEL_NAME[$kcount]=$kname
		if [ $kcount = 1 ];then
			KERNEL_LIST=$KERNEL_PAIR
		elif [ $kcount -gt 1 ];then
			KERNEL_LIST=$KERNEL_LIST,$KERNEL_PAIR
		fi
	done
	if [ -z "$KERNEL_LIST" ];then
		# /.../
		# the system image doesn't provide the kernel and initrd but
		# if there is a downloaded kernel and initrd from the KIWI_INITRD
		# setup. the kernelList function won't find initrds that gets
		# downloaded over tftp so make sure the vmlinu[zx]/initrd combo
		# gets added
		# ----
		if [ -e $prefix/boot/vmlinuz ];then
			KERNEL_LIST="vmlinuz:initrd"
			KERNEL_NAME[1]=vmlinuz
		fi
		if [ -e $prefix/boot/vmlinux ];then
			KERNEL_LIST="vmlinux:initrd"
			KERNEL_NAME[1]=vmlinux
		fi
	fi
	export KERNEL_LIST
	export KERNEL_NAME
}
#======================================
# validateSize
#--------------------------------------
function validateSize {
	# /.../
	# check if the image fits into the requested partition.
	# An information about the sizes is printed out
	# ----
	haveBytes=`partitionSize $imageDevice`
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
	if [ "$haveMByte" -gt "$needMByte" ];then
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
	# 65535 blocks, so the block size must be checked according
	# to the size of the image. The block size itself is also
	# limited to 65464 bytes
	# ----
	if [ -z "$zblocks" ] && [ -z "$blocks" ];then
		# md5 file not yet read in... skip
		return
	fi
	if [ ! -z "$zblocks" ];then
		isize=`expr $zblocks \* $zblocksize`
	else
		isize=`expr $blocks \* $blocksize`
	fi
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
		eval export $kernelKey=$kernelVal
	done
	if [ ! -z "$kiwikernelmodule" ];then
		kiwikernelmodule=`echo $kiwikernelmodule | tr , " "`
	fi
	if [ ! -z "$kiwibrokenmodule" ];then
		kiwibrokenmodule=`echo $kiwibrokenmodule | tr , " "`
	fi
	if [ ! -z "$kiwistderr" ];then
		export ELOG_CONSOLE=$kiwistderr
		export ELOG_EXCEPTION=$kiwistderr
	fi
	if [ ! -z "$ramdisk_size" ];then
		local modfile=/etc/modprobe.conf.local
		if [ -f $modfile ];then
			sed -i -e s"@rd_size=.*@rd_size=$ramdisk_size@" $modfile
		fi
	fi
	if [ ! -z "$lang" ];then
		export DIALOG_LANG=$lang
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
			if [ -d $dir ];then
				if ! umount $dir >/dev/null;then
				if ! umount -l $dir >/dev/null;then
					retval=1
				fi
				fi
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
# isFSTypeReadOnly
#--------------------------------------
function isFSTypeReadOnly {
	if [ "$FSTYPE" = "squashfs" ];then
		export unionFST=aufs
		return 0
	fi
	if [ "$FSTYPE" = "clicfs" ];then
		export unionFST=clicfs
		return 0
	fi
	return 1
}
#======================================
# kiwiMount
#--------------------------------------
function kiwiMount {
	local src=$1
	local dst=$2
	local opt=$3
	local lop=$4
	#======================================
	# load not autoloadable fs modules
	#--------------------------------------
	modprobe squashfs &>/dev/null
	#======================================
	# store old FSTYPE value
	#--------------------------------------
	if [ ! -z "$FSTYPE" ];then
		FSTYPE_SAVE=$FSTYPE
	fi
	#======================================
	# probe filesystem
	#--------------------------------------
	if [ ! "$FSTYPE" = "nfs" ];then
		if [ ! -z "$lop" ];then
			probeFileSystem $lop
		else
			probeFileSystem $src
		fi
	fi
	if [ -z "$FSTYPE" ] || [ "$FSTYPE" = "unknown" ];then
		FSTYPE="auto"
	fi
	#======================================
	# decide for a mount method
	#--------------------------------------
	if [ ! -z "$lop" ];then
		# /.../
		# if loop mount is requested a fixed loop1 device
		# was set as src parameter. Because this fixed loop
		# name is used later too we stick to this device name
		# ----
		losetup /dev/loop1 $lop
	fi
	if ! mount -t $FSTYPE $opt $src $dst >/dev/null;then
		return 1
	fi
	if [ ! -z "$FSTYPE_SAVE" ];then
		FSTYPE=$FSTYPE_SAVE
	fi
	return 0
}
#======================================
# setupReadWrite
#--------------------------------------
function setupReadWrite {
	# /.../
	# check/create read-write filesystem used for
	# overlay data
	# ----
	local rwDir=/read-write
	local rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
	mkdir -p $rwDir
	if [ $LOCAL_BOOT = "no" ] && [ $systemIntegrity = "clean" ];then
		if [ "$RELOAD_IMAGE" = "yes" ] || \
			! mount -o ro $rwDevice $rwDir >/dev/null
		then
			#======================================
			# store old FSTYPE value
			#--------------------------------------
			if [ ! -z "$FSTYPE" ];then
				FSTYPE_SAVE=$FSTYPE
			fi
			#======================================
			# probe filesystem
			#--------------------------------------
			probeFileSystem $rwDevice
			if [ ! "$FSTYPE" = "unknown" ];then
				Echo "Checking filesystem for RW data on $rwDevice..."
				e2fsck -p $rwDevice
			fi
			#======================================
			# restore FSTYPE
			#--------------------------------------
			if [ ! -z "$FSTYPE_SAVE" ];then
				FSTYPE=$FSTYPE_SAVE
			fi
			if [ "$RELOAD_IMAGE" = "yes" ] || \
				! mount -o ro $rwDevice $rwDir >/dev/null
			then
				Echo "Creating filesystem for RW data on $rwDevice..."
				if ! mke2fs -F -T ext3 -j $rwDevice >/dev/null;then
					Echo "Failed to create ext3 filesystem"
					return 1
				fi
				e2fsck -p $rwDevice >/dev/null
			fi
		else
			umount $rwDevice
		fi
	fi
	return 0
}
#======================================
# mountSystemUnified
#--------------------------------------
function mountSystemUnified {
	local loopf=$1
	local roDir=/read-only
	local roDevice=`echo $UNIONFS_CONFIG | cut -d , -f 2`
	#======================================
	# create read only mount point
	#--------------------------------------
	mkdir -p $roDir
	#======================================
	# check read/only device location
	#--------------------------------------
	if [ ! -z "$NFSROOT" ];then
		roDevice="$imageRootDevice"
	fi
	#======================================
	# mount read only device
	#--------------------------------------
	if ! kiwiMount "$roDevice" "$roDir" "" $loopf;then
		Echo "Failed to mount read only filesystem"
		return 1
	fi
	#======================================
	# check union mount method
	#--------------------------------------
	if [ -f $roDir/fsdata.ext3 ];then
		export haveDMSquash=yes
		mountSystemDMSquash
	else
		mountSystemOverlay
	fi
}
#======================================
# mountSystemDMSquash
#--------------------------------------
function mountSystemDMSquash {
	local roDir=/read-only
	local snDevice=/dev/mapper/sys_snap
	local rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
	local roDevice=`echo $UNIONFS_CONFIG | cut -d , -f 2`
	local orig_loop=$(losetup -r -s -f $roDir/fsdata.ext3)
	local orig_sectors=$(blockdev --getsize $orig_loop)
	local snap_sectors=$(blockdev --getsz $rwDevice)
	local free_sectors=0
	local used_sectors=0
	local chunk=8
	local flags=p
	local count=0
	#======================================
	# check read-write persistency
	#--------------------------------------
	if getDiskDevice $rwDevice | grep -q ram;then
		flags=n
	fi
	#======================================
	# create snapshot device
	#--------------------------------------
	dmsetup create sys_snap --notable
	echo "0 $orig_sectors snapshot $orig_loop $rwDevice $flags $chunk" |\
		dmsetup load sys_snap
	#======================================
	# resume snapshot and origin devices
	#--------------------------------------
	dmsetup resume sys_snap
	#======================================
	# mount snapshot as root to /mnt
	#--------------------------------------
	mount $snDevice /mnt
	#======================================
	# check free size and snapshot size
	#--------------------------------------
	snap_sectors=$(($snap_sectors * 80 / 100))
	for i in $(df --block-size 512 /mnt | tail -n1);do
		count=`expr $count + 1`
		if [ $count = 3 ];then
			used_sectors=$i
		fi
		if [ $count = 4 ];then
			free_sectors=$i
		fi
	done
	if [ $snap_sectors -lt $free_sectors ];then
		# /.../
		# the snapshot space if less than the free space
		# of the filesystem. Therefore we need to resize
		# the filesystem to the free space of the snapshot
		# ----
		Echo "*** WARNING ***"
		Echo "The snapshot space is: $snap_sectors 512B sectors"
		Echo "which is smaller than the filesystem reported"
		Echo "free sectors of: $free_sectors"
		#umount /mnt
		#snap_sectors=$(($snap_sectors + $used_sectors))
		#resize2fs -f -p $snDevice "$snap_sectors"s
		#mount $snDevice /mnt
	fi
}
#======================================
# mountSystemClicFS
#--------------------------------------
function mountSystemClicFS {
	local loopf=$1
	local roDir=/read-only
	local rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
	local roDevice=`echo $UNIONFS_CONFIG | cut -d , -f 2`
	local clic_cmd=clicfs
	local haveBytes
	local haveKByte
	local haveMByte
	local size
	#======================================
	# load fuse module
	#--------------------------------------
	modprobe fuse &>/dev/null
	#======================================
	# create read only mount point
	#--------------------------------------
	mkdir -p $roDir
	#======================================
	# check read/only device location
	#--------------------------------------
	if [ ! -z "$NFSROOT" ];then
		roDevice="$imageRootDevice"
	fi
	#======================================  
	# check kernel command line for log file  
	#--------------------------------------  
	if [ -n "$cliclog" ]; then  
		clic_cmd="$clic_cmd -l $cliclog"  
	fi  
	#======================================
	# check read/write device location
	#--------------------------------------
	getDiskDevice $rwDevice | grep -q ram
	if [ $? = 0 ];then
		haveKByte=`cat /proc/meminfo | grep MemFree | cut -f2 -d:| cut -f1 -dk`
		haveMByte=`expr $haveKByte / 1024`
		haveMByte=`expr $haveMByte \* 7 / 10`
		clic_cmd="$clic_cmd -m $haveMByte"
	else
		haveBytes=`blockdev --getsize64 $rwDevice`
		haveMByte=`expr $haveBytes / 1024 / 1024`
		if \
			[ "x$kiwi_hybrid" = "xyes" ] &&
			[ "x$kiwi_hybridpersistent" = "xyes" ]
		then
			# write into a cow file on a filesystem
			mkdir -p $HYBRID_PERSISTENT_DIR
			if ! mount $rwDevice $HYBRID_PERSISTENT_DIR;then
				if ! setupReadWrite; then
					Echo "Failed to setup read-write filesystem"
					return 1
				fi
				if ! mount $rwDevice $HYBRID_PERSISTENT_DIR;then
					Echo "Failed to mount read/write filesystem"
					return 1
				fi
			fi
			clic_cmd="$clic_cmd -m $haveMByte"
			clic_cmd="$clic_cmd -c $HYBRID_PERSISTENT_DIR/.clicfs_COW"
			clic_cmd="$clic_cmd --ignore-cow-errors"
		else
			# write into a device directly
			clic_cmd="$clic_cmd -m $haveMByte -c $rwDevice --ignore-cow-errors"
		fi
	fi
	#======================================
	# mount/check clic file
	#--------------------------------------
	if [ ! -z "$NFSROOT" ];then
		#======================================
		# clic exported via NFS
		#--------------------------------------
		if ! kiwiMount "$roDevice" "$roDir" "" $loopf;then
			Echo "Failed to mount NFS filesystem"
			return 1
		fi
		if [ ! -e "$roDir/fsdata.ext3" ];then
			Echo "Can't find clic fsdata.ext3 in NFS export"
			return 1
		fi
	else
		#======================================
		# mount clic container
		#--------------------------------------
		if [ -z "$loopf" ];then
			loopf=$roDevice
		fi
		if ! $clic_cmd $loopf $roDir; then  
			Echo "Failed to mount clic filesystem"
			return 1
		fi 
	fi
	#======================================
	# mount root over clic
	#--------------------------------------
	size=`stat -c %s $roDir/fsdata.ext3`
	size=$((size/4096))
	# we don't want reserved blocks...
	tune2fs -m 0 $roDir/fsdata.ext3 >/dev/null
	# we don't want automatic filesystem check...
	tune2fs -i 0 $roDir/fsdata.ext3 >/dev/null
	if [ ! $LOCAL_BOOT = "no" ];then
		e2fsck -p $roDir/fsdata.ext3
	fi
	if [ $LOCAL_BOOT = "no" ];then
		resize2fs $roDir/fsdata.ext3 $size
	fi
	mount -o loop,noatime,nodiratime,errors=remount-ro,barrier=0 \
		$roDir/fsdata.ext3 /mnt
	if [ ! $? = 0 ];then
		Echo "Failed to mount ext3 clic container"
		return 1
	fi
	export haveClicFS=yes
	return 0
}
#======================================
# mountSystemOverlay
#--------------------------------------
function mountSystemOverlay {
	local roDir=/read-only
	local rwDir=/read-write
	local xiDir=/xino
	local rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
	local roDevice=`echo $UNIONFS_CONFIG | cut -d , -f 2`
	local unionFST=`echo $UNIONFS_CONFIG | cut -d , -f 3`
	#======================================
	# create read write mount points
	#--------------------------------------
	for dir in $rwDir $xiDir;do
		mkdir -p $dir
	done
	#======================================
	# check read/write device location
	#--------------------------------------
	getDiskDevice $rwDevice | grep -q ram
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
		# write part is not a ram disk, create/check ext3 filesystem
		# on it if not remote. Mount the filesystem
		# ----
		if [ "$roDevice" = "nfs" ];then
			rwDevice="-o nolock,rw $nfsRootServer:$rwDevice"
		fi
		if [ ! "$roDevice" = "nfs" ] && ! setupReadWrite; then
			return 1
		fi
		if ! mount $rwDevice $rwDir >/dev/null;then
			Echo "Failed to mount read/write filesystem"
			return 1
		fi
	fi
	#======================================
	# setup overlay mount
	#--------------------------------------
	if [ $unionFST = "aufs" ];then
		mount -t tmpfs tmpfs $xiDir >/dev/null || retval=1
		mount -t aufs \
			-o dirs=$rwDir=rw:$roDir=ro,xino=$xiDir/.aufs.xino aufs /mnt \
		>/dev/null || return 1
	else
		mount -t unionfs \
			-o dirs=$rwDir=rw:$roDir=ro unionfs /mnt
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
	local loopf=$2
	local roDevice=$mountDevice
	if [ "$haveLVM" = "yes" ]; then
		local rwDevice="/dev/$VGROUP/LVRoot"
	elif [ "$haveLuks" = "yes" ]; then
		local rwDevice="/dev/mapper/luksReadWrite"
	else
		local rwDevice=`getNextPartition $mountDevice`
	fi
	mkdir /read-only >/dev/null
	# /.../
	# mount the read-only partition to /read-only and use
	# mount option -o ro for this filesystem
	# ----
	if ! kiwiMount "$roDevice" "/read-only" "" $loopf;then
		Echo "Failed to mount read only filesystem"
		return 1
	fi
	# /.../
	# mount a tmpfs as /mnt which will become the root fs (/) later on
	# and extract the rootfs tarball with the RAM data and the read-only
	# and read-write links into the tmpfs.
	# ----
	local rootfs=/read-only/rootfs.tar
	if [ ! -f $rootfs ];then
		Echo "Can't find rootfs tarball"
		umount "$roDevice" &>/dev/null
		return 1
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
	if ! mount -t tmpfs tmpfs -o size=512M,nr_inodes=$inr /mnt;then
		systemException \
			"Failed to mount root tmpfs" \
		"reboot"
	fi
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
		if partitionSize $rwDevice &>/dev/null;then
			# /.../
			# mount the read-write partition to /mnt/read-write and create
			# a link to it: /read-write -> /mnt/read-write 
			# ----
			mkdir /mnt/read-write >/dev/null
			mount $rwDevice /mnt/read-write >/dev/null
			rm -rf /read-write >/dev/null
			ln -s /mnt/read-write /read-write >/dev/null
		fi
	fi
	if [ "$LOCAL_BOOT" = "yes" ] && [ "$haveLuks" = "yes" ];then
		mkdir -p /mnt/luksboot
		( cd /mnt && rm boot && ln -sf luksboot/boot boot )
	fi
}
#======================================
# mountSystemStandard
#--------------------------------------
function mountSystemStandard {
	local mountDevice=$1
	if [ ! -z $FSTYPE ]          && 
	   [ ! $FSTYPE = "unknown" ] && 
	   [ ! $FSTYPE = "auto" ]
	then
		kiwiMount "$mountDevice" "/mnt"
	else
		mount $mountDevice /mnt >/dev/null
	fi
	if [ "$haveLVM" = "yes" ];then
		for i in /dev/$VGROUP/LV*;do
			local volume=$(echo $i | cut -f4 -d/ | cut -c3-)
			local mpoint=$(echo $volume | tr _ /)
			if \
				[ ! $volume = "Root" ] && \
				[ ! $volume = "Comp" ] && \
				[ ! $volume = "Swap" ]
			then
				mkdir -p /mnt/$mpoint
				mount /dev/$VGROUP/LV$volume /mnt/$mpoint
			fi
		done
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
	# set primary mount device
	#--------------------------------------
	local mountDevice="$imageRootDevice"
	if [ ! -z "$1" ];then
		mountDevice="$1"
	fi
	#======================================
	# wait for storage device to appear
	#--------------------------------------
	if ! echo $mountDevice | grep -qE "loop|nolock";then
		waitForStorageDevice $mountDevice
	fi
	#======================================
	# check root tree type
	#--------------------------------------
	if [ ! -z "$COMBINED_IMAGE" ];then
		mountSystemCombined "$mountDevice" $2
		retval=$?
	elif [ ! -z "$UNIONFS_CONFIG" ];then
		local unionFST=`echo $UNIONFS_CONFIG | cut -d , -f 3`
		if [ "$unionFST" = "clicfs" ];then
			mountSystemClicFS $2
		else
			mountSystemUnified $2
		fi
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
	# start a debugging shell on ELOG_BOOTSHELL
	# ----
	if [ -z "$kiwistderr" ] && [ ! -z $kiwidebug ];then
		Echo "Starting boot shell on $ELOG_BOOTSHELL"
		setctsid -f $ELOG_BOOTSHELL /bin/bash -i
	fi
}
#======================================
# killShell
#--------------------------------------
function killShell {
	# /.../
	# kill debugging shell on ELOG_BOOTSHELL
	# ----
	local umountProc=0
	if [ ! -e /proc/mounts ];then
		mount -t proc proc /proc
		umountProc=1
	fi
	if [ -z "$kiwistderr" ];then
		Echo "Stopping boot shell"
		fuser -k $ELOG_BOOTSHELL >/dev/null
	fi
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
	udevPending
	while true;do
		partitionSize $device &>/dev/null
		if [ $? = 0 ];then
			sleep 1; return 0
		fi
		if [ $check -eq 4 ];then
			return 1
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
	udevPending
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
		path=$(echo $path | sed -e s@\\.gz@@)
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
			# /.../
			# atftp activates multicast by '--option "multicast"'
			# and deactivates it again  by '--option "disable multicast"'
			# ----
			multicast_atftp="multicast"
			if test "$multicast" != "enable"; then 
				multicast_atftp="disable multicast"
			fi
			if test "$izip" = "compressed"; then
				# mutlicast is disabled because you can't seek in a pipe
				# atftp is disabled because it doesn't work with pipes
				busybox tftp \
					-b $imageBlkSize -g -r $path \
					-l >(gzip -d > $dest 2>>$TRANSFER_ERRORS_FILE) \
					$host 2>>$TRANSFER_ERRORS_FILE
			else
				atftp \
					--option "$multicast_atftp"  \
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
		if ! canWrite /mnt/boot;then
			Echo "Can't write to boot, import of boot message skipped"
		else
			mv /image/loader/message /mnt/boot
		fi
	fi
	if [ -f /image/loader/branding/logo.mng ];then
	if [ -d /mnt/etc/bootsplash/themes ];then
		for theme in /mnt/etc/bootsplash/themes/*;do
			if [ -d $theme/images ];then
				if ! canWrite $theme;then
					Echo "Can't write to $theme, import of boot theme skipped"
					continue
				fi
				cp /image/loader/branding/logo.mng  $theme/images
				cp /image/loader/branding/logov.mng $theme/images
				cp /image/loader/branding/*.jpg $theme/images
				cp /image/loader/branding/*.cfg $theme/config
			fi
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

#======================================
# getDiskID
#--------------------------------------
function getDiskID {
	# /.../
	# this function is able to turn a given standard device
	# name into the udev ID based representation
	# ----
	local device=$1
	if [ -z "$device" ];then
		return
	fi
	if echo $device | grep -q "$VGROUP"; then
		echo $device
		return
	fi
	for i in /dev/disk/by-id/*;do
		if echo $i | grep -q edd-;then
			continue
		fi
		local dev=`readlink $i`
		dev=/dev/`basename $dev`
		if [ $dev = $device ];then
			echo $i
			return
		fi
	done
	echo $device
}
#======================================
# getDiskDevice
#--------------------------------------
function getDiskDevice {
	# /.../
	# this function is able to turn the given udev disk
	# ID label into the /dev/ device name
	# ----
	local device=`readlink $1`
	if [ -z "$device" ];then
		echo $1
		return
	fi
	device=`basename $device`
	device=/dev/$device
	echo $device
}
#======================================
# getDiskModel
#--------------------------------------
function getDiskModels {
	# /.../
	# this function returns the disk identifier as
	# registered in the sysfs layer
	# ----
	local models=`cat /sys/block/*/device/model 2>/dev/null`
	if [ ! -z "$models" ];then
		echo $models; return
	fi
	echo "unknown"
}
#======================================
# setupInittab
#--------------------------------------
function setupInittab {
	# /.../
	# setup default runlevel according to /proc/cmdline
	# information. If textmode is set to 1 we will boot into
	# runlevel 3
	# ----
	local prefix=$1
	if cat /proc/cmdline | grep -qi "textmode=1";then
		sed -i -e s"@id:.*:initdefault:@id:3:initdefault:@" $prefix/etc/inittab
	fi
}
#======================================
# setupConfigFiles
#--------------------------------------
function setupConfigFiles {
	# /.../
	# all files created below /config inside the initrd are
	# now copied into the system image
	# ----
	local file
	local dir
	cd /config
	find . -type f | while read file;do
		dir=$(dirname $file)
		if ! canWrite /mnt/$dir;then
			Echo "Can't write to $dir, read-only filesystem... skipped"
			continue
		fi
		if [ ! -d /mnt/$dir ];then
			mkdir -p /mnt/$dir
		fi
		cp $file /mnt/$file
	done
	cd /
	rm -rf /config
}
#======================================
# activateImage
#--------------------------------------
function activateImage {
	# /.../
	# move the udev created nodes from the initrd into
	# the system root tree call the pre-init phase which
	# already runs in the new tree and finaly switch the
	# new tree to be the new root (/) 
	# ----
	#======================================
	# setup image name
	#--------------------------------------
	local name
	if [ ! -z "$stickSerial" ];then
		name="$stickSerial on -> $stickDevice"
	elif [ ! -z "$imageName" ];then
		name=$imageName
	elif [ ! -z "$imageRootName" ];then
		name=$imageRootName
	elif [ ! -z "$imageRootDevice" ];then
		name=$imageRootDevice
	elif [ ! -z "$imageDiskDevice" ];then
		name=$imageDiskDevice
	else
		name="unknown"
	fi
	#======================================
	# move union mount points to system
	#--------------------------------------
	local roDir=read-only
	local rwDir=read-write
	local xiDir=xino
	if [ -z "$NFSROOT" ];then
		if [ -d $roDir ];then
			mkdir -p /mnt/$roDir && mount --move /$roDir /mnt/$roDir
		fi
		if [ -d $rwDir ];then
			mkdir -p /mnt/$rwDir && mount --move /$rwDir /mnt/$rwDir
		fi
		if [ -d $xiDir ];then
			mkdir -p /mnt/$xiDir && mount --move /$xiDir /mnt/$xiDir
		fi
	fi
	#======================================
	# move live CD mount points to system
	#--------------------------------------
	local cdDir=/livecd
	if [ -d $cdDir ];then
		mkdir -p /mnt/$cdDir && mount --move /$cdDir /mnt/$cdDir
	fi
	#======================================
	# move device nodes
	#--------------------------------------
	Echo "Activating Image: [$name]"
	reopenKernelConsole
	udevPending
	mount --move /dev /mnt/dev
	udevKill
	umount -t devpts /mnt/dev/pts
	#======================================
	# copy boot log file into system image
	#--------------------------------------
	mkdir -p /mnt/var/log
	rm -f /var/log/boot.msg
	rm -f /mnt/boot/grub/mbrid
	cp -f /mnt/dev/shm/initrd.msg /mnt/var/log/boot.msg
	cp -f /var/log/boot.kiwi /mnt/var/log/boot.kiwi
	#======================================
	# run preinit stage
	#--------------------------------------
	Echo "Preparing preinit phase..."
	if ! cp /preinit /mnt;then
		systemException "Failed to copy preinit code" "reboot"
	fi
	if ! cp /include /mnt;then
		systemException "Failed to copy include code" "reboot"
	fi
	if [ ! -x /lib/mkinitrd/bin/run-init ];then
		systemException "Can't find run-init program" "reboot"
	fi
	#======================================
	# kill boot timer
	#--------------------------------------
	if [ ! $UTIMER = 0 ] && kill -0 $UTIMER &>/dev/null;then
		kill $UTIMER
	fi
}
#======================================
# cleanImage
#--------------------------------------
function cleanImage {
	# /.../
	# remove preinit code from system image before real init
	# is called
	# ----
	#======================================
	# remove preinit code from system image
	#--------------------------------------
	rm -f /preinit
	rm -f /include
	rm -f /.kconfig
	rm -f /.profile
	rm -rf /image
	#======================================
	# don't call root filesystem check
	#--------------------------------------
	if [ "$haveClicFS" = "yes" ] || [ ! -z "$NFSROOT" ] ;then
		# FIXME: clicfs / NFS doesn't like this umount tricks
		export ROOTFS_FSCK="0"
		return
	fi
	#======================================
	# umount non busy fstab listed entries
	#--------------------------------------
	umount -a &>/dev/null
	#======================================
	# umount LVM root parts lazy
	#--------------------------------------
	if [ "$haveLVM" = "yes" ]; then
		for i in /dev/$VGROUP/LV*;do
			if [ ! -e $i ];then
				continue
			fi
			if \
				[ ! $i = "/dev/$VGROUP/LVRoot" ] && \
				[ ! $i = "/dev/$VGROUP/LVComp" ] && \
				[ ! $i = "/dev/$VGROUP/LVSwap" ]
			then
				umount -l $i &>/dev/null
			fi
		done
	fi
}
#======================================
# bootImage
#--------------------------------------
function bootImage {
	# /.../
	# call the system image init process and therefore
	# boot into the operating system
	# ----
	local reboot=no
	local option=$@
	#======================================
	# turn runlevel 4 to 5 if found
	#--------------------------------------
	option=$(echo $@ | sed -e s@4@5@)
	echo && Echo "Booting System: $option"
	export IFS=$IFS_ORIG
	#======================================
	# check for reboot request
	#--------------------------------------
	if [ "$LOCAL_BOOT" = "no" ];then
		if [ -z "$KIWI_RECOVERY" ];then
			if [ ! -z "$OEM_REBOOT" ] || [ ! -z "$REBOOT_IMAGE" ];then
				reboot=yes
			fi
		fi
	fi
	#======================================
	# directly boot/reboot
	#--------------------------------------
	umount proc &>/dev/null && \
	umount proc &>/dev/null
	if [ $reboot = "yes" ];then
		Echo "Reboot requested... rebooting after preinit"
		exec /lib/mkinitrd/bin/run-init -c /dev/console /mnt /bin/bash -c \
			"/preinit ; . /include ; cleanImage ; exec /sbin/reboot -f -i"
	else
		# FIXME: clicfs doesn't like run-init
		if [ ! "$haveClicFS" = "yes" ];then
			exec /lib/mkinitrd/bin/run-init -c /dev/console /mnt /bin/bash -c \
				"/preinit ; . /include ; cleanImage ; exec /sbin/init $option"
		else
			cd /mnt && exec chroot . /bin/bash -c \
				"/preinit ; . /include ; cleanImage ; exec /sbin/init $option"
		fi
	fi
}
#======================================
# setupUnionFS
#--------------------------------------
function setupUnionFS {
	# /.../
	# export the UNIONFS_CONFIG environment variable
	# which contains a three part coma separated list of the
	# following style: rwDevice,roDevice,unionType. The
	# devices are stores by disk ID if possible
	# ----
	local rwDevice=`getDiskID $1`
	local roDevice=`getDiskID $2`
	local unionFST=$3
	rwDeviceLuks=$(luksOpen $rwDevice luksReadWrite)
	roDeviceLuks=$(luksOpen $roDevice luksReadOnly)
	if [ ! $rwDeviceLuks = $rwDevice ];then
		rwDevice=$rwDeviceLuks
		export haveLuks="yes"
	fi
	if [ ! $roDeviceLuks = $roDevice ];then
		roDevice=$roDeviceLuks
		export haveLuks="yes"
	fi
	export UNIONFS_CONFIG="$rwDevice,$roDevice,$unionFST"
}
#======================================
# canWrite
#--------------------------------------
function canWrite {
	# /.../
	# check if we can write to the given location
	# If no location is given the function test
	# for write permissions in /mnt.
	# returns zero on success.
	# ---
	local dest=$1
	if [ -z "$dest" ];then
		dest=/mnt
	fi
	if [ ! -d $dest ];then
		return 1
	fi
	if touch $dest/can-write &>/dev/null;then
		rm $dest/can-write
		return 0
	fi
	return 1
}
#======================================
# xenServer
#--------------------------------------
function xenServer {
	# /.../
	# test if we are running a Xen dom0 kernel
	# ---
	local check=/proc/xen/capabilities
	if cat $check 2>/dev/null | grep "control_d" &>/dev/null; then
		return 0
	fi
	return 1
}
#======================================
# makeLabel
#--------------------------------------
function makeLabel {
	# /.../
	# create boot label and replace all spaces with
	# underscores. current bootloaders show the
	# underscore sign as as space in the boot menu
	# ---
	if [ -z "$loader" ];then
		loader="grub"
	fi
	if [ ! $loader = "syslinux" ];then
		echo $1 | tr " " "_"
	else
		echo $1
	fi
}
#======================================
# waitForX
#--------------------------------------
function waitForX {
	# /.../
	# wait for the X-Server with PID $xserver_pid to
	# become read for client calls
	# ----
	local xserver_pid=$1
	local testx=/usr/sbin/testX
	local err=1
	while kill -0 $xserver_pid 2>/dev/null ; do
		sleep 1
		if test -e /tmp/.X11-unix/X0 && test -x $testx ; then
			$testx 16 2>/dev/null
			err=$?
			# exit code 1 -> XOpenDisplay failed...
			if test $err = 1;then
				Echo "TestX: XOpenDisplay failed"
				return 1
			fi
			# exit code 2 -> color or dimensions doesn't fit...
			if test $err = 2;then
				Echo "TestX: color or dimensions doesn't fit"
				kill $xserver_pid
				return 1
			fi
			# server is running, detach oom-killer from it
			echo -n '-17' > /proc/$xserver_pid/oom_adj
			return 0
		fi
	done
	return 1
}
#======================================
# startX
#--------------------------------------
function startX {
	# /.../
	# start X-Server and wait for it to become ready
	# ----
	export DISPLAY=:0
	local XServer=/usr/bin/Xorg
	if [ -x /usr/X11R6/bin/Xorg ];then
		XServer=/usr/X11R6/bin/Xorg
	fi
	$XServer -deferglyphs 16 vt07 &
	export XServerPID=$!
	if ! waitForX $XServerPID;then
		Echo "Failed to start X-Server"
		return 1
	fi
	return 0
}
#======================================
# stoppX
#--------------------------------------
function stoppX {
	if [ -z "$XServerPID" ];then
		return
	fi
	if kill -0 $XServerPID 2>/dev/null; then
		sleep 1 && kill $XServerPID
		while kill -0 $XServerPID 2>/dev/null; do
			sleep 1
		done
	fi
}
#======================================
# luksOpen
#--------------------------------------
function luksOpen {
	# /.../
	# check given device if it uses the LUKS extension
	# if yes open the device and return the new
	# /dev/mapper/ device name
	# ----
	local ldev=$1
	local name=$2
	local info
	if [ -z $name ];then
		name=luksroot
	fi
	if [ -e /dev/mapper/$name ];then
		echo /dev/mapper/$name; return
	fi
	if ! cryptsetup isLuks $ldev &>/dev/null;then
		echo $ldev; return
	fi
	while true;do
		if [ ! -e /tmp/luks ];then
			Dialog \
				--stdout --insecure \
				--passwordbox "\"$TEXT_LUKS\"" 10 60 |\
				cat > /tmp/luks
		fi
		info=$(cat /tmp/luks | cryptsetup luksOpen $ldev $name 2>&1)
		if [ $? = 0 ];then
			break
		fi
		rm -f /tmp/luks
		Dialog --stdout --timeout 10 --msgbox "\"Error: $info\"" 8 60
	done
	echo /dev/mapper/$name
}
#======================================
# luksResize
#--------------------------------------
function luksResize {
	# /.../
	# check given device if it is a mapped device name
	# and run cryptsetup resize on the mapper name
	# ----
	local ldev=$1
	if [ ! "$haveLuks" = "yes" ] || [ ! -e $ldev ];then
		return
	fi
	local name=$(basename $ldev)
	local dmap=$(dirname  $ldev)
	if [ ! "$dmap" = "/dev/mapper" ];then
		return
	fi
	cryptsetup resize $name
}
#======================================
# luksClose
#--------------------------------------
function luksClose {
	# /.../
	# close all open LUKS mappings
	# ----
	local name
	for i in /dev/mapper/luks*;do
		name=$(basename $i)
		cryptsetup luksClose $name
	done
}
#======================================
# selectLanguage
#--------------------------------------
function selectLanguage {
	# /.../
	# select language if not yet done. The value is
	# used for all dialog windows with i18n support
	# ----
	local title="\"Select Language\""
	local list="en_US \"[ English ]\" on"
	local list_orig=$list
	local zh_CN=Chinese
	local zh_TW=Taiwanese
	local ru_RU=Russian
	local de_DE=German
	local ar_AR=Arabic
	local cs_CZ=Czech
	local el_GR=Greek
	local es_ES=Spanish
	local fi_FI=Finnish
	local fr_FR=French
	local hu_HU=Hungarian
	local it_IT=Italian
	local ja_JP=Japanese
	local ko_KR=Korean
	local nl_NL=Dutch
	local pl_PL=Polish
	local pt_BR=Portuguese
	local sv_SE=Swedish
	local tr_TR=Turkish
	local code
	local lang
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	if [ "$DIALOG_LANG" = "ask" ];then
		for code in $(echo $kiwi_language | tr "," " ");do
			if [ $code = "en_US" ];then
				continue
			fi
			eval lang=\$$code
			list="$list $code \"[ $lang ]\" off"
		done
		if [ "$list" = "$list_orig" ];then
			DIALOG_LANG=en_US
		else
			DIALOG_LANG=$(runInteractive \
				"--stdout --no-cancel --radiolist $title 20 40 10 $list"
			)
		fi
	fi
	#======================================
	# Exports (Texts)
	#--------------------------------------
	export TEXT_OK=$(
		getText "OK")
	export TEXT_CANCEL=$(
		getText "Cancel")
	export TEXT_YES=$(
		getText "Yes")
	export TEXT_NO=$(
		getText "No")
	export TEXT_EXIT=$(
		getText "Exit")
	export TEXT_LUKS=$(
		getText "Enter LUKS passphrase")
	export TEXT_LICENSE=$(
		getText "Do you accept the license agreement ?")
	export TEXT_RESTORE=$(
		getText "Do you want to start the System-Restore ?")
	export TEXT_REPAIR=$(
		getText "Do you want to start the System-Recovery ?")
	export TEXT_RECOVERYTITLE=$(
		getText "Restoring base operating system...")
	export TEXT_INSTALLTITLE=$(
		getText "Installation...")
	export TEXT_CDPULL=$(
		getText "Please eject the install CD/DVD before continuing")
	export TEXT_USBPULL=$(
		getText "Please pull out the install USB stick before continuing")	
}
#======================================
# getText
#--------------------------------------
function getText {
	# /.../
	# return translated text
	# ----
	export LANG=$DIALOG_LANG.utf8
	local text=$(gettext kiwi "$1")
	if [ ! -z "$2" ];then
		text=$(echo $text | sed -e s"@%1@$2@")
	fi
	if [ ! -z "$3" ];then
		text=$(echo $text | sed -e s"@%2@$3@")
	fi
	echo "$text"
}
#======================================
# displayEULA
#--------------------------------------
function displayEULA {
	# /.../
	# display in a dialog window the text part of the
	# selected language file or the default file 
	# /license.txt or /EULA.txt
	# ----
	local code=$(echo $DIALOG_LANG | cut -f1 -d_)
	#======================================
	# check license files
	#--------------------------------------
	local files=$(find /license.*.txt 2>/dev/null)
	if [ -z "$files" ];then
		return
	fi
	#======================================
	# use selected file or default
	#--------------------------------------
	code=/license.$code.txt
	if [ ! -f $code ];then
		code=/license.txt
		if [ ! -f $code ];then
			code=/EULA.txt
		fi
	fi
	#======================================
	# check selected file and show it
	#--------------------------------------
	if [ ! -f $code ];then
		Echo "License file $code not found... skipped"
		return
	fi
	while true;do
		Dialog --textbox $code 20 70 \
			--and-widget --extra-button \
			--extra-label "$TEXT_NO" \
			--ok-label "$TEXT_YES" \
			--cancel-label "$TEXT_CANCEL" \
			--yesno "$TEXT_LICENSE" \
			5 45
		case $? in
			0 ) break
				;;
			1 ) continue
				;;
			* ) systemException \
					"License not accepted... reboot" \
				"reboot"
				;;
		esac
	done
}
#======================================
# ddn
#--------------------------------------
function ddn {
	# /.../
	# print disk device name (node name) according to the
	# linux device node specs: If the last character of the
	# device is a letter, attach the partition number. If the
	# last character is a number, attach a 'p' and then the
	# partition number.
	# ----
	local lastc=$(echo $1 | sed -e 's@\(^.*\)\(.$\)@\2@')
	if echo $lastc | grep -qP "^\d+$";then
		echo $1"p"$2
		return
	fi
	echo $1$2
}
#======================================
# dn
#--------------------------------------
function dn {
	# /.../
	# print disk name (device name) according to the
	# linux device node specs: If the last character of the
	# device is a letter remove pX if the last character is
	# a number remove the number
	# ----
	local part=$(getDiskDevice $1)
	local lastc=$(echo $part | sed -e 's@\(^.*\)\(.$\)@\2@')
	if echo $lastc | grep -qP "^\d+$";then
		part=$(echo $part | tr -d [0-9]+)
	else
		part=$(echo $part | sed -e s@p.*@@)
	fi
	echo $part
}
#======================================
# runInteractive
#--------------------------------------
function runInteractive {
	# /.../
	# run shell program in interactive shell and echo the
	# output to the calling terminal. The input file is
	# not allowed to contain a newline at the end of the
	# file. The input file is changed due to that call
	# ----
	local r=/tmp/rid
	echo "dialog $@ > /tmp/out" > $r
	if [ -e /dev/fb0 ];then
		setctsid $ELOG_EXCEPTION fbiterm -m $UFONT -- bash -i $r || return
	else
		setctsid $ELOG_EXCEPTION bash -i $r || return
	fi
	cat /tmp/out && rm -f /tmp/out $r
}
#======================================
# SAPMemCheck
#--------------------------------------
function SAPMemCheck {
	# /.../
	# if OEM SAP option is set this function checks
	# for enough memory to perform a SAP installation
	# ----
	if [ ! -z "$nomemcheck" ];then
		return
	fi
	local mem=`grep -i MemTotal /proc/meminfo | awk '{ print $2 }'`
	if [ "$mem" -lt 1900000 ]; then
		Echo "This installation requires at least 2 GB of RAM"
		Echo -b "but only $(( ${mem} / 1024 )) MB were detected."
		Echo -b "You can override this check by passing"
		Echo -b "'nomemcheck=1' to the kernel commandline."
		systemException \
			"SAPMemCheck failed... reboot" \
		"reboot"
	fi
}
#======================================
# SAPCPUCheck
#--------------------------------------
function SAPCPUCheck {
	# /.../
	# if OEM SAP option is set this function checks
	# for the supported system architecture to perform
	# a SAP installation
	# ----
	if [ ! -z "$nocpucheck" ];then
		return
	fi
	local cpu=`uname -m`
	if [ "$cpu" != "x86_64" ]; then
		Echo "This installation requires a 64Bit CPU (x86_64) but"
		Echo -b "a $cpu CPU was detected. You can override this check"
		Echo -b "by passing 'nocpucheck=1' to the kernel commandline."
		systemException \
			"SAPCPUCheck failed... reboot" \
		"reboot"
	fi
}
#======================================
# SAPCheckStorageSize
#--------------------------------------
function SAPStorageCheck {
	# /.../
	# if OEM SAP option is set this function checks
	# if the available storage space is big enough
	# to perform a SAP installation
	# ----
	if [ ! -z "$nohdcheck" ];then
		return
	fi
	local hwinfo=/usr/sbin/hwinfo
	local ROOT_DEVICE=$1
	local ROOT_EXCLUDE=$2
	if [ ! -n "$ROOT_DEVICE" ];then
		ROOT_DEVICE="."
	fi
	if [ -z "$ROOT_EXCLUDE" ];then
		ROOT_EXCLUDE=$ROOT_DEVICE
	fi
	local size_rootkB=$(partitionSize $ROOT_DEVICE)
	local DATA_DEVICE=""
	local size_datakB=""
	local main_memory_KB=`awk -F" " '{if (match ($1,"^MemTotal")) print $2}' \
		/proc/meminfo`
	local main_memory_MB=$(( ${main_memory_KB} / 1024 ))
	local main_memory_GB=$(( ${main_memory_MB} / 1024 ))
	local MIN_DATA_DEV_SIZE=200 # GB
	local MIN_ROOT_DEV_SIZE=$(( ${main_memory_GB} * 2 + 40 + 3 ))
	local NUM=`$hwinfo --disk | grep -c "Hardware Class:"`
	local req_size_datakB=""
	local req_size_rootkB=""
	local result=0
	#======================================
	# Calculate size requirements
	#--------------------------------------
	if [ "$NUM" != "1" ]; then
		# /.../
		# more than 1 disk, so we expect some more
		# sophisticated setup
		# ----
		req_size_datakB=$(( 1024*1024*${MIN_DATA_DEV_SIZE} ))
		req_size_rootkB=$(( 1024*1024*${MIN_ROOT_DEV_SIZE} ))
	else
		# /.../
		# only 1 disk, which must be large enough for <root>+<data>
		# ----
		req_size_datakB=$((
			1024*1024*${MIN_DATA_DEV_SIZE} + 1024*1024*${MIN_ROOT_DEV_SIZE}
		))
		req_size_rootkB=$req_size_datakB
	fi
	#======================================
	# Search a data disk
	#--------------------------------------
	local deviceDisks=`$hwinfo --disk |\
		grep "Device File:" | cut -f2 -d: |\
		cut -f1 -d"(" | sed -e s"@$ROOT_DEVICE@@" -s s"@$ROOT_EXCLUDE@@"`
	for DATA_DEVICE in $deviceDisks;do
		break
	done
	#======================================
	# Check size
	#--------------------------------------
	if [ $size_rootkB -lt $req_size_rootkB ];then
		result=1
	fi
	if [ ! -z "$DATA_DEVICE" ]; then
		size_datakB=$(partitionSize $DATA_DEVICE)
		if [ $size_datakB -lt $req_size_datakB ];then
			result=2
		fi
	fi
	#======================================
	# Print message on error
	#--------------------------------------
	case $result in
		1 ) Echo "The installation requires at least"
			Echo -b "$(( ${req_size_rootkB} / 1024 / 1024 )) GB disk space"
			Echo -b "for the root partition. You can override this check"
			Echo -b "by passing 'nohdcheck=1' to the kernel commandline."
			systemException \
				"SAPStorageCheck failed... reboot" \
			"reboot"
			;;
		2 ) Echo "The installation requires at least"
			Echo -b "$(( ${req_size_datakB} / 1024 / 1024 )) GB disk space"
			Echo -b "for the data partition (second partition)."
			Echo -b "You can override this check"
			Echo -b "by passing 'nohdcheck=1' to the kernel commandline."
			systemException \
				"SAPStorageCheck failed... reboot" \
			"reboot"
			;;
	esac
}
#======================================
# SAPDataStorageSetup
#--------------------------------------
function SAPDataStorageSetup {
	# /.../
	# if OEM SAP option is set this function searches for
	# a disk which is not the system disk and sets it
	# up as LVM container for later use
	# ----
	local ROOT_DEVICE=$1
	local ROOT_EXCLUDE=$2
	local hwinfo=/usr/sbin/hwinfo
	local input=/tmp/fdisk.input
	local storage
	#======================================
	# Search a data disk
	#--------------------------------------
	if [ ! -n "$ROOT_DEVICE" ];then
		ROOT_DEVICE="."
	fi
	if [ ! -n "$ROOT_EXCLUDE" ];then
		ROOT_EXCLUDE=$ROOT_DEVICE
	fi
	local deviceDisks=`$hwinfo --disk |\
		grep "Device File:" | cut -f2 -d: |\
		cut -f1 -d"(" | sed -e s"@$ROOT_DEVICE@@" -s s"@$ROOT_EXCLUDE@@"`
	for storage in $deviceDisks;do
		break
	done
	if [ -z "$storage" ];then
		Echo "SAPDataStorageSetup: No data disk found... skipped"
		return
	fi
	#======================================
	# Partition the data disk
	#--------------------------------------
	Echo "Setting up $storage as SAP data device..."
	cat > $input < /dev/null
	dd if=/dev/zero of=$storage bs=512 count=1 &>/dev/null
	for cmd in n p 1 . . t 8e w q; do
		if [ $cmd = "." ];then
			echo >> $input
			continue
		fi
		echo $cmd >> $input
	done
	fdisk $storage < $input 1>&2
	if test $? != 0; then
		systemException "Failed to create partition table" "reboot"
	fi
	#======================================
	# Add volume group and filesystem
	#--------------------------------------
	local diskpart=$(ddn $storage 1)
	pvcreate -ff -y $diskpart
	vgcreate data_vg $diskpart
	lvcreate -l 100%FREE -n sapdata data_vg
	mke2fs -F -T ext3 -j /dev/data_vg/sapdata
	if test $? != 0; then
		systemException "Failed to create sapdata volume" "reboot"
	fi
}
#======================================
# SAPStartMediaChanger
#--------------------------------------
function SAPStartMediaChanger {
	local runme=/var/lib/YaST2/runme_at_boot
	local ininf=/etc/install.inf
	startX
	test -e $runme && mv $runme /tmp
	test -e $ininf && mv $ininf /tmp
	yast2 --noborder --fullscreen inst_autosetup   initial
	yast2 --noborder --fullscreen inst_sap_wrapper initial
	stoppX
	test -e /tmp/runme_at_boot && mv /tmp/runme_at_boot $runme
	test -e /tmp/install.inf && mv /tmp/install.inf $ininf
}
#======================================
# createHybridPersistent
#--------------------------------------
function createHybridPersistent {
	local dev=$1;
	local relativeDevName=`basename $dev`
	local input=/part.input
	local id=0
	for disknr in 2 3 4; do
		id=`partitionID $dev $disknr`
		# do we have a linux partition already? Then stop
		if [ "$id" = "$HYBRID_PERSISTENT_ID" ]; then
			Echo "Existing persistent hybrid partition found ${dev}${disknr}"
			return
		fi
		if [ "$id" = "0" ]; then
			Echo -n "Creating hybrid persistent partition for COW data: "
			Echo "$dev$disknr id=$HYBRID_PERSISTENT_ID fs=$HYBRID_PERSISTENT_FS"
			if [ $disknr -lt 4 ];then
				createPartitionerInput \
					n p $disknr . . t $disknr $HYBRID_PERSISTENT_ID w
			else
				createPartitionerInput \
					n p . . t 4 $HYBRID_PERSISTENT_ID w
			fi
			callPartitioner $input
			if ! mkfs.$HYBRID_PERSISTENT_FS $dev$disknr;then
				Echo "Failed to create hybrid persistent filesystem"
				Echo "Persistent writing deactivated"
				unset kiwi_hybridpersistent
			fi
			return
		fi
	done
}
#======================================
# callPartitioner
#--------------------------------------
function callPartitioner {
	local input=$1
	if [ $PARTITIONER = "sfdisk" ];then
		Echo "Repartition the disk according to real geometry [ fdisk ]"
		fdisk $imageDiskDevice < $input 1>&2
		if test $? != 0; then
			systemException "Failed to create partition table" "reboot"
		fi
	else
		# /.../
		# nothing to do for parted here as we write
		# imediately with parted and don't create a
		# command input file as for fdisk but we re-read
		# the disk so that the new table will be used
		# ----
		blockdev --rereadpt $imageDiskDevice
	fi
}
#======================================
# createPartitionerInput
#--------------------------------------
function createPartitionerInput {
	if [ $PARTITIONER = "sfdisk" ];then
		createFDiskInput $@
	else
		Echo "Repartition the disk according to real geometry [ parted ]"
		partedInit $imageDiskDevice
		createPartedInput $imageDiskDevice $@
    fi
}
#======================================
# createFDiskInput
#--------------------------------------
function createFDiskInput {
	local input=/part.input
	rm -f $input
	for cmd in $*;do
		if [ $cmd = "." ];then
			echo >> $input
			continue
		fi
		echo $cmd >> $input
	done
}
#======================================
# partedInit
#--------------------------------------
function partedInit {
	# /.../
	# initialize current partition table output
	# as well as the number of cylinders and the
	# cyliner size in kB for this disk
	# ----
	local device=$1
	local IFS=""
	local parted=$(parted -m $device unit cyl print)
	local header=$(echo $parted | head -n 3 | tail -n 1)
	local ccount=$(echo $header | cut -f1 -d:)
	local cksize=$(echo $header | cut -f4 -d: | cut -f1 -dk)
	export partedOutput=$parted
	export partedCylCount=$ccount
	export partedCylKSize=$cksize
}
#======================================
# partedWrite
#--------------------------------------
function partedWrite {
	# /.../
	# call parted with current command queue.
	# This will immediately change the partition table
	# ----
	local device=$1
	local cmds=$2
	if ! parted -m $device unit cyl $cmds;then
		systemException "Failed to create partition table" "reboot"
	fi
	partedInit $device
}
#======================================
# partedStartCylinder
#--------------------------------------
function partedStartCylinder {
	# /.../
	# return start cylinder of given partition.
	# lowest cylinder number is 0
	# ----
	local part=$(($1 + 3))
	local IFS=""
	local header=$(echo $partedOutput | head -n $part | tail -n 1)
	local ccount=$(echo $header | cut -f2 -d: | tr -d cyl)
	echo $ccount
}
#======================================
# partedEndCylinder
#--------------------------------------
function partedEndCylinder {
	# /.../
	# return end cylinder of given partition, next
	# partition must start at return value plus 1
	# ----
	local part=$(($1 + 3))
	local IFS=""
	local header=$(echo $partedOutput | head -n $part | tail -n 1)
	local ccount=$(echo $header | cut -f3 -d: | tr -d cyl)
	echo $ccount
}
#======================================
# partedMBToCylinder
#--------------------------------------
function partedMBToCylinder {
	# /.../
	# convert size given in MB to cylinder count
	# ----
	local sizeKB=$(($1 * 1024))
	local cylreq=$(($sizeKB / $partedCylKSize))
	echo $cylreq
}
#======================================
# createPartedInput
#--------------------------------------
function createPartedInput {
	# /.../
	# evaluate partition instructions and turn them
	# into a parted command line queue. As soon as the
	# geometry data would be changed according to the
	# last partedInit() call the command queue is processed
	# and the partedInit() will be called afterwards
	# ----
	local disk=$1
	shift
	local index=0
	local pcmds
	local partid
	local pstart
	local pstopp
	local value
	local cmdq
	#======================================
	# create list of commands
	#--------------------------------------
	for cmd in $*;do
		pcmds[$index]=$cmd
		index=$(($index + 1))
	done
	index=0
	#======================================
	# process commands
	#--------------------------------------
	for cmd in ${pcmds[*]};do
		case $cmd in
			#======================================
			# delete partition
			#--------------------------------------
			"d")
				partid=${pcmds[$index + 1]}
				partid=$(($partid / 1))
				if [ $partid -eq 0 ];then
					partid=1
				fi
				cmdq="$cmdq rm $partid"
				;;
			#======================================
			# create new partition
			#--------------------------------------
			"n")
				partid=${pcmds[$index + 2]}
				partid=$(($partid / 1))
				if [ $partid -eq 0 ];then
					partid=1
				fi
				pstart=${pcmds[$index + 3]}
				if [ "$pstart" = "1" ];then
					pstart=0
				fi
				if [ $pstart = "." ];then
					# start is next cylinder according to previous partition
					pstart=$(($partid - 1))
					if [ $pstart -gt 0 ];then
						pstart=$(partedEndCylinder $pstart)
						pstart=$(($pstart + 1))
					fi
				fi
				pstopp=${pcmds[$index + 4]}
				if [ $pstopp = "." ];then
					# use rest of the disk for partition end
					pstopp=$partedCylCount
				elif echo $pstopp | grep -qi M;then
					# calculate stopp cylinder from size
					pstopp=$(($partid - 1))
					if [ $pstopp -gt 0 ];then
						pstopp=$(partedEndCylinder $pstopp)
					fi
					value=$(echo ${pcmds[$index + 4]} | cut -f1 -dM | tr -d +)
					value=$(partedMBToCylinder $value)
					pstopp=$((1 + $pstopp + $value))
				fi
				cmdq="$cmdq mkpart primary $pstart $pstopp"
				partedWrite "$disk" "$cmdq"
				cmdq=""
				;;
			#======================================
			# change partition ID
			#--------------------------------------
			"t")
				ptypex=${pcmds[$index + 2]}
				partid=${pcmds[$index + 1]}
				cmdq="$cmdq set $partid type 0x$ptypex"
				partedWrite "$disk" "$cmdq"
				cmdq=""
				;;
		esac
		index=$(($index + 1))
	done
}

#======================================
# reloadKernel
#--------------------------------------
function reloadKernel {
	# /.../
	# reload the given kernel and initrd. This function
	# checks USB stick devices for a kernel and initrd
	# and shows them in a dialog window. The selected kernel
	# and initrd is loaded via kexec.
	# ----
	#======================================
	# check proc/cmdline
	#--------------------------------------
	ldconfig
	mountSystemFilesystems &>/dev/null
	if ! cat /proc/cmdline | grep -qi "hotfix=1";then
		umountSystemFilesystems
		return
	fi
	#======================================
	# check for kexec
	#--------------------------------------
	if [ ! -x /sbin/kexec ];then
		systemException "Can't find kexec" "reboot"
	fi
	#======================================
	# start udev
	#--------------------------------------
	touch /etc/modules.conf
	touch /lib/modules/*/modules.dep
	udevStart
	errorLogStart
	probeDevices
	#======================================
	# search hotfix stick
	#--------------------------------------
	USBStickDevice kexec
	if [ $stickFound = 0 ];then
		systemException "No hotfix USB stick found" "reboot"
	fi
	#======================================
	# mount stick
	#--------------------------------------
	if ! mount -o ro $stickDevice /mnt;then
		systemException "Failed to mount hotfix stick" "reboot"
	fi
	#======================================
	# load kernel
	#--------------------------------------
	kexec -l /mnt/linux.kexec --initrd=/mnt/initrd.kexec \
		--append="$(cat /proc/cmdline | sed -e s"@hotfix=1@@")"
	if [ ! $? = 0 ];then
		systemException "Failed to load hotfix kernel" "reboot"
	fi
	#======================================
	# go for gold
	#--------------------------------------
	exec kexec -e
}

#======================================
# Check for hotfix kernel
#--------------------------------------
reloadKernel

# vim: set noexpandtab:
