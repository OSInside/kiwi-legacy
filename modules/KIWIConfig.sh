#================
# FILE          : KIWIConfig.sh
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module contains common used functions
#               : for the config.sh image scripts
#               : 
#               :
# STATUS        : Development
#----------------
#======================================
# work in POSIX environment
#--------------------------------------
export LANG=C
export LC_ALL=C
#======================================
# check base tools
#--------------------------------------
for tool in basename dirname;do
	if [ -x /bin/$tool ] && [ ! -e /usr/bin/$tool ];then
		ln -s /bin/$tool /usr/bin/$tool
	fi
done
for tool in setctsid klogconsole;do
	if [ -x /usr/bin/$tool ] && [ ! -e /usr/sbin/$tool ];then
		ln -s /usr/bin/$tool /usr/sbin/$tool
	fi
done
#======================================
# suseInsertService
#--------------------------------------
function suseInsertService {
	# /.../
	# Recursively insert a service. If there is a service
	# required for this service it will be inserted first
	# -----
	local service=$1
	if [ -f /bin/systemd ];then
		systemctl enable $service.service
	else
		if /sbin/insserv $service;then
			echo "Service $service inserted"
		else
			if ! /sbin/insserv --recursive $service;then
				echo "$service: recursive insertion failed...skipped"
			fi
		fi
	fi
}

#======================================
# suseRemoveService
#--------------------------------------
function suseRemoveService {
	# /.../
	# Remove a service and its dependant services
	# using insserv -r
	# ----
	local service=$1
	if [ -f /bin/systemd ];then
		systemctl disable $service.service
	else
		service=/etc/init.d/$service
		if /sbin/insserv -r $service;then
			echo "Service $service removed"
		else
			if ! /sbin/insserv --recursive -r $service;then
				echo "$service: recursive removal failed...skipped"
			fi
		fi
	fi
}

#======================================
# suseActivateServices
#--------------------------------------
function suseActivateServices {
	# /.../
	# Check all services in /etc/init.d/ and activate them
	# by calling insertService
	# -----
	for i in /etc/init.d/*;do
		if [ -x $i ] && [ -f $i ];then
			echo $i | grep -q skel
			if [ $? = 0 ];then
				continue
			fi
			suseInsertService $i
		fi
	done
}

#======================================
# suseService
#--------------------------------------
function suseService {
	# /.../
	# if a service exist then enable or disable it
	# example : suseService apache2 on
	# example : suseService apache2 off
	# ----
	local service=$1
	local action=$2
	if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$service ];then
		if [ $action = on ];then
			suseInsertService $service
		elif [ $action = off ];then
			suseRemoveService $service
		fi
	fi
}

#======================================
# suseServiceDefaultOn
#--------------------------------------
function suseActivateDefaultServices {
	# /.../
	# Some basic services that needs to be on.
	# ----
	local services=(
		boot.rootfsck
		boot.cleanup
		boot.localfs
		boot.localnet
		boot.clock
		policykitd
		dbus
		consolekit
		haldaemon
		network
		atd
		syslog
		cron
		kbd
	)
	for i in "${services[@]}";do
		if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$i ];then
			suseInsertService $i
		fi
	done
}

#======================================
# suseCloneRunlevel
#--------------------------------------
function suseCloneRunlevel {
	# /.../
	# Clone the given runlevel to work in the same way
	# as the default runlevel 3.
	# ----
	local clone=$1
	if [ -z "$clone" ];then
		echo "suseCloneRunlevel: no runlevel given... abort"
		return 1
	fi
	if [ $clone = 3 ];then
		echo "suseCloneRunlevel: can't clone myself... abort"
		return 1
	fi
	if [ -d /etc/init.d/rc$clone.d ];then
		rm -rf /etc/init.d/rc$clone.d
	fi
	cp -a /etc/init.d/rc3.d /etc/init.d/rc$clone.d
	sed -i -e s"@#l$clone@l4@" /etc/inittab
}

#======================================
# suseImportBuildKey
#--------------------------------------
function suseImportBuildKey {
	# /.../
	# Add missing gpg keys to rpm database
	# ----
	local KEY
	local TDIR=$(mktemp -d)
	if [ ! -d "$TDIR" ]; then
		echo "suseImportBuildKey: Failed to create temp dir"
		return
	fi
	pushd "$TDIR"
	/usr/lib/rpm/gnupg/dumpsigs /usr/lib/rpm/gnupg/suse-build-key.gpg
	ls gpg-pubkey-*.asc | while read KFN; do
		KEY=$(basename "$KFN" .asc)
		rpm -q "$KEY" >/dev/null
		[ $? -eq 0 ] && continue
		echo "Importing $KEY to rpm database"
		rpm --import "$KFN"
	done
	popd
	rm -rf "$TDIR"
}

#======================================
# baseSetupOEMPartition
#--------------------------------------
function baseSetupOEMPartition {
	local oemfile=/config.oempartition
	if [ -e $oemfile ];then
		echo "config.oempartition already defined:"
		cat $oemfile
		return
	fi
	if [ ! -z "$kiwi_oemreboot" ];then
		echo "Setting up OEM_REBOOT=1"
		echo "OEM_REBOOT=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemrebootinteractive" ];then
		echo "Setting up OEM_REBOOT_INTERACTIVE=1"
		echo "OEM_REBOOT_INTERACTIVE=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemsilentboot" ];then
		echo "Setting up OEM_SILENTBOOT=1"
		echo "OEM_SILENTBOOT=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemshutdown" ];then
		echo "Setting up OEM_SHUTDOWN=1"
		echo "OEM_SHUTDOWN=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemshutdowninteractive" ];then
		echo "Setting up OEM_SHUTDOWN_INTERACTIVE=1"
		echo "OEM_SHUTDOWN_INTERACTIVE=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemalign" ];then
		echo "Setting up OEM_ALIGN=1"
		echo "OEM_ALIGN=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oembootwait" ];then
		echo "Setting up OEM_BOOTWAIT=1"
		echo "OEM_BOOTWAIT=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemunattended" ];then
		echo "Setting up OEM_UNATTENDED=1"
		echo "OEM_UNATTENDED=1" >> $oemfile
	fi
	if [ -z "$kiwi_oemswap" ];then
		echo "Setting up OEM_WITHOUTSWAP=1"
		echo "OEM_WITHOUTSWAP=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oempartition_install" ];then
		echo "Setting up OEM_PARTITION_INSTALL=1"
		echo "OEM_PARTITION_INSTALL=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemswapMB" ];then
		echo "Setting up OEM_SWAPSIZE=$kiwi_oemswapMB"
		echo "OEM_SWAPSIZE=$kiwi_oemswapMB" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemrootMB" ];then
		echo "Setting up OEM_SYSTEMSIZE=$kiwi_oemrootMB"
		echo "OEM_SYSTEMSIZE=$kiwi_oemrootMB" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemtitle" ];then
		echo "Setting up OEM_BOOT_TITLE=$kiwi_oemtitle"
		echo "OEM_BOOT_TITLE=\"$kiwi_oemtitle\"" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemkboot" ];then
		echo "Setting up OEM_KIWI_INITRD=$kiwi_oemkboot"
		echo "OEM_KIWI_INITRD=$kiwi_oemkboot" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemrecovery" ];then
		echo "Setting up OEM_RECOVERY=1"
		echo "OEM_RECOVERY=1" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemrecoveryID" ];then
		echo "Setting up OEM_RECOVERY_ID=$kiwi_oemrecoveryID"
		echo "OEM_RECOVERY_ID=$kiwi_oemrecoveryID" >> $oemfile
	fi
	if [ ! -z "$kiwi_oemrecoveryInPlace" ];then
		echo "Setting up OEM_RECOVERY_INPLACE=1"
		echo "OEM_RECOVERY_INPLACE=1" >> $oemfile
	fi
}

#======================================
# baseSetupUserPermissions
#--------------------------------------
function baseSetupUserPermissions {
	while read line;do
		dir=`echo $line | cut -f6 -d:`
		uid=`echo $line | cut -f3 -d:`
		usern=`echo $line | cut -f1 -d:`
		group=`echo $line | cut -f4 -d:`
		if [ -d "$dir" ] && [ $uid -gt 200 ] && [ $usern != "nobody" ];then
			group=`cat /etc/group | grep "$group" | cut -f1 -d:`
			chown -c -R $usern:$group $dir/*
		fi
	done < /etc/passwd
}

#======================================
# baseSetupBoot
#--------------------------------------
function baseSetupBoot {
	if [ -f /linuxrc ];then
		cp linuxrc init
		exit 0
	fi
}

#======================================
# suseConfig
#--------------------------------------
function suseConfig {
	#======================================
	# keytable
	#--------------------------------------
	if [ ! -z "$kiwi_keytable" ];then
		baseUpdateSysConfig \
			/etc/sysconfig/keyboard KEYTABLE $kiwi_keytable
	fi
	#======================================
	# locale
	#--------------------------------------
	if [ ! -z "$kiwi_language" ];then
		language=$(echo $kiwi_language | cut -f1 -d,).UTF-8
		baseUpdateSysConfig \
			/etc/sysconfig/language RC_LANG $language
	fi
	#======================================
	# timezone
	#--------------------------------------
	if [ ! -z "$kiwi_timezone" ];then
		if [ -f /usr/share/zoneinfo/$kiwi_timezone ];then
			cp /usr/share/zoneinfo/$kiwi_timezone /etc/localtime
			baseUpdateSysConfig \
				/etc/sysconfig/clock TIMEZONE $kiwi_timezone
		else
			echo "timezone: $kiwi_timezone not found"
		fi
	fi
	#======================================
	# hwclock
	#--------------------------------------
	if [ ! -z "$kiwi_hwclock" ];then
		baseUpdateSysConfig \
			/etc/sysconfig/clock HWCLOCK "--$kiwi_hwclock"
	fi
	#======================================
	# SuSEconfig
	#--------------------------------------
	if [ -x /sbin/SuSEconfig ];then
		SuSEconfig
		SuSEconfig --module permissions
	fi
}

#======================================
# baseGetPackagesForDeletion
#--------------------------------------
function baseGetPackagesForDeletion {
	echo $kiwi_delete
}

#======================================
# baseGetProfilesUsed
#--------------------------------------
function baseGetProfilesUsed {
	echo $kiwi_profiles
}

#======================================
# baseCleanMount
#--------------------------------------
function baseCleanMount {
	umount /proc/sys/fs/binfmt_misc
	umount /proc
	umount /dev/pts
	umount /sys
}

#======================================
# baseStripMans 
#--------------------------------------
function baseStripMans {
	# /..,/
	# remove all manual pages, except 
	# one given as parametr
	#
	# params - name of keep man pages
	# example baseStripMans less
	# ----
	local keepMans="$@"
	local directories="
		/opt/gnome/share/man
		/usr/local/man
		/usr/share/man
		/opt/kde3/share/man/packages
	"
	find $directories -mindepth 1 -maxdepth 2 -type f 2>/dev/null |\
		baseStripAndKeep ${keepMans}
}

#======================================
# baseStripDocs 
#--------------------------------------
function baseStripDocs {
	# /.../
	# remove all documentation, except 
	# copying license copyright
	# ----
	local docfiles
	local directories="
		/opt/gnome/share/doc/packages
		/usr/share/doc/packages
		/opt/kde3/share/doc/packages
	"
	for dir in $directories; do
		docfiles=$(find $dir -type f |grep -iv "copying\|license\|copyright")
		rm -f $docfiles
	done
	rm -rf /usr/share/info
	rm -rf /usr/share/man
}
#======================================
# baseStripLocales
#--------------------------------------
function baseStripLocales {
	local keepLocales="$@"
	local directories="
		/usr/lib/locale
	"
	find $directories -mindepth 1 -maxdepth 1 -type d 2>/dev/null |\
		baseStripAndKeep ${keepLocales}
	rm -f /usr/lib/gconv/*
}

#======================================
# baseStripTranslations
#--------------------------------------
function baseStripTranslations {
	local keepMatching="$@"
	find /usr/share/locale -name "*.mo" | grep -v $keepMatching | xargs rm -f
}

#======================================
# baseStripInfos 
#--------------------------------------
function baseStripInfos {
	# /.../
	# remove all info files, 
	# except one given as parametr
	#
	# params - name of keep info files
	# ----
	local keepInfos="$@"
	local directories="
		/usr/share/info
	"
	find $directories -mindepth 1 -maxdepth 1 -type f 2>/dev/null |\
		baseStripAndKeep "${keepInfos}"
}
#======================================
# baseStripAndKeep
#--------------------------------------
function baseStripAndKeep {
	# /.../
	# helper function for strip* functions
	# read stdin lines of files to check 
	# for removing
	# - params - files which should be keep
	# ----
	local keepFiles="$@"
	while read file; do
			local baseFile=`/usr/bin/basename $file`
			local found="no"
			for keep in $keepFiles;do
					if echo $baseFile | grep -q $keep; then
							found="yes"
							break
					fi
			done
			if test $found = "no";then
				   Rm -rf $file
			fi
	done
}
#======================================
# baseStripTools
#--------------------------------------
function baseStripTools {
	local tpath=$1
	local tools=$2
	for file in `find $tpath`;do
		found=0
		base=`/usr/bin/basename $file`
		for need in $tools;do
			if [ $base = $need ];then
				found=1
				break
			fi
		done
		if [ $found = 0 ] && [ ! -d $file ];then
			Rm -fv $file
		fi
	done
}
#======================================
# suseStripPackager 
#--------------------------------------
function suseStripPackager {
	# /.../ 
	# remove smart o zypper packages and db 
	# files. Also remove rpm package and db 
	# if "-a" given
	#
	# params [-a]
	# ----
	local removerpm=falseq
	if [ ! -z ${1} ] && [ $1 = "-a" ]; then
		removerpm=true
	fi
	
	#zypper#
	Rpm -e --nodeps zypper libzypp satsolver-tools
	Rm -rf /var/lib/zypp
	
	#smart
	Rpm -e --nodeps smart smart-gui
	Rm -rf /var/lib/smart
	
	if [ $removerpm = true ]; then
		Rpm -e --nodeps rpm 
		Rm -rf /var/lib/rpm
	fi
}
#======================================
# baseStripRPM
#--------------------------------------
function baseStripRPM {
	# /.../
	# remove rpms defined in config.xml 
	# under image=delete section
	# ----
	for i in `baseGetPackagesForDeletion`;do
		Rpm -e --nodeps --noscripts $i
	done
}
#======================================
# baseSetupInPlaceSVNRepository
#--------------------------------------
function baseSetupInPlaceSVNRepository {
	# /.../
	# create an in place subversion repository for the
	# specified directories. A standard call could look like this
	# baseSetupInPlaceSVNRepository /etc /srv /var/log
	# ----
	local paths=$1
	local repo=/var/adm/sys-repo
	if [ ! -x /usr/bin/svn ];then
		echo "subversion not installed... skipped"
		return
	fi
	svnadmin create $repo
	chmod 700 $repo
	svn mkdir -m created file:///$repo/trunk
	local ifss=$IFS
	local subp=""
	for dir in $paths;do
		subp=""
		IFS="/"; for n in $dir;do
			if [ -z $n ];then
				continue
			fi
			subp="$subp/$n"
			svn mkdir -m created file:///$repo/trunk/$subp
		done
	done
	IFS=$ifss
	for dir in $paths;do
		chmod 700 $dir/.svn
		svn add $dir/*
		find $dir -name .svn | xargs chmod 700
		svn ci -m initial $dir
	done
}

#======================================
# baseSetupPlainTextGITRepository
#--------------------------------------
function baseSetupPlainTextGITRepository {
	# /.../
	# create an in place git repository of the root
	# directory containing all plain/text files.
	# ----
	if [ ! -x /usr/bin/git ];then
		echo "git not installed... skipped"
		return
	fi
	pushd /
	local ignore=""
	#======================================
	# directories to ignore
	#--------------------------------------
	local dirs="
		/sys /dev /var/log /home /media /var/run /var/tmp /tmp /var/lock
		/image /var/spool /var/cache /var/lib /boot /root /var/adm
		/usr/share/doc /base-system /usr/lib /usr/lib64 /usr/bin /usr/sbin
		/usr/share/man /proc /bin /sbin /lib /lib64 /opt
		/usr/share/X11 /.git
	"
	#======================================
	# files to ignore
	#--------------------------------------
	local files="
		./etc/Image* *.lock ./etc/resolv.conf *.gif *.png
		*.jpg *.eps *.ps *.la *.so */lib */lib64 */doc */zoneinfo
	"
	#======================================
	# creae .gitignore and find list
	#--------------------------------------
	for entry in $files;do
		echo $entry >> .gitignore
		if [ -z "$ignore" ];then
			ignore="-wholename $entry"
		else
			ignore="$ignore -or -wholename $entry"
		fi
	done
	for entry in $dirs;do
		echo $entry >> .gitignore
		if [ -z "$ignore" ];then
			ignore="-path .$entry"
		else
			ignore="$ignore -or -path .$entry"
		fi
	done
	#======================================
	# init git base
	#--------------------------------------
	git init
	#======================================
	# find all text/plain files except ign
	#--------------------------------------
	for i in `find . \( $ignore \) -prune -o -print`;do
		file=`echo $i | cut -f2 -d.`
		if file -i $i | grep -q "text/*";then
			git add $i
		fi
		if file -i $i | grep -q "application/x-shellscript";then
			git add $i
		fi
		if file -i $i | grep -q "application/x-awk";then
			git add $i
		fi
		if file -i $i | grep -q "application/x-c";then
			git add $i
		fi
		if file -i $i | grep -q "application/x-c++";then
			git add $i
		fi
		if file -i $i | grep -q "application/x-not-regular-file";then
			echo $file >> .gitignore
		fi
		if file -i $i | grep -q "application/x-gzip";then
			echo $file >> .gitignore
		fi
		if file -i $i | grep -q "application/x-empty";then
			echo $file >> .gitignore
		fi
	done
	#======================================
	# commit the git
	#--------------------------------------
	git commit -m "deployed"
	popd
}

#======================================
# baseSetupInPlaceGITRepository
#--------------------------------------
function baseSetupInPlaceGITRepository {
	# /.../
	# create an in place git repository of the root
	# directory. This process may take some time and you
	# may expect problems with binary data handling
	# ----
	if [ ! -x /usr/bin/git ];then
		echo "git not installed... skipped"
		return
	fi
	pushd /
	rm -rf .git
	cat > .gitignore < /dev/null
	local files="
		/bin/ /boot/ /dev/ /image/ /lib/ /lib64/ /lost+found/ /media/ /mnt/
		/opt/ /proc/ /sbin/ /sys/ /tmp/ /var/ /usr/ *.lock /etc/Image*
		/base-system/ /.broken /.buildenv .bash_history /.kconfig /.profile
		/etc/mtab
	"
	set -o noglob on
	for entry in $files;do
		echo $entry >> .gitignore
	done
	set -o noglob off
	git init && git add -A && \
	git commit -m "deployed"
	popd
}
#======================================
# Rm  
#--------------------------------------
function Rm {
	# /.../
	# delete files & anounce it to log
	# ----
	Debug "rm $@"
	rm $@
}

#======================================
# Rpm  
#--------------------------------------
function Rpm {
	# /.../
	# all rpm function & anounce it to log
	# ----
	Debug "rpm $@"
	rpm $@
}
#======================================
# Echo
#--------------------------------------
function Echo {
	# /.../
	# print a message to the controling terminal
	# ----
	local option=""
	local prefix="----->"
	local optn=""
	local opte=""
	while getopts "bne" option;do
		case $option in
			b) prefix="      " ;;
			n) optn="-n" ;;
			e) opte="-e" ;;
			*) echo "Invalid argument: $option" ;;
		esac
	done
	shift $(($OPTIND - 1))
	echo $optn $opte "$prefix $1"
	OPTIND=1
}
#======================================
# Debug
#--------------------------------------
function Debug {
	# /.../
	# print message if variable DEBUG is set to 1
	# -----
	if test "$DEBUG" = 1;then
		echo "+++++> (caller:${FUNCNAME[1]}:${FUNCNAME[2]} )  $@"
	fi
}
#======================================
# baseSetupBusyBox
#--------------------------------------
function baseSetupBusyBox {
	# /.../
	# activates busybox if installed for all links from
	# the busybox/busybox.links file - you can choose custom apps to
	# be forced into busybox with the "-f" option as first parameter
	# ---
	# example: baseSetupBusyBox -f /bin/zcat /bin/vi
	# ---
	local applets=""
	local force=no
	local busyboxlinks=/usr/share/busybox/busybox.links
	if ! rpm -q --quiet busybox; then
		echo "Busybox not installed... skipped"
		return 0
	fi
	if [ $# -gt 0 ] && [ "$1" = "-f" ]; then
		force=yes
		shift
	fi
	if [ $# -gt 0 ]; then
		for i in "$@"; do
			if grep -q "^$i$" "$busyboxlinks"; then 
				applets="${applets} $i"
			fi
		done
	else
		applets=`cat "$busyboxlinks"`
	fi
	for applet in $applets; do
		if [ ! -f "$applet" ] || [ "$force" = "yes" ]; then
			echo "Busybox Link: ln -sf /usr/bin/busybox $applet"
			ln -sf /usr/bin/busybox "$applet"
		fi
	done
}

#======================================
# stripUnusedLibs
#--------------------------------------
function baseStripUnusedLibs {
	# /.../
	# Remove libraries which are not directly linked
	# against applications in the bin directories
	# ----
	local needlibs
	local found
	local dir
	local lnk
	local new
	local lib
	local lddref
	# /.../
	# Find directly used libraries, by calling ldd
	# on files in *bin*
	# ---
	ldconfig
	rm -f /tmp/needlibs
	for i in /usr/bin/* /bin/* /sbin/* /usr/sbin/*;do
		for n in $(ldd $i 2>/dev/null | cut -f2- -d\/ | cut -f1 -d " ");do
			if [ ! -e /$n ];then
				continue
			fi
			lddref=/$n
			while true;do
				lib=$(readlink $lddref)
				if [ $? -eq 0 ];then
					lddref=$lib
					continue
				fi
				break
			done
			lddref=$(basename $lddref)
			echo $lddref >> /tmp/needlibs
		done
	done
	count=0
	for i in `cat /tmp/needlibs | sort | uniq`;do
		for d in \
			/lib /lib64 /usr/lib /usr/lib64 \
			/usr/X11R6/lib /usr/X11R6/lib64
		do
			if [ -e "$d/$i" ];then
				needlibs[$count]=$d/$i
				count=$((count + 1))
			fi
		done
	done
	# /.../
	# add exceptions
	# ----
	while [ ! -z $1 ];do
		for i in /lib*/$1* /usr/lib*/$1* /usr/X11R6/lib*/$1*;do
			if [ -e $i ];then
				needlibs[$count]=$i
				count=`expr $count + 1`
			fi
		done
		shift
	done
	# /.../
	# find unused libs and remove it, dl loaded libs
	# seems not to be that important within the initrd
	# ----
	rm -f /tmp/needlibs
	for i in \
		/lib/lib* /lib64/lib* /usr/lib/lib* \
		/usr/lib64/lib* /usr/X11R6/lib*/lib*
	do
		found=0
		if [ ! -e $i ];then
			continue
		fi
		if [ -d $i ];then
			continue
		fi
		if [ -L $i ];then
			continue
		fi
		for n in ${needlibs[*]};do
			if [ $i = $n ];then
				found=1; break
			fi
		done
		if [ $found -eq 0 ];then
			echo "Removing library: $i"
			rm $i
		fi
	done
}

#======================================
# baseUpdateSysConfig
#--------------------------------------
function baseUpdateSysConfig {
	# /.../
	# Update sysconfig variable contents
	# ----
	local FILE=$1
	local VAR=$2
	local VAL=$3
	local args=$(echo "s'@^\($VAR=\).*\$@\1\\\"$VAL\\\"@'")
	eval sed -i $args $FILE
}

#======================================
# suseStripInitrd
#--------------------------------------
function suseStripInitrd {
	#==========================================
	# Remove unneeded files
	#------------------------------------------
	for delete in $kiwi_strip_delete;do
		echo "Removing file/directory: $delete"
		rm -rf $delete
	done
	#==========================================
	# remove unneeded tools
	#------------------------------------------
	local tools="$kiwi_strip_tools"
	tools="$tools $@"
	for path in /sbin /usr/sbin /usr/bin /bin;do
		baseStripTools "$path" "$tools"
	done
	#==========================================
	# remove unused libs
	#------------------------------------------
	baseStripUnusedLibs $kiwi_strip_libs
	#==========================================
	# remove images.sh
	#------------------------------------------
	rm -f /image/images.sh
	#==========================================
	# remove unused root directories
	#------------------------------------------
	rm -rf /home
	rm -rf /media
	rm -rf /srv
	#==========================================
	# remove unused doc directories
	#------------------------------------------
	rm -rf /usr/share/doc
	rm -rf /usr/share/man
	#==========================================
	# remove package manager meta data
	#------------------------------------------
	for p in dpkg rpm smart yum;do
		rm -rf /var/lib/$p
	done
}

#======================================
# rhelStripInitrd
#--------------------------------------
function rhelStripInitrd {
	suseStripInitrd $@
}

#======================================
# rhelGFXBoot
#--------------------------------------
function rhelGFXBoot {
	suseGFXBoot $@
}

#======================================
# rhelSplashToGrub
#--------------------------------------
function rhelSplashToGrub {
	local grub_stage=/usr/lib/grub
	local rhel_logos=/boot/grub/splash.xpm.gz
	if [ ! -e $rhel_logos ];then
		return
	fi
	if [ ! -d $grub_stage ];then
		mkdir -p $grub_stage
	fi
	mv $rhel_logos $grub_stage
}

#======================================
# suseGFXBoot
#--------------------------------------
function suseGFXBoot {
	local theme=$1
	local loader=$2
	local loader_theme=$theme
	local splash_theme=$theme
	export PATH=$PATH:/usr/sbin
	if [ ! -z "$kiwi_splash_theme" ];then
		splash_theme=$kiwi_splash_theme
	fi
	if [ ! -z "$kiwi_loader_theme"  ];then
		loader_theme=$kiwi_loader_theme
	fi
	if [ ! -z "$kiwi_bootloader" ];then
		loader=$kiwi_bootloader
	fi
	if [ ! -z "$kiwi_hybrid" ];then
		loader="isolinux"
	fi
	if [ "$loader" = "extlinux" ] || [ "$loader" = "syslinux" ];then
		# need the same data for sys|extlinux and for isolinux
		loader="isolinux"
	fi
	if [ "$loader" = "zipl" ];then
		# thanks god, no graphics on s390 :-)
		return
	fi
	#======================================
	# setup bootloader data
	#--------------------------------------
	if [ -d /usr/share/gfxboot ];then
		#======================================
		# create boot theme with gfxboot-devel
		#--------------------------------------
		cd /usr/share/gfxboot
		# check for new source layout
		local newlayout=
		[ -f themes/$loader_theme/config ] && newlayout=1
		# create the archive [1]
		[ "$newlayout" ] || make -C themes/$loader_theme prep
		make -C themes/$loader_theme
		# find gfxboot.cfg file
		local gfxcfg=
		if [ "$newlayout" ];then
			if [ $loader = "isolinux" ];then
				gfxcfg=themes/$loader_theme/data-install/gfxboot.cfg
			else
				gfxcfg=themes/$loader_theme/data-boot/gfxboot.cfg
			fi
			if [ ! -f $gfxcfg ];then
				gfxcfg=themes/$loader_theme/src/gfxboot.cfg
			fi
			if [ ! -f $gfxcfg ];then
				echo "gfxboot.cfg not found !"
				echo "install::livecd will be skipped"
				echo "live || boot:addopt.keytable will be skipped"
				echo "live || boot:addopt.lang will be skipped"
				unset gfxcfg
			fi
		fi
		# update configuration for new layout only
		if [ "$newlayout" ] && [ ! -z "$gfxcfg" ];then
			if [ $loader = "isolinux" ];then
				# tell the bootloader about live CD setup
				gfxboot --config-file $gfxcfg \
					--change-config install::livecd=1
				# tell the bootloader to hand over keytable to cmdline 
				gfxboot --config-file $gfxcfg \
					--change-config live::addopt.keytable=1
				# tell the bootloader to hand over lang to cmdline
				gfxboot --config-file $gfxcfg \
					--change-config live::addopt.lang=1
			else
				# tell the bootloader to hand over keytable to cmdline 
				gfxboot --config-file $gfxcfg \
					--change-config boot::addopt.keytable=1
				# tell the bootloader to hand over lang to cmdline
				gfxboot --config-file $gfxcfg \
					--change-config boot::addopt.lang=1
				# add selected languages to the bootloader menu
				if [ ! -z "$kiwi_language" ];then
					for l in `echo $kiwi_language | tr "," " "`;do
						echo "Adding language: $l"
						echo $l >> themes/$loader_theme/data-boot/languages
					done
				fi
			fi
		fi
		# create the archive [2]
		[ "$newlayout" ] || make -C themes/$loader_theme prep
		make -C themes/$loader_theme
		mkdir /image/loader
		local gfximage=
		local bootimage=
		if [ "$newlayout" ] ; then
			gfximage=themes/$loader_theme/bootlogo
			bootimage=themes/$loader_theme/message
		else
			gfximage=themes/$loader_theme/install/bootlogo
			bootimage=themes/$loader_theme/boot/message
		fi
		if [ $loader = "isolinux" ];then
			# isolinux boot data...
			cp $gfximage /image/loader
			bin/unpack_bootlogo /image/loader
		else
			# boot loader graphics image file...
			if [ ! -z "$kiwi_language" ];then
				msgdir=/image/loader/message.dir
				mkdir $msgdir && mv $bootimage $msgdir
				(cd $msgdir && cat message | cpio -i && rm -f message)
				if [ "$newlayout" ];then
					for l in `echo $kiwi_language | tr "," " "`;do
						l=$(echo $l | cut -f1 -d_)
						cp themes/$loader_theme/po/$l*.tr $msgdir
						cp themes/$loader_theme/help-boot/$l*.hlp $msgdir
					done
				else
					for l in `echo $kiwi_language | tr "," " "`;do
						l=$(echo $l | cut -f1 -d_)
						cp themes/$loader_theme/boot/$l*.tr  $msgdir
						cp themes/$loader_theme/boot/$l*.hlp $msgdir
						echo $l >> $msgdir/languages
					done
				fi
				(cd $msgdir && find | cpio --quiet -o > ../message)
				rm -rf $msgdir
			else
				mv $bootimage /image/loader
			fi
		fi
		make -C themes/$loader_theme clean
	elif [ -f /etc/bootsplash/themes/$loader_theme/bootloader/message ];then
		#======================================
		# use boot theme from gfxboot-branding
		#--------------------------------------
		echo "gfxboot devel not installed, custom branding skipped !"
		echo "using gfxboot branding package"
		mkdir /image/loader
		if [ $loader = "isolinux" ];then
			# isolinux boot data...
			mv /etc/bootsplash/themes/$loader_theme/cdrom/* /image/loader
			local gfxcfg=/image/loader/gfxboot.cfg
			# tell the bootloader about live CD setup
			gfxboot --config-file $gfxcfg \
				--change-config install::livecd=1
			# tell the bootloader to hand over keytable to cmdline 
			gfxboot --config-file $gfxcfg \
				--change-config live::addopt.keytable=1
			# tell the bootloader to hand over lang to cmdline
			gfxboot --config-file $gfxcfg \
				--change-config live::addopt.lang=1
		else
			# boot loader graphics image file...
			mv /etc/bootsplash/themes/$loader_theme/bootloader/message \
				/image/loader
			local archive=/image/loader/message
			# tell the bootloader to hand over keytable to cmdline 
			gfxboot --archive $archive \
				--change-config boot::addopt.keytable=1
			# tell the bootloader to hand over lang to cmdline
			gfxboot --archive $archive \
				--change-config boot::addopt.lang=1
			# add selected languages to the bootloader menu
			if [ ! -z "$kiwi_language" ];then
				gfxboot --archive $archive --add-language \
					$(echo $kiwi_language | tr "," " ") --default-language en_US
			fi
		fi
	elif [ -d /usr/share/grub2/themes/$loader_theme ];then
		#======================================
		# use boot theme from grub2-branding
		#--------------------------------------
		echo "using grub2 branding data"
		mv /boot/grub2/themes/$loader_theme/background.png \
			/usr/share/grub2/themes/$loader_theme
		mkdir /image/loader
	else
		#======================================
		# no graphics boot possible
		#--------------------------------------
		echo "gfxboot devel not installed"
		echo "gfxboot branding not installed"
		echo "graphics boot skipped !"
		mkdir /image/loader
	fi
	#======================================
	# copy bootloader binaries if required
	#--------------------------------------
	if [ "$loader" = "isolinux" ];then
		# isolinux boot code...
		if [ -f /usr/share/syslinux/isolinux.bin ];then
			mv /usr/share/syslinux/isolinux.bin /image/loader
		elif [ -f /usr/lib/syslinux/isolinux.bin ];then
			mv /usr/lib/syslinux/isolinux.bin  /image/loader
		fi
		# use either gfxboot.com or gfxboot.c32
		if [ -f /usr/share/syslinux/gfxboot.com ];then
			mv /usr/share/syslinux/gfxboot.com /image/loader
		elif [ -f /usr/share/syslinux/gfxboot.c32 ];then
			mv /usr/share/syslinux/gfxboot.c32 /image/loader
		fi
		if [ -f /usr/share/syslinux/chain.c32 ];then
			mv /usr/share/syslinux/chain.c32 /image/loader
		fi
		if [ -f /usr/share/syslinux/mboot.c32 ];then
			mv /usr/share/syslinux/mboot.c32 /image/loader
		fi
		if [ -f /boot/memtest* ];then 
			mv /boot/memtest* /image/loader/memtest
		fi
	elif [ "$loader" = "uboot" ];then
		# uboot loaders
		if [ -f /boot/u-boot.bin ];then
			mv /boot/u-boot.bin /image/loader
		fi
		if [ -f /boot/MLO ];then
			mv /boot/MLO /image/loader
		fi
	else
		# boot loader binary part of MBR
		:
	fi
	#======================================
	# create splash screen
	#--------------------------------------
	if [ -d /usr/share/plymouth/themes/$splash_theme ];then
		echo "plymouth splash system is used"
		touch "/plymouth.splash.active"
		return
	fi
	if [ ! -f /sbin/splash ];then
		echo "bootsplash not installed... skipped"
		return
	fi
	sname[0]="08000600.spl"
	sname[1]="10240768.spl"
	sname[2]="12801024.spl"
	index=0
	if [ ! -d /etc/bootsplash/themes/$splash_theme ];then
		theme="SuSE-$splash_theme"
	fi
	if [ ! -d /etc/bootsplash/themes/$splash_theme ];then
		echo "bootsplash branding not installed... skipped"
		return
	fi
	mkdir -p /image/loader/branding
	cp /etc/bootsplash/themes/$splash_theme/images/logo.mng \
		/image/loader/branding
	cp /etc/bootsplash/themes/$splash_theme/images/logov.mng \
		/image/loader/branding
	for cfg in 800x600 1024x768 1280x1024;do
		cp /etc/bootsplash/themes/$splash_theme/images/bootsplash-$cfg.jpg \
		/image/loader/branding
		cp /etc/bootsplash/themes/$splash_theme/images/silent-$cfg.jpg \
		/image/loader/branding
		cp /etc/bootsplash/themes/$splash_theme/config/bootsplash-$cfg.cfg \
		/image/loader/branding
	done
	mkdir -p /image/loader/animations
	cp /etc/bootsplash/themes/$splash_theme/animations/* \
		/image/loader/animations &>/dev/null
	for cfg in 800x600 1024x768 1280x1024;do
		/sbin/splash -s -c -f \
			/etc/bootsplash/themes/$splash_theme/config/bootsplash-$cfg.cfg |\
			gzip -9c \
		> /image/loader/${sname[$index]}
		tdir=/image/loader/xxx
		mkdir $tdir
		cp -a --parents /etc/bootsplash/themes/$splash_theme/config/*-$cfg.* \
			$tdir
		cp -a --parents /etc/bootsplash/themes/$splash_theme/images/*-$cfg.* \
			$tdir
		ln -s /etc/bootsplash/themes/$splash_theme/config/bootsplash-$cfg.cfg \
				$tdir/etc/splash.cfg
		pushd $tdir
		chmod -R a+rX .
		find | cpio --quiet -o -H newc |\
			gzip -9 >> /image/loader/${sname[$index]}
		popd
		rm -rf $tdir
		index=`expr $index + 1`
	done
}

#======================================
# suseSetupProductInformation
#--------------------------------------
function suseSetupProductInformation {
	# /.../
	# This function will use zypper to search for the installed
	# product and prepare the product specific information
	# for YaST
	# ----
	if [ ! -x /usr/bin/zypper ];then
		echo "zypper not installed... skipped"
		return
	fi
	local zypper="zypper --non-interactive --no-gpg-checks"
	local product=$($zypper search -t product | grep product | head -n 1)
	local p_alias=$(echo $product | cut -f4 -d'|')
	local p_name=$(echo $product | cut -f 4-5 -d'|' | tr '|' '-' | tr -d " ")
	p_alias=$(echo $p_alias)
	p_name=$(echo $p_name)
	echo "Installing product information for $p_name"
	$zypper install -t product $p_alias
}

#======================================
# suseStripFirmware
#--------------------------------------
function suseStripFirmware {
	# /.../
	# check all kernel modules if they require a firmware and
	# strip out all firmware files which are not referenced
	# by a kernel module
	# ----
	local ifs=$IFS
	local base=/lib/modules
	local name
	local bmdir
	local IFS="
	"
	mkdir -p /lib/firmware-required
	for i in $(find $base -name "*.ko" | xargs modinfo | grep ^firmware);do
		IFS=$ifs
		name=$(echo $(echo $i | cut -f2 -d:))
		if [ -z "$name" ];then
			continue
		fi
		for match in /lib/firmware/$name /lib/firmware/*/$name;do
			if [ -e $match ];then
				match=$(echo $match | sed -e 's@\/lib\/firmware\/@@')
				bmdir=$(dirname $match)
				mkdir -p /lib/firmware-required/$bmdir
				mv /lib/firmware/$match /lib/firmware-required/$bmdir
			fi
		done
	done
	rm -rf /lib/firmware
	mv /lib/firmware-required /lib/firmware
}

#======================================
# suseStripModules
#--------------------------------------
function suseStripModules {
	# /.../
	# search for update modules and remove the old version
	# which might be provided by the standard kernel
	# ----
	local kernel=/lib/modules
	local files=$(find $kernel -type f -name "*.ko")
	local mlist=$(for i in $files;do echo $i;done | sed -e s@.*\/@@g | sort)
	local count=1
	local mosum=1
	local modup
	#======================================
	# create sorted module array
	#--------------------------------------
	for mod in $mlist;do
		name_list[$count]=$mod
		count=$((count + 1))
	done
	count=1
	#======================================
	# find duplicate modules by their name
	#--------------------------------------
	while [ $count -lt ${#name_list[*]} ];do
		mod=${name_list[$count]}
		mod_next=${name_list[$((count + 1))]}
		if [ "$mod" = "$mod_next" ];then
			mosum=$((mosum + 1))
		else
			if [ $mosum -gt 1 ];then
				modup="$modup $mod"
			fi
			mosum=1
		fi
		count=$((count + 1))
	done
	#======================================
	# sort out duplicates prefer updates
	#--------------------------------------
	if [ -z "$modup" ];then
		echo "suseStripModules: No update drivers found"
		return
	fi
	for file in $files;do
		for mod in $modup;do
			if [[ $file =~ $mod ]] && [[ ! $file =~ "updates" ]];then
				echo "suseStripModules: Update driver found for $mod"
				echo "suseStripModules: Removing old version: $file"
				rm -f $file
			fi
		done
	done
}

#======================================
# suseStripKernel
#--------------------------------------
function suseStripKernel {
	# /.../
	# this function will strip the kernel according to the
	# drivers information in the xml descr. It also will create
	# the vmlinux.gz and vmlinuz files which are required
	# for the kernel extraction in case of kiwi boot images
	# ----
	local ifss=$IFS
	local arch=$(uname -m)
	local kversion
	local i
	local d
	local mod
	local stripdir
	local kdata
	for kversion in /lib/modules/*;do
		IFS="
		"
		if [ ! -d "$kversion" ];then
			IFS=$ifss
			continue
		fi
		if [ -x /bin/rpm ];then
			kdata=$(rpm -qf $kversion)
		else
			kdata=$kversion
		fi
		for p in $kdata;do
			#==========================================
			# get kernel VERSION information
			#------------------------------------------
			if [ ! $? = 0 ];then
				# not in a package...
				IFS=$ifss
				continue
			fi
			if echo $p | grep -q "\-kmp\-";then  
				# a kernel module package...
				IFS=$ifss
				continue
			fi
			if echo $p | grep -q "\-source\-";then
				# a kernel source package...
				IFS=$ifss
				continue
			fi
			VERSION=$(/usr/bin/basename $kversion)
			echo "Stripping kernel $p: Image [$kiwi_iname]..."
			#==========================================
			# run depmod, deps should be up to date
			#------------------------------------------
			if [ ! -f /boot/System.map-$VERSION ];then
				# no system map for kernel
				echo "no system map for kernel: $p found... skip it"
				IFS=$ifss
				continue
			fi
			/sbin/depmod -F /boot/System.map-$VERSION $VERSION
			#==========================================
			# check for modules.order and backup it
			#------------------------------------------
			if [ -f $kversion/modules.order ];then
				mv $kversion/modules.order /tmp
			fi
			#==========================================
			# check for weak-/updates and backup them
			#------------------------------------------
			if [ -d $kversion/updates ];then
				mv $kversion/updates /tmp
			fi
			if [ -d $kversion/weak-updates ];then
				mv $kversion/weak-updates /tmp
			fi
			#==========================================
			# strip the modules but take care for deps
			#------------------------------------------
			stripdir=/tmp/stripped_modules
			IFS=,
			for mod in $kiwi_drivers; do
				local path=`/usr/bin/dirname $mod`
				local base=`/usr/bin/basename $mod`
				for d in kernel;do
					if [ "$base" = "*" ];then
						if test -d $kversion/$d/$path ; then
							mkdir -pv $stripdir$kversion/$d/$path
							cp -avl $kversion/$d/$path/* \
								$stripdir$kversion/$d/$path
						fi
					else
						if test -f $kversion/$d/$mod ; then
							mkdir -pv $stripdir$kversion/$d/$path
							cp -avl $kversion/$d/$mod \
								$stripdir$kversion/$d/$mod
						elif test -L $kversion/$d/$base ; then
							mkdir -pv $stripdir$kversion/$d
							cp -avl $kversion/$d/$base \
								$stripdir$kversion/$d
						elif test -f $kversion/$d/$base ; then
							mkdir -pv $stripdir$kversion/$d
							cp -avl $kversion/$d/$base \
								$stripdir$kversion/$d
						fi
					fi
				done
			done
			IFS=$ifss
			for mod in `find $stripdir -name "*.ko"`;do
				d=`/usr/bin/basename $mod`
				i=`/sbin/modprobe \
					--set-version $VERSION \
					--ignore-install \
					--show-depends \
					${d%.ko} | sed -ne 's:.*insmod /\?::p'`
				for d in $i; do
					case "$d" in
						*=*) ;;
						*)
						if ! test -f $stripdir/$d ; then
							echo "Fixing kernel module Dependency: $d"
							mkdir -vp `/usr/bin/dirname $stripdir/$d`
							cp -flav $d $stripdir/$d
						fi
						;;
					esac
				done
			done
			rm -rf $kversion
			mv -v $stripdir/$kversion $kversion
			rm -rf $stripdir
			#==========================================
			# restore backed up files and directories
			#------------------------------------------
			if [ -f /tmp/modules.order ];then
				mv /tmp/modules.order $kversion
			fi
			if [ -d /tmp/updates ];then
				mv /tmp/updates $kversion
			fi
			if [ -d /tmp/weak-updates ];then
				mv /tmp/weak-updates $kversion
			fi
			#==========================================
			# run depmod
			#------------------------------------------
			/sbin/depmod -F /boot/System.map-$VERSION $VERSION
			#==========================================
			# create common kernel files, last wins !
			#------------------------------------------
			pushd /boot
			if [ -f uImage-$VERSION ];then
				mv uImage-$VERSION vmlinuz
			elif [[ $arch =~ ^arm ]] && [ -f Image-$VERSION ];then
				mv Image-$VERSION vmlinuz
			elif [ -f vmlinux-$VERSION.gz ];then
				mv vmlinux-$VERSION.gz vmlinux.gz
				mv vmlinuz-$VERSION vmlinuz
			elif [ -f vmlinuz-$VERSION.el5 ];then
				mv vmlinux-$VERSION.el5 vmlinuz
			elif [ -f vmlinuz-$VERSION ];then
				mv vmlinuz-$VERSION vmlinuz
			elif [ -f image-$VERSION ];then
				mv image-$VERSION vmlinuz
			else
				rm -f vmlinux
				cp vmlinux-$VERSION vmlinux
				mv vmlinux-$VERSION vmlinuz
			fi
			popd
		done
	done
	suseStripModules
	suseStripFirmware
}

#======================================
# rhelStripKernel
#--------------------------------------
function rhelStripKernel {
	suseStripKernel
}

#======================================
# suseSetupProduct
#--------------------------------------
function suseSetupProduct {
	# /.../
	# This function will create the /etc/products.d/baseproduct
	# link pointing to the product referenced by either
	# the /etc/SuSE-brand file or the latest .prod file
	# available in /etc/products.d
	# ----
	local prod=undef
	if [ -f /etc/SuSE-brand ];then
		prod=$(head /etc/SuSE-brand -n 1)
	fi
	pushd /etc/products.d
	if [ -f $prod.prod ];then
		ln -sf $prod.prod baseproduct
	elif [ -f SUSE_$prod.prod ];then
		ln -sf SUSE_$prod.prod baseproduct
	else
		prod=$(ls -1t *.prod 2>/dev/null | tail -n 1)
		if [ -f $prod ];then
			ln -sf $prod baseproduct
		fi
	fi
	popd
}

#======================================
# baseSetRunlevel
#--------------------------------------
function baseSetRunlevel {
	# /.../
	# This function sets the runlevel in /etc/inittab to
	# the specified value
	# ----
	local RUNLEVEL=$1
	case "$RUNLEVEL" in
		1|2|3|5)
			sed -i "s/id:[0123456]:initdefault:/id:$RUNLEVEL:initdefault:/" \
			/etc/inittab
			if test -d /etc/systemd/system; then
				ln -sf \
					/lib/systemd/system/runlevel$RUNLEVEL.target \
					/etc/systemd/system/default.target
			fi
		;;
		*)
			echo "Invalid runlevel argument: $RUNLEVEL"
		;;
	esac
}

#======================================
# suseRemovePackagesMarkedForDeletion
#--------------------------------------
function suseRemovePackagesMarkedForDeletion {
	# /.../
	# This function removes all packages which are
	# added into the <packages type="delete"> section
	# ----
	local packs=$(baseGetPackagesForDeletion)
	local final=$(rpm -q $packs | grep -v 'is not installed')
	echo "suseRemovePackagesMarkedForDeletion: $final"
	Rpm -e --nodeps --noscripts $final
}

#======================================
# baseDisableCtrlAltDel
#--------------------------------------
function baseDisableCtrlAltDel {
	# /.../
	# This function disables the Ctrl-Alt-Del key sequence
	# ---
	sed -i "s/ca::ctrlaltdel/#ca::ctrlaltdel/" /etc/inittab
}

#======================================
# basePackBootIncludes
#--------------------------------------
function basePackBootIncludes {
	# /.../
	# This function packs the rpm files for the packages
	# listed in $kiwi_fixedpackbootincludes and the file list
	# in bootincluded_archives.filelist into a tarball
	# ----
	local archive=/bootinclude.tgz
	if [ -f /bootincluded_archives.filelist ];then
		echo "Packing bootincluded archives..."
		cat /bootincluded_archives.filelist | xargs tar -C / -rvf $archive
	fi
	if [ ! -z "$kiwi_fixedpackbootincludes" ];then
		echo "Packing bootincluded packages..."
		rpm -ql $kiwi_fixedpackbootincludes | \
			xargs tar -C / --no-recursion -rvf $archive
	fi
}

#======================================
# baseUnpackBootIncludes
#--------------------------------------
function baseUnpackBootIncludes {
	local archive=/bootinclude.tgz
	if [ -f $archive ];then
		echo "Unpacking bootinclude archive..."
		tar -C / -xvf $archive && rm -f $archive
	fi
}

#======================================
# baseSetupBootLoaderCompatLinks
#--------------------------------------
function baseSetupBootLoaderCompatLinks {
	if [ ! -d /usr/lib/grub ];then
		mkdir -p /usr/lib/grub
		cp -l /usr/share/grub/*/* /usr/lib/grub
	fi
}

#======================================
# baseQuoteFile
#--------------------------------------
function baseQuoteFile {
	local file=$1
	local conf=$file.quoted
	# create clean input, no empty lines and comments
	cat $file | grep -v '^$' | grep -v '^[ \t]*#' > $conf
	# remove start/stop quoting from values
	sed -i -e s"#\(^[a-zA-Z0-9_]\+\)=[\"']\(.*\)[\"']#\1=\2#" $conf
	# remove backslash quotes if any
	sed -i -e s"#\\\\\(.\)#\1#g" $conf
	# quote simple quotation marks
	sed -i -e s"#'#'\\\\''#g" $conf
	# add '...' quoting to values
	sed -i -e s"#\(^[a-zA-Z0-9_]\+\)=\(.*\)#\1='\2'#" $conf
	mv $conf $file
}

#======================================
# baseSetupBuildDay
#--------------------------------------
function baseSetupBuildDay {
	local buildDay="$(LC_ALL=C date -u '+%Y%m%d')"
	echo "build_day=$buildDay" > /build_day
}

# vim: set noexpandtab:
