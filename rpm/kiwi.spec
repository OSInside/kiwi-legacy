# /.../
# spec file for package kiwi (Version 1.2)
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
Name:          kiwi
BuildRequires: perl smart perl-XML-LibXML syslinux perl-libwww-perl screen qemu multipath-tools
Requires:      perl smart perl-XML-LibXML syslinux perl-libwww-perl screen qemu multipath-tools
Summary:       OpenSuSE - KIWI Image System
Version:       1.7
Release:       7
Group:         System
License:       GPL
Source:        kiwi.tar.bz2
BuildRoot:     %{_tmppath}/%{name}-%{version}-build

%description
This package contains the OpenSuSE - KIWI Image System

Authors:
--------
    Marcus Schäfer <ms@suse.de>

%package -n kiwi-pxeboot
Summary:      OpenSuSE - KIWI TFTP boot structure
Group:        System

%description -n kiwi-pxeboot
This package contains the OpenSuSE - KIWI TFTP boot structure

Authors:
--------
    Marcus Schäfer <ms@suse.de>


%package -n kiwi-images-boot
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-images-boot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a boot image description

%package -n kiwi-images-wyse
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-images-wyse
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a thin client description for Wyse terminals

%package -n kiwi-images-buildservice
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-images-buildservice
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a buildservice description for a package building client

%package -n kiwi-images-liveDVD
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-images-liveDVD
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a live DVD description for a package building client

Authors:
--------
    Marcus Schäfer <ms@suse.de>

%prep
%setup -n kiwi
# %patch

%build
rm -rf $RPM_BUILD_ROOT
test -e /.buildenv && . /.buildenv
#cat /proc/mounts > /etc/fstab
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

if [ $UID = 0 ];then
	# prepare and create boot images...
	mkdir -p $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.cfg
	mkdir -p $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot
	for i in `find system/boot/ -name restart`;do
		rm -f $i && cp -a tools/restart $i
	done
	for i in `find system/boot/ -name timed`;do
		rm -f $i && cp -a tools/timed $i
	done
	cd modules
	pxedefault=$RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.cfg/default
	echo "# /.../" > $pxedefault
	echo "# KIWI boot image setup" >> $pxedefault
	echo "# select boot label according to your system image" >> $pxedefault
	echo "# ..."  >> $pxedefault
	echo "DEFAULT Local-Boot" >> $pxedefault
	images="
		netboot/suse-10.1 netboot/suse-10.1-smp
		netboot/suse-10.2 netboot/suse-10.2-smp
		xenboot/suse-10.1
		xenboot/suse-10.2
	"
	for i in $images;do
		rootName=`echo $i | tr / -`
		echo "#DEFAULT $rootName" >> $pxedefault
	done
	echo >> $pxedefault
	echo "LABEL Local-Boot"  >> $pxedefault
	echo "      localboot 0" >> $pxedefault
	for i in $images;do
		rootName=`echo $i | tr / -`
		../kiwi.pl --root $RPM_BUILD_ROOT/root-$rootName --prepare ../system/boot/$i
		../kiwi.pl --create $RPM_BUILD_ROOT/root-$rootName \
			-d $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot
		rm -rf $RPM_BUILD_ROOT/root-$rootName
		echo >> $pxedefault
		echo "LABEL $rootName" >> $pxedefault
		(
			cd $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot
			xenkernel=""
			xenloader=""
			initrd=""
			kernel=""
			for n in *$rootName*;do
				echo $n | grep -q xen$      && xenkernel=$n || true
				echo $n | grep -q xen.gz$   && xenloader=$n || true
				echo $n | grep -q [0-9].gz$ && initrd=$n    || true
				echo $n | grep -q kernel    && kernel=$n    || true
			done
			if [ -n "$xenkernel" ];then
				echo "      kernel mboot.c32" >> $pxedefault
				echo "      append boot/$xenloader --- boot/$xenkernel vga=0x318 --- boot/$initrd" >> $pxedefault
				echo "      IPAPPEND 1" >> $pxedefault
			else
				echo "      kernel boot/$kernel" >> $pxedefault
				echo "      append initrd=boot/$initrd vga=0x318" >> $pxedefault
				echo "      IPAPPEND 1" >> $pxedefault
			fi
		)
	done
	rm -f $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot/*.md5
else
	echo "cannot build prebuild images without root privileges"
	true
fi

%install
mkdir -p $RPM_BUILD_ROOT/etc/permissions.d
echo "/var/lib/tftpboot/upload root:root 0777" \
	> $RPM_BUILD_ROOT/etc/permissions.d/kiwi
make buildroot=$RPM_BUILD_ROOT \
     doc_prefix=$RPM_BUILD_ROOT/%{_defaultdocdir} \
     man_prefix=$RPM_BUILD_ROOT/%{_mandir} \
     install
touch kiwi.loader
if [ ! $UID = 0 ];then
	install -m 755 pxeboot/pxelinux.0.config \
		$RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.cfg/default
fi
test -L $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.0 && \
	echo %{_var}/lib/tftpboot/pxelinux.0 > kiwi.loader
test -L $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/mboot.c32 && \
	echo %{_var}/lib/tftpboot/mboot.c32 >> kiwi.loader

cat kiwi.loader

#=================================================
# KIWI files...      
#-------------------------------------------------
%files
%defattr(-, root, root)
%dir %{_datadir}/kiwi
%dir %{_datadir}/kiwi/image
%{_datadir}/kiwi/modules
%{_datadir}/kiwi/tools
%{_sbindir}/kiwi

#=================================================
# KIWI-netboot files...  
# ------------------------------------------------
%files -n kiwi-pxeboot -f kiwi.loader
%defattr(-, root, root)
/etc/permissions.d/kiwi
%dir %{_var}/lib/tftpboot
%dir %{_var}/lib/tftpboot/KIWI
%dir %{_var}/lib/tftpboot/boot
%dir %{_var}/lib/tftpboot/pxelinux.cfg
%dir %{_var}/lib/tftpboot/image
%dir %{_var}/lib/tftpboot/upload
%{_var}/lib/tftpboot/boot
%{_var}/lib/tftpboot/pxelinux.cfg/default

#=================================================
# KIWI-images...
# ------------------------------------------------
%files -n kiwi-images-boot
%defattr(-, root, root)
%{_datadir}/kiwi/image/*boot*

%files -n kiwi-images-wyse
%defattr(-, root, root)
%{_datadir}/kiwi/image/wyseGhost-suse-10.1
%{_datadir}/kiwi/image/wyseGhost-suse-10.2
%{_datadir}/kiwi/image/wyseXMini-suse-10.1

%files -n kiwi-images-buildservice
%{_datadir}/kiwi/image/buildhost-suse-10.1
%defattr(-, root, root)

%files -n kiwi-images-liveDVD
%{_datadir}/kiwi/image/kwliveDVD-suse-10.3
%defattr(-, root, root)

%changelog -n kiwi
* Tue Feb 06 2007 - ms@suse.de
- better/faster device probing
* Sun Feb 04 2007 - ms@suse.de
- added support for qemu and vmdk (VMware) images (F:#301945)
- added targets usb:<type><boot> and vmx:<type><boot>
- use sparse files for buildhost image (Xen support)
- update documentation
* Thu Feb 01 2007 - ms@suse.de
- added wyseXMini-suse-10.1 to kiwi-images-wyse package
* Thu Feb 01 2007 - ms@suse.de
- added check for second level installation. The check will
  lookup already installed packages and remove them from the
  list if set
* Tue Jan 30 2007 - ms@suse.de
- fixed chroot path problem if repository pointer is a
  symbolic link to somewhere else
* Sat Jan 27 2007 - ms@suse.de
- added improved size information
* Fri Jan 26 2007 - ms@suse.de
- added wyseXMini description for a 128 MB image usable
  on a Wyse Model VX0 terminal only
* Wed Jan 24 2007 - ms@suse.de
- added rpm-force=true option for smart level 2 installation
- added support for zypper level 2 installation
* Sun Jan 21 2007 - ms@suse.de
- added perl-TimeDate to buildhost image
- fixed linuxrc to provide reiserfs in INITRD_MODULES even if
  the image is not reiserfs based. This has been done for backward
  compatibility
* Fri Jan 19 2007 - ms@suse.de
- added bsmd init script for buildservice image. This runlevel
  script is used to automatically setup a md0 raid for /abuild
* Wed Jan 17 2007 - ms@suse.de
- added bootable flag for first system partition
* Tue Jan 16 2007 - ms@suse.de
- fixed pattern support
- fixed support for prebuild boot images. They can only be built
  if the build user is root. I'm hoping to get rid of that
  requirement in the future
* Wed Dec 27 2006 - ms@suse.de
- fixed build in opensuse environment
* Tue Dec 19 2006 - ms@suse.de
- added documentation about image deployment
- added prebuild boot images
* Thu Dec 14 2006 - ms@suse.de
- added option -O dir_index for ext3 images
* Wed Dec 06 2006 - ms@suse.de
- added wyseGhost-suse-10.2 system to kiwi
* Wed Dec 06 2006 - ms@suse.de
- added support for modifiying user accounts
- added support for --list option which gives an overview
  about the available image descriptions
- added support for specifying --prepare without path. In that
  case it is assumed the image can be found in /usr/share/kiwi/image
- changed repository and package structure. Split kiwi-images
  into kiwi-images-boot and a kiwi-images-<Systems> packages
* Fri Dec 01 2006 - ms@suse.de
- update isoboot-suse-10.2 CD data
* Wed Nov 29 2006 - ms@suse.de
- starting zypper integration: added support removing services
  and getting package info: KIWIManager::resetSource
* Wed Nov 29 2006 - ms@suse.de
- starting zypper integration: added support for adding installation
  sources. This means method: KIWIManager::setupInstallationSource()
* Fri Nov 24 2006 - ms@suse.de
- rewrite root code to be able to easily exchange the
  package manager. This has been done to be able to integrate
  other package managers like zypper.
- update documentation
* Wed Nov 22 2006 - ms@suse.de
- reduced boot image size of netboot-suse-10.2 image
* Tue Nov 21 2006 - ms@suse.de
- update bsworker init skript in buildhost image
* Mon Nov 20 2006 - ms@suse.de
- reduced boot image size of usbboot-suse-10.2 image
- added basic system to inherit data from one config
  description to another. Update documentation concerning the
  inherit attribute
- fixed URL handler not to start if URL is not pointing to the
  network. This will increase startup speed in case of local
  build
* Fri Nov 17 2006 - ms@suse.de
- added ata/ tree to boot images for 10.2 and 10.2-smp
- fixed on-stick image support. Tested default 10.2 from USB
  stick, works great :-)
* Tue Nov 14 2006 - ms@suse.de
- added support for system image on stick. One need to use
  option --bootstick in combination with --bootstick-system.
  The parameter to --bootstick must be an usbboot initrd
  provided by kiwi. The parameter to --bootstick-system is
  a kiwi generated system image. Support for this is <alpha>
* Thu Nov 09 2006 - ms@suse.de
- fixed build for non SUSE distributions
* Wed Nov 08 2006 - ms@suse.de
- fixed pattern support
* Mon Nov 06 2006 - ms@suse.de
- added samba to the wyse image, only samba no client for now
* Fri Nov 03 2006 - ms@suse.de
- fixed this:// path if non absolut path specifications are used
  as paramter to the --prepare option
* Thu Nov 02 2006 - ms@suse.de
- added wyse description to source repository
- added image size check to initrd. The needed space is now
  displayed while downloading the image. If there is not enough
  space the download will not start
* Sat Oct 28 2006 - ms@suse.de
- creating an ISO image requires kiwi to implicitly create a boot
  image which is copied on the CD. It is very important that the
  kernel of the image and the boot image is the same. According to
  this I changed the code to use the same <repository> information
  for the boot image as it was used during prepare of the main image.
  The additional meta information is stored in
  image-root/image/main::Prepare
* Wed Oct 25 2006 - ms@suse.de
- added netboot descriptions for 10.1[-smp]/10.2[-smp]
- remove loop device usage from liveCD setup
- added high level URL: this:// which points to the
  description directory itself. This is usefull if you want
  to add an additional repository in your image description
  tree for example
* Mon Oct 23 2006 - ms@suse.de
- changed isolinux description files in cdboot/
- added isoboot-suse-10.2 image for 10.2 live CD setup
- include ext2 into boot images because the kernel exports
  the filesystem as module now
* Fri Oct 20 2006 - ms@suse.de
- fix for linuxrc sata detection. The order to load the
  modules piix and ata_piix is important to detect the disk
* Thu Oct 19 2006 - ms@suse.de
- added support for autoyast profiles
- fixed pattern support, don't use recommends (Prc)
- added <ignore> tag to be able to remove packages when needed
- adapt documentation
* Tue Oct 17 2006 - ms@suse.de
- improved recursive pattern check, setup pattern cache
* Fri Oct 13 2006 - ms@suse.de
- added grub and hwinfo to boot images
* Thu Oct 12 2006 - ms@suse.de
- added /srv/* and /var/log/* to the in-place repository
- added support for SuSE patterns. Patterns have been
  added with openSuSE 10.2 and can be used to describe a
  package set with one statement. To use this system the
  XML description provides the tag:
  <opensusePattern name="..."/>
* Mon Oct 09 2006 - ms@suse.de
- cleanup boot package list
- added option --createpassword to create cryp codes
* Thu Oct 05 2006 - ms@suse.de
- fixed xen build environment setup
* Mon Oct 02 2006 - ms@suse.de
- added support for <users> section. This allows the config.xml
  to specifiy users/groups to be added to the image. Update
  documentation concerning this feature
* Fri Sep 29 2006 - ms@suse.de
- added cramfs support for read-only images
* Fri Sep 22 2006 - ms@suse.de
- add setup of rpm-check-signatures option in xml description
* Tue Sep 19 2006 - ms@suse.de
- run smart update/install actions in screen session(s)
- added support for stripping binaries [--strip]
* Mon Sep 18 2006 - ms@suse.de
- fixed build for distributions without mboot.c32
  loader packaged in syslinux package
* Mon Sep 18 2006 - ms@suse.de
- added support for image deployment via USB stick and CD
- added support for --logfile option
* Fri Sep 15 2006 - ms@suse.de
- fixed repository handling in case of same types
- fixed return code handling of mktemp() call
- fixed setupMount() if source if a loop device
- disabled gpg key checking temporarily until smart -y
  really stops asking for fingerprint confirmation
* Wed Sep 13 2006 - ms@suse.de
- added drivers/message/fusion to xenboot image
- fixed bsworker init script to setup xen build
* Tue Sep 12 2006 - ms@suse.de
- fixed permissions for ssh keys in buildhost
- fixed hosts entries in buildhost
* Tue Sep 12 2006 - ms@suse.de
- added support for split images. These are images which
  consist of two portions. The first one contains the Read/Write
  data and the second contains the ReadOnly data according to
  current FHS. Each image can have its own filesystem which
  means you can put the ReadOnly part into a compressed filesystem
  as well. Disadvantage of such an image is that it requires a
  boot infrastructure to become activated.
* Fri Sep 08 2006 - ms@suse.de
- added linux32 to buildhost image
* Wed Sep 06 2006 - ms@suse.de
- added arch information to image name
- update cdboot documentation
* Mon Sep 04 2006 - ms@suse.de
- fixed adding subversion repository of /etc tree
- added cleanSmart() function to remove kiwi created smart
  channels on HUP signal
* Fri Sep 01 2006 - ms@suse.de
- added support for in-place subversion repository. This
  can be used to create an update dif before reloading an image
* Fri Sep 01 2006 - ms@suse.de
- added authorized_keys for root of buildhost image
- fixed boot images not to create the resolv.conf file
  this should be done automatically by the network setup
- added ntp service for buildhost image
- added dhcp config information to sysconfig/network
  This will set the hostname and resolv.conf
- added ssh host keys to the buildhost image
* Thu Aug 31 2006 - ms@suse.de
- fixed buildhost image: added hosts, fixed bsworker
- fixed kernel extracting, extract for boot images only
* Wed Aug 30 2006 - ms@suse.de
- fixed filesystem type detection in linuxrc
- fixed xenboot image to install the xen base package.
  This is needed to extract the xen.gz kernel to be able
  to multiboot the xen kernel with an initrd (mboot.c32)
* Tue Aug 29 2006 - ms@suse.de
- fixed missing kernel module.* alias,info files
- added new xenboot subtree for boot images with xen kernel
* Wed Aug 09 2006 - ms@suse.de
- fixed pxe config file initrd=... statement
- added 3com tg3 and bcm5700 network drivers to suse netboot
- changed location of pxelinux.0 and pxelinux.cfg
- added support for SATA und SCSI storage devices
* Tue Jul 25 2006 - ms@suse.de
- added support for Live CD file systems (CD ISO)
  The bootstrap code for the live CD is not yet ready
* Mon Jul 24 2006 - ms@suse.de
- added syslinux requirement instead of using a packed pxelinux.0
- added %%defattr(-, root, root) to %%files section. Thanks to
  Christoph Thiel <cthiel@suse.de>
* Fri Jul 21 2006 - ms@suse.de
- added support for high level urls like opensuse://
- added new XML format
* Wed Jul 12 2006 - ms@suse.de
- added helper script to generate grub boot disk and CD
- fixed linuxrc to mount the image os if needed
- added checkTFTP() function to check for the tftp server
  1) at the kernel cmdline
  2) as host tftp.$DOMAIN
  3) as the same host as the DHCP server is
* Thu Jul 06 2006 - ms@suse.de
- First Version of KIWI - Image system
* Thu Jul 06 2006 - ms@suse.de
- added support for LVM in initrd
- added opensuse installation source in image descriptions
- added lvm services to be started if installed
- added lvm2 package to package set for suse images
