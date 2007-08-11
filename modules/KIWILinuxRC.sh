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
export PARTITIONER=sfdisk

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
	# close the kernel console, messages from the kernel
	# will not be displayed on the controling terminal
	# if DEBUG is set the kernel console remains open
	# ----
	if test "$DEBUG" = 0;then
		/usr/sbin/klogconsole -l 1
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
	/usr/sbin/klogconsole -l 7
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
		item=`echo "$line" | cut -d '=' -f2- | tr -d \'`
		Debug "$key=$item"
		eval export $key\=\"$item\"
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
	Echo "$1"
	case "$2" in
	"reboot")
		Echo "rebootException: reboot in 60 sec..."; sleep 60
		/sbin/reboot -f -i >/dev/null 2>&1
	;;
	"wait")
		Echo "waitException: waiting for ever..."
		while true;do sleep 100;done
	;;
	"shell")
		Echo "shellException: providing shell..."
		/bin/sh
	;;
	*)
		Echo "unknownException..."
	;;
	esac
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
	dd if=$1 of=/tmp/filesystem-$$ bs=128k count=1 >/dev/null 2>&1
	data=$(file /tmp/filesystem-$$ 2> /dev/null) && rm -f /tmp/filesystem-$$
	case $data in
		*ext3*)     FSTYPE=ext3 ;;
		*ext2*)     FSTYPE=ext2 ;;
		*ReiserFS*) FSTYPE=reiserfs ;;
		*cramfs*)   FSTYPE=cramfs ;;
		*Squashfs*) FSTYPE=squashfs ;;
		*)
			FSTYPE=unknown
		;;
	esac
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
# probeDeviceAlias
#--------------------------------------
function probeDeviceAlias {
	# /.../
	# create the modalias information file from all
	# registered devices of the kernel
	# ----
	modalias=/tmp/modalias
	cat > $modalias < /dev/null
	for i in `find /sys -name modalias 2>/dev/null`;do
		alias=`cat $i | grep pci:`
		if [ ! -z "$alias" ];then
			echo $alias >> $modalias
		fi
	done
	cat $modalias | sort | uniq > $modalias.new
	mv $modalias.new $modalias
}
#======================================
# probeDeviceInfo
#--------------------------------------
function probeDeviceInfo {
	# /.../
	# create the modinfo information file from all
	# installed kernel drivers
	# ----
	modinfo=/tmp/modinfo
	cat > $modinfo < /dev/null
	for file in `find /lib/modules/*/kernel/drivers -type f`;do
		/sbin/modinfo -F alias $file |\
			sed -e s@*@.*@g -e s@.@$file%\&@ \
		>> $modinfo
	done
	cat $modinfo | sort | uniq > $modinfo.new
	mv $modinfo.new $modinfo
}
#======================================
# probeDevices
#--------------------------------------
function probeDevices {
	# /.../
	# check the modalias with the modinfo file and load
	# all matching kernel modules into the kernel
	# ----
	DRIVER_GENERIC=0
	DRIVER_ATA_PIIX=0
	Echo "Including required kernel modules..."
	IFS=$IFS_ORIG
	probeDeviceInfo
	probeDeviceAlias
	IFS="%"; while read file info in;do
		grep -q $info $modalias >/dev/null 2>&1
		if [ $? = 0 ];then
			module=`basename $file`
			module=`echo $module | sed -e s@.ko@@`
			INITRD_MODULES="$INITRD_MODULES $module"
			if [ $module = "generic" ];then
				DRIVER_GENERIC=1
			elif [  $module = "ata_piix" ] ; then
				DRIVER_ATA_PIIX=1
			else
				Echo "Probing module: $module"
				modprobe $module >/dev/null 2>&1
			fi
		fi
	done < $modinfo
	IFS=$IFS_ORIG
	#======================================
	# Handle special cases
	#--------------------------------------
	if [ $DRIVER_ATA_PIIX -eq 1 ] ; then
		Echo "Probing module: ata_piix"
		modprobe ata_piix >/dev/null 2>&1
	fi
	if [ $DRIVER_GENERIC -eq 1 ] ; then
		Echo "Probing module: generic"
		modprobe generic >/dev/null 2>&1
	fi
}
#======================================
# CDDevice
#--------------------------------------
function CDDevice {
	# /.../
	# detect CD/DVD device. The function use the information
	# from /proc/sys/dev/cdrom/info to activate the drive
	# ----
	for module in usb-storage sr_mod cdrom ide-cd BusLogic;do
		/sbin/modprobe $module
	done
	info="/proc/sys/dev/cdrom/info"
	cddevs=`cat $info | grep "drive name:" | cut -f2 -d: | tr "\t" ":"`
	cddevs=`echo $cddevs | cut -f3- -d:`
	cddevs=`echo $cddevs | tr -d [:space:]`
	IFS=":"; for i in $cddevs;do
		if [ -b "/dev/$i" ];then
			test -z $cddev && cddev=/dev/$i || cddev=$cddev:/dev/$i
		fi
	done
	IFS=$IFS_ORIG
	if [ -z $cddev ]; then
		systemException \
			"Failed to detect CD drive !" \
		"reboot"
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
	CDDevice
	mkdir -p /cdrom
	IFS=":"; for i in $cddev;do
		mount $i /cdrom &>/dev/null
		if [ -f $LIVECD_CONFIG ];then
			cddev=$i; return
		fi
		umount $i &>/dev/null
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
# searchSwapSpace
#--------------------------------------
function searchSwapSpace {
	# /.../
	# search for a type=82 swap partition
	# ----
	hwapp=/usr/sbin/hwinfo
	for diskdev in `$hwapp --disk | grep "Device File:" | cut -f2 -d:`;do
		for disknr in 1 2 3 4;do
			id=`/sbin/sfdisk --print-id $diskdev $disknr 2>/dev/null`
			if [ "$id" = "82" ];then
				echo $diskdev$disknr
				break
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
	hwapp=/usr/sbin/hwinfo
	for diskdev in `$hwapp --disk | grep "Device File:" | cut -f2 -d:`;do
		for disknr in 1 2 3 4;do
			id=`/sbin/sfdisk --print-id $diskdev $disknr 2>/dev/null`
			if [ -z $id ];then
				id=0
			fi
			if [ "$id" -ne 82 ] && [ "$id" -ne 0 ];then
				echo $diskdev$disknr
				break
			fi
		done
	done
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
	hwnet=/usr/sbin/hwinfo
	hwstr="Driver Activation Cmd:"
	IFS="
	"
	for i in `$hwnet --netcard | grep "$hwstr" | cut -f2 -d:`;do
		hwmod=`echo $i | tr -d \" | cut -f3 -d" "`
		hwcmd="$hwcmd:$hwmod"
	done
	if [ ! -z "$hwcmd" ];then
		networkModule=$hwcmd
	fi
	IFS=$IFS_ORIG
}
#======================================
# setupNetwork
#--------------------------------------
function setupNetwork {
	# /.../
	# setup the eth0 network interface using a dhcp
	# request. On success the dhcp info file is imported
	# into the current shell environment and the nameserver
	# information is written to /etc/resolv.conf
	# ----
	dhcpcd eth0 >/dev/null 2>&1
	if test $? != 0;then
		systemException \
			"Failed to setup DHCP network interface !" \
		"reboot"
	fi
	ifconfig lo 127.0.0.1 netmask 255.0.0.0 up
	for i in 1 2 3 4 5 6 7 8 9 0;do
		[ -s /var/lib/dhcpcd/dhcpcd-eth0.info ] && break
		sleep 5
	done
	importFile < /var/lib/dhcpcd/dhcpcd-eth0.info
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
		[ -z "$imageServer" ]  && imageServer=$TSERVER
		[ -z "$imageBlkSize" ] && imageBlkSize=8192
		atftp -g -r $imageMD5s -l /etc/image.md5 $imageServer >/dev/null 2>&1
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
	dd if=/dev/zero of=$diskDevice bs=32M >/dev/null 2>&1
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
	diskPartitionType=`sfdisk -c $diskPD $diskID 2>/dev/null`
	if test "$diskPartitionType" = "8e";then
		Echo "Creating Volume group [systemvg]"
		pvcreate $diskPartition >/dev/null 2>&1
		vgcreate systemvg $diskPartition >/dev/null 2>&1
	else
		# .../
		# There is no need to create a filesystem on the partition
		# because the image itself contains the filesystem
		# ----
		# mke2fs $diskPartition >/dev/null 2>&1
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
		fillPartition
	fi
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
	dd if=/dev/zero of=$DISK bs=512 count=1 >/dev/null 2>&1 && \
		/usr/sbin/parted -s $DISK mklabel msdos
	if [ $? -ne 0 ];then
		systemException \
			"Failed to clean partition table on: $DISK !" \
			"reboot"
	fi
	p_opts="-s $DISK unit s print"
	p_size=`/usr/sbin/parted $p_opts | grep "Disk" | cut -f2 -d: | cut -f1 -ds`
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
	eval $p_ids >/dev/null 2>&1
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

	dd if=/dev/zero of=$diskDevice bs=512 count=1 >/dev/null 2>&1
	sfdisk -uM --force $diskDevice < $PART_FILE >/dev/null 2>&1
	if test $? != 0;then
		systemException \
			"Failed to create partition table on: $diskDevice !" \
			"reboot"
	fi

	verifyOutput=`sfdisk -V $diskDevice 2>&1`
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
	diskPartitionType=`sfdisk -c $diskDevice 2 2>/dev/null`
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
		if [ -f /mnt/boot/vmlinuz ] && [ -f /mnt/boot/initrd ];then
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
# validateBlockSize
#--------------------------------------
function validateBlockSize {
	# /.../
	# check the block size value. atftp limits to a maximum of
	# 32768 blocks, so the block size must be checked according
	# to the size of the image
	# ----
	isize=`expr $blocks \* $blocksize`
	isize=`expr $isize / 32768`
	if [ $isize -gt $imageBlkSize ];then
		imageBlkSize=`expr $isize + 1024`
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
    echo $1 | grep -q "File not found"
    if [ $? = 0 ];then
        return 1
    fi
    echo $1 | grep -q "aborting"
    if [ $? = 0 ];then
        return 1
    fi
    return 0
}
#======================================
# validateRAM
#--------------------------------------
function validateRAM {
	# /.../
	# check if the image fits into the ramdisk.
	# An information about the sizes is printed out
	# ----
	needRAM=`expr $blocks \* $blocksize`
	needRAM=`expr $needRAM / 1024`
	needRAM=`expr $needRAM + 128`
	needMByte=`expr $needRAM / 1024`
	hasRAM=`cat /proc/meminfo | grep MemFree | cut -f2 -d:`
	hasRAM=`echo $hasRAM | cut -f1 -d" "`
	hasMByte=`expr $hasRAM / 1024`
	Echo "Have size: $imageDevice -> $hasRAM KBytes [ $hasMByte MB ]"
	Echo "Need size: $needRAM KBytes [ $needMByte MB ]"
	if test $hasRAM -gt $needRAM;then
		return 0
	fi
	return 1
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
		kernelKey=`echo $i | cut -f1 -d=`
		kernelVal=`echo $i | cut -f2 -d=`
		eval $kernelKey=$kernelVal
	done
}
#======================================
# checkTFTP
#--------------------------------------
function checkTFTP {
	# /.../
	# check the kernel commandline parameter kiwitftp.
	# If it exists its contents will be used as tftp
	# server address stored in the TSERVER variabe
	# ----
	if [ ! -z $kiwitftp ];then
		Echo "Found TFTP server in kernel cmdline"
		TSERVER=$kiwitftp
	fi
}

#======================================
# mountSystem
#--------------------------------------
function mountSystem () {
	retval=0
	OLDIFS=$IFS
	IFS=$IFS_ORIG
	mountDevice=$imageRootDevice
	if test ! -z $1;then
		mountDevice=$1
	fi
	if test ! -z $UNIONFS_CONFIG;then
		roDir=/ro_branch
		rwDir=/rw_branch
		xiDir=/xino
		for dir in $roDir $rwDir $xiDir;do
			mkdir -p $dir
		done
		rwDevice=`echo $UNIONFS_CONFIG | cut -d , -f 1`
		roDevice=`echo $UNIONFS_CONFIG | cut -d , -f 2`
		unionFST=`echo $UNIONFS_CONFIG | cut -d , -f 3`
		echo $rwDevice | grep -q ram
		if [ $? = 0 ];then
			# /.../
			# write part is a ram location, use tmpfs for ram
			# disk data storage
			# ----
			mount -t tmpfs tmpfs $rwDir >/dev/null 2>&1 || retval=1
		else
			# /.../
			# write part is not a ram disk, create ext2 filesystem on it
			# check and mount the filesystem
			# ----
			if test $LOCAL_BOOT = "no" && test $systemIntegrity = "clean";then
				if
					test "$RELOAD_IMAGE" = "yes" || \
					! mount $rwDevice $rwDir >/dev/null 2>&1
				then
					Echo "Creating EXT2 filesystem for RW data on $rwDevice..."
					if ! mke2fs $rwDevice >/dev/null 2>&1;then
						systemException \
							"Failed to create ext2 filesystem" \
						"reboot"
					fi
					Echo "Checking EXT2 write extend..."
					e2fsck -y -f $rwDevice >/dev/null 2>&1
				else
					umount $rwDevice
				fi
			fi
			if ! mount $rwDevice $rwDir >/dev/null 2>&1;then
				retval=1
			fi
		fi
		if ! mount -t squashfs $roDevice $roDir >/dev/null 2>&1;then
			if ! mount $roDevice $roDir >/dev/null 2>&1;then
				retval=1
			fi
		fi
		if [ $unionFST = "aufs" ];then
			mount -t tmpfs tmpfs $xiDir >/dev/null 2>&1 || retval=1
			mount -t aufs \
				-o dirs=$rwDir=rw:$roDir=ro,xino=$xiDir/.aufs.xino none /mnt \
			>/dev/null 2>&1 || retval=1
		else
			mount -t unionfs \
				-o dirs=$rwDir=rw:$roDir=ro none /mnt
			>/dev/null 2>&1 || retval=1
		fi
		usleep 500000
	else
		mount $mountDevice /mnt >/dev/null 2>&1
		retval=$?
	fi
	IFS=$OLDIFS
	return $retval
}

#======================================
# umountSystem
#--------------------------------------
function umountSystem () {
	umount /mnt >/dev/null 2>&1
	if test ! -z "$UNIONFS_CONFIG";then
		umount /ro_branch >/dev/null 2>&1
		umount /rw_branch >/dev/null 2>&1
		umount /xino >/dev/null 2>&1
	fi
}

#======================================
# cleanDirectory
#--------------------------------------
function cleanDirectory () {
	directory=$1
	shift 1
	save=$@

	tmpdir=`mktemp -d`
	for saveItem in $save;do
		mv $directory/$saveItem $tmpdir >/dev/null 2>&1
	done
	rm -rf $directory/*
	mv $tmpdir/* $directory
	rm -rf $tmpdir
}

#======================================
# cleanInitrd
#--------------------------------------
function cleanInitrd () {
	cp /usr/bin/chroot /bin
	for dir in /*;do
		case "$dir" in
			"/lib")   continue ;;
			"/lib64") continue ;;
			"/bin")   continue ;;
			"/mnt")   continue ;;
			"/ro_branch") continue ;;
			"/rw_branch") continue ;;
			"/xino")  continue ;;
			"/dev")   continue ;;
		esac
		rm -rf $dir/* >/dev/null 2>&1
	done
	# mount opens fstab so we give them one
	touch /etc/fstab
}

#======================================
# searchAlternativeConfig
#--------------------------------------
function searchAlternativeConfig () {
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
		result=`atftp -g \
			-r KIWI/config.$hexippart -l $CONFIG $TSERVER 2>&1 | head -n 1`
		if test -s $CONFIG;then
			break
		fi
		let STEP=STEP-1
	done
	# Check config.default if no hex config was found
	if test ! -s $CONFIG;then
		Echo "Checking for config file: config.default"
		result=`atftp -g \
			-r KIWI/config.default -l $CONFIG $TSERVER 2>&1 | head -n 1`
	fi
}
