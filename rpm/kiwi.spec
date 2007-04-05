# /.../
# spec file for package kiwi (Version 1.25)
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
# needsrootforbuild
Name:          kiwi
BuildRequires: perl smart perl-XML-LibXML perl-libwww-perl screen syslinux module-init-tools
Requires:      perl perl-XML-LibXML perl-libwww-perl screen
Summary:       OpenSuSE - KIWI Image System
Version:       1.25
Release:       25
Group:         System
License:       GPL
Source:        kiwi.tar.bz2
BuildRoot:     %{_tmppath}/%{name}-%{version}-build
ExcludeArch:   ia64 ppc64 s390x s390 ppc

%description
This package contains the OpenSuSE - KIWI Image System

Authors:
--------
    Marcus Schäfer <ms@suse.de>

%package -n kiwi-pxeboot
Requires:     syslinux
Summary:      OpenSuSE - KIWI TFTP boot structure
Group:        System

%description -n kiwi-pxeboot
This package contains the OpenSuSE - KIWI TFTP boot structure

Authors:
--------
    Marcus Schäfer <ms@suse.de>


%package -n kiwi-desc-isoboot
Requires:     kiwi smart syslinux
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-isoboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
an isoboot image description

%package -n kiwi-desc-usbboot
Requires:     kiwi smart
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-usbboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
an usbboot image description

%package -n kiwi-desc-vmxboot
Requires:     kiwi qemu multipath-tools smart
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-vmxboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a vmxboot image description

%package -n kiwi-desc-netboot
Requires:     kiwi smart
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-netboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a netboot image description

%package -n kiwi-desc-xennetboot
Requires:     kiwi smart
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-xennetboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a xennetboot image description

%package -n kiwi-desc-xenboot
Requires:     kiwi smart
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-xenboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a xenboot image description

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
	mkdir -p /usr/share/kiwi/modules
	rm -f /usr/share/kiwi/modules/KIWIScheme.xsd
	cp -f modules/KIWIScheme.xsd /usr/share/kiwi/modules
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
		xennetboot/suse-10.1
		xennetboot/suse-10.2
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
%dir %{_defaultdocdir}/kiwi
%dir %{_datadir}/kiwi
%dir %{_datadir}/kiwi/image
%doc %{_defaultdocdir}/kiwi/kiwi.pdf
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
%dir %{_var}/lib/tftpboot/pxelinux.cfg
%dir %{_var}/lib/tftpboot/image
%dir %{_var}/lib/tftpboot/upload
%{_var}/lib/tftpboot/boot
%{_var}/lib/tftpboot/pxelinux.cfg/default

#=================================================
# KIWI-images...
# ------------------------------------------------
%files -n kiwi-desc-isoboot
%defattr(-, root, root)
%{_datadir}/kiwi/image/isoboot
%{_datadir}/kiwi/image/isoinstboot

%files -n kiwi-desc-vmxboot
%defattr(-, root, root)
%{_datadir}/kiwi/image/vmxboot

%files -n kiwi-desc-usbboot
%defattr(-, root, root)
%{_datadir}/kiwi/image/usbboot

%files -n kiwi-desc-netboot
%defattr(-, root, root)
%{_datadir}/kiwi/image/netboot

%files -n kiwi-desc-xennetboot
%defattr(-, root, root)
%{_datadir}/kiwi/image/xennetboot

%files -n kiwi-desc-xenboot
%defattr(-, root, root)
%{_datadir}/kiwi/image/xenboot

