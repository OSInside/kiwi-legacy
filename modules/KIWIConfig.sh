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
	for p in `rpm -qa`;do
		#echo "Creating post script for package: $p"
		rpm -q --qf \
			"%|POSTIN?{%|POSTINPROG?{}|%{POSTIN}\n}:{%|POSTINPROG?{}|}|" \
		$p > $p.sh
		if [ -s "$p.sh" ];then
			echo "Calling post script $p.sh"
			need=`bash $p.sh 2>&1 | grep "for service" | cut -f10 -d " "`
			if [ ! -z "$need" ];then
				suseInsertService $need
			fi
		fi
		rm -f $p.sh
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
			sed -e s@KEYTABLE=\".*\"@KEYTABLE=\"$keytable\"@ \
		> etc/sysconfig/keyboard.new
		mv etc/sysconfig/keyboard.new etc/sysconfig/keyboard
	fi
	#======================================
	# locale
	#--------------------------------------
	if [ ! -z "$locale" ];then
		cat /etc/sysconfig/language |\
			sed -e s@RC_LANG=\".*\"@RC_LANG=\"$locale\"@ \
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
		if [ $found = 0 ];then
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
# baseSetupInPlaceGITRepository
#--------------------------------------
function baseSetupInPlaceGITRepository {
	# /.../
	# create an in place git repository of the root
	# directory. This process may take some time and you
	# may expect problems with binary data handling
	# ----
	if [ -x /usr/bin/git ];then
		echo "git not installed... skipped"
		return
	fi
	pushd /
	echo /proc > .gitignore
	echo /sys >> .gitignore
	echo /dev >> .gitignore
	git init && git add . && \
	git commit -m "deployed"
	popd
}

#======================================
# suseStripInitrd
#--------------------------------------
function suseStripInitrd {
	#==========================================
	# remove unneeded files
	#------------------------------------------
	rpm -e popt bzip2 --nodeps
	rm -rf `find -type d | grep .svn`
	local files="
		/usr/share/info /usr/share/man /usr/share/cracklib /usr/lib*/python*
		/usr/lib*/perl* /usr/share/locale /usr/share/doc/packages /var/lib/rpm
		/usr/lib*/rpm /var/lib/smart /boot/* /opt/* /usr/include /root/.gnupg
		/etc/PolicyKit /etc/sysconfig /etc/init.d /etc/profile.d /etc/skel
		/etc/ssl /etc/java /etc/default /etc/cron* /etc/dbus* /etc/modprobe*
		/etc/pam.d* /etc/DIR_COLORS /etc/rc* /usr/share/hal /usr/share/ssl
		/usr/lib*/hal /usr/lib*/*.a /usr/lib*/*.la /usr/lib*/librpm*
		/usr/lib*/libssl* /usr/lib*/libpanel* /usr/lib*/libncursesw*
		/usr/lib*/libmenu* /usr/src/packages/RPMS
		/usr/X11R6 /usr/lib*/X11 /var/X11R6 /usr/share/X11 /etc/X11
		/usr/lib*/libX* /usr/lib*/xorg
		/etc/ppp /etc/xdg /etc/NetworkManager /lib*/YaST /lib*/security
		/lib*/mkinitrd /srv /var/adm /usr/lib/engines /usr/src/packages
		/usr/src/linux* /usr/local
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
			/usr/lib*/libzypp* /usr/lib*/libx*
			/var/cache/zypp
		"
		for i in $files;do
			rm -rf $i
		done
	fi
	#==========================================
	# remove unneeded tools
	#------------------------------------------
	local tools="
		tune2fs swapon shutdown sfdisk resize_reiserfs
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
		usb_id ata_id vol_id edd_id setctsid
	"
	tools="$tools $@"
	for path in /sbin /usr/sbin /usr/bin /bin;do
		baseStripTools "$path" "$tools"
	done
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
	make -C themes/$theme prep
	make -C themes/$theme
	mkdir /image/loader
	if [ $loader = "isolinux" ];then
		cp themes/$theme/install/* /image/loader
		bin/unpack_bootlogo /image/loader
		for i in init languages log;do
			rm -f /image/loader/$i
		done
		mv /usr/share/syslinux/isolinux.bin /image/loader
		mv /boot/memtest.bin /image/loader/memtest
		echo "livecd=1" >> /image/loader/gfxboot.cfg
	fi
	if [ $loader = "grub" ];then
		mv themes/$theme/boot/message /image/loader
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
	mkdir /image/loader/animations
	cp /etc/bootsplash/themes/$theme/animations/* /image/loader/animations
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
