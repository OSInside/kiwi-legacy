# /.../
# spec file for package kiwi (Version 1.2)
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
Name:          kiwi
BuildRequires: syslinux
Requires:      perl smart perl-XML-LibXML syslinux perl-libwww-perl
Summary:       OpenSuSE - KIWI Image System
Version:       1.2
Release:       1
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
Version:      1.2
Release:      1
Summary:      OpenSuSE - KIWI TFTP boot structure
Group:        System

%description -n kiwi-pxeboot
This package contains the OpenSuSE - KIWI TFTP boot structure

Authors:
--------
    Marcus Schäfer <ms@suse.de>


%package -n kiwi-images
Requires:     kiwi
Version:      1.2
Release:      1
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-images
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory 

Authors:
--------
    Marcus Schäfer <ms@suse.de>

%prep
%setup -n kiwi
# %patch

%build
test -e /.buildenv && . /.buildenv
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/etc/permissions.d
echo "/var/lib/tftpboot/upload root:root 0777" \
	> $RPM_BUILD_ROOT/etc/permissions.d/kiwi
make buildroot=$RPM_BUILD_ROOT \
     doc_prefix=$RPM_BUILD_ROOT/%{_defaultdocdir} \
     man_prefix=$RPM_BUILD_ROOT/%{_mandir} \
     install
test -f $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.0 && \
	echo %{_var}/lib/tftpboot/pxelinux.0 > kiwi.loader
test -f $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/mboot.c32 && \
	echo %{_var}/lib/tftpboot/mboot.c32 >> kiwi.loader

#=================================================
# KIWI files...      
#-------------------------------------------------
%files
%defattr(-, root, root)
%dir %{_datadir}/kiwi
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
%{_var}/lib/tftpboot/pxelinux.cfg/default

#=================================================
# KIWI-images...
# ------------------------------------------------
%files -n kiwi-images
%defattr(-, root, root)
%{_datadir}/kiwi/image

%changelog -n kiwi
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
