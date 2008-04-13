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
# suseInsertService
#--------------------------------------
function suseInsertService {
	# /.../
	# Recursively insert a service. If there is a service
	# required for this service it will be inserted first
	# -----
	local service=$1
	local result
	while true;do
		result=`/sbin/insserv $service 2>&1`
		if [ $? = 0 ];then
			echo "Service $service inserted"
			break
		else
			result=`echo $result | head -n 1 | cut -f3 -d " "`
			if [ -f /etc/init.d/$result ];then
				suseInsertService /etc/init.d/$result
			else
				echo "$service: required service: $result not found...skipped"
				break
			fi
		fi
	done
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
	while true;do
		/sbin/insserv -r $service &>/dev/null
		if [ $? = 0 ];then
			echo "Service $service removed"
			break
		else
			result=`/sbin/insserv -r $service 2>&1|tail -n 2|cut -f10 -d " "`
			if [ -f /etc/init.d/$result ];then
				suseRemoveService $result
			else
				echo "$service: $result not found...skipped"
				break
			fi
		fi
	done
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
# suseActivateDefaultServices
#--------------------------------------
function suseActivateDefaultServices {
	# /.../
	# Call all postin scriptlets which among other things activates
	# all default services required using insserv
	# -----
	local ifss=$IFS
	local file=kiwi-services.default
	local name=""
	local name1=$name
	local name2=$name
	rm -f $file
	for p in `rpm -qa --qf "%{NAME}\n"`;do
		rpm -q --qf \
			"%|POSTIN?{%|POSTINPROG?{}|%{POSTIN}\n}:{%|POSTINPROG?{}|}|" \
		$p > $p.sh
		if [ -s "$p.sh" ];then
			echo "Calling post script $p.sh"
			bash $p.sh 2>&1
			cat $p.sh | sed -e s@\$SCRIPTNAME@$p@g | grep insserv >> $file
		fi
		rm -f $p.sh
	done
	IFS="
	"
	for i in \
		`cat $file | grep -v ^.*# | cut -f2- -d"/" | grep ^insserv`
	do
		name=`echo $i | cut -f2 -d. | cut -f2 -d/`
		if echo $name | grep -q insserv; then
			name1=`echo $name | cut -f2 -d" "`
			name2=`echo $name | cut -f3 -d" "`
			if [ ! -z $name1 ];then
				name=$name1
			fi
			if [ ! -z $name2 ];then
				name=$name2
			fi
		else
			name=`echo $name | tr -d " "`
		fi
		if [ -f /etc/init.d/$name ];then
			echo $name >> kiwi-services.tmp
		fi
	done
	for i in `cat kiwi-services.tmp | sort | uniq`;do
		suseInsertService $i
	done
	rm -f kiwi-services.tmp
	rm -f $file
	IFS=$ifss
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
function suseServiceDefaultOn {
	# /.../
	# Some basic services that needs to be on.
	# ----
	services=(
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
	)
	for i in "${services[@]}";do
		if [ -x /etc/init.d/$i ] && [ -f /etc/init.d/$i ];then
			/sbin/chkconfig $i on
		fi
	done
}

#======================================
# baseSetupUserPermissions
#--------------------------------------
function baseSetupUserPermissions {
	while read line in;do
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
	if [ ! -z "$keytable" ];then
		cat etc/sysconfig/keyboard |\
			sed -e s"@KEYTABLE=\".*\"@KEYTABLE=\"$keytable\"@" \
		> etc/sysconfig/keyboard.new
		mv etc/sysconfig/keyboard.new etc/sysconfig/keyboard
	fi
	#======================================
	# locale
	#--------------------------------------
	if [ ! -z "$language" ];then
		cat /etc/sysconfig/language |\
			sed -e s"@RC_LANG=\".*\"@RC_LANG=\"$language\"@" \
		> etc/sysconfig/language.new
		mv etc/sysconfig/language.new etc/sysconfig/language
	fi
	#======================================
	# timezone
	#--------------------------------------
	if [ ! -z "$timezone" ];then
		if [ -f /usr/share/zoneinfo/$timezone ];then
			mv /usr/share/zoneinfo/$timezone /etc/localtime
		else
			echo "timezone: $timezone not found"
		fi
	fi
	#======================================
	# SuSEconfig
	#--------------------------------------
	/sbin/SuSEconfig
}

#======================================
# baseGetPackagesForDeletion
#--------------------------------------
function baseGetPackagesForDeletion {
	echo $delete
}

#======================================
# baseGetProfilesUsed
#--------------------------------------
function baseGetProfilesUsed {
	echo $profiles
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
# stripLocales
#--------------------------------------
function baseStripLocales {
	local imageLocales="$@"
	local directories="
		/opt/gnome/share/locale
		/usr/share/locale
		/opt/kde3/share/locale
		/usr/lib/locale
	"
	for dir in $directories; do
		locales=`find $dir -type d -maxdepth 1 2>/dev/null`
		for locale in $locales;do
			if test $locale = $dir;then
				continue
			fi
			
			local baseLocale=`/usr/bin/basename $locale`
			local found="no"
			for keep in $imageLocales;do
				if echo $baseLocale | grep $keep;then
					found="yes"
					break
				fi
			done

			if test $found = "no";then
				rm -rf $locale
			fi
		done
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
			rm -f $file
		fi
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
		/usr/share/man /proc /bin /sbin /lib /lib64 /.git
	"
	#======================================
	# files to ignore
	#--------------------------------------
	local files="
		/etc/Image* *.lock /etc/resolv.conf *.gif *.png
		*.jpg *.eps *.ps
	"
	#======================================
	# creae .gitignore and find list
	#--------------------------------------
	for entry in $files;do
		echo $entry >> .gitignore
		if [ -z "$ignore" ];then
			ignore="-name $entry"
		else
			ignore="$ignore -or -name $entry"
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
	echo /proc > .gitignore
	local files="
		/sys /dev /var/log /home /media /var/run /etc/Image*
		/var/tmp /tmp /var/lock *.lock /image /var/spool /var/cache
		/var/lib /boot /root /var/adm /base-system
	"
	for entry in $files;do
		echo $entry >> .gitignore
	done
	git init && git add . && \
	git commit -m "deployed"
	popd
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
	local force="no"
	local busyboxlinks="/usr/share/busybox/busybox.links"
	if ! rpm -q --quiet busybox; then
		echo "Busybox not installed... skipped"
		return 0;
	fi
	if [ $# -gt 0 ] && [ "$1" = "-f" ]; then
		force="yes"
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
# suseStripInitrd
#--------------------------------------
function suseStripInitrd {
	#==========================================
	# remove unneeded files
	#------------------------------------------
	rpm -e popt bzip2 --nodeps --noscripts &>/dev/null
	rm -rf `find -type d | grep .svn`
	local files="
		/usr/share/info /usr/share/man /usr/share/cracklib /usr/lib*/python*
		/usr/lib*/perl* /usr/share/locale* /usr/share/doc/packages /var/lib/rpm
		/usr/lib*/rpm /var/lib/smart /opt/* /usr/include /root/.gnupg
		/etc/PolicyKit /etc/sysconfig /etc/init.d /etc/profile.d /etc/skel
		/etc/ssl /etc/java /etc/default /etc/cron* /etc/dbus*
		/etc/pam.d* /etc/DIR_COLORS /etc/rc* /usr/share/hal /usr/share/ssl
		/usr/lib*/hal /usr/lib*/*.a /usr/lib*/*.la /usr/lib*/librpm*
		/usr/lib*/libpanel* /usr/lib*/libncursesw*
		/usr/lib*/libmenu* /usr/lib*/libx* /usr/src/packages/RPMS
		/usr/X11R6 /usr/lib*/X11 /var/X11R6 /usr/share/X11 /etc/X11
		/usr/lib*/libX* /usr/lib*/xorg /usr/lib*/libidn*
		/etc/ppp /etc/xdg /etc/NetworkManager /lib*/YaST /lib*/security
		/lib*/mkinitrd /srv /var/adm /usr/lib/engines /usr/src/packages
		/usr/src/linux* /usr/local /var/log/* /usr/share/pixmaps
		/lib/modules/*/kernel/drivers/net/wireless
		/lib/modules/*/kernel/drivers/net/pcmcia
		/lib/modules/*/kernel/drivers/net/tokenring
		/lib/modules/*/kernel/drivers/net/bonding
		/lib/modules/*/kernel/drivers/net/hamradio
	"
	for i in $files;do
		rm -rf $i
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
			rm -rf $i
		done
	fi
	#==========================================
	# remove unneeded tools
	#------------------------------------------
	local tools="
		tune2fs swapon swapoff shutdown sfdisk resize_reiserfs
		reiserfsck reboot halt pivot_root modprobe modinfo rmmod
		mkswap mkinitrd mkreiserfs mkfs.ext3 mkfs.ext2 mkfs.cramfs
		losetup ldconfig insmod init ifconfig fdisk e2fsck dhcpcd
		depmod atftpd klogconsole hwinfo xargs wc tail tac readlink
		mkfifo md5sum head expr file free find env du dirname cut
		column chroot atftp clear tr host test printf mount dd uname umount
		true touch sleep sh pidof sed rmdir rm pwd ps mv mkdir kill hostname
		gzip grep false df cp cat bash basename arch sort ls uniq lsmod
		usleep parted mke2fs pvcreate vgcreate lvm resize2fs ln hdparm
		dmesg splash fbmngplay portmap start-statd sm-notify
		rpc.statd rpc.idmapd nbd-client mount.nfs mount.nfs4 eject
		blockdev posbios ping killall killall5 udevcontrol udevd
		udevsettle udevtrigger mknod stat path_id hwup scsi_id scsi_tur
		usb_id ata_id vol_id edd_id setctsid dumpe2fs debugreiserfs
		fuser udevadm blogd showconsole killproc curl tar
	"
	tools="$tools $@"
	for path in /sbin /usr/sbin /usr/bin /bin;do
		baseStripTools "$path" "$tools"
	done
	#==========================================
	# remove images.sh
	#------------------------------------------
	rm -f /image/images.sh
}

#======================================
# suseGFXBoot
#--------------------------------------
function suseGFXBoot {
	local theme=$1
	local loader=$2
	export PATH=$PATH:/usr/sbin
	#======================================
	# check for gfxboot package
	#--------------------------------------
	if [ ! -d /usr/share/gfxboot ];then
		echo "gfxboot not installed... skipped"
		return
	fi
	#======================================
	# create boot theme
	#--------------------------------------
	cd /usr/share/gfxboot
	# check for new source layout
	local newlayout=
	[ -f themes/$theme/config ] && newlayout=1
	[ "$newlayout" ] || make -C themes/$theme prep
	if [ ! -z "$language" ];then
		local l1=`echo $language | cut -f1 -d.`
		local l2=`echo $language | cut -f1 -d_`
		local found=0
		for lang in $l1 $l2;do
			if [ -f themes/$theme/po/$lang.po ];then
				echo "Found language default: $lang"
				make -C themes/$theme DEFAULT_LANG=$lang
				found=1
				break
			fi
		done
		if [ $found -eq 0 ];then
			echo "Language $language not found, skipped"
			make -C themes/$theme
		fi
	else
		make -C themes/$theme
	fi
	mkdir /image/loader
	local gfximage=
	local grubimage=
	if [ "$newlayout" ] ; then
		gfximage=themes/$theme/bootlogo
		grubimage=themes/$theme/message
	else
		gfximage=themes/$theme/install/bootlogo
		grubimage=themes/$theme/boot/message
	fi
	if [ $loader = "isolinux" ];then
		cp themes/$theme/install/* /image/loader
		cp $gfximage /image/loader
		bin/unpack_bootlogo /image/loader
		mv /usr/share/syslinux/isolinux.bin /image/loader
		mv /boot/memtest.bin /image/loader/memtest
		echo "livecd=1" >> /image/loader/gfxboot.cfg
	fi
	if [ $loader = "grub" ];then
		mv $grubimage /image/loader
	fi
	make -C themes/$theme clean
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
	if [ ! $theme = "SuSE" ];then
		theme="SuSE-$theme"
	fi
	mkdir /image/loader/branding
	cp /etc/bootsplash/themes/$theme/images/logo.mng  /image/loader/branding
	cp /etc/bootsplash/themes/$theme/images/logov.mng /image/loader/branding
	for cfg in 800x600 1024x768 1280x1024;do
		cp /etc/bootsplash/themes/$theme/images/bootsplash-$cfg.jpg \
		/image/loader/branding
		cp /etc/bootsplash/themes/$theme/config/bootsplash-$cfg.cfg \
		/image/loader/branding
	done
	mkdir /image/loader/animations
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
# suseStripKernel
#--------------------------------------
function suseStripKernel {
	# /.../
	# this function will strip the kernel according to the
	# drivers information in config.xml. It also will create
	# the vmlinux.gz and vmlinuz files which are required
	# for the kernel extraction in case of kiwi boot images
	# ----
	local ifss=$IFS
	for i in /lib/modules/*;do
		IFS="
		"
		for p in `rpm -qf $i`;do
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
			VERSION=$(/usr/bin/basename $i)
			echo "Stripping kernel $p: Image [$name]..."
			#==========================================
			# move interesting stuff to /tmp
			#------------------------------------------
			if [ -d lib/modules/$VERSION/updates ];then
				mv lib/modules/$VERSION/updates /tmp
			fi
			if [ -d lib/modules/$VERSION/weak-updates ];then
				mv lib/modules/$VERSION/weak-updates /tmp
			fi
			mv lib/modules/$VERSION/kernel/*  /tmp
			mv lib/modules/$VERSION/modules.* /tmp
			#==========================================
			# remove unneeded stuff
			#------------------------------------------
			rm -r lib/modules/$VERSION/*
			#==========================================
			# insert modules.* files
			#------------------------------------------
			mv /tmp/modules.* /lib/modules/$VERSION/
			if [ -d /tmp/updates ];then
				mv /tmp/updates /lib/modules/$VERSION/
			fi
			if [ -d /tmp/weak-updates ];then
				mv /tmp/weak-updates /lib/modules/$VERSION/
			fi
			#==========================================
			# create driver-used dirs with .o's to use
			#------------------------------------------
			mkdir -p /tmp/usb-used
			mkdir -p /tmp/scsi-used/drivers/scsi
			mkdir -p /tmp/net-used/drivers/net
			mkdir -p /tmp/misc-used
			IFS=","
			#==========================================
			# handle USB drivers...
			#------------------------------------------
			test ! -z "$usbdrivers";for i in $usbdrivers;do
				local path=`dirname $i`
				test -f /tmp/drivers/$i && \
				mkdir -p /tmp/usb-used/drivers/$path && \
				mv /tmp/drivers/$i /tmp/usb-used/drivers/$path
			done
			#==========================================
			# handle SCSI drivers...
			#------------------------------------------
			test ! -z "$scsidrivers";for i in $scsidrivers;do
				local path=`dirname $i`
				if [ $path = "." ];then
					test -f /tmp/drivers/scsi/$i && \
					mv /tmp/drivers/scsi/$i /tmp/scsi-used/drivers/scsi
				else
					test -f /tmp/drivers/scsi/$i && \
					mkdir -p /tmp/scsi-used/drivers/scsi/$path && \
					mv /tmp/drivers/scsi/$i /tmp/scsi-used/drivers/scsi/$path
				fi
			done
			#==========================================
			# handle Network drivers...
			#------------------------------------------
			test ! -z "$netdrivers";for i in $netdrivers;do
				local path=`dirname $i`
				if [ $path = "." ];then
					test -f /tmp/drivers/net/$i && \
					mv /tmp/drivers/net/$i /tmp/net-used/drivers/net
				else
					test -f /tmp/drivers/net/$i && \
					mkdir -p /tmp/net-used/drivers/net/$path && \
					mv /tmp/drivers/net/$i /tmp/net-used/drivers/net/$path
				fi
			done
			#==========================================
			# handle misc drivers...
			#------------------------------------------
			test ! -z "$drivers";for i in $drivers;do
				local path=`/usr/bin/dirname $i`
				local base=`/usr/bin/basename $i`
				if [ "$base" = "*" ];then
					test -d /tmp/$path && \
					mkdir -p /tmp/misc-used/$path && \
					mv /tmp/$path/* /tmp/misc-used/$path
				else
					test -f /tmp/$i && \
					mkdir -p /tmp/misc-used/$path && \
					mv /tmp/$i /tmp/misc-used/$path
				fi
			done
			#==========================================
			# Save all needed drivers...
			#------------------------------------------
			IFS=$ifss
			for root in \
				/tmp/scsi-used /tmp/net-used /tmp/usb-used /tmp/misc-used
			do
				pushd $root
				for dir in `find -type d`;do
					if [ ! -d /lib/modules/$VERSION/kernel/$dir ];then
						mkdir -p /lib/modules/$VERSION/kernel/$dir 2>/dev/null
					fi
				done
				popd
			done
			for root in \
				/tmp/scsi-used /tmp/net-used /tmp/usb-used /tmp/misc-used
			do
				pushd $root
				for file in `find -type f`;do
					local path=`/usr/bin/dirname $file`
					mv $file /lib/modules/$VERSION/kernel/$path;
				done
				popd
			done
			#==========================================
			# Cleanup /tmp...
			#------------------------------------------
			rm -rf /tmp/*
			#==========================================
			# run depmod
			#------------------------------------------
			/sbin/depmod -F /boot/System.map-$VERSION $VERSION
			#==========================================
			# create common kernel files, last wins !
			#------------------------------------------
			pushd /boot
			mv vmlinux-$VERSION.gz vmlinux.gz
			mv vmlinuz-$VERSION vmlinuz
			popd
		done
	done
}
