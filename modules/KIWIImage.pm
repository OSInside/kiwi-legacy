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
use KIWIBoot;
use Math::BigFloat;
use File::Basename;
use File::Find qw(find);
use File::stat;
use Fcntl ':mode';
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIImage object which is used to create
	# the different output image formats from a previosly
	# prepared physical extend
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Module Parameters
	#------------------------------------------
	my $kiwi       = shift;
	my $xml        = shift;
	my $imageTree  = shift;
	my $imageDest  = shift;
	my $imageStrip = shift;
	my $baseSystem = shift;
	my $imageOrig  = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
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
	if (! -f "$imageTree/image/config.xml") {
		$kiwi -> error  ("Validation of $imageTree failed");
		$kiwi -> failed ();
		return undef;
	}
	if (! -d $imageDest) {
		$kiwi -> error  ("No valid destdir: $imageDest");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $main::LogFile) {
		if (defined $imageOrig) {
			$kiwi -> setRootLog ($imageOrig.".".$$.".screenrc.log");
		} else {
			$kiwi -> setRootLog ($imageTree.".".$$.".screenrc.log");
		}
	}
	my $arch = qxx ("uname -m"); chomp ( $arch );
	$arch = ".$arch";
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}       = $kiwi;
	$this->{xml}        = $xml;
	$this->{imageTree}  = $imageTree;
	$this->{imageDest}  = $imageDest;
	$this->{imageStrip} = $imageStrip;
	$this->{baseSystem} = $baseSystem;
	$this->{arch}       = $arch;
	#==========================================
	# Clean kernel mounts if any
	#------------------------------------------
	$this -> cleanKernelFSMount();
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
	my $kiwi = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	$kiwi -> info ("Stripping shared objects/executables...");
	my @list = qxx ("find $imageTree -type f -perm -755");
	foreach my $file (@list) {
		chomp $file;
		my $data = qxx ("file \"$file\"");
		chomp $data;
		if ($data =~ /not stripped/) {
		if ($data =~ /shared object/) {
			qxx ("strip -p $file 2>&1");
		}
		if ($data =~ /executable/) {
			qxx ("strip -p $file 2>&1");
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
	my $imageTree = $this->{imageTree};
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupEXT2 ( $name,$imageTree,$journal )) {
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name)) {
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
	my $this = shift;
	$this -> createImageEXT2 ("journaled");
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
	my $name = $this -> preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupReiser ( $name )) {
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name)) {
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
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ("haveExtend");
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupSquashFS ( $name )) {
		return undef;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! $this -> buildMD5Sum ($name)) {
		return undef;
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if ($xml->getCompressed()) {
	if (! $this -> compressImage ($name)) {
		return undef;
	}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
	$kiwi -> info ("Creating boot configuration...");
	if (! $this -> writeImageConfig ($name)) {
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
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	my $compress  = 1;
	#==========================================
	# PRE check compression level
	#------------------------------------------
	if (! $xml -> getCompressed()) {
		$compress = 0;
	}
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ("haveExtend");
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# PRE Create filesystem on extend
	#------------------------------------------
	my $pwd  = qxx ("pwd"); chomp $pwd;
	my @cpio = ("--create", "--format=newc", "--quiet");
	my $tree = $imageTree;
	my $dest = $imageDest."/".$name.".gz";
	my $data;
	if (! $compress) {
		$dest = $imageDest."/".$name;
	}
	if ($dest !~ /^\//) {
		$dest = $pwd."/".$dest;
	}
	if ($compress) {
		$data = qxx ("cd $tree && find . | cpio @cpio | $main::Gzip -f > $dest");
	} else {
		$data = qxx ("cd $tree && find . | cpio @cpio > $dest");
	}
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create cpio archive");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	if ($compress) {
		$name = $name.".gz";
	}
	if (! $this -> buildMD5Sum ($name)) {
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
	my $kiwi = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	my $baseSystem= $this->{baseSystem};
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
			$ok = 1;
			if ($text ne "VMX") {
				$ok = $this -> createImageEXT2 ();
			}
			$result{imageTree} = $imageTree;
			last SWITCH;
		};
		/^ext3/       && do {
			$ok = 1;
			if ($text ne "VMX") {
				$ok = $this -> createImageEXT3 ();
			}
			$result{imageTree} = $imageTree;
			last SWITCH;
		};
		/^reiserfs/   && do {
			$ok = 1;
			if ($text ne "VMX") {
				$ok = $this -> createImageReiserFS ();
			}
			$result{imageTree} = $imageTree;
			last SWITCH;
		};
		/^squashfs/   && do {
			$ok = $this -> createImageSquashFS ();
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported $text type: $type");
		$kiwi -> failed ();
		return undef;
	};
	if (! $ok) {
		return undef;
	}
	if (! defined $main::ImageName) {
		$this -> buildImageName();
	}
	$result{systemImage} = $main::ImageName;
	#==========================================
	# Prepare and Create USB boot image
	#------------------------------------------
	$kiwi -> info ("Creating $text boot image: $boot...\n");
	my $Prepare = $imageTree."/image";
	my $xml = new KIWIXML ( $kiwi,$Prepare,undef,$main::SetImageType );
	if (! defined $xml) {
		return undef;
	}
	my %type   = %{$xml->getImageTypeAndAttributes()};
	my $pblt   = $type{checkprebuilt};
	my $tmpdir = qxx ("mktemp -q -d /tmp/kiwi-$text.XXXXXX"); chomp $tmpdir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$main::Survive  = "yes";
	$main::RootTree = "$tmpdir/kiwi-".$text."boot-$$";
	$main::Prepare  = $boot;
	$main::BaseRoot = $type{baseroot};
	if (defined $main::BaseRoot) {
		if (($main::BaseRoot !~ /^\//) && (! -d $main::BaseRoot)) {
			$main::BaseRoot = $main::System."/".$main::BaseRoot;
		}
	}
	if (($main::Prepare !~ /^\//) && (! -d $main::Prepare)) {
		$main::Prepare = $main::System."/".$main::Prepare;
	}
	if ($type{bootprofile}) {
		@main::Profiles = split (/,/,$type{bootprofile});
	}
	$main::ForeignRepo{xmlnode} = $xml -> getForeignNodeList();
	$main::ForeignRepo{packagemanager} = $xml -> getPackageManager();
	$main::ForeignRepo{locale}  = $xml -> getLocale();
	$main::ForeignRepo{prepare} = $main::Prepare;
	$main::ForeignRepo{create}  = $main::Create;
	$main::Compress = "no";
	$main::Create   = $main::RootTree;
	undef $main::SetImageType;
	$kiwi -> info ("Checking for pre-built boot image");
	if ((! $pblt) || ($pblt eq "false") || ($pblt eq "0")) {
		#==========================================
		# don't want a prebuilt boot image
		#------------------------------------------
		$kiwi -> notset();
		$pblt = 0;
	} else {
		#==========================================
		# check if a prebuilt boot image exists
		#------------------------------------------
		my $storexml = $this->{xml};
		$this->{xml} = new KIWIXML ( $kiwi,$main::Prepare );
		$this -> buildImageName();
		$this->{xml} = $storexml;
		my $lookup  = $main::Prepare."-prebuilt/";
		if (defined $main::PrebuiltBootImage) {
			$lookup = $main::PrebuiltBootImage."/";
		}
		my $pinitrd = $lookup.$main::ImageName.".gz";
		my $plinux  = $lookup.$main::ImageName.".kernel";
		if (! -f $pinitrd) {
			$pinitrd = $lookup.$main::ImageName;
		}
		if ((! -f $pinitrd) || (! -f $plinux)) {
			$kiwi -> skipped();
			$kiwi -> info ("Can't find pre-built boot image in $lookup");
			$kiwi -> skipped();
			$pblt = 0;
		} else {
			$kiwi -> done();
			$kiwi -> info ("Copying pre-built boot image to destination");
			my $data = qxx ("cp -a $pinitrd $main::Destination 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$kiwi -> error ("Can't copy pre-built initrd: $data");
				$kiwi -> failed();
				$pblt = 0;
			} else {
				$data = qxx ("cp -a $plinux* $main::Destination 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed();
					$kiwi -> error ("Can't copy pre-built kernel: $data");
					$kiwi -> failed();
					$pblt = 0;
				} else {
					$kiwi -> done();
					$pblt = 1;
				}
			}
		}
	}
	if (! $pblt) {
		if (! defined main::main()) {
			$main::Survive = "default";
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
			}
			return undef;
		}
	}
	#==========================================
	# remove tmpdir with boot tree
	#------------------------------------------
	if (! -d $main::RootTree.$baseSystem) {
		qxx ("rm -rf $main::RootTree");
		qxx ("rm -rf $tmpdir");
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $initrd = $main::Destination."/".$main::ImageName.".gz";
	if (! -f $initrd) {
		$initrd = $main::Destination."/".$main::ImageName;
	}
	my $kboot  = new KIWIBoot ($kiwi,$initrd);
	if (! defined $kboot) {
		return undef;
	}
	$kboot -> setupSplashForGrub();
	$kboot -> cleanTmp();
	#==========================================
	# Store meta data for subsequent calls
	#------------------------------------------
	$result{bootImage} = $main::ImageName;
	if ($text eq "VMX") {
		$result{format} = $type{format};
	}
	if ($text eq "USB") {
		$main::Survive = "default";
	}
	return \%result;
}

#==========================================
# createImagePXE
#------------------------------------------
sub createImagePXE {
	# ...
	# Create Image usable within a PXE boot environment. The
	# method will create the specified boot image (initrd) and
	# the system image. In order to use this image via PXE the
	# administration needs to provide the images via TFTP
	#
	# NOTE: Because the steps of creating
	# a PXE image are the same as creating an usb stick image
	# we make use of the usb code above to create the system and boot
	# image
	# ---
	#==========================================
	# Create PXE boot and system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my $name = $this -> createImageUSB ($para,"PXE");
	if (! defined $name) {
		return undef;
	}
	$main::Survive = "default";
	return $this;
}

#==========================================
# createImageVMX
#------------------------------------------
sub createImageVMX {
	# ...
	# Create virtual machine disks. By default a raw disk image will
	# created from which other types can be converted. The output
	# format is specified by the format attribute in the type section.
	# Supported formats are: vvfat vpc bochs dmg cloop vmdk qcow cow raw
	# The process will create the system image and the appropriate vmx
	# boot image plus a .raw and an optional format specific image.
	# The boot image description must exist in /usr/share/kiwi/image.
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
	my $xml  = $this->{xml};
	my %vmwc = $xml  -> getPackageAttributes ("vmware");
	my $name = $this -> createImageUSB ($para,"VMX");
	if (! defined $name) {
		return undef;
	}
	undef $main::Prepare;
	undef $main::Create;
	#==========================================
	# Create virtual disk images
	#------------------------------------------
	$main::BootVMDisk  = $main::Destination."/".$name->{bootImage}.".splash.gz";
	$main::BootVMSystem= $main::Destination."/".$name->{systemImage};
	$main::BootVMFormat= $name->{format};
	if (defined $name->{imageTree}) {
		$main::BootVMSystem = $name->{imageTree};
	}
	if (! defined main::main()) {
		$main::Survive = "default";
		return undef;
	}
	#==========================================
	# Create virtual disk configuration
	#------------------------------------------
	if ((defined $main::BootVMFormat) && ($main::BootVMFormat eq "vmdk")) {
		# VMware vmx file...
		if (! $this -> buildVMwareConfig ($main::Destination,$name,\%vmwc)) {
			$main::Survive = "default";
			return undef;
		}	
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
	my $xml  = $this->{xml};
	my %xenc = $xml  -> getPackageAttributes ("xen");
	my $name = $this -> createImageUSB ($para,"Xen");
	if (! defined $name) {
		return undef;
	}
	undef $main::Prepare;
	undef $main::Create;
	#==========================================
	# Create image xenconfig
	#------------------------------------------
	if (! $this -> buildXenConfig ($main::Destination,$name,\%xenc)) {
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
	my $kiwi = $this->{kiwi};
	my $arch = $this->{arch};
	my $sxml = $this->{xml};
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	my $baseSystem= $this->{baseSystem};
	my $error;
	my $data;
	my $code;
	my $imageTreeReadOnly;
	my $plinux;
	my $pinitrd;
	#==========================================
	# Get system image name
	#------------------------------------------
	my $systemName = $sxml -> getImageName();
	#==========================================
	# Get system image type information
	#------------------------------------------
	my %type = %{$sxml->getImageTypeAndAttributes()};
	my $pblt = $type{checkprebuilt};
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
	my $namecd = $this -> buildImageName (";");
	my $namerw = $this -> buildImageName ();
	my $namero = $this -> buildImageName ("-","-read-only");
	if (! defined $namerw) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! $this -> setupLogicalExtend ("quiet")) {
		return undef;
	}
	#==========================================
	# split physical extend into RW / RO part
	#------------------------------------------
	if (! defined $gzip) {
		$imageTreeReadOnly = $imageTree;
		$imageTreeReadOnly =~ s/\/+$//;
		$imageTreeReadOnly.= "-read-only/";
		$this->{imageTreeReadOnly} = $imageTreeReadOnly;
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
				$data = qxx ("mv $imageTree/$dir $imageTreeReadOnly 2>&1");
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
		my ($mbytesreal,$mbytesrw,$xmlsize) = $this -> getSize ($imageTree);
		$kiwi -> done ();

		#==========================================
		# Create RW logical extend
		#------------------------------------------
		$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
		if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
			$this -> restoreSplitExtend ();
			return undef;
		}
		$kiwi -> done ();
		#==========================================
		# Create EXT2 filesystem on RW extend
		#------------------------------------------
		if (! $this -> setupEXT2 ( $namerw,$imageTree )) {
			$this -> restoreSplitExtend ();
			return undef;
		}
		#==========================================
		# mount logical extend for data transfer
		#------------------------------------------
		my $extend = $this -> mountLogicalExtend ($namerw);
		if (! defined $extend) {
			$this -> restoreSplitExtend ();
			return undef;
		}
		#==========================================
		# copy physical to logical
		#------------------------------------------
		if (! $this -> installLogicalExtend ($extend,$imageTree)) {
			$this -> restoreSplitExtend ();
			return undef;
		}
		$this -> cleanMount();
	}
	#==========================================
	# Create compressed filesystem on RO extend
	#------------------------------------------
	if (defined $gzip) {
		if ($gzip eq "compressed") {
			if (! $this -> createImageSplit ("ext3,squashfs", 1)) {
				return undef;
			}
			$namero = $namerw;
		} else {
			$kiwi -> info ("Creating compressed read only filesystem...");
			if (! $this -> setupSquashFS ( $namero,$imageTree )) {
				$this -> restoreSplitExtend ();
				return undef;
			}
			$kiwi -> done();
		}
	}
	#==========================================
	# Check / build md5 sum of RW extend
	#------------------------------------------
	if (! defined $gzip) {
		#==========================================
		# Checking RW file system
		#------------------------------------------
		qxx ("/sbin/e2fsck -f -y $imageDest/$namerw 2>&1");

		#==========================================
		# Create image md5sum
		#------------------------------------------
		if (! $this -> buildMD5Sum ($namerw)) {
			$this -> restoreSplitExtend ();
			return undef;
		}
		#==========================================
		# Restoring physical extend
		#------------------------------------------
		if (! $this -> restoreSplitExtend ()) {
			return undef;
		}
		#==========================================
		# compress RW extend
		#------------------------------------------
		if (! $this -> compressImage ($namerw)) {
			return undef;
		}
	}
	#==========================================
	# recreate a copy of the read-only data
	#------------------------------------------	
	if ((defined $imageTreeReadOnly) && (! -d $imageTreeReadOnly) &&
		(! defined $gzip)
	) {
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
			$data = qxx ("cp -a $imageTree/$dir $imageTreeReadOnly 2>&1");
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
		qxx ("rm -rf $imageTreeReadOnly");
		return undef;
	}
	my $tmpdir = qxx (" mktemp -q -d /tmp/kiwi-cdboot.XXXXXX "); chomp $tmpdir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$main::Survive  = "yes";
	$main::RootTree = "$tmpdir/kiwi-cdboot-$$";
	$main::Prepare  = $boot;
	$main::BaseRoot = $type{baseroot};
	if (defined $main::BaseRoot) {
		if (($main::BaseRoot !~ /^\//) && (! -d $main::BaseRoot)) {
			$main::BaseRoot = $main::System."/".$main::BaseRoot;
		}
	}
	if (($main::Prepare !~ /^\//) && (! -d $main::Prepare)) {
		$main::Prepare = $main::System."/".$main::Prepare;
	}
	if ($type{bootprofile}) {
		@main::Profiles = split (/,/,$type{bootprofile});
	}
	$main::ForeignRepo{xmlnode} = $xml -> getForeignNodeList();
	$main::ForeignRepo{packagemanager} = $xml -> getPackageManager();
	$main::ForeignRepo{locale}  = $xml -> getLocale();
	$main::ForeignRepo{prepare} = $main::Prepare;
	$main::ForeignRepo{create}  = $main::Create;
	$main::Create = $main::RootTree;
	$xml = new KIWIXML ( $kiwi,$main::Prepare );
	my $iso = $xml -> getImageName();
	undef $main::SetImageType;
	$kiwi -> info ("Checking for pre-built boot image");
	if ((! $pblt) || ($pblt eq "false") || ($pblt eq "0")) {
		#==========================================
		# don't want a prebuilt boot image
		#------------------------------------------
		$kiwi -> notset();
		$pblt = 0;
	} else {
		#==========================================
		# check if a prebuilt boot image exists
		#------------------------------------------
		my $lookup = $main::Prepare."-prebuilt";
		if (defined $main::PrebuiltBootImage) {
			$lookup = $main::PrebuiltBootImage;
		}
		$pinitrd = glob ("$lookup/$iso*$arch*.gz");
		$plinux  = glob ("$lookup/$iso*$arch*.kernel");
		if ((! -f $pinitrd) || (! -f $plinux)) {
			$kiwi -> skipped();
			$kiwi -> info ("Cant't find pre-built boot image in $lookup");
			$kiwi -> skipped();
			$pblt = 0;
		} else {
			$kiwi -> done();
			$kiwi -> info ("Extracting pre-built boot image");
			$data = qxx ("mkdir -p $main::Create");
			$data = qxx (
				"$main::Gzip -cd $pinitrd|(cd $main::Create && cpio -di 2>&1)"
			);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$kiwi -> error ("Can't extract pre-built boot image: $data");
				$kiwi -> failed();
				$pblt = 0;
			} else {
				$kiwi -> done();
				$pblt = 1;
			}
		}
	}
	if (! $pblt) {
		#==========================================
		# build an isoboot boot image
		#------------------------------------------
		if (! defined main::main()) {
			$main::Survive = "default";
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			return undef;
		}
	}
	$main::Survive = "default";
	undef %main::ForeignRepo;
	#==========================================
	# Prepare for CD ISO image
	#------------------------------------------
	$kiwi -> info ("Creating CD filesystem");
	qxx ("mkdir -p $main::RootTree/CD/boot");
	$kiwi -> done ();

	#==========================================
	# Check for optional config-cdroot archive
	#------------------------------------------
	my $cdrootData = $imageTree."/image/config-cdroot.tgz";
	if (-f $cdrootData) {
		$kiwi -> info ("Integrating CD root information...");
		my $data = qxx ("tar -C $main::RootTree/CD -xvf $cdrootData");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to integrate CD root data: $data");
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			return undef;
		}
		$kiwi -> done();
		$kiwi -> info ("Removing CD root tarball from system image");
		$data = qxx ("rm $cdrootData");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	$cdrootData = $imageTree."/image/config-cdroot.sh";
	if (-x $cdrootData) {
		$kiwi -> info ("Calling CD root setup script...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $cdrootEnv = $imageTree."/.profile";
		if ($cdrootEnv !~ /^\//) {
			$cdrootEnv = $pwd."/".$cdrootEnv;
		}
		if ($cdrootData !~ /^\//) {
			$cdrootData = $pwd."/".$cdrootData;
		}
		my $CCD  = "$main::RootTree/CD";
		my $data = qxx ("
			cd $CCD && bash -c '. $cdrootEnv && . $cdrootData' 2>&1"
		);
		my $code = $? >> 8;
		if ($code != 0) {
			chomp $data;
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to call CD root script: $data");
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			return undef;
		}
		$kiwi -> done();
		$kiwi -> info ("Removing CD root setup script from system image");
		$data = qxx ("rm $cdrootData");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Installing second stage images
	#------------------------------------------
	$kiwi -> info ("Moving CD image data into boot structure");
	if (! defined $gzip) {
		qxx ("mv $imageDest/$namerw.md5 $main::RootTree/CD");
		qxx ("mv $imageDest/$namerw.gz $main::RootTree/CD");
	}
	if (defined $gzip) {
		qxx ("mv $imageDest/$namero $main::RootTree/CD");
	} else {
		qxx ("mkdir -p $main::RootTree/CD/read-only-system");
		qxx ("mv $imageTreeReadOnly/* $main::RootTree/CD/read-only-system");
		rmdir $imageTreeReadOnly;
	}
	$kiwi -> done ();

	#==========================================
	# copy boot files for isolinux
	#------------------------------------------
	my $CD  = $main::Prepare."/cdboot";
	my $gfx = $main::RootTree."/image/loader";
	my $isoarch = qxx ("uname -m"); chomp $isoarch;
	if ($isoarch =~ /i.86/) {
		$isoarch = "i386";
	}
	if (! -d $gfx) {
		$kiwi -> error  ("Couldn't open directory $gfx: $!");
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# copy kernel and initrd
	#------------------------------------------
	$kiwi -> info ("Copying boot image and kernel [$isoarch]");
	my $destination = "$main::RootTree/CD/boot/$isoarch/loader";
	qxx ("mkdir -p $destination");
	if ($pblt) {
		$data = qxx ("cp $pinitrd $destination/initrd");
	} else {
		$data = qxx ("cp $imageDest/$iso*$arch*.gz $destination/initrd");
	}
	$code = $? >> 8;
	if ($code == 0) {
		if ($pblt) {
			$data = qxx ("cp $plinux $destination/linux");
		} else {
			$data = qxx ("cp $imageDest/$iso*$arch*.kernel $destination/linux");
		}
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Copy failed: $data");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# copy base CD files
	#------------------------------------------
	$kiwi -> info ("Setting up isolinux boot CD [$isoarch]");
	$data = qxx ("cp -a $gfx/* $destination");
	$code = $? >> 8;
	if ($code == 0) {
		$data = qxx ("cp $CD/isolinux.cfg $destination");
		$code = $? >> 8;
		if ($code == 0) {
			$data = qxx ("cp $CD/isolinux.msg $destination");
			$code = $? >> 8;
		}
	}
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Copy failed: $data");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
    }
	$kiwi -> done ();
	#==========================================
	# setup isolinux boot label name
	#------------------------------------------
	my $label = "$systemName [ ISO ]";
	my $lsafe = "Failsafe-$label";
	qxx ("sed -i -e \"s:Live-System:$label:\" $destination/isolinux.cfg");
	qxx ("sed -i -e \"s:Live-Failsafe:$lsafe:\" $destination/isolinux.cfg");
	#==========================================
	# remove original kernel and initrd
	#------------------------------------------
	if (! $pblt) {
		$data = qxx ("rm $imageDest/$iso*.* 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> warning ("Couldn't cleanup boot files: $data");
			$kiwi -> skipped ();
		}
	}
	#==========================================
	# Create boot configuration
	#------------------------------------------
	if (! open (FD,">$main::RootTree/CD/config.isoclient")) {
		$kiwi -> error  ("Couldn't create image boot configuration");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}

	if ((! defined $gzip) || ($gzip eq "unified")) {
		print FD "IMAGE=/dev/ram1;$namecd\n";
	} else {
		print FD "IMAGE=/dev/loop1;$namecd\n";
	}
	
	if (defined $gzip) {
		if ($gzip eq "unified") {
			print FD "UNIONFS_CONFIG=/dev/ram1,/dev/loop1,aufs\n";
		} else {
			print FD "COMBINED_IMAGE=yes\n";
		}
	}
	close FD;

	#==========================================
	# create ISO image
	#------------------------------------------
	$kiwi -> info ("Calling mkisofs...");
	my $name = $imageDest."/".$namerw.".iso";
	$kiwi -> loginfo ("Calling: $CD/isolinux.sh $main::RootTree/CD $name");
	$data = qxx ("$CD/isolinux.sh $main::RootTree/CD $name 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to create ISO image: $data");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	$kiwi -> done();
	if (! relocateCatalog ($this,$name)) {
		return undef;
	}
	#==========================================
	# remove tmpdir with boot tree
	#------------------------------------------
	if (! -d $main::RootTree.$baseSystem) {
		qxx ("rm -rf $main::RootTree");
		qxx ("rm -rf $tmpdir");
	}
	return $this;
}

#==========================================
# createImageSplit
#------------------------------------------
sub createImageSplit {
	# ...
	# Create all split images and the specified boot image which
	# should be used in combination to this split image. The process
	# requires a subsequent action which could be either a kiwi call
	# to create a vmx/oemboot based virtual disk or an usbboot based
	# USB stick or the created images needs to copied into a PXE boot
	# structure for use with a netboot setup.
	# ---
	my $this = shift;
	my $type = shift;
	my $nopersistent = shift;
	my $kiwi = $this->{kiwi};
	my $arch = $this->{arch};
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	my $baseSystem= $this->{baseSystem};
	my $sxml = $this->{xml};
	my $FSTypeRW;
	my $FSTypeRO;
	my $error;
	my $ok;
	my $imageTreeRW;
	my $imageTreeTmp;
	my $mbytesreal;
	my $mbytesro;
	my $mbytesrw;
	my $xmlsize;
	my $boot;
	my $plinux;
	my $pinitrd;
	my $data;
	my $code;
	my $name;
	#==========================================
	# Get filesystem info for split image
	#------------------------------------------
	if ($type =~ /(.*),(.*):(.*)/) {
		$FSTypeRW = $1;
		$FSTypeRO = $2;
		$boot = $3;
	} elsif ($type =~ /(.*),(.*)/) {
		$FSTypeRW = $1;
		$FSTypeRO = $2;
	} else {
		$kiwi -> error  ("Invalid filesystem setup for split type");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Get system image type information
	#------------------------------------------
	my %type = %{$sxml->getImageTypeAndAttributes()};
	my $pblt = $type{checkprebuilt};
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $namerw = $this -> buildImageName ("-","-read-write");
	my $namero = $this -> buildImageName ();
	if (! defined $namerw) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (! $this -> setupLogicalExtend ("quiet", $namero)) {
		return undef;
	}
	#==========================================
	# split physical extend into RW/RO/tmp part
	#------------------------------------------
	$imageTreeTmp = $imageTree;
	$imageTreeTmp =~ s/\/+$//;
	$imageTreeTmp.= "-tmp/";
	$this->{imageTreeTmp} = $imageTreeTmp;
	my @persistFiles = $sxml -> getSplitPersistentFiles ();
	if (! -d $imageTreeTmp) {
		$kiwi -> info ("Creating temporary image part");
		if (! mkdir $imageTreeTmp) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create tmp directory: $error");
			$kiwi -> failed ();
			return undef;
		}
		my $createTmpTree = sub {
			my $file  = $_;
			my $dir   = $File::Find::dir;
			my $path  = "$dir/$file";
			my $target= $path;
			$target =~ s#$imageTree#$imageTreeTmp#;
			my $rerooted = $path;
			$rerooted =~ s#$imageTree#/read-only#;
			my $st = lstat($path);
			if (S_ISDIR($st->mode)) {
				mkdir $target;
				chmod S_IMODE($st->mode), $target;
				chown $st->uid, $st->gid, $target;
			} elsif (
				S_ISCHR($st->mode)  ||
				S_ISBLK($st->mode)  ||
				S_ISLNK($st->mode)
			) {
				qxx ("cp -a $path $target");
			} else {
				symlink ($rerooted, $target);
			}
		};
		find(\&$createTmpTree, $imageTree);
		my @tempFiles = $sxml -> getSplitTempFiles ();
		if ($nopersistent) {
			push (@tempFiles, @persistFiles);
			@persistFiles = ();
		}
		if (@tempFiles) {
			foreach my $temp (@tempFiles) {
				my $globsource = "${imageTree}${temp}";
				my @files = glob($globsource);
				foreach my $file (@files) {
					if (! -e $file) {
						next;
					}
					my $dest = $file;
					$dest =~ s#$imageTree#$imageTreeTmp#;
					qxx ("rm -rf $dest");
					qxx ("cp -a $file $dest");
				}
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# find persistent files for the read-write
	#------------------------------------------
	$imageTreeRW = $imageTree;
	$imageTreeRW =~ s/\/+$//;
	$imageTreeRW.= "-read-write";
	if (! -d $imageTreeRW && @persistFiles) {
		$kiwi -> info ("Creating read-write image part");
		$this->{imageTreeRW} = $imageTreeRW;
		if (! mkdir $imageTreeRW) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create read-write directory: $error");
			$kiwi -> failed ();
			return undef;
		}
		my @expandedPersistFiles = ();
		foreach my $persist (@persistFiles) {
			my $globsource = "${imageTreeTmp}${persist}";
			my @files = glob($globsource);
			foreach my $file (@files) {
				push @expandedPersistFiles, $file;
			}
		}
		sub dirsort {
			if (-d $a && -d $b) {
				my $lena = length($a);
				my $lenb = length($b);
				if ($lena == $lenb) {
					return 0;
				} elsif ($lena < $lenb) {
					return -1;
				} else {
					return 1;
				}
			} elsif (-d $a) {
				return -1;
			} else {
				return 1;
			}
		}
		my @sortedPersistFiles = sort dirsort @expandedPersistFiles;
		foreach my $file (@sortedPersistFiles) {
			my $source  = $file;
			my $rosource= $file;
			my $dest    = $file;
			my $rwroot  = $file;
			$rosource   =~ s#$imageTreeTmp#$imageTree#;
			$dest       =~ s#$imageTreeTmp#$imageTreeRW#;
			$rwroot     =~ s#$imageTreeTmp#/read-write#;
			my $destdir = dirname $dest;
			qxx ("rm -rf $dest");
			qxx ("mkdir -p $destdir");
			if (-d $source) {
				qxx ("mv $source $dest");
				symlink ($rwroot, $source);
			} else {
				qxx ("cp -a $rosource $dest");
				symlink ($rwroot, $source);
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Embed tmp extend into ro extend
	#------------------------------------------
	qxx ("cd $imageTreeTmp && tar cvfz $imageTree/rootfs.tar.gz * 2>&1");
	qxx ("rm -rf $imageTreeTmp");

	#==========================================
	# Count disk space for extends
	#------------------------------------------
	$kiwi -> info ("Computing disk space...");
	($mbytesreal,$mbytesro,$xmlsize) = $this -> getSize ($imageTree);
	if (defined $this->{imageTreeRW}) {
		($mbytesreal,$mbytesrw,$xmlsize) = $this -> getSize ($imageTreeRW);
	}
	$kiwi -> done ();
	if (defined $this->{imageTreeRW}) {
		#==========================================
		# Create RW logical extend
		#------------------------------------------
		if (defined $this->{imageTreeRW}) {
			$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
			if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
				return undef;
			}
			$kiwi -> done();
		}
		#==========================================
		# Create filesystem on RW extend
		#------------------------------------------
		SWITCH: for ($FSTypeRW) {
			/ext2/       && do {
				$ok = $this -> setupEXT2 ( $namerw,$imageTreeRW );
				last SWITCH;
			};
			/ext3/       && do {
				$ok = $this -> setupEXT2 ( $namerw,$imageTreeRW,"journaled" );
				last SWITCH;
			};
			/reiserfs/   && do {
				$ok = $this -> setupReiser ( $namerw );
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $FSTypeRW");
			$kiwi -> failed ();
			return undef;
		}
		if (! $ok) {
			return undef;
		}
	}
	#==========================================
	# Create RO logical extend
	#------------------------------------------
	$kiwi -> info ("Image RO part requires $mbytesro MB of disk space");
	if (! $this -> buildLogicalExtend ($namero,$mbytesro."M")) {
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Create filesystem on RO extend
	#------------------------------------------
	SWITCH: for ($FSTypeRO) {
		/ext2/       && do {
			$ok = $this -> setupEXT2 ( $namero,$imageTree );
			last SWITCH;
		};
		/ext3/       && do {
			$ok = $this -> setupEXT2 ( $namero,$imageTree,"journaled" );
			last SWITCH;
		};
		/reiserfs/   && do {
			$ok = $this -> setupReiser ( $namero );
			last SWITCH;
		};
		/squashfs/   && do {
			$ok = $this -> setupSquashFS ( $namero,$imageTree );
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $FSTypeRO");
		$kiwi -> failed ();
		return undef;
	}
	if (! $ok) {
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
			$source = $imageTreeRW;
			$type = $FSTypeRW;
		} else {
			$source = $imageTree;
			$type = $FSTypeRO;
		}
		if (! -d $source) {
			next;
		}
		my %fsattr = main::checkFileSystem ($type);
		if (! $fsattr{readonly}) {
			#==========================================
			# mount logical extend for data transfer
			#------------------------------------------
			my $extend = $this -> mountLogicalExtend ($name);
			if (! defined $extend) {
				return undef;
			}
			#==========================================
			# copy physical to logical
			#------------------------------------------
			if (! $this -> installLogicalExtend ($extend,$source)) {
				return undef;
			}
			$this -> cleanMount();
		}
		#==========================================
		# Checking file system
		#------------------------------------------
		$kiwi -> info ("Checking file system: $type...");
		SWITCH: for ($type) {
			/ext2/       && do {
				qxx ("/sbin/e2fsck -f -y $imageDest/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/ext3/       && do {
				qxx ("/sbin/fsck.ext3 -f -y $imageDest/$name 2>&1");
				qxx ("/sbin/tune2fs -j $imageDest/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/reiserfs/   && do {
				qxx ("/sbin/reiserfsck -y $imageDest/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/squashfs/   && do {
				$kiwi -> done ();
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# Create image md5sum
		#------------------------------------------
		if (! $this -> buildMD5Sum ($name)) {
			return undef;
		}
	}
	#==========================================
	# Create network boot configuration
	#------------------------------------------
	$kiwi -> info ("Creating boot configuration...");
	if (! $this -> writeImageConfig ($namero)) {
		return undef;
	}
	#==========================================
	# Cleanup temporary data
	#------------------------------------------
	qxx ("rm -rf $imageTreeRW");

	$name->{systemImage} = $main::ImageName;
        if (! defined $boot) {
		return $this;
	}
	#==========================================
	# Prepare and Create boot image
	#------------------------------------------
	$kiwi -> info ("Creating boot image: $boot...\n");
	my $Prepare = $imageTree."/image";
	my $xml = new KIWIXML ( $kiwi,$Prepare );
	if (! defined $xml) {
		return undef;
	}
	my $tmpdir = qxx ("mktemp -q -d /tmp/kiwi-splitboot.XXXXXX"); chomp $tmpdir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$main::Survive  = "yes";
	$main::RootTree = "$tmpdir/kiwi-splitboot-$$";
	$main::Prepare  = $boot;
	$main::BaseRoot = $type{baseroot};
	if (defined $main::BaseRoot) {
		if (($main::BaseRoot !~ /^\//) && (! -d $main::BaseRoot)) {
			$main::BaseRoot = $main::System."/".$main::BaseRoot;
		}
	}
	if (($main::Prepare !~ /^\//) && (! -d $main::Prepare)) {
		$main::Prepare = $main::System."/".$main::Prepare;
	}
	if ($type{bootprofile}) {
		@main::Profiles = split (/,/,$type{bootprofile});
	}
	$main::ForeignRepo{xmlnode} = $xml -> getForeignNodeList();
	$main::ForeignRepo{packagemanager} = $xml -> getPackageManager();
	$main::ForeignRepo{locale}  = $xml -> getLocale();
	$main::ForeignRepo{prepare} = $main::Prepare;
	$main::ForeignRepo{create}  = $main::Create;
	$main::Create = $main::RootTree;
	$xml = new KIWIXML ( $kiwi,$main::Prepare );
	my $iname = $xml -> getImageName();
	undef $main::SetImageType;
	$kiwi -> info ("Checking for pre-built boot image");

	if ((! $pblt) || ($pblt eq "false") || ($pblt eq "0")) {
		#==========================================
		# don't want a prebuilt boot image
		#------------------------------------------
		$kiwi -> notset();
		$pblt = 0;
	} else {
		#==========================================
		# check if a prebuilt boot image exists
		#------------------------------------------
		my $lookup = $main::Prepare."-prebuilt";
		if (defined $main::PrebuiltBootImage) {
			$lookup = $main::PrebuiltBootImage;
		}
		$pinitrd = glob ("$lookup/$iname*$arch*.gz");
		$plinux  = glob ("$lookup/$iname*$arch*.kernel");
		if ((! -f $pinitrd) || (! -f $plinux)) {
			$kiwi -> skipped();
			$kiwi -> info ("Cant't find pre-built boot image in $lookup");
			$kiwi -> skipped();
			$pblt = 0;
		} else {
			$kiwi -> done();
			$kiwi -> info ("Extracting pre-built boot image");
			$data = qxx ("mkdir -p $main::Create");
			$data = qxx (
				"$main::Gzip -cd $pinitrd|(cd $main::Create && cpio -di 2>&1)"
			);
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$kiwi -> error ("Can't extract pre-built boot image: $data");
				$kiwi -> failed();
				$pblt = 0;
			} else {
				$kiwi -> done();
				$pblt = 1;
			}
		}
	}
	if (! $pblt) {
		#==========================================
		# build the boot image
		#------------------------------------------
		if (! defined main::main()) {
			$main::Survive = "default";
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
			}
			return undef;
		}
	}
	#==========================================
	# remove tmpdir with boot tree
	#------------------------------------------
	if (! -d $main::RootTree.$baseSystem) {
		qxx ("rm -rf $main::RootTree");
		qxx ("rm -rf $tmpdir");
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $initrd = $main::Destination."/".$main::ImageName.".gz";
	if (! -f $initrd) {
		$initrd = $main::Destination."/".$main::ImageName;
	}
	my $kboot  = new KIWIBoot ($kiwi,$initrd);
	if (! defined $kboot) {
		return undef;
	}
	$kboot -> setupSplashForGrub();
	$kboot -> cleanTmp();
	#==========================================
	# Check further actions due to boot image
	#------------------------------------------
	$name->{bootImage} = $main::ImageName;
	$name->{format} = $type{format};
	undef %main::ForeignRepo;
	undef $main::Prepare;
	undef $main::Create;
	if ($boot =~ /vmxboot|oemboot/) {
		#==========================================
		# Create virtual disk images if requested
		#------------------------------------------
		$main::BootVMDisk  = $main::Destination."/".$name->{bootImage};
		$main::BootVMDisk  = $main::BootVMDisk.".splash.gz";
		$main::BootVMSystem= $main::Destination."/".$name->{systemImage};
		$main::BootVMFormat= $name->{format};
		if (! defined main::main()) {
			$main::Survive = "default";
			return undef;
		}
		#==========================================
		# Create virtual disk configuration
		#------------------------------------------
		if ((defined $main::BootVMFormat) && ($main::BootVMFormat eq "vmdk")) {
			# VMware vmx file...
			my %vmwc = $sxml -> getPackageAttributes ("vmware");
			if (! $this-> buildVMwareConfig ($main::Destination,$name,\%vmwc)) {
				$main::Survive = "default";
				return undef;
			}
		}
	}
	$main::Survive = "default";
	return $this;
}

#==========================================
# getBlocks
#------------------------------------------
sub getBlocks {
	# ...
	# calculate the block size and number of blocks used
	# to create a <size> bytes long image. Return list
	# (bs,count,seek)
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
		return (($bigimage,$count,$count*$bigimage));
	} else {
		# small image...
		$count = $number / $smallimage;
		$count = Math::BigFloat->new($count)->ffround(0);
		return (($smallimage,$count,$count*$smallimage));
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
	my $this = shift;
	my $haveExtend = shift;
	#==========================================
	# Get image creation date and name
	#------------------------------------------
	my $name = $this -> buildImageName ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Call images.sh script
	#------------------------------------------
	my $mBytes = $this -> setupLogicalExtend (undef,$name);
	if (! defined $mBytes) {
		return undef;
	}
	#==========================================
	# Create logical extend
	#------------------------------------------
	if (! defined $haveExtend) {
	if (! $this -> buildLogicalExtend ($name,$mBytes."M")) {
		return undef;
	}
	}
	return $name;
}

#==========================================
# writeImageConfig
#------------------------------------------
sub writeImageConfig {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $imageDest = $this->{imageDest};
	my $configName = $this -> buildImageName() . ".config";
	my $device = $xml -> getDeployImageDevice ();

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
		my $namecd = $this -> buildImageName(";");
		my $namerw = $this -> buildImageName(";", "-read-write");
		my $server = $xml -> getDeployServer ();
		my $blocks = $xml -> getDeployBlockSize ();
		if (! defined $server) {
			$server = "";
		}
		if (! defined $blocks) {
			$blocks = "";
		}
		print FD "DISK=${device}\n";
		my $targetPartition = 2;
		my $targetPartitionNext = 3;
		#==========================================
		# PART information
		#------------------------------------------
		my @parts = $xml -> getDeployPartitions ();
		if ((scalar @parts) > 0) {
			print FD "PART=";
			for my $href (@parts) {
				if ($href -> {target}) {
					$targetPartition = $href -> {number};
					$targetPartitionNext = $targetPartition + 1;
				}
				if ($href -> {size} eq "image") {
					print FD int (((-s "$imageDest/$name") / 1024 / 1024) + 1);
				} else {
					print FD $href -> {size};
				}

				my $type = $href -> {type};
				my $mountpoint = $href -> {mountpoint};

				SWITCH: for ($type) {
					/swap/i && do {
						$type = "S";
						last SWITCH;
					};
					/linux/i && do {
						$type = "83";
						last SWITCH;
					};
				}

				print FD ";$type;$mountpoint,";
			}
			print FD "\n";
		}
		my %type = %{$xml -> getImageTypeAndAttributes()};
		#==========================================
		# IMAGE information
		#------------------------------------------
		if ($xml->getCompressed("quiet")) {
			print FD "IMAGE=${device}${targetPartition};";
			print FD "$namecd;$server;$blocks;compressed";
			if ("$type{type}" eq "split" && defined $this->{imageTreeRW}) {
				print FD ",${device}${targetPartitionNext}";
				print FD ";$namerw;$server;$blocks;compressed\n";
			} else {
				print FD "\n";
			}
		} else {
			print FD "IMAGE=${device}${targetPartition};";
			print FD "$namecd;$server;$blocks";
			if ("$type{type}" eq "split" && defined $this->{imageTreeRW}) {
				print FD ",${device}${targetPartitionNext}";
				print FD ";$namerw;$server;$blocks\n";
			} else {
				print FD "\n";
			}
		}
		#==========================================
		# CONF information
		#------------------------------------------
		my %confs = $xml -> getDeployConfiguration ();
		if ((scalar keys %confs) > 0) {
			print FD "CONF=";
			foreach my $source (keys %confs) {
				print FD "$source;$confs{$source};$server;$blocks,";
			}
			print FD "\n";
		}
		#==========================================
		# COMBINED_IMAGE information
		#------------------------------------------
		if ("$type{type}" eq "split") {
			print FD "COMBINED_IMAGE=yes\n";
		}
		#==========================================
		# UNIONFS_CONFIG information
		#------------------------------------------
		my %unionConfig = $xml -> getDeployUnionConfig ();
		if (%unionConfig) {
			my $valid = 0;
			my $value;
			if (! $unionConfig{type}) {
				$unionConfig{type} = "aufs";
			}
			if (($unionConfig{rw}) && ($unionConfig{ro})) {
				$value = "$unionConfig{rw},$unionConfig{ro},$unionConfig{type}";
				$valid = 1;
			}
			if ($valid) {
				print FD "UNIONFS_CONFIG=$value\n";
			}
		}
		#==========================================
		# KIWI_BOOT_TIMEOUT information
		#------------------------------------------
		my $timeout = $xml -> getDeployTimeout ();
		if (defined $timeout) {
			print FD "KIWI_BOOT_TIMEOUT=$timeout\n";
		}
		#==========================================
		# KIWI_KERNEL_OPTIONS information
		#------------------------------------------
		my $cmdline = $xml -> getDeployCommandline ();
		if (defined $cmdline) {
			print FD "KIWI_KERNEL_OPTIONS='$cmdline'\n";
		}
		#==========================================
		# KIWI_KERNEL information
		#------------------------------------------
		my $kernel = $xml -> getDeployKernel ();
		if (defined $kernel) {
			print FD "KIWI_KERNEL=$kernel\n";
		}
		#==========================================
		# KIWI_INITRD information
		#------------------------------------------
		my $initrd = $xml -> getDeployInitrd ();
		if (defined $initrd) {
			print FD "KIWI_INITRD=$initrd\n";
		}
		#==========================================
		# More to come...
		#------------------------------------------
		close FD;
		$kiwi -> done ();
	} else {
		$kiwi -> skipped ();
	}
	# Reset main::ImageName...
	$this -> buildImageName();
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
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $imageDest = $this->{imageDest};
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	my $extend = $this -> mountLogicalExtend ($name);
	if (! defined $extend) {
		return undef;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	if (! $this -> installLogicalExtend ($extend)) {
		return undef;
	}
	$this -> cleanMount();

	#==========================================
	# Check image file system
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes()};
	my $para = $type{type}.":".$type{filesystem};
	$kiwi -> info ("Checking file system: $type{filesystem}...");
	SWITCH: for ($para) {
		#==========================================
		# Check EXT3 file system
		#------------------------------------------
		/ext3/i && do {
			qxx ("/sbin/fsck.ext3 -f -y $imageDest/$name 2>&1");
			qxx ("/sbin/tune2fs -j $imageDest/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT2 file system
		#------------------------------------------
		/ext2/i && do {
			qxx ("/sbin/e2fsck -f -y $imageDest/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check ReiserFS file system
		#------------------------------------------
		/reiserfs/i && do {
			qxx ("/sbin/reiserfsck -y $imageDest/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Unknown filesystem type
		#------------------------------------------
		$kiwi -> failed();
		$kiwi -> error ("Unsupported filesystem type: $type{filesystem}");
		$kiwi -> failed();
		return undef;
	}
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! $this -> buildMD5Sum ($name)) {
		return undef;
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if ($xml->getCompressed()) {
	if (! $this -> compressImage ($name)) {
		return undef;
	}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
	$kiwi -> info ("Creating boot configuration...");
	if (! $this -> writeImageConfig ($name)) {
		return undef;
	}
	return $name;
}

#==========================================
# buildImageName
#------------------------------------------
sub buildImageName {
	my $this = shift;
	my $xml  = $this->{xml};
	my $arch = $this->{arch};
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
	my $this = shift;
	my $name = shift;
	my $size = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $imageDest = $this->{imageDest};
	my $out  = $imageDest."/".$name;
	#==========================================
	# Calculate block size and number of blocks
	#------------------------------------------
	if (! defined $size) {
		return undef;
	}
	my @bsc  = getBlocks ( $size );
	my $seek = $bsc[2] - 1;
	#==========================================
	# Create logical extend storage and FS
	#------------------------------------------
	unlink ($out);
	my $data = qxx ("dd if=/dev/zero of=$out bs=1 seek=$seek count=1 2>&1");
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
	my $this   = shift;
	my $extend = shift;
	my $source = shift;
	my $kiwi   = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	if (! defined $source) {
		$source = $imageTree;
	}
	#==========================================
	# copy physical to logical
	#------------------------------------------
	my $name = basename ($source);
	$kiwi -> info ("Copying physical to logical [$name]...");
	my $data = qxx ("cp -a $source/* $extend 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ("No space left on device: $!");
		$kiwi -> failed ();
		$this -> cleanMount();
		return undef;
	}
	$kiwi -> done();
	return $extend;
}

#==========================================
# setupLogicalExtend
#------------------------------------------
sub setupLogicalExtend {
	my $this  = shift;
	my $quiet = shift;
	my $name  = shift;
	my $kiwi  = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	my $imageStrip= $this->{imageStrip};
	#==========================================
	# Call images.sh script
	#------------------------------------------
	if (-x "$imageTree/image/images.sh") {
		$kiwi -> info ("Calling image script: images.sh");
		my $data = qxx (" chroot $imageTree /image/images.sh 2>&1 ");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ($data);
			$this -> cleanMount();
			return undef;
		} else {
			$kiwi -> loginfo ("images.sh: $data");
		}
		qxx (" rm -f $imageTree/image/images.sh ");
		$kiwi -> done ();
	}
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	if (! $this -> extractKernel ($name)) {
		return undef;
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
	$this -> cleanKernelFSMount();
	my ($mbytesreal,$mbytes,$xmlsize) = $this -> getSize ($imageTree);
	if (! defined $quiet) {
		$kiwi -> info ("Image requires $mbytesreal MB, got $xmlsize MB");
		$kiwi -> done ();
		$kiwi -> info ("Suggested Image size: $mbytes MB");
		$kiwi -> done ();
	}
	return $xmlsize;
}

#==========================================
# mountLogicalExtend
#------------------------------------------
sub mountLogicalExtend {
	my $this = shift;
	my $name = shift;
	my $opts = shift;
	my $kiwi = $this->{kiwi};
	my $imageDest = $this->{imageDest};
	my $loopfound = 0;
	my $status;
	my $result;
	my $loop;
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	mkdir "$imageDest/mnt-$$";
	my $mount = "mount";
	if (defined $opts) {
		$mount = "mount $opts";
	}
	for (my $id=0;$id<=7;$id++) {
		$status = qxx (" /sbin/losetup /dev/loop$id 2>&1 ");
		$result = $? >> 8;
		if ($result eq 1) {
			$loopfound = 1;
			$loop = "/dev/loop".$id;
			$this->{loop} = $loop;
			last;
		}
	}
	if (! $loopfound) {
		$kiwi -> error  ("Couldn't find free loop device");
		$kiwi -> failed ();
		return undef;
	}
	my $data= qxx (
		"$mount -o loop=$loop $imageDest/$name $imageDest/mnt-$$ 2>&1"
	);
	my $code= $? >> 8;
	if ($code != 0) {
		chomp $data;
		$kiwi -> error  ("Image loop mount failed:");
		$kiwi -> failed ();
		$kiwi -> error  ("mount: $imageDest/$name -> $imageDest/mnt-$$: $data");
		return undef;
	}
	return "$imageDest/mnt-$$";
}

#==========================================
# extractKernel
#------------------------------------------
sub extractKernel {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml}; 
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	#==========================================
	# extract kernel from physical extend
	#------------------------------------------
	# This is done for boot images only. Therefore we check
	# if the file vmlinux.gz exists which was created by the
	# suseStripKernel() function
	# ---
	if (! defined $name) {
		return $this;
	}
	my %type = %{$xml->getImageTypeAndAttributes()};
	my $para = $type{type};
	if (defined $type{filesystem}) {
		$para = $para.":".$type{filesystem};
	}
	SWITCH: for ($para) {
		/ext3/i     && do {
			return $name;
			last SWITCH;
		};
		/reiserfs/i && do {
			return $name;
			last SWITCH;
		};
		/iso/i && do {
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
	if (-f "$imageTree/boot/vmlinux.gz") {
		$kiwi -> info ("Extracting kernel...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $file = "$imageDest/$name.kernel";
		my $lx = '"^Linux version"';
		my $sp = '-f3 -d" "';
		if ($file !~ /^\//) {
			$file = $pwd."/".$file;
		}
		qxx ("rm -f $file");
		qxx ("cp $imageTree/boot/vmlinuz $file");
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
		my $kernel = qxx (
			"$main::Gzip -dc $gzfile | strings | grep $lx | cut $sp"
		);
		chomp $kernel;
		qxx ("rm -f $file.$kernel");
		qxx ("mv $file $file.$kernel && ln -s $file.$kernel $file ");
		if (-f "$imageTree/boot/xen.gz") {
			$file = "$imageDest/$name.kernel-xen";
			qxx ("cp $imageTree/boot/xen.gz $file");
			qxx ("mv $file $file.$kernel.'gz'");
		}
		qxx ("rm -rf $imageTree/boot/*");
		$kiwi -> done();
	}
	return $name;
}

#==========================================
# setupEXT2
#------------------------------------------
sub setupEXT2 {
	my $this    = shift;
	my $name    = shift;
	my $tree    = shift;
	my $journal = shift;
	my $kiwi    = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	if (! defined $tree) {
		$tree = $imageTree;
	}
	my $fsopts;
	my $fileCount = int ( qxx ("find $tree | wc -l") );
	my $nodeCount = $fileCount * 2;
	if (defined $journal) {
		$fsopts = "-O dir_index -b 4096 -j -J size=4 -q -F -N $nodeCount";
	} else {  
		$fsopts = "-b 4096 -q -F -N $nodeCount";
	}
	my $data = qxx ("/sbin/mke2fs $fsopts $imageDest/$name 2>&1");
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
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $imageDest = $this->{imageDest};
	my $data = qxx (
		"/sbin/mkreiserfs -q -f -s 513 -b 4096 $imageDest/$name 2>&1"
	);
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
# setupSquashFS
#------------------------------------------
sub setupSquashFS {
	my $this = shift;
	my $name = shift;
	my $tree = shift;
	my $kiwi = $this->{kiwi};
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	if (! defined $tree) {
		$tree = $imageTree;
	}
	unlink ("$imageDest/$name");
	my $data = qxx ("/usr/bin/mksquashfs $tree $imageDest/$name 2>&1");
	my $code = $? >> 8; 
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create squashfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	qxx ("chmod 644 $imageDest/$name");
	return $name;
}

#==========================================
# buildXenConfig
#------------------------------------------
sub buildXenConfig {
	my $this   = shift;
	my $dest   = shift;
	my $name   = shift;
	my $xenref = shift;
	my $kiwi   = $this->{kiwi};
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
# buildVMwareConfig
#------------------------------------------
sub buildVMwareConfig {
	my $this   = shift;
	my $dest   = shift;
	my $name   = shift;
	my $vmwref = shift;
	my $kiwi   = $this->{kiwi};
	my $file   = $dest."/".$name->{systemImage}.".vmx";
	my %vmwconfig = %{$vmwref};
	if (defined $vmwconfig{disk}) {
		$kiwi -> info ("Creating image VMware configuration file...");
		if (! open (FD,">$file")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create xenconfig file: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $device = $vmwconfig{disk};
		my $memory = $vmwconfig{memory};
		my $image  = $dest."/".$name->{systemImage};
		# General...
		print FD '#!/usr/bin/vmware'."\n";
		print FD 'config.version = "8"'."\n";
		print FD 'virtualHW.version = "3"'."\n";
		print FD 'memsize = "'.$memory.'"'."\n";
		print FD 'guestOS = "Linux"'."\n";
		print FD 'displayName = "'.$name->{systemImage}.'"'."\n";
		if ($device =~ /^ide/) {
			# IDE Interface...
			print FD $device.':0.present = "true"'."\n";
			print FD $device.':0.fileName= "'.$image.'.vmdk"'."\n";
			print FD $device.':0.redo = ""'."\n";
		} else {
			# SCSI Interface...
			print FD $device.'.present = "true"'."\n";
			print FD $device.'.sharedBus = "none"'."\n";
			print FD $device.'.virtualDev = "lsilogic"'."\n";
			print FD $device.':0.present = "true"'."\n";
			print FD $device.':0.fileName = "'.$image.'"'."\n";
			print FD $device.':0.deviceType = "scsi-hardDisk"'."\n";
		}
		# Floppy...
		print FD 'floppy0.fileName = "/dev/fd0"'."\n";
		# Network...
		print FD 'Ethernet0.present = "true"'."\n";
		print FD 'ethernet0.addressType = "generated"'."\n";
		print FD 'ethernet0.generatedAddress = "00:0c:29:13:ea:50"'."\n";
		print FD 'ethernet0.generatedAddressOffset = "0"'."\n";
		# USB...
		print FD 'usb.present = "true"'."\n";
		# Power management...
		print FD 'priority.grabbed = "normal"'."\n";
		print FD 'priority.ungrabbed = "normal"'."\n";
		print FD 'powerType.powerOff = "hard"'."\n";
		print FD 'powerType.powerOn  = "hard"'."\n";
		print FD 'powerType.suspend  = "hard"'."\n";
		print FD 'powerType.reset    = "hard"'."\n";
		close FD;
		$kiwi -> done();
	}
	return $dest;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $imageDest = $this->{imageDest};
	#==========================================
	# Create image md5sum
	#------------------------------------------
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = -s "$imageDest/$name";
	my $primes = qxx ("factor $size"); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 8192);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qxx ("cat $imageDest/$name | md5sum - | cut -f 1 -d-");
	chomp $sum;
	if ($name =~ /\.gz$/) {
		$name =~ s/\.gz//;
	}
	qxx ("echo \"$sum $blocks $blocksize\" > $imageDest/$name.md5");
	$kiwi -> done();
	return $name;
}

#==========================================
# restoreSplitExtend
#------------------------------------------
sub restoreSplitExtend {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $imageTreeReadOnly = $this->{imageTreeReadOnly};
	my $imageTree = $this->{imageTree};
	if ((! defined $imageTreeReadOnly) || ( ! -d $imageTreeReadOnly)) {
		return $imageTreeReadOnly;
	}
	$kiwi -> info ("Restoring physical extend...");
	my @rodirs = qw (bin boot lib opt sbin usr);
	foreach my $dir (@rodirs) {
		my $data = qxx ("mv $imageTreeReadOnly/$dir $imageTree 2>&1");
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
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my $imageDest = $this->{imageDest};
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	$kiwi -> info ("Compressing image...");
	my $data = qxx ("$main::Gzip -f $imageDest/$name");
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
	my $this   = shift;
	my $extend = shift;
	my $xml    = $this->{xml};
	my $size = qxx (" du -ks $extend "); chomp $size;
	if ($size =~ /(\d+)\s.*/) {
		$size = $1;
	}
	#==========================================
	# Add 30% more space for later filesystem
	#------------------------------------------
	my $spare = 0.3 * $size;
	if ($spare <= 8192) {
		$spare = 8192;
	}
	my $orig = $size;
	$orig /= 1024;
	$orig = int ($orig);
	$size += $spare;
	$size /= 1024;
	$size = int ($size);
	my $xmlsize = $xml->getImageSize();
	if ($xmlsize eq "auto") {
		$xmlsize = $size;
	}
	return ($orig,$size,$xmlsize);
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	my $this = shift;
	my $imageDest = $this->{imageDest};
	qxx ("umount -l $imageDest/mnt-$$ 2>&1");
	if (defined $this->{loop}) {
		system ("/sbin/losetup -d $this->{loop}");
	}
	rmdir "$imageDest/mnt-$$";
}

#==========================================
# cleanKernelFSMount
#------------------------------------------
sub cleanKernelFSMount {
	my $this = shift;
	my $imageDest = $this->{imageDest};
	my @kfs  = ("/proc/sys/fs/binfmt_misc","/proc","/dev/pts","/sys");
	foreach my $system (@kfs) {
		qxx ("umount $imageDest/$system 2>&1");
	}
}

1;
