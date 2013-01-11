#
# spec file for package kiwi (Version 4.85.94)
#
# Copyright (c) 2010 SUSE LINUX Products GmbH, Nuernberg, Germany.
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

# needsrootforbuild

Url:            http://kiwi.berlios.de
Name:           kiwi
BuildRequires:  perl-Config-IniFiles perl-XML-LibXML perl-libwww-perl
BuildRequires:  module-init-tools screen zlib-devel
BuildRequires:  gcc-c++ libxslt swig trang
%if %{suse_version} > 1020
BuildRequires:  fdupes
%endif
%ifarch %ix86 x86_64
BuildRequires:  syslinux
%endif
%if %{suse_version} > 1010
BuildRequires:  libqt4 libqt4-devel
%else
BuildRequires:  freetype2-devel libpng-devel qt qt-devel
%endif 
%if %{suse_version} > 1030
BuildRequires:  libexpat-devel rpm-devel
%endif
%if %{suse_version} <= 1010
Requires:       qt
%endif
%ifarch %ix86 x86_64
%if %{suse_version} > 1010
Requires:       squashfs
%endif
%endif
Requires:       perl = %{perl_version}
Requires:       perl-XML-LibXML perl-libwww-perl screen coreutils
Requires:       perl-XML-LibXML-Common perl-XML-SAX perl-Config-IniFiles
Requires:       kiwi-tools libxslt checkmedia util-linux rsync
%if %{suse_version} > 1030
Requires:       satsolver-tools
%endif
%ifarch %ix86 x86_64
Requires:       master-boot-code
%if %{suse_version} > 1110
Requires:       clicfs >= 1.3.9
%endif
%endif
Summary:        OpenSuSE - KIWI Image System
Version:        4.85.94
Release:        1
Group:          System/Management
License:        GPLv2
Source:         %{name}.tar.bz2
Source1:        %{name}-rpmlintrc
Source2:        %{name}-docu.tar.bz2
Source3:        %{name}-repo.tar.bz2
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Recommends:     perl-satsolver >= 0.42
Recommends:     jing
Recommends:     zypper
Provides:       kiwi-desc-usbboot
Obsoletes:      kiwi-desc-usbboot


%description
The OpenSuSE KIWI Image System provides a complete operating system
image solution for Linux supported hardware platforms as well as for
virtualization systems like Xen.

Authors:
--------
    Marcus Schaefer <ms@novell.com>

%package -n kiwi-instsource
License:        GPLv2
Requires:       kiwi = %{version}
Requires:       inst-source-utils createrepo build
Summary:        Installation Source creation
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
	Adrian Schroeter <adrian@novell.com>
	Jan Bornschlegel <jcborn@novell.com>

%package -n kiwi-doc
License:        LGPLv2.0+
Summary:        OpenSuSE - KIWI Image System Documentation
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
License:        GPLv2+
Summary:        OpenSuSE - KIWI tools collection
Group:          System/Management

%description -n kiwi-tools
This package contains the OpenSuSE - KIWI tools set usable in and
outside of operating system images

Authors:
--------
    Marcus Schaefer <ms@novell.com>

%ifarch %ix86 x86_64

%package -n kiwi-pxeboot
License:        GPLv2+
Requires:       syslinux
Summary:        OpenSuSE - KIWI Image System PXE boot structure
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-pxeboot
PXE basic directory structure and pre-build boot images

Authors:
--------
    Marcus Schaefer <ms@novell.com>
%endif

%ifarch %ix86 x86_64

%package -n kiwi-desc-isoboot
License:        GPLv2+
Requires:       kiwi = %{version}
Requires:       syslinux
%if %{suse_version} > 1010
Requires:       genisoimage
%else
Requires:       mkisofs
%endif
Summary:        OpenSuSE - KIWI Image System ISO boot
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-isoboot
kiwi boot (initrd) image for activating system images on ISO media

Authors:
--------
    Marcus Schaefer <ms@novell.com>
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%package -n kiwi-desc-vmxboot
License:        GPLv2+
Requires:       kiwi = %{version}
Requires:       multipath-tools parted
Requires:       virt-utils
%ifarch %ix86 x86_64
Requires:       grub
%endif
Summary:        OpenSuSE - KIWI Image System Virtual Machine boot
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-vmxboot
kiwi boot (initrd) image for activating system images on virtual disk

Authors:
--------
    Marcus Schaefer <ms@novell.com>
%endif

%ifarch %ix86 x86_64 s390 s390x

%package -n kiwi-desc-netboot
License:        GPLv2+
Requires:       kiwi = %{version}
Summary:        OpenSuSE - KIWI Image System PXE network boot
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-netboot
kiwi boot (initrd) image for activating system images via TFTP

Authors:
--------
    Marcus Schaefer <ms@novell.com>
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%package -n kiwi-desc-oemboot
License:        GPLv2
Requires:       kiwi = %{version}
Requires:       multipath-tools parted
Requires:       virt-utils
%ifarch %ix86 x86_64
Requires:       grub
%endif
%if %{suse_version} > 1010
Requires:       genisoimage
%else
Requires:       mkisofs
%endif
Summary:        OpenSuSE - KIWI image descriptions
Group:          System/Management
%if 0%{?suse_version} > 1120
BuildArch:      noarch
%endif

%description -n kiwi-desc-oemboot
This package contains the OpenSuSE - KIWI image descriptions. Each
image description exists in a single directory and contains an oemboot
image description

Authors:
--------
    Marcus Schaefer <ms@novell.com>
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%package -n kiwi-templates
License:        GPL v2.0 or later
Requires:       kiwi-desc-vmxboot = %{version}
Summary:        OpenSuSE - KIWI JeOS system image templates
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

%prep
%setup -n %name -a2 -a3

%build
# empty because of rpmlint warning rpm-buildroot-usage

%install
# build
test -e /.buildenv && . /.buildenv
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

#install
cd $RPM_BUILD_DIR/kiwi
#mkdir -p $RPM_BUILD_ROOT/etc/permissions.d
#echo "/srv/tftpboot/upload/ root:root 0755" \
#	> $RPM_BUILD_ROOT/etc/permissions.d/kiwi
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

%ifarch %ix86 x86_64

%post -n kiwi-pxeboot
#============================================================
# create /srv/tftpboot/pxelinux.cfg/default only if not exist
	if ( [ ! -e srv/tftpboot/pxelinux.cfg/default  ] ) ; then
		cp /srv/tftpboot/pxelinux.cfg/default.default /srv/tftpboot/pxelinux.cfg/default
	fi
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
%ifarch %ix86 x86_64
%exclude %{_datadir}/kiwi/image/suse-11.4-JeOS
%exclude %{_datadir}/kiwi/image/suse-11.3-JeOS
%exclude %{_datadir}/kiwi/image/suse-11.2-JeOS
%exclude %{_datadir}/kiwi/image/suse-11.1-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE10-JeOS
%exclude %{_datadir}/kiwi/image/suse-SLE11-JeOS
%exclude %{_datadir}/kiwi/image/rhel-05.4-JeOS
%endif
%ifarch s390 s390x
%exclude %{_datadir}/kiwi/image/suse-SLE11-JeOS
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
%doc %{_mandir}/man1/kiwi.1.gz
%doc %{_mandir}/man1/KIWI::images.sh.1.gz
%doc %{_mandir}/man1/KIWI::config.sh.1.gz
%doc %{_mandir}/man1/KIWI::kiwirc.1.gz
%doc %{_defaultdocdir}/kiwi/COPYING
%doc %{_defaultdocdir}/kiwi/examples
%doc %{_defaultdocdir}/kiwi/images
%doc %{_defaultdocdir}/kiwi/kiwi.pdf
%doc %{_defaultdocdir}/kiwi/kiwi.html
%doc %{_defaultdocdir}/kiwi/susebooks.css
%doc %{_defaultdocdir}/kiwi/schema
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
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%files -n kiwi-desc-vmxboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/vmxboot
%doc %{_datadir}/kiwi/image/vmxboot/README
%{_datadir}/kiwi/image/vmxboot/suse*
%endif

%ifarch %ix86 x86_64 s390 s390x

%files -n kiwi-desc-netboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/netboot
%doc %{_datadir}/kiwi/image/netboot/README
%{_datadir}/kiwi/image/netboot/suse*
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%files -n kiwi-desc-oemboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/oemboot
%doc %{_datadir}/kiwi/image/oemboot/README
%{_datadir}/kiwi/image/oemboot/suse*
%endif

%ifarch %ix86 x86_64 ppc ppc64 s390 s390x

%files -n kiwi-templates
%defattr(-, root, root)
%ifarch %ix86 x86_64
%{_datadir}/kiwi/image/suse-11.4-JeOS
%{_datadir}/kiwi/image/suse-11.3-JeOS
%{_datadir}/kiwi/image/suse-11.2-JeOS
%{_datadir}/kiwi/image/suse-11.1-JeOS
%{_datadir}/kiwi/image/suse-SLE10-JeOS
%{_datadir}/kiwi/image/suse-SLE11-JeOS
%{_datadir}/kiwi/image/rhel-05.4-JeOS
%endif
%ifarch s390 s390x
%{_datadir}/kiwi/image/suse-SLE11-JeOS
%endif
%ifarch ppc ppc64
%{_datadir}/kiwi/image/suse-SLE11-JeOS
%endif

%endif

%changelog
