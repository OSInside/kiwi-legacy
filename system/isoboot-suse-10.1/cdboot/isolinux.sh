#!/bin/bash

#=======================================
# Globals
#---------------------------------------
CD_PREPARER="KIWI-Team - http://kiwi.berlios.de"
CD_PUBLISHER="SUSE LINUX Products GmbH, suse@suse.de"

#=======================================
# Globals
#---------------------------------------
PARAMS="-r -J -pad -joliet-long"
SORTFILE=`mktemp /var/tmp/m_cd-XXXXXX`
SOURCE2=`mktemp -d /var/tmp/m_cd-XXXXXX`
ROOT_ON_CD=suse
BOOT_BASE_DIR=boot
BOOT_IMAGE=$BOOT_BASE_DIR/image
BOOT_ISOLINUX=$BOOT_BASE_DIR/loader

#=======================================
# Parameters
#---------------------------------------
SOURCE=$1  # source tree
DEST=$2    # output file

#=======================================
# Create ISO
#---------------------------------------
TMP_LS=`/bin/ls -d $SOURCE/*/update 2> /dev/null`
if test -d $SOURCE/$BOOT_BASE_DIR \
	-o -d $SOURCE/$ROOT_ON_CD -o ! -z "$TMP_LS"
then
	if test -f $SOURCE/$BOOT_IMAGE -o -f $SOURCE/.boot \
		-o -d $SOURCE/$BOOT_ISOLINUX \
		-o -d $SOURCE/etc -o -f $SOURCE/boot/silo.conf
	then
		mkdir -p $SOURCE2 || { echo "can't create tmpdir $SOURCE2" ; exit 1 ; }
		chmod 755 $SOURCE2
		if [ -f $SOURCE/.boot ] ; then
			PARAMS="$PARAMS -b .boot -c boot.catalog"
			echo found boot image. Making CD bootable.
			mkdir -p $SOURCE2/$BOOT_BASE_DIR || exit 1
		elif [ -f $SOURCE/$BOOT_IMAGE ] ; then
			# needed for ia64
			xx=`filesize $SOURCE/$BOOT_IMAGE`
			if [ \( "$xx" -ne 1474560 \) -a \( "$xx" -ne 2949120 \) ] ; then
			if head -c 200 $SOURCE/$BOOT_IMAGE | \
				grep -a -q 'Sorry, didn.t find boot loader, stopped.'
			then
				PARAMS="$PARAMS -hard-disk-boot"
			else
				PARAMS="$PARAMS -no-emul-boot"
			fi
			fi
			echo "$SOURCE2/$BOOT_BASE_DIR/boot.catalog 2" >$SORTFILE
			echo "$SOURCE/$BOOT_IMAGE 1" >>$SORTFILE
			PARAMS="$PARAMS -sort $SORTFILE -b $BOOT_IMAGE \
					-c $BOOT_BASE_DIR/boot.catalog \
					-hide $BOOT_BASE_DIR/boot.catalog \
					-hide-joliet $BOOT_BASE_DIR/boot.catalog"
			echo found boot image. Making CD bootable.
			mkdir -p $SOURCE2/$BOOT_BASE_DIR || exit 1
		elif [ -d $SOURCE/$BOOT_ISOLINUX ] ; then
			echo "$SOURCE2/$BOOT_BASE_DIR/boot.catalog 3" >$SORTFILE
			echo "$BOOT_BASE_DIR/boot.catalog 3" >>$SORTFILE
			echo "$SOURCE/$BOOT_BASE_DIR/boot.catalog 3" >>$SORTFILE
			find $SOURCE/$BOOT_ISOLINUX -printf "%p 1\n" >>$SORTFILE
			# last priority wins
			echo "$SOURCE/$BOOT_ISOLINUX/isolinux.bin 2" >>$SORTFILE
			echo "sortfile has"
			cat $SORTFILE
			echo "end sortfile"
			# isolinux expects a directory
			PARAMS="$PARAMS -sort $SORTFILE -no-emul-boot \
				-boot-load-size 4 -boot-info-table \
				-b $BOOT_ISOLINUX/isolinux.bin \
				-c $BOOT_BASE_DIR/boot.catalog \
				-hide $BOOT_BASE_DIR/boot.catalog \
				-hide-joliet $BOOT_BASE_DIR/boot.catalog"
			echo found boot image. Making CD bootable.
			mkdir -p $SOURCE2/$BOOT_BASE_DIR || exit 1
		else
			if [ -d $SOURCE/etc ] ; then
				echo found $SOURCE/etc. put it at the beginning of iso image.
				mkdir -p $SOURCE2/etc || exit 1
			else
				if [ -f $SOURCE/boot/silo.conf ] ; then
					PARAMS="$PARAMS -silo-boot boot/second.b -s /boot/silo.conf"
					echo found SPARC boot config. Making CD bootable.
					mkdir -p $SOURCE2/boot || exit 1
				fi
			fi
		fi
		XPARAMS="$SOURCE2"
	else 
		echo found no boot image. No bootable CD.
	fi

	if test -f $SOURCE/content -a -z "$TMP_LS" ; then
		# we already collected this above
		APPID=$DISTIDENT
	elif test -f $SOURCE/$DESCRDIR/info ; then
		set -- `fgrep DIST_IDENT $SOURCE/$DESCRDIR/info`
		APPID=$2
	else
		# If we have directory "update" in the second level, we assume
		# this is a Patch-CD
		if test ! -z "$TMP_LS" ; then
		if test -f $SOURCE/media.1/patches ; then
			APPID="`cat $SOURCE/media.1/patches|sed -e"s|/ ||g" | tr " " _`"
		else
			APPID="`cat $SOURCE/.S.u.S.E-disk-* | tr " " _`"
		fi
		fi
	fi
	if test -z "$APPID" \
		-a -f $SOURCE/$ROOT_ON_CD/MD5SUMS \
		-a -f $SOURCE/.S.u.S.E-disk-*
	then
		APPID=`cat $SOURCE/.S.u.S.E-disk-*|tr " " - |sed -e"s@-Version-@-@"`
		APPID="$APPID.0#0"
	fi
	APPID=`echo $APPID | tr " " -`
	test -n "$APPID" && PARAMS="$PARAMS -A $APPID"

	if test -f $SOURCE/content ; then
		MEDIANUMBER=1
		for i in $SOURCE/media.? ; do
			test -d $i || continue
			MEDIADIR=`ls -d $SOURCE/media.?`
			MEDIANUMBER=${MEDIADIR##$SOURCE/media.}
		done
		VOL="0$MEDIANUMBER"
	elif test -f $SOURCE/.S.u.S.E-disk-* ; then
		BASE=`basename $SOURCE/.S.u.S.E-disk-*`
		VOL=`echo $BASE | cut -c 16-17`
	fi
	if test -n "$VOL" ; then
		DIS=`echo $APPID | sed -e "s/.*-//" | tr -d \.\#`
		VOL_PREFIX="SU"
		case "$APPID" in
			*Basic*)
				KND="B"
			;;
			*Evaluation*)
				KND="E"
			;;
			*FTP*)
				KND="F"
			;;
			*full*)
				KND="Z"
			;;
			*ITP*)
				KND="I"
			;;
			*Runtime*)
				KND="R"
			;;
			*Patch-CD*)
				DIS="PATCH"
				KND="P"
			;;
			*)
				KND="0"
			;;
		esac
		VOL="$VOL_PREFIX$DIS.$KND$VOL"
		if test -n "$VOL" ; then
			PARAMS="$PARAMS -V $VOL"
		fi
	fi
fi

isolinux-config --base $BOOT_ISOLINUX $SOURCE/$BOOT_ISOLINUX/isolinux.bin
mkisofs \
	-p "$CD_PREPARER" \
	-publisher "$CD_PUBLISHER" \
	$PARAMS -o $DEST $XPARAMS $SOURCE

#=======================================
# Clean up
#---------------------------------------
if [ -d "$SOURCE2" ] ; then
	echo removing $SOURCE2
	rm -r $SOURCE2
fi

if [ -e "$SORTFILE" ] ; then
	echo removing $SORTFILE
	rm -f "$SORTFILE"
fi
