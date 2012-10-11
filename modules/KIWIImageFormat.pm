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
use KIWIQX qw (qxx);
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
	my $cmdL   = shift;
	#==========================================
	# Module Parameters [ optional ]
	#------------------------------------------
	my $format = shift;
	my $xml    = shift;
	my $tdev   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $code;
	my $data;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{gdata} = $main::global -> getGlobals();
	#==========================================
	# check image file
	#------------------------------------------
	if ((! $this->{gdata}->{StudioNode}) && (! (-f $image || -b $image))) {
		$kiwi -> error ("no such image file: $image");
		$kiwi -> failed ();
		return;
	} 
	#==========================================
	# read XML if required
	#------------------------------------------
	if (! defined $xml) {
		my $boot = new KIWIBoot (
			$kiwi,undef,$cmdL,$image,undef,undef,
			$cmdL->getBuildProfiles()
		);
		if ($boot) {
			$xml = $boot->{xml};
			$boot -> cleanLoop();
		}
		if (! defined $xml) {
			$kiwi -> error  ("Can't load XML configuration, not an image ?");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# check format
	#------------------------------------------
	my $type = $xml -> getImageTypeAndAttributes_legacy();
	if (! defined $format) {
		if (($type) && ($type->{format})) {
			$format = $type->{format};
		}
	}
	#==========================================
	# check global pointer
	#------------------------------------------
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Read some XML data
	#------------------------------------------
	my %xenref = $xml -> getXenConfig_legacy();
	my %vmwref = $xml -> getVMwareConfig_legacy();
	my %ovfref = $xml -> getOVFConfig_legacy();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{cmdL}    = $cmdL;
	$this->{xenref}  = \%xenref;
	$this->{vmwref}  = \%vmwref;
	$this->{ovfref}  = \%ovfref;
	$this->{kiwi}    = $kiwi;
	$this->{xml}     = $xml;
	$this->{format}  = $format;
	$this->{image}   = $image;
	$this->{type}    = $type;
	$this->{imgtype} = $type->{type};
	$this->{targetDevice} = $tdev;
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
	my $targetDevice = $this->{targetDevice};
	#==========================================
	# convert disk into specified format
	#------------------------------------------
	if (($this->{gdata}->{StudioNode}) && ($format ne "ec2")) {
		$kiwi -> warning ("Format conversion skipped in targetstudio mode");
		$kiwi -> skipped ();
		return $this;
	}
	#==========================================
	# check for target device or file
	#------------------------------------------
	if (($targetDevice) && (-b $targetDevice)) {
		$image = $targetDevice;
	}
	#==========================================
	# check if format is a disk
	#------------------------------------------
	if (! defined $format) {
		$kiwi -> warning ("No format for $imgtype conversion specified");
		$kiwi -> skipped ();
		return;
	} else {
		my $data = qxx ("parted $image print 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("system image is not a disk or filesystem");
			$kiwi -> failed ();
			return
		}
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
	} elsif ($format eq "ova") {
		$kiwi -> info ("Starting raw => $format conversion\n");
		return $this -> createOVA();
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
	return;
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
		return;
	}
	if (($type{bootprofile}) && ($type{bootprofile} eq "xen")
		&& ($xend eq "domU")) {
		$kiwi -> info ("Starting $imgtype image machine configuration\n");
		return $this -> createXENConfiguration();
	} elsif ($format eq "vmdk") {
		$kiwi -> info ("Starting $imgtype image machine configuration\n");
		return $this -> createVMwareConfiguration();
	} elsif (($format eq "ovf") || ($format eq "ova")) {
		$kiwi -> info ("Starting $imgtype image machine configuration\n");
		return $this -> createOVFConfiguration();
	} else {
		$kiwi -> warning (
			"Can't create machine setup for selected $imgtype image type"
		);
		$kiwi -> skipped ();
	}
	return;
}

#==========================================
# createOVA
#------------------------------------------
sub createOVA {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $format = $this->{format};
	#==========================================
	# requires ovf to operate
	#------------------------------------------
	my $ovfdir = $this -> createOVF();
	if (! $ovfdir) {
		return;
	}
	return $ovfdir;
}

#==========================================
# createOVF
#------------------------------------------
sub createOVF {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $cmdL   = $this->{cmdL};
	my $xml    = $this->{xml};
	my $ovfref = $this->{ovfref};
	my $image  = $this->{image};
	my $mf;
	my $ovf;
	my $source;
	my $target;
	my $ovfsha1;
	my $imagesha1;
	my $FD;
	#==========================================
	# create vmdk for VMware, required for ovf
	#------------------------------------------
	if ($ovfref->{ovf_type} eq "vmware") {
		my $origin_format = $this->{format};
		$this->{format} = "vmdk";
		$image = $this->createVMDK();
		if (! $image) {
			return;
		}
		$this->{format} = $origin_format;
		$this->{image}  = $image;
	}
	#==========================================
	# prepare ovf destination directory
	#------------------------------------------
	my $ovfdir = $image;
	if ($ovfref->{ovf_type} eq "vmware") {
		$ovfdir =~ s/\.vmdk$/\.ovf/;
	} else {
		$ovfdir =~ s/\.raw$/\.ovf/;
	}
	if (-d $ovfdir) {
		qxx ("rm -f $ovfdir/*");
	} else {
		qxx ("mkdir -p $ovfdir");
	}
	my $img_base = basename $image;
	qxx ("ln -s $image $ovfdir/$img_base");
	$this->{ovfdir} = $ovfdir;
	return $ovfdir;
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
	if (defined $vmwc{vmware_disktype} ) {
		my $diskType = $vmwc{vmware_disktype};
		if ($diskType eq 'scsi') {
			$convert .= ' -o scsi';
		}
	}
	$status = qxx ("qemu-img $convert $target 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create $format image: $status");
		$kiwi -> failed ();
		return;
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
		return;
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
	if (! open ($FD, '<', $this->{gdata}->{KRegion})) {
		return;
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
	my %type = %{$xml->getImageTypeAndAttributes_legacy()};
	my %ec2  = $xml->getEc2Config_legacy();
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
		return;
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
		return;
	}
	if (($this->{targetDevice}) && (-b $this->{targetDevice})) {
		$status = qxx ("mount $this->{targetDevice} $tmpdir 2>&1");
	} else {
		$status = qxx ("mount -o loop $source $tmpdir 2>&1");
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't loop mount $source: $status");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# setup Xen console as serial tty
	#------------------------------------------
	$this -> __copy_origin ("$tmpdir/etc/inittab");
	if (! open $FD, '>>', "$tmpdir/etc/inittab") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/inittab: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $FD "\n";
	print $FD 'X0:12345:respawn:/sbin/agetty -L 9600 xvc0 xterm'."\n";
	close $FD;
	if (! open $FD, '>>', "$tmpdir/etc/securetty") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/securetty: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $FD "\n";
	print $FD 'xvc0'."\n";
	close $FD;
	#==========================================
	# create initrd
	#------------------------------------------
	if (! open $FD, '>', "$tmpdir/create_initrd.sh") {
		$kiwi -> error  ("Failed to open $tmpdir/create_initrd.sh: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
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
		$this -> __clean_loop ($tmpdir);
		return;
	}
	qxx ("rm -f $tmpdir/create_initrd.sh");
	#==========================================
	# create grub bootloader setup
	#------------------------------------------
	# setup directory for grub loader
	qxx ("mkdir -p $tmpdir/boot/grub");
	# copy grub image files
	qxx ("cp $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1");
	# boot/grub/device.map
	if (! open $FD, '>', "$tmpdir/boot/grub/device.map") {
		$kiwi -> error  ("Failed to open $tmpdir/boot/grub/device.map: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $FD '(hd0)'."\t".'/dev/sda1'."\n";
	close $FD;
	# etc/grub.conf
	if (! open $FD, '>', "$tmpdir/etc/grub.conf") {
		$kiwi -> error  ("Failed to open $tmpdir/etc/grub.conf: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $FD 'setup --stage2=/boot/grub/stage2 --force-lba (hd0) (hd0)'."\n";
	print $FD 'quit'."\n";
	close $FD;
	# boot/grub/menu.lst
	my $args="xencons=xvc0 console=xvc0 splash=silent showopts";
	if (! open $FD, '>', "$tmpdir/create_bootmenu.sh") {
		$kiwi -> error  ("Failed to open $tmpdir/create_bootmenu.sh: $!");
		$kiwi -> failed ();
		return;
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
		$this -> __clean_loop ($tmpdir);
		return;
	}
	qxx ("rm -f $tmpdir/create_bootmenu.sh");
	# etc/sysconfig/bootloader
	if (open $FD, '<', "$tmpdir/etc/sysconfig/bootloader") {
		my @lines = <$FD>;
		close $FD;
		$this -> __ensure_key (\@lines, "LOADER_TYPE"      , "grub");
		$this -> __ensure_key (\@lines, "DEFAULT_NAME"     , $title);
		$this -> __ensure_key (\@lines, "DEFAULT_APPEND"   , $args );
		$this -> __ensure_key (\@lines, "DEFAULT_VGA"      , ""    );
		$this -> __ensure_key (\@lines, "FAILSAFE_APPEND"  , $args );
		$this -> __ensure_key (\@lines, "FAILSAFE_VGA"     , ""    );
		$this -> __ensure_key (\@lines, "XEN_KERNEL_APPEND", $args );
		$this -> __ensure_key (\@lines, "XEN_APPEND"       , ""    );
		$this -> __ensure_key (\@lines, "XEN_VGA"          , ""    );
		open  $FD, '>', "$tmpdir/etc/sysconfig/bootloader";
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
		$this -> __clean_loop ($tmpdir);
		return;
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
	$this -> __clean_loop ($tmpdir);
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
		return
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
			return;
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
		if (! %xenconfig) {
			$kiwi -> warning ("No machine section for this image type found");
		} else {
			$kiwi -> warning ("No disk device setup found in machine section");
		}
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	if (! open ($FD, '>', "$file")) {
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
		if (! %vmwconfig) {
			$kiwi -> warning ("No machine section for this image type found");
		} else {
			$kiwi -> warning ("No disk device setup found in machine section");
		}
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	if (! open ($FD, '>', "$file")) {
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
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $ovfdir = $this->{ovfdir};
	my $ovfref = $this->{ovfref};
	my $format = $this->{format};
	my $base   = basename $this->{image};
	my $ovf;
	my $diskformat;
	my $systemtype;
	my $ostype;
	my $osid;
	my $FD;
	#==========================================
	# setup config file name from image name
	#------------------------------------------
	$kiwi -> info ("Creating image OVF configuration file...");
	my $image = $base;
	if ($base =~ /(.*)\.(.*?)$/) {
		$image = $1;
		$base  = $image.".ovf";
	}
	$ovf = $ovfdir."/".$base;
	unlink $ovf;
	#==========================================
	# check XML configuration data
	#------------------------------------------
	my %ovfconfig = %{$ovfref};
	if ((! %ovfconfig) || (! $ovfconfig{ovf_type})) {
		$kiwi -> skipped ();
		if (! %ovfconfig) {
			$kiwi -> warning ("No machine section for this image type found");
		} else {
			$kiwi -> warning ("No disk device setup found in machine section");
		}
		$kiwi -> skipped ();
		return $ovf;
	}
	my $type = $ovfconfig{ovf_type};
	#==========================================
	# OVF type specific setup
	#------------------------------------------
	if ($type eq "zvm") {
		$osid       = 36;
		$systemtype = "IBM:zVM:LINUX";
		$ostype     = "sles";
		$diskformat = "http://www.ibm.com/".
			"xmlns/ovf/diskformat/s390.linuxfile.exustar.gz";
	} elsif ($type eq "povervm") {
		$osid       = 84;
		$systemtype = "IBM:POWER:AIXLINUX";
		$ostype     = "sles";
		$diskformat = "http://www.ibm.com/".
			"xmlns/ovf/diskformat/power.aix.mksysb";
	} elsif ($type eq "xen") {
		$osid       = 84;
	} else {
		$osid       = 84;
		$systemtype = "vmx-04";
		$ostype     = $ovfconfig{vmware_guest};
		$diskformat = "http://www.vmware.com/".
			"interfaces/specifications/vmdk.html#streamOptimized";
	}
	#==========================================
	# create config file
	#------------------------------------------
	if (! open ($FD, '>', "$ovf")) {
		$kiwi -> error ("Couldn't create OVF config file: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print $FD "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"."\n".
		'<Envelope vmw:buildId="build-260188"'."\n".
		'xmlns="http://schemas.dmtf.org/ovf/envelope/1"'."\n".
		'xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common"'."\n".
		'xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"'."\n".
		'xmlns:rasd="http://schemas.dmtf.org/'.
			'wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData"'."\n".
		'xmlns:vmw="http://www.vmware.com/schema/ovf"'."\n".
		'xmlns:vssd="http://schemas.dmtf.org/'.
			'wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData"'."\n".
		'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'."\n";
	#==========================================
	# image description
	#------------------------------------------
	my $size = -s $this->{image};
	print $FD "<ovf:References>"."\n";
	print $FD "\t"."<ovf:File ovf:href=\"$base\""."\n".
		"\t"."ovf:id=\"file1\""."\n".
		"\t"."ovf:size=\"$size\"/>"."\n";
	print $FD "</ovf:References>"."\n";
	#==========================================
	# storage description
	#------------------------------------------
	print $FD "<ovf:DiskSection>"."\n".
		"\t"."<ovf:Info>Disk Section</ovf:Info>"."\n".
		"\t"."<ovf:Disk ovf:capacity=\"$size\"".
			" ovf:capacityAllocationUnits=\"byte\"".
			" ovf:diskId=\"vmRef1disk\" ovf:fileRef=\"file1\"".
			" ovf:format=\"$diskformat\"".
			" ovf:populatedSize=\"$size\"/>"."\n";
	print $FD "</ovf:DiskSection>"."\n";
	#==========================================
	# network description
	#------------------------------------------
	if (defined $ovfconfig{ovf_bridge}) {
		my $name = "The bridged network for:";
		my %nics = %{$ovfconfig{ovf_bridge}};
		while (my @nic_info = each %nics) {
			my $nic = $nic_info[0];
			next if $nic eq "undef";
			print $FD "<ovf:NetworkSection>"."\n".
				"\t"."<Info>The list of logical networks</Info>"."\n".
				"\t"."<Network ovf:name=\"$nic\">"."\n".
				"\t\t"."<Description>$name $nic</Description>"."\n";
			print $FD "</ovf:NetworkSection>"."\n";
		}
	}
	#==========================================
	# virtual system description
	#------------------------------------------
	print $FD "<VirtualSystem ovf:id=\"vm\">"."\n".
		"\t"."<Info>A virtual machine</Info>"."\n".
		"\t"."<Name>$base</Name>"."\n".
		"\t"."<OperatingSystemSection ".
		"ovf:id=\"$osid\" vmw:osType=\"$ostype\">"."\n".
		"\t\t"."<Info>Appliance created by KIWI</Info>"."\n".
		"\t"."</OperatingSystemSection>"."\n".
		"\t"."<VirtualHardwareSection>"."\n".
		"\t\t"."<Info>Virtual hardware requirements</Info>"."\n".
		"\t\t"."<System>"."\n".
		"\t\t"."<vssd:ElementName>Virtual Hardware Family".
		"</vssd:ElementName>"."\n".
		"\t\t"."<vssd:InstanceID>0</vssd:InstanceID>"."\n".
		"\t\t"."<vssd:VirtualSystemIdentifier>$base".
		"</vssd:VirtualSystemIdentifier>"."\n".
		"\t\t"."<vssd:VirtualSystemType>$systemtype".
		"</vssd:VirtualSystemType>"."\n".
		"\t\t"."</System>"."\n";
	print $FD "\t"."</VirtualHardwareSection>"."\n";
	print $FD "\t"."</VirtualSystem>"."\n";
	#==========================================
	# close envelope
	#------------------------------------------
	print $FD "</Envelope>";
	close $FD;
	#==========================================
	# create manifest file
	#------------------------------------------
	my $mf = $ovf;
	$mf =~ s/\.ovf$/\.mf/;
	if (! open ($FD, '>', "$mf")) {
		$kiwi -> error ("Couldn't create manifest file: $!");
		$kiwi -> failed ();
		return;
	}
	my $base_image = basename $this->{image};
	my $base_config= basename $ovf;
	my $ovfsha1   = qxx ("sha1sum $ovf | cut -f1 -d ' ' 2>&1");
	my $imagesha1 = qxx ("sha1sum $this->{image} | cut -f1 -d ' ' 2>&1");
	print $FD "SHA1($base_config)= $ovfsha1"."\n";
	print $FD "SHA1($base_image)= $imagesha1"."\n";
	close $FD;
	#==========================================
	# create OVA tarball
	#------------------------------------------
	if ($format eq "ova") {
		my $destdir  = dirname $this->{image};
		my $ovaimage = basename $ovfdir;
		$ovaimage =~ s/\.ovf$/\.ova/;
		my $ovabasis = $ovaimage;
		$ovabasis =~ s/\.ova$//;
		my $files = "$ovabasis.ovf $ovabasis.mf $ovabasis.vmdk";
		my $status = qxx (
			"tar -h -C $ovfdir -cf $destdir/$ovaimage $files 2>&1"
		);
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $format image: $status");
			$kiwi -> failed ();
			return;
		}
	}
	$kiwi -> done();
	return $ovf;
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
# __clean_loop
#------------------------------------------
sub __clean_loop {
	my $this = shift;
	my $dir = shift;
	qxx ("umount $dir/sys 2>&1");
	qxx ("umount $dir 2>&1");
	qxx ("rmdir  $dir 2>&1");
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
