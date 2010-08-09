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
use POSIX qw(getcwd);
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
	# Use absolute path for image destination
	#------------------------------------------
	if ($imageDest !~ /^\//) {
		my $pwd = getcwd();
		$imageDest = $pwd."/".$imageDest;
	}
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
	if (! -f $configFile) {
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
	# Store a disk label ID for this object
	#------------------------------------------
	$this -> getMBRDiskLabel();
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
# createImageClicFS
#------------------------------------------
sub createImageClicFS {
	# ...
	# create compressed loop image container
	# ---
	my $this    = shift;
	my $rename  = shift;
	my $journal = "journaled-ext3";
	my $kiwi    = $this->{kiwi};
	my $data;
	my $code;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ();
	if (! defined $name) {
		return undef;
	}
	if (defined $rename) {
		$data = qxx (
			"mv $this->{imageDest}/$name $this->{imageDest}/$rename 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Can't rename image file");
			$kiwi -> failed ();
			$kiwi -> error  ($data);
			return undef;
		}
		$name = $rename;
	}
	#==========================================
	# Create ext3 filesystem on extend
	#------------------------------------------
	if (! $this -> setupEXT2 ( $name,$journal )) {
		return undef;
	}
	#==========================================
	# POST filesystem setup
	#------------------------------------------
	if (! $this -> postImage ($name,"nozip","clicfs")) {
		return undef;
	}
	#==========================================
	# Rename filesystem loop file
	#------------------------------------------
	$data = qxx (
		"mv $this->{imageDest}/$name $this->{imageDest}/fsdata.ext3 2>&1"
	);
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Can't move file to fsdata.ext3");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	#==========================================  
	# Resize to minimum  
	#------------------------------------------
	my $rver= qxx (
		"resize2fs --version 2>&1 | head -n 1 | cut -f2 -d ' ' | cut -f1-2 -d."
	); chomp $rver;
	my $dfs = "/sbin/debugfs";
	my $req = "-R 'show_super_stats -h'";
	my $bcn = "'^Block count:'";
	my $bfr = "'^Free blocks:'";
	my $src = "$this->{imageDest}/fsdata.ext3";
	my $blocks = 0;
	$kiwi -> loginfo ("Using resize2fs version: $rver\n");
	if ($rver >= 1.41) {
		$data = qxx (
			"resize2fs $this->{imageDest}/fsdata.ext3 -M 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to resize ext3 container: $data");
			$kiwi -> failed ();
			return undef;
		}
	} else {
		$data = qxx (
			"$dfs $req $src 2>/dev/null | grep $bcn | sed -e 's,.*: *,,'"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("debugfs: block count request failed: $data");
			$kiwi -> failed ();
			return undef;
		}
		chomp $data;
		$blocks = $data;  
		$data = qxx (
			"$dfs $req $src 2>/dev/null | grep $bfr | sed -e 's,.*: *,,'"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("debugfs: free blocks request failed: $data");
			$kiwi -> failed ();
			return undef;
		}  
		$kiwi -> info ("clicfs: blocks count=$blocks free=$data");
		$blocks = $blocks - $data;  
		$data = qxx (
			"resize2fs $this->{imageDest}/fsdata.ext3 $blocks 2>&1"
		);
		$code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error  ("Failed to resize ext3 container: $data");
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# Create clicfs filesystem from ext3
	#------------------------------------------
	$kiwi -> info ("Creating clicfs container...");
	my $clicfs = $this->{imageTree}."/usr/bin/mkclicfs";
	if (! -x $clicfs) {
		$kiwi -> done ();
		$kiwi -> warning (
			"Using mkclicfs from build system, versions should match !"
		);
		$clicfs = "mkclicfs";
	}
	if (defined $ENV{MKCLICFS_COMPRESSION}) {
		my $c = int $ENV{MKCLICFS_COMPRESSION};
		my $d = $this->{imageDest};
		$data = qxx ("$clicfs -c $c $d/fsdata.ext3 $d/$name 2>&1");
	} else {
		my $d = $this->{imageDest};
		$data = qxx ("$clicfs $d/fsdata.ext3 $d/$name 2>&1");
	}
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create clicfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	qxx ("mv -f $this->{imageDest}/$name.ext3 $this->{imageDest}/$name.clicfs");
	qxx ("rm -f $this->{imageDest}/fsdata.ext3");
	$kiwi -> done();
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if (! $this -> buildMD5Sum ($name)) {
		return undef;
	}
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
	my $name = $this -> preImage ();
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# Create filesystem on extend
	#------------------------------------------
	if (! $this -> setupEXT2 ( $name,$journal )) {
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
	return $this -> createImageEXT2 ("journaled-ext3");
}

#==========================================
# createImageEXT4
#------------------------------------------
sub createImageEXT4 {
	# ...
	# create journaled EXT4 image from source tree
	# ---
	my $this = shift;
	return $this -> createImageEXT2 ("journaled-ext4");
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
# createImageBTRFS
#------------------------------------------
sub createImageBTRFS {
	# ...
	# create BTRFS image from source tree
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
	if (! $this -> setupBTRFS ( $name )) {
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
	my $this  = shift;
	my $kiwi  = $this->{kiwi};
	my $xml   = $this->{xml};
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
	my %type = %{$xml->getImageTypeAndAttributes()};
	if (($type{compressed}) && ($type{compressed} =~ /yes|true/)) {
		if (! $this -> compressImage ($name)) {
			return undef;
		}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
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
	my $compress  = 1;
	#==========================================
	# PRE filesystem setup
	#------------------------------------------
	my $name = $this -> preImage ("haveExtend","quiet");
	if (! defined $name) {
		return undef;
	}
	#==========================================
	# PRE Create filesystem on extend
	#------------------------------------------
	my $pwd  = qxx ("pwd"); chomp $pwd;
	my @cpio = ("--create", "--format=newc", "--quiet");
	my $dest = $this->{imageDest}."/".$name.".gz";
	my $dspl = $this->{imageDest}."/".$name.".splash.gz";
	my $data;
	if (! $compress) {
		$dest = $this->{imageDest}."/".$name;
	}
	if ($dest !~ /^\//) {
		$dest = $pwd."/".$dest;
	}
	if ($dspl !~ /^\//) {
		$dspl = $pwd."/".$dspl;
	}
	if (-e $dspl) {
		qxx ("rm -f $dspl 2>&1");
	}
	if ($compress) {
		$data = qxx (
			"cd $imageTree && find . | cpio @cpio | $main::Gzip -f > $dest"
		);
	} else {
		$data = qxx ("rm -f $dest && rm -f $dest.gz");
		$data = qxx (
			"cd $imageTree && find . | cpio @cpio > $dest"
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
	# createImageVMX(), createImagePXE()
	# functions too 
	# ---
	#==========================================
	# Create usb|vmx|xen|pxe system image
	#------------------------------------------
	my $this = shift;
	my $para = shift;
	my $text = shift;
	my $kiwi = $this->{kiwi};
	my $sxml = $this->{xml};
	my %stype= %{$sxml->getImageTypeAndAttributes()};
	my $imageTree = $this->{imageTree};
	my $baseSystem= $this->{baseSystem};
	my $treeAccess= 1;
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
	#==========================================
	# Check for direct tree access
	#------------------------------------------
	if (($text ne "VMX") || ($stype{luks})) {
		$treeAccess = 0;
	}
	#==========================================
	# Walk through the types
	#------------------------------------------
	SWITCH: for ($type) {
		/^ext2/       && do {
			if (! $treeAccess) {
				$ok = $this -> createImageEXT2 ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^ext3/       && do {
			if (! $treeAccess) {
				$ok = $this -> createImageEXT3 ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^ext4/       && do {
			if (! $treeAccess) {
				$ok = $this -> createImageEXT4 ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^reiserfs/   && do {
			if (! $treeAccess) {
				$ok = $this -> createImageReiserFS ();
			} else {
				$ok = $this -> setupLogicalExtend();
				$result{imageTree} = $imageTree;
			}
			last SWITCH;
		};
		/^squashfs/   && do {
			$ok = $this -> createImageSquashFS ();
			last SWITCH;
		};
		/^clicfs/     && do {
			$ok = $this -> createImageClicFS ();
			last SWITCH;
		};
		/^btrfs/      && do {
			$ok = $this -> createImageBTRFS ();
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
	if (defined $type{baseroot}) {
		$main::BaseRoot = $type{baseroot};
	}
	if (defined $main::BaseRoot) {
		if (($main::BaseRoot !~ /^\//) && (! -d $main::BaseRoot)) {
			$main::BaseRoot = $main::System."/".$main::BaseRoot;
		}
	}
	if (($main::Prepare !~ /^\//) && (! -d $main::Prepare)) {
		$main::Prepare = $main::System."/".$main::Prepare;
	}
	@main::Profiles = ();
	if ($type{bootprofile}) {
		push @main::Profiles ,split (/,/,$type{bootprofile});
	}
	if ($type{bootkernel}) {
		push @main::Profiles ,split (/,/,$type{bootkernel});
	}
	if ($type{cmdline}) {
		$main::ForeignRepo{"kernelcmdline"} = $type{cmdline};
	}
	if ($type{bootloader}) {
		$main::ForeignRepo{"bootloader"} = $type{bootloader};
	}
	$main::ForeignRepo{"xmlobj"}  = $xml;
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"xmlpacnode"} = $xml -> getForeignPackageNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"domain"} = $xml -> getXenDomain();
	$main::ForeignRepo{"oem-partition-install"} =$xml->getOEMPartitionInstall();
	$main::ForeignRepo{"oem-swap"}       = $xml -> getOEMSwap();
	$main::ForeignRepo{"oem-swapsize"}   = $xml -> getOEMSwapSize();
	$main::ForeignRepo{"oem-systemsize"} = $xml -> getOEMSystemSize();
	$main::ForeignRepo{"oem-home"}       = $xml -> getOEMHome();
	$main::ForeignRepo{"oem-boot-title"} = $xml -> getOEMBootTitle();
	$main::ForeignRepo{"oem-kiwi-initrd"}= $xml -> getOEMKiwiInitrd();
	$main::ForeignRepo{"oem-reboot"}     = $xml -> getOEMReboot();
	$main::ForeignRepo{"oem-dumphalt"}   = $xml -> getOEMDumpHalt();
	$main::ForeignRepo{"oem-unattended"} = $xml -> getOEMUnattended();
	$main::ForeignRepo{"oem-recovery"}   = $xml -> getOEMRecovery();
	$main::ForeignRepo{"oem-recoveryID"} = $xml -> getOEMRecoveryID();
	$main::ForeignRepo{"oem-inplace-recovery"} = $xml ->getOEMRecoveryInPlace();
	$main::ForeignRepo{"displayname"}    = $xml -> getImageDisplayName();
	$main::ForeignRepo{"locale"}    = $xml -> getLocale();
	$main::ForeignRepo{"boot-theme"}= $xml -> getBootTheme();
	$main::ForeignRepo{"prepare"}   = $main::Prepare;
	$main::ForeignRepo{"create"}    = $main::Create;
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
		my $psplash;
		if (-f $lookup.$main::ImageName.".splash.gz") {
			$psplash = $lookup.$main::ImageName.".splash.gz";
		}
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
				if ($psplash) {
					qxx ("cp -a $psplash $main::Destination 2>&1");
				}
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
	my $newinitrd = $kboot -> setupSplash();
	$kboot -> cleanTmp();
	#==========================================
	# inflate/deflate initrd to make xen happy
	#------------------------------------------
	if (($type{type} eq "xen") || ($type{bootprofile} eq "xen")) {
		my $irdunc = $newinitrd;
		$irdunc =~ s/\.gz//;
		qxx ("$main::Gzip -d $newinitrd && $main::Gzip $irdunc");
	}
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
	my %xenc = $xml  -> getXenConfig();
	my %type = %{$xml -> getImageTypeAndAttributes()};
	my $name = $this -> createImageUSB ($para,"VMX");
	my $xendomain;
	if (! defined $name) {
		return undef;
	}
	if (defined $xenc{xen_domain}) {
		$xendomain = $xenc{xen_domain};
	} else {
		$xendomain = "dom0";
	}
	undef $main::Prepare;
	undef $main::Create;
	#==========================================
	# Create virtual disk images
	#------------------------------------------
	$main::BootVMDisk  = $main::Destination."/".$name->{bootImage}.".splash.gz";
	$main::BootVMSystem= $main::Destination."/".$name->{systemImage};
	if (defined $name->{imageTree}) {
		$main::BootVMSystem = $name->{imageTree};
	}
	if (! defined main::main()) {
		$main::Survive = "default";
		return undef;
	}
	#==========================================
	# Create VM format/configuration
	#------------------------------------------
	if ((defined $name->{format}) || ($xendomain eq "domU")) {
		undef $main::BootVMDisk;
		undef $main::BootVMSystem;
		$main::Convert = $main::Destination."/".$name->{systemImage}.".raw";
		$main::Format  = $name->{format};
		if (! defined main::main()) {
			$main::Survive = "default";
			return undef;
		}
	}
	$main::Survive = "default";
	return $this;
}

#==========================================
# makeLabel
#------------------------------------------
sub makeLabel {
	# ...
	# isolinux handles spaces as "_", so we replace
	# each space with an underscore
	# ----
	my $this = shift;
	my $label = shift;
	$label =~ s/ /_/g;
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
	my $baseSystem= $this->{baseSystem};
	my $error;
	my $data;
	my $code;
	my $imageTreeReadOnly;
	my $plinux;
	my $pinitrd;
	my $pxboot;
	my $hybrid = 0;
	my $hybridpersistent = 0;
	my $cmdline;
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
	my $vga  = $type{vga};
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
	# Check for hybrid ISO
	#------------------------------------------
	if ((defined $type{hybrid}) && ($type{hybrid} =~ /yes|true/i)) {
		$hybrid = 1;
	}
	if ((defined $type{hybridpersistent}) &&
		($type{hybridpersistent} =~ /yes|true/i)
	) {
		$hybridpersistent = 1;
	}
	#==========================================
	# Check for user-specified cmdline options
	#------------------------------------------
	if (defined $type{cmdline}) {
		$cmdline = " $cmdline";
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
		qxx ("mv $imageTree/image/$cdrootData $this->{imageDest}");
	}
	#==========================================
	# Check for config-cdroot.sh and move it
	#------------------------------------------
	my $cdrootScript = "config-cdroot.sh";
	if (-x $imageTree."/image/".$cdrootScript) {
		qxx ("mv $imageTree/image/$cdrootScript $this->{imageDest}");
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
		my ($mbytesrw,$xmlsize) = $this -> getSize ($imageTree);
		$kiwi -> done ();

		#==========================================
		# Create RW logical extend
		#------------------------------------------
		$kiwi -> info ("Image RW part requires $mbytesrw MB of disk space");
		if (! $this -> buildLogicalExtend ($namerw,$mbytesrw."M")) {
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
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
		if (! $this -> setupEXT2 ( $namerw )) {
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
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
			$this -> cleanLuks();
			return undef;
		}
		#==========================================
		# copy physical to logical
		#------------------------------------------
		if (! $this -> installLogicalExtend ($extend,$imageTree)) {
			$this -> restoreCDRootData();
			$this -> restoreSplitExtend ();
			$this -> cleanLuks();
			return undef;
		}
		$this -> cleanMount();
		$this -> restoreImageDest();
		$this -> cleanLuks();
	}
	#==========================================
	# Create compressed filesystem on RO extend
	#------------------------------------------
	if (defined $gzip) {
		SWITCH: for ($gzip) {
			/^compressed$/ && do {
				$kiwi -> info ("Creating split ext3 + squashfs...\n");
				if (! $this -> createImageSplit ("ext3,squashfs", 1)) {
					$this -> restoreCDRootData();
					return undef;
				}
				$namero = $namerw;
				last SWITCH;
			};
			/^unified$/ && do {
				$kiwi -> info ("Creating squashfs read only filesystem...\n");
				if (! $this -> setupSquashFS ( $namero,$imageTree )) {
					$this -> restoreCDRootData();
					$this -> restoreSplitExtend ();
					return undef;
				}
				last SWITCH;
			};
			/^clic$/ && do {
				$kiwi -> info ("Creating clicfs read only filesystem...\n");
				if (! $this -> createImageClicFS ( $namero )) {
					$this -> restoreCDRootData();
					$this -> restoreSplitExtend ();
					return undef;
				}
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
		qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$namerw 2>&1");

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
		if ($imageTreeReadOnly) {
			qxx ("rm -rf $imageTreeReadOnly");
		}
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
	if (defined $type{baseroot}) {
		$main::BaseRoot = $type{baseroot};
	}
	if (defined $main::BaseRoot) {
		if (($main::BaseRoot !~ /^\//) && (! -d $main::BaseRoot)) {
			$main::BaseRoot = $main::System."/".$main::BaseRoot;
		}
	}
	if (($main::Prepare !~ /^\//) && (! -d $main::Prepare)) {
		$main::Prepare = $main::System."/".$main::Prepare;
	}
	@main::Profiles = ();
	if ($type{bootprofile}) {
		push @main::Profiles ,split (/,/,$type{bootprofile});
	}
	if ($type{bootkernel}) {
		push @main::Profiles ,split (/,/,$type{bootkernel});
	}
	if ($type{cmdline}) {
		$main::ForeignRepo{"kernelcmdline"} = $type{cmdline};
	}
	if ($hybrid) {
		$main::ForeignRepo{"hybrid"}= "true";
	}
	if ($hybridpersistent) {
		$main::ForeignRepo{"hybridpersistent"} = "true";
	}
	$main::ForeignRepo{"xmlobj"}  = $xml;
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"xmlpacnode"} = $xml -> getForeignPackageNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"locale"}    = $xml -> getLocale();
	$main::ForeignRepo{"boot-theme"}= $xml -> getBootTheme();
	$main::ForeignRepo{"prepare"}   = $main::Prepare;
	$main::ForeignRepo{"create"}    = $main::Create;
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
				if ($imageTreeReadOnly) {
					qxx ("rm -rf $imageTreeReadOnly");
				}
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
			$initrd = "$this->{imageDest}/$iso$arch-$ver.gz";
		}
		if (! $this -> checkKernel ($initrd,$imageTree)) {
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				if ($imageTreeReadOnly) {
					qxx ("rm -rf $imageTreeReadOnly");
				}
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
	if (-f $this->{imageDest}."/".$cdrootData) {
		$kiwi -> info ("Integrating CD root information...");
		my $data= qxx (
			"tar -C $main::RootTree/CD -xvf $this->{imageDest}/$cdrootData"
		);
		my $code= $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to integrate CD root data: $data");
			$kiwi -> failed ();
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
				if ($imageTreeReadOnly) {
					qxx ("rm -rf $imageTreeReadOnly");
				}
			}
			$this -> restoreCDRootData();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	if (-x $this->{imageDest}."/".$cdrootScript) {
		$kiwi -> info ("Calling CD root setup script...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $cdrootEnv = $imageTree."/.profile";
		if ($cdrootEnv !~ /^\//) {
			$cdrootEnv = $pwd."/".$cdrootEnv;
		}
		my $script = $this->{imageDest}."/".$cdrootScript;
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
				if ($imageTreeReadOnly) {
					qxx ("rm -rf $imageTreeReadOnly");
				}
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
		# /.../
		# don't symlink these file because in this old live iso
		# mode we don't allow mkisofs to follow symlinks
		# ----
		qxx ("mv $this->{imageDest}/$namerw.md5 $main::RootTree/CD");
		qxx ("mv $this->{imageDest}/$namerw.gz $main::RootTree/CD");
		qxx ("rm $this->{imageDest}/$namerw.*");
	}
	if (defined $gzip) {
		#qxx ("mv $this->{imageDest}/$namero $main::RootTree/CD");
		#qxx ("rm $this->{imageDest}/$namero.*");
		qxx (
			"ln -s $this->{imageDest}/$namero $main::RootTree/CD/$namero"
		);
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
	my $xboot = glob ("$this->{imageDest}/$iso$arch-$ver*xen.gz");
	if (-f $xboot) {
		$isxen = 1;
	}
	if ($hybrid) {
		#==========================================
		# Create MBR id file for boot device check
		#------------------------------------------
		$kiwi -> info ("Saving hybrid disk label on ISO: $this->{mbrid}...");
		my $destination = "$main::RootTree/CD/boot/grub";
		qxx ("mkdir -p $destination");
		if (! open (FD,">$destination/mbrid")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create mbrid file: $!");
			if (! -d $main::RootTree.$baseSystem) {
				qxx ("rm -rf $main::RootTree");
				qxx ("rm -rf $tmpdir");
			}
			$kiwi -> failed ();
			return undef;
		}
		print FD "$this->{mbrid}";
		close FD;
		$kiwi -> done();
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
			"cp $this->{imageDest}/$iso$arch-$ver.gz $destination/initrd 2>&1"
		);
	}
	$code = $? >> 8;
	if ($code == 0) {
		if ($pblt) {
			$data = qxx ("cp $plinux $destination/linux 2>&1");
		} else {
			$data = qxx (
				"cp $this->{imageDest}/$iso$arch-$ver.kernel $destination/linux 2>&1"
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
	my $label = $this->makeLabel ($systemDisplayName);
	my $lsafe = $this->makeLabel ("Failsafe -- ".$label);
	#==========================================
	# setup isolinux.cfg file
	#------------------------------------------
	$kiwi -> info ("Creating isolinux configuration...");
	my $syslinux_new_format = 0;
	if (-f "$gfx/gfxboot.com" || -f "$gfx/gfxboot.c32") {
		$syslinux_new_format = 1;
	}
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
	if ($syslinux_new_format) {
		print FD "ui gfxboot bootlogo isolinux.msg"."\n";
	} else {
		print FD "gfxboot  bootlogo"."\n";
		print FD "display  isolinux.msg"."\n";
	}
	print FD "prompt   1"."\n";
	print FD "timeout  200"."\n";
	if (! $isxen) {
		print FD "label $label"."\n";
		print FD "  kernel linux"."\n";
		print FD "  append initrd=initrd ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent${cmdline} showopts ";
		#print FD "console=ttyS0,9600n8 console=tty0${cmdline} showopts ";
		if ($vga) {
			print FD "vga=$vga ";
		}
		print FD "\n";
		print FD "label $lsafe"."\n";
		print FD "  kernel linux"."\n";
		print FD "  append initrd=initrd ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent${cmdline} showopts ";
		print FD "ide=nodma apm=off acpi=off noresume selinux=0 nosmp ";
		print FD "noapic maxcpus=0 edd=off"."\n";
	} else {
		print FD "label $label"."\n";
		print FD "  kernel mboot.c32"."\n";
		print FD "  append xen.gz --- linux ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent${cmdline} ";
		#print FD "console=ttyS0,9600n8 console=tty0 ";
		if ($vga) {
			print FD "vga=$vga ";
		}
		print FD "--- initrd showopts"."\n";
		print FD "\n";
		print FD "label $lsafe"."\n";
		print FD "  kernel mboot.c32"."\n";
		print FD "  append xen.gz --- linux ramdisk_size=512000 ";
		print FD "ramdisk_blocksize=4096 splash=silent${cmdline} ";
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
			print FD "  append initrd=initrd splash=silent mediacheck=1";
			print FD "$cmdline ";
			print FD "showopts"."\n";
		} else {
			print FD "label mediacheck"."\n";
			print FD "  kernel mboot.c32"."\n";
			print FD "  append xen.gz --- linux splash=silent mediacheck=1";
			print FD "$cmdline ";
			print FD "--- initrd showopts"."\n";
		}
	}
	#==========================================
	# setup default harddisk/memtest entries
	#------------------------------------------
	print FD "\n";
	print FD "label harddisk\n";
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
	printf (FD "%-20s - %s\n",$label,"Live System");
	printf (FD "%-20s - %s\n",$lsafe,"Live System failsafe mode");
	printf (FD "%-20s - %s\n","harddisk","Local boot from hard disk");
	printf (FD "%-20s - %s\n","mediacheck","Media check");
	printf (FD "%-20s - %s\n","memtest","Memory Test");
	print FD "\n";
	print FD "Have a lot of fun..."."\n";
	close FD;
	$kiwi -> done();
	#==========================================
	# remove original kernel and initrd
	#------------------------------------------
	if (! $pblt) {
		$data = qxx ("rm $this->{imageDest}/$iso*.* 2>&1");
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
	if ((! defined $gzip) || ($gzip =~ /^(unified|clic)/)) {
		print FD "IMAGE=/dev/ram1;$namecd\n";
	} else {
		print FD "IMAGE=/dev/loop1;$namecd\n";
	}
	if (defined $gzip) {
		if ($gzip =~ /^unified/) {
			print FD "UNIONFS_CONFIG=/dev/ram1,/dev/loop1,aufs\n";
		} elsif ($gzip =~ /^clic/) {
			print FD "UNIONFS_CONFIG=/dev/ram1,/dev/loop1,clicfs\n";
		} else {
			print FD "COMBINED_IMAGE=yes\n";
		}
	}
	close FD;
	#==========================================
	# create ISO image
	#------------------------------------------
	$kiwi -> info ("Creating ISO image...\n");
	my $isoerror = 1;
	my $name = $this->{imageDest}."/".$namerw.".iso";
	my $attr = "-R -J -f -pad -joliet-long";
	if (! defined $gzip) {
		$attr = "-R -J -pad -joliet-long";
	}
	$attr .= " -p \"$main::Preparer\" -publisher \"$main::Publisher\"";
	if (! defined $gzip) {
		$attr .= " -iso-level 4"; 
	}
	if ($type{volid}) {
		$attr .= " -V \"$type{volid}\"";
	}
	my $isolinux = new KIWIIsoLinux (
		$kiwi,$main::RootTree."/CD",$name,$attr,"checkmedia"
	);
	if (defined $isolinux) {
		$isoerror = 0;
		if (! $isolinux -> callBootMethods()) {
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
	if (! $isolinux -> relocateCatalog()) {
		if (! -d $main::RootTree.$baseSystem) {
			qxx ("rm -rf $main::RootTree");
			qxx ("rm -rf $tmpdir");
		}
		return undef;
	}
	#==========================================
	# Turn ISO into hybrid if requested
	#------------------------------------------
	if ($hybrid) {
		$kiwi -> info ("Setting up hybrid ISO...");
		if (! $isolinux -> createHybrid ($this->{mbrid})) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to create hybrid ISO image");
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
	# tag ISO image with tagmedia
	#------------------------------------------
	if (-x "/usr/bin/tagmedia") {
		$kiwi -> info ("Adding checkmedia tag...");
		if (! $isolinux -> checkImage()) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to tag ISO image");
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
	my $baseSystem= $this->{baseSystem};
	my $sxml = $this->{xml};
	my %xenc = $sxml->getXenConfig();
	my $FSTypeRW;
	my $FSTypeRO;
	my $error;
	my $ok;
	my $imageTreeRW;
	my $imageTreeTmp;
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
	my $xendomain;
	#==========================================
	# check for xen domain setup
	#------------------------------------------
	if (defined $xenc{xen_domain}) {
		$xendomain = $xenc{xen_domain};
	} else {
		$xendomain = "dom0";
	}
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
	if (-d $this->{imageDest}."/".$treebase) {
		qxx ("rm -rf $this->{imageDest}/$treebase");
	}
	$data = qxx ("cp -a -x $imageTree $this->{imageDest}");
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
	$imageTree = $this->{imageDest}."/".$treebase;
	if ($imageTree !~ /^\//) {
		my $pwd = qxx ("pwd"); chomp $pwd;
		$imageTree = $pwd."/".$imageTree;
	}
	$imageTreeTmp = $imageTree;
	$imageTreeTmp =~ s/\/+$//;
	$imageTreeTmp.= "-tmp/";
	$this->{imageTreeTmp} = $imageTreeTmp;
	#==========================================
	# run split tree creation
	#------------------------------------------
	$kiwi -> info ("Creating temporary image part...\n");
	if (! mkdir $imageTreeTmp) {
		$error = $!;
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create split tmp directory: $error");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTree");
		return undef;
	}
	#==========================================
	# walk through except files if any
	#------------------------------------------
	my %exceptHash;
	foreach my $except ($sxml -> getSplitTmpExceptions()) {
		my $globsource = "${imageTree}${except}";
		my @files = qxx ("find $globsource -xtype f 2>/dev/null");
		my $code  = $? >> 8;
		if ($code != 0) {
			# excepted file(s) doesn't exist anyway
			next;
		}
		chomp @files;
		foreach my $file (@files) {
			$exceptHash{$file} = $file;
		}
	}
	#==========================================
	# create linked list for files, create dirs
	#------------------------------------------
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
			$rerooted =~ s#/+#/#g;
			symlink ($rerooted, $target);
		}
	};
	find(\&$createTmpTree, $imageTree);
	my @tempFiles    = $sxml -> getSplitTempFiles ();
	my @persistFiles = $sxml -> getSplitPersistentFiles ();
	if ($nopersistent) {
		push (@tempFiles, @persistFiles);
		undef @persistFiles;
	}
	#==========================================
	# search temporary files, respect excepts
	#------------------------------------------
	my %tempFiles_new;
	if (@tempFiles) {
		foreach my $temp (@tempFiles) {
			my $globsource = "${imageTree}${temp}";
			my @files = qxx ("find $globsource -xtype f 2>/dev/null");
			my $code  = $? >> 8;
			if ($code != 0) {
				$kiwi -> warning ("file $globsource doesn't exist");
				$kiwi -> skipped ();
				next;
			}
			chomp @files;
			foreach (@files) {
				$tempFiles_new{$_} = $_;
			}
		}
	}
	@tempFiles = sort keys %tempFiles_new;
	if (@tempFiles) {
		foreach my $file (@tempFiles) {
			if (defined $exceptHash{$file}) {
				next;
			}
			my $dest = $file;
			$dest =~ s#$imageTree#$imageTreeTmp#;
			qxx ("rm -rf $dest");
			qxx ("mv $file $dest");
		}
	}
	#==========================================
	# find persistent files for the read-write
	#------------------------------------------
	$imageTreeRW = $imageTree;
	$imageTreeRW =~ s/\/+$//;
	$imageTreeRW.= "-read-write";
	if (@persistFiles) {
		$kiwi -> info ("Creating read-write image part...\n");
		#==========================================
		# Create read-write directory
		#------------------------------------------
		$this->{imageTreeRW} = $imageTreeRW;
		if (! mkdir $imageTreeRW) {
			$error = $!;
			$kiwi -> error  (
				"Couldn't create split read-write directory: $error"
			);
			$kiwi -> failed ();
			qxx ("rm -rf $imageTree $imageTreeTmp");
			return undef;
		}
		#==========================================
		# walk through except files if any
		#------------------------------------------
		my %exceptHash;
		foreach my $except ($sxml -> getSplitPersistentExceptions()) {
			my $globsource = "${imageTree}${except}";
			my @files = qxx ("find $globsource -xtype f 2>/dev/null");
			my $code  = $? >> 8;
			if ($code != 0) {
				# excepted file(s) doesn't exist anyway
				next;
			}
			chomp @files;
			foreach my $file (@files) {
				$exceptHash{$file} = $file;
			}
		}
		#==========================================
		# search persistent files, respect excepts
		#------------------------------------------
		my %expandedPersistFiles;
		foreach my $persist (@persistFiles) {
			my $globsource = "${imageTree}${persist}";
			my @files = qxx ("find $globsource 2>/dev/null");
			my $code  = $? >> 8;
			if ($code != 0) {
				$kiwi -> warning ("file $globsource doesn't exist");
				$kiwi -> skipped ();
				next;
			}
			chomp @files;
			foreach my $file (@files) {
				if (defined $exceptHash{$file}) {
					next;
				}
				$expandedPersistFiles{$file} = $file;
			}
		}
		@persistFiles = keys %expandedPersistFiles;
		#==========================================
		# relink to read-write, and move files
		#------------------------------------------
		foreach my $file (@persistFiles) {
			my $dest = $file;
			my $link = $file;
			my $rlnk = $file;
			$dest =~ s#$imageTree#$imageTreeRW#;
			$link =~ s#$imageTree#$imageTreeTmp#;
			$rlnk =~ s#$imageTree#/read-write#;
			if (-d $file) {
				#==========================================
				# recreate directory
				#------------------------------------------
				qxx ("mkdir -p $dest");
			} else {
				#==========================================
				# move file to read-write area
				#------------------------------------------
				my $destdir = dirname $dest;
				qxx ("rm -rf $dest");
				qxx ("mkdir -p $destdir");
				qxx ("mv $file $dest");
				#==========================================
				# relink file to read-write area
				#------------------------------------------
				qxx ("rm -rf $link");
				qxx ("ln -s $rlnk $link");
			}
		}
		#==========================================
		# relink if entire directory was set
		#------------------------------------------
		foreach my $persist ($sxml -> getSplitPersistentFiles()) {
			my $globsource = "${imageTree}${persist}";
			if (-d $globsource) {
				my $link = $globsource;
				my $rlnk = $globsource;
				$link =~ s#$imageTree#$imageTreeTmp#;
				$rlnk =~ s#$imageTree#/read-write#;
				#==========================================
				# relink directory to read-write area
				#------------------------------------------
				qxx ("rm -rf $link");
				qxx ("ln -s $rlnk $link");
			}
		}
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
	($mbytesro,$xmlsize) = $this -> getSize ($imageTree);
	if (defined $this->{imageTreeRW}) {
		($mbytesrw,$xmlsize) = $this -> getSize ($imageTreeRW);
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
				$ok = $this -> setupEXT2 ( $namerw );
				last SWITCH;
			};
			/ext3/       && do {
				$ok = $this -> setupEXT2 ( $namerw,"journaled-ext3" );
				last SWITCH;
			};
			/ext4/       && do {
				$ok = $this -> setupEXT2 ( $namerw,"journaled-ext4" );
				last SWITCH;
			};
			/reiserfs/   && do {
				$ok = $this -> setupReiser ( $namerw );
				last SWITCH;
			};
			/btrfs/      && do {
				$ok = $this -> setupBTRFS ( $namerw );
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $FSTypeRW");
			$kiwi -> failed ();
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return undef;
		}
		if (! $ok) {
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
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
			$ok = $this -> setupEXT2 ( $namero );
			last SWITCH;
		};
		/ext3/       && do {
			$ok = $this -> setupEXT2 ( $namero,"journaled-ext3" );
			last SWITCH;
		};
		/ext4/       && do {
			$ok = $this -> setupEXT2 ( $namero,"journaled-ext4" );
			last SWITCH;
		};
		/reiserfs/   && do {
			$ok = $this -> setupReiser ( $namero );
			last SWITCH;
		};
		/btrfs/      && do {
			$ok = $this -> setupBTRFS ( $namero );
			last SWITCH;
		};
		/squashfs/   && do {
			$ok = $this -> setupSquashFS ( $namero,$imageTree );
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $FSTypeRO");
		$kiwi -> failed ();
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		$this -> cleanLuks();
		return undef;
	}
	if (! $ok) {
		qxx ("rm -rf $imageTreeRW");
		qxx ("rm -rf $imageTree");
		$this -> cleanLuks();
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
				$this -> cleanLuks();
				return undef;
			}
			#==========================================
			# copy physical to logical
			#------------------------------------------
			if (! $this -> installLogicalExtend ($extend,$source)) {
				qxx ("rm -rf $imageTreeRW");
				qxx ("rm -rf $imageTree");
				$this -> cleanLuks();
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
				qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/ext3/       && do {
				qxx ("/sbin/fsck.ext3 -f -y $this->{imageDest}/$name 2>&1");
				qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/ext4/       && do {
				qxx ("/sbin/fsck.ext4 -f -y $this->{imageDest}/$name 2>&1");
				qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/reiserfs/   && do {
				qxx ("/sbin/reiserfsck -y $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/btrfs/      && do {
				qxx ("/sbin/btrfsck $this->{imageDest}/$name 2>&1");
				$kiwi -> done();
				last SWITCH;
			};
			/squashfs/   && do {
				$kiwi -> done ();
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type");
			$kiwi -> failed ();
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return undef;
		}
		#==========================================
		# Create image md5sum
		#------------------------------------------
		$this -> restoreImageDest();
		if (! $this -> buildMD5Sum ($name)) {
			qxx ("rm -rf $imageTreeRW");
			qxx ("rm -rf $imageTree");
			$this -> cleanLuks();
			return undef;
		}
		$this -> remapImageDest();
	}
	$this -> restoreImageDest();
	$this -> cleanLuks();
	#==========================================
	# Create network boot configuration
	#------------------------------------------
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
	if (defined $type{baseroot}) {
		$main::BaseRoot = $type{baseroot};
	}
	if (defined $main::BaseRoot) {
		if (($main::BaseRoot !~ /^\//) && (! -d $main::BaseRoot)) {
			$main::BaseRoot = $main::System."/".$main::BaseRoot;
		}
	}
	if (($main::Prepare !~ /^\//) && (! -d $main::Prepare)) {
		$main::Prepare = $main::System."/".$main::Prepare;
	}
	@main::Profiles = ();
	if ($type{bootprofile}) {
		push @main::Profiles ,split (/,/,$type{bootprofile});
	}
	if ($type{bootkernel}) {
		push @main::Profiles ,split (/,/,$type{bootkernel});
	}
	if ($type{cmdline}) {
		$main::ForeignRepo{"kernelcmdline"} = $type{cmdline};
	}
	if ($type{bootloader}) {
		$main::ForeignRepo{"bootloader"} = $type{bootloader};
	}
	$main::ForeignRepo{"xmlnode"} = $xml -> getForeignNodeList();
	$main::ForeignRepo{"xmlpacnode"} = $xml -> getForeignPackageNodeList();
	$main::ForeignRepo{"packagemanager"} = $xml -> getPackageManager();
	$main::ForeignRepo{"domain"} = $xml -> getXenDomain();
	$main::ForeignRepo{"oem-partition-install"} =$xml->getOEMPartitionInstall();
	$main::ForeignRepo{"oem-swap"}       = $xml -> getOEMSwap();
	$main::ForeignRepo{"oem-swapsize"}   = $xml -> getOEMSwapSize();
	$main::ForeignRepo{"oem-systemsize"} = $xml -> getOEMSystemSize();
	$main::ForeignRepo{"oem-home"}       = $xml -> getOEMHome();
	$main::ForeignRepo{"oem-boot-title"} = $xml -> getOEMBootTitle();
	$main::ForeignRepo{"oem-kiwi-initrd"}= $xml -> getOEMKiwiInitrd();
	$main::ForeignRepo{"oem-reboot"}     = $xml -> getOEMReboot();
	$main::ForeignRepo{"oem-dumphalt"}   = $xml -> getOEMDumpHalt();
	$main::ForeignRepo{"oem-unattended"} = $xml -> getOEMUnattended();
	$main::ForeignRepo{"oem-recovery"}   = $xml -> getOEMRecovery();
	$main::ForeignRepo{"oem-recoveryID"} = $xml -> getOEMRecoveryID();
	$main::ForeignRepo{"oem-inplace-recovery"} = $xml ->getOEMRecoveryInPlace();
	$main::ForeignRepo{"displayname"}    = $xml -> getImageDisplayName();
	$main::ForeignRepo{"locale"}    = $xml -> getLocale();
	$main::ForeignRepo{"boot-theme"}= $xml -> getBootTheme();
	$main::ForeignRepo{"prepare"}   = $main::Prepare;
	$main::ForeignRepo{"create"}    = $main::Create;
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
		if (! defined main::main()) {
			$main::Survive = "default";
			return undef;
		}
		#==========================================
		# Create VM format/configuration
		#------------------------------------------
		if ((defined $name->{format}) || ($xendomain eq "domU")) {
			undef $main::BootVMDisk;
			undef $main::BootVMSystem;
			$main::Convert = $main::Destination."/".$name->{systemImage}.".raw";
			$main::Format  = $name->{format};
			if (! defined main::main()) {
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
	my $quiet= shift;
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
	my $mBytes = $this -> setupLogicalExtend ($quiet,$name);
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
	my $configName = $this -> buildImageName() . ".config";
	my $device = $xml -> getPXEDeployImageDevice ();
	my %type = %{$xml -> getImageTypeAndAttributes()};
	#==========================================
	# create .config for types which needs it
	#------------------------------------------
	if (defined $device) {
		$kiwi -> info ("Creating boot configuration...");
		if (! open (FD,">$this->{imageDest}/$configName")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create image boot configuration");
			$kiwi -> failed ();
			return undef;
		}
		my $namecd = $this -> buildImageName(";");
		my $namerw = $this -> buildImageName(";", "-read-write");
		my $server = $xml -> getPXEDeployServer ();
		my $blocks = $xml -> getPXEDeployBlockSize ();
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
		my @parts = $xml -> getPXEDeployPartitions ();
		if ((scalar @parts) > 0) {
			print FD "PART=";
			for my $href (@parts) {
				if ($href -> {target}) {
					$targetPartition = $href -> {number};
					$targetPartitionNext = $targetPartition + 1;
				}
				if ($href -> {size} eq "image") {
					my $size = main::isize ("$this->{imageDest}/$name");
					print FD int (($size/1024/1024)+1);
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
		#==========================================
		# IMAGE information
		#------------------------------------------
		if (($type{compressed}) && ($type{compressed} =~ /yes|true/)) {
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
		my %confs = $xml -> getPXEDeployConfiguration ();
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
		my %unionConfig = $xml -> getPXEDeployUnionConfig ();
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
		my $timeout = $xml -> getPXEDeployTimeout ();
		if (defined $timeout) {
			print FD "KIWI_BOOT_TIMEOUT=$timeout\n";
		}
		#==========================================
		# KIWI_KERNEL_OPTIONS information
		#------------------------------------------
		my $cmdline = $type{cmdline};
		if (defined $cmdline) {
			print FD "KIWI_KERNEL_OPTIONS='$cmdline'\n";
		}
		#==========================================
		# KIWI_KERNEL information
		#------------------------------------------
		my $kernel = $xml -> getPXEDeployKernel ();
		if (defined $kernel) {
			print FD "KIWI_KERNEL=$kernel\n";
		}
		#==========================================
		# KIWI_INITRD information
		#------------------------------------------
		my $initrd = $xml -> getPXEDeployInitrd ();
		if (defined $initrd) {
			print FD "KIWI_INITRD=$initrd\n";
		}
		#==========================================
		# More to come...
		#------------------------------------------
		close FD;
		$kiwi -> done ();
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
	my $this  = shift;
	my $name  = shift;
	my $nozip = shift;
	my $fstype= shift;
	my $kiwi  = $this->{kiwi};
	my $xml   = $this->{xml};
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
		$this -> cleanLuks();
		return undef;
	}
	$this -> cleanMount();
	#==========================================
	# Check image file system
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes()};
	if ((! $type{filesystem}) && ($fstype)) {
		$type{filesystem} = $fstype;
	}
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
		/ext3|ec2|clicfs/i && do {
			qxx ("/sbin/fsck.ext3 -f -y $this->{imageDest}/$name 2>&1");
			qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT4 file system
		#------------------------------------------
		/ext4/i     && do {
			qxx ("/sbin/fsck.ext4 -f -y $this->{imageDest}/$name 2>&1");
			qxx ("/sbin/tune2fs -j $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check EXT2 file system
		#------------------------------------------
		/ext2/i     && do {
			qxx ("/sbin/e2fsck -f -y $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check ReiserFS file system
		#------------------------------------------
		/reiserfs/i && do {
			qxx ("/sbin/reiserfsck -y $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Check BTRFS file system
		#------------------------------------------
		/btrfs/     && do {
			qxx ("/sbin/btrfsck $this->{imageDest}/$name 2>&1");
			$kiwi -> done();
			last SWITCH;
		};
		#==========================================
		# Unknown filesystem type
		#------------------------------------------
		$kiwi -> failed();
		$kiwi -> error ("Unsupported filesystem type: $type{filesystem}");
		$kiwi -> failed();
		$this -> cleanLuks();
		return undef;
	}
	$this -> restoreImageDest();
	$this -> cleanLuks ();
	#==========================================
	# Create image md5sum
	#------------------------------------------
	if ($fstype ne "clicfs") {
		if (! $this -> buildMD5Sum ($name)) {
			return undef;
		}
	}
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	if (! defined $nozip) {
		if (($type{compressed}) && ($type{compressed} =~ /yes|true/)) {
			if (! $this -> compressImage ($name)) {
				return undef;
			}
		}
	}
	#==========================================
	# Create image boot configuration
	#------------------------------------------
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
	my $encode = 0;
	my $cipher = 0;
	my $out  = $this->{imageDest}."/".$name;
	my %type = %{$xml->getImageTypeAndAttributes()};
	#==========================================
	# Check if luks encoding is requested
	#------------------------------------------
	if ($type{luks}) {
		$encode = 1;
		$cipher = "$type{luks}";
		$main::LuksCipher = $cipher;
	}
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
	#==========================================
	# Setup encoding
	#------------------------------------------
	if ($encode) {
		$this -> setupEncoding ($name,$out,$cipher);
	}
	return $name;
}

#==========================================
# setupEncoding
#------------------------------------------
sub setupEncoding {
	# ...
	# setup LUKS encoding on the given file and remap
	# the imageDest variable to the new device mapper
	# location
	# ---
	my $this   = shift;
	my $name   = shift;
	my $out    = shift;
	my $cipher = shift;
	my $kiwi   = $this->{kiwi};
	my $data;
	my $code;
	$data = qxx ("/sbin/losetup -s -f $out 2>&1"); chomp $data;
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't loop bind logical extend: $data");
		$kiwi -> failed ();
		return undef;
	}
	my $loop = $data;
	my @luksloop;
	if ($this->{luksloop}) {
		@luksloop = @{$this->{luksloop}};
	}
	push @luksloop,$loop;
	$this->{luksloop} = \@luksloop;
	$data = qxx ("echo $cipher | cryptsetup -q luksFormat $loop 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't setup luks format: $loop");
		$kiwi -> failed ();
		$this -> cleanLuks ();
		return undef;
	}
	$data = qxx ("echo $cipher | cryptsetup luksOpen $loop $name 2>&1");
	$code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't open luks device: $data");
		$kiwi -> failed ();
		$this -> cleanLuks ();
		return undef;
	}
	my @luksname;
	if ($this->{luksname}) {
		@luksname = @{$this->{luksname}};
	}
	push @luksname,$name;
	$this->{luksname} = \@luksname;
	if (! $this->{imageDestOrig}) {
		$this->{imageDestOrig} = $this->{imageDest};
		$this->{imageDestMap} = "/dev/mapper/";
	}
	$this->{imageDest} = $this->{imageDestMap};
	return $this;
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
	my $free = qxx ("df -h $extend 2>&1");
	$kiwi -> loginfo ("getSize: mount: $free\n");
	my $data = qxx ("tar -cf - -C $source . | tar -x -C $extend 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> info   ("tar based copy failed: $data");
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
	my ($mbytes,$xmlsize) = $this -> getSize ($imageTree);
	if (! defined $quiet) {
		$kiwi -> info ("Image requires ".$mbytes."M, got $xmlsize");
		$kiwi -> done ();
		$kiwi -> info ("Suggested Image size: $mbytes"."M");
		$kiwi -> done ();
	}
	#==========================================
	# Check given XML size
	#------------------------------------------
	if ($xmlsize =~ /^(\d+)([MG])$/i) {
		$xmlsize = $1;
		my $unit = $2;
		if ($unit eq "G") {
			# convert GB to MB...
			$xmlsize *= 1024;
		}
	}
	#==========================================
	# Return XML size or required size
	#------------------------------------------
	if (int $xmlsize > $mbytes) {
		return $xmlsize;
	}
	return $mbytes;
}

#==========================================
# mountLogicalExtend
#------------------------------------------
sub mountLogicalExtend {
	my $this = shift;
	my $name = shift;
	my $opts = shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# mount logical extend for data transfer
	#------------------------------------------
	mkdir "$this->{imageDest}/mnt-$$";
	my $mount = "mount -o loop";
	if (defined $opts) {
		$mount = "mount $opts -o loop";
	}
	#==========================================
	# check for filesystem options
	#------------------------------------------
	my $fstype = qxx (
		"/sbin/blkid -c /dev/null -s TYPE -o value $this->{imageDest}/$name"
	);
	chomp $fstype;
	if ($fstype eq "ext4") {
		# /.../
		# ext4 (currently) should be mounted with 'nodelalloc';
		# else we might run out of space unexpectedly...
		# ----
		$mount .= ",nodelalloc";
	}
	my $data= qxx (
		"$mount $this->{imageDest}/$name $this->{imageDest}/mnt-$$ 2>&1"
	);
	my $code= $? >> 8;
	if ($code != 0) {
		chomp $data;
		$kiwi -> error  ("Image loop mount failed:");
		$kiwi -> failed ();
		$kiwi -> error  (
			"mnt: $this->{imageDest}/$name -> $this->{imageDest}/mnt-$$: $data"
		);
		return undef;
	}
	return "$this->{imageDest}/mnt-$$";
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
		/ext4/i     && do {
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
		/clicfs/i && do {
			return $name;
			last SWITCH;
		};
		/btrfs/i  && do {
			return $name;
			last SWITCH;
		};
	}
	#==========================================
	# this is a boot image, extract kernel
	#------------------------------------------
	return $this -> extractLinux (
		$name,$imageTree,$this->{imageDest}
	);
}

#==========================================
# extractLinux
#------------------------------------------
sub extractLinux {
	my $this      = shift;
	my $name      = shift;
	my $imageTree = shift;
	my $dest      = shift;
	my $kiwi      = $this->{kiwi};
	my $xml       = $this->{xml};
	my %xenc      = $xml->getXenConfig();
	if ((-f "$imageTree/boot/vmlinux.gz")  ||
		(-f "$imageTree/boot/vmlinuz.el5") ||
		(-f "$imageTree/boot/vmlinux")     ||
		(-f "$imageTree/boot/vmlinuz")
	) {
		$kiwi -> info ("Extracting kernel...");
		#==========================================
		# setup file names / cleanup...
		#------------------------------------------
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $shortfile = "$name.kernel";
		my $file = "$dest/$shortfile";
		if ($file !~ /^\//) {
			$file = $pwd."/".$file;
		}
		if (-e $file) {
			qxx ("rm -f $file");
		}
		# /.../
		# the KIWIConfig::suseStripKernel() function provides the
		# kernel as common name /boot/vmlinuz. We use this file for
		# the extraction
		# ----
		qxx ("cp $imageTree/boot/vmlinuz $file");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> info   ("Failed to extract kernel: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $kernel = qxx ("get_kernel_version $file"); chomp $kernel;
		qxx ("mv -f $file $file.$kernel && ln -s $shortfile.$kernel $file");
		# /.../
		# check for the Xen hypervisor and extract them as well
		# ----
		if ((defined $xenc{xen_domain}) && ($xenc{xen_domain} eq "dom0")) {
			if (! -f "$imageTree/boot/xen.gz") {
				$kiwi -> failed ();
				$kiwi -> info   ("Xen dom0 requested but no hypervisor found");
				$kiwi -> failed ();
				return undef;
			}
		}
		if (-f "$imageTree/boot/xen.gz") {
			$file = "$dest/$name.kernel-xen";
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
	my $journal = shift;
	my $kiwi    = $this->{kiwi};
	my $xml  = $this->{xml};
	my %type = %{$xml->getImageTypeAndAttributes()};
	my $fsopts;
	my $tuneopts;
	my %FSopts = main::checkFSOptions();
	if ((defined $journal) && ($journal eq "journaled-ext3")) {
		$fsopts = $FSopts{ext3};
		$fsopts.="-j -F";
	} elsif ((defined $journal) && ($journal eq "journaled-ext4")) {
		$fsopts = $FSopts{ext4};
		$fsopts.="-j -F";
	} else {
		$fsopts = $FSopts{ext2};
		$fsopts.= "-F";
	}
	if ($this->{inodes}) {
		$fsopts.= " -N $this->{inodes}";
	}
	$tuneopts = $type{fsnocheck} eq "true" ? "-c 0 -i 0" : "";
	$tuneopts = $FSopts{extfstune} if $FSopts{extfstune};
	my $data = qxx ("/sbin/mke2fs $fsopts $this->{imageDest}/$name 2>&1");
	my $code = $? >> 8;
	if (!$code && $tuneopts) {
		$data = qxx ("/sbin/tune2fs $tuneopts $this->{imageDest}/$name 2>&1");
		$code = $? >> 8;
	}
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create EXT2 filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$this -> restoreImageDest();
	if ((defined $journal) && ($journal eq "journaled-ext3")) {
		$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.ext3 2>&1");
	} elsif ((defined $journal) && ($journal eq "journaled-ext4")) {
		$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.ext4 2>&1");
	} else {
		$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.ext2 2>&1");
	}
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# setupBTRFS
#------------------------------------------
sub setupBTRFS {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	my %FSopts = main::checkFSOptions();
	my $fsopts = $FSopts{btrfs};
	my $data = qxx (
		"/sbin/mkfs.btrfs $fsopts $this->{imageDest}/$name 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create BTRFS filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$this -> restoreImageDest();
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.btrfs 2>&1");
	$this -> remapImageDest();
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
	my %FSopts = main::checkFSOptions();
	my $fsopts = $FSopts{reiserfs};
	$fsopts.= "-f";
	my $data = qxx (
		"/sbin/mkreiserfs $fsopts $this->{imageDest}/$name 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> error  ("Couldn't create Reiser filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$this -> restoreImageDest();
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.reiserfs 2>&1");
	$this -> remapImageDest();
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
	my $xml  = $this->{xml};
	my %type = %{$xml->getImageTypeAndAttributes()};
	my $imageTree = $this->{imageTree};
	if (! defined $tree) {
		$tree = $imageTree;
	}
	if ($type{luks}) {
		$kiwi -> warning ("LUKS extension not supported for squashfs");
		$kiwi -> skipped ();
		$this -> restoreImageDest();
	}
	unlink ("$this->{imageDest}/$name");
	my $data = qxx ("/usr/bin/mksquashfs $tree $this->{imageDest}/$name 2>&1");
	my $code = $? >> 8; 
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create squashfs filesystem");
		$kiwi -> failed ();
		$kiwi -> error  ($data);
		return undef;
	}
	$this -> restoreImageDest();
	$data = qxx ("chmod 644 $this->{imageDest}/$name");
	$data = qxx ("cd $this->{imageDest} && ln -vs $name $name.squashfs 2>&1");
	$this -> remapImageDest();
	$kiwi -> loginfo ($data);
	return $name;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
	my $this = shift;
	my $name = shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# Create image md5sum
	#------------------------------------------
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = main::isize ("$this->{imageDest}/$name");
	my $primes = qxx ("factor $size"); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 65464);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qxx ("cat $this->{imageDest}/$name | md5sum - | cut -f 1 -d-");
	chomp $sum;
	if ($name =~ /\.gz$/) {
		$name =~ s/\.gz//;
	}
	qxx ("echo \"$sum $blocks $blocksize\" > $this->{imageDest}/$name.md5");
	$this->{md5file} = $this->{imageDest}."/".$name.".md5";
	$kiwi -> done();
	return $name;
}

#==========================================
# restoreCDRootData
#------------------------------------------
sub restoreCDRootData {
	my $this = shift;
	my $imageTree    = $this->{imageTree};
	my $cdrootData   = "config-cdroot.tgz";
	my $cdrootScript = "config-cdroot.sh";
	if (-f $this->{imageDest}."/".$cdrootData) {
		qxx ("mv $this->{imageDest}/$cdrootData $imageTree/image");
	}
	if (-f $this->{imageDest}."/".$cdrootScript) {
		qxx ("mv $this->{imageDest}/$cdrootScript $imageTree/image");
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
	#==========================================
	# Compress image using gzip
	#------------------------------------------
	$kiwi -> info ("Compressing image...");
	my $data = qxx ("$main::Gzip -f $this->{imageDest}/$name");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Compressing image failed: $!");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done();
	$this -> updateMD5File ("$this->{imageDest}/$name.gz");
	return $name;
}

#==========================================
# updateMD5File
#------------------------------------------
sub updateMD5File {
	my $this = shift;
	my $image= shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# Update md5file adding zblocks/zblocksize
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
		my $size = main::isize ($image);
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
	my $kiwi   = $this->{kiwi};
	my $extend = shift;
	my $xml    = $this->{xml};
	my $mini   = qxx ("find $extend | wc -l"); chomp $mini;
	my $minsize= qxx ("du -s --block-size=1 $extend | cut -f1"); chomp $minsize;
	my $spare  = 1.5;
	my $journal= 12 * 1024 * 1024;
	my $files  = $mini;
	my $xmlsize;
	#==========================================
	# Double minimum inode count
	#------------------------------------------
	$mini *= 2;
	#==========================================
	# Minimum size calculated in Byte + spare
	#------------------------------------------
	$kiwi -> loginfo ("getSize: files: $files\n");
	$kiwi -> loginfo ("getSize: spare: $spare\n");
	$kiwi -> loginfo ("getSize: usage: $minsize Bytes\n");
	$kiwi -> loginfo ("getSize: inode: $main::FSInodeSize Bytes\n");
	$kiwi -> loginfo ("getSize: journ: $journal Bytes\n");
	$minsize += $mini * $main::FSInodeSize;
	$minsize *= $spare;
	$minsize += $journal;
	$xmlsize = $minsize;
	$kiwi -> loginfo ("getSize: minsz: $minsize Bytes\n");
	#==========================================
	# XML size calculated in Byte
	#------------------------------------------
	my $additive = $xml -> getImageSizeAdditiveBytes();
	if ($additive) {
		# relative size value specified...
		$xmlsize = $minsize + $additive;
	} else {
		# absolute size value specified...
		$xmlsize = $xml -> getImageSize();
		if ($xmlsize eq "auto") {
			$xmlsize = $minsize;
		} elsif ($xmlsize =~ /^(\d+)([MG])$/i) {
			my $value= $1;
			my $unit = $2;
			if ($unit eq "G") {
				# convert GB to MB...
				$value *= 1024;
			}
			# convert MB to Byte
			$xmlsize = $value * 1048576;
			# check the size value with what kiwi thinks is the minimum
			if ($xmlsize < $minsize) {
				$kiwi -> warning (
					"--> given xml size might be too small, using it anyhow !\n"
				);
				$kiwi -> warning (
					"--> min size changed from $minsize to $xmlsize bytes\n"
				);
				$minsize = $xmlsize;
			}
		}
	}
	#==========================================
	# Setup used size and inodes, prefer XML
	#------------------------------------------
	my $usedsize = $minsize; 
	if ($xmlsize > $minsize) {
		$usedsize = $xmlsize;
		$this->{inodes} = sprintf ("%.0f",$usedsize / $main::FSInodeRatio);
	} else {
		$this->{inodes} = $mini;
	}
	#==========================================
	# return result list in MB
	#------------------------------------------
	$minsize = sprintf ("%.0f",$minsize  / 1048576);
	$usedsize= sprintf ("%.0f",$usedsize / 1048576);
	$usedsize.= "M";
	return ($minsize,$usedsize);
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
# cleanLuks
#------------------------------------------
sub cleanLuks {
	my $this = shift;
	my $loop = $this->{luksloop};
	my $name = $this->{luksname};
	if ($name) {
		foreach my $luks (@{$name}) {
			qxx ("cryptsetup luksClose $luks 2>&1");
		}
	}
	if ($loop) {
		foreach my $ldev (@{$loop}) {
			qxx ("losetup -d $ldev 2>&1");
		}
	}
}

#==========================================
# restoreImageDest
#------------------------------------------
sub restoreImageDest {
	my $this = shift;
	if ($this->{imageDestOrig}) {
		$this->{imageDest} = $this->{imageDestOrig};
	}
}

#==========================================
# remapImageDest
#------------------------------------------
sub remapImageDest {
	my $this = shift;
	if ($this->{imageDestMap}) {
		$this->{imageDest} = $this->{imageDestMap};
	}
}

#==========================================
# cleanMount
#------------------------------------------
sub cleanMount {
	my $this = shift;
	qxx ("umount $this->{imageDest}/mnt-$$ 2>&1");
	rmdir "$this->{imageDest}/mnt-$$";
}

#==========================================
# cleanKernelFSMount
#------------------------------------------
sub cleanKernelFSMount {
	my $this = shift;
	my @kfs  = ("/proc/sys/fs/binfmt_misc","/proc","/dev/pts","/sys");
	foreach my $system (@kfs) {
		qxx ("umount $this->{imageDest}/$system 2>&1");
	}
}

#==========================================
# getMBRDiskLabel
#------------------------------------------
sub getMBRDiskLabel {
	# ...
	# create a random 4byte MBR disk label ID, used
	# the isohybrid call as parameter
	# ---
	my $this  = shift;
	my $range = 0xfe;
	my @bytes;
	undef $this->{mbrid};
	for (my $i=0;$i<4;$i++) {
		$bytes[$i] = 1 + int(rand($range));
		redo if $bytes[0] <= 0xf;
	}
	my $nid = sprintf ("0x%02x%02x%02x%02x",
		$bytes[0],$bytes[1],$bytes[2],$bytes[3]
	);
	$this->{mbrid} = $nid;
	return $this;
}

1;

# vim: set noexpandtab:
