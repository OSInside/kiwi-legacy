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
	if /sbin/insserv $service;then
		echo "Service $service inserted"
	else
		if ! /sbin/insserv --recursive $service;then
			echo "$service: recursive insertion failed...skipped"
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
	local service=/etc/init.d/$1
	if /sbin/insserv -r $service;then
		echo "Service $service removed"
	else
		if ! /sbin/insserv --recursive -r $service;then
			echo "$service: recursive removal failed...skipped"
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
	# if a service exist then enable or disable it using chkconfig
	# example : suseService apache2 on
	# example : suseService apache2 off
	# ----
	local service=$1
	local action=$2
	if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$service ];then
		if [ $action = on ];then
			/sbin/chkconfig $service on
		elif [ $action = off ];then
			/sbin/chkconfig $service off
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
		cat etc/sysconfig/keyboard |\
			sed -e s"@KEYTABLE=\".*\"@KEYTABLE=\"$kiwi_keytable\"@" \
		> etc/sysconfig/keyboard.new
		mv etc/sysconfig/keyboard.new etc/sysconfig/keyboard
	fi
	#======================================
	# locale
	#--------------------------------------
	if [ ! -z "$kiwi_language" ];then
		language=$(echo $kiwi_language | cut -f1 -d,).UTF-8
		cat /etc/sysconfig/language |\
			sed -e s"@RC_LANG=\".*\"@RC_LANG=\"$language\"@" \
		> etc/sysconfig/language.new
		mv etc/sysconfig/language.new etc/sysconfig/language
	fi
	#======================================
	# timezone
	#--------------------------------------
	if [ ! -z "$kiwi_timezone" ];then
		if [ -f /usr/share/zoneinfo/$kiwi_timezone ];then
			cp /usr/share/zoneinfo/$kiwi_timezone /etc/localtime
			cat /etc/sysconfig/clock |\
				sed -e s"@TIMEZONE=\".*\"@TIMEZONE=\"$kiwi_timezone\"@" \
			> etc/sysconfig/clock.new
			mv etc/sysconfig/clock.new etc/sysconfig/clock
		else
			echo "timezone: $kiwi_timezone not found"
		fi
	fi
	#======================================
	# hwclock
	#--------------------------------------
	if [ ! -z "$kiwi_hwclock" ];then
		cat /etc/sysconfig/clock |\
			sed -e s"@HWCLOCK=\".*\"@HWCLOCK=\"--$kiwi_hwclock\"@" \
		> etc/sysconfig/clock.new
		mv etc/sysconfig/clock.new etc/sysconfig/clock
	fi
	#======================================
	# SuSEconfig
	#--------------------------------------
	/sbin/SuSEconfig
	#======================================
	# SuSEconfig permissions
	#--------------------------------------
	SuSEconfig --module permissions
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
	for i in `baseGetPackagesForDeletion`
	do
		Rpm -e --nodeps $i
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
	# /.../
	# Find directly used libraries, by calling ldd
	# on files in *bin*
	# ---
	ldconfig
	rm -f /tmp/needlibs
	for i in /usr/bin/* /bin/* /sbin/* /usr/sbin/*;do
		for n in `ldd $i 2>/dev/null`;do
			if [ -e $n ];then
				echo $n >> /tmp/needlibs
			fi
		done
	done
	count=0
	for i in `cat /tmp/needlibs | sort | uniq`;do
		needlibs[$count]=$i
		count=`expr $count + 1`
		if [ -L $i ];then
			dir=`dirname $i`
			lnk=`readlink $i`
			new=$dir/$lnk
			needlibs[$count]=$new
			count=`expr $count + 1`
		fi
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
		if [ -d $i ];then
			continue
		fi
		for n in ${needlibs[*]};do
			if [ $i = $n ];then
				found=1; break
			fi
		done
		if [ $found -eq 0 ];then
			echo "Removing: $i"
			rm $i
		fi
	done
}

#======================================
# baseSysConfig
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
	rm -rf `find -type d | grep .svn`
	local files="
		/usr/share/backgrounds/images /usr/share/zoneinfo
		/var/lib/yum /var/lib/dpkg /usr/kerberos /usr/lib*/gconv
		/usr/share/apps/ksplash /usr/share/apps/firstboot
		/usr/share/info /usr/share/man /usr/share/cracklib /usr/lib*/python*
		/usr/lib*/perl* /usr/share/doc/packages /var/lib/rpm
		/usr/lib*/rpm /var/lib/smart /opt/* /usr/include /root/.gnupg
		/etc/PolicyKit /etc/init.d /etc/profile.d /etc/skel
		/etc/ssl /etc/java /etc/default /etc/cron* /etc/dbus*
		/etc/pam.d* /etc/DIR_COLORS /etc/rc* /usr/share/hal /usr/share/ssl
		/usr/lib*/hal /usr/lib*/*.a /usr/lib*/*.la /usr/lib*/librpm*
		/usr/lib*/libpanel* /usr/lib*/libmenu* /usr/src/packages/RPMS
		/usr/lib*/X11 /var/X11R6 /usr/share/X11 /etc/X11
		/usr/lib*/xorg /usr/share/locale-bundle
		/etc/ppp /etc/xdg /etc/NetworkManager /lib*/YaST /lib*/security
		/lib*/mkinitrd/boot /lib*/mkinitrd/dev /lib*/mkinitrd/scripts
		/lib*/mkinitrd/setup
		/srv /var/adm /usr/lib*/engines /usr/src/packages
		/usr/src/linux* /usr/local /var/log/* /usr/share/pixmaps
		/usr/share/gtk-doc /var/games /opt /var/spool /var/opt
		/var/cache /var/tmp /etc/rpm /etc/cups /etc/opt
		/home /media /usr/lib*/lsb /usr/lib*/krb5
		/usr/lib*/ldscripts /usr/lib*/getconf /usr/lib*/pwdutils
		/usr/lib*/pkgconfig /usr/lib*/browser-plugins
		/usr/share/omc /usr/share/tmac /usr/share/emacs /usr/share/idnkit
		/usr/share/games /usr/share/PolicyKit /usr/share/tabset
		/usr/share/mkinitrd /usr/share/xsessions /usr/share/pkgconfig
		/usr/share/dbus-1 /usr/share/sounds /usr/share/dict /usr/share/et
		/usr/share/ss /usr/share/java /usr/share/themes /usr/share/doc
		/usr/share/applications /usr/share/mime /usr/share/icons
		/usr/share/xml /usr/share/sgml /usr/share/fonts /usr/games
		/usr/lib/mit /usr/lib/news /usr/lib/pkgconfig /usr/lib/smart
		/usr/lib/browser-plugins /usr/lib/restricted /usr/x86_64-suse-linux
		/etc/logrotate* /etc/susehelp* /etc/SuSEconfig /etc/permissions.d
		/etc/aliases.d /etc/hal /etc/news /etc/pwdutils /etc/uucp
		/etc/openldap /etc/xinetd /etc/depmod.d /etc/smart /etc/lvm
		/etc/named* /etc/bash_completion* usr/share/gnupg
		/lib/modules/*/kernel/drivers/net/pcmcia
		/lib/modules/*/kernel/drivers/net/tokenring
		/lib/modules/*/kernel/drivers/net/bonding
		/lib/modules/*/kernel/drivers/net/hamradio
		/usr/X11R6/bin /usr/X11R6/lib/X11/locale
	"
	for i in $files;do
		rm -rfv $i
	done
	#==========================================
	# remove unneeded files
	#------------------------------------------
	if [ -d /var/cache/zypp ];then
		files="
			/usr/lib*/libzypp* /lib*/libgcrypt* /lib*/libgpg*
			/usr/lib*/dirmngr /usr/lib*/gnupg* /usr/lib*/gpg*
			/usr/lib*/libboost* /usr/lib*/libcurl* /usr/lib*/libicu*
			/usr/lib*/libksba* /usr/lib*/libpth*
			/var/cache/zypp /usr/lib*/zypp* /usr/share/curl
			/usr/share/emacs /usr/share/gnupg
			/usr/share/zypp* /var/lib/zypp* /var/log/zypper.log
		"
		for i in $files;do
			rm -rfv $i
		done
	fi
	#==========================================
	# remove unneeded tools
	#------------------------------------------
	local tools="
		tune2fs swapon swapoff shutdown resize_reiserfs
		reiserfsck reboot halt pivot_root modprobe modinfo rmmod
		mkswap mkinitrd mkreiserfs mkfs.cramfs mkfs.btrfs btrfsctl
		losetup ldconfig insmod init ifconfig e2fsck fsck.ext2
		fsck.ext3 fsck.ext4 dhcpcd mkfs.ext2 mkfs.ext3 mkfs.ext4
		depmod atftpd klogconsole hwinfo xargs wc tail tac readlink
		mkfifo md5sum head expr file free find env du dirname cut
		column chroot atftp tr host test printf mount dd uname umount
		true touch sleep sh pidof sed rmdir rm pwd ps mv mkdir kill hostname
		gzip grep false df cp cat bash basename arch sort ls uniq lsmod
		usleep parted mke2fs pvcreate vgcreate lvm resize2fs ln hdparm
		dmesg splash fbmngplay portmap start-statd sm-notify
		rpc.statd rpc.idmapd nbd-client mount.nfs mount.nfs4 eject
		blockdev posbios ping killall killall5 udevcontrol udevd
		udevsettle udevtrigger mknod stat path_id hwup scsi_id scsi_tur
		usb_id ata_id vol_id edd_id setctsid dumpe2fs debugreiserfs
		fuser udevadm blogd showconsole killproc curl tar
		ldd driveready checkmedia splashy bzip2 hexdump vgremove
		pvchange pvresize pvscan vgscan vgchange vgextend vgdisplay
		lvchange lvresize lvextend lvcreate grub dcounter tty
		dmsetup dialog awk gawk clicfs cryptsetup clear blkid fbiterm
		gettext diff bc utimer cmp busybox kexec pam_console_apply
		setterm kpartx vgcfgbackup vgcfgrestore lsdasd dasd_configure
		qeth_configure fdasd mkdosfs egrep mkfs.xfs mdadm yes fdisk
		startproc zfcp_host_configure zfcp_disk_configure xfs_growfs
		xfs_check vgrename kpartx_id mpath_id dmraid dmevent_tool
		which mpath_wait seq route haveged wpa_supplicant
	"
	tools="$tools $@"
	for path in /sbin /usr/sbin /usr/bin /bin;do
		baseStripTools "$path" "$tools"
	done
	#==========================================
	# remove unused libs
	#------------------------------------------
	baseStripUnusedLibs \
		librt libutil libsysfs libnss_files libnss_compat libnsl libpng \
		libfontenc libutempter libfreetype libgcc_s libresolv libnss_dns
	#==========================================
	# remove images.sh and /root
	#------------------------------------------
	rm -f /image/images.sh
	rm -rf /root
	#==========================================
	# strip down configuration files
	#------------------------------------------
	rm -rf /tmp/*
	rm -rf /tmp/.*
	files="
		/etc/modprobe.conf /etc/modprobe.conf.local /etc/mtab
		/etc/protocols /etc/services /etc/termcap /etc/aliases
		/etc/bash.bashrc /etc/filesystems /etc/ld.so.conf /etc/magic
		/etc/group /etc/passwd /etc/nsswitch.conf /etc/scsi_id.config
		/etc/netconfig /etc/hosts /etc/resolv.conf /etc/modprobe.d
	"
	for i in $files;do
		if [ -e $i ];then
			mv $i /tmp
		fi
	done
	rm -f /etc/*
	mv /tmp/* /etc
}

#======================================
# rhelStripInitrd
#--------------------------------------
function rhelStripInitrd {
	suseStripInitrd
}

#======================================
# rhelGFXBoot
#--------------------------------------
function rhelGFXBoot {
	suseGFXBoot $@
}

#======================================
# suseGFXBoot
#--------------------------------------
function suseGFXBoot {
	local theme=$1
	local loader=$2
	export PATH=$PATH:/usr/sbin
	if [ ! -z "$kiwi_boottheme" ];then
		theme=$kiwi_boottheme
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
		[ -f themes/$theme/config ] && newlayout=1
		# create the archive [1]
		[ "$newlayout" ] || make -C themes/$theme prep
		make -C themes/$theme
		# find gfxboot.cfg file
		local gfxcfg=
		if [ "$newlayout" ];then
			if [ $loader = "isolinux" ];then
				gfxcfg=themes/$theme/data-install/gfxboot.cfg
			else
				gfxcfg=themes/$theme/data-boot/gfxboot.cfg
			fi
			if [ ! -f $gfxcfg ];then
				gfxcfg=themes/$theme/src/gfxboot.cfg
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
						echo $l >> themes/$theme/data-boot/languages
					done
				fi
			fi
		fi
		# create the archive [2]
		[ "$newlayout" ] || make -C themes/$theme prep
		make -C themes/$theme
		mkdir /image/loader
		local gfximage=
		local bootimage=
		if [ "$newlayout" ] ; then
			gfximage=themes/$theme/bootlogo
			bootimage=themes/$theme/message
		else
			gfximage=themes/$theme/install/bootlogo
			bootimage=themes/$theme/boot/message
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
						cp themes/$theme/po/$l*.tr $msgdir
						cp themes/$theme/help-boot/$l*.hlp $msgdir
					done
				else
					for l in `echo $kiwi_language | tr "," " "`;do
						l=$(echo $l | cut -f1 -d_)
						cp themes/$theme/boot/$l*.tr  $msgdir
						cp themes/$theme/boot/$l*.hlp $msgdir
						echo $l >> $msgdir/languages
					done
				fi
				(cd $msgdir && find | cpio --quiet -o > ../message)
				rm -rf $msgdir
			else
				mv $bootimage /image/loader
			fi
		fi
		make -C themes/$theme clean
	elif [ -f /etc/bootsplash/themes/$theme/bootloader/message ];then
		#======================================
		# use boot theme from gfxboot-branding
		#--------------------------------------
		echo "gfxboot devel not installed, custom branding skipped !"
		echo "using gfxboot branding package"
		mkdir /image/loader
		if [ $loader = "isolinux" ];then
			# isolinux boot data...
			mv /etc/bootsplash/themes/$theme/cdrom/* /image/loader
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
			mv /etc/bootsplash/themes/$theme/bootloader/message /image/loader
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
	# copy bootloader binaries of required
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
	else
		# boot loader binary part of MBR
		:
	fi
	#======================================
	# create splash screen
	#--------------------------------------
	if [ ! -f /sbin/splash ];then
		echo "bootsplash not installed... skipped"
		return
	fi
	sname[0]="08000600.spl"
	sname[1]="10240768.spl"
	sname[2]="12801024.spl"
	index=0
	if [ ! -d /etc/bootsplash/themes/$theme ];then
		theme="SuSE-$theme"
	fi
	if [ ! -d /etc/bootsplash/themes/$theme ];then
		echo "bootsplash branding not installed... skipped"
		return
	fi
	mkdir -p /image/loader/branding
	cp /etc/bootsplash/themes/$theme/images/logo.mng  /image/loader/branding
	cp /etc/bootsplash/themes/$theme/images/logov.mng /image/loader/branding
	for cfg in 800x600 1024x768 1280x1024;do
		cp /etc/bootsplash/themes/$theme/images/bootsplash-$cfg.jpg \
		/image/loader/branding
		cp /etc/bootsplash/themes/$theme/images/silent-$cfg.jpg \
		/image/loader/branding
		cp /etc/bootsplash/themes/$theme/config/bootsplash-$cfg.cfg \
		/image/loader/branding
	done
	mkdir -p /image/loader/animations
	cp /etc/bootsplash/themes/$theme/animations/* \
		/image/loader/animations &>/dev/null
	for cfg in 800x600 1024x768 1280x1024;do
		/sbin/splash -s -c -f \
			/etc/bootsplash/themes/$theme/config/bootsplash-$cfg.cfg |\
			gzip -9c \
		> /image/loader/${sname[$index]}
		tdir=/image/loader/xxx
		mkdir $tdir
		cp -a --parents /etc/bootsplash/themes/$theme/config/*-$cfg.* $tdir
		cp -a --parents /etc/bootsplash/themes/$theme/images/*-$cfg.* $tdir
		ln -s /etc/bootsplash/themes/$theme/config/bootsplash-$cfg.cfg \
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
			for mod in \
				$kiwi_usbdrivers $kiwi_scsidrivers \
				$kiwi_netdrivers $kiwi_drivers
			do
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
			if [ -f vmlinux-$VERSION.gz ];then
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
	rpm -e --nodeps \
		$(rpm -q `baseGetPackagesForDeletion` | grep -v "is not installed")
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

# vim: set noexpandtab:
