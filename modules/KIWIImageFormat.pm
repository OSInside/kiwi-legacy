#================
# FILE          : KIWIImageFormat.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to provide methods for
#               : creating image output formats based on the
#               : raw output file like vmdk, ovf, hyperV
#               : and more
#               : 
#               :
# STATUS        : Development
#----------------
package KIWIImageFormat;
#==========================================
# Modules
#------------------------------------------
use strict;
use KIWILog;
use KIWIQX;
use File::Basename;
use KIWIBoot;
use KIWILocator;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIImageFormat object which is used
	# to gather information required for the format conversion 
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters [ mandatory ]
	#------------------------------------------
	my $kiwi   = shift;
	my $image  = shift;
	#==========================================
	# Module Parameters [ optional ]
	#------------------------------------------
	my $format = shift;
	my $xml    = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	my $data;
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# check image file
	#------------------------------------------
	if ((! $main::targetStudio) && (! (-f $image || -b $image))) {
		$kiwi -> error ("no such image file: $image");
		$kiwi -> failed ();
		return undef;
	} 
	#==========================================
	# read XML if required
	#------------------------------------------
	if (! defined $xml) {
		my $boot = new KIWIBoot (
			$kiwi,undef,$image,undef,undef,\@main::ProfilesOrig
		);
		if ($boot) {
			$xml = $boot->{xml};
			$boot -> cleanLoop();
		}
		if (! defined $xml) {
			$kiwi -> error  ("Can't load XML configuration, not an image ?");
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# check format
	#------------------------------------------
	my $type = $xml -> getImageTypeAndAttributes();
	if (! defined $format) {
		if (($type) && ($type->{format})) {
			$format = $type->{format};
		}
	}
	#==========================================
	# Read some XML data
	#------------------------------------------
	my %xenref = $xml -> getXenConfig();
	my %vmwref = $xml -> getVMwareConfig();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{xenref}  = \%xenref;
	$this->{vmwref}  = \%vmwref;
	$this->{kiwi}    = $kiwi;
	$this->{xml}     = $xml;
	$this->{format}  = $format;
	$this->{image}   = $image;
	$this->{type}    = $type;
	$this->{imgtype} = $type->{type};
	return $this;
}

#==========================================
# createFormat
#------------------------------------------
sub createFormat {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $image  = $this->{image};
	my $imgtype= $this->{imgtype};
	#==========================================
	# check if format is a disk
	#------------------------------------------
	if (! defined $format) {
		$kiwi -> warning ("No format for $imgtype conversion specified");
		$kiwi -> skipped ();
		return undef;
	} else {
		my $data = qxx ("parted $image print 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("system image is not a disk or filesystem");
			$kiwi -> failed ();
			return undef
		}
	}
	#==========================================
	# convert disk into specified format
	#------------------------------------------
	if (($main::targetStudio) && ($format ne "ec2")) {
		$kiwi -> warning ("Format conversion skipped in targetstudio mode");
		$kiwi -> skipped ();
		return undef;
	}
	if ($format eq "vmdk") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVMDK();
	} elsif ($format eq "vhd") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVHD();
	} elsif ($format eq "vhd-fixed") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createVHDSubFormatFixed()
	} elsif ($format eq "ovf") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createOVF();
	} elsif ($format eq "qcow2") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createQCOW2();
	} elsif ($format eq "ec2") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createEC2();
	} else {
		$kiwi -> warning (
			"Can't convert image type $imgtype to $format format"
		);
		$kiwi -> skipped ();
	}
	return undef;
}

#==========================================
# createMaschineConfiguration
#------------------------------------------
sub createMaschineConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $imgtype= $this->{imgtype};
	my $xml    = $this->{xml};
	my %type   = %{$this->{type}};
	my $xenref = $this->{xenref};
	my %xenc   = %{$xenref};
	my $xend   = "dom0";
	if (defined $xenc{xen_domain}) {
		$xend = $xenc{xen_domain};
	}
	if ($imgtype eq "iso") {
		$kiwi -> warning (
			"Can't create machine setup for selected $imgtype image type"
		);
		$kiwi -> skipped ();
		return undef;
	}
	if (($type{bootprofile}) && ($type{bootprofile} eq "xen")
		&& ($xend eq "domU")) {
		$kiwi -> info ("Starting $imgtype image machine configuration\n");
		return $this -> createXENConfiguration();
	} elsif ($format eq "vmdk") {
		$kiwi -> info ("Starting $imgtype image machine configuration\n");
		return $this -> createVMwareConfiguration();
	} elsif ($format eq "ovf") {
		$kiwi -> info ("Starting $imgtype image machine configuration\n");
		return $this -> createOVFConfiguration();
	} else {
		$kiwi -> warning (
			"Can't create machine setup for selected $imgtype image type"
		);
		$kiwi -> skipped ();
	}
	return undef;
}

#==========================================
# createOVF
#------------------------------------------
sub createOVF {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $ovftool = "/usr/bin/ovftool";
	my $vmdk;
	my $vmxf;
	my $source;
	my $target;
	#==========================================
	# check for ovftool
	#------------------------------------------
	if (! -x $ovftool) {
		$kiwi -> error  ("Can't find $ovftool, is it installed ?");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# create vmdk first, required for ovf
	#------------------------------------------
	$this->{format}	= "vmdk";
	$vmdk = $this->createVMDK();
	$vmxf = $this->createMaschineConfiguration();
	#==========================================
	# create ovf from the vmdk
	#------------------------------------------
	if ((-e $vmdk) && (-e $vmxf)) {
		$source = $vmxf;
		$target = $vmxf;
		$target =~ s/\.vmx$/\.$format/;
		$this->{format} = $format;
		$kiwi -> info ("Creating $format image...");
		# /.../
		# temporary hack, because ovftool is not able to handle
		# scsi-hardDisk correctly at the moment
		# ---- beg ----
		qxx ("sed -i -e 's;scsi-hardDisk;disk;' $source");
		# ---- end ----
		my $status = qxx ("rm -rf $target; mkdir -p $target 2>&1");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create OVF directory: $status");
			$kiwi -> failed ();
			return undef;
		}
		my $output = basename $target;
		$status= qxx (
			"$ovftool -o -q $source $target/$output 2>&1"
		);
		$result = $? >> 8;
		# --- beg ----
		qxx ("sed -i -e 's;disk;scsi-hardDisk;' $source");
		qxx ("rm -rf $main::Destination/*.lck 2>&1");
		# --- end ----
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create OVF image: $status");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
	} else {
		$kiwi -> error  ("Required vmdk files not present");
		$kiwi -> failed ();
		return undef;
	}
	return $target;
}

#==========================================
# createVMDK
#------------------------------------------
sub createVMDK {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my %vmwc   = %{$this->{vmwref}};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating $format image...");
	$target  =~ s/\.raw$/\.$format/;
	$convert = "convert -f raw $source -O $format";
	$status = qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create $format image: $status");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createVHD
#------------------------------------------
sub createVHD {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my %vmwc   = %{$this->{vmwref}};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating vhd image...");
	$target  =~ s/\.raw$/\.vhd/;
	$convert = "convert -f raw $source -O vpc";
	$status = qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create vhd image: $status");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createVHDSubFormatFixed
#------------------------------------------
sub createVHDSubFormatFixed {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating vhd-fixed image...");
	$target  =~ s/\.raw$/\.vhdfixed/;
	$convert = "convert -f raw -O vpc -o subformat=fixed";
	$status = qxx ("qemu-img $convert $source $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create vhd-fixed image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createQCOW2
#------------------------------------------
sub createQCOW2 {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating qcow2 image...");
	$target  =~ s/\.raw$/\.qcow2/;
	$convert = "convert -c -f raw $source -O qcow2";
	$status = qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create qcow2 image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done ();
	return $target;
}

#==========================================
# createEC2
#------------------------------------------
sub createEC2 {
	my $this   = shift;
	my $xml    = $this->{xml};
	my $kiwi   = $this->{kiwi};
	my $source = $this->{image};
	my $format = $this->{format};
	my $target = $source;
	my $mods   = "ext3 jbd xenblk";
	my $kmod   = "INITRD_MODULES";
	my $sysk   = "/etc/sysconfig/kernel";
	my $aminame= basename $source;
	my $destdir= dirname  $source;
	my $status;
	my $result;
	my $tmpdir;
	my $FD;
	#==========================================
	# Import AWS region kernel map
	#------------------------------------------
	my %ec2RegionKernelMap;
	if (! open ($FD,$main::KRegion)) {
		return undef;
	}
	while (my $line = <$FD>) {
		next if $line =~ /^#/;
		if ($line =~ /(.*)\s*=\s*(.*)/) {
			my $region= $1;
			my $aki   = $2;
			$ec2RegionKernelMap{$region} = $aki;
		}
	}
	close $FD;
	#==========================================
	# Check AWS account information
	#------------------------------------------
	$kiwi -> info ("Creating $format image...\n");
	$target  =~ s/\/$//;
	$target .= ".$format";
	$aminame.= ".ami";
	my $title= $xml -> getImageDisplayName();
	my $arch = qxx ("uname -m"); chomp ( $arch );
	my %type = %{$xml->getImageTypeAndAttributes()};
	my %ec2  = $xml->getEc2Config();
	my $have_account = 1;
	if (! defined $ec2{AWSAccountNr}) {
		$kiwi->warning ("Missing AWS account number");
		$kiwi->skipped ();
		$have_account = 0;
	}
	if (! defined $ec2{EC2CertFile}) {
		$kiwi->warning ("Missing AWS user's PEM encoded RSA pubkey cert file");
		$kiwi->skipped ();
		$have_account = 0;
	} elsif (! -f $ec2{EC2CertFile}) {
		$kiwi->warning ("EC2 file: $ec2{EC2CertFile} does not exist");
		$kiwi->skipped ();
		$have_account = 0;
	}
	if (! defined $ec2{EC2PrivateKeyFile}) {
		$kiwi->warning ("Missing AWS user's PEM encoded RSA private key file");
		$kiwi->skipped ();
		$have_account = 0;
	} elsif (! -f $ec2{EC2PrivateKeyFile}) {
		$kiwi->warning ("EC2 file: $ec2{EC2PrivateKeyFile} does not exist");
		$kiwi->skipped ();
		$have_account = 0;
	}
	if ($arch =~ /i.86/) {
		$arch = "i386";
	}
	if (($arch ne "i386") && ($arch ne "x86_64")) {
		$kiwi->error  ("Unsupport AWS EC2 architecture: $arch");
		$kiwi->failed ();
		return undef;
	}
	#==========================================
	# loop mount root image and create config
	#------------------------------------------
	$tmpdir = qxx ("mktemp -q -d $destdir/ec2.XXXXXX"); chomp $tmpdir;
	$this->{tmpdir} = $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$status = qxx ("mount -o loop $source $tmpdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't loop mount $source: $status");
		$kiwi -> failed ();
		return undef;
	}
	sub clean_loop {
		my $dir = shift;
		qxx ("umount $dir 2>&1");
		qxx ("rmdir  $dir 2>&1");
	}
	#==========================================
	# setup Xen console as serial tty
	#------------------------------------------
	$this -> __copy_origin ("$tmpdir/etc/inittab");
	if (! open $FD, ">>$tmpdir/etc/inittab") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/inittab: $!");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	print $FD "\n";
	print $FD 'X0:12345:respawn:/sbin/agetty -L 9600 xvc0 xterm'."\n";
	close $FD;
	if (! open $FD, ">>$tmpdir/etc/securetty") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/securetty: $!");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	print $FD "\n";
	print $FD 'xvc0'."\n";
	close $FD;
	#==========================================
	# create initrd
	#------------------------------------------
	if (! open $FD, ">$tmpdir/create_initrd.sh") {
		$kiwi -> error  ("Failed to open $tmpdir/create_initrd.sh: $!");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	print $FD 'export rootdev=/dev/sda1'."\n";
	print $FD 'export rootfstype='.$type{type}."\n";
	print $FD 'mknod /dev/sda1 b 8 1'."\n";
	print $FD 'touch /boot/.rebuild-initrd'."\n";
	print $FD 'sed -i -e \'s@^';
	print $FD $kmod;
	print $FD '="\(.*\)"@'.$kmod.'="\1 ';
	print $FD $mods;
	print $FD '"@\' ';
	print $FD $sysk;
	print $FD "\n";
	print $FD 'mkinitrd -B'."\n";
	close $FD;
	qxx ("chmod u+x $tmpdir/create_initrd.sh");
	$status = qxx ("chroot $tmpdir bash -c ./create_initrd.sh 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to create initrd: $status");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	qxx ("rm -f $tmpdir/create_initrd.sh");
	#==========================================
	# create grub bootloader setup
	#------------------------------------------
	# copy grub image files
	qxx ("cp $tmpdir/usr/lib/grub/* $tmpdir/boot/grub");
	# boot/grub/device.map
	if (! open $FD, ">$tmpdir/boot/grub/device.map") {
		$kiwi -> error  ("Failed to open $tmpdir/boot/grub/device.map: $!");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	print $FD '(hd0)'."\t".'/dev/sda1'."\n"; 
	close $FD;
	# etc/grub.conf
	if (! open $FD, ">$tmpdir/etc/grub.conf") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/grub.conf: $!");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	print $FD 'setup --stage2=/boot/grub/stage2 --force-lba (hd0) (hd0)'."\n";
	print $FD 'quit'."\n";
	close $FD;
	# boot/grub/menu.lst
	my $args="xencons=xvc0 console=xvc0 splash=silent showopts";
	if (! open $FD, ">$tmpdir/create_bootmenu.sh") {
		$kiwi -> error  ("Failed to open $tmpdir/create_bootmenu.sh: $!");
		$kiwi -> failed ();
		return undef;
	}
	print $FD 'file=/boot/grub/menu.lst'."\n";
	print $FD 'args="'.$args.'"'."\n";
	print $FD 'echo "serial --unit=0 --speed=9600" > $file'."\n";
	print $FD 'echo "terminal --dumb serial" >> $file'."\n";
	print $FD 'echo "default 0" >> $file'."\n";
	print $FD 'echo "timeout 0" >> $file'."\n";
	print $FD 'echo "hiddenmenu" >> $file'."\n";
	print $FD 'ls /lib/modules | while read D; do'."\n";
	print $FD '   [ -d "/lib/modules/$D" ] || continue'."\n";
	print $FD '   echo "$D"'."\n";
	print $FD 'done | /usr/lib/rpm/rpmsort | tac | while read D; do'."\n";
	print $FD '   for K in /boot/vmlinu[zx]-$D; do'."\n";
	print $FD '      [ -f "$K" ] || continue'."\n";
	print $FD '      echo >> $file'."\n";
	print $FD '      echo "title '.$title.'" >> $file'."\n";
	print $FD '      echo "    root (hd0)" >> $file'."\n";
	print $FD '      echo "    kernel $K root=/dev/sda1 $args" >> $file'."\n";
	print $FD '      if [ -f "/boot/initrd-$D" ]; then'."\n";
	print $FD '         echo "    initrd /boot/initrd-$D" >> $file'."\n";
	print $FD '      fi'."\n";
	print $FD '   done'."\n";
	print $FD 'done'."\n";
	close $FD;
	qxx ("chmod u+x $tmpdir/create_bootmenu.sh");
	$status = qxx ("chroot $tmpdir bash -c ./create_bootmenu.sh 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to create boot menu: $status");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	qxx ("rm -f $tmpdir/create_bootmenu.sh");
	# etc/sysconfig/bootloader
	if (open $FD, "$tmpdir/etc/sysconfig/bootloader") {
		my @lines = <$FD>; close $FD;
		$this -> __ensure_key (\@lines, "LOADER_TYPE"      , "grub");
		$this -> __ensure_key (\@lines, "DEFAULT_NAME"     , $title);
		$this -> __ensure_key (\@lines, "DEFAULT_APPEND"   , $args );
		$this -> __ensure_key (\@lines, "DEFAULT_VGA"      , ""    );
		$this -> __ensure_key (\@lines, "FAILSAFE_APPEND"  , $args );
		$this -> __ensure_key (\@lines, "FAILSAFE_VGA"     , ""    );
		$this -> __ensure_key (\@lines, "XEN_KERNEL_APPEND", $args );
		$this -> __ensure_key (\@lines, "XEN_APPEND"       , ""    );
		$this -> __ensure_key (\@lines, "XEN_VGA"          , ""    );
		open  $FD, ">$tmpdir/etc/sysconfig/bootloader";
		print $FD @lines;
		close $FD;
	}
	#==========================================
	# setup fstab
	#------------------------------------------
	$this -> __copy_origin ("$tmpdir/etc/fstab");
	if (! open $FD, '+<', "$tmpdir/etc/fstab") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/fstab: $!");
		$kiwi -> failed ();
		clean_loop $tmpdir;
		return undef;
	}
	my $rootfs=0;
	foreach my $line (<$FD>) {
		my @entries = split (/\s+/,$line);
		if ($entries[1] eq "/") {
			$rootfs=1; last;
		}
	}
	if (! $rootfs) {
		print $FD "/dev/sda1 / $type{type} defaults 0 0"."\n";
	}
	close $FD;
	#==========================================
	# cleanup loop
	#------------------------------------------
	clean_loop $tmpdir;
	#==========================================
	# call ec2-bundle-image (Amazon toolkit)
	#------------------------------------------
	if ($have_account == 0) {
		$kiwi->warning (
			"EC2 bundle creation skipped due to missing credentials"
		);
		$kiwi->skipped ();
		return $source;
	}
	#==========================================
	# Check for Amazon EC2 toolkit
	#------------------------------------------
	my $locator = new KIWILocator($kiwi);
	my $bundleCmd = $locator -> getExecPath ('ec2-bundle-image');
	if (! $bundleCmd ) {
		$kiwi -> error (
			"Couldn't find ec2-bundle-image; required to create EC2 image"
		);
		$kiwi -> failed ();
		return undef
	}
	#==========================================
	# Create bundle(s)
	#------------------------------------------
	my $pk = $ec2{EC2PrivateKeyFile};
	my $ca = $ec2{EC2CertFile};
	my $nr = $ec2{AWSAccountNr};
	my $fi = $source;
	my $amiopts = "-i $fi -k $pk -c $ca -u $nr -p $aminame "
	. '--block-device-mapping ami=sda1,root=/dev/sda1';
	my @regions = @{ $ec2{EC2Regions} };
	if (! @regions) {
		push @regions, 'any';
	}
	for my $region (@regions) {
		my $regionTgt = "$target-$region";
		if ( $region ne 'any' ) {
			my $kernel = $ec2RegionKernelMap{"$region-$arch"};
			$amiopts .= " --kernel $kernel";
		}
		qxx ("mkdir -p $regionTgt 2>&1");
		qxx ("rm -rf $regionTgt/* 2>&1");
		$status = qxx ( "$bundleCmd $amiopts -d $regionTgt -r $arch 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("$bundleCmd: $status");
			$kiwi -> failed ();
			return undef;
		}
	}
	$kiwi -> done();
	return $target;
}

#==========================================
# createXENConfiguration
#------------------------------------------
sub createXENConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $xenref = $this->{xenref};
	my %type   = %{$this->{type}};
	my $dest   = dirname  $this->{image};
	my $base   = basename $this->{image};
	my %xenconfig = %{$xenref};
	my $format;
	my $file;
	my $FD;
	$kiwi -> info ("Creating image Xen configuration file...");
	#==========================================
	# setup config file name from image name
	#------------------------------------------
	my $image = $base;
	if ($base =~ /(.*)\.(.*?)$/) {
		$image  = $1;
		$format = $2;
		$base   = $image.".xenconfig";
	}
	$file = $dest."/".$base;
	unlink $file;
	#==========================================
	# find kernel
	#------------------------------------------
	my $kernel;
	my $initrd;
	foreach my $k (glob ($dest."/*.kernel")) {
		if (-l $k) {
			$kernel = readlink ($k);
			$kernel = basename ($kernel);
			last;
		}
	}
	if (! -e "$dest/$kernel") {
		$kiwi -> skipped ();
		$kiwi -> warning ("Can't find kernel in $dest");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# find initrd
	#------------------------------------------
	foreach my $i (glob ($dest."/*.splash.gz")) {
		$initrd = $i;
		$initrd = basename ($initrd);
		last;
	}
	if (! -e "$dest/$initrd") {
		$kiwi -> skipped ();
		$kiwi -> warning ("Can't find initrd in $dest");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# check XML configuration data
	#------------------------------------------
	if ((! %xenconfig) || (! $xenconfig{xen_diskdevice})) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Not enough or missing Xen machine config data");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	if (! open ($FD,">$file")) {
		$kiwi -> skipped ();
		$kiwi -> warning  ("Couldn't create xenconfig file: $!");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $device = $xenconfig{xen_diskdevice};
	$device =~ s/\/dev\///;
	my $part = $device."1";
	my $memory = $xenconfig{xen_memory};
	my $ncpus  = $xenconfig{xen_ncpus};
	$image .= ".".$format;
	print $FD '#  -*- mode: python; -*-'."\n";
	print $FD "name=\"".$this->{xml}->getImageDisplayName()."\"\n";
	if ($memory) {
		print $FD 'memory='.$memory."\n";
	}
	if ($ncpus) {
		print $FD 'vcpus='.$ncpus."\n";
	}
	my $tap = $format;
	if ($tap eq "raw") {
		$tap = "aio";
	}
	print $FD 'disk=[ "tap:'.$tap.':'.$image.','.$device.',w" ]'."\n";
	#==========================================
	# network setup
	#------------------------------------------
	my $vifcount = -1;
	foreach my $bname (keys %{$xenconfig{xen_bridge}}) {
		$vifcount++;
		my $mac = $xenconfig{xen_bridge}{$bname};
		my $vif = '"bridge='.$bname.'"';
		if ($bname eq "undef") {
			$vif = '""';
		}
		if ($mac) {
			$vif = '"mac='.$mac.',bridge='.$bname.'"';
			if ($bname eq "undef") {
				$vif = '"mac='.$mac.'"';
			}
		}
		if ($vifcount == 0) {
			print $FD "vif=[ ".$vif;
		} else {
			print $FD ", ".$vif;
		}
	}
	if ($vifcount >= 0) {
		print $FD " ]"."\n";
	}
	#==========================================
	# Process raw config options
	#------------------------------------------
	my @userOptSettings;
	for my $configOpt (@{$xenconfig{xen_config}}) {
		print $FD $configOpt . "\n";
		push @userOptSettings, (split /=/, $configOpt)[0];
	}
	#==========================================
	# xen virtual framebuffer
	#------------------------------------------
	if (! grep /vfb/, @userOptSettings) {
		print $FD 'vfb = ["type=vnc,vncunused=1,vnclisten=0.0.0.0"]'."\n";
	}
	close $FD;
	$kiwi -> done();
	return $file;
}

#==========================================
# createVMwareConfiguration
#------------------------------------------
sub createVMwareConfiguration {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $vmwref = $this->{vmwref};
	my $dest   = dirname  $this->{image};
	my $base   = basename $this->{image};
	my $file;
	my $FD;
	$kiwi -> info ("Creating image VMware configuration file...");
	#==========================================
	# setup config file name from image name
	#------------------------------------------
	my $image = $base;
	if ($base =~ /(.*)\.(.*?)$/) {
		$image = $1;
		$base  = $image.".vmx";
	}
	$file = $dest."/".$base;
	unlink $file;
	#==========================================
	# check XML configuration data
	#------------------------------------------
	my %vmwconfig = %{$vmwref};
	if ((! %vmwconfig) || (! $vmwconfig{vmware_disktype})) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Not enough or Missing VMware machine config data");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	if (! open ($FD,">$file")) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Couldn't create VMware config file: $!");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print $FD '#!/usr/bin/env vmware'."\n";
	print $FD 'config.version = "8"'."\n";
	print $FD 'tools.syncTime = "true"'."\n";
	print $FD 'uuid.action = "create"'."\n";
	if ($vmwconfig{vmware_hwver}) {
		print $FD 'virtualHW.version = "'.$vmwconfig{vmware_hwver}.'"'."\n";
	} else {
		print $FD 'virtualHW.version = "4"'."\n";
	}
	print $FD 'displayName = "'.$image.'"'."\n";
	if ($vmwconfig{vmware_memory}) {
		print $FD 'memsize = "'.$vmwconfig{vmware_memory}.'"'."\n";
	}
	if ($vmwconfig{vmware_ncpus}) {
		print $FD 'numvcpus = "'.$vmwconfig{vmware_ncpus}.'"'."\n";
	}
	print $FD 'guestOS = "'.$vmwconfig{vmware_guest}.'"'."\n";
	#==========================================
	# storage setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_disktype}) {
		my $type   = $vmwconfig{vmware_disktype};
		my $device = $vmwconfig{vmware_disktype}.$vmwconfig{vmware_diskid};
		if ($type eq "ide") {
			# IDE Interface...
			print $FD $device.':0.present = "true"'."\n";
			print $FD $device.':0.fileName= "'.$image.'.vmdk"'."\n";
			print $FD $device.':0.redo = ""'."\n";
		} else {
			# SCSI Interface...
			print $FD $device.'.present = "true"'."\n";
			print $FD $device.'.sharedBus = "none"'."\n";
			print $FD $device.'.virtualDev = "lsilogic"'."\n";
			print $FD $device.':0.present = "true"'."\n";
			print $FD $device.':0.fileName = "'.$image.'.vmdk"'."\n";
			print $FD $device.':0.deviceType = "scsi-hardDisk"'."\n";
		}
	}
	#==========================================
	# network setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_nic}) {
		my %vmnics = %{$vmwconfig{vmware_nic}};
		while (my @nic_info = each %vmnics) {
			my $driver = $nic_info[1] -> { drv };
			my $mode   = $nic_info[1] -> { mode };
			my $nic    = "ethernet".$nic_info[0];
			print $FD $nic.'.present = "true"'."\n";
			print $FD $nic.'.addressType = "generated"'."\n";
			if ($driver) {
				print $FD $nic.'.virtualDev = "'.$driver.'"'."\n";
			}
			if ($mode) {
				print $FD $nic.'.connectionType = "'.$mode.'"'."\n";
			}
			if ($vmwconfig{vmware_arch} =~ /64$/) {
				print $FD $nic.'.allow64bitVmxnet = "true"'."\n";
			}
		}
	}
	#==========================================
	# CD/DVD drive setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_cdtype}) {
		my $device = $vmwconfig{vmware_cdtype}.$vmwconfig{vmware_cdid};
		print $FD $device.':0.present = "true"'."\n";
		print $FD $device.':0.deviceType = "cdrom-raw"'."\n";
		print $FD $device.':0.autodetect = "true"'."\n";
		print $FD $device.':0.startConnected = "true"'."\n";
	}
	#==========================================
	# Setup default options
	#------------------------------------------
	my %defaultOpts = (
		'usb.present'        => 'true',
		'priority.grabbed'   => 'normal',
		'priority.ungrabbed' => 'normal',
		'powerType.powerOff' => 'soft',
		'powerType.powerOn'  => 'soft',
		'powerType.suspend'  => 'soft',
		'powerType.reset'    => 'soft'
	);
	#==========================================
	# Process raw config options
	#------------------------------------------
	my @userOptSettings;
	for my $configOpt (@{$vmwconfig{vmware_config}}) {
		print $FD $configOpt . "\n";
		push @userOptSettings, (split /=/, $configOpt)[0];
	}
	#==========================================
	# Process the default options
	#------------------------------------------
	for my $defOpt (keys %defaultOpts) {
		if (grep /$defOpt/, @userOptSettings) {
			next;
		}
		print $FD $defOpt . ' = ' . '"' . $defaultOpts{$defOpt} . '"' . "\n";
	}
	close $FD;
	chmod 0755,$file;
	$kiwi -> done();
	return $file;
}

#==========================================
# createOVFConfiguration
#------------------------------------------
sub createOVFConfiguration {
	# TODO
	my $this = shift;
	return $this;
}

#==========================================
# helper functions
#------------------------------------------
#==========================================
# __ensure_key
#------------------------------------------
sub __ensure_key {
	my $this = shift;
	my $lines= shift;
	my $key  = shift;
	my $val  = shift;
	my $found= 0;
	my $i = 0;
	for ($i=0;$i<@{$lines};$i++) {
		if ($lines->[$i] =~ /^$key/) {
			$lines->[$i] = "$key=\"$val\"";
			$found = 1;
			last;
		}
	}
	if (! $found) {
		$lines->[$i] = "$key=\"$val\"\n";
	}
}
#==========================================
# __copy_origin
#------------------------------------------
sub __copy_origin {
	my $this = shift;
	my $file = shift;
	if (-f "$file.orig") {
		qxx ("cp $file.orig $file");
	} else {
		qxx ("cp $file $file.orig");
	}
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this   = shift;
	my $tmpdir = $this->{tmpdir};
	if (-d $tmpdir) {
		qxx ("rm -rf $tmpdir 2>&1");
	}
	return $this;
}

1;

# vim: set noexpandtab:
