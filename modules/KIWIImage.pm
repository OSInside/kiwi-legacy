#================
# FILE          : KIWIImage.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create a logical
#               : extend, an image file based on a Linux
#               : filesystem
#               : 
#               :
# STATUS        : Development
#----------------
package KIWIImage;
#==========================================
# Modules
#------------------------------------------
use strict;
use KIWILog;
use Math::BigFloat;

#==========================================
# Private
#------------------------------------------
my $imageTreeReadOnly;
my $imageTree;
my $imageDest;
my $imageStrip;
my $baseSystem;
my $kiwi;
my $xml;
my $arch;

#==========================================
# Constructor
#------------------------------------------
sub new {
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi = shift;
	$xml  = shift;
	$imageTree  = shift;
	$imageDest  = shift;
	$imageStrip = shift;
	$baseSystem = shift;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! defined $xml) {
		$kiwi -> error ("No XML reference specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $baseSystem) {
		$kiwi -> error ("No base system path specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $imageTree) {
		$kiwi -> error  ("No image tree specified");
		$kiwi -> failed ();
		return undef;
	}
	if (! -f "$imageTree/etc/ImageVersion") {
		$kiwi -> error  ("Validation of $imageTree failed");
		$kiwi -> failed ();
		return undef;
	}
	if (! -d $imageDest) {
		$kiwi -> error  ("No valid destdir: $imageDest");
		$kiwi -> failed ();
		return undef;
	}
	$arch = qx ( arch ); chomp ( $arch );
	$arch = ".$arch";
	return $this;
}

#==========================================
# stripImage
#------------------------------------------
sub stripImage {
	# ...
	# remove symbols from shared objects and binaries
	# using strip -p
	# ---
	my $this = shift;
	$kiwi -> info ("Stripping shared objects/executables...");
	my @list = qx (find $imageTree -type f -perm -755);
	foreach my $file (@list) {
		chomp $file;
		my $data = qx (file "$file");
		chomp $data;
		if ($data =~ /not stripped/) {
		if ($data =~ /shared object/) {
			qx ( strip -p $file 2>&1 );
		}
		if ($data =~ /executable/) {
			qx ( strip -p $file 2>&1 );
		}
		}
	}
	$kiwi -> done ();
	return $this;
}

#==========================================
# createImageEXT2
#------------------------------------------
sub createImageEXT2 {
	# ...
	# Create EXT2 image from source tree
	# ---
	my $this    = shift;
	my $journal = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! setupEXT2 ( $name,$imageTree,$journal )) {
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! postImage ($name)) {
		return undef;
	}
	return $this;
}

#==========================================
# createImageEXT3
#------------------------------------------
sub createImageEXT3 {
	# ...
	# create journaled EXT3 image from source tree
	# ---
	createImageEXT2 ("journaled");
}

#==========================================
# createImageReiserFS
#------------------------------------------
sub createImageReiserFS {
	# ...
	# create journaled ReiserFS image from source tree
	# ---
	my $this = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! setupReiser ( $name )) {
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! postImage ($name)) {
		return undef;
	}
	return $this;
}

#==========================================
# createImageSquashFS
#------------------------------------------
sub createImageSquashFS {
	# ...
	# create squashfs image from source tree
	# ---
	my $this = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ("haveExtend");
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! setupSquashFS ( $name )) {
		return undef;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! buildMD5Sum ($name)) {
		return undef;
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if ($xml->getCompressed()) {
	if (! compressImage ($name)) {
		return undef;
	}
	}

	$kiwi -> info ("Creating boot configuration...");
	if (! writeImageConfig ($name)) {
		$kiwi -> failed ();
		return undef;
	}
	return $this;
}

#==========================================
# createImageCPIO
#------------------------------------------
sub createImageCPIO {
	# ...
	# create cpio archive from the image source tree
	# The kernel will use this archive and mount it as
	# cpio archive
	# ---
	my $this = shift;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = preImage ("haveExtend");
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	my @cpio = ("--create", "--format=newc", "--quiet");
	my $tree = $imageTree;
	my $dest = $imageDest."/".$name.".gz";
	my $data = qx (cd $tree && find . | cpio @cpio | gzip > $dest);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create cpio archive");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! buildMD5Sum ($name.".gz")) {
		return undef;
	}
	return $this;
}

#==========================================
# createImageUSB
#------------------------------------------
sub createImageUSB {
	# ...
	# Create all images needed to use it on an USB stick.
	# This includes the system image and the boot image appropriate
	# for the system image. The boot image description must exist
	# in /usr/share/kiwi/image. The process will create all images
	# but will _not_ deploy the images on the stick. To do this
	# call kiwi with the --bootstick option after the image creation
	# process is finished
	#
	# Note: Virtual machine images requires the same steps than USB
	# images. The only difference is that there is no real disk
	# (USB-storage) the images are deployed to. Because of this we
	# are using the same code for creating the system and boot image
	# in the createImageVMX() method
	# ---
	#==========================================
	# Create USB boot and system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my $text = shift;
	my $type;
	my $boot;
	my %result;
	my $ok;
	if ($para =~ /(.*):(.*)/) {
		$type = $1;
		$boot = $2;
	}
	if (! defined $text) {
		$text = "USB";
	}
	if ((! defined $type) || (! defined $boot)) {
		$kiwi -> error  ("Invalid $text type specified: $para");
		$kiwi -> failed ();
		return undef;
	}
	SWITCH: for ($type) {
		/^ext2/       && do {
			$ok = createImageEXT2 ();
			last SWITCH;
		};
		/^ext3/       && do {
			$ok = createImageEXT3 ();
			last SWITCH;
		};
		/^reiserfs/   && do {
			$ok = createImageReiserFS ();
			last SWITCH;
		};
		/^squashfs/   && do {
			$ok = createImageSquashFS ();
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported $text type: $type");
		$kiwi -> failed ();
		return undef;
	};
	if (! $ok) {
		return undef;
	}
	$result{systemImage} = $main::ImageName;
	#==========================================
	# Prepare and Create USB boot image
	#------------------------------------------
	$kiwi -> info ("Creating $text boot image: $boot...\n");
	my $Prepare = $imageTree."/image";
	my $xml = new KIWIXML ( $kiwi,$Prepare );
	if (! defined $xml) {
		return undef;
	}
	$main::ForeignRepo{xmlnode} = $xml -> getForeignNodeList();
	$main::ForeignRepo{prepare} = $Prepare;
	$main::Survive  = "yes";
	$main::RootTree = "/tmp/kiwi-".$text."boot-$$";
	$main::Prepare  = $main::System."/".$boot;
	$main::Create   = $main::RootTree;
	if (! defined main::main()) {
		$main::Survive = "default";
		if (! -d $main::RootTree.$baseSystem) {
			qx (rm -rf $main::RootTree);
		}
		return undef;
	}
	if (! -d $main::RootTree.$baseSystem) {
		qx (rm -rf $main::RootTree);
	}
	$result{bootImage} = $main::ImageName;
	if ($text eq "USB") {
		$main::Survive = "default";
	}
	return \%result;
}

#==========================================
# createImageVMX
#------------------------------------------
sub createImageVMX {
	# ...
	# Create virtual machine disks usable for QEMU and VMware virtual
	# machines. The process will create the system image and the
	# appropriate vmx boot image plus a .qemu and a .vmdk image usable
	# in qemu or vmware player. The boot image description must exist
	# in /usr/share/kiwi/image.
	#
	# NOTE: Because the first steps of creating
	# a virtual machine image are the same as creating a usb stick image
	# we make use of the usb code above to create the system and boot
	# image
	# ---
	#==========================================
	# Create VMX boot and system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my $name = createImageUSB ($this,$para,"VMX");
	if (! defined $name) {
		return undef;
	}
	undef $main::Prepare;
	undef $main::Create;
	#==========================================
	# Create .qemu and .vmdk VM images
	#------------------------------------------
	$main::BootVMDisk   = $main::Destination."/".$name->{bootImage}.".gz";
	$main::BootVMSystem = $main::Destination."/".$name->{systemImage};
	$main::BootVMSize   = $main::BootVMSize;
	if (! defined main::main()) {
		$main::Survive = "default";
		return undef;
	}
	$main::Survive = "default";
	return $this;
}

#==========================================
# createImageXen
#------------------------------------------
sub createImageXen {
	# ...
	# Create a para virtualized image usable in Xen. The process
	# will create the system image and the appropriate xen initrd
	# and kernel plus a Xen configuration to be able to run the
	# image within Xen
	#
	# NOTE: Because the first steps of creating
	# a Xen image are the same as creating a usb stick image
	# we make use of the usb code above to create the system and boot
	# image
	# ---
	#==========================================
	# Create Xen boot and system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my %xenc = $xml -> getPackageAttributes ("xen");
	my $name = createImageUSB ($this,$para,"Xen");
	if (! defined $name) {
		return undef;
	}
	undef $main::Prepare;
	undef $main::Create;
	#==========================================
	# Create image xenconfig
	#------------------------------------------
	if (! buildXenConfig ($main::Destination,$name,\%xenc)) {
		$main::Survive = "default";
		return undef;
	}
	$main::Survive = "default";
	return $this;
}

#==========================================
# createImageLiveCD
#------------------------------------------
sub createImageLiveCD {
	# ...
	# Create a live filesystem on CD using the isoboot boot image
	# 1) split physical extend into two parts:
	#    part1 -> writable
	#    part2 -> readonly
	# 2) Setup an ext2 based image for the RW part and a squashfs
	#    image if it should be compressed. If no compression is used
	#    all RO data will be directly on CD/DVD as part of the ISO
	#    filesystem
	# 3) Prepare and Create the given iso <$boot> boot image
	# 4) Setup the CD structure and copy all files
	#    including the syslinux isolinux data
	# 5) Create the iso image using isolinux.sh
	# ---
	my $this = shift;
	my $para = shift;
	my $error;
	my $data;
	my $code;
	#==========================================
	# Get boot image name and compressed flag
	#------------------------------------------
	my @plist = split (/,/,$para);
	my $boot  = $plist[0];
	my $gzip  = $plist[1];
	if (! defined $boot) {
		$kiwi -> failed ();
		$kiwi -> error  ("No boot image name specified");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $namecd = buildImageName (";");
	my $namerw = buildImageName ();
	my $namero = buildImageName ("-","-read-only");
	if (! defined $namerw) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! setupLogicalExtend ("quiet")) {
		return undef;
	}
	#==========================================
	# split physical extend into RW / RO part
	#------------------------------------------
	$imageTreeReadOnly = $imageTree;
	$imageTreeReadOnly =~ s/\/+$//;
	$imageTreeReadOnly.= "-read-only/";
	if (! -d $imageTreeReadOnly) {
		$kiwi -> info ("Creating read only image part");
		if (! mkdir $imageTreeReadOnly) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create ro directory: $error");
			$kiwi -> failed ();
			return undef;
		}
		my @rodirs = qw (bin boot lib opt sbin usr);
		foreach my $dir (@rodirs) {
			$data = qx (mv $imageTree/$dir $imageTreeReadOnly 2>&1);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't setup ro directory: $data");
				$kiwi -> failed ();
				return undef;
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Count disk space for RW extend
	#------------------------------------------
	$kiwi -> info ("Computing disk space...");
	my ($mbytesreal,$mbytesrw,$xmlsize) = getSize ($imageTree);
	$kiwi -> done ();

	#==========================================
	# Create RW logical extend
	#------------------------------------------
	$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
	if (! buildLogicalExtend ($namerw,$mbytesrw."M")) {
		restoreSplitExtend ();
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# Create EXT2 filesystem on RW extend
	#------------------------------------------
	if (! setupEXT2 ( $namerw,$imageTree )) {
		restoreSplitExtend ();
		return undef;
	}
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	my $extend = mountLogicalExtend ($namerw);
	if (! defined $extend) {
		restoreSplitExtend ();
		return undef;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	if (! installLogicalExtend ($extend,$imageTree)) {
		restoreSplitExtend ();
		return undef;
	}
	cleanMount();
	#==========================================
	# Create compressed filesystem on RO extend
	#------------------------------------------
	if (defined $gzip) {
		$kiwi -> info ("Creating compressed read only filesystem...");
		if (! setupSquashFS ( $namero,$imageTreeReadOnly )) {
			restoreSplitExtend ();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Checking RW file system
	#------------------------------------------
	qx (/sbin/e2fsck -f -y $imageDest/$namerw 2>&1);

	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! buildMD5Sum ($namerw)) {
		restoreSplitExtend ();
		return undef;
	}
	#==========================================
	# Restoring physical extend
	#------------------------------------------
	if (! restoreSplitExtend ()) {
		return undef;
	}
	#==========================================
	# recreate a copy of the read-only data
	#------------------------------------------	
	if ((! -d $imageTreeReadOnly) && (! defined $gzip)) {
		$kiwi -> info ("Creating read only reference...");
		if (! mkdir $imageTreeReadOnly) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create ro directory: $error");
			$kiwi -> failed ();
			return undef;
		}
		my @rodirs = qw (bin boot lib opt sbin usr);
		foreach my $dir (@rodirs) {
			$data = qx (cp -a $imageTree/$dir $imageTreeReadOnly 2>&1);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't setup ro directory: $data");
				$kiwi -> failed ();
				return undef;
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Prepare and Create ISO boot image
	#------------------------------------------
	$kiwi -> info ("Creating ISO boot image: $boot...\n");
	my $Prepare = $imageTree."/image";
	my $xml = new KIWIXML ( $kiwi,$Prepare );
	if (! defined $xml) {
		qx (rm -rf $imageTreeReadOnly);
		return undef;
	}
	$main::ForeignRepo{xmlnode} = $xml -> getForeignNodeList();
	$main::ForeignRepo{prepare} = $Prepare;
	$main::Survive  = "yes";
	$main::RootTree = "/tmp/kiwi-cdboot-$$";
	$main::Prepare  = $main::System."/".$boot;
	$main::Create   = $main::RootTree;
	if (! defined main::main()) {
		$main::Survive = "default";
		if (! -d $main::RootTree.$baseSystem) {
			qx (rm -rf $main::RootTree);
			qx (rm -rf $imageTreeReadOnly);
		}
		return undef;
	}
	$main::Survive = "default";
	undef %main::ForeignRepo;
	#==========================================
	# Create CD ISO image
	#------------------------------------------
	$kiwi -> info ("Creating CD filesystem");
	qx (mkdir -p $main::RootTree/CD/boot);
	$kiwi -> done ();

	#==========================================
	# Installing second stage images
	#------------------------------------------
	$kiwi -> info ("Moving CD image data into boot structure");
	qx (mv $imageDest/$namerw.md5 $main::RootTree/CD);
	qx (mv $imageDest/$namerw $main::RootTree/CD);
	if (defined $gzip) {
		qx (mv $imageDest/$namero $main::RootTree/CD);
	} else {
		qx (mkdir -p $main::RootTree/CD/read-only-system);
		qx (mv $imageTreeReadOnly/* $main::RootTree/CD/read-only-system);
		rmdir $imageTreeReadOnly;
	}
	$kiwi -> done ();

	#==========================================
	# copy boot files for isolinux
	#------------------------------------------
	my $CD  = "$main::Prepare/cdboot";
	my $gfx = $imageTree."/image/loader";
	my $xml = new KIWIXML ( $kiwi,$main::Prepare );
	my $iso = $xml -> getImageName();
	my $isoarch = qx (arch); chomp $isoarch;
	if ($isoarch =~ /i.86/) {
		$isoarch = "i386";
	}
	if (! -d $gfx) {
		$kiwi -> error  ("Couldn't open directory $gfx: $!");
		if (! -d $main::RootTree.$baseSystem) {
			qx (rm -rf $main::RootTree);
		}
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# copy kernel and initrd
	#------------------------------------------
	$kiwi -> info ("Copying boot image and kernel [$isoarch]");
	my $destination = "$main::RootTree/CD/boot/$isoarch/loader";
	qx (mkdir -p $destination);
	qx (cp $imageDest/$iso*$arch*.gz $destination/initrd);
	qx (cp $imageDest/$iso*$arch*.kernel* $destination/linux);
	$kiwi -> done ();

	#==========================================
	# copy base CD files
	#------------------------------------------
	$kiwi -> info ("Setting up isolinux boot CD [$isoarch]");
	qx (cp $gfx/* $destination);
	qx (cp $CD/isolinux.cfg $destination);
	qx (cp $CD/isolinux.msg $destination);
	$kiwi -> done ();

	#==========================================
	# remove original kernel and initrd
	#------------------------------------------
	qx (rm -f $imageDest/$iso*.*]);

	#==========================================
	# Create boot configuration
	#------------------------------------------
	if (! open (FD,">$main::RootTree/CD/config.isoclient")) {
		$kiwi -> error  ("Couldn't create image boot configuration");
		$kiwi -> failed ();
		return undef;
	}
	print FD "IMAGE=/dev/ram1;$namecd\n";
	close FD;

	#==========================================
	# create ISO image
	#------------------------------------------
	$kiwi -> info ("Calling mkisofs...");
	my $name = $imageDest."/".$namerw.".iso";
	my $data = qx ($CD/isolinux.sh $main::RootTree/CD $name 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create ISO image: $data");
		$kiwi -> failed ();
		return undef;
	}
	if (! -d $main::RootTree.$baseSystem) {
		qx (rm -rf $main::RootTree);
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# createImageSplit
#------------------------------------------
sub createImageSplit {
	my $this = shift;
	my $type = shift;
	my $FSTypeRW;
	my $FSTypeRO;
	my $error;
	my $ok;
	#==========================================
	# Get filesystem info for split image
	#------------------------------------------
	if ($type =~ /(.*),(.*)/) {
		$FSTypeRW = $1;
		$FSTypeRO = $2;
	} else {
		return undef;
	}
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $namerw = buildImageName ();
	my $namero = buildImageName ("-","-read-only");
	if (! defined $namerw) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! setupLogicalExtend ("quiet")) {
		return undef;
	}
	#==========================================
	# split physical extend into RW / RO part
	#------------------------------------------
	$imageTreeReadOnly = $imageTree;
	$imageTreeReadOnly =~ s/\/+$//;
	$imageTreeReadOnly.= "-read-only/";
	if (! -d $imageTreeReadOnly) {
		$kiwi -> info ("Creating read only image part");
		if (! mkdir $imageTreeReadOnly) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create ro directory: $error");
			$kiwi -> failed ();
			return undef;
		} 
		my @rodirs = qw (bin boot lib opt sbin usr);
		foreach my $dir (@rodirs) {
			my $data = qx (mv $imageTree/$dir $imageTreeReadOnly 2>&1);
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't setup ro directory: $data");
				$kiwi -> failed ();
				return undef;
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Count disk space for extends
	#------------------------------------------
	$kiwi -> info ("Computing disk space...");
	my ($mbytesreal,$mbytesrw,$xmlsize) = getSize ($imageTree);
	my ($mbytesreal,$mbytesro,$xmlsize) = getSize ($imageTreeReadOnly);
	$kiwi -> done ();

	#==========================================
	# Create RW logical extend
	#------------------------------------------
	$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
	if (! buildLogicalExtend ($namerw,$mbytesrw."M")) {
		restoreSplitExtend ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Create filesystem on RW extend
	#------------------------------------------
	SWITCH: for ($FSTypeRW) {
		/ext2/       && do {
			$ok = setupEXT2 ( $namerw,$imageTree );
			last SWITCH;
		};
		/ext3/       && do {
			$ok = setupEXT2 ( $namerw,$imageTree,"journaled" );
			last SWITCH;
		};
		/reiserfs/   && do {
			$ok = setupReiser ( $namerw );
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $FSTypeRW");
		$kiwi -> failed ();
		restoreSplitExtend ();
		return undef;
	}
	if (! $ok) {
		restoreSplitExtend ();
		return undef;
	}
	#==========================================
	# Create RO logical extend
	#------------------------------------------
	$kiwi -> info ("Image RO part requires $mbytesro MB of disk space");
	if (! buildLogicalExtend ($namero,$mbytesro."M")) {
		restoreSplitExtend ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Create filesystem on RO extend
	#------------------------------------------
	SWITCH: for ($FSTypeRO) {
		/ext2/       && do {
			$ok = setupEXT2 ( $namero,$imageTreeReadOnly );
			last SWITCH;
		};
		/ext3/       && do {
			$ok = setupEXT2 ( $namero,$imageTreeReadOnly,"journaled" );
			last SWITCH;
		};
		/reiserfs/   && do {
			$ok = setupReiser ( $namero );
			last SWITCH;
		};
		/cramfs/     && do {
			$ok = setupCramFS ( $namero,$imageTreeReadOnly );
			last SWITCH;
		};
		/squashfs/   && do {
			$ok = setupSquashFS ( $namero,$imageTreeReadOnly );
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $FSTypeRO");
		$kiwi -> failed ();
		restoreSplitExtend ();
		return undef;
	}
	if (! $ok) {
		restoreSplitExtend ();
		return undef;
	}
	#==========================================
	# Install logical extends
	#------------------------------------------
	foreach my $name ($namerw,$namero) {
		#==========================================
		# select physical extend
		#------------------------------------------
		my $source;
		my $type;
		if ($name eq $namerw) {
			$source = $imageTree;
			$type = $FSTypeRW;
		} else {
			$source = $imageTreeReadOnly;
			$type = $FSTypeRO;
		}
		if ($type ne "cramfs") {
			#==========================================
			# mount logical extend for data transfer
			#------------------------------------------
			my $extend = mountLogicalExtend ($name);
			if (! defined $extend) {
				restoreSplitExtend ();
				return undef;
			}
			#==========================================
			# copy physical to logical
			#------------------------------------------
			if (! installLogicalExtend ($extend,$source)) {
				restoreSplitExtend ();
				return undef;
			}
			cleanMount();
		}
		#==========================================
		# Checking file system
		#------------------------------------------
		$kiwi -> info ("Checking file system: $type...");
		SWITCH: for ($type) {
			/ext2/       && do {
				qx (/sbin/e2fsck -f -y $imageDest/$name 2>&1);
				$kiwi -> done();
				last SWITCH;
			};
			/ext3/       && do {
				qx (/sbin/fsck.ext3 -f -y $imageDest/$name 2>&1);
				$kiwi -> done();
				last SWITCH;
			};
			/reiserfs/   && do {
				qx (/sbin/reiserfsck -y $imageDest/$name 2>&1);
				$kiwi -> done();
				last SWITCH;
			};
			/cramfs/     && do {
				qx (/sbin/fsck.cramfs -v $imageDest/$name 2>&1);
				$kiwi -> done();
				last SWITCH;
			};
			/squashfs/   && do {
				$kiwi -> done ();
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type");
			$kiwi -> failed ();
			restoreSplitExtend ();
			return undef;
		}
		#==========================================
		# Create image md5sum
		#------------------------------------------
		if (! buildMD5Sum ($name)) {
			restoreSplitExtend ();
			return undef;
		}
	}
	#==========================================
	# Restoring physical extend
	#------------------------------------------
	if (! restoreSplitExtend ()) {
		return undef;
	}
	return $this;
}

#==========================================
# getBlocks
#------------------------------------------
sub getBlocks {
	# ...
	# calculate the block size and number of blocks used
	# to create a <size> bytes long image. Return list
	# (bs,count)
	# ---
	my $size = $_[0];
	my $bigimage   = 1048576; # 1M
	my $smallimage = 8192;    # 8K
	my $number;
	my $suffix;
	if ($size =~ /(\d+)(.*)/) {
		$number = $1;
		$suffix = $2;
		if ($suffix eq "") {
			return (($size,1));
		} else {
			SWITCH: for ($suffix) { 
			/K/i   && do {
				$number *= 1024;
			last SWITCH;
			}; 
			/M/i   && do {
				$number *= 1024 * 1024;
			last SWITCH;
			}; 
			/G/i   && do {
				$number *= 1024 * 1024 * 1024;
			last SWITCH;
			};
			# default...
			return (($size,1));
			}
		}
	} else {
		return (($size,1));
	}
	my $count;
	if ($number > 100 * 1024 * 1024) {
		# big image...
		$count = $number / $bigimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		return (($bigimage,$count));
	} else {
		# small image...
		$count = $number / $smallimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		return (($smallimage,$count));
	}
}

#==========================================
# preImage
#------------------------------------------
sub preImage {
	# ...
	# pre-stage preparation of a logical extend.
	# This method includes all common not filesystem
	# dependant tasks before the logical extend
	# has been created
	# ---
	my $haveExtend = shift;
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $name = buildImageName ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	if (! extractKernel ($name)) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! setupLogicalExtend ()) {
		return undef;
	}
	#==========================================
	# Create logical extend
	#------------------------------------------
	if (! defined $haveExtend) {
	if (! buildLogicalExtend ($name)) {
		return undef;
	}
	}
	return $name;
}

#==========================================
# writeImageConfig
#------------------------------------------
sub writeImageConfig {
	my $name = shift;
	my $configName = buildImageName() . ".config";
	my $device = $xml -> getImageDevice ();

	#==========================================
	# create .config for types which needs it
	#------------------------------------------
	if (defined $device) {
		if (! open (FD,">$imageDest/$configName")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create image boot configuration");
			$kiwi -> failed ();
			return undef;
		}
		my $namecd = buildImageName(";");
		print FD "IMAGE=${device}2;$namecd\n";
		print FD "DISK=${device}\n";
		#==========================================
		# PART information
		#------------------------------------------
		my @parts = $xml -> getPartitions ();
		if ((scalar @parts) > 0) {
			print FD "PART=";
			for my $href (@parts) {
				if ($href->{size} eq "image") {
					print FD int (((-s "$imageDest/$name") / 1024 / 1024) + .5);
				} else {
					print FD $href->{size};
				}

				if ($href -> {type} eq "swap") {
					print FD ";S;x,";
				} else {
					my $mountpoint = $href -> {mountpoint};
					print FD ";L;$mountpoint,";
				}
			}
			print FD "\n";
		}
		#==========================================
		# COMBINED_IMAGE information
		#------------------------------------------
		if ($xml -> getImageType () =~ /^split:(.*)/) {
			print FD "COMBINED_IMAGE=yes\n";
		}
		#==========================================
		# More to come...
		#------------------------------------------
		close FD;
	}
	return $configName;
}

#==========================================
# postImage
#------------------------------------------
sub postImage {
	# ...
	# post-stage preparation of a logical extend.
	# This method includes all common not filesystem
	# dependant tasks after the logical extend has
	# been created
	# ---
	my $name = shift;
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	my $extend = mountLogicalExtend ($name);
	if (! defined $extend) {
		return undef;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	if (! installLogicalExtend ($extend)) {
		return undef;
	}
	cleanMount();

	#==========================================
	# Check image file system
	#------------------------------------------
	$kiwi -> info ("Checking file system...");
	my $type = $xml->getImageType();
	SWITCH: for ($type) {
		#==========================================
		# Check EXT3 file system
		#------------------------------------------
		/ext3/i && do {
			qx (/sbin/fsck.ext3 -f -y $imageDest/$name 2>&1);
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT2 file system
		#------------------------------------------
		/ext2/i && do {
			qx (/sbin/e2fsck -f -y $imageDest/$name 2>&1);
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check ReiserFS file system
		#------------------------------------------
		/reiserfs/i && do {
			qx (/sbin/reiserfsck -y $imageDest/$name 2>&1);
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Unknown filesystem type
		#------------------------------------------
		$kiwi -> failed();
		$kiwi -> error ("Unsupported filesystem type: $type");
		$kiwi -> failed();
		return undef;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! buildMD5Sum ($name)) {
		return undef;
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if ($xml->getCompressed()) {
	if (! compressImage ($name)) {
		return undef;
	}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
	$kiwi -> info ("Creating boot configuration...");
	if (! writeImageConfig ($name)) {
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();	
	return $name;
}

#==========================================
# buildImageName
#------------------------------------------
sub buildImageName {
	my $separator = shift;
	my $extension = shift;
	if (! defined $separator) {
		$separator = "-";
	}
	my $name = $xml -> getImageName();
	my $iver = $xml -> getImageVersion();
	if (defined $extension) {
		$name = $name.$extension.$arch.$separator.$iver;
	} else {
		$name = $name.$arch.$separator.$iver;
	}
	chomp  $name;
	$main::ImageName = $name;
	return $name;
}

#==========================================
# buildLogicalExtend
#------------------------------------------
sub buildLogicalExtend {
	my $name = shift;
	my $size = shift;
	#==========================================
	# Calculate block size and number of blocks
	#------------------------------------------
	if (! defined $size) {
		$size = $xml -> getImageSize();
	}
	my @bsc  = getBlocks ( $size );
	my $bs   = $bsc[0];
	my $cnt  = $bsc[1];
	#==========================================
	# Create logical extend storage and FS
	#------------------------------------------
	unlink ("$imageDest/$name");
	my $data = qx (dd if=/dev/zero of=$imageDest/$name bs=$bs count=$cnt 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create logical extend");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return $name;
}

#==========================================
# installLogicalExtend
#------------------------------------------
sub installLogicalExtend {
	my $extend = shift;
	my $source = shift;
	if (! defined $source) {
		$source = $imageTree;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	my $name = qx (basename $source); chomp $name;
	$kiwi -> info ("Copying physical to logical [$name]...");
	my $data = qx (cp -a $source/* $extend 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ("No space left on device: $!");
		$kiwi -> failed ();
		cleanMount();
		return undef;
	}
	$kiwi -> done();
	return $extend;
}

#==========================================
# setupLogicalExtend
#------------------------------------------
sub setupLogicalExtend {
	my $quiet = shift;
	#==========================================
	# Call depmod
	#------------------------------------------
	my $depmod = "/sbin/depmod";
	my $systemMap = glob("$imageTree/boot/System.map*");
	if (defined $systemMap) {
		$kiwi -> info ("Calculating kernel module dependencies...");
		my $kernelVersion;
		if ($systemMap =~ /System.map-(.*)/) {
			$kernelVersion = $1;
		} else {
			$kiwi -> failed ();
			$kiwi -> info ("Could not determine kernel version");
			cleanMount ();
			return undef;
		}
		my $data = qx ( $depmod -F $systemMap -b $imageTree $kernelVersion );
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info ($data);
			cleanMount();
			return undef;
		}
		$kiwi -> done ();
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (-x "$imageTree/image/images.sh") {
		$kiwi -> info ("Calling image script: images.sh");
		my $data = qx ( chroot $imageTree /image/images.sh 2>&1 );
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			cleanMount();
			return undef;
		}
		qx ( rm -f $imageTree/image/images.sh );
		$kiwi -> done ();
	}
	#==========================================
	# Strip if specified
	#------------------------------------------
	if (defined $imageStrip) {
		stripImage();
	}
	#==========================================
	# Calculate needed space
	#------------------------------------------
	my ($mbytesreal,$mbytes,$xmlsize) = getSize ($imageTree);
	if (! defined $quiet) {
		$kiwi -> info ("Image requires $mbytesreal MB, got $xmlsize MB");
		$kiwi -> done ();
		$kiwi -> info ("Suggested Image size: $mbytes MB");
		$kiwi -> done ();
	}
	return $mbytes;
}

#==========================================
# mountLogicalExtend
#------------------------------------------
sub mountLogicalExtend {
	my $name = shift;
	my $opts = shift;
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	mkdir "$imageDest/mnt-$$";
	my $data = qx (mount $opts -oloop $imageDest/$name $imageDest/mnt-$$);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't mount image");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return "$imageDest/mnt-$$";
}

#==========================================
# extractKernel
#------------------------------------------
sub extractKernel {
	my $name = shift;
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	# This is done for boot images only. Which means
	# we will check for files named vmlinuz,vmlinux.gz.
	# These files are created from the kernel package
	# script which exists for boot images only
	# ---
	my $type = $xml->getImageType();
	SWITCH: for ($type) {
		/ext3/i     && do {
			return $name;
			last SWITCH;
		};
		/reiserfs/i && do {
			return $name;
			last SWITCH;
		};
		/iso:(.*)/i && do {
			return $name;
			last SWITCH;
		};
		/ext2/i && do {
			if ($name !~ /boot/) {
				return $name;
			}
			last SWITCH;
		};
		/squashfs/i && do {
			return $name;
			last SWITCH;
		};
	}
	if (-f "$imageTree/boot/vmlinuz") {
		$kiwi -> info ("Extracting kernel...");
		my $file = "$imageDest/$name.kernel";
		my $lx = '"^Linux version"';
		my $sp = '-f3 -d" "';
		qx (cp $imageTree/boot/vmlinuz $file);
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ("Failed to extract kernel: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $gzfile;
		if (-f "$imageTree/boot/vmlinux.gz") {
			$gzfile = "$imageTree/boot/vmlinux.gz";
		} elsif (-f "$imageTree/boot/xen.gz") {
			$gzfile = "$imageTree/boot/xen.gz";
		} else {
			$kiwi -> failed ();
			$kiwi -> info   ("Couldn't find compressed kernel");
			$kiwi -> failed ();
			return undef;
		}
		my $kernel = qx (gzip -dc $gzfile | strings | grep $lx | cut $sp);
		chomp $kernel;
		qx (mv $file $file.$kernel);
		if (-f "$imageTree/boot/xen.gz") {
			$file = "$imageDest/$name.kernel-xen";
			qx (cp $imageTree/boot/xen.gz $file);
			qx (mv $file $file.$kernel."gz");
		}
		$kiwi -> done();
	}
	return $name;
}

#==========================================
# setupEXT2
#------------------------------------------
sub setupEXT2 {
	my $name    = shift;
	my $tree    = shift;
	my $journal = shift;
	if (! defined $tree) {
		$tree = $imageTree;
	}
	my $fsopts;
	my $fileCount = int (qx (find $tree | wc -l));
	my $nodeCount = $fileCount * 2;
	if (defined $journal) {
		$fsopts = "-O dir_index -b 4096 -j -J size=4 -q -F -N $nodeCount";
	} else {  
		$fsopts = "-q -F -N $nodeCount";
	}
	my $data = qx (/sbin/mke2fs $fsopts $imageDest/$name 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create EXT2 filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return $name;
}

#==========================================
# setupReiser
#------------------------------------------
sub setupReiser {
	my $name = shift;
	my $data = qx (/sbin/mkreiserfs -q -f -b 4096 $imageDest/$name 2>&1);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create Reiser filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return $name;
}

#==========================================
# setupCramFS
#------------------------------------------
sub setupCramFS {
	my $name = shift;
	my $tree = shift;
	if (! defined $tree) {
		$tree = $imageTree;
	}
	my $data = qx (/sbin/mkfs.cramfs -v $tree $imageDest/$name 2>&1);
	my $code = $? >> 8; 
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create CRam filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	return $name;
}

#==========================================
# setupSquashFS
#------------------------------------------
sub setupSquashFS {
	my $name = shift;
	my $tree = shift;
	if (! defined $tree) {
		$tree = $imageTree;
	}
	unlink ("$imageDest/$name");
	my $data = qx (/usr/bin/mksquashfs $tree $imageDest/$name -noI 2>&1);
	my $code = $? >> 8; 
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create squashfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	qx (chmod 644 $imageDest/$name);
	return $name;
}

#==========================================
# buildXenConfig
#------------------------------------------
sub buildXenConfig {
	my $dest   = shift;
	my $name   = shift;
	my $xenref = shift;
	my $file   = $dest."/".$name->{systemImage}.".xenconfig";
	my $initrd = $dest."/".$name->{bootImage}.".gz";
	my $kernel = $dest."/".$name->{bootImage}.".kernel";
	$kernel    = glob ("$kernel\.*");
	my %xenconfig = %{$xenref};
	if (defined $xenconfig{disk}) {
		$kiwi -> info ("Creating image Xen configuration file...");
		if (! open (FD,">$file")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create xenconfig file: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $device = $xenconfig{disk};
		my $part   = $device."1";
		my $memory = $xenconfig{memory};
		my $image  = $dest."/".$name->{systemImage};
		$part =~ s/\/dev\///;
		print FD '#  -*- mode: python; -*-'."\n";
		print FD 'kernel="'.$kernel.'"'."\n";
		print FD 'ramdisk="'.$initrd.'"'."\n";
		print FD 'memory='.$memory."\n";
		print FD 'disk=[ "file:'.$image.','.$part.',w" ]'."\n";
		print FD 'root="'.$device.' ro"'."\n";
		print FD 'extra=" xencons=tty "'."\n";
		close FD;
		$kiwi -> done();
	}
	return $dest;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
	my $name = shift;
	#==========================================
	# Create image md5sum
	#------------------------------------------
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = -s "$imageDest/$name";
	my $primes = qx (factor $size); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 8192);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qx (cat $imageDest/$name | md5sum - | cut -f 1 -d-);
	chomp $sum;
	if ($name =~ /\.gz$/) {
		$name =~ s/\.gz//;
	}
	qx (echo "$sum $blocks $blocksize" > $imageDest/$name.md5);
	$kiwi -> done();
	return $name;
}

#==========================================
# restoreSplitExtend
#------------------------------------------
sub restoreSplitExtend {
	if ((! defined $imageTreeReadOnly) || ( ! -d $imageTreeReadOnly)) {
		return $imageTreeReadOnly;
	}
	$kiwi -> info ("Restoring physical extend...");
	my @rodirs = qw (bin boot lib opt sbin usr);
	foreach my $dir (@rodirs) {
		my $data = qx (mv $imageTreeReadOnly/$dir $imageTree 2>&1);
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't restore physical extend: $data");
			$kiwi -> failed ();
			return undef;
		}
	}
	$kiwi -> done();
	rmdir  $imageTreeReadOnly;
	return $imageTreeReadOnly;
}

#==========================================
# compressImage
#------------------------------------------
sub compressImage {
	my $name = shift;
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	$kiwi -> info ("Compressing image...");
	my $data = qx (gzip $imageDest/$name);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Compressing image failed: $!");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	return $name;
}

#==========================================
# getSize
#------------------------------------------
sub getSize {
	# ...
	# calculate size of the logical extend. The
	# method returns the size value in MegaByte
	# ---
	my $extend = shift;
	my $size = qx ( du -ks $extend );
	$size =~ /(\d+)\s.*/;
	#==========================================
	# Add 10% more space for later filesystem
	#------------------------------------------
	my $spare = 0.1 * $size;
	if ($spare <= 8192) {
		$spare = 8192;
	}
	my $orig = $size;
	$orig /= 1024;
	$orig = int ($orig);
	$size += $spare;
	$size /= 1024;
	$size = int ($size);
	return ($orig,$size,$xml->getImageSize());
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	qx (umount $imageDest/mnt-$$ 2>&1);
	rmdir "$imageDest/mnt-$$";
}

1;
