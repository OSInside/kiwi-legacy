#
# spec file for package kiwi
#
# Copyright (c) 2012 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Url:            http://github.com/openSUSE/kiwi
Name:           kiwi
Summary:        OpenSUSE - KIWI Image System
License:        GPL-2.0
Group:          System/Management
Version:        5.03.35
Release:        0
# requirements to build packages
BuildRequires:  gcc-c++
BuildRequires:  libxslt
BuildRequires:  module-init-tools
BuildRequires:  perl-Config-IniFiles
BuildRequires:  perl-XML-LibXML
BuildRequires:  perl-libwww-perl
BuildRequires:  screen
BuildRequires:  zlib-devel
%if %{suse_version} > 1020
BuildRequires:  fdupes
%endif
%ifarch %ix86 x86_64
BuildRequires:  syslinux
%endif
%if %{suse_version} > 1030
BuildRequires:  libexpat-devel
BuildRequires:  rpm-devel
%endif
%if %{suse_version} > 1140
BuildRequires:  btrfsprogs
BuildRequires:  cdrkit-cdrtools-compat
BuildRequires:  genisoimage
BuildRequires:  perl-Test-Unit
BuildRequires:  squashfs
BuildRequires:  zypper
%endif
# requirements to run kiwi
Requires:       checkmedia
Requires:       coreutils
Requires:       kiwi-tools
Requires:       libxslt
Requires:       perl = %{perl_version}
Requires:       perl-Config-IniFiles
Requires:       perl-XML-LibXML
Requires:       perl-XML-LibXML-Common
Requires:       perl-XML-SAX
Requires:       perl-libwww-perl
Requires:       rsync
Requires:       screen
Requires:       util-linux
%ifarch %ix86 x86_64
%if %{suse_version} > 1010
Requires:       squashfs
%endif
%endif
%if %{suse_version} > 1030
Requires:       satsolver-tools
%endif
%ifarch %ix86 x86_64
Requires:       master-boot-code
%if %{suse_version} > 1110
Requires:       clicfs >= 1.3.9
%endif
%endif
# recommended to run kiwi
%if 0%{?suse_version}
Recommends:     perl-satsolver >= 0.42
Recommends:     jing
Recommends:     zypper
Recommends:     lxc
%endif
%if %{suse_version} > 1140
Recommends:     db45-utils
%endif
# obsoletes
Obsoletes:      kiwi-desc-usbboot <= 4.81
# sources
Source:         %{name}.tar.bz2
Source1:        %{name}-rpmlintrc
Source2:        %{name}-docu.tar.bz2
Source3:        %{name}-repo.tar.bz2
Source4:        %{name}-find-boot-requires.sh
# build root path
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

# find out about the name scheme of the local system for -requieres packages
%if 0%{?suse_version}
%if 0%{?sles_version}
%define mysystems suse-SLES%{sles_version} suse-SLED%{sles_version}
%else
%define mysystems %(echo `export VER=%{suse_version}; echo "suse-${VER:0:2}.${VER:2:1}"`)
%endif
%endif
%if 0%{?rhel_version}
%define mysystems %(echo `VER=%{rhel_version} echo "rhel-0${VER:0:1}.${VER:1:2}"`)
%endif
# find out about my arch name, could be done also via symlinks
%define myarch %{_target_cpu}
%ifarch armv7l armv7hl
%define myarch armv7l
%endif
%ifarch %ix86
%define myarch ix86
%endif

%description
The OpenSUSE KIWI Image System provides a complete operating system
image solution for Linux supported hardware platforms as well as for
virtualization systems like Xen.

Authors:
--------
    Marcus Schaefer <ms@suse.com>

%package -n kiwi-instsource
Requires:       build
Requires:       createrepo
Requires:       inst-source-utils
Requires:       kiwi = %{version}
Summary:        Installation Source creation
License:        GPL-2.0
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-instsource
This package contains modules used for installation source creation.
With those it is possible to create a valid installation repository
from blank RPM file trees. The created tree can be used directly for
the image creation process afterwards. This package allows using the
--create-instsource <path-to-config.xml> switch.

Authors:
--------
	Adrian Schroeter <adrian@suse.com>
	Jan Bornschlegel <jcborn@suse.com>

%package -n kiwi-doc
Summary:        OpenSUSE - KIWI Image System Documentation
License:        LGPL-2.0+
Group:          Documentation/Howto
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-doc
This package contains the documentation and manual pages for the KIWI
Image System

Authors:
--------
    Thomas Schraitle
    Marcus Schaefer

%package -n kiwi-tools
Summary:        OpenSUSE - KIWI tools collection
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-tools
This package contains the OpenSUSE - KIWI tools set usable in and
outside of operating system images

Authors:
--------
    Marcus Schaefer <ms@suse.com>

%ifarch %ix86 x86_64

%package -n kiwi-pxeboot
Requires:       syslinux
Summary:        OpenSUSE - KIWI Image System PXE boot structure
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-pxeboot
PXE basic directory structure and pre-build boot images

Authors:
--------
    Marcus Schaefer <ms@suse.com>
%endif

%ifarch %ix86 x86_64

%package -n kiwi-desc-isoboot
Requires:       kiwi = %{version}
Requires:       syslinux
Requires:       e2fsprogs
%if %{suse_version} > 1010
Requires:       genisoimage
%else
Requires:       mkisofs
%endif
%ifarch ppc ppc64 s390 s390x
Requires:       virt-utils
%else
%if 0%{?suse_version} >= 1130
Requires:       virt-utils
%endif
%endif
Summary:        OpenSUSE - KIWI Image System ISO boot
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-isoboot
kiwi boot (initrd) image for activating system images on ISO media

Authors:
--------
    Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-isoboot-requires
Requires:       kiwi-desc-isoboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} isoboot %{myarch} %{mysystems}`)
Summary:        OpenSUSE - KIWI Image System ISO boot required packages
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-isoboot-requires
Meta-package to pull in all requires to build a isoboot media.

%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%package -n kiwi-desc-vmxboot
Requires:       kiwi = %{version}
%if 0%{?suse_version}
Requires:       multipath-tools
Requires:       parted
%endif
%if 0%{?rhel_version}
Requires:       device-mapper-multipath
Requires:       parted
%endif
%ifarch %ix86 x86_64
%if 0%{?suse_version} >= 1220
Requires:       grub2
%else
Requires:       grub
%endif
%endif
%ifarch ppc ppc64 s390 s390x
Requires:       virt-utils
%else
%if 0%{?suse_version} >= 1130
Requires:       virt-utils
%endif
%if 0%{?suse_version} < 1130
Requires:       qemu
%endif
%if 0%{?rhel_version}
Requires:       qemu-img
%endif
%endif
Summary:        OpenSUSE - KIWI Image System Virtual Machine boot
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-vmxboot
kiwi boot (initrd) image for activating system images on virtual disk

Authors:
--------
    Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-vmxboot-requires
Requires:       kiwi-desc-vmxboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} vmxboot %{myarch} %{mysystems}`)
Summary:        OpenSUSE - KIWI Image System VMX boot required packages
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-vmxboot-requires
Meta-package to pull in all requires to build a vmxboot media.

%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%package -n kiwi-desc-netboot
Requires:       kiwi = %{version}
Summary:        OpenSUSE - KIWI Image System PXE network boot
%ifarch ppc ppc64 s390 s390x
Requires:       virt-utils
%else
%if 0%{?suse_version} >= 1130
Requires:       virt-utils
%endif
%endif
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-netboot
kiwi boot (initrd) image for activating system images via TFTP

Authors:
--------
    Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-netboot-requires
Requires:       kiwi-desc-netboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} netboot %{myarch} %{mysystems}`)
Summary:        OpenSUSE - KIWI Image System NET boot required packages
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-netboot-requires
Meta-package to pull in all requires to build a netboot media.

%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%package -n kiwi-desc-oemboot
Requires:       kiwi = %{version}
%ifarch %arm
Requires:       u-boot-tools
%endif
%ifarch ppc ppc64 s390 s390x
Requires:       virt-utils
%else
%if 0%{?suse_version} >= 1130
Requires:       virt-utils
%endif
%if 0%{?suse_version} < 1130
Requires:       qemu
%endif
%if 0%{?rhel_version}
Requires:       qemu-img
%endif
%endif
%if 0%{?suse_version}
Requires:       multipath-tools
Requires:       parted
%endif
%if 0%{?rhel_version}
Requires:       device-mapper-multipath
Requires:       parted
%endif
%ifarch %ix86 x86_64
Requires:       grub
%endif
%if %{suse_version} > 1010
Requires:       genisoimage
%else
Requires:       mkisofs
%endif
Summary:        OpenSUSE - KIWI image descriptions
License:        GPL-2.0
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-oemboot
This package contains the OpenSUSE - KIWI image descriptions. Each
image description exists in a single directory and contains an oemboot
image description

Authors:
--------
    Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-oemboot-requires
Requires:       kiwi-desc-oemboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} oemboot %{myarch} %{mysystems}`)
Summary:        OpenSUSE - KIWI Image System oem boot required packages
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-oemboot-requires
Meta-package to pull in all requires to build a oemboot media.

%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%package -n kiwi-templates
Requires:       kiwi-desc-vmxboot = %{version}
Summary:        OpenSUSE - KIWI JeOS system image templates
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-templates
This package contains system image templates to easily build
a JeOS based operating system image with kiwi 

Authors:
--------
    Marcus Schaefer
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%package -n kiwi-media-requires
Summary:        OpenSUSE - packages which should be part of the DVD
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif
%if 0%{?suse_version}
Recommends:     busybox
Recommends:     atftp
Recommends:     gfxboot
Recommends:     memtest86+
Recommends:     lxc
%if 0%{?suse_version} > 1210
Recommends:     grub2-branding-openSUSE
%endif
%endif

%description -n kiwi-media-requires
This package recommends a set of packages which should be part of
the DVD distribution. Some kiwi system/boot templates references
those packages and it is assumed that they are part of the 
distributed source media (DVD)

Authors:
--------
    Marcus Schaefer
%endif

%prep
%setup -n %name -a2 -a3

%build
# empty because of rpmlint warning rpm-buildroot-usage

%if %{suse_version} > 1140
%check
make KIWIVERBTEST=1 KIWI_NO_NET=1 test
%endif

%install
# build
test -e /.buildenv && . /.buildenv
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

#install
cd $RPM_BUILD_DIR/kiwi
make buildroot=$RPM_BUILD_ROOT \
     doc_prefix=$RPM_BUILD_ROOT/%{_defaultdocdir} \
     man_prefix=$RPM_BUILD_ROOT/%{_mandir} \
     install
touch kiwi.loader

%ifarch %ix86 x86_64
	install -m 644 pxeboot/pxelinux.0.config \
		$RPM_BUILD_ROOT/srv/tftpboot/pxelinux.cfg/default.default
%else
	# no PXE boot setup for non x86 archs
	rm -rf $RPM_BUILD_ROOT/srv/tftpboot
	rm -rf $RPM_BUILD_ROOT/etc/permissions.d/kiwi
%endif

mkdir -p $RPM_BUILD_ROOT/var/cache/kiwi

test -f $RPM_BUILD_ROOT/srv/tftpboot/pxelinux.0 && \
	echo /srv/tftpboot/pxelinux.0 > kiwi.loader
test -f $RPM_BUILD_ROOT/srv/tftpboot/mboot.c32 && \
	echo /srv/tftpboot/mboot.c32 >> kiwi.loader
./.links
%if %{suse_version} > 1020
%fdupes $RPM_BUILD_ROOT/srv/tftpboot
%fdupes $RPM_BUILD_ROOT/usr/share/kiwi/image
%fdupes $RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/examples
%fdupes $RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/schema
%endif
cat kiwi.loader

for i in isoboot vmxboot netboot oemboot ; do
  if [ -d  $RPM_BUILD_ROOT/%{_datadir}/kiwi/image/$i ]; then
    cat > $RPM_BUILD_ROOT/%{_datadir}/kiwi/image/$i/README.requires <<EOF
This is a meta package to pull in all dependencies required for $i kiwi
images. This is supposed to be used in Open Build Service in first place
to track the dependencies.
EOF
  fi
done

%ifarch %ix86 x86_64
%post -n kiwi-pxeboot
#============================================================
# create /srv/tftpboot/pxelinux.cfg/default only if not exist
	if ( [ ! -e srv/tftpboot/pxelinux.cfg/default  ] ) ; then
		cp /srv/tftpboot/pxelinux.cfg/default.default /srv/tftpboot/pxelinux.cfg/default
	fi
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%post -n kiwi-templates
#============================================================
# Clean up old old template directories if the exists
oldDists=( 10.1 10.2 10.3 11.0 11.1 11.2 )
for dist in ${oldDists[@]};do
	rm -rf /usr/share/kiwi/image/suse-$dist-JeOS
done
%endif

%clean
rm -rf $RPM_BUILD_ROOT
#=================================================
# KIWI files...      
#-------------------------------------------------

%files
%defattr(-, root, root)
%dir %{_datadir}/kiwi
%dir %{_datadir}/kiwi/image
%dir /var/cache/kiwi
%doc %{_mandir}/man1/kiwi.1.gz
%doc %{_mandir}/man1/KIWI::images.sh.1.gz
%doc %{_mandir}/man1/KIWI::config.sh.1.gz
%doc %{_mandir}/man1/KIWI::kiwirc.1.gz
%ifarch %ix86 x86_64
%exclude %{_datadir}/kiwi/image/suse-11.4-JeOS
%exclude %{_datadir}/kiwi/image/suse-12.1-JeOS
%exclude %{_datadir}/kiwi/image/suse-12.2-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE10-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE11-JeOS
%exclude %{_datadir}/kiwi/image/rhel-05.4-JeOS
%exclude %{_datadir}/kiwi/image/rhel-06.0-JeOS
%endif
%ifarch s390 s390x
%exclude %{_datadir}/kiwi/image/suse-SLE11-JeOS
%endif
%ifarch %arm
%exclude %{_datadir}/kiwi/image/suse-12.2-JeOS
%endif
%{_datadir}/kiwi/.revision
%{_datadir}/kiwi/modules
%{_datadir}/kiwi/locale
%{_datadir}/kiwi/repo
%exclude %{_datadir}/kiwi/modules/KIWIIsoLinux-AppleFileMapping.txt
%exclude %{_datadir}/kiwi/modules/KIWICollect.pm
%exclude %{_datadir}/kiwi/modules/KIWIRepoMetaHandler.pm
%exclude %{_datadir}/kiwi/modules/KIWIUtil.pm
%{_datadir}/kiwi/xsl
%{_sbindir}/kiwi
#=================================================
# KIWI doc...      
#-------------------------------------------------

%files -n kiwi-doc
%defattr(-, root, root)
%dir %{_defaultdocdir}/kiwi
%{_defaultdocdir}/kiwi/COPYING
%{_defaultdocdir}/kiwi/examples
%{_defaultdocdir}/kiwi/images
%{_defaultdocdir}/kiwi/kiwi.pdf
%{_defaultdocdir}/kiwi/kiwi.html
%{_defaultdocdir}/kiwi/susebooks.css
%{_defaultdocdir}/kiwi/schema
#=================================================
# KIWI instsource...      
#-------------------------------------------------

%files -n kiwi-instsource
%defattr(-, root, root)
%{_datadir}/kiwi/modules/KIWIIsoLinux-AppleFileMapping.txt
%{_datadir}/kiwi/modules/KIWICollect.pm
%{_datadir}/kiwi/modules/KIWIUtil.pm
%{_datadir}/kiwi/modules/KIWIRepoMetaHandler.pm

#=================================================
# KIWI-pxeboot files...  
# ------------------------------------------------
%ifarch %ix86 x86_64

%files -n kiwi-pxeboot -f kiwi.loader
%defattr(-, root, root)
%doc /srv/tftpboot/README
%dir /srv/tftpboot
%dir /srv/tftpboot/KIWI
%dir /srv/tftpboot/pxelinux.cfg
%dir /srv/tftpboot/image
%dir /srv/tftpboot/upload
%dir /srv/tftpboot/boot
/srv/tftpboot/pxelinux.cfg/default.default
%endif
#=================================================
# KIWI-tools files...  
# ------------------------------------------------

%files -n kiwi-tools
%defattr(-, root, root)
%doc %{_defaultdocdir}/kiwi/README.tools
/usr/bin/*
#=================================================
# KIWI-desc-* and templates...
# ------------------------------------------------
%ifarch %ix86 x86_64

%files -n kiwi-desc-isoboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/isoboot
%doc %{_datadir}/kiwi/image/isoboot/README
%{_datadir}/kiwi/image/isoboot/suse*
%{_datadir}/kiwi/image/isoboot/rhel*

%files -n kiwi-desc-isoboot-requires
%defattr(-, root, root)
%doc %{_datadir}/kiwi/image/isoboot/README.requires
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%files -n kiwi-desc-vmxboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/vmxboot
%doc %{_datadir}/kiwi/image/vmxboot/README
%{_datadir}/kiwi/image/vmxboot/suse*
%ifarch %ix86 x86_64
%{_datadir}/kiwi/image/vmxboot/rhel*
%endif

%files -n kiwi-desc-vmxboot-requires
%defattr(-, root, root)
%doc %{_datadir}/kiwi/image/vmxboot/README.requires
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%files -n kiwi-desc-netboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/netboot
%doc %{_datadir}/kiwi/image/netboot/README
%{_datadir}/kiwi/image/netboot/suse*

%files -n kiwi-desc-netboot-requires
%defattr(-, root, root)
%doc %{_datadir}/kiwi/image/netboot/README.requires
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%files -n kiwi-desc-oemboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/oemboot
%doc %{_datadir}/kiwi/image/oemboot/README
%{_datadir}/kiwi/image/oemboot/suse*
%ifarch %ix86 x86_64
%{_datadir}/kiwi/image/oemboot/rhel*
%endif

%files -n kiwi-desc-oemboot-requires
%defattr(-, root, root)
%doc %{_datadir}/kiwi/image/oemboot/README.requires
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%files -n kiwi-templates
%defattr(-, root, root)
%ifarch %ix86 x86_64
%{_datadir}/kiwi/image/suse-11.4-JeOS
%{_datadir}/kiwi/image/suse-12.1-JeOS
%{_datadir}/kiwi/image/suse-12.2-JeOS
%{_datadir}/kiwi/image/suse-SLE10-JeOS
%{_datadir}/kiwi/image/suse-SLE11-JeOS
%{_datadir}/kiwi/image/rhel-05.4-JeOS
%{_datadir}/kiwi/image/rhel-06.0-JeOS
%endif
%ifarch s390 s390x
%{_datadir}/kiwi/image/suse-SLE11-JeOS
%endif
%ifarch %arm
%{_datadir}/kiwi/image/suse-12.2-JeOS
%endif
%ifarch ppc ppc64
%{_datadir}/kiwi/image/suse-SLE11-JeOS
%endif

%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x %arm

%files -n kiwi-media-requires
%defattr(-, root, root)
%dir %{_defaultdocdir}/kiwi

%endif

%changelog
