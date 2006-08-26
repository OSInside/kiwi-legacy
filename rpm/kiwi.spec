# /.../
# spec file for package kiwi (Version 1.2)
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
Name:          kiwi
BuildRequires: syslinux
Requires:      perl smart perl-XML-LibXML syslinux
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
%files -n kiwi-pxeboot
%defattr(-, root, root)
/etc/permissions.d/kiwi
%dir %{_var}/lib/tftpboot
%dir %{_var}/lib/tftpboot/KIWI
%dir %{_var}/lib/tftpboot/boot
%dir %{_var}/lib/tftpboot/pxelinux.cfg
%dir %{_var}/lib/tftpboot/image
%dir %{_var}/lib/tftpboot/upload
%{_var}/lib/tftpboot/pxelinux.cfg/default
%{_var}/lib/tftpboot/pxelinux.0

#=================================================
# KIWI-images...
# ------------------------------------------------
%files -n kiwi-images
%defattr(-, root, root)
%{_datadir}/kiwi/image
