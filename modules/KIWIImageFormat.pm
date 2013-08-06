#================
# FILE          : KIWIImageFormat.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use warnings;
use FileHandle;
use File::Basename;
#==========================================
# KWIW Modules
#------------------------------------------
use KIWIBoot;
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);

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
	my $global = KIWIGlobals -> instance();
	$this->{gdata} = $global -> getKiwiConfig();
	#==========================================
	# check image file
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if ((! $this->{gdata}->{StudioNode}) && (! (-f $image || -b $image))) {
		$kiwi -> error ("no such image file: $image");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# read XML if required
	#------------------------------------------
	if (! defined $xml) {
		my $boot = KIWIBoot -> new (
			undef,$cmdL,$image,undef,undef,
			$cmdL->getBuildProfiles()
		);
		if ($boot) {
			$xml = $boot->{xml};
			$boot -> cleanStack ();
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
	# check for guid in vhd-fixed format
	#------------------------------------------
	my $guid = $xml -> getImageType() -> getVHDFixedTag();
	#==========================================
	# Read some XML data
	#------------------------------------------
	my %xenref = $xml -> getXenConfig_legacy();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{cmdL}    = $cmdL;
	$this->{xenref}  = \%xenref;
	$this->{vmdata}  = $xml -> getVMachineConfig();
	$this->{kiwi}    = $kiwi;
	$this->{xml}     = $xml;
	$this->{format}  = $format;
	$this->{image}   = $image;
	$this->{type}    = $type;
	$this->{guid}    = $guid;
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
		return $this;
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
# createMachineConfiguration
#------------------------------------------
sub createMachineConfiguration {
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
	my $image  = $this->{image};
	my $cmdl   = $this->{cmdL};
	#==========================================
	# create vmdk for VMware, required for ovf
	#------------------------------------------
	my $vmdata = $this->{vmdata};
	my $ovftype = $vmdata -> getOVFType();
	if ($ovftype eq "vmware") {
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
	if ($ovftype eq "vmware") {
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
	my $finalImgLoc = $cmdl -> getImageTargetDir();
	qxx ("ln -s $finalImgLoc/$img_base $ovfdir/$img_base");
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
	my $source = $this->{image};
	my $target = $source;
	my $convert;
	my $status;
	my $result;
	$kiwi -> info ("Creating $format image...");
	$target  =~ s/\.raw$/\.$format/;
	$convert = "convert -f raw $source -O $format";
	if ($this->{vmdata}) {
		my $diskType = $this->{vmdata} -> getSystemDiskType();
		if ($diskType && $diskType eq 'scsi') {
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
	my $guid   = $this->{guid};
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
	if ($guid) {
		$kiwi -> info ("Saving VHD disk Tag: $guid");
		if (! $this -> writeVHDTag ($target,$guid)) {
			return;
		}
		$kiwi -> done();
	}
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
	my $kmod   = "INITRD_MODULES";
	my $sysk   = "/etc/sysconfig/kernel";
	my $aminame= basename $source;
	my $destdir= dirname  $source;
	my $status;
	my $result;
	my $tmpdir;
	#==========================================
	# Default kernel modules
	#------------------------------------------
	# Building ec2 image the type must be a filesystem
	my $fsType = $xml -> getImageType() -> getTypeName();
	my $mods = "$fsType jbd xenblk";
	#==========================================
	# Import AWS region kernel map
	#------------------------------------------
	my %ec2RegionKernelMap;
	my $REGIONFD = FileHandle -> new();
	if (! $REGIONFD -> open ($this->{gdata}->{KRegion})) {
		return;
	}
	while (my $line = <$REGIONFD>) {
		next if $line =~ /^#/;
		if ($line =~ /(.*)\s*=\s*(.*)/) {
			my $region= $1;
			my $aki   = $2;
			$ec2RegionKernelMap{$region} = $aki;
		}
	}
	$REGIONFD -> close();
	#==========================================
	# Amazon pre-conditions check
	#------------------------------------------
	$kiwi -> info ("Creating $format image...\n");
	$target  =~ s/\/$//;
	$target .= ".$format";
	$aminame.= ".ami";
	my $arch = qxx ("uname -m"); chomp ( $arch );
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
	my $ITABFD = FileHandle -> new();
	if (! $ITABFD -> open (">>$tmpdir/etc/inittab")) {
		$kiwi -> error  ("Failed to open $tmpdir/etc/inittab: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $ITABFD "\n";
	print $ITABFD 'X0:12345:respawn:/sbin/agetty -L 9600 xvc0 xterm'."\n";
	$ITABFD -> close();
	my $STTYFD = FileHandle -> new();
	if (! $STTYFD -> open (">>$tmpdir/etc/securetty")) {
		$kiwi -> error  ("Failed to open $tmpdir/etc/securetty: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $STTYFD "\n";
	print $STTYFD 'xvc0'."\n";
	$STTYFD -> close();
	#==========================================
	# create initrd
	#------------------------------------------
	my $IRDFD = FileHandle -> new();
	if (! $IRDFD -> open (">$tmpdir/create_initrd.sh")) {
		$kiwi -> error  ("Failed to open $tmpdir/create_initrd.sh: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $IRDFD 'export rootdev=/dev/sda1'."\n";
	print $IRDFD 'export rootfstype='.$fsType."\n";
	print $IRDFD 'mknod /dev/sda1 b 8 1'."\n";
	print $IRDFD 'touch /boot/.rebuild-initrd'."\n";
	print $IRDFD 'mv /lib/mkinitrd/setup/61-multipath.sh /tmp'."\n";
	print $IRDFD 'sed -i -e \'s@^';
	print $IRDFD $kmod;
	print $IRDFD '="\(.*\)"@'.$kmod.'="\1 ';
	print $IRDFD $mods;
	print $IRDFD '"@\' ';
	print $IRDFD $sysk;
	print $IRDFD "\n";
	print $IRDFD 'mkinitrd -A -B'."\n";
	print $IRDFD 'mv /tmp/61-multipath.sh /lib/mkinitrd/setup/'."\n";
	$IRDFD -> close();
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
	my $DMAPFD = FileHandle -> new();
	if (! $DMAPFD -> open (">$tmpdir/boot/grub/device.map")) {
		$kiwi -> error  ("Failed to open $tmpdir/boot/grub/device.map: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $DMAPFD '(hd0)'."\t".'/dev/sda1'."\n";
	$DMAPFD -> close();
	# etc/grub.conf
	my $GCFD = FileHandle -> new();
	if (! $GCFD -> open (">$tmpdir/etc/grub.conf")) {
		$kiwi -> error  ("Failed to open $tmpdir/etc/grub.conf: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	print $GCFD 'setup --stage2=/boot/grub/stage2 --force-lba (hd0) (hd0)'
		. "\n";
	print $GCFD 'quit'."\n";
	$GCFD -> close();
	# boot/grub/menu.lst
	my $title= $xml -> getImageDisplayName();
	my $args = "xencons=xvc0 console=xvc0 splash=silent showopts";
	my $GMFD = FileHandle -> new();
	if (! $GMFD -> open (">$tmpdir/create_bootmenu.sh")) {
		$kiwi -> error  ("Failed to open $tmpdir/create_bootmenu.sh: $!");
		$kiwi -> failed ();
		return;
	}
	print $GMFD 'file=/boot/grub/menu.lst'."\n";
	print $GMFD 'args="'.$args.'"'."\n";
	print $GMFD 'echo "serial --unit=0 --speed=9600" > $file'."\n";
	print $GMFD 'echo "terminal --dumb serial" >> $file'."\n";
	print $GMFD 'echo "default 0" >> $file'."\n";
	print $GMFD 'echo "timeout 0" >> $file'."\n";
	print $GMFD 'echo "hiddenmenu" >> $file'."\n";
	print $GMFD 'ls /lib/modules | while read D; do'."\n";
	print $GMFD '   [ -d "/lib/modules/$D" ] || continue'."\n";
	print $GMFD '   echo "$D"'."\n";
	print $GMFD 'done | /usr/lib/rpm/rpmsort | tac | while read D; do'."\n";
	print $GMFD '   for K in /boot/vmlinu[zx]-$D; do'."\n";
	print $GMFD '      [ -f "$K" ] || continue'."\n";
	print $GMFD '      echo >> $file'."\n";
	print $GMFD '      echo "title '.$title.'" >> $file'."\n";
	print $GMFD '      echo "    root (hd0)" >> $file'."\n";
	print $GMFD '      echo "    kernel $K root=/dev/sda1 $args" >> $file';
	print $GMFD "\n";
	print $GMFD '      if [ -f "/boot/initrd-$D" ]; then'."\n";
	print $GMFD '         echo "    initrd /boot/initrd-$D" >> $file'."\n";
	print $GMFD '      fi'."\n";
	print $GMFD '   done'."\n";
	print $GMFD 'done'."\n";
	$GMFD -> close();
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
	my $SYSBOOT_RFD = FileHandle -> new();
	if ($SYSBOOT_RFD -> open ("$tmpdir/etc/sysconfig/bootloader")) {
		my @lines = <$SYSBOOT_RFD>;
		$SYSBOOT_RFD -> close();
		$this -> __ensure_key (\@lines, "LOADER_TYPE"      , "grub");
		$this -> __ensure_key (\@lines, "DEFAULT_NAME"     , $title);
		$this -> __ensure_key (\@lines, "DEFAULT_APPEND"   , $args );
		$this -> __ensure_key (\@lines, "DEFAULT_VGA"      , ""    );
		$this -> __ensure_key (\@lines, "FAILSAFE_APPEND"  , $args );
		$this -> __ensure_key (\@lines, "FAILSAFE_VGA"     , ""    );
		$this -> __ensure_key (\@lines, "XEN_KERNEL_APPEND", $args );
		$this -> __ensure_key (\@lines, "XEN_APPEND"       , ""    );
		$this -> __ensure_key (\@lines, "XEN_VGA"          , ""    );
		my $SYSBOOT_WFD = FileHandle -> new();
		if (! $SYSBOOT_WFD -> open (">$tmpdir/etc/sysconfig/bootloader")) {
			$kiwi -> error  ("Failed to create sysconfig/bootloader: $!");
			$kiwi -> failed ();
			$this -> __clean_loop ($tmpdir);
			return;
		}
		print $SYSBOOT_WFD @lines;
		$SYSBOOT_WFD -> close();
	}
	#==========================================
	# setup fstab
	#------------------------------------------
	$this -> __copy_origin ("$tmpdir/etc/fstab");
	my $FSTABFD = FileHandle -> new();
	if (! $FSTABFD -> open  ("+<$tmpdir/etc/fstab")) {
		$kiwi -> error  ("Failed to open $tmpdir/etc/fstab: $!");
		$kiwi -> failed ();
		$this -> __clean_loop ($tmpdir);
		return;
	}
	my $rootfs=0;
	while (my $line = <$FSTABFD>) {
		my @entries = split (/\s+/,$line);
		if ($entries[1] eq "/") {
			$rootfs=1; last;
		}
	}
	if (! $rootfs) {
		print $FSTABFD "/dev/sda1 / $fsType defaults 0 0"."\n";
	}
	$FSTABFD -> close();
	#==========================================
	# cleanup loop
	#------------------------------------------
	$this -> __clean_loop ($tmpdir);
	#==========================================
	# Rebuild md5 sum
	#------------------------------------------
	my $file = $source;
	if (($this->{targetDevice}) && (-b $this->{targetDevice})) {
		$file = $this->{targetDevice};
	}
	if (! KIWIBoot::buildMD5Sum ($this,$file,$file.'.md5')) {
		return;
	}
	#==========================================
	# AWS Account data check
	#------------------------------------------
	my $ec2Config = $xml -> getEC2Config();
	if (! $ec2Config) {
		$kiwi -> info ('No AWS Account Data provided, skip bundle creation');
		$kiwi -> skipped ();
		return $source;
	}
	my $acctNo = $ec2Config -> getAccountNumber();
	my $certFl = $ec2Config -> getCertFilePath();
	my $privKey = $ec2Config -> getPrivateKeyFilePath();
	my $have_account = 1;
	if (! defined $acctNo) {
		$kiwi->warning ("Missing AWS account number");
		$kiwi->skipped ();
		$have_account = 0;
	}
	if (! defined $certFl) {
		$kiwi->warning ("Missing AWS user's PEM encoded RSA pubkey cert file");
		$kiwi->skipped ();
		$have_account = 0;
	} elsif (! -f $certFl) {
		$kiwi->warning ("EC2 file: $certFl does not exist");
		$kiwi->skipped ();
		$have_account = 0;
	}
	if (! defined $privKey) {
		$kiwi->warning ("Missing AWS user's PEM encoded RSA private key file");
		$kiwi->skipped ();
		$have_account = 0;
	} elsif (! -f $privKey) {
		$kiwi->warning ("EC2 file: $privKey does not exist");
		$kiwi->skipped ();
		$have_account = 0;
	}
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
	my $locator = KIWILocator -> instance();
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
	my $amiopts = "-i $source "
		. "-k $privKey "
		. "-c $certFl "
		. "-u $acctNo "
		. "-p $aminame "
		. '--block-device-mapping ami=sda1,root=/dev/sda1';
	my $ec2Regions = $ec2Config -> getRegions();
	my @regions;
	if (! $ec2Regions) {
		push @regions, 'any';
	} else {
		@regions = @{$ec2Regions};
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
	my $XENFD = FileHandle -> new();
	if (! $XENFD -> open (">$file")) {
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
	print $XENFD '#  -*- mode: python; -*-'."\n";
	print $XENFD "name=\"".$this->{xml}->getImageDisplayName()."\"\n";
	if ($memory) {
		print $XENFD 'memory='.$memory."\n";
	}
	if ($ncpus) {
		print $XENFD 'vcpus='.$ncpus."\n";
	}
	my $tap = $format;
	if ($tap eq "raw") {
		$tap = "aio";
	}
	print $XENFD 'disk=[ "tap:'.$tap.':'.$image.','.$device.',w" ]'."\n";
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
			print $XENFD "vif=[ ".$vif;
		} else {
			print $XENFD ", ".$vif;
		}
	}
	if ($vifcount >= 0) {
		print $XENFD " ]"."\n";
	}
	#==========================================
	# Process raw config options
	#------------------------------------------
	my @userOptSettings;
	for my $configOpt (@{$xenconfig{xen_config}}) {
		print $XENFD $configOpt . "\n";
		push @userOptSettings, (split /=/, $configOpt)[0];
	}
	#==========================================
	# xen virtual framebuffer
	#------------------------------------------
	if (! grep {/vfb/} @userOptSettings) {
		print $XENFD 'vfb = ["type=vnc,vncunused=1,vnclisten=0.0.0.0"]'."\n";
	}
	$XENFD -> close();
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
	my $dest   = dirname  $this->{image};
	my $base   = basename $this->{image};
	my $file;
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
	my $vmdata = $this->{vmdata};
	if (! $vmdata ) {
		$kiwi -> skipped ();
		$kiwi -> warning ('No machine section for this image type found');
		$kiwi -> skipped ();
		return $file;
	}
	my $diskController = $vmdata -> getSystemDiskController();
	if (! $diskController) {
		$kiwi -> skipped ();
		$kiwi -> warning ('No disk device setup found in machine section');
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# Create config file
	#------------------------------------------
	my $VMWFD = FileHandle -> new();
	if (! $VMWFD -> open (">$file")) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Couldn't create VMware config file: $!");
		$kiwi -> skipped ();
		return $file;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print $VMWFD '#!/usr/bin/env vmware'."\n";
	print $VMWFD 'config.version = "8"'."\n";
	print $VMWFD 'tools.syncTime = "true"'."\n";
	print $VMWFD 'uuid.action = "create"'."\n";
	my $hwVer = $vmdata -> getHardwareVersion();
	print $VMWFD 'virtualHW.version = "' . $hwVer . '"' . "\n";
	print $VMWFD 'displayName = "' . $image . '"' . "\n";
	my $memory = $vmdata -> getMemory();
	if ($memory) {
		print $VMWFD 'memsize = "' . $memory . '"' . "\n";
	}
	my $ncpus = $vmdata -> getNumCPUs();
	if ($ncpus) {
		print $VMWFD 'numvcpus = "' . $ncpus . '"' . "\n";
	}
	my $guest = $vmdata -> getGuestOS();
	print $VMWFD 'guestOS = "' . $guest . '"' . "\n";
	#==========================================
	# storage setup
	#------------------------------------------
	my $diskID = $vmdata -> getSystemDiskID();
	if (! $diskID) {
		$diskID = '0';
	}
	my $device = $diskController . $diskID;
	if ($diskController eq "ide") {
		# IDE Interface...
		print $VMWFD $device.':0.present = "true"'."\n";
		print $VMWFD $device.':0.fileName= "'.$image.'.vmdk"'."\n";
		print $VMWFD $device.':0.redo = ""'."\n";
	} else {
		# SCSI Interface...
		print $VMWFD $device.'.present = "true"'."\n";
		print $VMWFD $device.'.sharedBus = "none"'."\n";
		print $VMWFD $device.'.virtualDev = "lsilogic"'."\n";
		print $VMWFD $device.':0.present = "true"'."\n";
		print $VMWFD $device.':0.fileName = "'.$image.'.vmdk"'."\n";
		print $VMWFD $device.':0.deviceType = "scsi-hardDisk"'."\n";
	}
	#==========================================
	# network setup
	#------------------------------------------
	my @nicIds = @{$vmdata -> getNICIDs()};
	for my $id (@nicIds) {
		my $iFace = $vmdata -> getNICInterface($id);
		my $nic = "ethernet" . $iFace;
		print $VMWFD $nic . '.present = "true"' . "\n";
		my $mac = $vmdata -> getNICMAC($id);
		if ($mac) {
			print $VMWFD $nic . '.addressType = "static"' . "\n";
			print $VMWFD $nic . '.address = ' . "$mac\n";
		} else {
			print $VMWFD $nic . '.addressType = "generated"' . "\n";
		}
		my $driver = $vmdata -> getNICDriver($id);
		if ($driver) {
			print $VMWFD $nic . '.virtualDev = "' . $driver . '"' . "\n";
		}
		my $mode = $vmdata -> getNICMode($id);
		if ($mode) {
			print $VMWFD $nic . '.connectionType = "' . $mode . '"' . "\n";
		}
		my $arch = $vmdata -> getArch();
		if ($arch && $arch=~ /64$/smx) {
			print $VMWFD $nic.'.allow64bitVmxnet = "true"'."\n";
		}
	}
	#==========================================
	# CD/DVD drive setup
	#------------------------------------------
	my $cdtype = $vmdata -> getDVDController();
	my $cdid = $vmdata -> getDVDID();
	if ($cdtype && defined $cdid) {
		my $device = $cdtype . $cdid;
		print $VMWFD $device.':0.present = "true"'."\n";
		print $VMWFD $device.':0.deviceType = "cdrom-raw"'."\n";
		print $VMWFD $device.':0.autodetect = "true"'."\n";
		print $VMWFD $device.':0.startConnected = "true"'."\n";
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
	my $rawConfig = $vmdata -> getConfigEntries();
	my %usrConfigSet = ();
	if ($rawConfig) {
		my @usrConfig = @{$rawConfig};
		for my $configOpt (@usrConfig) {
			print $VMWFD $configOpt . "\n";
			my @opt = split /=/smx, $configOpt;
			$usrConfigSet{$opt[0]} = 1;
		}
	}
	#==========================================
	# Process the default options
	#------------------------------------------
	for my $defOpt (keys %defaultOpts) {
		if ($usrConfigSet{$defOpt}) {
			next;
		}
		print $VMWFD $defOpt . ' = ' . '"' . $defaultOpts{$defOpt}
			. '"' . "\n";
	}
	$VMWFD -> close();
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
	my $format = $this->{format};
	my $base   = basename $this->{image};
	my $ovf;

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
	my $vmdata = $this->{vmdata};
	if (! $vmdata ) {
		$kiwi -> skipped ();
		$kiwi -> warning ('No machine section for this image type found');
		$kiwi -> skipped ();
		return $ovf;
	}
	my $ovfType = $vmdata -> getOVFType();
	if (! $ovfType) {
		$kiwi -> skipped ();
		my $msg = 'No type specified, cannot disambiguate OVF format.';
		$kiwi -> warning ($msg);
		$kiwi -> skipped ();
		return $ovf;
	}
	#==========================================
	# OVF type specific setup
	#------------------------------------------
	my $diskformat;
	my $osid;
	my $systemtype;
	my $guest = $vmdata -> getGuestOS();
	my $hwVersion = $vmdata -> getHardwareVersion();
	if ($guest eq 'suse') {
		$guest = 'SUSE';
	} elsif ($guest eq 'suse-64') {
		$guest = 'SUSE 64-Bit';
	}
	my $ostype = $guest;
	if ($ovfType eq 'zvm') {
		$osid       = 36;
		$systemtype = 'IBM:zVM:LINUX';
		$diskformat = 'http://www.ibm.com/'
			. 'xmlns/ovf/diskformat/s390.linuxfile.exustar.gz';
	} elsif ($ovfType eq 'powervm') {
		$osid       = 84;
		$systemtype = 'IBM:POWER:AIXLINUX';
		$diskformat = 'http://www.ibm.com/'
			. 'xmlns/ovf/diskformat/power.aix.mksysb';
	} elsif ($ovfType eq 'xen') {
		$osid       = 84;
		$systemtype = 'xen-' . $hwVersion;
		$diskformat = 'http://xen.org/';
	} else {
		$osid       = 84;
		$systemtype = 'vmx-0' . $hwVersion;
		$diskformat = 'http://www.vmware.com/'
			. 'interfaces/specifications/vmdk.html#streamOptimized';
	}
	#==========================================
	# create config file
	#------------------------------------------
	my $OVFFD = FileHandle -> new();
	if (! $OVFFD -> open (">$ovf")) {
		$kiwi -> error ("Couldn't create OVF config file: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print $OVFFD '<?xml version="1.0" encoding="UTF-8"?>' . "\n"
		. '<Envelope vmw:buildId="build-260188"' . "\n"
		. 'xmlns="http://schemas.dmtf.org/ovf/envelope/1"' . "\n"
		. 'xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common"' . "\n"
		. 'xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"' . "\n"
		. 'xmlns:rasd="http://schemas.dmtf.org/'
		. 'wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData"' . "\n"
		. 'xmlns:vmw="http://www.vmware.com/schema/ovf"' . "\n"
		. 'xmlns:vssd="http://schemas.dmtf.org/'
		. 'wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData"' . "\n"
		. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' . "\n";
	#==========================================
	# image description
	#------------------------------------------
	my $size = -s $this->{image};
	print $OVFFD '<ovf:References>' . "\n"
		. "\t" . '<ovf:File ovf:href="' . $base. '" ovf:id="file1"'
		. 'ovf:size="' . $size . '"/>' . "\n"
		. '</ovf:References>' . "\n";
	#==========================================
	# storage description
	#------------------------------------------
	print $OVFFD '<ovf:DiskSection>' . "\n"
		. "\t" . '<ovf:Info>Virtual disk information</ovf:Info>' . "\n"
		. "\t" . '<ovf:Disk ovf:capacity="' . $size . '" '
		. 'ovf:capacityAllocationUnits="byte" '
		. 'ovf:diskId="vmdisk1" '
		. 'ovf:fileRef="file1"'
		. 'ovf:format="' . $diskformat . '" '
		. 'ovf:populatedSize="' . $size . '"/>' . "\n"
	    . '</ovf:DiskSection>' . "\n";
	#==========================================
	# network description
	#------------------------------------------
	my @nicIDs = @{$vmdata -> getNICIDs()};
	my $numNics = scalar @nicIDs;
	if ($numNics) {
		print $OVFFD '<ovf:NetworkSection>' . "\n"
			. "\t" . '<Info>The list of logical networks</Info>' . "\n";
	}
	my %modes;
	for my $id (@nicIDs) {
		my $mode = $vmdata -> getNICMode($id);
		if (! $modes{$mode}) {
			print $OVFFD "\t" . '<Network ovf:name="' . $mode . '">' . "\n"
				. "\t\t" . '<Description>The ' . $mode . ' network'
				. '</Description>' . "\n"
				. "\t" . '</Network>' . "\n";
			$modes{$mode} = 1;
		}
	}
	if ($numNics) {
		print $OVFFD '</ovf:NetworkSection>' . "\n";
	}
	#==========================================
	# virtual system description
	#------------------------------------------
	my $instID = 0;
	print $OVFFD '<VirtualSystem ovf:id="vm">' . "\n"
		. "\t" . '<Info>A virtual machine</Info>' . "\n"
		. "\t" . '<Name>' . $base . '</Name>' . "\n"
		. "\t" . '<OperatingSystemSection '
		. 'ovf:id="' . $osid. '" '
		. 'vmw:osType="' . $ostype . '">' . "\n"
		. "\t\t" . '<Info>Appliance created by KIWI</Info>' . "\n"
		. "\t" . '</OperatingSystemSection>' . "\n"
		. "\t" . '<VirtualHardwareSection>' . "\n"
		. "\t\t" . '<Info>Virtual hardware requirements</Info>' . "\n"
		. "\t\t" . '<System>' . "\n"
		. "\t\t\t" . '<vssd:ElementName>Virtual Hardware Family'
		. '</vssd:ElementName>' . "\n"
		. "\t\t\t" . '<vssd:InstanceID>' . $instID
		. '</vssd:InstanceID>' . "\n"
		. "\t\t\t" . '<vssd:VirtualSystemIdentifier>' . $base
		. '</vssd:VirtualSystemIdentifier>' . "\n"
		. "\t\t\t" . '<vssd:VirtualSystemType>' . $systemtype
		. '</vssd:VirtualSystemType>' . "\n"
		. "\t\t" . '</System>' . "\n";
	$instID += 1;
	# CPU setup
	my $maxCPU = $vmdata -> getMaxCPUCnt();
	my $minCPU = $vmdata -> getMinCPUCnt();
	my $numCPU = $vmdata -> getNumCPUs();
	if ($maxCPU || $minCPU || $numCPU) {
		print $OVFFD "\t\t" . '<Item>' . "\n"
			. "\t\t\t"
			. '<rasd:Description>Number of Virtual CPUs</rasd:Description>'
			. "\n"
			. "\t\t\t"
			. '<rasd:ElementName>CPU definition</rasd:ElementName>' . "\n";
		if (! $numCPU) {
			if ($maxCPU && $minCPU) {
				my $max = int $maxCPU;
				my $min = int $minCPU;
				$numCPU = ($max + $min) / 2;
			} elsif ($maxCPU) {
				$numCPU = int $maxCPU;
				if ($numCPU > 1) {
					$numCPU -= 1;
				}
			} elsif ($minCPU) {
				$numCPU = int $minCPU;
				$numCPU += 1;
			}
		}
		print $OVFFD "\t\t\t"
			. '<rasd:VirtualQuantity>' . $numCPU
			. '</rasd:VirtualQuantity>' . "\n";
		if ($minCPU) {
			print $OVFFD "\t\t\t"
				. '<rasd:Limit>' . $minCPU . '</rasd:Limit>' . "\n";
		}
		if ($maxCPU) {
			print $OVFFD "\t\t\t"
				. '<rasd:Limit>' . $maxCPU . '</rasd:Limit>' . "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
			. "\t\t\t"
			. '<rasd:ResourceType>3</rasd:ResourceType>' . "\n"
			. "\t\t" . '</Item>' . "\n";
		$instID += 1;
	}
	# Memory setup
	my $maxMem = $vmdata -> getMaxMemory();
	my $minMem = $vmdata -> getMinMemory();
	my $memory = $vmdata -> getMemory();
	if ($maxMem || $minMem || $memory) {
		print $OVFFD "\t\t" . '<Item>' . "\n"
			. "\t\t\t"
			. '<rasd:AllocationUnits>MB</rasd:AllocationUnits>' . "\n"
			. "\t\t\t"
			. '<rasd:Description>Memory Size</rasd:Description>' . "\n";
		if (! $memory) {
			if ($maxMem && $minMem) {
				my $max = int $maxMem;
				my $min = int $minMem;
				$memory = ($maxMem + $minMem) / 2;
			} elsif ($maxMem) {
				$memory = int $maxMem;
				if ($memory > 512) {
					$memory -= 512;
				}
			} elsif ($minMem) {
				$memory = int $minMem;
				$memory += 512;
			}
		}
		print $OVFFD "\t\t\t"
			. '<rasd:ElementName>' . $memory
			. 'MB Memory</rasd:ElementName>' . "\n"
			. "\t\t\t"
			. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n";
		if ($minMem) {
			print $OVFFD "\t\t\t"
				. '<rasd:Limit>' . $minMem . '</rasd:Limit>' . "\n";
		}
		if ($maxMem) {
			print $OVFFD "\t\t\t"
				. '<rasd:Limit>' . $maxMem . '</rasd:Limit>' . "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:ResourceType>4</rasd:ResourceType>' . "\n"
			. "\t\t\t"
			. '<rasd:VirtualQuantity>' . $memory
			. '</rasd:VirtualQuantity>' . "\n"
			. "\t\t" . '</Item>' . "\n";
		$instID += 1;
	}
	# Disk controller
	my $controller = $vmdata -> getSystemDiskController();
	my $controllerID = $instID;
	if ($controller) {
		my $rType;
		if ($controller eq 'ide') {
			$rType = 5;
		} else {
			$rType = 6;
		}
		print $OVFFD "\t\t" . '<Item>' . "\n"
		. "\t\t\t"
		. '<rasd:Description>System disk controller</rasd:Description>'
		. "\n"
		. "\t\t\t"
		. '<rasd:ElementName>' . $controller . 'Controller'
		. '</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>' . $rType . '</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
		$instID += 1;
	}
	# Connect the system disk to the controller
	my $pAddress = 0;
	if ($controller) {
		print $OVFFD "\t\t" . '<Item>' . "\n"
		. "\t\t\t"
		. '<rasd:AddressOnParent>' . $pAddress
		. '</rasd:AddressOnParent>' . "\n"
		. "\t\t\t"
		. '<rasd:ElementName>disk1</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:Parent>' . $controllerID . '</rasd:Parent>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>17</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
		$pAddress += 1;
		$instID += 1;
	}
	# DVD
	my $dvdController = $vmdata -> getDVDController();
	if ($dvdController) {
		my $dvdContID = $controllerID;
		if ($controller && $dvdController ne $controller) {
			my $rType;
			if ($dvdController eq 'ide') {
				$rType = 5;
			} else {
				$rType = 6;
			}
			print $OVFFD "\t\t" . '<Item>' . "\n"
				. "\t\t\t"
				. '<rasd:Description>DVD controller</rasd:Description>'
				. "\n"
				. "\t\t\t"
				. '<rasd:ElementName>DVDController' . $dvdController
				. '</rasd:ElementName>' . "\n"
				. "\t\t\t"
				. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
				. "\t\t\t"
				. '<rasd:ResourceType>' . $rType . '</rasd:ResourceType>'
				. "\n"
				. "\t\t" . '</Item>' . "\n";
			$dvdContID = $instID;
			$instID += 1;
		}
		print $OVFFD "\t\t" . '<Item ovf:required="false">' . "\n"
		. "\t\t\t"
		. '<rasd:AddressOnParent>' . $pAddress
		. '</rasd:AddressOnParent>' . "\n"
		. "\t\t\t"
		. '<rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>'
		. "\n"
		. "\t\t\t"
		. '<rasd:Description>DVD device</rasd:Description>' . "\n"
		. "\t\t\t"
		. '<rasd:ElementName>DVDdrive</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:Parent>' . $dvdContID . '</rasd:Parent>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>16</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
		$pAddress += 1;
		$instID += 1;
	}
	# Network
	for my $id (@nicIDs) {
		my $iFace = $vmdata -> getNICInterface($id);
		my $mac = $vmdata -> getNICMAC($id);
		print $OVFFD "\t\t" . '<Item>' . "\n";
		if ($mac) {
			print $OVFFD "\t\t\t"
				. '<rasd:Address>' . $mac . '</rasd:Address>'. "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:AddressOnParent>' . $pAddress
			. '</rasd:AddressOnParent>' . "\n"
			. "\t\t\t"
			. '<rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>'
			. "\n";
		my $mode = $vmdata -> getNICMode($id);
		print $OVFFD "\t\t\t"
			. '<rasd:Connection>' . $mode . '</rasd:Connection>' . "\n"
			. "\t\t\t"
			. '<rasd:Description>Network adapter</rasd:Description>' . "\n"
			. "\t\t\t"
			. '<rasd:ElementName>ethernet' . $iFace
			. '</rasd:ElementName>' . "\n"
			. "\t\t\t"
			. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n";
		my $driver = $vmdata -> getNICDriver($id);
		if ($driver) {
			print $OVFFD "\t\t\t"
			. '<rasd:ResourceSubType>' . $driver . '</rasd:ResourceSubType>'
			. "\n";
		}
		print $OVFFD "\t\t\t"
			. '<rasd:ResourceType>10</rasd:ResourceType>' . "\n"
			. "\t\t" . '</Item>' . "\n";
		$pAddress += 1;
		$instID += 1;
	}
	# Video section
	print $OVFFD "\t\t" . '<Item ovf:required="false">' . "\n"
		. "\t\t\t"
		. '<rasd:AutomaticAllocation>false</rasd:AutomaticAllocation>'
		. "\n"
		. "\t\t\t"
		. '<rasd:ElementName>video</rasd:ElementName>' . "\n"
		. "\t\t\t"
		. '<rasd:InstanceID>' . $instID . '</rasd:InstanceID>' . "\n"
		. "\t\t\t"
		. '<rasd:ResourceType>24</rasd:ResourceType>' . "\n"
		. "\t\t" . '</Item>' . "\n";
	$pAddress += 1;
	print $OVFFD "\t" . '</VirtualHardwareSection>' . "\n"
		. '</VirtualSystem>' ."\n";
	#==========================================
	# close envelope
	#------------------------------------------
	print $OVFFD '</Envelope>';
	$OVFFD -> close();
	#==========================================
	# create manifest file
	#------------------------------------------
	my $mf = $ovf;
	$mf =~ s/\.ovf$/\.mf/;
	my $MFFD = FileHandle -> new();
	if (! $MFFD -> open (">$mf")) {
		$kiwi -> error ("Couldn't create manifest file: $!");
		$kiwi -> failed ();
		return;
	}
	my $base_image = basename $this->{image};
	my $base_config= basename $ovf;
	my $ovfsha1   = qxx ("sha1sum $ovf | cut -f1 -d ' ' 2>&1");
	my $imagesha1 = qxx ("sha1sum $this->{image} | cut -f1 -d ' ' 2>&1");
	print $MFFD "SHA1($base_config)= $ovfsha1"."\n";
	print $MFFD "SHA1($base_image)= $imagesha1"."\n";
	$MFFD -> close();
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
# createNetGUID
#------------------------------------------
sub createNetGUID {
	# /.../
	# Convert a string in the expected format, into 16 bytes,
	# emulating .Net's Guid constructor
	# ----
	my $this = shift;
	my $id   = shift;
	my $hx   = '[0-9a-f]';
	if ($id !~ /^($hx{8})-($hx{4})-($hx{4})-($hx{4})-($hx{12})$/i) {
		return;
	}
	my @parts = split (/-/,$id);
	#==========================================
	# pack into signed long 4 byte
	#------------------------------------------
	my $p1 = $parts[0];
	$p1 = pack   'H*', $p1;
	$p1 = unpack 'l>', $p1;
	$p1 = pack   'l' , $p1;
	#==========================================
	# pack into unsigned short 2 byte
	#------------------------------------------
	my $p2 = $parts[1];
	$p2 = pack   'H*', $p2;
	$p2 = unpack 'S>', $p2;
	$p2 = pack   'S' , $p2;
	#==========================================
	# pack into unsigned short 2 byte
	#------------------------------------------
	my $p3 = $parts[2];
	$p3 = pack   'H*', $p3;
	$p3 = unpack 'S>', $p3;
	$p3 = pack   'S' , $p3;
	#==========================================
	# pack into hex string (high nybble first)
	#------------------------------------------
	my $p4 = $parts[3];
	my $p5 = $parts[4];
	$p4 = pack   'H*', $p4;
	$p5 = pack   'H*', $p5;
	#==========================================
	# concat result and return
	#------------------------------------------
	my $guid = $p1.$p2.$p3.$p4.$p5;
	return $guid;
}

#==========================================
# writeVHDTag
#------------------------------------------
sub writeVHDTag {
	# /.../
	# Azure service uses a tag injected into the disk
	# image to identify the OS. The tag is 512B long,
	# starting with a GUID, and is placed at a 16K offset
	# from the start of the disk image.
	#
	# +------------------------------+
	# | jump       | GUID(16B)000... |
	# +------------------------------|
	# | 16K offset | TAG (512B)      |
	# +------------+-----------------+
	#
	# Fixed-format VHD
	# ----
	my $this   = shift;
	my $file   = shift;
	my $tag    = shift;
	my $kiwi   = $this->{kiwi};
	my $guid   = $this->createNetGUID ($tag);
	my $buffer = '';
	my $null_fh;
	my $done;
	#==========================================
	# check result of guid format
	#------------------------------------------
	if (! $guid) {
		$kiwi -> failed ();
		$kiwi -> error  ("VHD Tag: failed to convert tag: $tag");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# open target file
	#------------------------------------------
	my $FD = FileHandle -> new();
	if (! $FD -> open("+<$file")) {
		$kiwi -> failed ();
		$kiwi -> error  ("VHD Tag: failed to open file: $file: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# read in an empty buffer
	#------------------------------------------
	if (! sysopen ($null_fh,"/dev/zero",O_RDONLY) ) {
		$kiwi -> error  ("VHD Tag: Cannot open /dev/zero: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# seek to 16k offset and zero out 512 byte
	#------------------------------------------
	sysread ($null_fh,$buffer, 512); close ($null_fh);
	seek $FD,16384,0;
	$done = syswrite ($FD,$buffer);
	if ((! $done) || ($done != 512)) {
		$kiwi -> failed ();
		if ($done) {
			$kiwi -> error ("VHD Tag: only $done bytes cleaned");
		} else {
			$kiwi -> error ("VHD Tag: syswrite to $file failed: $!");
		}
		$kiwi -> failed ();
		seek $FD,0,2;
		$FD -> close();
		return;
	}
	#==========================================
	# seek back to 16k offset
	#------------------------------------------
	seek $FD,16384,0;
	#==========================================
	# write 16 bytes GUID
	#------------------------------------------
	$done = syswrite ($FD,$guid,16);
	if ((! $done) || ($done != 16)) {
		$kiwi -> failed ();
		if ($done) {
			$kiwi -> error ("VHD Tag: only $done bytes written");
		} else {
			$kiwi -> error ("VHD Tag: syswrite to $file failed: $!");
		}
		$kiwi -> failed ();
		seek $FD,0,2;
		$FD -> close();
		return;
	}
	#==========================================
	# seek end and close
	#------------------------------------------
	seek $FD,0,2;
	$FD -> close();
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
	return;
}
#==========================================
# __copy_origin
#------------------------------------------
sub __copy_origin {
	my $this = shift;
	my $file = shift;
	if (-f "$file.orig") {
		qxx ("cp $file.orig $file 2>&1");
	} else {
		qxx ("cp $file $file.orig 2>&1");
	}
	return;
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
	return;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this   = shift;
	my $tmpdir = $this->{tmpdir};
	if (($tmpdir) && (-d $tmpdir)) {
		qxx ("rm -rf $tmpdir 2>&1");
	}
	return $this;
}

1;

# vim: set noexpandtab:
