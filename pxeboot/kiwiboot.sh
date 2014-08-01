#!/bin/sh
# to generate a grub boot disk or CD with network (PXE boot)
# support one has to create a disk boot image and use this
# disk boot image as boot image for the CD with floppy emulation
# enabled
#
#===================================
# check for root privileges
#-----------------------------------
if [ ! $UID = 0 ];then
    echo "---> Only root can do this... abort"
    exit 1
fi

#===================================
# check for the grub stages
#-----------------------------------
if [ ! -d /usr/lib/grub ];then
    echo "---> Couldn't find the grub... abort"
    exit 1
fi

#===================================
# Ask for the TFTP Server
#-----------------------------------
while test -z "$TFTP_SERVER";do
    read -p "Enter the IP Address of the TFTP server: " TFTP_SERVER
    if [ ! -z $TFTP_SERVER ];then
        echo $TFTP_SERVER | pcregrep -q "^\d{1,3}\.\d{1,3}.\d{1,3}.\d{1,3}$"
        if [ ! $? = 0 ];then
            echo "---> Invalid IP Address specified"
            TFTP_SERVER=""
        fi
    fi
done

#===================================
# create temp dir and catch errors
#-----------------------------------
TMPDIR=$(mktemp -q -d /tmp/$0.XXXXXX)
if [ $? -ne 0 ]; then
    echo "---> Can't create temp file, exiting..."
    exit 1
fi

#===================================
# create disk image
#-----------------------------------
dd if=/dev/zero of=$TMPDIR/kiwiFD.dsk bs=18k count=80
mkdosfs $TMPDIR/kiwiFD.dsk

#===================================
# mount disk image and copy stages
#-----------------------------------
mount -o loop $TMPDIR/kiwiFD.dsk /mnt
mkdir -p /mnt/boot/grub
cp /usr/lib/grub/stage1          /mnt/boot/grub/stage1
cp /usr/lib/grub/stage2.netboot  /mnt/boot/grub/stage2

#===================================
# create menu.lst for the grub
#-----------------------------------
menu=/mnt/boot/grub/menu.lst
echo "color white/blue black/light-gray" > $menu
echo "default 0"       >> $menu
echo "timeout 8"       >> $menu
echo "framebuffer 1"   >> $menu
echo "title KIWI"      >> $menu
echo " bootp"          >> $menu
echo " tftpserver $TFTP_SERVER"   >> $menu
echo " kernel (nd)/boot/linux vga=normal ramdisk_size=128000" >> $menu
echo " initrd (nd)/boot/initrd"   >> $menu
umount /mnt

#===================================
# install grub on image
#-----------------------------------
/usr/sbin/grub --batch <<-EOT
    device (fd0) $TMPDIR/kiwiFD.dsk
    root (fd0)
    setup (fd0)
    quit
EOT

#===================================
# Create boot ISO for CD
#-----------------------------------
mkdir -p $TMPDIR/CD/boot/grub
cd $TMPDIR && cp kiwiFD.dsk $TMPDIR/CD/boot/grub
mkisofs -R -b boot/grub/kiwiFD.dsk \
    -boot-info-table -o kiwiCD.iso CD
rm -rf CD

echo "--> Find images at: $TMPDIR"
exit 0
