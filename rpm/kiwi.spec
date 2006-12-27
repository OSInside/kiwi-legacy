# /.../
# spec file for package kiwi (Version 1.2)
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
Name:          kiwi
BuildRequires: perl smart perl-XML-LibXML syslinux perl-libwww-perl screen
Requires:      perl smart perl-XML-LibXML syslinux perl-libwww-perl screen
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

# prepare and create boot images...
mkdir -p $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.cfg
mkdir -p $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot
for i in `find system/boot/ -name restart`;do
	cp -a tools/restart $i
done
for i in `find system/boot/ -name timed`;do
	cp -a tools/timed $i
done
cd modules
pxedefault=$RPM_BUILD_ROOT/%{_var}/lib/tftpboot/pxelinux.cfg/default
echo "# /.../" > $pxedefault
echo "# KIWI boot image setup" >> $pxedefault
echo "# select boot label according to your system image" >> $pxedefault
echo "# ..."  >> $pxedefault
echo "DEFAULT Local-Boot" >> $pxedefault
images="
	netboot-suse-10.1 netboot-suse-10.1-smp
	netboot-suse-10.2 netboot-suse-10.2-smp
	xenboot-suse-10.1
	xenboot-suse-10.2
"
for i in $images;do
	echo "#DEFAULT $i" >> $pxedefault
done
echo >> $pxedefault
echo "LABEL Local-Boot"  >> $pxedefault
echo "      localboot 0" >> $pxedefault
for i in $images;do
	../kiwi.pl --root $RPM_BUILD_ROOT/root-$i --prepare ../system/boot/$i
	../kiwi.pl --create $RPM_BUILD_ROOT/root-$i \
		-d $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot
	rm -rf $RPM_BUILD_ROOT/root-$i
	echo >> $pxedefault
	echo "LABEL $i" >> $pxedefault
	(
		cd $RPM_BUILD_ROOT/%{_var}/lib/tftpboot/boot
		xenkernel=""
		xenloader=""
		initrd=""
		kernel=""
		for n in *$i*;do
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

%install
mkdir -p $RPM_BUILD_ROOT/etc/permissions.d
echo "/var/lib/tftpboot/upload root:root 0777" \
	> $RPM_BUILD_ROOT/etc/permissions.d/kiwi
make buildroot=$RPM_BUILD_ROOT \
     doc_prefix=$RPM_BUILD_ROOT/%{_defaultdocdir} \
     man_prefix=$RPM_BUILD_ROOT/%{_mandir} \
     install
touch kiwi.loader
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

%files -n kiwi-images-buildservice
%{_datadir}/kiwi/image/buildhost-suse-10.1
%defattr(-, root, root)
