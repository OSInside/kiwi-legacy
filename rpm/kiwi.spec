# /.../
# spec file for package kiwi (Version 1.62
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
# needsrootforbuild
Name:          kiwi
BuildRequires: perl smart perl-XML-LibXML perl-libwww-perl screen syslinux module-init-tools
Requires:      perl perl-XML-LibXML perl-libwww-perl screen
Summary:       OpenSuSE - KIWI Image System
Version:       1.62
Release:       28
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

%package -n kiwi-pxeboot-prebuild
Requires:     syslinux
Summary:      OpenSuSE - KIWI TFTP prebuild boot images
Group:        System

%description -n kiwi-pxeboot-prebuild
This package contains the OpenSuSE - KIWI TFTP prebuild boot images

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
Requires:     kiwi smart kiwi-desc-netboot
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

%package -n kiwi-desc-oemboot
Requires:     kiwi smart
Summary:      OpenSuSE - KIWI image descriptions
Group:        System

%description -n kiwi-desc-oemboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
an oemboot image description

Authors:
--------
    Marcus Schäfer <ms@suse.de>

%prep
%setup -n kiwi
# %patch

%build
export K_USER=0 # set value to -1 to prevent building boot images
rm -rf $RPM_BUILD_ROOT
test -e /.buildenv || export K_USER=-1 # no buildenv, no boot image build
test -e /.buildenv && . /.buildenv
#cat /proc/mounts > /etc/fstab
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

if [ "$UID" = "$K_USER" ];then
	# prepare and create boot images...
	mkdir -p $RPM_BUILD_ROOT/srv/tftpboot/pxelinux.cfg
	mkdir -p $RPM_BUILD_ROOT/srv/tftpboot/boot
	mkdir -p /usr/share/kiwi/modules
	mkdir -p /usr/share/kiwi/image/netboot
	rm -f /usr/share/kiwi/modules/*
	cp -f modules/* /usr/share/kiwi/modules
	cp -a system/boot/netboot/suse-repo /usr/share/kiwi/image/netboot
	cd modules
	pxedefault=$RPM_BUILD_ROOT/srv/tftpboot/pxelinux.cfg/default
	echo "# /.../" > $pxedefault
	echo "# KIWI boot image setup" >> $pxedefault
	echo "# select boot label according to your system image" >> $pxedefault
	echo "# ..."  >> $pxedefault
	echo "DEFAULT Local-Boot" >> $pxedefault
	images="
		netboot/suse-SLES10 netboot/suse-SLED10
		netboot/suse-SLES10-smp netboot/suse-SLED10-smp
		netboot/suse-SLED10-SP1 netboot/suse-SLED10-SP1-smp
		netboot/suse-SLES10-SP1 netboot/suse-SLES10-SP1-smp
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
			-d $RPM_BUILD_ROOT/srv/tftpboot/boot
		rm -rf $RPM_BUILD_ROOT/root-$rootName*
		echo >> $pxedefault
		echo "LABEL $rootName" >> $pxedefault
		(
			cd $RPM_BUILD_ROOT/srv/tftpboot/boot
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
	rm -f $RPM_BUILD_ROOT/srv/tftpboot/boot/*.md5
	rm -f $RPM_BUILD_ROOT/srv/tftpboot/boot/*.kernel
	chmod 644 $pxedefault
else
	echo "cannot build prebuild images without root privileges"
	true
fi

%install
mkdir -p $RPM_BUILD_ROOT/etc/permissions.d
echo "/srv/tftpboot/upload root:root 0755" \
	> $RPM_BUILD_ROOT/etc/permissions.d/kiwi
make buildroot=$RPM_BUILD_ROOT \
     doc_prefix=$RPM_BUILD_ROOT/%{_defaultdocdir} \
     man_prefix=$RPM_BUILD_ROOT/%{_mandir} \
     install
touch kiwi.loader
if [ ! "$UID" = "$K_USER" ];then
	install -m 644 pxeboot/pxelinux.0.config \
		$RPM_BUILD_ROOT/srv/tftpboot/pxelinux.cfg/default
fi
test -f $RPM_BUILD_ROOT/srv/tftpboot/pxelinux.0 && \
	echo /srv/tftpboot/pxelinux.0 > kiwi.loader
test -f $RPM_BUILD_ROOT/srv/tftpboot/mboot.c32 && \
	echo /srv/tftpboot/mboot.c32 >> kiwi.loader

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
# KIWI-pxeboot files...  
# ------------------------------------------------
%files -n kiwi-pxeboot -f kiwi.loader
%defattr(-, root, root)
%doc /srv/tftpboot/README
/etc/permissions.d/kiwi
%dir /srv/tftpboot
%dir /srv/tftpboot/KIWI
%dir /srv/tftpboot/pxelinux.cfg
%dir /srv/tftpboot/image
%dir /srv/tftpboot/upload
%dir /srv/tftpboot/boot
%config /srv/tftpboot/pxelinux.cfg/default

#=================================================
# KIWI-pxeboot-prebuild files...  
# ------------------------------------------------
%files -n kiwi-pxeboot-prebuild
%defattr(-, root, root)
%doc /srv/tftpboot/README.prebuild
/srv/tftpboot/boot

#=================================================
# KIWI-desc-*...
# ------------------------------------------------
%files -n kiwi-desc-isoboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/isoboot
%doc %{_datadir}/kiwi/image/isoboot/README
%{_datadir}/kiwi/image/isoboot/suse*

%files -n kiwi-desc-vmxboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/vmxboot
%doc %{_datadir}/kiwi/image/vmxboot/README
%{_datadir}/kiwi/image/vmxboot/suse*

%files -n kiwi-desc-usbboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/usbboot
%doc %{_datadir}/kiwi/image/usbboot/README
%{_datadir}/kiwi/image/usbboot/suse*

%files -n kiwi-desc-netboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/netboot
%doc %{_datadir}/kiwi/image/netboot/README
%{_datadir}/kiwi/image/netboot/suse*

%files -n kiwi-desc-xennetboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/xennetboot
%doc %{_datadir}/kiwi/image/xennetboot/README
%{_datadir}/kiwi/image/xennetboot/suse*

%files -n kiwi-desc-xenboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/xenboot
%doc %{_datadir}/kiwi/image/xenboot/README
%{_datadir}/kiwi/image/xenboot/suse*

%files -n kiwi-desc-oemboot
%defattr(-, root, root)
%dir %{_datadir}/kiwi/image/oemboot
%doc %{_datadir}/kiwi/image/oemboot/README
%{_datadir}/kiwi/image/oemboot/suse*
