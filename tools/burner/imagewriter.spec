#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# needsrootforbuild
%define qmake qmake
%define lrelease lrelease

Url:            http://kiwi.berlios.de
Name:           imagewriter
BuildRequires:  hal-devel 
BuildRequires:  gcc-c++
BuildRequires:  libqt4 libqt4-devel
Summary:        SUSE Studio Imagewriter
Version:        1.4
Release:        0
Group:          System/Tools
License:        GPL v2
Source:         imagewriter-1.4.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Graphical image writer application

%prep
%setup 

%build
qmake -makefile imagewriter.pro
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"
%install
# build
install -d $RPM_BUILD_ROOT/usr/bin
install -m 755 -p imagewriter $RPM_BUILD_ROOT/usr/bin

%clean
rm -rf $RPM_BUILD_ROOT
%files 
%defattr(-, root, root, 0755)
%{_bindir}/imagewriter
