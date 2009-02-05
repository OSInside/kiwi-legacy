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
use Carp qw (cluck);
use KIWILog;
use KIWIBoot;
use KIWIXML;
use KIWIIsoLinux;
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
	my $configFile = $xml -> getConfigName();
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
	if (! -f "$imageTree/image/$configFile") {
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
		$imageTree =~ s/\/$//;
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
# createImageEC2
#------------------------------------------
sub createImageEC2 {
	# ...
	# create Amazon EC2 image from an ext3 based
	# kiwi image
	# ---
	my $this      = shift;
	my $boot      = shift;
	my $imageTree = $this->{imageTree};
	my $imageDest = $this->{imageDest};
	my $baseSystem= $this->{baseSystem};
	my $sxml      = $this->{xml};
	my $kiwi      = $this->{kiwi};
	my $type;
	my $plinux;
	my $pinitrd;
	#==========================================
	# Check AWS account information
	#------------------------------------------
	my $arch = qxx ("uname -m"); chomp ( $arch );
	my %type = %{$sxml->getImageTypeAndAttributes()};
	my $pblt = $type{checkprebuilt};
	if (! defined $type{AWSAccountNr}) {
		$kiwi -> error  ("Missing AWS account number");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $type{EC2CertFile}) {
		$kiwi -> error  ("Missing AWS user's PEM encoded RSA pubkey cert file");
		$kiwi -> failed ();
		return undef;
	} elsif (! -f $type{EC2CertFile}) {
		$kiwi -> error  ("EC2 file: $type{EC2CertFile} does not exist");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $type{EC2PrivateKeyFile}) {
		$kiwi -> error ("Missing AWS user's PEM encoded RSA private key file");
		$kiwi -> failed ();
		return undef;
	} elsif (! -f $type{EC2PrivateKeyFile}) {
		$kiwi -> error  ("EC2 file: $type{EC2PrivateKeyFile} does not exist");
		$kiwi -> failed ();
		return undef;
	}
	if ($arch =~ /i.86/) {
		$arch = "i386";
	}
	if (($arch ne "i386") && ($arch ne "x86_64")) {
		$kiwi -> error  ("Unsupport AWS EC2 architecture: $arch");
		$kiwi -> failed ();
		return undef;
	}
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
	if (! $this -> setupEXT2 ( $name,$imageTree,"journaled" )) {
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,"no_compress")) {
		return undef;
	}
	#==========================================
	# call ec2-bundle-image (Amazon toolkit)
	#------------------------------------------
	$kiwi -> info ("Creating EC2 bundle...");
	my $pk = $type{EC2PrivateKeyFile};
	my $ca = $type{EC2CertFile};
	my $nr = $type{AWSAccountNr};
	my $fi = $imageDest."/".$name;
	my $amiopts = "-i $fi -k $pk -c $ca -u $nr -p $name.ami";
	my $data = qxx (
		"ec2-bundle-image $amiopts -d $imageDest -r $arch 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("ec2-bundle-image: $data");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# build boot image only if specified
	#------------------------------------------
	if ((! defined $boot) || ($boot eq "ok")) {
		return $this;
	}
	#==========================================
	# Prepare and Create boot image
	#------------------------------------------
	$imageTree = $this->{imageTree};
	$kiwi -> info ("Creating boot image: $boot...\n");
	my $Prepare = $imageTree."/image";
	my $xml = new KIWIXML ( $kiwi,$Prepare );
	if (! defined $xml) {
		return undef;
	}
	my $tmpdir = qxx ("mktemp -q -d /tmp/kiwi-ec2boot.XXXXXX"); chomp $tmpdir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$main::Survive  = "yes";
	$main::RootTree = "$tmpdir/kiwi-ec2boot-$$";
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
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"locale"}  = $xml -> getLocale();
	$main::ForeignRepo{"prepare"} = $main::Prepare;
	$main::ForeignRepo{"create"}  = $main::Create;
	$main::Create = $main::RootTree;
	$xml = new KIWIXML ( $kiwi,$main::Prepare );
	if (! defined $xml) {
		return undef;
	}
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
		# build the ec2 boot image
		#------------------------------------------
		undef @main::AddPackage;
		undef $main::Upgrade;
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
	$main::Survive = "default";
	if (! -d $main::RootTree.$baseSystem) {
		qxx ("rm -rf $main::RootTree");
		qxx ("rm -rf $tmpdir");
	}
	#==========================================
	# setup initrd name 
	#------------------------------------------
	my $kernel = $main::Destination."/".$main::ImageName.".kernel";
	my $initrd = $main::Destination."/".$main::ImageName.".gz";
	if (! -f $initrd) {
		$initrd = $main::Destination."/".$main::ImageName;
	}
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if (defined $main::CheckKernel) {
		if (! $this -> checkKernel ($initrd,$imageTree)) {
			return undef;
		}
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $kboot  = new KIWIBoot ($kiwi,$initrd);
	if (! defined $kboot) {
		return undef;
	}
	$kboot -> setupSplash();
	$kboot -> cleanTmp();
	#==========================================
	# call ec2-bundle-ramdisk (Amazon toolkit)
	#------------------------------------------
	$kiwi -> info ("Creating EC2 bundle (ramdisk)...");
	my $ariopts = "-i $initrd -k $pk -c $ca -u $nr ";
	$ariopts.= "-p $main::ImageName.ari";
	$data = qxx (
		"ec2-bundle-ramdisk $ariopts -d $imageDest -r $arch 2>&1"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("ec2-bundle-ramdisk: $data");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# call ec2-bundle-kernel (Amazon toolkit)
	#------------------------------------------
	$kiwi -> info ("Creating EC2 bundle (kernel)...");
	my $akiopts = "-K $kernel -k $pk -c $ca -u $nr ";
	$akiopts.= "-p $main::ImageName.kernel.aki";
	$data = qxx (
		"ec2-bundle-kernel $akiopts -d $imageDest -r $arch 2>&1"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("ec2-bundle-kernel: $data");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	return $this;
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
# createImageCromFS
#------------------------------------------
sub createImageCromFS {
	# ...
	# create cromfs image from source tree
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
	if (! $this -> setupCromFS ( $name )) {
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
	my $dest = $imageDest."/".$name.".gz";
	my $data;
	if (! $compress) {
		$dest = $imageDest."/".$name;
	}
	if ($dest !~ /^\//) {
		$dest = $pwd."/".$dest;
	}
	if ($compress) {
		$data = qxx (
			"cd $imageTree && find . | cpio @cpio | $main::Gzip -f > $dest"
		);
	} else {
		$data = qxx (
			"rm -f $dest && cd $imageTree && find . | cpio @cpio > $dest"
		);
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
	# Note: vmx|xen|pxe images requires the same steps than USB
	# images. Therefore this function is used inside the
	# createImageVMX(), createImagePXE() and createImageXen()
	# functions too 
	# ---
	#==========================================
	# Create usb|vmx|xen|pxe system image
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
			} else {
				$ok = $this -> setupLogicalExtend();
			}
			$result{imageTree} = $imageTree;
			last SWITCH;
		};
		/^ext3/       && do {
			$ok = 1;
			if ($text ne "VMX") {
				$ok = $this -> createImageEXT3 ();
			} else {
				$ok = $this -> setupLogicalExtend();
			}
			$result{imageTree} = $imageTree;
			last SWITCH;
		};
		/^reiserfs/   && do {
			$ok = 1;
			if ($text ne "VMX") {
				$ok = $this -> createImageReiserFS ();
			} else {
				$ok = $this -> setupLogicalExtend();
			}
			$result{imageTree} = $imageTree;
			last SWITCH;
		};
		/^squashfs/   && do {
			$ok = $this -> createImageSquashFS ();
			last SWITCH;
		};
		/^cromfs/     && do {
			$ok = $this -> createImageCromFS ();
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
	# Prepare usb|vmx|xen|pxe boot image
	#------------------------------------------
	$kiwi -> info ("Creating $text boot image: $boot...\n");
	my $Prepare = $imageTree."/image";
	my $xml = new KIWIXML (
		$kiwi,$Prepare,undef,$main::SetImageType,\@main::Profiles
	);
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
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"oem-swap"}       = $xml -> getOEMSwap();
	$main::ForeignRepo{"oem-swapsize"}   = $xml -> getOEMSwapSize();
	$main::ForeignRepo{"oem-systemsize"} = $xml -> getOEMSystemSize();
	$main::ForeignRepo{"oem-home"}       = $xml -> getOEMHome();
	$main::ForeignRepo{"oem-boot-title"} = $xml -> getOEMBootTitle();
	$main::ForeignRepo{"oem-kiwi-initrd"}= $xml -> getOEMKiwiInitrd();
	$main::ForeignRepo{"oem-reboot"}     = $xml -> getOEMReboot();
	$main::ForeignRepo{"oem-recovery"}   = $xml -> getOEMRecovery();
	$main::ForeignRepo{"locale"}  = $xml -> getLocale();
	$main::ForeignRepo{"prepare"} = $main::Prepare;
	$main::ForeignRepo{"create"}  = $main::Create;
	$main::Compress = "no";
	$main::Create   = $main::RootTree;
	my $imageTypeSaved = $main::SetImageType;
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
			my $lookup = basename $pinitrd;
			if (-f "$main::Destination/$lookup") {
				# prebuilt boot image already exists in destination dir...
				$kiwi -> done();
				$pblt = 1;
			} else {
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
	}
	if (! $pblt) {
		#==========================================
		# build the usb|vmx|xen|pxe boot image
		#------------------------------------------
		undef @main::AddPackage;
		undef $main::Upgrade;
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
	# setup initrd name
	#------------------------------------------
	my $initrd = $main::Destination."/".$main::ImageName.".gz";
	if (! -f $initrd) {
		$initrd = $main::Destination."/".$main::ImageName;
	}
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if (defined $main::CheckKernel) {
		if (! $this -> checkKernel ($initrd,$imageTree)) {
			return undef;
		}
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $kboot  = new KIWIBoot ($kiwi,$initrd);
	if (! defined $kboot) {
		return undef;
	}
	$kboot -> setupSplash();
	$kboot -> cleanTmp();
	#==========================================
	# Store meta data for subsequent calls
	#------------------------------------------
	$main::SetImageType = $imageTypeSaved;
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
	# Supported formats are: vvfat vpc bochs dmg vmdk qcow cow raw
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
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my %vmwc = $xml  -> getVMwareConfig ();
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
	if (defined $main::BootVMFormat) {
		#==========================================
		# VMware virtual disk description
		#------------------------------------------
		my $vmxfile; 
		if ($main::BootVMFormat =~ "vmdk|ovf") {
			# VMware vmx file...
			$vmxfile = $this -> buildVMwareConfig (
				$main::Destination,$name,\%vmwc
			);
			if (! $vmxfile) {
				$main::Survive = "default";
				return undef;
			}
		}
		#==========================================
		# VMware open virtual format image
		#------------------------------------------
		if ($main::BootVMFormat eq "ovf") {
			# VMware ovf file...
			# in case of the ovf format we need to call the ovftool from
			# VMware. The tool is able to convert from a vmx into an ovf
			# ----
			$kiwi -> info ("Creating OVF image...");
			my $ovffile = $vmxfile;
			my $ovflog  = $kiwi -> getRootLog();
			my $ovftool = "/usr/bin/ovftool";
			if (! -x $ovftool) {
				$kiwi -> failed ();
				$kiwi -> error  ("Can't find $ovftool, is it installed ?");
				$kiwi -> failed ();
				$main::Survive = "default";
				return undef;
			}
			$ovffile =~ s/\.vmx$/\.ovf/;
			my $status;
			if (! $ovflog) {
				$status= qxx ("$ovftool -bf $vmxfile $ovffile 2>&1");
			} else {
				$status= qxx ("$ovftool -bf $vmxfile $ovffile -l $ovflog 2>&1");
			}
			my $result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create OVF image: $status");
				$kiwi -> failed ();
				$main::Survive = "default";
				return undef;
			}
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
	my %xenc = $xml  -> getXenConfig();
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
# makeLabel
#------------------------------------------
sub makeLabel {
	# ...
	# isolinux does not handle spaces, so we replace it
	# with this unicode non-breaking space
	# ----
	my $this = shift;
	my $label = shift;
	$label =~ s/ /\x{00a0}/g;
	return $label;
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
	# 5) Create the iso image using isolinux shell script
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
	my $pxboot;
	#==========================================
	# Get system image name
	#------------------------------------------
	my $systemName = $sxml -> getImageName();
	my $systemDisplayName = $sxml -> getImageDisplayName();
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
	# Check for config-cdroot and move it
	#------------------------------------------
	my $cdrootData = "config-cdroot.tgz";
	if (-f $imageTree."/image/".$cdrootData) {
		qxx ("mv $imageTree/image/$cdrootData $imageDest");
	}
	#==========================================
	# Check for config-cdroot.sh and move it
	#------------------------------------------
	my $cdrootScript = "config-cdroot.sh";
	if (-x $imageTree."/image/".$cdrootScript) {
		qxx ("mv $imageTree/image/$cdrootScript $imageDest");
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
				$this -> restoreCDRootData();
				return undef;
			}
			my @rodirs = qw (bin boot lib lib64 opt sbin usr);
			foreach my $dir (@rodirs) {
				if (! -d "$imageTree/$dir") {
					next;
				}
				$data = qxx ("mv $imageTree/$dir $imageTreeReadOnly 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("Couldn't setup ro directory: $data");
					$kiwi -> failed ();
					$this -> restoreCDRootData();
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
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			return undef;
		}
		$kiwi -> done ();
		#==========================================
		# Create EXT2 filesystem on RW extend
		#------------------------------------------
		my $setBlockSize = 0;
		if (! defined $main::FSBlockSize) {
			$main::FSBlockSize = 4096;
			$setBlockSize = 1;
		}
		if (! $this -> setupEXT2 ( $namerw,$imageTree )) {
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			return undef;
		}
		if ($setBlockSize) {
			undef $main::FSBlockSize;
		}
		#==========================================
		# mount logical extend for data transfer
		#------------------------------------------
		my $extend = $this -> mountLogicalExtend ($namerw);
		if (! defined $extend) {
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			return undef;
		}
		#==========================================
		# copy physical to logical
		#------------------------------------------
		if (! $this -> installLogicalExtend ($extend,$imageTree)) {
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			return undef;
		}
		$this -> cleanMount();
	}
	#==========================================
	# Create compressed filesystem on RO extend
	#------------------------------------------
	if (defined $gzip) {
		SWITCH: for ($gzip) {
			/^compressed$/ && do {
				if (! $this -> createImageSplit ("ext3,squashfs", 1)) {
					$this -> restoreCDRootData();
					return undef;
				}
				$namero = $namerw;
				last SWITCH;
			};
			/^compressed-cromfs$/ && do {
				if (! $this -> createImageSplit ("ext3,cromfs", 1)) {
					$this -> restoreCDRootData();
					return undef;
				}
				$namero = $namerw;
				last SWITCH;
			};
			/^unified$/ && do {
				$kiwi -> info ("Creating squashfs read only filesystem...");
				if (! $this -> setupSquashFS ( $namero,$imageTree )) {
					$this -> restoreCDRootData();
					$this -> restoreSplitExtend ();
					return undef;
				}
				$kiwi -> done();
				last SWITCH;
			};
			/^unified-cromfs$/ && do {
				$kiwi -> info ("Creating cromfs read only filesystem...");
				if (! $this -> setupCromFS ( $namero,$imageTree )) {
					$this -> restoreCDRootData();
					$this -> restoreSplitExtend ();
					return undef;
				}
				$kiwi -> done();
				last SWITCH;
			};
			# invalid flag setup...
			$kiwi -> error  ("Invalid iso flags: $gzip");
			$kiwi -> failed ();
			return undef;
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
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			return undef;
		}
		#==========================================
		# Restoring physical extend
		#------------------------------------------
		if (! $this -> restoreSplitExtend ()) {
			$this -> restoreCDRootData();
			return undef;
		}
		#==========================================
		# compress RW extend
		#------------------------------------------
		if (! $this -> compressImage ($namerw)) {
			$this -> restoreCDRootData();
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
			$this -> restoreCDRootData();
			return undef;
		}
		my @rodirs = qw (bin boot lib lib64 opt sbin usr);
		foreach my $dir (@rodirs) {
			if (! -d "$imageTree/$dir") {
				next;
			}
			$data = qxx ("cp -a $imageTree/$dir $imageTreeReadOnly 2>&1");
			$code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't setup ro directory: $data");
				$kiwi -> failed ();
				$this -> restoreCDRootData();
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
		$this -> restoreCDRootData();
		return undef;
	}
	my $tmpdir = qxx (" mktemp -q -d /tmp/kiwi-cdboot.XXXXXX "); chomp $tmpdir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		$this -> restoreCDRootData();
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
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"locale"}  = $xml -> getLocale();
	$main::ForeignRepo{"prepare"} = $main::Prepare;
	$main::ForeignRepo{"create"}  = $main::Create;
	$main::Create = $main::RootTree;
	$xml = new KIWIXML ( $kiwi,$main::Prepare );
	if (! defined $xml) {
		return undef;
	}
	my $iso = $xml -> getImageName();
	my $ver = $xml -> getImageVersion();
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
		$pinitrd = glob ("$lookup/$iso$arch-$ver.gz");
		$plinux  = glob ("$lookup/$iso$arch-$ver.kernel");
		$pxboot  = glob ("$lookup/$iso$arch-$ver*xen.gz");
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
		# build the isoboot boot image
		#------------------------------------------
		undef @main::AddPackage;
		undef $main::Upgrade;
		if (! defined main::main()) {
			$main::Survive = "default";
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			$this -> restoreCDRootData();
			return undef;
		}
	}
	$main::Survive = "default";
	undef %main::ForeignRepo;
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if (defined $main::CheckKernel) {
		my $initrd = $pinitrd;
		if (! $pblt) {
			$initrd = "$imageDest/$iso$arch-$ver.gz";
		}
		if (! $this -> checkKernel ($initrd,$imageTree)) {
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			$this -> restoreCDRootData();
			return undef;
		}
	}
	#==========================================
	# Prepare for CD ISO image
	#------------------------------------------
	$kiwi -> info ("Creating CD filesystem");
	qxx ("mkdir -p $main::RootTree/CD/boot");
	$kiwi -> done ();

	#==========================================
	# Check for optional config-cdroot archive
	#------------------------------------------
	if (-f $imageDest."/".$cdrootData) {
		$kiwi -> info ("Integrating CD root information...");
		my $data= qxx ("tar -C $main::RootTree/CD -xvf $imageDest/$cdrootData");
		my $code= $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to integrate CD root data: $data");
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				qxx ("rm -rf $imageTreeReadOnly");
			}
			$this -> restoreCDRootData();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	if (-x $imageDest."/".$cdrootScript) {
		$kiwi -> info ("Calling CD root setup script...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $cdrootEnv = $imageTree."/.profile";
		if ($cdrootEnv !~ /^\//) {
			$cdrootEnv = $pwd."/".$cdrootEnv;
		}
		my $script = $imageDest."/".$cdrootScript;
		if ($script !~ /^\//) {
			$script = $pwd."/".$script;
		}
		my $CCD  = "$main::RootTree/CD";
		my $data = qxx (
			"cd $CCD && bash -c '. $cdrootEnv && . $script' 2>&1"
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
			$this -> restoreCDRootData();
			return undef;
		} else {
			$kiwi -> loginfo ("config-cdroot.sh: $data");
		}
		$kiwi -> done();
	}
	#==========================================
	# Restore CD root data and script
	#------------------------------------------
	$this -> restoreCDRootData();

	#==========================================
	# Installing second stage images
	#------------------------------------------
	$kiwi -> info ("Moving CD image data into boot structure");
	if (! defined $gzip) {
		qxx ("mv $imageDest/$namerw.md5 $main::RootTree/CD");
		qxx ("mv $imageDest/$namerw.gz $main::RootTree/CD");
		qxx ("rm $imageDest/$namerw.*");
	}
	if (defined $gzip) {
		qxx ("mv $imageDest/$namero $main::RootTree/CD");
		qxx ("rm $imageDest/$namero.*");
	} else {
		qxx ("mkdir -p $main::RootTree/CD/read-only-system");
		qxx ("mv $imageTreeReadOnly/* $main::RootTree/CD/read-only-system");
		rmdir $imageTreeReadOnly;
	}
	$kiwi -> done ();
	#==========================================
	# check for graphics boot files
	#------------------------------------------
	my $CD  = $main::Prepare."/root/";
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
	# check if Xen kernel is used
	#------------------------------------------
	my $isxen = 0;
	my $xboot = glob ("$imageDest/$iso$arch-$ver*xen.gz");
	if (-f $xboot) {
		$isxen = 1;
	}
	#==========================================
	# copy boot kernel and initrd
	#------------------------------------------
	$kiwi -> info ("Copying boot image and kernel [$isoarch]");
	my $destination = "$main::RootTree/CD/boot/$isoarch/loader";
	qxx ("mkdir -p $destination");
	if ($pblt) {
		$data = qxx ("cp $pinitrd $destination/initrd 2>&1");
	} else {
		$data = qxx (
			"cp $imageDest/$iso$arch-$ver.gz $destination/initrd 2>&1"
		);
	}
	$code = $? >> 8;
	if ($code == 0) {
		if ($pblt) {
			$data = qxx ("cp $plinux $destination/linux 2>&1");
		} else {
			$data = qxx (
				"cp $imageDest/$iso$arch-$ver.kernel $destination/linux 2>&1"
			);
		}
		$code = $? >> 8;
	}
	if (($code == 0) && ($isxen)) {
		if ($pblt) {
			$data = qxx ("cp $pxboot $destination/xen.gz 2>&1");
		} else {
			$data = qxx (
				"cp $xboot $destination/xen.gz 2>&1"
			);
		}
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Copy of isolinux boot files failed: $data");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# copy base graphics boot CD files
	#------------------------------------------
	$kiwi -> info ("Setting up isolinux boot CD [$isoarch]");
	$data = qxx ("cp -a $gfx/* $destination");
	$code = $? >> 8;
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
	my $label = $this->makeLabel ("$systemDisplayName");
	my $lsafe = $this->makeLabel ("Failsafe -- $label");
	#==========================================
	# setup isolinux.cfg file
	#------------------------------------------
	$kiwi -> info ("Creating isolinux configuration...");
	if (! open (FD, ">$destination/isolinux.cfg")) {
		$kiwi -> failed();
		$kiwi -> error  ("Failed to create $destination/isolinux.cfg: $!");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	binmode(FD, ":utf8");
	print FD "default $label"."\n";
	print FD "implicit 1"."\n";
	print FD "gfxboot  bootlogo"."\n";
	print FD "display  isolinux.msg"."\n";
	print FD "prompt   1"."\n";
	print FD "timeout  200"."\n";
	if (! $isxen) {
		print FD "label $label"."\n";
		print FD "  kernel linux"."\n";
		print FD "  append initrd=initrd ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent showopts"."\n";
		print FD "\n";
		print FD "label $lsafe"."\n";
		print FD "  kernel linux"."\n";
		print FD "  append initrd=initrd ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent showopts ";
		print FD "ide=nodma apm=off acpi=off noresume selinux=0 nosmp ";
		print FD "noapic maxcpus=0 edd=off"."\n";
	} else {
		print FD "label $label"."\n";
		print FD "  kernel mboot.c32"."\n";
		print FD "  append xen.gz --- linux ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent ";
		print FD "--- initrd showopts"."\n";
		print FD "\n";
		print FD "label $lsafe"."\n";
		print FD "  kernel mboot.c32"."\n";
		print FD "  append xen.gz --- linux ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent ";
		print FD "ide=nodma apm=off acpi=off noresume selinux=0 nosmp ";
		print FD "noapic maxcpus=0 edd=off ";
		print FD "--- initrd showopts"."\n";
	}
	#==========================================
	# setup isolinux checkmedia boot entry
	#------------------------------------------
	if (defined $main::ISOCheck) {
		print FD "\n";
		if (! $isxen) {
			print FD "label mediacheck"."\n";
			print FD "  kernel linux"."\n";
			print FD "  append initrd=initrd splash=silent mediacheck=1 ";
			print FD "showopts"."\n";
		} else {
			print FD "label mediacheck"."\n";
			print FD "  kernel mboot.c32"."\n";
			print FD "  append xen.gz --- linux splash=silent mediacheck=1 ";
			print FD "--- initrd showopts"."\n";
		}
	}
	#==========================================
	# setup default harddisk/memtest entries
	#------------------------------------------
	print FD "\n";
	print FD "label " . $this->makeLabel ("Boot From Hard Disk") . "\n";
	print FD "  localboot 0x80"."\n";
	print FD "\n";
	print FD "label memtest"."\n";
	print FD "  kernel memtest"."\n";
	print FD "\n";
	close FD;
	#==========================================
	# setup isolinux.msg file
	#------------------------------------------
	if (! open (FD,">$destination/isolinux.msg")) {
		$kiwi -> failed();
		$kiwi -> error  ("Failed to create isolinux.msg: $!");
		$kiwi -> failed ();
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	print FD "\n"."Welcome !"."\n\n";
	print FD "To start the system enter '".$label."' and press <return>"."\n";
	print FD "\n\n";
	print FD "Available boot options:\n";
	print FD "$label     - Live System"."\n";
	print FD "$lsafe     - Live System failsafe mode"."\n";
	print FD "Hard-Disk  - Local boot from hard disk"."\n";
	print FD "mediacheck - Media check"."\n";
	print FD "memtest    - Memory Test"."\n";
	print FD "\n";
	print FD "Have a lot of fun..."."\n";
	close FD;
	$kiwi -> done();
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
	if ((! defined $gzip) || ($gzip =~ /^unified/)) {
		print FD "IMAGE=/dev/ram1;$namecd\n";
	} else {
		print FD "IMAGE=/dev/loop1;$namecd\n";
	}
	if (defined $gzip) {
		if ($gzip =~ /^unified/) {
			print FD "UNIONFS_CONFIG=/dev/ram1,/dev/loop1,aufs\n";
		} else {
			print FD "COMBINED_IMAGE=yes\n";
		}
	}
	close FD;
	#==========================================
	# create ISO image
	#------------------------------------------
	$kiwi -> info ("Calling mkisofs...\n");
	my $isoerror = 1;
	my $name = $imageDest."/".$namerw.".iso";
	my $isolinux = new KIWIIsoLinux (
		$kiwi,$main::RootTree."/CD",$name
	);
	if (defined $isolinux) {
		$isoerror = 0;
		if (! $isolinux -> createSortFile()) {
			$isoerror = 1;
		}
		if (! $isolinux -> createISOLinuxConfig()) {
			$isoerror = 1;
		}
		if (! $isolinux -> createISO()) {
			$isoerror = 1;
		}
	}
	if ($isoerror) {
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	#==========================================
	# relocate boot catalog
	#------------------------------------------
	if (! relocateCatalog ($this,$name)) {
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	#==========================================
	# tag ISO image with tagmedia
	#------------------------------------------
	if (-x "/usr/bin/tagmedia") {
		$kiwi -> info ("Adding checkmedia tag...");
		$data = qxx ("tagmedia --md5 --check $name 2>&1");
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to tag ISO image: $data");
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
			}
			return undef;
		}
		$kiwi -> done();
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
	my $treebase;
	#==========================================
	# turn image path into absolute path
	#------------------------------------------
	if ($imageTree !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$imageTree = $pwd."/".$imageTree;
	}
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
	# Create clone of prepared tree
	#------------------------------------------
	$kiwi -> info ("Creating root tree clone for split operations");
	$treebase = basename $imageTree;
	if (-d $imageDest."/".$treebase) {
		qxx ("rm -rf $imageDest/$treebase");
	}
	$data = qxx ("cp -a $imageTree $imageDest");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Can't create copy of image tree: $data");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTree");
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# split physical extend into RW/RO/tmp part
	#------------------------------------------
	$imageTree    = $imageDest."/".$treebase;
	$imageTreeTmp = $imageTree;
	$imageTreeTmp =~ s/\/+$//;
	$imageTreeTmp.= "-tmp/";
	$this->{imageTreeTmp} = $imageTreeTmp;
	my @persistFiles = $sxml -> getSplitPersistentFiles ();
	my @exceptFiles  = $sxml -> getSplitExceptions ();
	my %exceptHash;
	my %persistDir;
	#==========================================
	# walk through except files if any
	#------------------------------------------
	foreach my $except (@exceptFiles) {
		my $globsource = "${imageTree}${except}";
		my @files = glob($globsource);
		foreach my $file (@files) {
			#==========================================
			# find except files to set read-only
			#------------------------------------------
			if (! -e $file) {
				next;
			}
			my $rerooted = $file;
			$rerooted =~ s#$imageTree#/read-only/#;
			my $tmpdest = $file;
			$tmpdest =~ s#$imageTree#$imageTreeTmp#;
			$exceptHash{$tmpdest} = $rerooted;
			#==========================================
			# check file dirname in persistent list 
			#------------------------------------------
			my $tdir = dirname $tmpdest;
			$tdir =~ s#$imageTreeTmp##;
			foreach my $persist (@persistFiles) {
				if (($persist eq $tdir) && (! $persistDir{$persist})) {
					$persistDir{$persist} = $persist;
					last;
				}
			}
		}
	}
	#==========================================
	# reordering persistent directory list
	#------------------------------------------
	foreach my $pdir (keys %persistDir) {
		my $dir = "${imageTree}${pdir}";
		my @res = ();
		if (! opendir (FD,$dir)) {
			$kiwi -> warning ("Can't open directory: $dir: $!");
			$kiwi -> skipped ();
			next;
		}
		while (my $entry = readdir (FD)) {
			next if ($entry =~ /^\.+$/);
			if (-d $imageTree.$pdir."/".$entry) {
				push @res,$pdir."/".$entry;
			}
		}
		closedir (FD);
		my @newlist = ();
		push @persistFiles,@res;
		foreach my $entry (@persistFiles) {
			if ($entry ne $pdir) {
				push @newlist,$entry;
			}
		}
		@persistFiles = @newlist;
	}
	#==========================================
	# run split tree creation
	#------------------------------------------
	if (! -d $imageTreeTmp) {
		$kiwi -> info ("Creating temporary image part");
		if (! mkdir $imageTreeTmp) {
			$error = $!;
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create tmp directory: $error");
			$kiwi -> failed ();
			qxx ("rm -rf $imageTree");
			return undef;
		}
		my $createTmpTree = sub {
			my $file  = $_;
			my $dir   = $File::Find::dir;
			my $path  = "$dir/$file";
			my $target= $path;
			$target =~ s#$imageTree#$imageTreeTmp#;
			my $rerooted = $path;
			$rerooted =~ s#$imageTree#/read-only/#;
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
					qxx ("mv $file $dest");
				}
			}
		}
		#==========================================
		# handle optional exceptions
		#------------------------------------------
		if (@exceptFiles) {
			foreach my $except (keys %exceptHash) {
				qxx ("rm -rf $except");
				symlink ($exceptHash{$except},$except);
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
			qxx ("rm -rf $imageTree");
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
			if ($exceptHash{$file}) {
				# /.../
				# don't handle this file for read-write
				# because of an exception
				# ----
				next;
			}
			my $source  = $file;
			my $rosource= $file;
			my $dest    = $file;
			my $rwroot  = $file;
			$rosource   =~ s#$imageTreeTmp#$imageTree#;
			$dest       =~ s#$imageTreeTmp#$imageTreeRW#;
			$rwroot     =~ s#$imageTreeTmp#/read-write/#;
			my $destdir = dirname $dest;
			qxx ("rm -rf $dest");
			qxx ("mkdir -p $destdir");
			if (-d $source) {
				qxx ("mv $source $dest");
				symlink ($rwroot, $source);
			} else {
				qxx ("mv $rosource $dest");
				qxx ("rm -f $source");
				symlink ($rwroot, $source);
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Embed tmp extend into ro extend
	#------------------------------------------
	qxx ("cd $imageTreeTmp && tar cvf $imageTree/rootfs.tar * 2>&1");
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
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
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
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			return undef;
		}
		if (! $ok) {
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			return undef;
		}
	}
	#==========================================
	# Create RO logical extend
	#------------------------------------------
	$kiwi -> info ("Image RO part requires $mbytesro MB of disk space");
	if (! $this -> buildLogicalExtend ($namero,$mbytesro."M")) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
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
		/cromfs/     && do {
			$ok = $this -> setupCromFS ( $namero,$imageTree );
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $FSTypeRO");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		return undef;
	}
	if (! $ok) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
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
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
				return undef;
			}
			#==========================================
			# copy physical to logical
			#------------------------------------------
			if (! $this -> installLogicalExtend ($extend,$source)) {
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
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
			/cromfs/     && do {
				$kiwi -> done ();
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type");
			$kiwi -> failed ();
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			return undef;
		}
		#==========================================
		# Create image md5sum
		#------------------------------------------
		if (! $this -> buildMD5Sum ($name)) {
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			return undef;
		}
	}
	#==========================================
	# Create network boot configuration
	#------------------------------------------
	$kiwi -> info ("Creating boot configuration...");
	if (! $this -> writeImageConfig ($namero)) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		return undef;
	}
	#==========================================
	# Cleanup temporary data
	#------------------------------------------
	qxx ("rm -rf $imageTreeRW");
	qxx ("rm -rf $imageTree");
	#==========================================
	# build boot image only if specified
	#------------------------------------------
	$name->{systemImage} = $main::ImageName;
	if (! defined $boot) {
		return $this;
	}
	#==========================================
	# Prepare and Create boot image
	#------------------------------------------
	$imageTree = $this->{imageTree};
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
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"oem-swap"}       = $xml -> getOEMSwap();
	$main::ForeignRepo{"oem-swapsize"}   = $xml -> getOEMSwapSize();
	$main::ForeignRepo{"oem-systemsize"} = $xml -> getOEMSystemSize();
	$main::ForeignRepo{"oem-home"}       = $xml -> getOEMHome();
	$main::ForeignRepo{"oem-boot-title"} = $xml -> getOEMBootTitle();
	$main::ForeignRepo{"oem-kiwi-initrd"}= $xml -> getOEMKiwiInitrd();
	$main::ForeignRepo{"oem-reboot"}     = $xml -> getOEMReboot();
	$main::ForeignRepo{"oem-recovery"}   = $xml -> getOEMRecovery();
	$main::ForeignRepo{"locale"}  = $xml -> getLocale();
	$main::ForeignRepo{"prepare"} = $main::Prepare;
	$main::ForeignRepo{"create"}  = $main::Create;
	$main::Create = $main::RootTree;
	$xml = new KIWIXML ( $kiwi,$main::Prepare );
	if (! defined $xml) {
		return undef;
	}
	my $iname = $xml -> getImageName();
	my $imageTypeSaved = $main::SetImageType;
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
		# build the split boot image
		#------------------------------------------
		undef @main::AddPackage;
		undef $main::Upgrade;
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
	# setup initrd name
	#------------------------------------------
	my $initrd = $main::Destination."/".$main::ImageName.".gz";
	if (! -f $initrd) {
		$initrd = $main::Destination."/".$main::ImageName;
	}
	#==========================================
	# Check boot and system image kernel
	#------------------------------------------
	if (defined $main::CheckKernel) {
		if (! $this -> checkKernel ($initrd,$imageTree)) {
			return undef;
		}
	}
	#==========================================
	# Include splash screen to initrd
	#------------------------------------------
	my $kboot  = new KIWIBoot ($kiwi,$initrd);
	if (! defined $kboot) {
		return undef;
	}
	$kboot -> setupSplash();
	$kboot -> cleanTmp();
	#==========================================
	# Check further actions due to boot image
	#------------------------------------------
	$main::SetImageType = $imageTypeSaved;
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
			my %vmwc = $sxml -> getVMwareConfig ();
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
	my $nozip= shift;
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
	if ($type{filesystem}) {
		$kiwi -> info ("Checking file system: $type{filesystem}...");
	} else {
		$kiwi -> info ("Checking file system: $type{type}...");
	}
	SWITCH: for ($para) {
		#==========================================
		# Check EXT3 file system
		#------------------------------------------
		/ext3|ec2/i && do {
			qxx ("/sbin/fsck.ext3 -f -y $imageDest/$name 2>&1");
			qxx ("/sbin/tune2fs -j $imageDest/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT2 file system
		#------------------------------------------
		/ext2/i     && do {
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
	if (! defined $nozip) {
		if ($xml->getCompressed()) {
			if (! $this -> compressImage ($name)) {
				return undef;
			}
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
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	mkdir "$imageDest/mnt-$$";
	my $mount = "mount";
	if (defined $opts) {
		$mount = "mount $opts";
	}
	my $data= qxx (
		"$mount -o loop $imageDest/$name $imageDest/mnt-$$ 2>&1"
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
	# if the file vmlinux[.gz] exists which was created by the
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
		/cromfs/i   && do {
			return $name;
			last SWITCH;
		};
	}
	#==========================================
	# this is a boot image, extract kernel
	#------------------------------------------
	return $this -> extractLinux (
		$name,$imageTree,$imageDest
	);
}

#==========================================
# extractLinux
#------------------------------------------
sub extractLinux {
	my $this      = shift;
	my $name      = shift;
	my $imageTree = shift;
	my $imageDest = shift;
	my $kiwi      = $this->{kiwi};
	if ((-f "$imageTree/boot/vmlinux.gz") ||
		(-f "$imageTree/boot/vmlinux")    ||
		(-f "$imageTree/boot/vmlinuz")
	) {
		$kiwi -> info ("Extracting kernel...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $shortfile = "$name.kernel";
		my $file = "$imageDest/$shortfile";
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
		my $kfile;
		if (-f "$imageTree/boot/vmlinux.gz") {
			$kfile = "$imageTree/boot/vmlinux.gz";
		} elsif (-f "$imageTree/boot/xen.gz") {
			$kfile = "$imageTree/boot/xen.gz";
		} elsif (-f "$imageTree/boot/vmlinux") {
			$kfile = "$imageTree/boot/vmlinux";
		} elsif (-f "$imageTree/boot/vmlinuz") {
			$kfile = "$imageTree/boot/vmlinuz";
		} else {
			$kiwi -> failed ();
			$kiwi -> info   ("Couldn't find kernel file");
			$kiwi -> failed ();
			return undef;
		}
		my $kernel;
		$kernel = qxx ("/sbin/get_kernel_version $kfile"); chomp $kernel;
		qxx ("mv -f $file $file.$kernel && ln -s $shortfile.$kernel $file ");
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
	my $fsopts;
	if (! defined $tree) {
		$tree = $imageTree;
	}
	my %FSopts = main::checkFSOptions();
	if (defined $journal) {
		$fsopts = $FSopts{ext3};
		$fsopts.="-j -F";
	} else {
		$fsopts = $FSopts{ext2};
		$fsopts.= "-F";
	}
	my $data = qxx ("/sbin/mke2fs $fsopts $imageDest/$name 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create EXT2 filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	if (defined $journal) {
		$data = qxx ("cd $imageDest && ln -vs $name $name.ext3 2>&1");
	} else {
		$data = qxx ("cd $imageDest && ln -vs $name $name.ext2 2>&1");
	}
	$kiwi -> loginfo ($data);
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
	my %FSopts = main::checkFSOptions();
	my $fsopts = $FSopts{reiserfs};
	$fsopts.= "-f";
	my $data = qxx (
		"/sbin/mkreiserfs $fsopts $imageDest/$name 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create Reiser filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$data = qxx ("cd $imageDest && ln -vs $name $name.reiserfs 2>&1");
	$kiwi -> loginfo ($data);
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
	$data = qxx ("chmod 644 $imageDest/$name");
	$data = qxx ("cd $imageDest && ln -vs $name $name.squashfs 2>&1");
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# setupCromFS
#------------------------------------------
sub setupCromFS {
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
	my $data = qxx (
		"/usr/bin/mkcromfs --lzmabits 0,0,8 $tree $imageDest/$name 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create cromfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$data = qxx ("chmod 644 $imageDest/$name");
	$data = qxx ("cd $imageDest && ln -vs $name $name.cromfs 2>&1");
	$kiwi -> loginfo ($data);
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
	my $initrd = $name->{bootImage}.".splash.gz";
	my $irdunc = $name->{bootImage}.".splash";
	my $kernel = $dest."/".$name->{bootImage}.".kernel";
	$kernel    = readlink ($kernel);
	$kernel    = basename ($kernel);
	my %xenconfig = %{$xenref};
	$kiwi -> info ("Creating image Xen configuration file...");
	if (! %xenconfig) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Missing Xen virtualisation config data");
		$kiwi -> skipped ();
		return $dest;
	}
	if (! open (FD,">$file")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create xenconfig file: $!");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# inflate/deflate initrd to make xm happy
	#------------------------------------------
	qxx ("$main::Gzip -d $dest/$initrd && $main::Gzip $dest/$irdunc");
	#==========================================
	# global setup
	#------------------------------------------
	my $device = $xenconfig{xen_diskdevice};
	my $part   = $device."1";
	my $memory = $xenconfig{xen_memory};
	my $image  = $name->{systemImage};
	$part =~ s/\/dev\///;
	print FD '#  -*- mode: python; -*-'."\n";
	print FD 'kernel="'.$kernel.'"'."\n";
	print FD 'ramdisk="'.$initrd.'"'."\n";
	print FD 'memory='.$memory."\n";
	print FD 'disk=[ "file:'.$image.','.$part.',w" ]'."\n";
	#==========================================
	# network setup
	#------------------------------------------
	my $vifcount = -1;
	foreach my $bname (keys %{$xenconfig{xen_bridge}}) {
		$vifcount++;
		my $mac = $xenconfig{xen_bridge}{$bname};
		my $vif = '"bridge='.$bname.'"';
		if ($mac) {
			$vif = '"mac='.$mac.',bridge='.$bname.'"';
		}
		if ($vifcount == 0) {
			print FD "vif=[ ".$vif;
		} else {
			print FD ", ".$vif;
		}
	}
	if ($vifcount >= 0) {
		print FD " ]"."\n";
	}
	#==========================================
	# xen console
	#------------------------------------------
	print FD 'root="'.$part.' ro"'."\n";
	print FD 'extra=" xencons=tty "'."\n";
	close FD;
	$kiwi -> done();
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
	my $arch   = $this->{arch};
	my $file   = $dest."/".$name->{systemImage}.".vmx";
	my $image  = $name->{systemImage};
	my %vmwconfig = %{$vmwref};
	$kiwi -> info ("Creating image VMware configuration file...");
	if (! %vmwconfig) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Missing VMware virtualisation config data");
		$kiwi -> skipped ();
		return $dest;
	}
	if (! open (FD,">$file")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create xenconfig file: $!");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# global setup
	#------------------------------------------
	print FD '#!/usr/bin/vmware'."\n";
	print FD 'config.version = "8"'."\n";
	print FD 'tools.syncTime = "true"'."\n";
	print FD 'uuid.action = "create"'."\n";
	if ($vmwconfig{vmware_hwver}) {
		print FD 'virtualHW.version = "'.$vmwconfig{vmware_hwver}.'"'."\n";
	} else {
		print FD 'virtualHW.version = "4"'."\n";
	}
	print FD 'displayName = "'.$name->{systemImage}.'"'."\n";
	print FD 'memsize = "'.$vmwconfig{vmware_memory}.'"'."\n";
	print FD 'guestOS = "'.$vmwconfig{vmware_guest}.'"'."\n";
	#==========================================
	# storage setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_disktype}) {
		my $type   = $vmwconfig{vmware_disktype};
		my $device = $vmwconfig{vmware_disktype}.$vmwconfig{vmware_diskid};
		if ($type eq "ide") {
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
			print FD $device.':0.fileName = "'.$image.'.vmdk"'."\n";
			print FD $device.':0.deviceType = "scsi-hardDisk"'."\n";
		}
	}
	#==========================================
	# network setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_niciface}) {
		my $driver = $vmwconfig{vmware_nicdriver};
		my $mode   = $vmwconfig{vmware_nicmode};
		my $nic    = "ethernet".$vmwconfig{vmware_niciface};
		print FD $nic.'.present = "true"'."\n";
		print FD $nic.'.virtualDev = "'.$driver.'"'."\n";
		print FD $nic.'.addressType = "generated"'."\n";
		print FD $nic.'.connectionType = "'.$mode.'"'."\n";
		if ($vmwconfig{vmware_arch} =~ /64$/) {
			print FD $nic.'.allow64bitVmxnet = "true"'."\n";
		}
	}
	#==========================================
	# CD/DVD drive setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_cdtype}) {
		my $device = $vmwconfig{vmware_cdtype}.$vmwconfig{vmware_cdid};
		print FD $device.':0.present = "true"'."\n";
		print FD $device.':0.deviceType = "cdrom-raw"'."\n";
		print FD $device.':0.autodetect = "true"'."\n";
		print FD $device.':0.startConnected = "true"'."\n";
	}
	#==========================================
	# USB setup
	#------------------------------------------
	if (defined $vmwconfig{vmware_usb}) {
		print FD 'usb.present = "true"'."\n";
	}
	#==========================================
	# Power Management setup
	#------------------------------------------
	print FD 'priority.grabbed = "normal"'."\n";
	print FD 'priority.ungrabbed = "normal"'."\n";
	print FD 'powerType.powerOff = "soft"'."\n";
	print FD 'powerType.powerOn  = "soft"'."\n";
	print FD 'powerType.suspend  = "soft"'."\n";
	print FD 'powerType.reset    = "soft"'."\n";
	close FD;
	$kiwi -> done();
	return $file;
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
		last if ($blocksize * $factor > 65464);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qxx ("cat $imageDest/$name | md5sum - | cut -f 1 -d-");
	chomp $sum;
	if ($name =~ /\.gz$/) {
		$name =~ s/\.gz//;
	}
	qxx ("echo \"$sum $blocks $blocksize\" > $imageDest/$name.md5");
	$this->{md5file} = $imageDest."/".$name.".md5";
	$kiwi -> done();
	return $name;
}

#==========================================
# restoreCDRootData
#------------------------------------------
sub restoreCDRootData {
	my $this = shift;
	my $imageTree    = $this->{imageTree};
	my $imageDest    = $this->{imageDest};
	my $cdrootData   = "config-cdroot.tgz";
	my $cdrootScript = "config-cdroot.sh";
	if (-f $imageDest."/".$cdrootData) {
		qxx ("mv $imageDest/$cdrootData $imageTree/image");
	}
	if (-f $imageDest."/".$cdrootScript) {
		qxx ("mv $imageDest/$cdrootScript $imageTree/image");
	}
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
	my @rodirs = qw (bin boot lib lib64 opt sbin usr);
	foreach my $dir (@rodirs) {
		if (! -d "$imageTreeReadOnly/$dir") {
			next;
		}
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
	#==========================================
	# Update md5file
	#------------------------------------------
	if (defined $this->{md5file}) {
		$kiwi -> info ("Updating md5 file...");
		if (! open (FD,$this->{md5file})) {
			$kiwi -> failed ();
			$kiwi -> error ("Failed to open md5 file: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $line = <FD>; close FD; chomp $line;
		my $size = -s "$imageDest/$name.gz";
		my $primes = qxx ("factor $size"); $primes =~ s/^.*: //;
		my $blocksize = 1;
		for my $factor (split /\s/,$primes) {
			last if ($blocksize * $factor > 65464);
			$blocksize *= $factor;
		}
		my $blocks = $size / $blocksize;
		my $md5file= $this->{md5file};
		qxx ("echo \"$line $blocks $blocksize\" > $md5file");
		$kiwi -> done();
	}
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
	$size += $xml -> getImageSizeAdditiveBytes() / 1024;
	$size /= 1024;
	$size = int ($size);
	my $xmlsize = $xml -> getImageSize();
	if ($xmlsize eq "auto") {
		$xmlsize = $size;
	}
	return ($orig,$size,$xmlsize);
}

#==========================================
# checkKernel
#------------------------------------------
sub checkKernel {
	# ...
	# this function receives two parameters. The initrd image
	# file and the system image tree directory path. It checks
	# whether at least one kernel matches both, the initrd and
	# the system image. If not the function tries to copy the
	# kernel from the system image into the initrd. If the
	# system image specifies more than one kernel an error
	# is printed pointing out that the boot image needs to
	# specify one of the found system image kernels
	# ---
	my $this    = shift;
	my $initrd  = shift;
	my $systree = shift;
	my $kiwi    = $this->{kiwi};
	my $arch    = $this->{arch};
	my %sysk    = ();
	my %bootk   = ();
	my $status;
	my $tmpdir;
	#==========================================
	# find system image kernel(s)
	#------------------------------------------
	foreach my $dir (glob ("$systree/lib/modules/*")) {
		if ($dir =~ /-debug$/) {
			next;
		}
		$dir =~ s/$systree\///;
		$sysk{$dir} = "system-kernel";
	}
	if (! %sysk) {
		$kiwi -> error  ("Can't find any system image kernel");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# find boot image kernel
	#------------------------------------------
	my $cmd = "cat $initrd";
	my $zip = 0;
	if ($initrd =~ /\.gz$/) {
		$cmd = "$main::Gzip -cd $initrd";
		$zip = 1;
	}
	my @status = qxx ("$cmd|cpio -it --quiet 'lib/modules/*'|cut -f1-3 -d/");
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Can't find any boot image kernel");
		$kiwi -> failed ();
		return undef;
	}
	foreach my $module (@status) {
		chomp $module;
		$bootk{$module} = "boot-kernel";
	}
	if (! %bootk) {
		$kiwi -> error  ("Can't find any boot image kernel");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# search system image kernel in initrd 
	#------------------------------------------
	foreach my $system (keys %sysk) {
		if ($bootk{$system}) {
			# found system image kernel in initrd, ok
			return $this;
		}
	}
	#==========================================
	# check system image kernel count
	#------------------------------------------
	if (keys %sysk > 1) {
		$kiwi -> error  ("*** kernel check failed ***");
		$kiwi -> failed ();
		$kiwi -> note ("Can't find a system kernel matching the initrd\n");
		$kiwi -> note ("multiple system kernels were found, make sure your\n");
		$kiwi -> note ("boot image includes the intended kernel\n");
		return undef;
	}
	#==========================================
	# fix kernel inconsistency:
	#------------------------------------------
	$kiwi -> info ("Fixing kernel inconsistency...");
	$tmpdir = qxx ("mktemp -q -d /tmp/kiwi-fixboot.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
    # 1) unpack initrd...
    #------------------------------------------
	$status = qxx ("cd $tmpdir && $cmd|cpio -i --quiet");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't unpack initrd: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $tmpdir");
		return undef;
	}
	#==========================================
	# 2) create images.sh script...
	#------------------------------------------
	if (! open (FD,">$tmpdir/images.sh")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create image.sh file: $!");
		$kiwi -> failed ();
		qxx ("rm -rf $tmpdir");
		return undef;
	}
	print FD '#!/bin/sh'."\n";
	print FD 'test -f /.kconfig && . /.kconfig'."\n";
	print FD 'test -f /.profile && . /.profile'."\n";
	print FD 'echo "*** Fixing kernel inconsistency ***"'."\n";
	print FD 'suseStripKernel'."\n";
	print FD 'exit 0'."\n";
	close FD;
	#==========================================
	# 3) copy system kernel to initrd...
	#------------------------------------------
	qxx ("rm -rf $tmpdir/boot");
	qxx ("cp -a  $systree/boot $tmpdir");
	qxx ("rm -rf $tmpdir/lib/modules");
	qxx ("cp -a  $systree/lib/modules $tmpdir/lib");
	qxx ("cp $main::BasePath/modules/KIWIConfig.sh $tmpdir/.kconfig");
	qxx ("chmod u+x $tmpdir/images.sh");
	#==========================================
	# 4) call images.sh script...
	#------------------------------------------
	$status = qxx ("chroot $tmpdir /images.sh 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ($status);
		qxx ("rm -rf $tmpdir");
		return undef;
	} else {
		$kiwi -> loginfo ("images.sh: $status");
	}
	$kiwi -> done();
	#==========================================
	# 5) extract kernel files...
	#------------------------------------------
	my $xml  = new KIWIXML ($kiwi,$tmpdir."/image");
	my $name = $xml -> getImageName();
	my $iver = $xml -> getImageVersion();
	my $dest = dirname $initrd;
	$name = $name.$arch."-".$iver;
	qxx ("rm -f $dest/$name*");
	if (! $this -> extractLinux ($name,$tmpdir,$dest)) {
		qxx ("rm -rf $tmpdir");
		return undef;
	}
	#==========================================
	# 6) rebundle initrd...
	#------------------------------------------
	my @cpio = ("--create", "--format=newc", "--quiet");
	$status = qxx ( "cd $tmpdir && find . | cpio @cpio > $dest/$name");
	if ($zip) {
		$status = qxx (
			"cd $tmpdir && cat $dest/$name | $main::Gzip -f > $initrd"
		);
	} 
	#==========================================
	# 7) recreate md5 file...
	#------------------------------------------
	my $origDest = $this->{imageDest};
	$this->{imageDest} = $dest;
	if (! $this -> buildMD5Sum ($name)) {
		$this->{imageDest} = $origDest;
		qxx ("rm -rf $tmpdir");
		return undef;
	}
	$this->{imageDest} = $origDest;
	qxx ("rm -rf $tmpdir");
	return $this;
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	my $this = shift;
	my $imageDest = $this->{imageDest};
	qxx ("umount $imageDest/mnt-$$ 2>&1");
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
