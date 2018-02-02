#
# spec file for package kiwi
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.
#
# Please submit bugfixes or comments via:
#
#       https://github.com/openSUSE/kiwi/issues
#
#
#perl_verion is not defined in centos/RHEL yet
%if 0%{?rhel_version} || 0%{?centos_version}
%define perl_version    %(eval "`%{__perl} -V:version`"; echo $version)
%endif

# in TW and SLE12SP2 python-kiwi provides the kiwi-tools package
%if 0%{?suse_version} > 1320 || 0%{?sle_version} >= 120200
%bcond_with kiwitools
%bcond_with kiwipxeboot
%else
%bcond_without kiwitools
%bcond_without kiwipxeboot
%endif

Summary:        KIWI - Appliance Builder
Url:            http://github.com/openSUSE/kiwi
Name:           kiwi
License:        GPL-2.0
Group:          System/Management
Version:        7.04.41
Provides:       kiwi-schema = 6.2
Provides:       kiwi-image:aci
Provides:       kiwi-image:lxc
Provides:       kiwi-image:tbz
Provides:       kiwi:%{_mandir}/man1/kiwi.1.gz
Provides:       kiwi:%{_mandir}/man1/KIWI::images.sh.1.gz
Provides:       kiwi:%{_mandir}/man1/KIWI::config.sh.1.gz
Provides:       kiwi:%{_mandir}/man1/KIWI::kiwirc.1.gz
Conflicts:      kiwi-doc < 5
Release:        0
# requirements to build packages
BuildRequires:  genisoimage
BuildRequires:  diffutils
BuildRequires:  e2fsprogs
BuildRequires:  gcc-c++
BuildRequires:  libxslt
BuildRequires:  lvm2
BuildRequires:  module-init-tools
BuildRequires:  rsync
BuildRequires:  screen
BuildRequires:  zlib-devel
BuildRequires:  perl-Class-Singleton
BuildRequires:  perl-Config-IniFiles
BuildRequires:  perl-Digest-SHA1
BuildRequires:  perl-File-Slurp
BuildRequires:  perl-JSON
BuildRequires:  perl-Readonly
BuildRequires:  perl-XML-LibXML
BuildRequires:  perl-XML-LibXML-Common
BuildRequires:  perl-XML-SAX
BuildRequires:  perl-libwww-perl
BuildRequires:  perl-Test-Unit-Lite
%if 0%{?suse_version}
BuildRequires:  fdupes
%endif
%ifarch %ix86 x86_64
BuildRequires:  syslinux
%endif
%if 0%{?suse_version} > 1140
BuildRequires:  btrfsprogs
BuildRequires:  genisoimage
BuildRequires:  squashfs
BuildRequires:  zypper
%endif
# requirements to run kiwi
Requires:       perl >= %{perl_version}
Requires:       checkmedia
Requires:       coreutils
%if %{with kiwitools}
Requires:       kiwi-tools >= %{version}
%endif
Requires:       libxslt
Requires:       perl-Class-Singleton
Requires:       perl-Config-IniFiles >= 2.49
Requires:       perl-Digest-SHA1
Requires:       perl-File-Slurp
Requires:       perl-JSON
Requires:       perl-Readonly
Requires:       perl-XML-LibXML
Requires:       perl-XML-LibXML-Common
Requires:       perl-XML-SAX
Requires:       perl-libwww-perl
Requires:       rsync
Requires:       screen
Requires:       tar >= 1.2.7
Requires:       psmisc
Requires:       util-linux
%if 0%{?suse_version} == 1110
Requires:       sysvinit
%else
Requires:       sysvinit-tools
%endif
%if 0%{?suse_version}
# SUSE specific requires
%if 0%{?suse_version} >= 1210
Requires:       gptfdisk
Requires:       libsolv-tools
Requires:       perl-solv
%else
Requires:       satsolver-tools
Requires:       perl-satsolver >= 0.42
%endif
%if 0%{?suse_version} == 1110
Requires:       virt-utils
%else
Requires:       qemu-tools
%endif
%endif
%if 0%{?rhel_version} || 0%{?fedora} || 0%{?centos}
# RHEL specific requires
Requires:       qemu-img
%endif
# recommended to run kiwi
%if 0%{?suse_version}
Recommends:     db45-utils
Recommends:     db48-utils
%endif
# obsoletes
Obsoletes:      kiwi-desc-usbboot <= 4.81
Obsoletes:      kiwi-desc-xenboot <= 4.81
# sources
Source:         %{name}.tar.bz2
Source1:        %{name}-rpmlintrc
Source2:        %{name}-docu.tar.bz2
Source3:        %{name}-repo.tar.bz2
Source4:        %{name}-find-boot-requires.sh
# build root path
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

# find out about the name scheme of the local system for
# the buildservice needed -requires packages. In terms of
# problems with this magic ask adrian@suse.de for details

%if 0%{?suse_version}
%define mysystems %(echo `export VER=%{suse_version}; echo "suse-${VER:0:2}.${VER:2:1}"`)
# redefine for the SLES case if no sles_version exists
# SLE12:
%if 0%{?suse_version} == 1315 && !0%{?is_opensuse}
%define mysystems suse-SLES12
%endif
# Leap 42.1:
%if 0%{?suse_version} == 1315 && 0%{?is_opensuse}
%define mysystems suse-leap42.1
%endif
# Tumbleweed:
# Current Tumbleweed version, moving target
%if 0%{?suse_version} >= 1330 && !0%{?sle_version}
%define mysystems suse-tumbleweed
%endif
# redefine for the SLE11 case if no sles_version exists
# SLE11: NOTE: this works only because openSUSE 11.1 is out of scope
%if 0%{?suse_version} == 1110
%define mysystems suse-SLES11
%endif
%endif

# SLES with sles_version macro
%if 0%{?sles_version}
%define mysystems suse-SLES%{sles_version}
%endif

# RHEL // CentOS
# use the rhel templates for CentOS, too
%if 0%{?rhel_version} == 600 || 0%{?centos_version} == 600
%define mysystems rhel-06.0
%endif
%if 0%{?rhel_version} == 700 || 0%{?centos_version} == 700
%define mysystems rhel-07.0
%endif

# find out about my arch name, could be done also via symlinks
%define myarch %{_target_cpu}
%ifarch armv7l armv7hl
%define myarch armv7l
%endif
%ifarch armv6l armv6hl
%define myarch armv6l
%endif
%ifarch %ix86
%define myarch ix86
%endif

%description
The KIWI Image System provides an operating system image builder
for Linux supported hardware platforms as well as for virtualization
and cloud systems like Xen, KVM, VMware, EC2 and more. The online
documentation can be found here: http://doc.opensuse.org

Authors:
--------
        Marcus Schaefer <ms@suse.com>
        Robert Schweikert <rjschwei@suse.com>

%package -n kiwi-requires
Summary:        KIWI - buildservice package requirements
Provides:       kiwi-filesystem:btrfs
Provides:       kiwi-filesystem:xfs
Provides:       kiwi-filesystem:ext3
Provides:       kiwi-filesystem:ext4
Provides:       kiwi-filesystem:squashfs
Provides:       kiwi-image:docker
Requires:       btrfsprogs
Requires:       e2fsprogs
Requires:       kiwi = %{version}
License:        GPL-2.0
Group:          System/Management
%if 0%{?rhel_version} || 0%{?centos_version}
Provides:       kiwi-packagemanager:yum
Requires:       yum
Requires:       squashfs-tools
%endif
%if 0%{?suse_version}
Provides:       kiwi-packagemanager:zypper
Requires:       zypper
Requires:       squashfs
%endif
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-requires
Meta-package to pull in all requires to prepare a new root system.
It is used by Open Build Service (OBS) to provide and install the
needed packages automatically.

%package -n kiwi-instsource
Provides:       kiwi-packagemanager:instsource
Summary:        KIWI - Product media creator
Requires:       build
Requires:       createrepo
Requires:       inst-source-utils
Requires:       kiwi-instsource-plugin
Requires:       kiwi = %{version}
Requires:       genisoimage
%ifarch %ix86 x86_64
Requires:       syslinux
%endif
License:        GPL-2.0
Group:          System/Management

%description -n kiwi-instsource
This package contains modules used for installation source creation.
With those it is possible to create a valid installation repository
from blank RPM file trees. The created tree can be used directly for
the image creation process afterwards. This package allows using the
--create-instsource <path-to-config.xml> switch.

Authors:
--------
    Adrian Schroeter <adrian@suse.com>
    Stephan Kulow <coolo@suse.com>

%package -n kiwi-doc
Summary:        KIWI - Appliance Builder Documentation
License:        LGPL-2.0+
Group:          Documentation/Howto
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-doc
This package contains the documentation and manual pages for
the KIWI image builder.

Authors:
--------
        Thomas Schraitle <toms@suse.com>
        Marcus Schaefer <ms@suse.com>

%if %{with kiwitools}
%package -n kiwi-tools
Summary:        KIWI - Collection of Boot Helper Tools
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-tools
This package contains a small set of helper tools used for the
kiwi created initial ramdisk which is used to control the very
first boot of an appliance. The tools are not meant to be used
outside of the scope of kiwi appliance building.

Authors:
--------
        Marcus Schaefer <ms@suse.com>
%endif

%ifarch %ix86 x86_64
%if %{with kiwipxeboot}
%package -n kiwi-pxeboot
Summary:        KIWI - PXE boot structure
PreReq:         coreutils
%if 0%{?rhel_version} || 0%{?centos_version}
PreReq:         shadow-utils
%else
%if 0%{?suse_version} > 1220
PreReq:         shadow
%else
PreReq:         pwdutils
%endif
%endif
%ifarch %ix86 x86_64
Requires:       syslinux
%endif
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-pxeboot
This package contains the basic PXE directory structure which is
needed to serve kiwi built images via PXE.

Authors:
--------
        Marcus Schaefer <ms@suse.com>
%endif
%endif

%ifarch %ix86 x86_64

%package -n kiwi-desc-isoboot
Summary:        KIWI - Live ISO boot templates
Requires:       e2fsprogs
Requires:       kiwi = %{version}
%ifarch %ix86 x86_64
Requires:       syslinux
%endif
Requires:       dosfstools
%if 0%{?suse_version}
Requires:       genisoimage
%endif
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-isoboot
This package contains kiwi boot (initrd) descriptions for booting
live ISO images.

Authors:
--------
        Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-isoboot-requires
Provides:       kiwi-image:iso
Provides:       kiwi-boot:isoboot
%if 0%{?suse_version}
Requires:       genisoimage
%endif
Requires:       kiwi-desc-isoboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} isoboot %{myarch} %{mysystems}`)
%ifarch ppc ppc64 ppc64le
%if 0%{?suse_version} >= 1315
Requires:       grub2-powerpc-ieee1275
%else
Requires:       yaboot
%endif
%endif
%ifarch s390 s390x
Requires:       s390-tools
%endif
%ifarch %ix86 x86_64
# rhel7 has no grub, only grub2
%if 0%{?suse_version} < 1315 && 0%{?rhel_version} < 700 && 0%{?centos_version} < 700
Requires:       grub
%endif
%endif
Summary:        KIWI - buildservice package requirements for isoboot
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-isoboot-requires
Meta-package to pull in all requires to build an isoboot media.
It is used by Open Build Service (OBS) to provide and install the
needed packages automatically.

%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%package -n kiwi-desc-vmxboot
Summary:        KIWI - Virtual Machine boot templates
Requires:       lvm2
Requires:       dosfstools
Requires:       e2fsprogs
Requires:       kiwi = %{version}
Requires:       parted
%if 0%{?suse_version}
Requires:       multipath-tools
Requires:       squashfs
%endif
%if 0%{?rhel_version} || 0%{?centos_version}
Requires:       device-mapper-multipath
Requires:       squashfs-tools
%endif
%ifarch %ix86 x86_64
Requires:       syslinux
%if 0%{?suse_version} >= 1220 || 0%{?rhel_version} >= 700 || 0%{?centos_version} >= 700
Requires:       grub2
%else
Requires:       grub
%endif
%endif
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-vmxboot
This package contains kiwi boot (initrd) descriptions for booting
virtual disk images.

Authors:
--------
        Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-vmxboot-requires
Summary:        KIWI - buildservice package requirements for vmxboot
Provides:       kiwi-image:vmx
Provides:       kiwi-boot:vmxboot
%if 0%{?suse_version}
Requires:       genisoimage
%endif
Requires:       kiwi-desc-vmxboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} vmxboot %{myarch} %{mysystems}`)
%ifarch ppc ppc64 ppc64le
%if 0%{?suse_version} >= 1315
Requires:       grub2-powerpc-ieee1275
%else
Requires:       yaboot
%endif
%endif
%ifarch s390 s390x
Requires:       s390-tools
%endif
%ifarch %ix86 x86_64 %arm aarch64
%if 0%{?suse_version} < 1315 && 0%{?rhel_version} < 700 && 0%{?centos_version} < 700
Requires:       grub
%endif
%if 0%{?suse_version} >= 1220 || 0%{?rhel_version} >= 700 || 0%{?centos_version} >= 700
Requires:       grub2
%endif
%ifarch x86_64
Requires:       grub2-x86_64-efi
%endif
%ifarch %ix86
Requires:       grub2-i386-efi
%endif
%ifarch aarch64
Requires:       grub2-arm64-efi
%endif
%ifarch %arm
Requires:       grub2-arm-efi
%endif
%endif
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-vmxboot-requires
Meta-package to pull in all requires to build a vmxboot media.
It is used by Open Build Service (OBS) to provide and install the
needed packages automatically.

%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x

%package -n kiwi-desc-netboot
Summary:        KIWI - PXE network boot templates
Requires:       kiwi = %{version}
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-netboot
kiwi boot (initrd) image for booting PXE images.

Authors:
--------
        Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-netboot-requires
Provides:       kiwi-image:pxe
Provides:       kiwi-boot:netboot
Summary:        KIWI - buildservice package requirements for netboot
Requires:       kiwi-desc-netboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} netboot %{myarch} %{mysystems}`)
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-netboot-requires
Meta-package to pull in all requires to build a netboot media.
It is used by Open Build Service (OBS) to provide and install the
needed packages automatically.

%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%package -n kiwi-desc-oemboot
Summary:        KIWI - Expandable Virtual Machine boot templates
Requires:       lvm2
Requires:       dosfstools
Requires:       e2fsprogs
Requires:       kiwi = %{version}
Requires:       parted
%if 0%{?suse_version}
Requires:       genisoimage
Requires:       multipath-tools
Requires:       mtools
Requires:       squashfs
%endif
%if 0%{?rhel_version} || 0%{?centos_version}
Requires:       device-mapper-multipath
Requires:       squashfs-tools
%endif
%ifarch %ix86 x86_64
Requires:       syslinux
%if 0%{?suse_version} >= 1220 || 0%{?rhel_version} >= 700 || 0%{?centos_version} >= 700
Requires:       grub2
%else
Requires:       grub
%endif
%endif
%ifarch %arm aarch64
Requires:       u-boot-tools
%endif
License:        GPL-2.0
Group:          System/Management

%description -n kiwi-desc-oemboot
This package contains kiwi boot (initrd) descriptions for booting
expandable virtual disk images.

Authors:
--------
        Marcus Schaefer <ms@suse.com>

%package -n kiwi-desc-oemboot-requires
Provides:       kiwi-image:oem
Provides:       kiwi-boot:oemboot
Provides:       kiwi-boot:tbz
%if 0%{?suse_version}
Requires:       genisoimage
%endif
Requires:       kiwi-desc-oemboot = %{version}
Requires:       %(echo `bash %{S:4} %{S:0} oemboot %{myarch} %{mysystems}`)
%ifarch ppc ppc64 ppc64le
%if 0%{?suse_version} >= 1315
Requires:       grub2-powerpc-ieee1275
%else
Requires:       yaboot
%endif
%endif
%ifarch s390 s390x
Requires:       s390-tools
%endif
%ifarch %ix86 x86_64 %arm aarch64
%if 0%{?suse_version} < 1315 && 0%{?rhel_version} < 700 && 0%{?centos_version} < 700
Requires:       grub
%endif
%if 0%{?suse_version} >= 1220 || 0%{?rhel_version} >= 700 || 0%{?centos_version} >= 700
Requires:       grub2
%endif
%ifarch x86_64
Requires:       grub2-x86_64-efi
%endif
%ifarch %ix86
Requires:       grub2-i386-efi
%endif
%ifarch aarch64
Requires:       grub2-arm64-efi
%endif
%ifarch %arm
Requires:       grub2-arm-efi
%endif
%endif

Summary:        KIWI - buildservice package requirements for oemboot
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-desc-oemboot-requires
Meta-package to pull in all requires to build a oemboot media.
It is used by Open Build Service (OBS) to provide and install the
needed packages automatically.

%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%package -n kiwi-templates
Summary:        KIWI - JeOS system image templates
PreReq:         coreutils
Requires:       kiwi-desc-vmxboot = %{version}
License:        GPL-2.0+
Group:          System/Management

%description -n kiwi-templates
This package contains system image templates to easily build
a JeOS based operating system image with kiwi 

Authors:
--------
        Marcus Schaefer <ms@suse.com>
%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%package -n kiwi-media-requires
Summary:        Packages which should be part of the DVD media
License:        GPL-2.0+
Group:          System/Management
%if 0%{?suse_version}
Recommends:     busybox
Recommends:     atftp
Recommends:     gfxboot
Recommends:     memtest86+
Recommends:     kiwi
Recommends:     kiwi-desc-oemboot
Recommends:     kiwi-desc-vmxboot
Recommends:     kiwi-desc-isoboot
Recommends:     kiwi-desc-netboot
Recommends:     kiwi-templates
Recommends:     fribidi
Recommends:     fbiterm
%ifarch x86_64
%if 0%{?suse_version} > 1220
Recommends:     shim
%endif
%endif
%endif
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-media-requires
This package recommends a set of packages which should be part of
the DVD distribution. Some kiwi system/boot templates references
those packages and it is assumed that they are part of the 
distributed source media (DVD)

Authors:
--------
        Marcus Schaefer <ms@suse.com>
%endif

%package -n kiwi-test
Requires:       kiwi = %{version}
Requires:       perl-Test-Unit-Lite
Summary:        Unit tests for kiwi
License:        GPL-2.0
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-test
This package contains the unit tests executed during package build and
used for development testing.

Authors:
--------
        Robert Schweikert <rjschwei@suse.com>
        Marcus Schaefer <ms@suse.com>

%prep
%setup -q -n %name -a2 -a3

%build
echo "mysystems set to: %{mysystems}"
# empty because of rpmlint warning rpm-buildroot-usage

%if 0%{?suse_version} > 1140
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

%if %{with kiwipxeboot}
%ifarch %ix86 x86_64
    install -m 644 pxeboot/pxelinux.0.config \
        $RPM_BUILD_ROOT/srv/tftpboot/pxelinux.cfg/default.default
%else
    # no PXE boot setup for non x86 archs
    rm -rf $RPM_BUILD_ROOT/srv/tftpboot
    rm -rf $RPM_BUILD_ROOT/etc/permissions.d/kiwi
%endif
%else
    rm -rf $RPM_BUILD_ROOT/srv/tftpboot
    rm -rf $RPM_BUILD_ROOT/etc/permissions.d/kiwi
%endif

mkdir -p $RPM_BUILD_ROOT/var/cache/kiwi
mkdir -p $RPM_BUILD_ROOT/var/cache/kiwi/packages
mkdir -p $RPM_BUILD_ROOT/var/cache/kiwi-images

test -f $RPM_BUILD_ROOT/srv/tftpboot/pxelinux.0 && \
    echo /srv/tftpboot/pxelinux.0 > kiwi.loader
test -f $RPM_BUILD_ROOT/srv/tftpboot/mboot.c32 && \
    echo /srv/tftpboot/mboot.c32 >> kiwi.loader
./.links
%if 0%{?suse_version} > 1020
%fdupes $RPM_BUILD_ROOT/srv/tftpboot
%fdupes $RPM_BUILD_ROOT/usr/share/kiwi/image
%fdupes $RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/examples
%fdupes $RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/schema
%fdupes $RPM_BUILD_ROOT/usr/share/kiwi/tests/unit/data
%endif
cat kiwi.loader

%if 0%{?suse_version}
# suse provides this tool in an extra package, others don't
rm -f $RPM_BUILD_ROOT/usr/bin/setctsid
%endif

for i in isoboot vmxboot netboot oemboot ; do
    if [ -d  $RPM_BUILD_ROOT/%{_datadir}/kiwi/image/$i ]; then
        cat > $RPM_BUILD_ROOT/%{_datadir}/kiwi/image/$i/README.requires <<EOF
This is a meta package to pull in all dependencies required for $i kiwi
images. This is supposed to be used in Open Build Service in first place
to track the dependencies.
EOF
    fi
done
cat > $RPM_BUILD_ROOT/%{_datadir}/kiwi/README.requires <<EOF
This is a meta package to pull in all base dependencies required for kiwi
images. This is supposed to be used in Open Build Service in first place
to track the dependencies.
EOF

%if !%{with kiwitools}
shopt -s extglob
rm -f %{buildroot}%{_defaultdocdir}/kiwi/README.tools
rm -f %{buildroot}%{_bindir}/!(livestick)
%endif

%ifarch %ix86 x86_64
%if %{with kiwipxeboot}
%pre -n kiwi-pxeboot
#============================================================
# create user and group tftp if they does not exist
if ! /usr/bin/getent group tftp >/dev/null; then
    %{_sbindir}/groupadd -r tftp 2>/dev/null || :
fi
if ! /usr/bin/getent passwd tftp >/dev/null; then
    %{_sbindir}/useradd -c "TFTP account" -d /srv/tftpboot -G tftp -g tftp \
        -r -s /bin/false tftp 2>/dev/null || :
fi

%post -n kiwi-pxeboot
#============================================================
# create /srv/tftpboot/pxelinux.cfg/default only if not exist
if ( [ ! -e srv/tftpboot/pxelinux.cfg/default  ] ) ; then
    cp /srv/tftpboot/pxelinux.cfg/default.default \
        /srv/tftpboot/pxelinux.cfg/default
fi
%endif
%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%post -n kiwi-templates
#============================================================
# Clean up old old template directories if present
for dist in 10.1 10.2 10.3 11.0 11.1 11.2 11.3 12.1 12.2 12.3 SLE10 SLED10; do
    if ( [ -d /usr/share/kiwi/image/suse-$dist-JeOS ] ) ; then
        rm -rf /usr/share/kiwi/image/suse-$dist-JeOS
    fi
done
%endif

%post -n kiwi
# make sure kiwi can create this file from scratch with the
# permissions it needs and is not in trouble if it exists
# already with permissions which doesn't allow kiwi to create
# or use this file if kiwi is called as non root user
rm -f /dev/shm/lwp-download

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
%dir /var/cache/kiwi-images
%dir /var/cache/kiwi/packages
%doc %{_mandir}/man1/kiwi.1.gz
%doc %{_mandir}/man1/KIWI::images.sh.1.gz
%doc %{_mandir}/man1/KIWI::config.sh.1.gz
%doc %{_mandir}/man1/KIWI::kiwirc.1.gz
%ifarch %ix86 x86_64
%exclude %{_datadir}/kiwi/image/suse-13.1-JeOS
%exclude %{_datadir}/kiwi/image/suse-13.2-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE11-community-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%exclude %{_datadir}/kiwi/image/suse-leap-42.1-JeOS
%exclude %{_datadir}/kiwi/image/rhel-06.6-JeOS
%exclude %{_datadir}/kiwi/image/rhel-07.0-JeOS
%endif
%ifarch s390 s390x
%exclude %{_datadir}/kiwi/image/suse-SLE11-community-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%endif
%ifarch %arm aarch64
%exclude %{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%endif
%{_datadir}/kiwi/.revision
%{_datadir}/kiwi/modules
%{_datadir}/kiwi/metadata
%{_datadir}/kiwi/livestick
%{_datadir}/kiwi/editing
%{_datadir}/kiwi/locale
%{_datadir}/kiwi/repo
%{_datadir}/emacs/site-lisp
%config /etc/bash_completion.d/kiwi.sh
%exclude %{_datadir}/kiwi/metadata/KIWIIsoLinux-AppleFileMapping.map
%exclude %{_datadir}/kiwi/modules/KIWICollect.pm
%exclude %{_datadir}/kiwi/modules/KIWIRepoMetaHandler.pm
%exclude %{_datadir}/kiwi/modules/KIWIUtil.pm
%{_datadir}/kiwi/xsl
%{_sbindir}/kiwi
/usr/bin/livestick

%files -n kiwi-requires
%defattr(-, root, root)
%doc %{_datadir}/kiwi/README.requires
#=================================================
# KIWI doc...      
#-------------------------------------------------

%files -n kiwi-doc
%defattr(-, root, root)
%dir %{_defaultdocdir}/kiwi
%{_defaultdocdir}/kiwi/COPYING
%{_defaultdocdir}/kiwi/examples
%{_defaultdocdir}/kiwi/html
%{_defaultdocdir}/kiwi/pdf
%{_defaultdocdir}/kiwi/schema
#=================================================
# KIWI instsource...      
#-------------------------------------------------

%files -n kiwi-instsource
%defattr(-, root, root)
%{_datadir}/kiwi/metadata/KIWIIsoLinux-AppleFileMapping.map
%{_datadir}/kiwi/modules/KIWICollect.pm
%{_datadir}/kiwi/modules/KIWIUtil.pm
%{_datadir}/kiwi/modules/KIWIRepoMetaHandler.pm

#=================================================
# KIWI-pxeboot files...  
# ------------------------------------------------
%ifarch %ix86 x86_64
%if %{with kiwipxeboot}
%files -n kiwi-pxeboot -f kiwi.loader
%defattr(-, root, root)
%dir %attr(0750,tftp,tftp) /srv/tftpboot
%doc /srv/tftpboot/README
%dir /srv/tftpboot/KIWI
%dir /srv/tftpboot/pxelinux.cfg
%dir /srv/tftpboot/image
%dir /srv/tftpboot/upload
%dir /srv/tftpboot/boot
/srv/tftpboot/pxelinux.cfg/default.default
%endif
%endif
#=================================================
# KIWI-tools files...  
# ------------------------------------------------

%if %{with kiwitools}
%files -n kiwi-tools
%defattr(-, root, root)
%dir %{_defaultdocdir}/kiwi
%doc %{_defaultdocdir}/kiwi/README.tools
%exclude /usr/bin/livestick
/usr/bin/*
%endif
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

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

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

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x

%files -n kiwi-desc-netboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/netboot
%doc %{_datadir}/kiwi/image/netboot/README
%{_datadir}/kiwi/image/netboot/suse*
%ifarch %ix86 x86_64
%{_datadir}/kiwi/image/netboot/rhel*
%endif

%files -n kiwi-desc-netboot-requires
%defattr(-, root, root)
%doc %{_datadir}/kiwi/image/netboot/README.requires
%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

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

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%files -n kiwi-templates
%defattr(-, root, root)
%ifarch %ix86 x86_64
%{_datadir}/kiwi/image/suse-13.1-JeOS
%{_datadir}/kiwi/image/suse-13.2-JeOS
%{_datadir}/kiwi/image/suse-SLE11-community-JeOS
%{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%{_datadir}/kiwi/image/suse-leap-42.1-JeOS
%{_datadir}/kiwi/image/rhel-06.6-JeOS
%{_datadir}/kiwi/image/rhel-07.0-JeOS
%endif
%ifarch s390 s390x
%{_datadir}/kiwi/image/suse-SLE11-community-JeOS
%{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%endif
%ifarch %arm aarch64
%{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%endif
%ifarch ppc ppc64 ppc64le
%{_datadir}/kiwi/image/suse-SLE11-community-JeOS
%{_datadir}/kiwi/image/suse-SLE12-community-JeOS
%endif

%endif

%ifarch %ix86 x86_64 ppc ppc64 ppc64le s390 s390x %arm aarch64

%files -n kiwi-media-requires
%defattr(-, root, root)
%dir %{_defaultdocdir}/kiwi

%endif

%files -n kiwi-test
%defattr(-, root, root)
%{_datadir}/kiwi/tests

%changelog
