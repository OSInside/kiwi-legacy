# /.../
# spec file for package kiwi (Version 2.34
# Copyright (c) 2006 SUSE LINUX Products GmbH, Nuernberg, Germany.
# Please submit bugfixes or comments via http://bugs.opensuse.org
# ---
# needsrootforbuild
Name:          kiwi
BuildRequires: smart perl-XML-LibXML perl-libwww-perl
BuildRequires: screen module-init-tools zlib-devel hal-devel
BuildRequires: gcc-c++ libxslt swig
%if %{suse_version} > 1020
BuildRequires: fdupes
%endif
%ifarch %ix86 x86_64
BuildRequires: syslinux
%endif
%if %{suse_version} > 1010
BuildRequires: libqt4 libqt4-devel
%else
BuildRequires: qt qt-devel libpng-devel freetype2-devel
%endif 
%if %{suse_version} > 1030
BuildRequires: libsatsolver libsatsolver-devel db-devel libexpat-devel
%endif
Requires:      perl = %{perl_version}
Requires:      perl-XML-LibXML perl-libwww-perl screen coreutils
Requires:      kiwi-tools
Summary:       OpenSuSE - KIWI Image System
Provides:      kiwi2 = 2.14
Obsoletes:     kiwi2 = 2.14
Version:       2.34
Release:       28
Group:         System
License:       GPL
Source:        %{name}.tar.bz2
Source1:       %{name}-rpmlintrc
BuildRoot:     %{_tmppath}/%{name}-%{version}-build
ExcludeArch:   ia64 ppc64 s390x s390 ppc
Recommends:    smart zypper

%description
This package contains the OpenSuSE - KIWI Image System

Authors:
--------
    Marcus Schäfer <ms@suse.de>

%package -n kiwi-pxeboot
Requires:     syslinux
Summary:      OpenSuSE - KIWI TFTP boot structure
Obsoletes:    kiwi2-pxeboot = 2.14
Provides:     kiwi2-pxeboot = 2.14
Group:        System

%description -n kiwi-pxeboot
This package contains the OpenSuSE - KIWI TFTP boot structure

%package -n kiwi-tools
Summary:      OpenSuSE - KIWI tools collection
Obsoletes:    kiwi2-tools = 2.14
Provides:     kiwi2-tools = 2.14
Group:        System

%description -n kiwi-tools
This package contains the OpenSuSE - KIWI tools set usable in
and outside of operating system images

%package -n kiwi-pxeboot-prebuild
Requires:     syslinux
Summary:      OpenSuSE - KIWI TFTP prebuild boot images
Obsoletes:    kiwi2-pxeboot-prebuild = 2.14
Provides:     kiwi2-pxeboot-prebuild = 2.14
Group:        System

%description -n kiwi-pxeboot-prebuild
This package contains the OpenSuSE - KIWI TFTP prebuild boot images

%package -n kiwi-desc-isoboot
Requires:     kiwi syslinux mkisofs
Summary:      OpenSuSE - KIWI image descriptions
Obsoletes:    kiwi2-desc-isoboot = 2.14
Provides:     kiwi2-desc-isoboot = 2.14
Group:        System

%description -n kiwi-desc-isoboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
an isoboot image description

%package -n kiwi-desc-usbboot
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Obsoletes:    kiwi2-desc-usbboot = 2.14
Provides:     kiwi2-desc-usbboot = 2.14
Group:        System

%description -n kiwi-desc-usbboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
an usbboot image description

%package -n kiwi-desc-vmxboot
Requires:     kiwi qemu multipath-tools
Summary:      OpenSuSE - KIWI image descriptions
Obsoletes:    kiwi2-desc-vmxboot = 2.14
Provides:     kiwi2-desc-vmxboot = 2.14
Group:        System

%description -n kiwi-desc-vmxboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a vmxboot image description

%package -n kiwi-desc-netboot
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Obsoletes:    kiwi2-desc-netboot = 2.14
Provides:     kiwi2-desc-netboot = 2.14
Group:        System

%description -n kiwi-desc-netboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a netboot image description

%package -n kiwi-desc-xenboot
Requires:     kiwi
Summary:      OpenSuSE - KIWI image descriptions
Obsoletes:    kiwi2-desc-xenboot = 2.14
Provides:     kiwi2-desc-xenboot = 2.14
Group:        System

%description -n kiwi-desc-xenboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
a xenboot image description

%package -n kiwi-desc-oemboot
Requires:     kiwi qemu multipath-tools
Summary:      OpenSuSE - KIWI image descriptions
Obsoletes:    kiwi2-desc-oemboot = 2.14
Provides:     kiwi2-desc-oemboot = 2.14
Group:        System

%description -n kiwi-desc-oemboot
This package contains the OpenSuSE - KIWI image descriptions.
Each image description exists in a single directory and contains
an oemboot image description

%package -n kiwi-doc
Summary:      OpenSuSE - KIWI image documentation
Group:        System

%description -n kiwi-doc
This package contains the kiwi documentation

%prep
%setup -n kiwi

%build
# empty because of rpmlint warning rpm-buildroot-usage

%install
# build
export K_USER=0 # set value to -1 to prevent building boot images
test -e /.buildenv || export K_USER=-1 # no buildenv, no boot image build
test -e /.buildenv && . /.buildenv
make buildroot=$RPM_BUILD_ROOT CFLAGS="$RPM_OPT_FLAGS"

if [ "$UID" = "$K_USER" ];then
	# prepare and create boot images...
	(cd tools/dbuslock && make install)
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
		netboot/suse-SLES10
		netboot/suse-SLED10
		netboot/suse-SLED10-SP1 
		netboot/suse-SLES10-SP1
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
			pushd $RPM_BUILD_ROOT/srv/tftpboot/boot
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
			popd
			../kiwi.pl --setup-grub-splash \
				$RPM_BUILD_ROOT/srv/tftpboot/boot/$initrd   && \
			rm -f $RPM_BUILD_ROOT/srv/tftpboot/boot/$initrd && \
			initrd=`echo $initrd | sed -e "s@.gz@.splash.gz@"`
			pushd $RPM_BUILD_ROOT/srv/tftpboot/boot
			cd $RPM_BUILD_ROOT/srv/tftpboot/boot
			if [ -n "$xenkernel" ];then
				echo "      kernel mboot.c32" >> $pxedefault
				echo "      append boot/$xenloader --- boot/$xenkernel vga=0x314 ramdisk_size=512000 ramdisk_blocksize=4096 splash=silent showopts --- boot/$initrd" >> $pxedefault
				echo "      IPAPPEND 2" >> $pxedefault
			else
				echo "      kernel boot/$kernel" >> $pxedefault
				echo "      append initrd=boot/$initrd vga=0x314 ramdisk_size=512000 ramdisk_blocksize=4096 splash=silent showopts" >> $pxedefault
				echo "      IPAPPEND 2" >> $pxedefault
			fi
			popd
		)
	done
	rm -f $RPM_BUILD_ROOT/srv/tftpboot/boot/*.md5
	rm -f $RPM_BUILD_ROOT/srv/tftpboot/boot/*.kernel
	chmod 644 $pxedefault
else
	echo "cannot build prebuild images without root privileges"
	true
fi

#install
cd $RPM_BUILD_DIR/kiwi
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

install -m 644 tools/README \
	$RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/README.tools
rm -rf $RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/kiwi-man
%perl_process_packlist
rm -f $RPM_BUILD_ROOT/%{perl_vendorarch}/example.pl
rm -f $RPM_BUILD_ROOT/%{perl_vendorarch}/auto/SaT/SaT.bs
rm -f $RPM_BUILD_ROOT/%{perl_vendorarch}/auto/dbusdevice/dbusdevice.bs
rm -f $RPM_BUILD_ROOT/var/adm/perl-modules/kiwi
./.links
%if %{suse_version} > 1020
%fdupes $RPM_BUILD_ROOT/usr/share/kiwi/image
%fdupes $RPM_BUILD_ROOT/usr/share/doc/packages/kiwi/examples
%endif
cat kiwi.loader

%clean
rm -rf $RPM_BUILD_ROOT

#=================================================
# KIWI files...      
#-------------------------------------------------
%files
%defattr(-, root, root)
%dir %{_datadir}/kiwi
%dir %{_datadir}/kiwi/image
%{_datadir}/kiwi/.revision
%{_datadir}/kiwi/modules
%{_datadir}/kiwi/xsl
%{_sbindir}/kiwi
%{perl_vendorarch}/dbusdevice.pm
%{perl_vendorarch}/auto/dbusdevice
%if %{suse_version} > 1030
%{perl_vendorarch}/SaT.pm
%{perl_vendorarch}/auto/SaT
%endif

#=================================================
# KIWI doc...      
#-------------------------------------------------
%files -n kiwi-doc
%defattr(-, root, root)
%dir %{_defaultdocdir}/kiwi
%doc %{_mandir}/man1/kiwi.1.gz
%doc %{_mandir}/man1/KIWI::images.sh.1.gz
%doc %{_mandir}/man1/KIWI::config.sh.1.gz
%doc %{_defaultdocdir}/kiwi/COPYING
%doc %{_defaultdocdir}/kiwi/examples
%doc %{_defaultdocdir}/kiwi/kiwi.pdf
%doc %{_defaultdocdir}/kiwi/ChangeLog
%doc %{_defaultdocdir}/kiwi/kiwi.xsd.diag
%doc %{_defaultdocdir}/kiwi/kiwi.xsd.html
%doc %{_defaultdocdir}/kiwi/kiwi.rng.html
%doc %{_defaultdocdir}/kiwi/kiwi.quick.pdf

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
/srv/tftpboot/pxelinux.cfg/default

#=================================================
# KIWI-pxeboot-prebuild files...  
# ------------------------------------------------
%files -n kiwi-pxeboot-prebuild
%defattr(-, root, root)
%doc /srv/tftpboot/README.prebuild
/srv/tftpboot/boot

#=================================================
# KIWI-tools files...  
# ------------------------------------------------
%files -n kiwi-tools
%defattr(-, root, root)
%doc %{_defaultdocdir}/kiwi/README.tools
/usr/bin/*

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
