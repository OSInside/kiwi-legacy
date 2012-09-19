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
export BOOTABLE_FLAG="$(echo -ne '\x80')"
export ELOG_FILE=/var/log/boot.kiwi
export TRANSFER_ERRORS_FILE=/tmp/transfer.errors
export UFONT=/usr/share/fbiterm/fonts/b16.pcf.gz
export HYBRID_PERSISTENT_FS=ext3
export HYBRID_PERSISTENT_ID=83
export HYBRID_PERSISTENT_PART=4
export HYBRID_PERSISTENT_DIR=/read-write
export UTIMER_INFO=/dev/utimer
export bootLoaderOK=0

#======================================
# Exports (General)
#--------------------------------------
test -z "$haveDASD"           && export haveDASD=0
test -z "$haveZFCP"           && export haveZFCP=0
test -z "$ELOG_CONSOLE"       && export ELOG_CONSOLE=/dev/tty3
test -z "$ELOG_BOOTSHELL"     && export ELOG_BOOTSHELL=/dev/tty2
test -z "$ELOG_EXCEPTION"     && export ELOG_EXCEPTION=/dev/tty1
test -z "$KLOG_CONSOLE"       && export KLOG_CONSOLE=4
test -z "$KLOG_DEFAULT"       && export KLOG_DEFAULT=1
test -z "$ELOG_STOPPED"       && export ELOG_STOPPED=0
test -z "$PARTITIONER"        && export PARTITIONER=parted
test -z "$DEFAULT_VGA"        && export DEFAULT_VGA=0x314
test -z "$HAVE_MODULES_ORDER" && export HAVE_MODULES_ORDER=1
test -z "$DIALOG_LANG"        && export DIALOG_LANG=ask
test -z "$TERM"               && export TERM=linux
test -z "$LANG"               && export LANG=en_US.utf8
test -z "$UTIMER"             && export UTIMER=0
test -z "$VGROUP"             && export VGROUP=kiwiVG
test -z "$PARTED_HAVE_ALIGN"  && export PARTED_HAVE_ALIGN=0
test -z "$PARTED_HAVE_MACHINE"&& export PARTED_HAVE_MACHINE=0
test -z "$DHCPCD_HAVE_PERSIST"&& export DHCPCD_HAVE_PERSIST=1
if [ -x /sbin/blogd ];then
	test -z "$CONSOLE"            && export CONSOLE=/dev/console
	test -z "$REDIRECT"           && export REDIRECT=/dev/tty1
fi
if [ -e /usr/sbin/parted ];then
	if parted -h | grep -q '\-\-align';then
		export PARTED_HAVE_ALIGN=1
	fi
	if parted -h | grep -q '\-\-machine';then
		export PARTED_HAVE_MACHINE=1
	fi
	if [ $PARTED_HAVE_MACHINE -eq 0 ];then
		export PARTITIONER=unsupported
	fi
fi
if dhcpcd -p 2>&1 | grep -q 'Usage';then
	export DHCPCD_HAVE_PERSIST=0
fi
#======================================
# Exports (arch specific)
#--------------------------------------
arch=`uname -m`
if [ "$arch" = "ppc64" ];then
	loader=lilo
	export ELOG_BOOTSHELL=/dev/hvc0
fi
if [[ $arch =~ s390 ]];then
	loader=zipl
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
		local prefix=$(cat $UTIMER_INFO)
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
	if [ -x /usr/sbin/klogconsole ];then
		klogconsole -l 1
	fi
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
	if [ ! -x /usr/sbin/klogconsole ];then
		return
	fi
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
	if [ ! -x /usr/sbin/klogconsole ];then
		return
	fi
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
	local prefix=$1
	cat - | grep -v ^# > /tmp/srcme
	# remove start/stop quoting from values
	sed -i -e s"#\(^[a-zA-Z0-9_]\+\)=[\"']\(.*\)[\"']#\1=\2#" /tmp/srcme
	# remove backslash quotes if any
	sed -i -e s"#\\\\\(.\)#\1#g" /tmp/srcme
	# quote simple quotation marks
	sed -i -e s"#'#'\\\\''#g" /tmp/srcme
	# add '...' quoting to values
	sed -i -e s"#\(^[a-zA-Z0-9_]\+\)=\(.*\)#$prefix\1='\2'#" /tmp/srcme
	source /tmp/srcme
	while read line;do
		key=$(echo "$line" | cut -d '=' -f1)
		eval "export $key"
	done < /tmp/srcme
	if [ ! -z "$ERROR_INTERRUPT" ];then
		Echo -e "$ERROR_INTERRUPT"
		systemException "*** interrupted ****" "shell"
	fi
}
#======================================
# unsetFile
#--------------------------------------
function unsetFile {
	# /.../
	# unset variables specified within the given file.
	# the file must be in the config.<MAC> style format
	# ----
	IFS="
	"
	local prefix=$1 #change name of key with a prefix
	while read line;do
		echo $line | grep -qi "^#" && continue
		key=`echo "$line" | cut -d '=' -f1`
		if [ -z "$key" ];then
			continue
		fi
		Debug "unset $prefix$key"
		eval unset "$prefix$key"
	done
	IFS=$IFS_ORIG
}
#======================================
# condenseConfigData
#--------------------------------------
function condenseConfigData {
	# /.../
	# if multiple same config files (config files with same deployment path)
	# are present on the CONF line,
	# only last one will be kept (this preserves compatibility)
	# ----
	IFS=","
	local conf=( $1 )
	local cconf
	local sep=''
	for (( i=0; i<${#conf[@]}; i++ ));do
		local configDest=`echo "${conf[$i]}" | cut -d ';' -f 2`
		if test ! -z $configDest;then
			local copythis=1
			for (( j=i+1; j<${#conf[@]}; j++ ));do
				local cmpconfigDest=`echo "${conf[$j]}" | cut -d ';' -f 2`
				if [ "$cmpconfigDest" = "$configDest" ];then
					copythis=0
					break
				fi
			done
			[ $copythis -eq '1' ] && cconf="${cconf}${sep}${conf[$i]}"
			sep=$IFS
		fi
	done
	IFS=$IFS_ORIG
	echo "$cconf"
}
#======================================
# systemException
#--------------------------------------
function systemException {
	# /.../
	# print a message to the controling terminal followed
	# by an action. Possible actions are reboot, wait, shutdown,
	# and opening a shell
	# ----
	set +x
	local what=$2
	local nuldev=/dev/null
	local ttydev=$ELOG_EXCEPTION
	if [ ! -e $nuldev ];then
		nuldev=/mnt/$nuldev
	fi
	if [ ! -e $ttydev ];then
		ttydev=/mnt/$ttydev
	fi
	test -e /proc/splash && echo verbose > /proc/splash
	if [ $what = "reboot" ];then
		if cat /proc/cmdline 2>/dev/null | grep -qi "kiwidebug=1";then
			what="shell"
		fi
	fi
	runHook preException "$@"
	Echo "$1"
	case "$what" in
	"reboot")
		Echo "rebootException: error consoles at Alt-F3/F4"
		Echo "rebootException: reboot in 120 sec..."; sleep 120
		/sbin/reboot -f -i >$nuldev
	;;
	"wait")
		Echo "waitException: waiting for ever..."
		while true;do sleep 100;done
	;;
	"shell")
		Echo "shellException: providing shell..."
		if ! setctsid $ttydev /bin/true;then
			/bin/bash -i
		else
			setctsid $ttydev /bin/bash -i
		fi
	;;
	"user_reboot")
		Echo "reboot triggered by user: consoles at Alt-F3/F4"
		Echo "reboot in 30 sec..."; sleep 30
		/sbin/reboot -f -i >$nuldev
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
		#======================================
		# Header for main stage log
		#--------------------------------------
		echo "KIWI Log:" >> $ELOG_FILE
	else
		#======================================
		# Header for pre-init stage log
		#--------------------------------------
		startUtimer
		echo "KIWI PreInit Log" >> $ELOG_FILE
		cat /iprocs | grep -v TAIL_PID > /iprocs
	fi
	echo "Boot-Logging enabled on $ELOG_CONSOLE"
	setctsid -f $ELOG_CONSOLE tail -f $ELOG_FILE &
	exec 2>>$ELOG_FILE
	if [ -f .profile ];then
		echo "KIWI .profile contents:" 1>&2
		cat .profile 1>&2
	fi
	set -x 1>&2
	local DTYPE=`stat -f -c "%T" /proc 2>/dev/null`
	if test "$DTYPE" != "proc" ; then
		mount -t proc proc /proc
	fi
	TAIL_PID=$(fuser $ELOG_CONSOLE | tr -d " ")
	echo TAIL_PID=$TAIL_PID >> /iprocs
}
#======================================
# udevPending
#--------------------------------------
function udevPending {
	local timeout=30
	if [ -x /sbin/udevadm ];then
		/sbin/udevadm settle --timeout=$timeout
	else
		/sbin/udevsettle --timeout=$timeout
	fi
}
#======================================
# udevTrigger
#--------------------------------------
function udevTrigger {
	if [ -x /sbin/udevadm ];then
		/sbin/udevadm trigger
	else
		/sbin/udevtrigger
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
# udevSystemStop
#--------------------------------------
function udevSystemStop {
	# /.../
	# stop udev while in pre-init phase.
	# ----
	/etc/init.d/boot.udev stop
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
	# load modules required before udev
	moduleLoadBeforeUdev
	# start the udev daemon
	/sbin/udevd --daemon
	UDEVD_PID=$(pidof /sbin/udevd)
	echo UDEVD_PID=$UDEVD_PID >> /iprocs
	# trigger events for all devices
	udevTrigger
	# wait for events to finish
	udevPending
	# start splashy if configured
	startSplashy
}
#======================================
# moduleLoadBeforeUdev
#--------------------------------------
function moduleLoadBeforeUdev {
	# /.../
	# load modules which have to be loaded before the
	# udev daemon is started in this function
	# ----
	loadAGPModules
}
#======================================
# loadAGPModules
#--------------------------------------
function loadAGPModules {
	# remove kms udev rule, see bnc #659843 for details
	rm -f /lib/udev/rules.d/79-kms.rules
	# load agp modules manually (not by udev) 
	local krunning=$(uname -r)
	for i in /lib/modules/$krunning/kernel/drivers/char/agp/*; do
		test -e $i || continue
		modprobe $(echo $i | sed "s#.*\\/\\([^\\/]\\+\\).ko#\\1#")
	done
}
#======================================
# udevKill
#--------------------------------------
function udevKill {
	. /iprocs ; kill $UDEVD_PID
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
	if test -n "$REDIRECT" ; then
		mkdir -p /var/log
		> /dev/shm/initrd.msg
		ln -sf /dev/shm/initrd.msg /var/log/boot.msg
		mkdir -p /var/run
		startproc /sbin/blogd $REDIRECT
		BLOGD_PID=$(pidof /sbin/blogd)
		echo BLOGD_PID=$BLOGD_PID >> /iprocs
	fi
}
#======================================
# killBlogD
#--------------------------------------
function killBlogD {
	# /.../
	# kill blogd on /dev/console
	# ----
	if test -n "$REDIRECT" ; then
		local umountProc=0
		if [ ! -e /proc/mounts ];then
			mount -t proc proc /proc
			umountProc=1
		fi
		Echo "Stopping boot logging"
		. /iprocs ; kill $BLOGD_PID
		if [ $umountProc -eq 1 ];then
			umount /proc
		fi
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
	resetBootBind
	local arch=`uname -m`
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)       installBootLoaderGrub ;;
		x86_64-grub)     installBootLoaderGrub ;;
		ppc*)            installBootLoaderLilo ;;
		i*86-syslinux)   installBootLoaderSyslinux ;;
		x86_64-syslinux) installBootLoaderSyslinux ;;
		i*86-extlinux)   installBootLoaderSyslinux ;;
		x86_64-extlinux) installBootLoaderSyslinux ;;
		s390-zipl)       installBootLoaderS390 ;;
		s390x-zipl)      installBootLoaderS390 ;;
		*)
		systemException \
			"*** boot loader install for $arch-$loader not implemented ***" \
		"reboot"
	esac
	if [ ! -z "$masterBootID" ];then
		Echo "writing MBR ID back to master boot record: $masterBootID"
		masterBootIDHex=$(echo $masterBootID |\
			sed 's/^0x\(..\)\(..\)\(..\)\(..\)$/\\x\4\\x\3\\x\2\\x\1/')
		echo -e -n $masterBootIDHex | dd of=$imageDiskDevice \
			bs=1 count=4 seek=$((0x1b8))
	fi
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
		i*86-grub)       installBootLoaderGrubRecovery ;;
		x86_64-grub)     installBootLoaderGrubRecovery ;;
		i*86-syslinux)   installBootLoaderSyslinuxRecovery ;;
		x86_64-syslinux) installBootLoaderSyslinuxRecovery ;;
		i*86-extlinux)   installBootLoaderSyslinuxRecovery ;;
		x86_64-extlinux) installBootLoaderSyslinuxRecovery ;;
		s390-zipl)       installBootLoaderS390Recovery ;;
		s390x-zipl)      installBootLoaderS390Recovery ;;
		*)
		systemException \
			"*** boot loader setup for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# installBootLoaderS390
#--------------------------------------
function installBootLoaderS390 {
	if [ -x /sbin/zipl ];then
		Echo "Installing boot loader..."
		zipl -c /etc/zipl.conf 1>&2
		if [ ! $? = 0 ];then
			Echo "Failed to install boot loader"
		fi
	else
		Echo "Image doesn't have zipl installed"
		Echo "Can't install boot loader"
	fi
}
#======================================
# installBootLoaderSyslinux
#--------------------------------------
function installBootLoaderSyslinux {
	local syslmbr=/usr/share/syslinux/mbr.bin
	if [ -e $syslmbr ];then
		Echo "Installing boot loader..."
		if [ $loader = "syslinux" ];then
			syslinux $imageBootDevice
		else
			extlinux --install /boot/syslinux
		fi
		dd if=$syslmbr of=$imageDiskDevice bs=512 count=1 conv=notrunc
	else
		Echo "Image doesn't have syslinux (mbr.bin) installed"
		Echo "Can't install boot loader"
	fi
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
# installBootLoaderS390Recovery
#--------------------------------------
function installBootLoaderS390Recovery {
	systemException \
		"*** zipl: recovery boot not implemented ***" \
	"reboot"
}
#======================================
# installBootLoaderSyslinuxRecovery
#--------------------------------------
function installBootLoaderSyslinuxRecovery {
	local syslmbr=/usr/share/syslinux/mbr.bin
	if [ -e $syslmbr ];then
		if [ $loader = "syslinux" ];then
			syslinux $imageRecoveryDevice
		else
			extlinux --install /reco-save/boot/syslinux
		fi
	else
		Echo "Image doesn't have syslinux (mbr.bin) installed"
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
	if [ -x /usr/sbin/grub ];then
		/usr/sbin/grub --batch < $input 1>&2
		rm -f $input
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
	local haveVMX=0
	local params
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
		if grep -qi param_B /sbin/mkinitrd;then
			params="-B"
		fi
		if [ $bootLoaderOK = "1" ];then
			if [ -f /boot/initrd.vmx ];then
				rm -f /boot/initrd.vmx
				rm -f /boot/linux.vmx
				haveVMX=1
			fi
		fi
		if ! mkinitrd $params;then
			Echo "Can't create initrd"
			systemIntegrity=unknown
			bootLoaderOK=0
		fi
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
		# quote simple quotation marks
		arg=$(echo $1 | sed -e s"#'#'\\\\''#g")
		para="$para '$arg'"
		shift
	done
	if [ ! -z "$kiwi_bootloader" ];then
		loader=$kiwi_bootloader
	fi
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)       eval setupBootLoaderGrub $para ;;
		x86_64-grub)     eval setupBootLoaderGrub $para ;;
		i*86-syslinux)   eval setupBootLoaderSyslinux $para ;;
		x86_64-syslinux) eval setupBootLoaderSyslinux $para ;;
		i*86-extlinux)   eval setupBootLoaderSyslinux $para ;;
		x86_64-extlinux) eval setupBootLoaderSyslinux $para ;;
		s390-zipl)       eval setupBootLoaderS390 $para ;;
		s390x-zipl)      eval setupBootLoaderS390 $para ;;
		ppc*)            eval setupBootLoaderLilo $para ;;
		*)
		systemException \
			"*** boot loader setup for $arch-$loader not implemented ***" \
		"reboot"
	esac
	setupBootLoaderTheme "/config"
}
#======================================
# setupBootLoaderTheme
#--------------------------------------
function setupBootLoaderTheme {
	local destprefix=$1
	local srcprefix=$2
	if [ -z "$srcprefix" ];then
		srcprefix=/mnt
	fi
	#======================================
	# no boot theme set, return
	#--------------------------------------
	if [ -z "$kiwi_boottheme" ];then
		return
	fi
	#======================================
	# prepare paths
	#--------------------------------------
	local sysimg_bootsplash=$srcprefix/etc/sysconfig/bootsplash
	local sysbootsplash=$destprefix/etc/sysconfig/bootsplash
	mkdir -p $destprefix/etc/sysconfig
	touch $sysbootsplash
	#======================================
	# check for bootsplash config in sysimg
	#--------------------------------------
	if [ -f $sysimg_bootsplash ];then
		cp $sysimg_bootsplash $sysbootsplash
	fi
	#======================================
	# change/create bootsplash config
	#--------------------------------------
	if cat $sysbootsplash | grep -q -E "^THEME"; then
		sed -i "s/^THEME=.*/THEME=\"$kiwi_boottheme\"/" $sysbootsplash
	else
		echo "THEME=\"$kiwi_boottheme\"" >> $sysbootsplash
	fi
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
		# quote simple quotation marks
		arg=$(echo $1 | sed -e s"#'#'\\\\''#g")
		para="$para '$arg'"
		shift
	done
	if [ -z "$loader" ];then
		loader="grub"
	fi
	case $arch-$loader in
		i*86-grub)       eval setupBootLoaderGrubRecovery $para ;;
		x86_64-grub)     eval setupBootLoaderGrubRecovery $para ;;
		i*86-syslinux)   eval setupBootLoaderSyslinuxRecovery $para ;;
		x86_64-syslinux) eval setupBootLoaderSyslinuxRecovery $para ;;
		i*86-extlinux)   eval setupBootLoaderSyslinuxRecovery $para ;;
		x86_64-extlinux) eval setupBootLoaderSyslinuxRecovery $para ;;
		s390-zipl)       eval setupBootLoaderS390Recovery $para ;;
		s390x-zipl)      eval setupBootLoaderS390Recovery $para ;;
		*)
		systemException \
			"*** boot loader setup for $arch-$loader not implemented ***" \
		"reboot"
	esac
}
#======================================
# setupBootLoaderS390Recovery
#--------------------------------------
function setupBootLoaderS390Recovery {
	systemException \
		"*** zipl: recovery boot not implemented ***" \
	"reboot"
}
#======================================
# setupBootLoaderSyslinuxRecovery
#--------------------------------------
function setupBootLoaderSyslinuxRecovery {
	# /.../
	# create syslinux configuration for the recovery boot system
	# ----
	local mountPrefix=$1  # mount path of the image
	local destsPrefix=$2  # base dir for the config files
	local gnum=$3         # boot partition ID
	local rdev=$4         # root partition
	local gfix=$5         # syslinux title postfix
	local swap=$6         # optional swap partition
	local conf=$destsPrefix/boot/syslinux/syslinux.cfg
	local kernel=""
	local initrd=""
	local fbmode=$vga
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	#======================================
	# import syslinux into recovery
	#--------------------------------------
	cp -a $mountPrefix/boot/syslinux $destsPrefix/boot
	#======================================
	# setup config file name
	#--------------------------------------
	if [ $loader = "extlinux" ];then
		conf=$destsPrefix/boot/syslinux/extlinux.conf
	fi
	#======================================
	# create syslinux.cfg file
	#--------------------------------------
	echo "implicit 1"                   > $conf
	echo "prompt   1"                  >> $conf
	echo "TIMEOUT $KIWI_BOOT_TIMEOUT"  >> $conf
	echo "display isolinux.msg"        >> $conf
	if [ -f "$mountPrefix/boot/syslinux/bootlogo" ];then
		if \
			[ -f "$mountPrefix/boot/syslinux/gfxboot.com" ] || \
			[ -f "$mountPrefix/boot/syslinux/gfxboot.c32" ]
		then
			echo "ui gfxboot bootlogo isolinux.msg" >> $conf
		else
			echo "gfxboot bootlogo"                 >> $conf
		fi
	fi
	kernel=linux.vmx   # this is a copy of the kiwi linux.vmx file
	initrd=initrd.vmx  # this is a copy of the kiwi initrd.vmx file
	#======================================
	# create recovery entry
	#--------------------------------------
	if [ ! -z "$OEM_RECOVERY" ];then
		#======================================
		# Reboot
		#--------------------------------------
		title=$(makeLabel "Cancel/Reboot")
		echo "DEFAULT $title"                              >> $conf
		echo "label $title"                                >> $conf
		echo " localboot 0x80"                             >> $conf
		#======================================
		# Recovery
		#--------------------------------------
		title=$(makeLabel "Recover/Repair System")
		echo "label $title"                                >> $conf
		if xenServer $kernel $mountPrefix;then
			systemException \
				"*** $loader: Xen dom0 boot not implemented ***" \
			"reboot"
		else
			echo "kernel /boot/$kernel"                    >> $conf
			echo -n "append initrd=/boot/$initrd"          >> $conf
			echo -n " root=$diskByID"                      >> $conf
			if [ ! -z "$imageDiskDevice" ];then
				echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
			fi
			echo -n " vga=$fbmode loader=$loader"          >> $conf
			echo -n " splash=silent"                       >> $conf
			echo -n " $KIWI_INITRD_PARAMS"                 >> $conf
			echo -n " $KIWI_KERNEL_OPTIONS"                >> $conf
			if [ "$haveLVM" = "yes" ];then
				echo -n " VGROUP=$VGROUP"                  >> $conf
			fi
			echo " KIWI_RECOVERY=$recoid"                  >> $conf
			echo " showopts"                               >> $conf
		fi
		#======================================
		# Restore
		#--------------------------------------
		title=$(makeLabel "Restore Factory System")
		echo "label $title"                                >> $conf
		if xenServer $kernel $mountPrefix;then
			systemException \
				"*** $loader: Xen dom0 boot not implemented ***" \
			"reboot"
		else
			echo "kernel /boot/$kernel"                    >> $conf
			echo -n "append initrd=/boot/$initrd"          >> $conf
			echo -n " root=$diskByID"                      >> $conf
			if [ ! -z "$imageDiskDevice" ];then
				echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
			fi
			echo -n " vga=$fbmode loader=$loader"          >> $conf
			echo -n " splash=silent"                       >> $conf
			echo -n " $KIWI_INITRD_PARAMS"                 >> $conf
			echo -n " $KIWI_KERNEL_OPTIONS"                >> $conf
			if [ "$haveLVM" = "yes" ];then
				echo -n " VGROUP=$VGROUP"                  >> $conf
			fi
			echo " KIWI_RECOVERY=$recoid RESTORE=1"        >> $conf
			echo " showopts"                               >> $conf
		fi
	fi
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
	mkdir -p $destsPrefix/boot/grub
	cp $mountPrefix/boot/grub/stage1 $destsPrefix/boot/grub
	cp $mountPrefix/boot/grub/stage2 $destsPrefix/boot/grub
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
		echo "default 0"                                  >> $menu
		#======================================
		# Reboot
		#--------------------------------------
		title=$(makeLabel "Cancel/Reboot")
		echo "title $title"                               >> $menu
		echo " reboot"                                    >> $menu
		#======================================
		# Recovery
		#--------------------------------------
		title=$(makeLabel "Recover/Repair System")
		echo "title $title"                               >> $menu
		if xenServer $kernel $mountPrefix;then
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
		if xenServer $kernel $mountPrefix;then
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
	fi
}
#======================================
# setupBootLoaderS390
#--------------------------------------
function setupBootLoaderS390 {
	# /.../
	# create /etc/zipl.conf used for the
	# zipl bootloader
	# ----
	local mountPrefix=$1  # mount path of the image
	local destsPrefix=$2  # base dir for the config files
	local znum=$3         # boot partition ID
	local rdev=$4         # root partition
	local zfix=$5         # zipl title postfix
	local swap=$6         # optional swap partition
	local conf=$destsPrefix/etc/zipl.conf
	local sysb=$destsPrefix/etc/sysconfig/bootloader
	local kname=""
	local kernel=""
	local initrd=""
	local title=""
	#======================================
	# check for device by ID
	#--------------------------------------
	local diskByID=`getDiskID $rdev`
	local swapByID=`getDiskID $swap swap`
	#======================================
	# check for boot image .profile
	#--------------------------------------
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for bootloader displayname
	#--------------------------------------
	if [ -z "$kiwi_oemtitle" ] && [ ! -z "$kiwi_displayname" ];then
		kiwi_oemtitle=$kiwi_displayname
	fi
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for kernel options
	#--------------------------------------
	if [ ! -z "$kiwi_cmdline" ];then
		KIWI_KERNEL_OPTIONS="$KIWI_KERNEL_OPTIONS $kiwi_cmdline"
	fi
	#======================================
	# check for syslinux title postfix
	#--------------------------------------
	if [ -z "$zfix" ];then
		zfix="unknown"
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
	# create zipl.conf file
	#--------------------------------------
	local count
	local title_default
	local title_failsafe
	echo "[defaultboot]"                      > $conf
	echo "defaultmenu = menu"                >> $conf
	echo ":menu"                             >> $conf
	echo "    default = 1"                   >> $conf
	echo "    prompt = 1"                    >> $conf
	echo "    target = /boot/zipl"           >> $conf
	echo "    timeout = $KIWI_BOOT_TIMEOUT"  >> $conf
	count=1
	IFS="," ; for i in $KERNEL_LIST;do
		if test -z "$i";then
			continue
		fi
		kname=${KERNEL_NAME[$count]}
		if ! echo $zfix | grep -E -q "OEM|USB|VMX|NET|unknown";then
			if [ "$count" = "1" ];then
				title_default=$(makeLabel "$zfix")
			else
				title_default=$(makeLabel "$kname ( $zfix )")
			fi
		elif [ -z "$kiwi_oemtitle" ];then
			title_default=$(makeLabel "$kname ( $zfix )")
		else
			if [ "$count" = "1" ];then
				title_default=$(makeLabel "$kiwi_oemtitle ( $zfix )")
			else
				title_default=$(makeLabel "$kiwi_oemtitle-$kname ( $zfix )")
			fi
		fi
		title_failsafe=$(makeLabel "Failsafe -- $title_default")
		echo "    $count = $title_default"  >> $conf
		count=`expr $count + 1`
		echo "    $count = $title_failsafe" >> $conf
		count=`expr $count + 1`
	done
	count=1
	IFS="," ; for i in $KERNEL_LIST;do
		if test -z "$i";then
			continue
		fi
		kernel=`echo $i | cut -f1 -d:`
		initrd=`echo $i | cut -f2 -d:`
		kname=${KERNEL_NAME[$count]}
		if ! echo $zfix | grep -E -q "OEM|USB|VMX|NET|unknown";then
			if [ "$count" = "1" ];then
				title_default=$(makeLabel "$zfix")
			else
				title_default=$(makeLabel "$kname ( $zfix )")
			fi
		elif [ -z "$kiwi_oemtitle" ];then
			title_default=$(makeLabel "$kname ( $zfix )")
		else
			if [ "$count" = "1" ];then
				title_default=$(makeLabel "$kiwi_oemtitle ( $zfix )")
			else
				title_default=$(makeLabel "$kiwi_oemtitle-$kname ( $zfix )")
			fi
		fi
		title_failsafe=$(makeLabel "Failsafe -- $title_default")
		#======================================
		# create standard entry
		#--------------------------------------
		echo "[$title_default]"                  >> $conf
		echo "target  = /boot/zipl"              >> $conf
		echo "image   = /boot/$kernel"           >> $conf
		echo "ramdisk = /boot/$initrd,0x2000000" >> $conf
		echo -n "parameters = \"root=$diskByID"  >> $conf
		if [ ! -z "$imageDiskDevice" ];then
			echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
		fi
		if [ ! -z "$swap" ];then
			echo -n " resume=$swapByID" >> $conf
		fi
		if [ "$haveLVM" = "yes" ];then
			echo -n " VGROUP=$VGROUP" >> $conf
		fi
		echo -n " $KIWI_INITRD_PARAMS"  >> $conf
		echo -n " $KIWI_KERNEL_OPTIONS" >> $conf
		echo " loader=$loader\""        >> $conf
		#======================================
		# create failsafe entry
		#--------------------------------------
		echo "[$title_failsafe]"                 >> $conf
		echo "target  = /boot/zipl"              >> $conf
		echo "image   = /boot/$kernel"           >> $conf
		echo "ramdisk = /boot/$initrd,0x2000000" >> $conf
		echo -n "parameters = \"root=$diskByID"  >> $conf
		if [ ! -z "$imageDiskDevice" ];then
			echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
		fi
		if [ "$haveLVM" = "yes" ];then
			echo -n " VGROUP=$VGROUP" >> $conf
		fi
		echo -n " $KIWI_INITRD_PARAMS"       >> $conf
		echo -n " $KIWI_KERNEL_OPTIONS"      >> $conf
		echo " loader=$loader x11failsafe\"" >> $conf
		count=`expr $count + 1`
	done
	#======================================
	# create recovery entry
	#--------------------------------------
	if [ ! -z "$OEM_RECOVERY" ];then
		systemException \
			"*** zipl: recovery chain loading not implemented ***" \
		"reboot"
	fi
	#======================================
	# create sysconfig/bootloader
	#--------------------------------------
	echo "LOADER_TYPE=\"$loader\""                            > $sysb
	echo "LOADER_LOCATION=\"mbr\""                           >> $sysb
	echo -n "DEFAULT_APPEND=\"root=$diskByID splash=silent"  >> $sysb
	if [ ! -z "$swap" ];then
		echo -n " resume=$swapByID"                          >> $sysb
	fi
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo " showopts\""                                       >> $sysb
	echo -n "FAILSAFE_APPEND=\"root=$diskByID"               >> $sysb
	echo -n " $KIWI_INITRD_PARAMS $KIWI_KERNEL_OPTIONS"      >> $sysb
	echo -n " x11failsafe noresume\""                        >> $sysb
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
	if [ ! -z "$OEM_RECOVERY" ];then
		local gdevreco=$recoid
	fi
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	#======================================
	# check for device by ID
	#--------------------------------------
	local diskByID=`getDiskID $rdev`
	local swapByID=`getDiskID $swap swap`
	#======================================
	# check for boot image .profile
	#--------------------------------------
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for bootloader displayname
	#--------------------------------------
	if [ -z "$kiwi_oemtitle" ] && [ ! -z "$kiwi_displayname" ];then
		kiwi_oemtitle=$kiwi_displayname
	fi
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for kernel options
	#--------------------------------------
	if [ ! -z "$kiwi_cmdline" ];then
		KIWI_KERNEL_OPTIONS="$KIWI_KERNEL_OPTIONS $kiwi_cmdline"
	fi
	#======================================
	# setup config file name
	#--------------------------------------
	if [ $loader = "extlinux" ];then
		conf=$destsPrefix/boot/syslinux/extlinux.conf
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
	echo "implicit 1"                   > $conf
	echo "prompt   1"                  >> $conf
	echo "TIMEOUT $KIWI_BOOT_TIMEOUT"  >> $conf
	echo "display isolinux.msg"        >> $conf
	if [ -f "$mountPrefix/boot/syslinux/bootlogo" ];then
		if \
			[ -f "$mountPrefix/boot/syslinux/gfxboot.com" ] || \
			[ -f "$mountPrefix/boot/syslinux/gfxboot.c32" ]
		then
			echo "ui gfxboot bootlogo isolinux.msg" >> $conf
		else
			echo "gfxboot bootlogo"                 >> $conf
		fi
	fi
	local count=1
	IFS="," ; for i in $KERNEL_LIST;do
		if test ! -z "$i";then
			#======================================
			# setup syslinux requirements
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
			echo "DEFAULT $title"                              >> $conf
			echo "label $title"                                >> $conf
			if xenServer $kname $mountPrefix;then
				systemException \
					"*** $loader: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "kernel /boot/$kernel"                    >> $conf
				echo -n "append initrd=/boot/$initrd"          >> $conf
				echo -n " root=$diskByID $console"             >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
				fi
				echo -n " vga=$fbmode loader=$loader"          >> $conf
				echo -n " splash=silent"                       >> $conf
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"                >> $conf
				fi
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"         >> $conf
				elif [ -e /dev/hvc0 ];then
					echo -n " console=hvc console=tty"         >> $conf
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
			echo "label $title"                                >> $conf
			if xenServer $kname $mountPrefix;then
				systemException \
					"*** $loader: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "kernel /boot/$kernel"                    >> $conf
				echo -n "append initrd=/boot/$initrd"          >> $conf
				echo -n " root=$diskByID $console"             >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)"  >> $conf
				fi
				echo -n " vga=$fbmode loader=$loader"          >> $conf
				echo -n " splash=silent"                       >> $conf
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"                >> $conf
				fi
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"         >> $conf
				elif [ -e /dev/hvc0 ];then
					echo -n " console=hvc console=tty"         >> $conf
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
		echo "label Recovery"                             >> $conf
		echo "kernel chain"                               >> $conf
		echo "append hd0 $gdevreco"                       >> $conf
	fi
	#======================================
	# create sysconfig/bootloader
	#--------------------------------------
	echo "LOADER_TYPE=\"$loader\""                           > $sysb
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
	local swapByID=`getDiskID $swap swap`
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
	# check for bootloader displayname
	#--------------------------------------
	if [ -z "$kiwi_oemtitle" ] && [ ! -z "$kiwi_displayname" ];then
		kiwi_oemtitle=$kiwi_displayname
	fi
	#======================================
	# check for kernel options
	#--------------------------------------
	if [ ! -z "$kiwi_cmdline" ];then
		KIWI_KERNEL_OPTIONS="$KIWI_KERNEL_OPTIONS $kiwi_cmdline"
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
			if xenServer $kname $mountPrefix;then
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
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"            >> $menu
				elif [ -e /dev/hvc0 ];then
					echo -n " console=hvc console=tty"            >> $menu
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
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"            >> $menu
				elif [ -e /dev/hvc0 ];then
					echo -n " console=hvc console=tty"            >> $menu
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
			if xenServer $kname $mountPrefix;then
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
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"            >> $menu
				elif [ -e /dev/hvc0 ];then
					echo -n " console=hvc console=tty"            >> $menu
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
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"            >> $menu
				elif [ -e /dev/hvc0 ];then
					echo -n " console=hvc console=tty"            >> $menu
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
	if [ -z "$fbmode" ];then
		fbmode=$DEFAULT_VGA
	fi
	#======================================
	# check for device by ID
	#--------------------------------------
	local diskByID=`getDiskID $rdev`
	local swapByID=`getDiskID $swap swap`
	#======================================
	# check for boot image .profile
	#--------------------------------------
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	#======================================
	# check for bootloader displayname
	#--------------------------------------
	if [ -z "$kiwi_oemtitle" ] && [ ! -z "$kiwi_displayname" ];then
		kiwi_oemtitle=$kiwi_displayname
	fi
	#======================================
	# check for system image .profile
	#--------------------------------------
	if [ -f $mountPrefix/image/.profile ];then
		importFile < $mountPrefix/image/.profile
	fi
	#======================================
	# check for kernel options
	#--------------------------------------
	if [ ! -z "$kiwi_cmdline" ];then
		KIWI_KERNEL_OPTIONS="$KIWI_KERNEL_OPTIONS $kiwi_cmdline"
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
			if xenServer $kname $mountPrefix;then
				systemException \
					"*** lilo: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "default=\"$title\""		      >> $conf
				echo "image=/boot/$kernel"                    >> $conf
				echo "label=\"$title\""                       >> $conf
				echo "initrd=/boot/$initrd"                   >> $conf
				echo -n "append=\"quiet sysrq=1 panic=9"      >> $conf
				echo -n " root=$diskByID"                     >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)" >> $conf
				fi
				if [ ! "$arch" = "ppc64" ];then
				echo -n " $console vga=$fbmode splash=silent" >> $conf
				fi
				if [ ! -z "$swap" ];then                     
					echo -n " resume=$swapByID"               >> $conf
				fi
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"        >> $conf
				elif [ -e /dev/hvc0 ];then
					if [ "$arch" = "ppc64" ];then
					echo -n " console=hvc0"        >> $conf
					else
					echo -n " console=hvc0 console=tty"        >> $conf
					fi
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
			if xenServer $kname $mountPrefix;then
				systemException \
					"*** lilo: Xen dom0 boot not implemented ***" \
				"reboot"
			else
				echo "image=/boot/$kernel"                    >> $conf
				echo "label=\"$title\""                       >> $conf
				echo "initrd=/boot/$initrd"                   >> $conf
				echo -n "append=\"quiet sysrq=1 panic=9"      >> $conf
				echo -n " root=$diskByID"                     >> $conf
				if [ ! -z "$imageDiskDevice" ];then
					echo -n " disk=$(getDiskID $imageDiskDevice)" >> $conf
				fi
				if [ ! "$arch" = "ppc64" ];then
				echo -n " $console vga=$fbmode splash=silent" >> $conf
				fi
				if [ ! -z "$swap" ];then
					echo -n " resume=$swapByID"               >> $conf
				fi
				if [ -e /dev/xvc0 ];then
					echo -n " console=xvc console=tty"        >> $conf
				elif [ -e /dev/hvc0 ];then
					if [ "$arch" = "ppc64" ];then
					echo -n " console=hvc0"        >> $conf
					else
					echo -n " console=hvc0 console=tty"        >> $conf
					fi
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
	if [ -z "$PXE_IFACE" ];then
		return
	fi
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
	echo "devpts  /dev/pts          devpts  mode=0620,gid=5 0 0"  >> $nfstab
	echo "proc    /proc             proc    defaults        0 0"  >> $nfstab
	echo "sysfs   /sys              sysfs   noauto          0 0"  >> $nfstab
	echo "debugfs /sys/kernel/debug debugfs noauto          0 0"  >> $nfstab
	echo "usbfs   /proc/bus/usb     usbfs   noauto          0 0"  >> $nfstab
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
		echo "$diskByID / $FSTYPE defaults 1 1" >> $nfstab
	else
		echo "/dev/root / defaults 1 1" >> $nfstab
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
				echo "/dev/$VGROUP/LV$volume /$mpoint $FSTYPE defaults 1 1" \
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
	echo "$diskByID swap swap defaults 0 0" >> $nfstab
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
	if [ -z "$FSTYPE" ] || [ "$FSTYPE" = "unknown" ];then
		FSTYPE="auto"
	fi
	echo "$diskByID $mount $FSTYPE defaults 1 2" >> $nfstab
	echo "$mount/boot /boot none bind 0 0" >> $nfstab
	if [ ! -z "$FSTYPE_SAVE" ];then
		FSTYPE=$FSTYPE_SAVE
	fi
}
#======================================
# updateClicBootDeviceFstab
#--------------------------------------
function updateClicBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/clicboot"
}
#======================================
# updateLuksBootDeviceFstab
#--------------------------------------
function updateLuksBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/luksboot"
}
#======================================
# updateBtrBootDeviceFstab
#--------------------------------------
function updateBtrBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/btrboot"
}
#======================================
# updateXfsBootDeviceFstab
#--------------------------------------
function updateXfsBootDeviceFstab {
	updateLVMBootDeviceFstab $1 $2 "/xfsboot"
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
	if [ $loader = "syslinux" ];then
		echo "$diskByID /syslboot vfat defaults 1 2" >> $nfstab
	else
		echo "$diskByID /syslboot ext2 defaults 1 2" >> $nfstab
	fi
	echo "/syslboot/boot /boot none bind 0 0" >> $nfstab
}
#======================================
# updateOtherDeviceFstab
#--------------------------------------
function updateOtherDeviceFstab {
	# /.../
	# check the contents of the $PART variable and
	# add one line to the fstab file for each partition
	# which has a mount point defined.
	# ----
	local prefix=$1
	local sysroot=$2
	local nfstab=$prefix/etc/fstab
	local index=0
	local field=0
	local count=0
	local device
	local IFS=","
	if [ -z "$sysroot" ];then
		sysroot=/mnt
	fi
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		if \
			[ ! -z "$partMount" ]       && \
			[ ! "$partMount" = "x" ]    && \
			[ ! "$partMount" = "swap" ] && \
			[ ! "$partMount" = "/" ]
		then
			if [ ! -z "$RAID" ];then
				device=/dev/md$((count - 1))
			else
				device=$(ddn $DISK $count)
			fi
			probeFileSystem $device
			if [ ! "$FSTYPE" = "luks" ] && [ ! "$FSTYPE" = "unknown" ];then
				if [ ! -d $sysroot/$partMount ];then
					mkdir -p $sysroot/$partMount
				fi
				echo "$device $partMount $FSTYPE defaults 0 0" >> $nfstab
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
	local sysimg_ktempl=$srcprefix/var/adm/fillup-templates/sysconfig.kernel
	local sysimg_ktempl2=$sysimg_ktempl-mkinitrd
	local sysimg_syskernel=$srcprefix/etc/sysconfig/kernel
	local syskernel=$destprefix/etc/sysconfig/kernel
	local newstyle_mkinitrd=$srcprefix/lib/mkinitrd/scripts/boot-usb.sh
	local key
	local val
	mkdir -p $destprefix/etc/sysconfig
	#======================================
	# check for sysconfig template file
	#--------------------------------------
	if [ ! -f $sysimg_ktempl ] && [ ! -f $sysimg_ktempl2 ];then
		systemException \
			"Can't find kernel sysconfig template in system image !" \
		"reboot"
	fi
	#======================================
	# check for mkinitrd capabilities
	#--------------------------------------
	if [ ! -e $newstyle_mkinitrd ];then
		# /.../
		# if boot-usb.sh does not exist we are based on an old
		# mkinitrd version which requires all modules as part of
		# sysconfig/kernel. Therefore we include all USB modules
		# required to support USB storage like USB sticks
		# ----
		local USB_MODULES="ehci-hcd ohci-hcd uhci-hcd usbcore usb-storage sd"
		INITRD_MODULES="$INITRD_MODULES $USB_MODULES"
		# /.../
		# old mkinitrd cannot figure this out on its own
		# ---
		if [ -e /sys/devices/virtio-pci ];then
			Echo 'Adding virtio kernel modules to initrd.'
			INITRD_MODULES="$INITRD_MODULES virtio-blk virtio-pci"
		fi
	fi
	#======================================
	# use system image config or template
	#--------------------------------------
	if [ -f $sysimg_syskernel ];then
		cp $sysimg_syskernel $syskernel
	else
		cp $sysimg_ktempl $syskernel
	fi
	#======================================
	# update config file
	#--------------------------------------
	for key in INITRD_MODULES DOMU_INITRD_MODULES;do
		if [ $key = "INITRD_MODULES" ];then
			val=$INITRD_MODULES
		fi
		if [ $key = "DOMU_INITRD_MODULES" ];then
			val=$DOMURD_MODULES
		fi
		if [ -z "$val" ];then
			continue
		fi
		sed -i -e \
			s"@^$key=\"\(.*\)\"@$key=\"\1 $val\"@" \
		$syskernel
	done
}
#======================================
# getKernelBootParameters
#--------------------------------------
function getKernelBootParameters {
	# /.../
	# check contents of bootloader configuration
	# and extract cmdline parameters
	# ----
	local prefix=$1
	local params
	local files="
		$prefix/boot/syslinux/syslinux.cfg
		$prefix/boot/syslinux/extlinux.conf
		$prefix/boot/grub/menu.lst
		$prefix/etc/lilo.conf
		$prefix/etc/zipl.conf
	"
	for c in $files;do
		if [ -f $c ];then
			params=$(cat $c | grep 'root=' | head -n1)
			break
		fi
	done
	params=$(echo $params | sed -e 's@^append=@@')
	params=$(echo $params | sed -e 's@^append@@')
	params=$(echo $params | sed -e 's@^module@@')
	params=$(echo $params | sed -e 's@^kernel@@')
	params=$(echo $params | sed -e 's@^parameters=@@')
	params=$(echo $params | sed -e 's@"@@g')
	params=$(echo $params)
	echo $params
}
#======================================
# kernelCheck
#--------------------------------------
function kernelCheck {
	# /.../
	# Check the running kernel against the kernel
	# installed in the image. If the version does not 
	# match we need to reboot to activate the system
	# image kernel. This is done by either using kexec
	# or a real reboot is triggered
	# ----
	local kactive=`uname -r`
	local kreboot=1
	local prefix=$1
	local kernel
	local initrd
	local params
	#======================================
	# check installed and running kernel
	#--------------------------------------
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
	#======================================
	# check for forced reboot
	#--------------------------------------
	if [ ! -z "$FORCE_KEXEC" ];then
		kreboot=2
	fi
	#======================================
	# evaluate kreboot condition
	#--------------------------------------
	case $kreboot in
		1) Echo "Kernel versions do not match..." ;;
		2) Echo "kexec based reboot forced..." ;;
		0) return ;;
	esac
	#======================================
	# trigger reboot if kexec doesn't exist
	#--------------------------------------
	if [ ! -f /sbin/kexec ];then
		Echo "Reboot triggered in 5 sec..."
		sleep 5 ; /sbin/reboot -f -i
	fi
	#======================================
	# trigger reboot using kexec
	#--------------------------------------
	if [ -f /sbin/kexec ];then
		#======================================
		# find installed kernel / initrd
		#--------------------------------------
		if [ -z "$KERNEL_LIST" ] ; then
			kernelList $prefix
		fi
		IFS="," ; for i in $KERNEL_LIST;do
			if test -z "$i";then
				continue
			fi
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			break
		done
		if [ ! -f $prefix/boot/$kernel ] || [ ! -f $prefix/boot/$initrd ];then
			Echo "Can't find $kernel / $initrd in system image"
			Echo "Reboot triggered in 5 sec..."
			sleep 5 ; /sbin/reboot -f -i
		fi
		#======================================
		# extract bootloader cmdline params
		#--------------------------------------
		params=$(getKernelBootParameters $prefix)
		#======================================
		# load and run kernel...
		#--------------------------------------
		kexec -l $prefix/boot/$kernel \
			--append="$params" --initrd=$prefix/boot/$initrd
		if [ ! $? = 0 ];then
			Echo "Failed to load kernel"
			Echo "Reboot triggered in 5 sec..."
			sleep 5 ; /sbin/reboot -f -i
		fi
		#======================================
		# go for gold
		#--------------------------------------
		exec kexec -e
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
		btrfs)       FSTYPE=btrfs ;;
		ext4)        FSTYPE=ext4 ;;
		ext3)        FSTYPE=ext3 ;;
		ext2)        FSTYPE=ext2 ;;
		reiserfs)    FSTYPE=reiserfs ;;
		squashfs)    FSTYPE=squashfs ;;
		luks)        FSTYPE=luks ;;
		crypto_LUKS) FSTYPE=luks ;;
		vfat)        FSTYPE=vfat ;;
		clicfs)      FSTYPE=clicfs ;;
		xfs)         FSTYPE=xfs ;;
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
		if grep -q ^hsqs /tmp/filesystem-$$;then
			FSTYPE=squashfs
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
	udevPending
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
	if [ -e /sys/bus/usb/devices ];then
		stdevs=$(ls -1 /sys/bus/usb/devices/ | wc -l)
		if [ $stdevs -gt 0 ];then
			export HAVE_USB="yes"
		fi
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
	for i in rd brd edd dm-mod xennet xenblk virtio_blk;do
		modprobe $i &>/dev/null
	done
	udevPending
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
		udevPending
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
	local id=$(blkid -o value -s TYPE $1)
	if [ "$id" = "iso9660" ];then
		echo "-t iso9660"
	fi
}
#======================================
# IsBootable
#--------------------------------------
function IsBootable {
	# /.../
	# params: device, partitionNumber
	# checks whether a partition is marked as bootable or not
	# ----
	local offset
	let offset="446 + 16 * (${2} - 1)"
	local flag=$(dd "if=${1}" bs=1 count=1 skip=${offset} 2>/dev/null)
	test "$flag" = "${BOOTABLE_FLAG}"
}
#======================================
# GetBootable
#--------------------------------------
function GetBootable {
	# /.../
	# params: device
	# print the number of the first bootable partition on the
	# given block device. If no partition is flagged as bootable,
	# it prints 1.
	# ----
	local partition
	for (( partition = 1; partition <= 4; partition++ ));do
		if IsBootable "${1}" "${partition}";then
			echo "${partition}"
			return
		fi
	done
	# No bootable partition found, select the first one
	echo "1"
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
		if [ "$kiwi_hybridpersistent" = "yes" ];then
			protectedDevice=$(echo $biosBootDevice | sed -e s@/dev/@@)
			protectedDisk=$(cat /sys/block/$protectedDevice/ro)
			if [ $protectedDisk = "0" ];then
				createHybridPersistent $biosBootDevice
			fi
		fi
		cddev=$(ddn "${biosBootDevice}" "$(GetBootable "${biosBootDevice}")")
		Echo -n "Mounting hybrid live boot drive ${cddev}..."
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
			export HYBRID_RW=$(ddn $biosBootDevice $HYBRID_PERSISTENT_PART)
			#======================================
			# LIVECD_CONFIG found go with it
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
# searchOFBootDevice
#--------------------------------------
function searchOFBootDevice {
	# /.../
	# search for the device with the OF PROM id
	# this is required for the ppc boot architecture
	# as we don't have a BIOS and a MBR here
	# ----
	IFS=$IFS_ORIG
	local h=/usr/sbin/hwinfo
	local c="Device File:|PROM id"
	local ddevs=`$h --disk|grep -E "$c"|sed -e"s@(.*)@@"|cut -f2 -d:|tr -d " "`
	#======================================
	# Store device with PROM id 
	#--------------------------------------
	for curd in $ddevs;do
		if [ $curd = "/dev/sda" ];then
			export biosBootDevice=$curd
			return 0
		fi
	done
	export biosBootDevice="Can't find OF boot device"
	return 1
}
#======================================
# searchBusIDBootDevice
#--------------------------------------
function searchBusIDBootDevice {
	# /.../
	# if searchBIOSBootDevice did not return a result this
	# function is called to check for a DASD or ZFCP device
	# like they exist on the s390 architecture. If found the
	# device is set online and the biosBootDevice variable
	# is set to this device for further processing
	# ----
	local deviceID=0
	local dpath=/dev/disk/by-path
	local ipl_type=$(cat /sys/firmware/ipl/ipl_type)
	local wwpn
	local slun
	#======================================
	# check for custom device init command
	#--------------------------------------
	if [ ! -z "$DEVICE_INIT" ];then
		if ! eval $DEVICE_INIT;then
			export biosBootDevice="Failed to call: $DEVICE_INIT"
			return 1
		fi
		export biosBootDevice=$DISK
		return 0
	fi
	#======================================
	# determine device type: dasd or zfcp
	#--------------------------------------
	if [ -z "$ipl_type" ];then
		systemException \
			"Can't find IPL type" \
		"reboot"
	fi
	if [ "$ipl_type" = "fcp" ];then
		haveZFCP=1
	elif [ "$ipl_type" = "ccw" ];then
		haveDASD=1
	else
		systemException \
			"Unknown IPL type: $ipl_type" \
		"reboot"
	fi
	#======================================
	# store device bus / host id
	#--------------------------------------
	deviceID=$(cat /sys/firmware/ipl/device)
	#======================================
	# check if we can find the device
	#--------------------------------------
	if [ ! -e /sys/bus/ccw/devices/$deviceID ];then
		systemException \
			"Can't find disk with ID: $deviceID" \
		"reboot"
	fi
	#======================================
	# DASD
	#--------------------------------------
	if [ $haveDASD -eq 1 ];then
		dasd_configure $deviceID 1 0
		biosBootDevice="$dpath/ccw-$deviceID"
	fi
	#======================================
	# ZFCP
	#--------------------------------------
	if [ $haveZFCP -eq 1 ];then
		wwpn=$(cat /sys/firmware/ipl/wwpn)
		slun=$(cat /sys/firmware/ipl/lun)
		zfcp_host_configure $deviceID 1
		zfcp_disk_configure $deviceID $wwpn $slun 1
		biosBootDevice="$dpath/ccw-$deviceID-zfcp-$wwpn:$slun"
	fi
	#======================================
	# setup boot device variable
	#--------------------------------------
	waitForStorageDevice $biosBootDevice
	if [ ! -e $biosBootDevice ];then
		export biosBootDevice="Failed to set disk $deviceID online"
		return 1
	fi
	export biosBootDevice=$(getDiskDevice $biosBootDevice)
	return 0
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
	local fst
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
			fst=$(blkid $dev -s TYPE -o value)
			if [ -z "$fst" ];then
				continue
			fi
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
		mbrML=`dd if=$curd bs=1 count=4 skip=$((0x1b8))|hexdump -n4 -e '"0x%08x"'`
		mbrMB=`echo $mbrML | sed 's/^0x\(..\)\(..\)\(..\)\(..\)$/0x\4\3\2\1/'`
		if [ "$mbrML" = "$mbrI" ] || [ "$mbrMB" = "$mbrI" ];then
			ifix=1
			matched=$curd
			if [ "$mbrML" = "$mbrI" ];then
				export masterBootID=$mbrML
			fi
			if [ "$mbrMB" = "$mbrI" ];then
				export masterBootID=$mbrMB
			fi
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
	if [ ! "$kiwi_lvm" = "true" ];then
		return 1
	fi
	Echo "Activating $VGROUP volume group..."
	vgchange -a y $VGROUP
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
# updateMTAB
#--------------------------------------
function updateMTAB {
	prefix=$1
	umount=0
	if [ ! -e /proc/mounts ];then
		mount -t proc proc /proc
		umount=1
	fi
	if [ -e /proc/self/mounts ];then
		pushd $prefix/etc
		rm -f mtab && ln -s /proc/self/mounts mtab
		popd
	fi
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
# loadNetworkCard
#--------------------------------------
function loadNetworkCard {
	# /.../
	# load network module found by probeNetworkCard()
	# ----
	local loaded=0
	probeNetworkCard
	IFS=":" ; for i in $networkModule;do
		if [ ! -z "$i" ];then
			modprobe $i 2>/dev/null
			if [ $? = 0 ];then
				loaded=1
			fi
		fi
	done
	IFS=$IFS_ORIG
	if [ $loaded = 0 ];then
		systemException \
			"Network module: Failed to load network module !" \
		"reboot"
	fi
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
	#======================================
	# local variable setup
	#--------------------------------------
	local IFS="
	"
	local MAC=0
	local DEV=0
	local mac_list=0
	local dev_list=0
	local index=0
	local hwicmd=/usr/sbin/hwinfo
	local prefer_iface=eth0
	local opts="--noipv4ll -p"
	local try_iface
	#======================================
	# global variable setup
	#--------------------------------------
	export DHCPCD_STARTED
	#======================================
	# detect network card(s)
	#--------------------------------------
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
		# the first interface that responds to dhcp
		# ----
		prefer_iface=${dev_list[*]}
	else
		# /.../
		# evaluate the information from the PXE boot interface
		# if we found the MAC in the list the appropriate interface
		# name is assigned.
		# ----
		index=0
		BOOTIF=`echo $BOOTIF | cut -f2- -d - | tr "-" ":"`
		for i in ${mac_list[*]};do
			if [ $i = $BOOTIF ];then
				prefer_iface=${dev_list[$index]}
			fi
			index=`expr $index + 1`
		done
	fi
	if [ $DHCPCD_HAVE_PERSIST -eq 0 ];then
		# /.../
		# older version of dhcpd which doesn't have the
		# options we want to pass
		# ----
		unset opts
	fi
	mkdir -p /var/lib/dhcpcd
	for try_iface in ${dev_list[*]}; do
		# try DHCP_DISCOVER on all interfaces
		dhcpcd $opts -T $try_iface > /var/lib/dhcpcd/dhcpcd-$try_iface.info &
		DHCPCD_STARTED="$DHCPCD_STARTED $try_iface"
	done
	if [ -z "$DHCPCD_STARTED" ];then
		if [ -e "$root" ];then
			Echo "Failed to setup DHCP network interface !"
			Echo "Try fallback to local boot on: $root"
			LOCAL_BOOT=yes
			return
		else
			systemException \
				"Failed to setup DHCP network interface !" \
			"reboot"
		fi
	fi
	#======================================
	# wait for any preferred interface(s)
	#--------------------------------------
	for j in 1 2 ;do
		for i in 1 2 3 4 5 6 7 8 9 10 11;do
			for try_iface in $prefer_iface ; do
				if [ -s /var/lib/dhcpcd/dhcpcd-$try_iface.info ] &&
					grep -q "^IPADDR=" /var/lib/dhcpcd/dhcpcd-$try_iface.info
				then
					break 3
				fi
			done
			sleep 2
		done
		# /.../
		# we are behind the dhcpcd timeout 20s so the only thing
		# we can do now is to try again
		# ----
		for try_iface in $DHCPCD_STARTED; do
			dhcpcd $opts -T $try_iface \
				> /var/lib/dhcpcd/dhcpcd-$try_iface.info &
		done
		sleep 2
	done
	#======================================
	# select interface from preferred list
	#--------------------------------------
	for try_iface in $prefer_iface $DHCPCD_STARTED; do
		if [ -s /var/lib/dhcpcd/dhcpcd-$try_iface.info ] &&
			grep -q "^IPADDR=" /var/lib/dhcpcd/dhcpcd-$try_iface.info
		then
			export PXE_IFACE=$try_iface
			eval `grep "^IPADDR=" /var/lib/dhcpcd/dhcpcd-$try_iface.info`
			rm /var/lib/dhcpcd/dhcpcd-$try_iface.info
			# continue with the DHCP protocol on the selected interface
			dhcpcd $opts -r $IPADDR $PXE_IFACE 2>&1
			break
		fi
	done
	#======================================
	# fallback to local boot if possible
	#--------------------------------------
	if [ -z "$PXE_IFACE" ];then
		if [ -e "$root" ];then
			Echo "Can't get DHCP reply on any interface !"
			Echo "Try fallback to local boot on: $root"
			LOCAL_BOOT=yes
			return
		else
			systemException \
				"Can't get DHCP reply on any interface !" \
			"reboot"
		fi
	fi
	#======================================
	# wait for iface to finish negotiation
	#--------------------------------------
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20;do
		if [ -s /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info ] &&
			grep -q "^IPADDR=" /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info
		then
			break
		fi
		sleep 2
	done
	#======================================
	# setup selected interface
	#--------------------------------------
	ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
	if [ -s /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info ] &&
		grep -q "^IPADDR=" /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info; then
		importFile < /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info
	fi
	if [ -z "$IPADDR" ];then
		if [ -e "$root" ];then
			Echo "Can't assign IP addr via dhcp info: dhcpcd-$PXE_IFACE.info !"
			Echo "Try fallback to local boot on: $root"
			LOCAL_BOOT=yes
			return
		else
			systemException \
				"Can't assign IP addr via dhcp info: dhcpcd-$PXE_IFACE.info !" \
				"reboot"
		fi
	fi
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
# releaseNetwork
#--------------------------------------
function releaseNetwork {
	# /.../
	# release network setup by dhcpcd and free the lease
	# Do that only for _non_ network root devices
	# ----
	if [ -z "$NFSROOT" ] && [ -z "$NBDROOT" ] && [ -z "$AOEROOT" ];then
		#======================================
		# unset dhcp info variables
		#--------------------------------------
		unsetFile < /var/lib/dhcpcd/dhcpcd-$PXE_IFACE.info
		#======================================
		# free the lease and the cache
		#--------------------------------------
		dhcpcd -k $PXE_IFACE
		#======================================
		# remove sysconfig state information
		#--------------------------------------
		rm -rf /dev/.sysconfig/network
	fi
}
#======================================
# setupNetworkInterfaceS390
#--------------------------------------
function setupNetworkInterfaceS390 {
	# /.../
	# bring up the network card according to the parm file
	# parameters and create the correspondent udev rules
	# needs includeKernelParametersLowerCase to be run
	# because parm file parameters are case insensitive
	# ----
	case "$instnetdev" in
		"osa"|"hsi")
			local qeth_cmd="/sbin/qeth_configure"
			if [ "$layer2" = "1" ];then
				qeth_cmd="$qeth_cmd -l"
			fi
			if [ -n "$portname" ];then
				qeth_cmd="$qeth_cmd -p $portname"
			fi
			if [ -n "$portno" ];then
				qeth_cmd="$qeth_cmd -n $portno"
			fi
			qeth_cmd="$qeth_cmd $readchannel $writechannel"
			if [ -n "$datachannel" ];then
				qeth_cmd="$qeth_cmd $datachannel"
			fi
			eval $qeth_cmd 1
			;;
		"ctc")
			/sbin/ctc_configure $readchannel $writechannel 1 $ctcprotocol
			;;
		"iucv")
			/sbin/iucv_configure $iucvpeer 1
			;;
		*)
			systemException \
				"Unknown s390 network type: $instnetdev" "reboot"
			;;
	esac
	if [ ! $? = 0 ];then
		systemException \
			"Failed to bring up the network: $instnetdev" \
		"reboot"
	fi
	udevPending
}
#======================================
# convertCIDRToNetmask
#--------------------------------------
function convertCIDRToNetmask {
	# /.../
	# convert the CIDR part to a useable netmask
	# ----
	local cidr=$1
	local count=0
	for count in `seq 1 4`;do
		if [ $((cidr / 8)) -gt 0 ];then
			echo -n 255
		else
			local remainder=$((cidr % 8))
			if [ $remainder -gt 0 ];then
				echo -n $(( value = 256 - (256 >> remainder)))
			else
				echo -n 0
			fi
		fi
		cidr=$((cidr - 8))
		if [ $count -lt 4 ];then
			echo -n .
		fi
	done
	echo
}
#======================================
# setupNetworkStatic
#--------------------------------------
function setupNetworkStatic {
	# /.../
	# configure static network either bring it up manually
	# or save the configuration depending on 'up' parameter
	# ----
	local up=$1
	if [[ $hostip =~ / ]];then
		#======================================
		# interpret the CIDR part and remove it from the hostip
		#--------------------------------------
		local cidr=$(echo $hostip | cut -f2 -d/)
		hostip=$(echo $hostip | cut -f1 -d/)
		netmask=$(convertCIDRToNetmask $cidr)
	fi
	if [ "$up" = "1" ];then
		#======================================
		# activate network
		#--------------------------------------
		local iface=`cat /proc/net/dev|tail -n1|cut -d':' -f1|sed 's/ //g'`
		local ifconfig_cmd="/sbin/ifconfig $iface $hostip netmask $netmask"
		if [ -n "$broadcast" ];then
			ifconfig_cmd="$ifconfig_cmd broadcast $broadcast"
		fi
		if [ -n "$pointopoint" ];then
			ifconfig_cmd="$ifconfig_cmd pointopoint $pointopoint"
		fi
		if [ -n "$osahwaddr" ];then
			ifconfig_cmd="$ifconfig_cmd hw ether $osahwaddr"
		fi
		$ifconfig_cmd up
		if [ ! $? = 0 ];then
			systemException "Failed to set up the network: $iface" "reboot"
		fi
		export iface_static=$iface
	elif [ ! -z $iface_static ];then
		#======================================
		# write network setup
		#--------------------------------------
		local netFile="/etc/sysconfig/network/ifcfg-$iface_static"
		echo "BOOTPROTO='static'" > $netFile
		echo "STARTMODE='auto'" >> $netFile
		echo "IPADDR='$hostip'" >> $netFile
		echo "NETMASK='$netmask'" >> $netFile
		if [ -n "$broadcast" ];then
			echo "BROADCAST='$broadcast'" >> $netFile
		fi
		if [ -n "$pointopoint" ];then
			echo "REMOTE_IPADDR='$pointopoint'" >> $netFile
		fi
	fi
	setupDefaultGateway $up
	setupDNS
}
#======================================
# setupDefaultGateway
#--------------------------------------
function setupDefaultGateway {
	# /.../
	# setup default gateway. either set the route or save
	# the configuration depending on 'up' parameter
	# ----
	local up=$1
	if [ "$up" == "1" ];then
		#======================================
		# activate GW route
		#--------------------------------------
		route add default gw $gateway
	else
		#======================================
		# write GW configuration
		#--------------------------------------
		echo "default  $gateway - -" > "/etc/sysconfig/network/routes"
	fi
}
#======================================
# setupDNS
#--------------------------------------
function setupDNS {
	# /.../
	# setup DNS. write data to resolv.conf
	# ----
	if [ -n "$domain" ];then
		export DOMAIN=$domain
		echo "search $domain" >> /etc/resolv.conf
	fi
	if [ -n "$nameserver" ];then
		export DNS=$nameserver
		IFS="," ; for i in $nameserver;do
			echo "nameserver $i" >> /etc/resolv.conf
		done
	fi
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
# fdasdGetPartitionID
#--------------------------------------
function fdasdGetPartitionID {
	local count=1
	for i in $(fdasd -s -p $1 | grep -E '^[ ]+\/' |\
		awk -v OFS=":" '$1=$1' | cut -f5 -d:);do
		if [ $count = $2 ];then
			if $i = 2;then
				echo 82
			elif $i = 1;then
				echo 83
			else
				echo $i
			fi
			return
		fi
		count=$((count + 1))
	done
}
#======================================
# partedGetPartitionID
#--------------------------------------
function partedGetPartitionID {
	# /.../
	# prints the partition ID for the given device and number
	# ----
	parted -m -s $1 print | grep ^$2: | cut -f2 -d= |\
		sed -e 's@[,; ]@@g' | tr -d 0
}
#======================================
# partitionID
#--------------------------------------
function partitionID {
	local diskDevice=$1
	local diskNumber=$2
	if [ $PARTITIONER = "fdasd" ];then
		fdasdGetPartitionID $diskDevice $diskNumber
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
		echo 1 ; return 1
	fi
	expr $(blockdev --getsize64 $diskDevice) / 1024
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
	local kcount=1
	local kname=""
	local kernel=""
	local initrd=""
	local kpair=""
	local krunning=`uname -r`
	KERNEL_LIST=""
	KERNEL_NAME=""
	KERNEL_PAIR=""
	#======================================
	# search running kernel first
	#--------------------------------------
	if [ -d $prefix/lib/modules/$krunning ];then
		for name in vmlinux vmlinuz image;do
			if [ -f $prefix/boot/$name-$krunning ];then
				kernel=$name-$krunning
				initrd=initrd-$krunning
				break
			fi
		done
		if [ ! -z "$kernel" ];then
			KERNEL_PAIR=$kernel:$initrd
			KERNEL_NAME[$kcount]=$krunning
			KERNEL_LIST=$KERNEL_PAIR
			kcount=$((kcount+1))
		fi
	fi
	#======================================
	# search for other kernels
	#--------------------------------------
	for i in $prefix/lib/modules/*;do
		if [ ! -d $i ];then
			continue
		fi
		unset kernel
		unset initrd
		kname=`basename $i`
		if [ "$kname" = $krunning ];then
			continue
		fi
		for name in vmlinux vmlinuz image;do
			for k in $prefix/boot/$name-${i##*/}; do
				if [ -f $k ];then
					kernel=${k##*/}
					initrd=initrd-${i##*/}
					break 2
				fi
			done
		done
		if [ ! -z "$kernel" ];then
			kpair=$kernel:$initrd
			KERNEL_NAME[$kcount]=$kname
			KERNEL_LIST=$KERNEL_LIST,$kpair
			kcount=$((kcount+1))
		fi
	done
	#======================================
	# what if no kernel was found...
	#--------------------------------------
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
	KERNEL_LIST=$(echo $KERNEL_LIST | sed -e s@^,@@)
	export KERNEL_LIST
	export KERNEL_NAME
	export KERNEL_PAIR
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
	local blkTest
	local nBlk
	if [ -z "$zblocks" ] && [ -z "$blocks" ];then
		# md5 file not yet read in... skip
		return
	fi
	if [ ! -z "$zblocks" ];then
		isize=`expr $zblocks \* $zblocksize`
	else
		isize=`expr $blocks \* $blocksize`
	fi
	local IFS=' '
	testBlkSizes="32768 61440 65464"
	if [ "$imageBlkSize" -gt 0 ]; then
		testBlkSizes="$imageBlkSize $testBlkSizes"
	fi
	for blkTest in $testBlkSizes ; do
		nBlk=`expr $isize / $blkTest`
		if [ $nBlk -lt 65535 ] ; then
			imageBlkSize=$blkTest
			return
		fi
	done
	systemException \
		"Maximum blocksize for atftp protocol exceeded" \
	"reboot"
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
		#======================================
		# convert parameters to lowercase if required
		#--------------------------------------
		if [ "$1" = "lowercase" ];then
			kernelKey=`echo $kernelKey | tr [:upper:] [:lower:]`
		fi
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
		local modfile=/etc/modprobe.d/99-local.conf
		if [ ! -f $modfile ];then
			modfile=/etc/modprobe.conf.local
		fi
		if [ -f $modfile ];then
			sed -i -e s"@rd_size=.*@rd_size=$ramdisk_size@" $modfile
		fi
	fi
	if [ ! -z "$lang" ];then
		export DIALOG_LANG=$lang
	fi
}
#======================================
# includeKernelParametersLowerCase
#--------------------------------------
function includeKernelParametersLowerCase {
	includeKernelParameters "lowercase"
}
#======================================
# umountSystem
#--------------------------------------
function umountSystem {
	local retval=0
	local OLDIFS=$IFS
	local mountList="/mnt /read-only /read-write"
	IFS=$IFS_ORIG
	#======================================
	# umount boot device
	#--------------------------------------
	if [ ! -z "$imageBootDevice" ];then
		umount $imageBootDevice 1>&2
	fi
	#======================================
	# umount mounted mountList paths
	#--------------------------------------
	for mpath in $(cat /proc/mounts | cut -f2 -d " ");do
		for umount in $mountList;do
			if [ "$mpath" = "$umount" ];then
				if ! umount $mpath >/dev/null;then
				if ! umount -l $mpath >/dev/null;then
					retval=1
				fi
				fi
			fi
		done
	done
	#======================================
	# remove mount points
	#--------------------------------------
	for dir in "/read-only" "/read-write" "/xino";do
		test -d $dir && rmdir $dir 1>&2
	done
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
				if ! mkfs.ext3 -F $rwDevice >/dev/null;then
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
	mountSystemOverlay
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
	local resetReadWrite=0
	local ramOnly=0
	local haveBytes
	local haveKByte
	local haveMByte
	local wantCowFS
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
	if [ ! -e $rwDevice ];then
		ramOnly=1
	elif getDiskDevice $rwDevice | grep -q ram;then
		ramOnly=1
	fi
	if [ $ramOnly = 1 ];then
		haveKByte=`cat /proc/meminfo | grep MemFree | cut -f2 -d:| cut -f1 -dk`
		haveMByte=`expr $haveKByte / 1024`
		haveMByte=`expr $haveMByte \* 7 / 10`
		clic_cmd="$clic_cmd -m $haveMByte"
	else
		haveBytes=`blockdev --getsize64 $rwDevice`
		haveMByte=`expr $haveBytes / 1024 / 1024`
		wantCowFS=0
		if \
			[ "$kiwi_hybrid" = "yes" ] &&
			[ "$kiwi_hybridpersistent" = "yes" ]
		then
			# write into a cow file on a filesystem, for hybrid iso's
			wantCowFS=1
		fi
		if [ $wantCowFS = 1 ];then
			# write into a cow file on a filesystem
			mkdir -p $HYBRID_PERSISTENT_DIR
			if [ $LOCAL_BOOT = "no" ] && [ $systemIntegrity = "clean" ];then
				resetReadWrite=1
			elif ! mount $rwDevice $HYBRID_PERSISTENT_DIR;then
				resetReadWrite=1
			elif [ ! -z "$wipecow" ];then
				resetReadWrite=1
			fi
			if [ $resetReadWrite = 1 ];then
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
	size=$((size/512))
	# we don't want reserved blocks...
	tune2fs -m 0 $roDir/fsdata.ext3 >/dev/null
	# we don't want automatic filesystem check...
	tune2fs -i 0 $roDir/fsdata.ext3 >/dev/null
	if [ ! $LOCAL_BOOT = "no" ];then
		e2fsck -p $roDir/fsdata.ext3
	fi
	if [ $LOCAL_BOOT = "no" ] || [ $ramOnly = 1 ];then
		resize2fs $roDir/fsdata.ext3 $size"s"
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
}
#======================================
# mountSystemStandard
#--------------------------------------
function mountSystemStandard {
	local mountDevice=$1
	if [ "$FSTYPE" = "btrfs" ];then
		export haveBtrFS=yes
	fi
	if [ "$FSTYPE" = "xfs" ];then
		export haveXFS=yes
	fi
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
	#======================================
	# setup boot partition
	#--------------------------------------
	if [ ! "$arch" = "ppc64" ];then
		if \
			[ "$LOCAL_BOOT" = "no" ]          && \
			[ ! "$systemIntegrity" = "fine" ] && \
			[ $retval = 0 ]                   && \
			[ -z "$RESTORE" ]
		then
			setupBootPartition
		fi
	fi
	#======================================
	# reset mount counter
	#--------------------------------------
	resetMountCounter
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
# searchGroupConfig
#--------------------------------------
function searchGroupConfig {
	local localhwaddr=$DHCPCHADDR
	local GROUPCONFIG=/etc/config.group
	local list_var
	local mac_list
	#======================================
	# Load group file if it exists
	#--------------------------------------
	Echo "Checking for config file: config.group";
	fetchFile KIWI/config.group $GROUPCONFIG
	if [ ! -s $GROUPCONFIG ]; then
		return
	fi
	Echo "Found config.group, determining available groups";
	importFile < $GROUPCONFIG
	Debug "KIWI_GROUP = '$KIWI_GROUP'"
	#======================================
	# Parse group file
	#--------------------------------------
	if [ -z "$KIWI_GROUP" ] ; then
		systemException \
			"No groups defined in $GROUPCONFIG" \
		"reboot"
	fi
	for i in `echo "$KIWI_GROUP" | sed 's/,/ /g' | sed 's/[ \t]+/ /g'`; do
		Echo "Lookup MAC address: $localhwaddr in ${i}_KIWI_MAC_LIST"
		eval list_var="${i}_KIWI_MAC_LIST"
		eval mac_list=\$$list_var
		searchGroupHardwareAddress $i "$mac_list"
		if [ -s $CONFIG ]; then
			break
		fi
		unset list_var
		unset mac_list
	done
}
#======================================
# searchGroupHardwareAddress
#--------------------------------------
function searchGroupHardwareAddress {
	# /.../
	# function to check the existance of the hosts
	# hardware address within the defined "mac_list".
	# If the hardware address is found, load the config file.
	# ----
	local localhwaddr=$DHCPCHADDR
	local local_group=$1
	local mac_list=$2
	for j in `echo "$mac_list" | sed 's/,/ /g' | sed 's/[ \t]+/ /g'`; do
		if [ "$localhwaddr" = "$j" ] ; then
			Echo "MAC address $localhwaddr found in group $local_group"
			Echo "Checking for config file: config.$local_group"
			fetchFile KIWI/config.$local_group $CONFIG
			if [ ! -s $CONFIG ]; then
				systemException \
					"No configuration found for $j" \
				"reboot"
			fi
			break
		fi
	done
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
# searchHardwareMapConfig
#--------------------------------------
function searchHardwareMapConfig {
	local list_var
	local mac_list
	#======================================
	# return if no map was specified
	#--------------------------------------
	if [ -z "$HARDWARE_MAP" ];then
		return
	fi
	Echo "Found hardware/vendor map configuration variable"
	#===========================================
	# Evaluate the MAP list, and test for hwaddr
	#-------------------------------------------
	for i in `echo "$HARDWARE_MAP" | sed 's/,/ /g' | sed 's/[ \t]+/ /g'`; do
		Echo "Lookup MAC address: $localhwaddr in ${i}_HARDWARE_MAP"
		eval list_var="${i}_HARDWARE_MAP"
		eval mac_list=\$$list_var
		Debug "${i}_HARDWARE_MAP = '$mac_list'"
		searchHardwareMapHardwareAddress $i "$mac_list"
		if [ -s $CONFIG ]; then
			break
		fi
		unset list_var
		unset mac_list
	done
}
#======================================
# searchHardwareMapHardwareAddress
#--------------------------------------
function searchHardwareMapHardwareAddress {
	local HARDWARE_CONFIG=/etc/config.hardware
	local localhwaddr=$DHCPCHADDR
	local hardware_group=$1
	local mac_list=$2
	Debug "hardware_group = '$hardware_group'"
	Debug "mac_list = '$mac_list'"
	for j in `echo "$mac_list" | sed 's/,/ /g' | sed 's/[ \t]+/ /g'`; do
		if [ "$localhwaddr" = "$j" ] ; then
			Echo "MAC address $localhwaddr found in group $hardware_group"
			Echo "Checking for config file: hardware_config.$hardware_group"
			fetchFile KIWI/hardware_config.$hardware_group $HARDWARE_CONFIG
			if [ ! -s $HARDWARE_CONFIG ]; then
				systemException \
					"No configuration found for $j" \
				"reboot"
			fi
			importFile < $HARDWARE_CONFIG
			break
		fi
	done
}
#======================================
# runHook
#--------------------------------------
function runHook {
	HOOK="/kiwi-hooks/$1.sh"
	if [ ! -e $HOOK ];then
		HOOK="/lib/kiwi/hooks/$1.sh"
	fi
	if [ -e $HOOK ]; then
		. $HOOK "$@"
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
# atftpProgress
#--------------------------------------
function atftpProgress {
	# /.../
	# atftp doesn't use a stream based download and sometimes
	# seek back and forth which makes it hard to use pipes for
	# progress indication. Therefore we watch the trace output
	# ----
	local imgsize=$1    # image size in MB
	local prefix=$2     # line prefix text
	local file=$3       # file with progress data
	local blocksize=$4  # blocksize use for download
	local bytes=0       # log lines multiplied by blocksize
	local lines=0       # log lines
	local percent=0     # in percent of all
	local all=$((imgsize * 1024 * 1024))
	local line
	local step=0
	# number of cycles for approx. 2% steps
	local max_step=$(($all / $blocksize / 25))
	cat < dev/null > $file.tmp
	#======================================
	# print progress information
	#--------------------------------------
	while read line ;do
		echo "$line" >> $file.tmp
		let step=step+1
		if [ $step -lt $max_step ]; then
			continue
		fi
		step=0
		# /.../
		# the trace logs two lines indicating one download block of
		# blocksize bytes. We assume only full blocks. At the end
		# it might happen that only a part of blocksize bytes is
		# required. The function does not precisely calculate them
		# and assumes blocksize bytes. imho that's ok for the progress
		# bar. In order to be exact the function would have to sum
		# up all bytes from the trace log for each iteration which
		# would cause the download to pause because it has to wait
		# for the progress bar to get ready
		# ----
		# the same block can be transferred multiple times
		lines=$(grep "^sent ACK" $file.tmp | sort -u | wc -l)
		bytes=$((lines * $blocksize))
		percent=$(echo "scale=2; $bytes * 100"  | bc)
		percent=$(echo "scale=0; $percent / $all" | bc)
		echo -en "$prefix ( $percent%)\r"
	done
	grep -v "^\(received \)\|\(sent \)" $file.tmp > $file
	rm $file.tmp
	echo
}

#======================================
# encodeURL
#--------------------------------------
function encodeURL {
	# /.../
	# encode special characters in URL's to correctly
	# serve as input for fetchFile and putFile
	# ----
	local STR
	local CH
	STR="$@"
	echo -n "$STR" | while read -n1 CH; do
		[[ $CH =~ [-_A-Za-z0-9./] ]] && printf "$CH" || printf "%%%x" \'"$CH"
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
	local chunk=$6
	local encoded_path
	local dump
	local call
	local call_pid
	if test -z "$chunk";then
		chunk=4k
	fi
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
		path=$(echo "$path" | sed -e s@\\.gz@@)
		path="$path.gz"
	fi
	encoded_path=$(encodeURL "$path")
	#======================================
	# setup progress meta information
	#--------------------------------------
	dump="dd bs=$chunk of=\"$dest\""
	showProgress=0
	if [ -x /usr/bin/dcounter ] && [ -f /etc/image.md5 ] && [ -b "$dest" ];then
		showProgress=1
		read sum1 blocks blocksize zblocks zblocksize < /etc/image.md5
		needBytes=$((blocks * blocksize))
		needMByte=$((needBytes / 1048576))
		if [ ! -z "$zblocks" ];then
			needZBytes=$((zblocks * zblocksize))
			needZMByte=$((needZBytes / 1048576))
		fi
		progressBaseName=$(basename "$path")
		TEXT_LOAD=$(getText "Loading %1" "$progressBaseName")
		TEXT_GZIP=$(getText "Uncompressing %1" "$progressBaseName")
		dump="dcounter -s $needMByte -l \"$TEXT_LOAD \" 2>/progress | $dump"
	fi
	#======================================
	# build download command
	#--------------------------------------
	case "$type" in
		"http")
			if test "$izip" = "compressed"; then
				call="curl -f http://$host/$encoded_path \
					2>$TRANSFER_ERRORS_FILE |\
					gzip -d 2>>$TRANSFER_ERRORS_FILE | $dump"
			else
				call="curl -f http://$host/$encoded_path \
					2>$TRANSFER_ERRORS_FILE |\
					$dump"
			fi
			;;
		"https")
			if test "$izip" = "compressed"; then
				call="curl -f -k https://$host/$encoded_path \
					2>$TRANSFER_ERRORS_FILE |\
					gzip -d 2>>$TRANSFER_ERRORS_FILE | $dump"
			else
				call="curl -f -k https://$host/$encoded_path \
					2>$TRANSFER_ERRORS_FILE |\
					$dump"
			fi
			;;
		"ftp")
			if test "$izip" = "compressed"; then
				call="curl ftp://$host/$encoded_path \
					2>$TRANSFER_ERRORS_FILE |\
					gzip -d 2>>$TRANSFER_ERRORS_FILE | $dump"
			else
				call="curl ftp://$host/$encoded_path \
					2>$TRANSFER_ERRORS_FILE |\
					$dump"
			fi
			;;
		"tftp")
			validateBlockSize
			# /.../
			# atftp activates multicast by '--option "multicast"'
			# and deactivates it again  by '--option "disable multicast"'
			# ----
			if [ -f /etc/image.md5 ] && [ -b "$dest" ];then
				# enable multicast for system image and transfer to block device
				multicast_atftp="multicast"
			else
				# disable multicast for any other transfer
				multicast_atftp="disable multicast"
			fi
			havetemp_dir=1
			if [ -z "$FETCH_FILE_TEMP_DIR" ];then
				# we don't have a tmp dir available for downloading
				havetemp_dir=0
			elif [ -e "$FETCH_FILE_TEMP_DIR/${path##*/}" ];then
				# temporary download data already exists
				havetemp_dir=0
			else
				# prepare use of temp files for compressed download
				FETCH_FILE_TEMP_FILE="$FETCH_FILE_TEMP_DIR/${path##*/}"
				export FETCH_FILE_TEMP_FILE
			fi
			if test "$izip" = "compressed"; then
				if [ $havetemp_dir -eq 0 ];then
					# /.../
					# operate without temp files, standard case
					# ----
					call="busybox tftp \
						-b $imageBlkSize -g -r \"$path\" \
						-l >(gzip -d 2>>$TRANSFER_ERRORS_FILE | $dump) \
						$host 2>>$TRANSFER_ERRORS_FILE"
				else
					# /.../
					# operate using temp files
					# export the path to allow temp file management in a hook
					# ----
					if [ $showProgress -eq 1 ];then
						call="(atftp \
							--trace \
							--option \"$multicast_atftp\"  \
							--option \"blksize $imageBlkSize\" \
							-g -r \"$path\" -l \"$FETCH_FILE_TEMP_FILE\" \
							$host 2>&1 | \
							atftpProgress \
								$needZMByte \"$TEXT_LOAD\" \
								$TRANSFER_ERRORS_FILE $imageBlkSize \
							>&2 ; \
							gzip -d < \"$FETCH_FILE_TEMP_FILE\" | \
								dcounter -s $needMByte -l \"$TEXT_GZIP \" | \
								dd bs=$chunk of=\"$dest\" ) 2>/progress "
					else
						call="atftp \
							--option \"$multicast_atftp\"  \
							--option \"blksize $imageBlkSize\" \
							-g -r \"$path\" -l \"$FETCH_FILE_TEMP_FILE\" $host \
							&> $TRANSFER_ERRORS_FILE ; \
							gzip -d < \"$FETCH_FILE_TEMP_FILE\" | \
							dd bs=$chunk of=\"$dest\" "
					fi
				fi
			else
				if [ $showProgress -eq 1 ];then
					call="atftp \
						--trace \
						--option \"$multicast_atftp\"  \
						--option \"blksize $imageBlkSize\" \
						-g -r \"$path\" -l \"$dest\" $host 2>&1 | \
						atftpProgress \
							$needMByte \"$TEXT_LOAD\" \
							$TRANSFER_ERRORS_FILE $imageBlkSize \
						> /progress"
				else
					call="atftp \
						--option \"$multicast_atftp\"  \
						--option \"blksize $imageBlkSize\" \
						-g -r \"$path\" -l \"$dest\" $host \
						&> $TRANSFER_ERRORS_FILE"
				fi
			fi
			;;
		*)
			systemException "Unknown download type: $type" "reboot"
			;;
	esac
	#======================================
	# run the download
	#--------------------------------------
	if [ $showProgress -eq 1 ];then
		test -e /progress || mkfifo /progress
		test -e /tmp/load_code && rm -f /tmp/load_code
		errorLogStop
		(
			eval $call \; 'echo ${PIPESTATUS[0]} > /tmp/load_code' &>/dev/null
		)&
		call_pid=$!
		echo "cat /progress | dialog \
			--backtitle \"$TEXT_INSTALLTITLE\" \
			--progressbox 3 65
		" > /tmp/progress.sh
		if [ -e /dev/fb0 ];then
			fbiterm -m $UFONT -- bash -e /tmp/progress.sh || \
			bash -e /tmp/progress.sh
		else
			bash -e /tmp/progress.sh
		fi
		clear
		wait $call_pid
		loadCode=`cat /tmp/load_code`
		if [ -z "$loadCode" ]; then
			systemException \
				"Failed to get the download process return value" \
			"reboot"
		fi
	else
		eval $call \; 'loadCode=${PIPESTATUS[0]}'
	fi
	if [ $showProgress -eq 1 ];then
		errorLogContinue
	fi
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
	local encoded_dest
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
	encoded_dest=$(encodeURL "$dest")
	case "$type" in
		"http")
			curl -f -T "$path" http://$host/$encoded_dest \
				> $TRANSFER_ERRORS_FILE 2>&1
			return $?
			;;
		"https")
			curl -f -T "$path" https://$host/$encoded_dest \
				> $TRANSFER_ERRORS_FILE 2>&1
			return $?
			;;
		"ftp")
			curl -T "$path" ftp://$host/$encoded_dest \
				> $TRANSFER_ERRORS_FILE 2>&1
			return $?
			;;
		"tftp")
			atftp -p -l "$path" -r "$dest" $host >/dev/null 2>&1
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
	local swap=$2
	local prefix=by-id
	if [ -z "$device" ];then
		return
	fi
	if echo $device | grep -q "$VGROUP"; then
		echo $device
		return
	fi
	if [ -z "$swap" ] && echo $device | grep -q "dev\/md"; then
		echo $device
		return
	fi
	if [ ! -z "$NON_PERSISTENT_DEVICE_NAMES" ]; then
		echo $device
		return
	fi
	if [ ! -z "$USE_BY_UUID_DEVICE_NAMES" ];then
		prefix=by-uuid
	fi
	for i in /dev/disk/$prefix/*;do
		if [ -z "$i" ];then
			continue
		fi
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
		if [ ! -d /mnt/$dir ];then
			mkdir -p /mnt/$dir
		fi
		if ! canWrite /mnt/$dir;then
			Echo "Can't write to $dir, read-only filesystem... skipped"
			continue
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
	#======================================
	# run preinit stage
	#--------------------------------------
	Echo "Preparing preinit phase..."
	if ! cp /iprocs /mnt;then
		systemException "Failed to copy iprocs code" "reboot"
	fi
	if ! cp /preinit /mnt;then
		systemException "Failed to copy preinit code" "reboot"
	fi
	if ! cp /include /mnt;then
		systemException "Failed to copy include code" "reboot"
	fi
	if [ ! -x /lib/mkinitrd/bin/run-init ];then
		systemException "Can't find run-init program" "reboot"
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
	# setup logging in this mode
	#--------------------------------------
	exec 2>>$ELOG_FILE
	set -x
	#======================================
	# kill second utimer and tail
	#--------------------------------------
	. /iprocs
	kill $UTIMER_PID &>/dev/null
	kill $TAIL_PID   &>/dev/null
	#======================================
	# remove preinit code from system image
	#--------------------------------------
	rm -f /tmp/utimer
	rm -f /dev/utimer
	rm -f /utimer
	rm -f /iprocs
	rm -f /preinit
	rm -f /include
	rm -f /.kconfig
	rm -f /.profile
	rm -rf /image
	#======================================
	# return early for special types
	#--------------------------------------
	if \
		[ "$haveClicFS" = "yes" ] || \
		[ "$haveBtrFS"  = "yes" ] || \
		[ "$haveXFS"  = "yes" ] || \
		[ ! -z "$NFSROOT" ]       || \
		[ ! -z "$NBDROOT" ]       || \
		[ ! -z "$AOEROOT" ]       || \
		[ ! -z "$COMBINED_IMAGE" ]
	then
		export ROOTFS_FSCK="0"
		return
	fi
	#======================================
	# umount LVM root parts
	#--------------------------------------
	for i in /dev/$VGROUP/LV*;do
		if [ ! -e $i ];then
			continue
		fi
		if \
			[ ! $i = "/dev/$VGROUP/LVRoot" ] && \
			[ ! $i = "/dev/$VGROUP/LVComp" ] && \
			[ ! $i = "/dev/$VGROUP/LVSwap" ]
		then
			mpoint=$(echo ${i##/*/LV})
			umount $mpoint 1>&2
		fi
	done
	#======================================
	# umount image boot partition if any
	#--------------------------------------
	for i in lvmboot btrboot clicboot xfsboot luksboot syslboot;do
		if [ ! -e /$i ];then
			continue
		fi
		umount /$i 1>&2
	done
	umount /boot 1>&2
	#======================================
	# turn off swap
	#--------------------------------------
	mount -t proc proc /proc
	swapoff -a   1>&2
	umount /proc 1>&2
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
	# check for init kernel option
	#--------------------------------------
	if [ -z "$init" ];then
		init=/sbin/init
	fi
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
			if [ ! -z "$OEM_REBOOT_INTERACTIVE" ];then
				rebootinter=yes
			fi
			if [ ! -z "$OEM_SHUTDOWN" ];then
				shutdown=yes
			fi
			if [ ! -z "$OEM_SHUTDOWN_INTERACTIVE" ];then
				shutdowninter=yes
			fi
		fi
	fi
	#======================================
	# kill initial tail and utimer
	#--------------------------------------
	. /iprocs
	kill $UTIMER_PID &>/dev/null
	kill $TAIL_PID   &>/dev/null
	#======================================
	# copy boot log file into system image
	#--------------------------------------
	mkdir -p /mnt/var/log
	rm -f /mnt/boot/grub/mbrid
	if [ -e /mnt/dev/shm/initrd.msg ];then
		cp -f /mnt/dev/shm/initrd.msg /mnt/var/log/boot.msg
	fi
	if [ -e /var/log/boot.kiwi ];then
		cp -f /var/log/boot.kiwi /mnt/var/log/boot.kiwi
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
	fi
	if [ "$rebootinter" = "yes" ];then
		Echo "Reboot requested... rebooting after preinit"
		if [ "$OEMInstallType" = "CD" ];then
			TEXT_DUMP=$TEXT_CDPULL
		else
			TEXT_DUMP=$TEXT_USBPULL
		fi
		Dialog \
			--backtitle \"$TEXT_INSTALLTITLE\" \
			--msgbox "\"$TEXT_DUMP\"" 5 70
		clear
		Echo "Prepare for reboot"
		exec /lib/mkinitrd/bin/run-init -c /dev/console /mnt /bin/bash -c \
			"/preinit ; . /include ; cleanImage ; exec /sbin/reboot -f -i"
	fi
	if [ "$shutdown" = "yes" ];then
		Echo "Shutdown  requested... system shutdown after preinit"
		exec /lib/mkinitrd/bin/run-init -c /dev/console /mnt /bin/bash -c \
			"/preinit ; . /include ; cleanImage ; exec /sbin/halt -fihp"
	fi
	if [ "$shutdowninter" = "yes" ];then
		Echo "Shutdown  requested... system shutdown after preinit"
		if [ "$OEMInstallType" = "CD" ];then
			TEXT_DUMP=$TEXT_CDPULL_SDOWN
		else
			TEXT_DUMP=$TEXT_USBPULL_SDOWN
		fi
		Dialog \
			--backtitle \"$TEXT_INSTALLTITLE\" \
			--msgbox "\"$TEXT_DUMP\"" 5 70
		clear
		Echo "Prepare for shutdown"
		exec /lib/mkinitrd/bin/run-init -c /dev/console /mnt /bin/bash -c \
			"/preinit ; . /include ; cleanImage ; exec /sbin/halt -fihp" 
	fi
	# FIXME: clicfs doesn't like run-init
	if [ ! "$haveClicFS" = "yes" ];then
		exec /lib/mkinitrd/bin/run-init -c /dev/console /mnt /bin/bash -c \
			"/preinit ; . /include ; cleanImage ; exec $init $option"
	else
		cd /mnt && exec chroot . /bin/bash -c \
			"/preinit ; . /include ; cleanImage ; exec $init $option"
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
	luksOpen $rwDevice luksReadWrite
	rwDeviceLuks=$luksDeviceOpened
	luksOpen $roDevice luksReadOnly
	roDeviceLuks=$luksDeviceOpened
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
	# check if the given kernel is a xen kernel and if so
	# check if a dom0 or a domU setup was requested
	# ----
	local kname=$1
	local mountPrefix=$2
	local sysmap="$mountPrefix/boot/System.map-$kname"
	local isxen
	if [ ! -e $sysmap ]; then
		sysmap="$mountPrefix/boot/System.map"
	fi
	if [ ! -e $sysmap ]; then
		Echo "No system map for kernel $kname found"
		return 1
	fi
	isxen=$(grep -c "xen_base" $sysmap)
	if [ $isxen -eq 0 ]; then
		# not a xen kernel
		return 1
	fi
	if [ -z "$kiwi_xendomain" ];then
		# no xen domain set, assume domU
		return 1
	fi
	if [ $kiwi_xendomain = "dom0" ];then
		# xen dom0 requested
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
	if [ ! $loader = "syslinux" ] && [ ! $loader = "extlinux" ];then
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
	local retry=1
	local info
	#======================================
	# no map name set, build it from device
	#--------------------------------------
	if [ -z "$name" ];then
		name=luks_$(basename $ldev)
	fi
	#======================================
	# luks map already exists, return
	#--------------------------------------
	if [ -e /dev/mapper/$name ];then
		export luksDeviceOpened=/dev/mapper/$name
		return
	fi
	#======================================
	# check device for luks extension
	#--------------------------------------
	if ! cryptsetup isLuks $ldev &>/dev/null;then
		export luksDeviceOpened=$ldev
		return
	fi
	#======================================
	# ask for passphrase if not cached
	#--------------------------------------
	while true;do
		if [ -z "$luks_pass" ];then
			Echo "Try: $retry"
			errorLogStop
			luks_pass=$(runInteractive \
				"--stdout --insecure --passwordbox "\"$TEXT_LUKS\"" 10 60"
			)
			errorLogContinue
		fi
		if echo "$luks_pass" | cryptsetup luksOpen $ldev $name;then
			break
		fi
		unset luks_pass
		if [ -n "$luks_open_can_fail" ]; then
			unset luksDeviceOpened
			return 1
		fi
		if [ $retry -eq 3 ];then
			systemException \
				"Max retries reached... reboot" \
			"reboot"
		fi
		retry=$(($retry + 1))
	done
	#======================================
	# wait for the luks map to appear
	#--------------------------------------
	if ! waitForStorageDevice /dev/mapper/$name &>/dev/null;then
		systemException \
			"LUKS map /dev/mapper/$name doesn't appear... fatal !" \
		"reboot"
	fi
	#======================================
	# store luks device and return
	#--------------------------------------
	export luksDeviceOpened=/dev/mapper/$name
	return 0
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
	local name=$1
	#======================================
	# close specified name if set
	#--------------------------------------
	if [ -n "$1" ]; then
		name=$(basename $1)
		cryptsetup luksClose $name
		return
	fi
	#======================================
	# close all luks* map names
	#--------------------------------------
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
	local nb_NO=Norwegian
	local da_DK=Danish
	local pt_PT=Portuguese
	local en_GB=English
	local code
	local lang
	if [ -f /.profile ];then
		importFile < /.profile
	fi
	if [ ! -z "$kiwi_oemunattended" ] && [ "$DIALOG_LANG" = "ask" ];then
		DIALOG_LANG=en_US
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
		getText "Please remove the CD/DVD before reboot")
	export TEXT_USBPULL=$(
		getText "Please unplug the USB stick before reboot")
	export TEXT_CDPULL_SDOWN=$(
		getText "Please remove the CD/DVD before shutdown")
	export TEXT_USBPULL_SDOWN=$(
		getText "System will be shutdown. Remove USB stick before power on")
	export TEXT_SELECT=$(
		getText "Select disk for installation:")
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
	local files=$(find /license.*txt 2>/dev/null)
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
			--yesno "\"$TEXT_LICENSE\"" \
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
	# partition number. If the device name starts with /dev/disk
	# the /dev/disk/<name>-partN schema is used
	# ----
	if echo $1 | grep -q "^\/dev\/disk\/" ; then
		echo $1"-part"$2
		return
	fi
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
	# linux device node specs: If the device matches "p"
	# followed by a number remove pX else remove 
	# the last number
	# ----
	local part=$(getDiskDevice $1)
	local part_new=$(echo $part | sed -e 's@\(^.*\)\(p[0-9].*$\)@\1@')
	if [ $part = $part_new ];then
		part_new=$(echo $part | sed -e 's@\(^.*\)\([0-9].*$\)@\1@')
	fi
	echo $part_new
}
#======================================
# nd
#--------------------------------------
function nd {
	# /.../
	# print the number of the disk device according to the
	# device node name. 
	# ----
	local part=$(getDiskDevice $1)
	local part_new=$(echo $part | sed -e 's@\(^.*\)p\([0-9].*$\)@\2@')
	if [ $part = $part_new ];then
		part_new=$(echo $part | sed -e 's@\(^.*\)\([0-9].*$\)@\2@')
	fi
	echo $part_new
}
#======================================
# runInteractive
#--------------------------------------
function runInteractive {
	# /.../
	# run dialog in a bash inside an fbiterm or directly
	# on the running terminal. Make the terminal the controlling
	# tty first. The output of the dialog call is stored in
	# a file and printed as result to this function
	# ----
	local r=/tmp/rid
	local code
	echo "dialog $@ > /tmp/out" > $r
	echo "echo -n \$? > /tmp/out.exit" >> $r
	if [ -e /dev/fb0 ];then
		setctsid $ELOG_EXCEPTION fbiterm -m $UFONT -- bash -i $r
	else
		setctsid $ELOG_EXCEPTION bash -i $r
	fi
	code=$(cat /tmp/out.exit)
	if [ ! $code = 0 ];then
		return $code
	fi
	cat /tmp/out && rm -f /tmp/out* $r
	return 0
}
#======================================
# createHybridPersistent
#--------------------------------------
function createHybridPersistent {
	# /.../
	# create a new partition to handle the copy-on-write actions
	# by the clicfs live mount. A new partition with a filesystem
	# inside labeled as 'hybrid' is created for this purpose
	# ----
	local device=$1
	local input=/part.input
	local disknr=$HYBRID_PERSISTENT_PART
	mkdir -p /cow
	rm -f $input
	#======================================
	# check persistent write partition
	#--------------------------------------
	if mount -L hybrid /cow;then
		Echo "Existing persistent hybrid partition found"
		umount /cow
		rmdir  /cow
		return
	fi
	#======================================
	# create persistent write partition
	#--------------------------------------
	# /.../
	# we have to use fdisk here because parted can't work
	# with the partition table created by isohybrid
	# ----
	Echo "Creating hybrid persistent partition for COW data"
	for cmd in n p $disknr . . t $disknr $HYBRID_PERSISTENT_ID w q;do
		if [ $cmd = "." ];then
			echo >> $input
			continue
		fi
		echo $cmd >> $input
	done
	fdisk $device < $input 1>&2
	if test $? != 0; then
		Echo "Failed to create persistent write partition"
		Echo "Persistent writing deactivated"
		unset kiwi_hybridpersistent
		return
	fi
	#======================================
	# check partition device node
	#--------------------------------------
	if ! waitForStorageDevice $(ddn $device $disknr);then
		Echo "Partition $disknr on $device doesn't appear... fatal !"
		Echo "Persistent writing deactivated"
		unset kiwi_hybridpersistent
		return
	fi
	#======================================
	# create filesystem on write partition
	#--------------------------------------
	if ! mkfs.$HYBRID_PERSISTENT_FS -L hybrid $(ddn $device $disknr);then
		Echo "Failed to create hybrid persistent filesystem"
		Echo "Persistent writing deactivated"
		unset kiwi_hybridpersistent
	fi
}
#======================================
# callPartitioner
#--------------------------------------
function callPartitioner {
	local input=$1
	if [ $PARTITIONER = "fdasd" ];then
		Echo "Repartition the disk according to real geometry [ fdasd ]"
		echo "w" >> $input
		echo "q" >> $input
		fdasd $imageDiskDevice < $input 1>&2
		if test $? != 0; then
			systemException "Failed to create partition table" "reboot"
		fi
		udevPending
		blockdev --rereadpt $imageDiskDevice
	else
		# /.../
		# nothing to do for parted here as we write
		# imediately with parted and don't create a
		# command input file as for fdasd but we re-read
		# the disk so that the new table will be used
		# ----
		udevPending
		blockdev --rereadpt $imageDiskDevice
	fi
}
#======================================
# createPartitionerInput
#--------------------------------------
function createPartitionerInput {
	if echo $imageDiskDevice | grep -q 'dev\/dasd';then
		PARTITIONER=fdasd
	fi
	if [ $PARTITIONER = "fdasd" ];then
		createFDasdInput $@
	else
		Echo "Repartition the disk according to real geometry [ parted ]"
		partedInit $imageDiskDevice
		partedSectorInit $imageDiskDevice
		createPartedInput $imageDiskDevice $@
	fi
}
#======================================
# createFDasdInput
#--------------------------------------
function createFDasdInput {
	local input=/part.input
	local ignore_once=0
	local ignore=0
	normalizeRepartInput $*
	for cmd in ${pcmds[*]};do
		if [ $ignore = 1 ] && echo $cmd | grep -qE '[dntwq]';then
			ignore=0
		elif [ $ignore = 1 ];then
			continue
		fi
		if [ $ignore_once = "1" ];then
			ignore_once=0
			continue
		fi
		if [ $cmd = "a" ];then
			ignore=1
			continue
		fi
		if [ $cmd = "p" ];then
			ignore_once=1
			continue
		fi
		if [ $cmd = "83" ] || [ $cmd = "8e" ];then
			cmd=1
		fi
		if [ $cmd = "82" ];then
			cmd=2
		fi
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
	local opts
	if [ $PARTED_HAVE_ALIGN -eq 1 ];then
		opts="-a cyl"
	fi
	if ! parted $opts -m $device unit cyl $cmds;then
		systemException "Failed to create partition table" "reboot"
	fi
	partedInit $device
}
#======================================
# partedSectorInit
#--------------------------------------
function partedSectorInit {
	# /.../
	# return aligned start/end sectors of current table.
	# ----
	IFS=$IFS_ORIG
	local disk=$1
	local s_start
	local s_stopp
	unset startSectors
	unset endSectors
	for i in $(
		parted -m $disk unit s print | grep ^[1-4]: | cut -f2-3 -d: | tr -d s
	);do
		s_start=$(echo $i | cut -f1 -d:)
		s_stopp=$(echo $i | cut -f2 -d:)
		if [ -z "$startSectors" ];then
			startSectors=${s_start}s
		else
			startSectors=${startSectors}:${s_start}s
		fi
		if [ -z "$endSectors" ];then
			endSectors=$((s_stopp/8*8+8))s
		else
			endSectors=$endSectors:$((s_stopp/8*8+8))s
		fi
	done
	# /.../
	# in case of an empty disk we use the following start sector
	# ----
	if [ -z "$startSectors" ];then
		startSectors=2048s
	fi
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
	local sizeKB=$(($1 * 1048576))
	local cylreq=$(echo "scale=0; $sizeKB / ($partedCylKSize * 1000)" | bc)
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
	local partid
	local pstart
	local pstopp
	local value
	local cmdq
	#======================================
	# normalize commands
	#--------------------------------------
	normalizeRepartInput $*
	for cmd in ${pcmds[*]};do
		case $cmd in
			#======================================
			# delete partition
			#--------------------------------------
			"d")
				partid=${pcmds[$index + 1]}
				partid=$(($partid / 1))
				cmdq="$cmdq rm $partid"
				partedWrite "$disk" "$cmdq"
				cmdq=""
				;;
			#======================================
			# create new partition
			#--------------------------------------
			"n")
				partid=${pcmds[$index + 2]}
				partid=$(($partid / 1))
				pstart=${pcmds[$index + 3]}
				if [ "$pstart" = "1" ];then
					pstart=$(echo $startSectors | cut -f $partid -d:)
				fi
				if [ $pstart = "." ];then
					# start is next sector according to previous partition
					pstart=$(($partid - 1))
					if [ $pstart -gt 0 ];then
						pstart=$(echo $endSectors | cut -f $pstart -d:)
					else
						pstart=$(echo $startSectors | cut -f $partid -d:)
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
					if [ $pstopp -gt $partedCylCount ];then
						# given size is out of bounds, reduce to end of disk
						pstopp=$partedCylCount
					fi
				fi
				cmdq="$cmdq mkpart primary $pstart $pstopp"
				partedWrite "$disk" "$cmdq"
				partedSectorInit $imageDiskDevice
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
# normalizeRepartInput
#--------------------------------------
function normalizeRepartInput {
	local pcmds_fix
	local index=0
	local index_fix=0
	local partid
	local cmd
	#======================================
	# create list of commands
	#--------------------------------------
	unset pcmds
	for cmd in $*;do
		pcmds[$index]=$cmd
		index=$(($index + 1))
	done
	index=0
	#======================================
	# fix list of commands
	#--------------------------------------
	while [ ! -z "${pcmds[$index]}" ];do
		cmd=${pcmds[$index]}
		pcmds_fix[$index_fix]=$cmd
		case $cmd in
			"d")
				partid=${pcmds[$index + 1]}
				if ! echo $partid | grep -q "^[0-4]$";then
					# make sure there is a ID set for the deletion
					index_fix=$(($index_fix + 1))
					pcmds_fix[$index_fix]=1
				fi
			;;
			"n")
				partid=${pcmds[$index + 2]}
				if [ ! "$PARTITIONER" = "fdasd" ];then
					if ! echo $partid | grep -q "^[0-4]$";then
						# make sure there is a ID set for the creation
						index_fix=$(($index_fix + 1))
						pcmds_fix[$index_fix]=${pcmds[$index + 1]}
						index_fix=$(($index_fix + 1))
						pcmds_fix[$index_fix]=4
						index=$(($index + 1))
					fi
				fi
			;;
			"t")
				partid=${pcmds[$index + 1]}
				if ! echo $partid | grep -q "^[0-4]$";then
					# make sure there is a ID set for the type
					index_fix=$(($index_fix + 1))
					pcmds_fix[$index_fix]=1
				fi
			;;
		esac
		index=$(($index + 1))
		index_fix=$(($index_fix + 1))
	done
	#======================================
	# use fixed list and print log info
	#--------------------------------------
	unset pcmds
	pcmds=(${pcmds_fix[*]})
	unset pcmds_fix
	echo "Normalized Repartition input: ${pcmds[*]}" 1>&2
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
# resizeFilesystem
#--------------------------------------
function resizeFilesystem {
	local deviceResize=$1
	local callme=$2
	local ramdisk=0
	local resize_fs
	local resize_lucks
	local check
	if echo $deviceResize | grep -qi "/dev/ram";then
		ramdisk=1
	fi
	if [ -z "$FSTYPE" ];then
		probeFileSystem $deviceResize
	fi
	resize_lucks="luksResize $deviceResize"
	if [ "$FSTYPE" = "reiserfs" ];then
		Echo "Resize Reiser filesystem to full partition space..."
		resize_fs="resize_reiserfs -q $deviceResize"
		check="reiserfsck -y $deviceResize"
	elif [ "$FSTYPE" = "ext2" ];then
		Echo "Resize EXT2 filesystem to full partition space..."
		resize_fs="resize2fs -f -F -p $deviceResize"
		check="e2fsck -p $deviceResize"
		if [ $ramdisk -eq 1 ];then
			resize_fs="resize2fs -f $deviceResize"
		fi
	elif [ "$FSTYPE" = "ext3" ];then
		Echo "Resize EXT3 filesystem to full partition space..."
		resize_fs="resize2fs -f -F -p $deviceResize"
		check="e2fsck -p $deviceResize"
		if [ $ramdisk -eq 1 ];then
			resize_fs="resize2fs -f $deviceResize"
		fi
	elif [ "$FSTYPE" = "ext4" ];then
		Echo "Resize EXT4 filesystem to full partition space..."
		resize_fs="resize2fs -f -F -p $deviceResize"
		check="e2fsck -p $deviceResize"
		if [ $ramdisk -eq 1 ];then
			resize_fs="resize2fs -f $deviceResize"
		fi
	elif [ "$FSTYPE" = "btrfs" ];then
		Echo "Resize BTRFS filesystem to full partition space..."
		resize_fs="mount $deviceResize /mnt &&"
		resize_fs="$resize_fs btrfsctl -r max /mnt;umount /mnt"
		check="btrfsck $deviceResize"
	elif [ "$FSTYPE" = "xfs" ];then
		Echo "Resize XFS filesystem to full partition space..."
		resize_fs="mount $deviceResize /mnt &&"
		resize_fs="$resize_fs xfs_growfs /mnt;umount /mnt"
		check="xfs_check $deviceResize"
	else
		# don't know how to resize this filesystem
		return
	fi
	if [ -z "$callme" ];then
		if [ $ramdisk -eq 0 ];then
			eval $resize_lucks
			eval $resize_fs
		else
			eval $resize_lucks
			eval $resize_fs
		fi
		if [ ! $? = 0 ];then
			systemException \
				"Failed to resize/check filesystem" \
			"reboot"
		fi
		if [ $ramdisk -eq 0 ];then
			$check
		fi
		INITRD_MODULES="$INITRD_MODULES $FSTYPE"
	else
		echo $resize_fs
	fi
}
#======================================
# resetMountCounter
#--------------------------------------
function resetMountCounter {
	local curtype=$FSTYPE
	local command
	for device in \
		$imageRootDevice $imageBootDevice \
		$imageRecoveryDevice
	do
		if [ ! -e $device ];then
			continue
		fi
		probeFileSystem $device
		if [ "$FSTYPE" = "ext2" ];then
			command="tune2fs -c -1 -i 0"
		elif [ "$FSTYPE" = "ext3" ];then
			command="tune2fs -c -1 -i 0"
		elif [ "$FSTYPE" = "ext4" ];then
			command="tune2fs -c -1 -i 0"
		else
			# nothing to do here...
			continue
		fi
		eval $command $device 1>&2
	done
	FSTYPE=$curtype
}
#======================================
# createFilesystem
#--------------------------------------
function createFilesystem {
	local deviceCreate=$1
	local blocks=$2
	if [ "$FSTYPE" = "reiserfs" ];then
		mkreiserfs -f $deviceCreate $blocks 1>&2
	elif [ "$FSTYPE" = "ext2" ];then
		mkfs.ext2 -F $deviceCreate $blocks 1>&2
	elif [ "$FSTYPE" = "ext3" ];then
		mkfs.ext3 -F $deviceCreate $blocks 1>&2
	elif [ "$FSTYPE" = "ext4" ];then
		mkfs.ext4 -F $deviceCreate $blocks 1>&2
	elif [ "$FSTYPE" = "btrfs" ];then
		if [ ! -z "$blocks" ];then
			local bytes=$((blocks * 4096))
			mkfs.btrfs -b $bytes $deviceCreate
		else
			mkfs.btrfs $deviceCreate
		fi
	elif [ "$FSTYPE" = "xfs" ];then
		mkfs.xfs -f $deviceCreate
	else
		# use ext3 by default
		mkfs.ext3 -F $deviceCreate $blocks 1>&2
	fi
	if [ ! $? = 0 ];then
		systemException \
			"Failed to create filesystem" \
		"reboot"
	fi
}
#======================================
# restoreLVMMetadata
#--------------------------------------
function restoreLVMPhysicalVolumes {
	# /.../
	# restore the pysical volumes by the given restore file
	# created from vgcfgbackup. It's important to create them
	# with the same uuid's compared to the restore file
	# ----
	local restorefile=$1
	cat $restorefile | grep -A2 -E 'pv[0-9] {' | while read line;do
		if [ -z "$uuid" ];then
			uuid=$(echo $line | grep 'id =' |\
				cut -f2 -d= | tr -d \")
		fi
		if [ -z "$pdev" ];then
			pdev=$(echo $line|grep 'device =' |\
				cut -f2 -d\" | cut -f1 -d\")
		fi
		if [ ! -z "$pdev" ];then
			pvcreate -u $uuid $pdev
			unset uuid
			unset pdev
		fi
	done
}
#======================================
# pxeCheckServer
#--------------------------------------
function pxeCheckServer {
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
# pxeSetupDownloadServer
#--------------------------------------
function pxeSetupDownloadServer {
	# /.../
	# the pxe image system requires a server which stores
	# the image files. This function setup the SERVER variable
	# pointing to that server using the following heuristic:
	# ----
	# 1) check for $kiwiserver from cmdline
	# 2) try tftp.$DOMAIN whereas $DOMAIN is from dhcpcd-info
	# 3) try address of DHCP server if no servertype or tftp is used
	# 4) fail if no location was found
	# ----
	pxeCheckServer
	if [ -z "$SERVER" ];then
		SERVER=tftp.$DOMAIN
	fi
	Echo "Checking Server name: $SERVER"
	if ! ping -c 1 -w 30 $SERVER >/dev/null 2>&1;then
		Echo "Server: $SERVER not found"
		if [ -z "$SERVERTYPE" ] || [ "$SERVERTYPE" = "tftp" ]; then
			if [ ! -z "$DHCPSIADDR" ];then
				Echo "Using: $DHCPSIADDR from dhcpcd-info"
				SERVER=$DHCPSIADDR
			elif [ ! -z "$DHCPSID" ];then
				Echo "Using: $DHCPSID from dhcpcd-info"
				SERVER=$DHCPSID
			else
				systemException \
					"Can't assign SERVER IP/name... fatal !" \
				"reboot"
			fi
		fi
	fi
}
#======================================
# pxeSetupSystemAliasName
#--------------------------------------
function pxeSetupSystemAliasName {
	# /.../
	# Ask for an alias name if NAME from config.<MAC>
	# contains a number. If the number is -1 the system will
	# ask for ever for this name otherwhise the number sets
	# a timeout how long to wait for input of this data
	# ----
	if test $NAME -ne 0;then
		if test $NAME -eq -1;then
			Echo -n "Enter Alias Name for this system: " && \
			read SYSALIAS
		else
			Echo -n "Enter Alias Name [timeout in $NAME sec]: " && \
			read -t $NAME SYSALIAS
		fi
	fi
}
#======================================
# pxeSetupSystemHWInfoFile
#--------------------------------------
function pxeSetupSystemHWInfoFile {
	# /.../
	# calls hwinfo and stores the information into a file
	# suffixed by the hardware address of the network card
	# NOTE: it's required to have the dhcp info file sourced
	# before this function is called
	# ----
	hwinfo --all --log=hwinfo.$DHCPCHADDR >/dev/null
}
#======================================
# pxeSetupSystemHWTypeFile
#--------------------------------------
function pxeSetupSystemHWTypeFile {
	# /.../
	# collects information about the alias name the
	# architecture and more and stores that into a
	# file suffixed by the hardware address of the
	# network card.
	# ----
	echo "NCNAME=$SYSALIAS"   >> hwtype.$DHCPCHADDR
	echo "CRNAME=$SYSALIAS"   >> hwtype.$DHCPCHADDR
	echo "IPADDR=$IPADDR"     >> hwtype.$DHCPCHADDR
	echo "ARCHITECTURE=$ARCH" >> hwtype.$DHCPCHADDR
}
#======================================
# pxeSizeToMB
#--------------------------------------
function pxeSizeToMB {
	local size=$1
	if [ "$size" = "x" ];then
		echo . ; return
	fi
	local lastc=$(echo $size | sed -e 's@\(^.*\)\(.$\)@\2@')
	local value=$(echo $size | sed -e 's@\(^.*\)\(.$\)@\1@')
	if [ "$lastc" = "m" ] || [ "$lastc" = "M" ];then
		size=$value
	elif [ "$lastc" = "g" ] || [ "$lastc" = "G" ];then
		size=$(($value * 1024))
	fi
	echo +"$size"M
}
#======================================
# pxePartitionInput
#--------------------------------------
function pxePartitionInput {
	if [ $PARTITIONER = "fdasd" ];then
		pxePartitionInputFDASD
	else
		pxePartitionInputGeneric
	fi
}
#======================================
# pxeRaidPartitionInput
#--------------------------------------
function pxeRaidPartitionInput {
	if [ $PARTITIONER = "fdasd" ];then
		pxeRaidPartitionInputFDASD
	else
		pxeRaidPartitionInputGeneric
	fi
}
#======================================
# pxePartitionInputFDASD
#--------------------------------------
function pxePartitionInputFDASD {
	local field=0
	local count=0
	local IFS=","
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		partSize=$(pxeSizeToMB $partSize)
		if [ "$partID" = '82' ] || [ "$partID" = 'S' ];then
			partID=2
		elif [ "$partID" = '83' ] || [ "$partID" = 'L' ];then
			partID=1
		elif [ "$partID" -eq '8e' ] || [ "$partID" = 'V' ];then
			partID=4
		else
			partID=1
		fi
		echo -n "n . $partSize "
		if [ $partID = "2" ] || [ $partID = "4" ];then
			echo -n "t $count $partID "
		fi
	done
	echo "w"
}
#======================================
# pxeRaidPartitionInputFDASD
#--------------------------------------
function pxeRaidPartitionInputFDASD {
	pxePartitionInputFDASD
}
#======================================
# pxePartitionInputGeneric
#--------------------------------------
function pxePartitionInputGeneric {
	local field=0
	local count=0
	local IFS=","
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		partSize=$(pxeSizeToMB $partSize)
		if [ $partID = "S" ];then
			partID=82
		fi
		if [ $partID = "L" ];then
			partID=83
		fi
		if [ $partID = "V" ];then
			partID=8e
		fi
		if [ $count -eq 1 ];then
			echo -n "n p $count 1 $partSize "
			if [ $partID = "82" ] || [ $partID = "8e" ];then
				echo -n "t $partID "
			fi
		else
			echo -n "n p $count . $partSize "
			if [ $partID = "82" ] || [ $partID = "8e" ];then
				echo -n "t $count $partID "
			fi
		fi
		done
	echo "w q"
}
#======================================
# pxeRaidPartitionInputGeneric
#--------------------------------------
function pxeRaidPartitionInputGeneric {
	local field=0
	local count=0
	local IFS=","
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		partSize=$(pxeSizeToMB $partSize)
		partID=fd
		if [ $count -eq 1 ];then
			echo -n "n p $count 1 $partSize "
			echo -n "t $partID "
		else
			echo -n "n p $count . $partSize "
			echo -n "t $count $partID "
		fi
	done
	echo "w q"
}
#======================================
# pxeRaidCreate
#--------------------------------------
function pxeRaidCreate {
	local count=0
	local mdcount=0
	local IFS=","
	local raidFirst
	local raidSecond
	local conf=/mdadm.conf
	touch $conf
	for i in $PART;do
		count=$((count + 1))
		raidFirst=$(ddn $raidDiskFirst $count)
		raidSecond=$(ddn $raidDiskSecond $count)
		if ! waitForStorageDevice $raidFirst;then
			return
		fi
		if ! waitForStorageDevice $raidSecond;then
			return
		fi
		mdadm --zero-superblock $raidFirst
		mdadm --zero-superblock $raidSecond
		mdadm --create --metadata=0.9 --run /dev/md$mdcount \
			--level=$raidLevel --raid-disks=2 $raidFirst $raidSecond
		if [ ! $? = 0 ];then
			systemException \
				"Failed to create raid array... fatal !" \
			"reboot"
		fi
		echo "mdadm -Db /dev/md$mdcount" >> $conf
		mdcount=$((mdcount + 1))
	done
}
#======================================
# pxeRaidAssemble
#--------------------------------------
function pxeRaidAssemble {
	local count=0
	local mdcount=0
	local field=0
	local devices
	local IFS=";"
	local raidFirst
	local raidSecond
	for n in $RAID;do
		case $field in
			0) raidLevel=$n     ; field=1 ;;
			1) raidDiskFirst=$n ; field=2 ;;
			2) raidDiskSecond=$n; field=3
		esac
	done
	IFS=","
	for i in $PART;do
		count=$((count + 1))
		raidFirst=$(ddn $raidDiskFirst $count)
		raidSecond=$(ddn $raidDiskSecond $count)
		if ! waitForStorageDevice $raidFirst;then
			echo "Warning: device $raidFirst did not appear"
		else
			devices=$raidFirst
		fi
		if ! waitForStorageDevice $raidSecond;then
			echo "Warning: device $raidSecond did not appear"
		else
			devices="$devices $raidSecond"
		fi
		IFS=$IFS_ORIG
		mdadm --assemble --run /dev/md$mdcount $devices
		mdcount=$((mdcount + 1))
	done
}
#======================================
# pxeRaidZeroSuperBlock
#--------------------------------------
function pxeRaidZeroSuperBlock {
	# /.../
	# if we switch from a raid setup back to a non-raid
	# setup and use the same partition table setup as before
	# it might happen that the raid superblock survives.
	# This function removes all raid super blocks from
	# all partitions in the PART setup. If the partition
	# layout is different compared to the former raid layout
	# the superblock is not valid anymore
	# ----
	local count=1
	local device
	local IFS=","
	for i in $PART;do
		device=$(ddn $imageDiskDevice $count)
		if ! waitForStorageDevice $device;then
			continue
		fi
		mdadm --zero-superblock $device
		count=$((count + 1))
	done
}
#======================================
# pxeRaidStop
#--------------------------------------
function pxeRaidStop {
	local count=0
	local IFS=","
	for i in $PART;do
		mdadm --stop /dev/md$count
		count=$((count + 1))
	done
}
#======================================
# pxeSwapDevice
#--------------------------------------
function pxeSwapDevice {
	local field=0
	local count=0
	local device
	local IFS=","
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		if test $partID = "82" -o $partID = "S";then
			device=$(ddn $DISK $count)
			waitForStorageDevice $device
			echo $device
			return
		fi
	done
}
#======================================
# pxeRaidSwapDevice
#--------------------------------------
function pxeRaidSwapDevice {
	local field=0
	local count=0
	local mdcount=0
	local device
	local IFS=","
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		if test $partID = "82" -o $partID = "S";then
			device=/dev/md$mdcount
			waitForStorageDevice $device
			echo $device
			return
		fi
		mdcount=$((mdcount + 1))
	done
}
#======================================
# pxeRaidPartCheck
#--------------------------------------
function pxeRaidPartCheck {
	local count=0
	local field=0
	local n
	local raidLevel
	local raidDiskFirst
	local raidDiskSecond
	local device
	local IFS=";"
	local partSize
	local partID
	local partMount
	local IdFirst
	local IdSecond
	local raidFirst
	local raidSecond
	local size
	local maxDiffPlus=10240  # max 10MB bigger
	local maxDiffMinus=10240 # max 10MB smaller
	for n in $RAID;do
		case $field in
			0) raidLevel=$n     ; field=1 ;;
			1) raidDiskFirst=$n ; field=2 ;;
			2) raidDiskSecond=$n; field=3
		esac
	done
	IFS=","
	for i in $PART;do
		count=$((count + 1))
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		IdFirst="$(partitionID $raidDiskFirst $count)"
		IdSecond="$(partitionID $raidDiskSecond $count)"
		raidFirst=$(ddn $raidDiskFirst $count)
		raidSecond=$(ddn $raidDiskSecond $count)
		if [ "$IdFirst" != "fd" ] || ! waitForStorageDevice $raidFirst;then
			raidFirst=
		fi
		if [ "$IdSecond" != "fd" ] || ! waitForStorageDevice $raidSecond;then
			raidSecond=
		fi
		# /.../
		# RAID should be able to work in degraded mode when
		# one of the disks is missing
		# ----
		if [ -z "$raidFirst" -a -z "$raidSecond" ]; then
			return 1
		fi
		if [ "$partSize" == "x" ] ; then
			# partition use all available space
			continue
		fi
		for device in $raidFirst $raidSecond ; do
			size=$(partitionSize $device)
			if [ "$(( partSize * 1024 - size ))" -gt "$maxDiffMinus" -o \
				"$(( size - partSize * 1024 ))" -gt "$maxDiffPlus" ]
			then
				return 1
			fi
		done
	done
	return 0
}
#======================================
# pxePartitionSetupCheck
#--------------------------------------
function pxePartitionSetupCheck {
	# /.../
	# validation check for the PART line. So far this
	# function counts the given partition sizes and
	# checks if it's possible to setup those partitions
	# with respect to the available disk size
	# ----
	local field=0
	local count=0
	local IFS=","
	local reqsizeMB=0
	if [ -z "$DISK" ];then
		# no disk device available, might be a ram only
		# or diskless client
		return
	fi
	local haveKBytes=$(partitionSize $DISK)
	local haveMBytes=$((haveKBytes / 1024))
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n; field=1 ;;
		esac
		done
		if [ "$partSize" == "x" ] ; then
			# partition requests all available space
			# use a fake value of 10 MB as minimum
			reqsizeMB=$((reqsizeMB + 10))
		else
			# some size was requested, use value as MB size
			reqsizeMB=$((reqsizeMB + partSize))
		fi
	done
	if [ $reqsizeMB -gt $haveMBytes ];then
		systemException \
			"Requested partition sizes exceeds disk size" \
		"reboot"
	fi
}
#======================================
# pxePartCheck
#--------------------------------------
function pxePartCheck {
	# /.../
	# check the current partition table according to the
	# current setup of the PART line. Thus this function
	# checks if a new partition table setup compared to
	# the existing one was requested. Additionally the check
	# is clever enough to find out if the new partition
	# table setup would destroy data on the existing one
	# or if it only increases the partitions so that no
	# data loss is expected.
	# ----
	local count=0
	local field=0
	local n
	local partSize
	local partID
	local partMount
	local device
	local size
	local IFS
	local maxDiffPlus=10240  # max 10MB bigger
	local maxDiffMinus=10240 # max 10MB smaller
	IFS=","
	for i in $PART;do
		count=$((count + 1))
		field=0
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		device=$(ddn $DISK $count)
		if [ "$(partitionID $DISK $count)" != "$partID" ]; then
			return 1
		fi
		if ! waitForStorageDevice $device;then
			return 1
		fi
		if [ "$partSize" == "x" ] ; then
			# partition use all available space
			continue
		fi
		size=$(partitionSize $device)
		if [ "$(( partSize * 1024 - size ))" -gt "$maxDiffMinus" -o \
			"$(( size - partSize * 1024 ))" -gt "$maxDiffPlus" ]
		then
			return 1
		fi
	done
	return 0
}
#======================================
# pxeBootDevice
#--------------------------------------
function pxeBootDevice {
	local field=0
	local count=0
	local device
	local IFS=","
	for i in $PART;do
		field=0
		count=$((count + 1))
		IFS=";" ; for n in $i;do
		case $field in
			0) partSize=$n   ; field=1 ;;
			1) partID=$n     ; field=2 ;;
			2) partMount=$n;
		esac
		done
		if [ $partMount = "/boot" ];then
			device=$(ddn $DISK $count)
			waitForStorageDevice $device
			echo $device
			return
		fi
	done
}
#======================================
# startUtimer
#--------------------------------------
function startUtimer {
	local utimer=/usr/bin/utimer
	if [ ! -x $utimer ];then
		utimer=/utimer
	fi
	if [ -x $utimer ];then
		if [ ! -e /tmp/utimer ];then
			ln -s $UTIMER_INFO /tmp/utimer
		fi
		$utimer
		export UTIMER=$(cat /var/run/utimer.pid)
		if [ -f /iprocs ];then
			cat /iprocs | grep -v UTIMER_PID > /iprocs
		fi
		echo UTIMER_PID=$UTIMER >> /iprocs
	fi
}
#======================================
# setupBootPartition
#--------------------------------------
function setupBootPartition {
	local pSearch=83
	local mpoint
	unset NETBOOT_ONLY
	if [ "$haveLVM" = "yes" ];then
		#======================================
		# lvmboot
		#--------------------------------------
		test -z "$bootid" && export bootid=1
		mpoint=lvmboot
	elif [ "$haveBtrFS" = "yes" ];then
		#======================================
		# btrboot
		#--------------------------------------
		test -z "$bootid" && export bootid=2
		mpoint=btrboot
	elif [ "$haveClicFS" = "yes" ];then
		#======================================
		# clicboot
		#--------------------------------------
		test -z "$bootid" && export bootid=3
		mpoint=clicboot
	elif [ "$haveXFS" = "yes" ];then
		#======================================
		# btrboot
		#--------------------------------------
		test -z "$bootid" && export bootid=2
		mpoint=xfsboot
	elif \
		[ "$loader" = "syslinux" ] || \
		[ "$loader" = "extlinux" ] || \
		[ "$haveLuks" = "yes" ]
	then
		#======================================
		# syslboot / luksboot
		#--------------------------------------
		if [ -z "$bootid" ];then
			local FSTYPE_SAVE=$FSTYPE
			test "$loader" = "syslinux" && pSearch=6
			for i in 4 3 2;do
				pType=$(partitionID $imageDiskDevice $i)
				if [ "$pType" = $pSearch ];then
					probeFileSystem $(ddn $imageDiskDevice $i)
					if [ ! "$FSTYPE" = "luks" ]; then
						export bootid=$i
						break
					fi
				fi
			done
			FSTYPE=$FSTYPE_SAVE
		fi
		if [ "$haveLuks" = "yes" ];then
			mpoint=luksboot
		else
			mpoint=syslboot
		fi
	else
		#======================================
		# no separate boot partition
		#--------------------------------------
		if [ -z "$bootid" ];then
			export bootid=1
		fi
		return
	fi
	if [ -z "$bootid" ] && [[ $kiwi_iname =~ netboot ]];then
		# pxe boot env and no suitable boot partition found
		export NETBOOT_ONLY=yes
		return
	fi
	if [ -z "$imageDiskDevice" ];then
		# no disk device like for live ISO based on clicfs
		return
	fi
	if [ -z "$imageBootDevice" ] && [ ! -z "$bootid" ];then
		export imageBootDevice=$(ddn $imageDiskDevice $bootid)
	fi
	if [ ! -e $imageBootDevice ];then
		# no such boot device like for live ISO hybrid disk
		return
	fi
	#======================================
	# copy boot data from image to bootpart
	#--------------------------------------
	mkdir -p /$mpoint
	mount $imageBootDevice /$mpoint
	cp -a /mnt/boot /$mpoint
	if [ -e /boot.tgz ];then
		tar -xf /boot.tgz -C /$mpoint
	fi
	umount /$mpoint
	rmdir  /$mpoint
	#======================================
	# bind mount boot partition
	#--------------------------------------
	# the resetBootBind() function will resolve this to a
	# standard /boot mount when the bootloader will be
	# installed in preinit.
	# ---
	if ! isFSTypeReadOnly;then
		rm -rf /mnt/boot
		mkdir  /mnt/boot
	fi
	mkdir /mnt/$mpoint
	mount $imageBootDevice /mnt/$mpoint
	mount --bind \
		/mnt/$mpoint/boot /mnt/boot
}
#======================================
# isVirtioDevice
#--------------------------------------
function isVirtioDevice {
	if [ $haveDASD -eq 0 ] && [ $haveZFCP -eq 0 ];then
		return 0
	fi
	return 1
}
#======================================
# isDASDDevice
#--------------------------------------
function isDASDDevice {
	if [ $haveDASD -eq 1 ];then
		return 0
	fi
	return 1
}
#======================================
# isZFCPDevice
#--------------------------------------
function isZFCPDevice {
	if [ $haveZFCP -eq 1 ];then
		return 0
	fi
	return 1
}
#======================================
# runPreinitServices
#--------------------------------------
function runPreinitServices {
	# /.../
	# run the .sh scripts in /etc/init.d/kiwi while
	# inside the preinit stage of the kiwi boot process
	# ----
	local service=/etc/init.d/kiwi/$1
	if [ ! -d $service ];then
		Echo "kiwi service $service not found... skipped"
		return
	fi
	for script in $service/*.sh;do
		test -e $script && bash -x $script
	done
}
#======================================
# setupConsole
#--------------------------------------
function setupConsole {
	# /.../
	# setup the xvc and/or hvc console if the device is present
	# also remove the ttyS0 console if no ttyS0 device exists
	# ----
	local itab=/etc/inittab
	local stty=/etc/securetty
	if [ -e /sys/class/tty/xvc0 ];then
		if ! cat $itab | grep -v '^#' | grep -q xvc0;then
			echo "X0:12345:respawn:/sbin/mingetty --noclear xvc0 linux" >> $itab
			echo xvc0 >> $stty
		fi
	fi
	if [ -e /sys/class/tty/hvc0 ];then
		if ! cat $itab | grep -v '^#' | grep -q hvc0;then
			echo "H0:12345:respawn:/sbin/mingetty --noclear hvc0 linux" >> $itab
			echo hvc0 >> $stty
		fi
	fi
	if [ ! -e /sys/class/tty/ttyS0 ];then
		cat $itab | grep -vi 'ttyS0' > $itab.new && mv $itab.new $itab
	fi
}
#======================================
# cleanPartitionTable
#--------------------------------------
function cleanPartitionTable {
	# /.../
	# remove partition table and create a new msdos
	# table label if parted is in use
	# ----
	dd if=/dev/zero of=$imageDiskDevice bs=512 count=1 >/dev/null
	if [ $PARTITIONER = "parted" ];then
		parted -s $imageDiskDevice mklabel msdos
	fi
}
#======================================
# createSnapshotMap
#--------------------------------------
function createSnapshotMap {
	local readOnlyRootImage=$1
	local snapshotChunk=8
	local snapshotCount=100
	local reset=/tmp/resetSnapshotMap
	local diskLoop
	local snapLoop
	local orig_sectors
	local snap_sectors
	#======================================
	# cleanup
	#--------------------------------------
	unset snapshotMap
	#======================================
	# create root filesystem loop device
	#--------------------------------------
	diskLoop=$(losetup -s -f $readOnlyRootImage)
	if [ ! $? = 0 ];then
		return
	fi
	echo "losetup -d $diskLoop" > $reset
	if ! kpartx -a $diskLoop;then
		return
	fi
	echo "kpartx -d $diskLoop" >> $reset
	if searchVolumeGroup; then
		diskLoop=/dev/$VGROUP/LVRoot
		echo "vgchange -an" >> $reset
	else
		diskLoop=$(echo $diskLoop | cut -f3 -d '/')
		diskLoop=/dev/mapper/${diskLoop}p1
	fi
	#======================================
	# create snapshot loop device
	#--------------------------------------
	if ! dd if=/dev/zero of=/tmp/cow bs=1M count=$snapshotCount;then
		return
	fi
	if ! mkfs.ext3 -F /tmp/cow &>/dev/null;then
		return
	fi
	echo "rm -f /tmp/cow" >> $reset
	snapLoop=$(losetup -s -f /tmp/cow)
	if [ ! $? = 0 ];then
		return
	fi
	echo "losetup -d $snapLoop" >> $reset
	#======================================
	# setup device mapper tables
	#--------------------------------------
	orig_sectors=$(blockdev --getsize $diskLoop)
	snap_sectors=$(blockdev --getsize $snapLoop)
	echo "0 $orig_sectors linear $diskLoop 0" | \
		dmsetup create ms_data
	echo "dmsetup remove ms_data" >> $reset
	dmsetup create ms_origin --notable
	echo "dmsetup remove ms_origin" >> $reset
	dmsetup table ms_data | dmsetup load ms_origin
	dmsetup resume ms_origin
	dmsetup create ms_snap --notable
	echo "dmsetup remove ms_snap" >> $reset
	echo "0 $orig_sectors snapshot $diskLoop $snapLoop p $snapshotChunk" |\
		dmsetup load ms_snap
	echo "0 $orig_sectors snapshot-origin $diskLoop" | \
		dmsetup load ms_data
	dmsetup resume ms_snap
	dmsetup resume ms_data
	#======================================
	# export mount point
	#--------------------------------------
	export snapshotMap=/dev/mapper/ms_snap
}
#======================================
# resetSnapshotMap
#--------------------------------------
function resetSnapshotMap {
	local reset=/tmp/resetSnapshotMap
	if [ ! -f $reset ];then
		return
	fi
	tac $reset > $reset.run
	bash -x $reset.run
	unset snapshotMap
}
#======================================
# resetBootBind
#--------------------------------------
function resetBootBind {
	# /.../
	# remove the bind mount boot setup and replace with a
	# symbolic link to make the suse kernel update process
	# to work correctly
	# ----
	local bootdir
	#======================================
	# find bind boot dir
	#--------------------------------------
	for i in lvmboot btrboot clicboot xfsboot luksboot syslboot;do
		if [ -d /$i ];then
			bootdir=$i
			break
		fi
	done
	if [ -z "$bootdir" ];then
		return
	fi
	#======================================
	# reset bind mount to standard boot dir
	#--------------------------------------
	umount /boot
	mv /$bootdir/boot /$bootdir/tmp
	mv /$bootdir/tmp/* /$bootdir
	rmdir /$bootdir/tmp
	umount /$bootdir
	rmdir /$bootdir
	#======================================
	# update fstab entry
	#--------------------------------------
	cat /etc/fstab | grep -v bind > /etc/fstab.new
	mv /etc/fstab.new /etc/fstab
	cat /etc/fstab | sed -e s@/$bootdir@/boot@ > /etc/fstab.new
	mv /etc/fstab.new /etc/fstab
	#======================================
	# mount boot again
	#--------------------------------------
	mount $imageBootDevice /boot
	#======================================
	# check for syslinux requirements
	#--------------------------------------	
	if [ "$loader" = "syslinux" ];then
		# /.../
		# if syslinux is used we need to make sure to move
		# the kernel and initrd to /boot on the boot partition.
		# This is normally done by the boot -> . link but we
		# can't create links on fat
		# ----
		IFS="," ; for i in $KERNEL_LIST;do
			if test -z "$i";then
				continue
			fi
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			break
		done
		IFS=$IFS_ORIG
		mkdir -p /boot/boot
		mv /boot/$kernel /boot/boot/
		mv /boot/$initrd /boot/boot/
	fi
}
#======================================
# setupKernelLinks
#--------------------------------------
function setupKernelLinks {
	# /.../
	# check kernel names and links to kernel and initrd
	# according to the different boot-up situations
	# ----
	#======================================
	# mount boot partition if required
	#--------------------------------------
	local mountCalled=no
	if [ -e "$imageBootDevice" ] && blkid $imageBootDevice;then
		if kiwiMount $imageBootDevice "/mnt";then
			mountCalled=yes
		fi
	fi
	#======================================
	# Change to boot directory
	#--------------------------------------
	pushd /mnt/boot >/dev/null
	#======================================
	# remove garbage if possible 
	#--------------------------------------
	if [ $loader = "syslinux" ] || [ $loader = "extlinux" ];then
		rm -rf grub
	fi
	#======================================
	# setup if overlay filesystem is used
	#--------------------------------------
	if  [ "$OEM_KIWI_INITRD" = "yes" ] || \
		[ "$PXE_KIWI_INITRD" = "yes" ] || \
		isFSTypeReadOnly
	then
		# /.../
		# we are using a special root setup based on an overlay
		# filesystem. In this case we can't use the SuSE Linux
		# initrd but must stick to the kiwi boot system.
		# ----
		IFS="," ; for i in $KERNEL_LIST;do
			if test -z "$i";then
				continue
			fi
			kernel=`echo $i | cut -f1 -d:`
			initrd=`echo $i | cut -f2 -d:`
			break
		done
		IFS=$IFS_ORIG
		if [ "$loader" = "syslinux" ];then
			rm -f $initrd && mv initrd.vmx $initrd
			rm -f $kernel && mv linux.vmx  $kernel
		elif [ "$PXE_KIWI_INITRD" = "yes" ];then
			if [ ! -f initrd.kiwi ] && [ ! -f linux.kiwi ];then
				Echo "WARNING: can't find kiwi initrd/linux !"
				Echo -b "local boot will not work, maybe you forgot"
				Echo -b "to add KIWI_INITRD and KIWI_KERNEL in config.<MAC> ?"
			else
				if [ "$loader" = "syslinux" ];then
					rm -f $initrd && mv initrd.kiwi $initrd
					rm -f $kernel && mv linux.kiwi  $kernel
				else
					rm -f $initrd && ln -s initrd.kiwi $initrd
					rm -f $kernel && ln -s linux.kiwi  $kernel
				fi
			fi
		else
			rm -f $initrd && ln -s initrd.vmx $initrd
			rm -f $kernel && ln -s linux.vmx  $kernel
		fi
	fi	
	#======================================
	# make sure boot => . link exists
	#--------------------------------------
	if [ ! $loader = "syslinux" ] && [ ! -e boot ];then
		ln -s . boot
	fi
	#======================================
	# umount boot partition if required
	#--------------------------------------
	popd >/dev/null
	if [ "$mountCalled" = "yes" ];then
		umount /mnt
	fi
}
#======================================
# initialize
#--------------------------------------
function initialize {
	#======================================
	# Check partitioner capabilities
	#--------------------------------------
	if [ $PARTITIONER = "unsupported" ];then
		systemException \
			"Installed parted version is too old" \
		"reboot"
	fi
	#======================================
	# Check for hotfix kernel
	#--------------------------------------
	reloadKernel
	#======================================
	# Prevent blank screen
	#--------------------------------------
	if [ -x /usr/bin/setterm ];then
		setterm -powersave off -blank 0
	fi
	#======================================
	# Start boot timer (first stage)
	#--------------------------------------
	startUtimer
}

# vim: set noexpandtab:
