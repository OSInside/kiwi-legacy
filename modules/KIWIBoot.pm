#================
# FILE          : KIWIBoot.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to create a boot USB stick
#               : or boot cd from a previously created initrd
#               : image
#               :
#               :
# STATUS        : Development
#----------------
package KIWIBoot;
#==========================================
# Modules
#------------------------------------------
require Exporter;

use strict;
use warnings;
use Carp qw (cluck);
use FileHandle;
use File::Basename;
use File::Spec;
use Math::BigFloat;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIIsoLinux;
use KIWIQX qw (qxx);

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create KIWIBoot object which is used to create bootable
	# media images like CD/DVD's , USB sticks or Virtual disks
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
	my $initrd = shift;
	my $cmdL   = shift;
	my $system = shift;
	my $vmsize = shift;
	my $device = shift;
	my $profile= shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $syszip    = 0;
	my $sysird    = 0;
	my $zipped    = 0;
	my $firmware  = "bios";
	my $vga       = "0x314";
	my $vgroup    = "kiwiVG";
	my $haveTree  = 0;
	my $haveSplit = 0;
	my $vmmbyte;
	my $kernel;
	my $knlink;
	my $tmpdir;
	my $loopdir;
	my $result;
	my $status;
	my $isxen;
	my $xendomain;
	my $xengz;
	my $xml;
	#==========================================
	# check initrd file parameter
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if ((defined $initrd) && (! -f $initrd)) {
		$kiwi -> error  ("Couldn't find initrd file: $initrd");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check for split system
	#------------------------------------------
	if (($system) && (-f "$system/rootfs.tar")) {
		$kiwi -> error ("Can't use split root tree, run create first");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# find image type...
	#------------------------------------------
	if (! defined $cmdL->getBuildType()) {
		if ($initrd =~ /oemboot/) {
			$cmdL -> setBuildType ("oem");
		}
		if ($initrd =~ /vmxboot/) {
			$cmdL -> setBuildType ("vmx");
		}
	}
	#==========================================
	# check system image file parameter
	#------------------------------------------
	if (defined $system) {
		if ((-f $system) || (-b $system)) {
			my %fsattr = KIWIGlobals
				-> instance()
				-> checkFileSystem ($system);
			if ($fsattr{readonly}) {
				$syszip = KIWIGlobals -> instance() -> isize ($system);
			} else {
				$syszip = 0;
			}
		} elsif (! -d $system) {
			$kiwi -> error  ("Couldn't find image file/directory: $system");
			$kiwi -> failed ();
			return;
		} elsif (-f "$system/kiwi-root.cow") {
			#==========================================
			# Check for overlay structure
			#------------------------------------------
			$this->{overlay} = KIWIOverlay -> new($system);
			if (! $this->{overlay}) {
				return;
			}
			$system = $this->{overlay} -> mountOverlay();
			if (! -d $system) {
				return;
			}
		}
	}
	#==========================================
	# check if we got the tree or image file
	#------------------------------------------
	if (($system) && (-d $system)) {
		$haveTree = 1;
	}
	#==========================================
	# compressed initrd used...
	#------------------------------------------
	if (($initrd) && ($initrd =~ /\.gz$/)) {
		$zipped = 1;
	}
	#==========================================
	# find kernel file
	#------------------------------------------
	$kernel = $initrd;
	if (($kernel) && ($kernel =~ /gz$/)) {
		$kernel =~ s/gz$/kernel/;
	} else {
		$kernel = $kernel.".kernel";
	}
	if (! -e $kernel) {
		$kernel =~ s/splash\.kernel$/kernel/;
	}
	if (-l $kernel) {
		$knlink = $kernel;
		$kernel = readlink ($knlink);
		if (!File::Spec->file_name_is_absolute($kernel)) {
			$kernel = File::Spec->catfile(dirname($initrd), $kernel);
		}
	}
	if ((defined $initrd) && (! -f $kernel)) {
		$kiwi -> error  ("Couldn't find kernel file: $kernel");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check if Xen system is used
	#------------------------------------------
	$isxen = 0;
	$xengz = $initrd;
	if ($xengz) {
		$xengz =~ s/\.gz$//;
		$xengz =~ s/\.splash$//;
		foreach my $xen (glob ("$xengz*xen*.gz")) {
			$isxen = 1;
			$xengz = $xen;
			last;
		}
		if (! $isxen) {
			my $kernel = readlink $xengz.".kernel";
			if (($kernel) && ($kernel =~ /.*-xen$/)) {
				$isxen = 1;
			}
		}
	}
	#==========================================
	# create tmp dir for operations
	#------------------------------------------
	$tmpdir = qxx ("mktemp -qdt kiwiboot.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return;
	}
	$loopdir = qxx ("mktemp -qdt kiwiloop.XXXXXX"); chomp $loopdir;
	$result  = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $loopdir: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data (1)
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{cleanupStack} = [];
	$this->{gdata}    = $global -> getKiwiConfig();
	$this->{tmpdir}   = $tmpdir;
	$this->{loopdir}  = $loopdir;
	$this->{lvmgroup} = $vgroup;
	$this->{tmpdirs}  = [ $tmpdir, $loopdir ];
	$this->{haveTree} = $haveTree;
	$this->{kiwi}     = $kiwi;
	$this->{bootsize} = 100;
	$this->{isDisk}   = 0;
	#==========================================
	# setup pointer to XML configuration
	#------------------------------------------
	if (defined $system) {
		my $rootpath = $system;
		if (! -d $system) {
			#==========================================
			# mount system image
			#------------------------------------------
			if (! KIWIGlobals -> instance() -> mount ($system,$tmpdir)) {
				return;
			}
			my $sdev = KIWIGlobals -> instance() -> getMountDevice();
			if (KIWIGlobals -> instance() -> isMountLVM()) {
				$this->{lvmgroup} = KIWIGlobals
					-> instance()
					-> getMountLVMGroup();
				$this->{lvm} = 1;
			}
			#==========================================
			# check for read-only root
			#------------------------------------------
			my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($sdev);
			if ($fsattr{readonly}) {
				$syszip = KIWIGlobals -> instance() -> isize ($system);
			}
			#==========================================
			# set root path to mountpoint
			#------------------------------------------
			$rootpath = $tmpdir;
		}
		#==========================================
		# check for split type
		#------------------------------------------
		if (-f "$rootpath/rootfs.tar") {
			$cmdL -> setBuildType ("split");
			$haveSplit = 1;
		}
		#==========================================
		# read origin path of XML description
		#------------------------------------------
		if (open my $FD, '<', "$rootpath/image/main::Prepare") {
			my $idesc = <$FD>; close $FD;
			$this->{originXMLPath} = $idesc;
		}
		#==========================================
		# read and validate XML description
		#------------------------------------------
		my $locator = KIWILocator -> instance();
		my $controlFile = $locator -> getControlFile ($rootpath."/image");
		my $validator = KIWIXMLValidator -> new (
			$controlFile,
			$this->{gdata}->{Revision},
			$this->{gdata}->{Schema},
			$this->{gdata}->{SchemaCVT}
		);
		my $isValid = $validator ? $validator -> validate() : undef;
		if (! $isValid) {
			if (! -d $system) {
				KIWIGlobals -> instance() -> umount();
			}
			return;
		}
		$xml = KIWIXML -> new (
			$rootpath."/image",$cmdL->getBuildType(),$profile,$cmdL
		);
		#==========================================
		# clean up
		#------------------------------------------
		if (! -d $system) {
			$this->{isDisk} = KIWIGlobals -> instance() -> isDisk();
			KIWIGlobals -> instance() -> umount();
		}
		#==========================================
		# check if we got the XML description
		#------------------------------------------
		if (! defined $xml) {
			return;
		}
	}
	#==========================================
	# find Xen domain configuration
	#------------------------------------------
	if ($isxen && defined $xml) {
		my %xenc = $xml -> getXenConfig_legacy();
		if (defined $xenc{xen_domain}) {
			$xendomain = $xenc{xen_domain};
		} else {
			$xendomain = "dom0";
		}
	}
	#==========================================
	# Setup disk size and inode count
	#------------------------------------------
	if ((defined $system) && (defined $initrd)) {
		my $sizeBytes;
		my $minInodes;
		my $sizeXMLBytes = 0;
		my $spare        = 100 * 1024 * 1024; # 100M free
		my $fsoverhead   = 1.4;
		my $fsopts       = $cmdL -> getFilesystemOptions();
		my $inodesize    = $fsopts->[1];
		my $inoderatio   = $fsopts->[2];
		my $kernelSize   = KIWIGlobals -> instance() -> isize ($kernel);
		my $initrdSize   = KIWIGlobals -> instance() -> isize ($initrd);
		#==========================================
		# Calculate minimum size of the system
		#------------------------------------------
		if (-d $system) {
			# System is specified as a directory...
			$minInodes = qxx ("find $system | wc -l");
			$sizeBytes = qxx ("du -s --block-size=1 $system | cut -f1");
			$sizeBytes*= $fsoverhead;
			chomp $minInodes;
			chomp $sizeBytes;
			$minInodes*= 2;
			$sizeBytes+= $minInodes * $inodesize;
			$sizeBytes+= $kernelSize;
			$sizeBytes+= $initrdSize;
			$sizeBytes+= $spare;
		} else {
			# system is specified as a file...
			$sizeBytes = KIWIGlobals -> instance() -> isize ($system);
			$sizeBytes+= $kernelSize;
			$sizeBytes+= $initrdSize;
			$sizeBytes+= $spare;
		}
		#==========================================
		# Store optional size setup from XML
		#------------------------------------------
		my $sizeXMLAddBytes = $xml -> getImageSizeAdditiveBytes_legacy();
		if ($sizeXMLAddBytes) {
			$sizeXMLBytes = $sizeBytes + $sizeXMLAddBytes;
		} else {
			$sizeXMLBytes = $xml -> getImageSizeBytes_legacy();
		}
		#==========================================
		# Store initial disk size
		#------------------------------------------
		$this -> __initDiskSize ($sizeBytes,$vmsize,$sizeXMLBytes);
		#==========================================
		# Calculate required inode count for root
		#------------------------------------------
		if (-d $system) {
			# /.../
			# if the system is a directory the root filesystem
			# will be created during the image creation. In this
			# case we need to create the inode count
			# ----
			$this->{inodes} = int ($this->{vmmbyte} * 1048576 / $inoderatio);
			$kiwi -> loginfo (
				"Using ".$this->{inodes}." inodes for the root filesystem\n"
			);
		}
	}
	#==========================================
	# round compressed image size
	#------------------------------------------
	if ($syszip) {
		$syszip = $syszip / 1e6;
		$syszip = sprintf ("%.0f", $syszip);
	}
	#==========================================
	# Store a disk label ID for this object
	#------------------------------------------
	$this->{mbrid} = KIWIGlobals -> instance() -> getMBRDiskLabel (
		$cmdL -> getMBRID()
	);
	#==========================================
	# find system architecture
	#------------------------------------------
	my $arch = qxx ("uname -m"); chomp $arch;
	if (defined $xml) {
		#==========================================
		# check framebuffer vga value
		#------------------------------------------
		my %type = %{$xml->getImageTypeAndAttributes_legacy()};
		if ($type{vga}) {
			$vga = $type{vga};
		}
		if ($type{luks}) {
			KIWIGlobals
			-> instance()
			-> setKiwiConfigData ("LuksCipher",$type{luks});
		}
		#==========================================
		# check boot firmware
		#------------------------------------------
		if ($type{firmware}) {
			$firmware = $type{firmware};
		}
		if (($firmware eq 'uefi') && ($arch ne 'x86_64')) {
			$kiwi -> warning (
				"UEFI Secure boot is only supported on x86_64"
			);
			$kiwi -> skipped ();
			$firmware = 'bios';
		}
	}
	#==========================================
	# check partitioner
	#------------------------------------------
	my $ptool = $cmdL -> getPartitioner();
	if (! $ptool) {
		$ptool = $this->{gdata}->{Partitioner};
	}
	#==========================================
	# Store object data (2)
	#------------------------------------------
	$this->{initrd}    = $initrd;
	$this->{system}    = $system;
	$this->{kernel}    = $kernel;
	$this->{syszip}    = $syszip;
	$this->{device}    = $device;
	$this->{zipped}    = $zipped;
	$this->{isxen}     = $isxen;
	$this->{xengz}     = $xengz;
	$this->{arch}      = $arch;
	$this->{ptool}     = $ptool;
	$this->{vga}       = $vga;
	$this->{xml}       = $xml;
	$this->{cmdL}      = $cmdL;
	$this->{xendomain} = $xendomain;
	$this->{profile}   = $profile;
	$this->{haveSplit} = $haveSplit;
	$this->{imgtype}   = $cmdL->getBuildType();
	$this->{chainload} = $cmdL->getGrubChainload();
	$this->{firmware}  = $firmware;
	return $this;
}

#==========================================
# createBootStructure
#------------------------------------------
sub createBootStructure {
	my $this   = shift;
	my $loc    = shift;
	my $kiwi   = $this->{kiwi};
	my $initrd = $this->{initrd};
	my $tmpdir = $this->{tmpdir};
	my $kernel = $this->{kernel};
	my $zipped = $this->{zipped};
	my $isxen  = $this->{isxen};
	my $xengz  = $this->{xengz};
	my $xendomain = $this->{xendomain};
	my $lname  = "linux";
	my $iname  = "initrd";
	my $xname  = "xen.gz";
	my $zipper = $this->{gdata}->{Gzip};
	my $status;
	my $result;
	if (defined $loc) {
		$lname  = $lname.".".$loc;
		$iname  = $iname.".".$loc;
		$xname  = $xname.".".$loc;
	}
	if ($initrd !~ /splash\.gz$|splash\.install\.gz/) {
		$initrd = $this -> setupSplash();
		$zipped = 1;
	}
	$kiwi -> info ("Creating initial boot structure");
	$status = qxx ( "mkdir -p $tmpdir/boot 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating initial directories: $status");
		$kiwi -> failed ();
		return;
	}
	if ($zipped) {
		$status = qxx ( "cp $initrd $tmpdir/boot/$iname 2>&1" );
	} else {
		$status = qxx ( "cat $initrd | $zipper > $tmpdir/boot/$iname" );
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing initrd: $!");
		$kiwi -> failed ();
		return;
	}
	$status = qxx ( "cp $kernel $tmpdir/boot/$lname 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing kernel: $!");
		$kiwi -> failed ();
		return;
	}
	if (($isxen) && ($xendomain eq "dom0")) {
		$status = qxx ( "cp $xengz $tmpdir/boot/$xname 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing Xen dom0 kernel: $!");
			$kiwi -> failed ();
			return;
		}
	}
	qxx ("touch $tmpdir/boot/$this->{mbrid}");
	$kiwi -> done();
	return $tmpdir;
}

#==========================================
# getRemovableUSBStorageDevices
#------------------------------------------
sub getRemovableUSBStorageDevices {
	my $this    = shift;
	my %devices = ();
	my @storage = glob ("/sys/bus/usb/drivers/usb-storage/*");
	foreach my $device (@storage) {
		if (-l $device) {
			my @descriptions = glob ("$device/host*/target*/*/block*");
			foreach my $description (@descriptions) {
				if (! -d $description) {
					next;
				}
				my $isremovable = "$description/removable";
				my $serial = "USB Stick (unknown type)";
				if ($description =~ /usb-storage\/(.*?):.*/) {
					$serial = "/sys/bus/usb/devices/$1/serial";
					if (open (my $FD,'<',$serial)) {
						$serial = <$FD>;
						chomp $serial;
						close $FD;
					}
				}
				if ($description =~ /block:(.*)/) {
					$description = "/dev/".$1;
				} else {
					my @bdevs = glob ("$description/*");	
					my $bdev = basename ($bdevs[0]);
					$isremovable = $description."/".$bdev."/removable";
					$description = "/dev/".$bdev;
				}
				my $FD;
				if (! open ($FD,'<',$isremovable)) {
					next;
				}
				$isremovable = <$FD>; close $FD;
				if ($isremovable == 1) {
					my $result = $this -> getStorageSize ($description);
					if ($result > 0) {
						$devices{$description} = $serial;
					}
				}
			}
		}
	}
	return %devices;
}

#==========================================
# setupInstallCD
#------------------------------------------
sub setupInstallCD {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $arch      = $this->{arch};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $oldird    = $this->{initrd};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $lvm       = $this->{lvm};
	my $xml       = $this->{xml};
	my $firmware  = $this->{firmware};
	my $md5name   = $system;
	my $destdir   = dirname ($initrd);
	my $gotsys    = 1;
	my $volid     = "KIWI CD/DVD Installation";
	my $appid     = $this->{mbrid};
	my $bootloader;
	if ($arch =~ /ppc|ppc64/) {
		$bootloader = "yaboot";
	} elsif ($arch =~ /arm/) {
		$bootloader = "uboot";
	} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
		$bootloader = "grub2";
	} else {
		$bootloader = "grub";
	}
	my $efi_arch= 'x86_64';
	if ($arch ne 'x86_64') {
		$efi_arch = 'i386';
	}
	my $status;
	my $result;
	my $tmpdir;
	my %type;
	my $haveDiskDevice;
	my $version;
	my $FD;
	#==========================================
	# Check for disk device
	#------------------------------------------
	if (($system) && (-b $system)) {
		$haveDiskDevice = $system;
		$version = $xml -> getImageVersion_legacy();
		$system  = $xml -> getImageName();
		$system  = $destdir."/".$system.".".$arch."-".$version.".raw";
		$md5name = $system;
		$this->{system} = $system;
	}
	#==========================================
	# Create new MBR label for install ISO
	#------------------------------------------
	$this->{mbrid} = KIWIGlobals -> instance() -> getMBRDiskLabel();
	$appid = $this->{mbrid};
	$kiwi -> info ("Using ISO Application ID: $appid");
	$kiwi -> done();
	#==========================================
	# read config XML attributes
	#------------------------------------------
	if (defined $xml) {
		%type = %{$xml->getImageTypeAndAttributes_legacy()};
	}
	#==========================================
	# check for volume id
	#------------------------------------------
	if ((%type) && ($type{volid})) {
		$volid = $type{volid};
	}
	#==========================================
	# setup boot loader type
	#------------------------------------------
	if ((%type) && ($type{bootloader})) {
		$bootloader = $type{bootloader};
	}
	#==========================================
	# create tmp directory
	#------------------------------------------
	my $basedir;
	if ($system) {
		$basedir = dirname ($system);
	} else {
		$basedir = dirname ($initrd);
	}
	$tmpdir = qxx ( "mktemp -q -d $basedir/kiwicdinst.XXXXXX" ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return;
	}
	$this->{tmpdir} = $tmpdir;
	push @{$this->{tmpdirs}},$tmpdir;
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check if system image is given
	#------------------------------------------
	if (! $system) {
		$system = $initrd;
		$gotsys = 0;
	}
	#==========================================
	# build label from xml data
	#------------------------------------------
	if ($gotsys) {
		$this->{bootlabel} = $xml -> getImageDisplayName();
	}
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	if ($gotsys) {
		if (! $haveDiskDevice) {
			$this -> buildMD5Sum ($system);
		} else {
			$this -> buildMD5Sum ($this->{loop},$system);
		}
	}
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $namecd = basename ($system);
	#==========================================
	# Compress system image
	#------------------------------------------
	if ($gotsys) {
		$md5name =~ s/\.raw$/\.md5/;
		$kiwi -> info ("Compressing installation image...");
		$result = 0;
		if ($haveDiskDevice) {
			# /.../
			# Unfortunately mksquashfs can not use a block device as
			# input file so we have to create a file from the device
			# first and pass that to mksquashfs
			# ----
			$status = qxx (
				"qemu-img convert -f raw -O raw $haveDiskDevice $system"
			);
			$result = $? >> 8;
		}
		if ($result == 0) {
			$status = qxx (
				"mksquashfs $system $md5name $system.squashfs -no-progress 2>&1"
			);
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to compress system image: $status");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
		$system = $system.".squashfs";
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$kiwi -> info ("Repack initrd with install flags...");
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		return;
	}
	$this->{initrd} = $initrd;
	$kiwi -> done();
	#==========================================
	# Create CD structure
	#------------------------------------------
	if (! $this -> createBootStructure()) {
		$this->{initrd} = $oldird;
		return;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader,"iso")) {
		return;
	}
	qxx ("rm -rf $tmpdir/usr 2>&1");
	qxx ("rm -rf $tmpdir/image 2>&1");
	$this->{initrd} = $oldird;
	#==========================================
	# Creating boot loader configuration
	#------------------------------------------
	my $title = "KIWI CD Installation";
	if (! $gotsys) {
		$title = "KIWI CD Boot: $namecd";
	}
	if (! $this -> setupBootLoaderConfiguration (
		$bootloader,$title,undef,"ISO")
	) {
		return;
	}
	#==========================================
	# Check for optional config-cdroot archive
	#------------------------------------------
	my $cdrootData = "config-cdroot.tgz";
	if (-f "$destdir/$cdrootData") {
		$kiwi -> info ("Integrating CD root information...");
		$status= qxx (
			"tar -C $tmpdir -xvf $destdir/$cdrootData"
		);
		$result= $? >> 8;
		qxx ("rm -f $destdir/$cdrootData");
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to integrate CD root data: $status");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	my $cdrootScript = "config-cdroot.sh";
	if (-x "$destdir/$cdrootScript") {
		$kiwi -> info ("Calling CD root setup script...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $script = "$destdir/$cdrootScript";
		if ($script !~ /^\//) {
			$script = $pwd."/".$script;
		}
		$status = qxx (
			"cd $tmpdir && bash -c $script 2>&1"
		);
		$result = $? >> 8;
		qxx ("rm -f $script");
		if ($result != 0) {
			chomp $status;
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to call CD root script: $status");
			$kiwi -> failed ();
			return;
		} else {
			$kiwi -> loginfo ("config-cdroot.sh: $status");
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy system image if given
	#------------------------------------------
	if ($gotsys) {
		my $FD;
		if (! open ($FD,'>',"$tmpdir/config.isoclient")) {
			$kiwi -> error  ("Couldn't create CD install flag file");
			$kiwi -> failed ();
			return;
		}
		print $FD "IMAGE='".$namecd."'\n";
		close $FD;
		$kiwi -> info ("Importing system image: $system");
		$status = qxx ("mv $system $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			return;
		}
		$system =~ s/\.squashfs$//;
		$kiwi -> done();
	}
	#==========================================
	# copy grub2 config file to efi path too
	#------------------------------------------
	if (($firmware eq "efi") || ($firmware eq "uefi")) {
		qxx ("mkdir -p $tmpdir/EFI/BOOT");
		qxx ("cp $tmpdir/boot/grub2-efi/grub.cfg $tmpdir/EFI/BOOT");
	}
	#==========================================
	# make iso EFI bootable
	#------------------------------------------
	if (($firmware eq "efi") || ($firmware eq "uefi")) {
		my $efi_fat = "$tmpdir/boot/$efi_arch/efi";
		$status = qxx ("mkdir -p $tmpdir/boot/$efi_arch");
		$result = $? >> 8;
		if ($result == 0) {
			$status = qxx ("qemu-img create $efi_fat 4M 2>&1");
			$result = $? >> 8;
		}
		if ($result == 0) {
			$status = qxx ("/sbin/mkdosfs -n 'BOOT' $efi_fat 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx ("mcopy -Do -s -i $efi_fat $tmpdir/EFI :: 2>&1");
				$result = $? >> 8;
			}
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating efi fat image: $status");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Create an iso image from the tree
	#------------------------------------------
	$kiwi -> info ("Creating ISO image...");
	my $name = $system;
	if ($gotsys) {
		$name =~ s/raw$/install\.iso/;
	} else {
		$name =~ s/gz$/install\.iso/;
	}
	my $base;
	my $opts;
	if ($bootloader eq "grub2") {
		# let mkisofs run grub2 efi or eltorito image...
		$base = "-V \"$volid\" -A \"$appid\" -R -J -f ";
		if (($firmware eq "efi") || ($firmware eq "uefi")) {
			$base.= "-b boot/$efi_arch/efi -no-emul-boot ";
		} else {
			$base.= "-b boot/grub2/i386-pc/eltorito.img -no-emul-boot ";
			$base.= "-boot-load-size 4 -boot-info-table -udf ";
			$base.= "-allow-limited-size ";
		}
		$opts.= "-joliet-long ";
	} elsif ($bootloader eq "grub") {
		# let isolinux run grub second stage...
		$base = "-R -J -f -b boot/grub/stage2 -no-emul-boot ";
		$base.= "-V \"$volid\" -A \"$appid\"";
		$opts = "-boot-load-size 4 -boot-info-table -udf -allow-limited-size ";
		$opts.= "-pad -joliet-long";
	} elsif ($bootloader =~ /(sys|ext)linux/) {
		# turn sys/extlinux configuation into a isolinux configuration...
		my $cfg_ext = "$tmpdir/boot/syslinux/syslinux.cfg";
		if (! -f $cfg_ext) {
			$cfg_ext = "$tmpdir/boot/syslinux/extlinux.conf";
		}
		my $cfg_iso = "$tmpdir/boot/syslinux/isolinux.cfg";
		qxx ("mv $cfg_ext $cfg_iso 2>&1");
		qxx ("mv $tmpdir/boot/initrd $tmpdir/boot/syslinux");
		qxx ("mv $tmpdir/boot/linux  $tmpdir/boot/syslinux");
		qxx ("mv $tmpdir/boot/syslinux $tmpdir/boot/loader 2>&1");
		$base = "-R -J -f -b boot/loader/isolinux.bin -no-emul-boot ";
		$base.= "-V \"$volid\" -A \"$appid\"";
		$opts = "-boot-load-size 4 -boot-info-table -udf -allow-limited-size ";
		$opts.= "-pad -joliet-long";
	} elsif ($bootloader eq "yaboot") {
		$base = "-r";
		$opts = "-U -chrp-boot -pad -joliet-long";
	} else {
		# don't know how to use this bootloader together with isolinux
		$kiwi -> failed ();
		$kiwi -> error  ("Bootloader not supported for CD inst: $bootloader");
		$kiwi -> failed ();
		return;
	}
	my $wdir = qxx ("pwd"); chomp $wdir;
	if ($name !~ /^\//) {
		$name = $wdir."/".$name;
	}
	my $iso = KIWIIsoLinux -> new (
		$tmpdir,$name,$base.' '.$opts,"checkmedia",
		$this->{cmdL},$this->{xml}
	);
	if (! defined $iso) {
		return;
	}
	if ($bootloader =~ /(sys|ext)linux/) {
		$iso -> createISOLinuxConfig ("/boot");
	}
	if (! $iso -> createISO()) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating ISO image: $status");
		$kiwi -> failed ();
		$iso  -> cleanISO ();
		return;
	}
	$kiwi -> done ();
	if ($bootloader =~ /(sys|ext)linux/) {
		if (! $iso->createHybrid($this->{mbrid})) {
			return;
		}
	}
	if ($bootloader ne "yaboot") {
		if (! $iso -> relocateCatalog ()) {
			$iso  -> cleanISO ();
			return;
		}
		if (! $iso -> fixCatalog()) {
			$iso  -> cleanISO ();
			return;
		}
	}
	#==========================================
	# Clean tmp
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	my $imgfile = basename $name;
	$kiwi -> info ("Created $imgfile to be burned on CD");
	$kiwi -> done ();
	$iso  -> cleanISO ();
	return $this;
}

#==========================================
# setupInstallStick
#------------------------------------------
sub setupInstallStick {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $arch      = $this->{arch};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $oldird    = $this->{initrd};
	my $device    = $this->{device};
	my $loopdir   = $this->{loopdir};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $lvm       = $this->{lvm};
	my $xml       = $this->{xml};
	my $cmdL      = $this->{cmdL};
	my $firmware  = $this->{firmware};
	my $irdsize   = KIWIGlobals -> instance() -> isize ($initrd);
	my $vmsize    = KIWIGlobals -> instance() -> isize ($system);
	my $md5name   = $system;
	my $destdir   = dirname ($initrd);
	my %deviceMap = ();
	my @commands  = ();
	my $gotsys    = 1;
	my $bootloader;
	if ($arch =~ /ppc|ppc64/) {
		$bootloader = "yaboot";
	} elsif ($arch =~ /arm/) {
		$bootloader = "uboot";
	} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
		$bootloader = "grub2";
	} else {
		$bootloader = "grub";
	}
	my $haveDiskDevice;
	my $status;
	my $result;
	my $version;
	my $tmpdir;
	my %type;
	my $stick;
	my $diskname;
	#==========================================
	# Clear image inode setup, use default
	#------------------------------------------
	undef $this->{inodes};
	#==========================================
	# Create new MBR label for install disk
	#------------------------------------------
	$this->{mbrid} = KIWIGlobals -> instance() -> getMBRDiskLabel();
	#==========================================
	# Check for disk device
	#------------------------------------------
	if (($system) && (-b $system)) {
		$haveDiskDevice = $system;
		$version = $xml -> getImageVersion_legacy();
		$system  = $xml -> getImageName();
		$system  = $destdir."/".$system.".".$arch."-".$version.".raw";
		$md5name = $system;
		$this->{system} = $system;
	}
	#==========================================
	# read config XML attributes
	#------------------------------------------
	if (defined $xml) {
		%type = %{$xml->getImageTypeAndAttributes_legacy()};
	}
	#==========================================
	# setup boot loader type
	#------------------------------------------
	if ((%type) && ($type{bootloader})) {
		$bootloader = $type{bootloader};
	}
	#==========================================
	# create tmp directory
	#------------------------------------------
	$tmpdir = qxx ( "mktemp -qdt kiwistickinst.XXXXXX" ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return;
	}
	$this->{tmpdir} = $tmpdir;
	push @{$this->{tmpdirs}},$tmpdir;
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check if system image is given
	#------------------------------------------
	if ($system) {
		$diskname = $system.".install.raw";
	} else {
		$system   = $initrd;
		$diskname = $initrd;
		$diskname =~ s/gz$/install\.raw/;
		$gotsys   = 0;
	}
	#==========================================
	# check for boot menu entry base name
	#------------------------------------------
	if ($gotsys) {
		$this->{bootlabel} = $xml -> getImageDisplayName();
	}
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	if ($gotsys) {
		if (! $haveDiskDevice) {
			$this -> buildMD5Sum ($system);
		} else {
			$this -> buildMD5Sum ($haveDiskDevice,$system);
		}
	}
	#==========================================
	# Compress system image
	#------------------------------------------
	if ($gotsys) {
		$md5name =~ s/\.raw$/\.md5/;
		$kiwi -> info ("Compressing installation image...");
		$result = 0;
		if ($haveDiskDevice) {
			$status = qxx (
				"qemu-img convert -f raw -O raw $haveDiskDevice $system"
			);
			$result = $? >> 8;
		}
		if ($result == 0) {
			$status = qxx (
				"mksquashfs $system $md5name $system.squashfs -no-progress 2>&1"
			);
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to compress system image: $status");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
		$system = $system.".squashfs";
		$vmsize = -s $system;
	}
	#==========================================
	# setup required disk size
	#------------------------------------------
	$irdsize= ($irdsize / 1e6) + 40;
	$irdsize= sprintf ("%.0f", $irdsize);
	$vmsize = ($vmsize / 1e6) * 1.3 + $irdsize;
	$vmsize = sprintf ("%.0f", $vmsize);
	$vmsize = $vmsize."M";
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $nameusb = basename ($system);
	#==========================================
	# Create virtual disk to be dumped on stick
	#------------------------------------------
	$kiwi -> info ("Creating virtual disk...");
	$status = qxx ("qemu-img create $diskname $vmsize 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual disk: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	$kiwi -> info ("Binding virtual disk to loop device");
	if (! $this -> bindDiskDevice ($diskname)) {
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	#==========================================
	# check required boot filesystem type
	#------------------------------------------
	my $bootfs = 'ext3';
	my $partid = "83";
	if ($type{bootfilesystem}) {
		$bootfs = $type{bootfilesystem};
	} elsif ($bootloader eq 'syslinux') {
		$bootfs = 'fat32';
	} elsif ($bootloader eq 'yaboot') {
		if ($lvm) {
			$bootfs = 'fat16';
		} else {
			$bootfs = 'fat32';
		}
	} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
		$bootfs = 'fat16';
	} else {
		$bootfs = 'ext3';
	}
	#==========================================
	# setup boot partition type
	#------------------------------------------
	if ($bootfs =~ /^fat/) {
		$partid = "c";
	}
	#==========================================
	# create disk partitions
	#------------------------------------------
	$kiwi -> info ("Create partition table for install media");
	if ($gotsys) {
		@commands = (
			"n","p","1",".","+".$irdsize."M",
			"n","p","2",".",".",
			"t","1",$partid,
			"a","1","w","q"
		);
		$this->{partids}{boot} = '1';
		$this->{partids}{root} = '2';
	} else {
		@commands = (
			"n","p","1",".",".",
			"t","1",$partid,
			"a","1","w","q"
		);
		$this->{partids}{boot} = '1';
	}
	if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create partition table");
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	$kiwi -> done();
	#==========================================
	# setup device mapper
	#------------------------------------------
	$kiwi -> info ("Setup device mapper for partition access");
	if (! $this -> bindDiskPartitions ($this->{loop})) {
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	$kiwi -> done();
	#==========================================
	# Create loop device mapping table
	#------------------------------------------
	%deviceMap = $this -> setLoopDeviceMap ($this->{loop});
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$kiwi -> info ("Repack initrd with install flags...");
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		return;
	}
	$this->{initrd} = $initrd;
	$kiwi -> done();
	#==========================================
	# Create Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this->{initrd} = $oldird;
		return;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		return;
	}
	#==========================================
	# Creating boot loader configuration
	#------------------------------------------
	my $title = "KIWI USB-Stick Installation";
	if (! $gotsys) {
		$title = "KIWI USB Boot: $nameusb";
	}
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$title)) {
		return;
	}
	$this->{initrd} = $oldird;
	#==========================================
	# Setup device names
	#------------------------------------------
	my $boot = $deviceMap{boot};
	my $data;
	if ($gotsys) {
		$data = $deviceMap{root};
	}
	#==========================================
	# Create filesystem on partitions
	#------------------------------------------
	foreach my $root ($boot,$data) {
		next if ! defined $root;
		if ($root eq $boot) {
			#==========================================
			# build boot filesystem
			#------------------------------------------
			if (! $this -> setupFilesystem ($bootfs,$root,"install-boot","BOOT")
			) {
				$this -> cleanStack ();
				return;
			}
		} else {
			#==========================================
			# build root filesystem
			#------------------------------------------
			if (! $this -> setupFilesystem ('ext3',$root,"install-root")) {
				$this -> cleanStack ();
				return;
			}
		}
	}
	#==========================================
	# Copy boot data on first partition
	#------------------------------------------
	$kiwi -> info ("Installing boot data to disk");
	if (! KIWIGlobals -> instance() -> mount ($boot, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount boot partition: $status");
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	if (! $this -> copyBootCode ($tmpdir,$loopdir,$bootloader)) {
		KIWIGlobals -> instance() -> umount();
		return;
	}
	KIWIGlobals -> instance() -> umount();
	$kiwi -> done();
	#==========================================
	# Check for optional config-cdroot archive
	#------------------------------------------
	my $cdrootData = "config-cdroot.tgz";
	if (-f "$destdir/$cdrootData") {
		$kiwi -> info ("Integrating CD root information...");
		$status= qxx (
			"tar -C $loopdir -xvf $destdir/$cdrootData"
		);
		$result= $? >> 8;
		qxx ("rm -f $destdir/$cdrootData");
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to integrate CD root data: $status");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	my $cdrootScript = "config-cdroot.sh";
	if (-x "$destdir/$cdrootScript") {
		$kiwi -> info ("Calling CD root setup script...");
		my $pwd = qxx ("pwd"); chomp $pwd;
		my $script = "$destdir/$cdrootScript";
		if ($script !~ /^\//) {
			$script = $pwd."/".$script;
		}
		$status = qxx (
			"cd $loopdir && bash -c $script 2>&1"
		);
		$result = $? >> 8;
		qxx ("rm -f $script");
		if ($result != 0) {
			chomp $status;
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to call CD root script: $status");
			$kiwi -> failed ();
			return;
		} else {
			$kiwi -> loginfo ("config-cdroot.sh: $status");
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy system image if defined
	#------------------------------------------
	if ($gotsys) {
		$kiwi -> info ("Installing image data to disk");
		if (! KIWIGlobals
			-> instance()
			-> mount ($data, $loopdir,$type{fsmountoptions})) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount data partition: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		$status = qxx ("mv $system $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		my $FD;
		if (! open ($FD,'>',"$loopdir/config.usbclient")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create USB install flag file");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		print $FD "IMAGE='".$nameusb."'\n";
		close $FD;
		KIWIGlobals -> instance() -> umount();
		$kiwi -> done();
	}
	#==========================================
	# Install boot loader on disk
	#------------------------------------------
	my $bootdevice = $diskname;
	if (! $this -> installBootLoader ($bootloader, $bootdevice)) {
		$this -> cleanStack ();
		return;
	}
	$this -> cleanStack();
	my $imgfile = basename $diskname;
	$kiwi -> info ("Created $imgfile to be dd'ed on Stick");
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupInstallPXE
#------------------------------------------
sub setupInstallPXE {
	my $this = shift;
	my $kiwi      = $this->{kiwi};
	my $zipper    = $this->{gdata}->{Gzip};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $xml       = $this->{xml};
	my $zipped    = $this->{zipped};
	my $arch      = $this->{arch};
	my $vgroup    = $this->{lvmgroup};
	my $lvm       = $this->{lvm};
	my $imgtype   = $this->{imgtype};
	my %type      = %{$xml->getImageTypeAndAttributes_legacy()};
	my $destdir   = dirname ($initrd);
	my $md5name   = $system;
	my $appname;
	my $sysname;
	my $irdname;
	my $krnname;
	my $tarname;
	my $haveDiskDevice;
	my $status;
	my $result;
	my $version;
	my @packfiles;
	#==========================================
	# Create new MBR label for PXE install
	#------------------------------------------
	$this->{mbrid} = KIWIGlobals -> instance() -> getMBRDiskLabel();
	#==========================================
	# Check for disk device
	#------------------------------------------
	if (-b $system) {
		$haveDiskDevice = $system;
		$version = $xml -> getImageVersion_legacy();
		$system  = $xml -> getImageName();
		$system  = $destdir."/".$system.".".$arch."-".$version.".raw";
		$md5name = $system;
		$this->{system} = $system;
	}
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check if system image is given
	#------------------------------------------
	if (! defined $system) {
		$kiwi -> error  ("System raw disk image required");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check for kernel image
	#------------------------------------------
	$krnname = $initrd;
	if ($krnname =~ /gz$/) {
		$krnname =~ s/gz$/kernel/;
	} else {
		$krnname = $krnname.".kernel";
	}
	if (! -e $krnname) {
		$krnname =~ s/splash\.kernel$/kernel/;
	}
	if (-l $krnname) {
		my $knlink = $krnname;
		$krnname = readlink ($knlink);
		if (!File::Spec->file_name_is_absolute($krnname)) {
			$krnname = File::Spec->catfile(dirname($initrd), $krnname);
		}
	}
	if (! -e $krnname) {
		$kiwi -> error  ("Can't find kernel image: $krnname");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	if (! $haveDiskDevice) {
		$this -> buildMD5Sum ($system);
	} else {
		$this -> buildMD5Sum ($this->{loop},$system);
	}
	$md5name =~ s/\.raw$/\.md5/;
	#==========================================
	# Create PXE config append information
	#------------------------------------------
	$appname = $system;
	$appname =~ s/\.raw$/\.append/;
	my $appfd = FileHandle -> new();
	if ($appfd -> open(">$appname")) {
		print $appfd 'pxe=1';
		if ($type{cmdline}) {
			print $appfd " $type{cmdline}";
		}
		if ($lvm) {
			print $appfd " VGROUP=$vgroup";
		}
		if ($imgtype eq 'split') {
			print $appfd ' COMBINED_IMAGE=yes';
		}
		if ($type{bootloader}) {
			print $appfd " loader=$type{bootloader}";
		}
		print $appfd "\n";
		$appfd -> close();
	} else {
		$kiwi -> error  ("Failed to create append file: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Compress system image
	#------------------------------------------
	$kiwi -> info ("Compressing installation image...");
	$result = 0;
	$sysname = $system;
	$sysname =~ s/\.raw$/\.gz/;
	if ($haveDiskDevice) {
		$status = qxx (
			"qemu-img convert -f raw -O raw $haveDiskDevice $system"
		);
		$result = $? >> 8;
	}
	if ($result == 0) {
		$status = qxx ("$zipper -c $system > $sysname 2>&1");
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to compress system image: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$kiwi -> info ("Repack initrd with install flags...");
	$irdname = $this -> setupInstallFlags();
	if (! defined $irdname) {
		return;
	}
	$kiwi -> done();
	#==========================================
	# Pack result into tarball
	#------------------------------------------
	$kiwi -> info ("Packing installation data...");
	$tarname = $system;
	$tarname =~ s/\.raw$/\.install\.tgz/;
	foreach my $file ($md5name,$sysname,$irdname,$krnname,$appname) {
		push @packfiles, basename $file;
	}
	$status = qxx (
		"tar -C $destdir -czf $tarname @packfiles"
	);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to pack PXE install data: $status");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> done();
	unlink $md5name;
	unlink $sysname;
	unlink $irdname;
	unlink $appname;
	$kiwi -> info ("Successfully created PXE data set: $tarname");
	$kiwi -> done();
	return $this;
}

#==========================================
# setupBootDisk
#------------------------------------------
sub setupBootDisk {
	my $this      = shift;
	my $device    = shift;
	my $kiwi      = $this->{kiwi};
	my $arch      = $this->{arch};
	my $system    = $this->{system};
	my $syszip    = $this->{syszip};
	my $tmpdir    = $this->{tmpdir};
	my $initrd    = $this->{initrd};
	my $loopdir   = $this->{loopdir};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $lvm       = $this->{lvm};
	my $profile   = $this->{profile};
	my $xendomain = $this->{xendomain};
	my $xml       = $this->{xml};
	my $cmdL      = $this->{cmdL};
	my $haveTree  = $this->{haveTree};
	my $imgtype   = $this->{imgtype};
	my $haveSplit = $this->{haveSplit};
	my $firmware  = $this->{firmware};
	my $diskname  = $system.".raw";
	my %deviceMap = ();
	my @commands  = ();
	my $bootfix   = "VMX";
	my $haveluks  = 0;
	my $needJumpP = 0;
	my $needBootP = 0;
	my $needParts = 1;
	my $rawRW     = 0;
	my $md        = 0;
	my $bootloader;
	if ($arch =~ /ppc|ppc64/) {
		$bootloader = "yaboot";
	} elsif ($arch =~ /arm/) {
		$bootloader = "uboot";
	} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
		$bootloader = "grub2";
	} else {
		$bootloader = "grub";
	}
	my $boot;
	my $partidfile;
	my $haveDiskDevice;
	my $splitfile;
	my $version;
	my $label;
	my $FSTypeRW;
	my $FSTypeRO;
	my $sysname;
	my $sysird;
	my $result;
	my $status;
	my $destdir;
	my %lvmparts;
	#==========================================
	# check if we can operate on this root
	#------------------------------------------
	if ($this->{isDisk}) {
		$kiwi -> error ("System is specified as raw disk device");
		$kiwi -> failed();
		$kiwi -> error (
			"Required is either a root: directory, fsimage, or partition"
		);
		$kiwi -> failed();
		return;
	}
	#==========================================
	# check if we got a real device
	#------------------------------------------
	if ($device) {
		$haveDiskDevice = $device;
	}
	#==========================================
	# load type attributes...
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes_legacy()};
	if (! $type{installiso}) {
		$type{installiso} = 'false';
	}
	if (! $type{installstick}) {
		$type{installstick} = 'false';
	}
	if (! $type{installpxe}) {
		$type{installpxe} = 'false';
	}
	#==========================================
	# Check for software raid...
	#------------------------------------------
	if ($type{mdraid}) {
		$md = $type{mdraid};
		$this->{md} = $md;
	}
	#==========================================
	# Check for LVM...
	#------------------------------------------
	if ((($type{lvm}) && ($type{lvm} eq "true")) || ($lvm)) {
		#==========================================
		# add boot space if lvm based
		#------------------------------------------
		$lvm = 1;
		$this->{lvm}= $lvm;
		#==========================================
		# set volume group name
		#------------------------------------------
		my $vgroupName = $xml -> getLVMGroupName_legacy();
		if ($vgroupName) {
			$this->{lvmgroup} = $vgroupName;
		}
		#==========================================
		# check and set LVM volumes setup
		#------------------------------------------
		%lvmparts = $xml -> getLVMVolumes_legacy();
		if (%lvmparts) {
			if ( ! -d $system ) {
				$kiwi -> error (
					"LVM volumes setup requires root tree but got image file"
				);
				$kiwi -> failed ();
				return;
			}
			foreach my $vol (keys %lvmparts) {
				#==========================================
				# check directory per volume
				#------------------------------------------
				my $pname  = $vol; $pname =~ s/_/\//g;
				if (! -d "$system/$pname") {
					$kiwi -> error ("LVM: No such directory $system/$pname");
					$kiwi -> failed ();
					return;
				}
				#==========================================
				# calculate size required by volume
				#------------------------------------------
				my $lvsize = qxx (
					"du -s --block-size=1 $system/$pname | cut -f1"
				);
				chomp $lvsize;
				$lvsize /= 1048576;
				#==========================================
				# use 20% (min 30M) spare space per volume
				#------------------------------------------
				my $spare = int (($lvsize * 1.2) - $lvsize);
				if ($spare < 30) {
					$spare = 30;
				}
				my $spare_on_volume = $spare;
				my $serve_on_disk   = $spare;
				#==========================================
				# is requested size absolute or relative
				#------------------------------------------
				my $reqAbsolute = 0;
				if ($lvmparts{$vol}) {
					$reqAbsolute = $lvmparts{$vol}->[1];
				}
				#==========================================
				# requested size value
				#------------------------------------------
				my $reqSize = 0;
				# /.../
				# The requested volume size is only used if the image
				# type is _not_ oem. That's because for oem images the
				# size of the volumes is created by a resize operation
				# on first boot of the appliance
				# ----
				if (($type{type} ne "oem") && ($lvmparts{$vol})) {
					$reqSize = $lvmparts{$vol}->[0];
					if ($reqSize eq "all") {
						$reqSize = 0;
					}
				}
				#==========================================
				# calculate volume size
				#------------------------------------------
				my $addToDisk = 0;
				if ($reqAbsolute) {
					# process absolute size value from XML
					if ($reqSize > ($lvsize + $spare_on_volume)) {
						$addToDisk = $reqSize - $lvsize;
						$lvsize = $reqSize;
					} else {
						$addToDisk = $serve_on_disk;
						$lvsize += $spare_on_volume;
					}
				} else {
					# process relative size value from XML
					$lvsize = int ( $lvsize + $reqSize + $spare_on_volume);
					$addToDisk = $reqSize + $serve_on_disk;
				}
				#==========================================
				# add calculated volume size to lvmparts
				#------------------------------------------
				$lvmparts{$vol}->[2] = $lvsize;
				#==========================================
				# increase total vm disk size
				#------------------------------------------
				$kiwi->loginfo ("Increasing disk size for volume $pname\n");
				$this -> __updateDiskSize ($addToDisk);
			}
		}
	}
	#==========================================
	# check for LUKS extension
	#------------------------------------------
	if ($type{luks}) {
		$haveluks = 1;
	}
	#==========================================
	# check for raw read-write overlay
	#------------------------------------------
	if ($type{filesystem} eq "clicfs") {
		$rawRW = 1;
	}
	#==========================================
	# setup boot loader type
	#------------------------------------------
	if ($type{bootloader}) {
		$bootloader = $type{bootloader};
	}
	$this->{bootloader} = $bootloader;
	#==========================================
	# setup boot partition ID
	#------------------------------------------
	if ($md) {
		$needBootP = 1;
		$needParts = 2;
	}
	if ($lvm) {
		$needBootP = 1;
		$needParts = 2;
	} elsif ($syszip) {
		$needBootP = 1;
		$needParts = 2;
		if ($imgtype eq "split") {
			$needBootP = 1;
			$needParts = 3;
		} elsif ($type{filesystem} eq "clicfs") {
			$needBootP = 1;
			$needParts = 3;
		} elsif ($bootloader =~ /(sys|ext)linux|yaboot|uboot/) {
			$needBootP = 1;
			$needParts = 3;
		} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
			$needBootP = 1;
			$needParts = 3;
		} elsif ($type{luks}) {
			$needBootP = 1;
			$needParts = 3;
		}
	} elsif ($type{filesystem} =~ /btrfs|xfs/) {
		$needBootP = 1;
		$needParts = 2;
	} elsif ($bootloader =~ /(sys|ext)linux|yaboot|uboot/) {
		$needBootP = 1;
		$needParts = 2;
	} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
		$needBootP = 1;
		$needParts = 2;
	} elsif ($type{luks}) {
		$needBootP = 1;
		$needParts = 2;
	}
	$this->{needBootP} = $needBootP;
	#==========================================
	# check root partition type
	#------------------------------------------
	my $rootid = '83';
	if ($lvm) {
		$rootid = '8e';
	}
	if ($md) {
		$rootid = 'fd';
	}
	#==========================================
	# check required boot filesystem type
	#------------------------------------------
	my $partid = 83;
	my $bootfs = 'ext3';
	if ($needBootP) {
		if ($type{bootfilesystem}) {
			$bootfs = $type{bootfilesystem};
		} elsif ($bootloader eq 'syslinux') {
			$bootfs = 'fat32';
		} elsif ($bootloader eq 'yaboot') {
			if ($lvm) {
				$bootfs = 'fat16';
			} else {
				$bootfs = 'fat32';
			}
		} elsif (($firmware eq "efi") || ($firmware eq "uefi")) {
			$bootfs = 'ext3';
		} else {
			$bootfs = 'ext3';
		}
	}
	#==========================================
	# setup boot partition type
	#------------------------------------------
	if ($bootfs =~ /^fat/) {
		$partid = "c";
	}
	#==========================================
	# build disk name and label from xml data
	#------------------------------------------
	$destdir    = dirname ($initrd);
	$label      = $xml -> getImageDisplayName();
	$version    = $xml -> getImageVersion_legacy();
	$diskname   = $xml -> getImageName();
	$diskname   = $destdir."/".$diskname.".".$arch."-".$version.".raw";
	$splitfile  = $destdir."/".$label."-read-write.".$arch."-".$version;
	$partidfile = $diskname;
	$partidfile =~ s/\.raw$/\.pids/;
	$this->{bootlabel}= $label;
	#==========================================
	# build bootfix for the bootloader on oem
	#------------------------------------------
	if ($initrd =~ /oemboot/) {
		my $oemtitle = $xml -> getOEMBootTitle_legacy();
		if ($oemtitle) {
			$this->{bootlabel} = $oemtitle;
			$bootfix = "OEM";
		}
	}
	#==========================================
	# increase disk size for in-place recovery
	#------------------------------------------
	my $inplace = $xml -> getOEMRecoveryInPlace_legacy();
	if (($inplace) && ("$inplace" eq "true")) {
		my ($FD,$recoMB);
		my $sizefile = "$destdir/recovery.partition.size";
		if (open ($FD,'<',$sizefile)) {
			$recoMB = <$FD>; chomp $recoMB;	close $FD; unlink $sizefile;
			$kiwi -> info (
				"Adding $recoMB MB spare space for in-place recovery"
			);
			$this -> __updateDiskSize ($recoMB);
			$kiwi -> done ();
		}
	}
	#==========================================
	# increase vmsize if image split RW portion
	#------------------------------------------
	if (($imgtype eq "split") && (-f $splitfile)) {
		my $splitsize = KIWIGlobals -> instance() -> isize ($splitfile);
		my $splitMB = int (($splitsize * 1.2) / 1048576);
		$kiwi -> info (
			"Adding $splitMB MB space for split read-write portion"
		);
		$this -> __updateDiskSize ($splitMB);
		$kiwi -> done();
	}
	#==========================================
	# obtain filesystem type from xml data
	#------------------------------------------
	if ($type{filesystem} =~ /(.*),(.*)/) {
		$FSTypeRW = $1;
		$FSTypeRO = $2;
	} else {
		$FSTypeRW = $type{filesystem};
		$FSTypeRO = $FSTypeRW;
	}
	if ($haveSplit) {
		my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($FSTypeRW);
		if ($fsattr{readonly}) {
			$kiwi -> error ("Can't copy data into requested RO filesystem");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Setup boot partition space
	#------------------------------------------
	if ($needBootP) {
		$this ->{bootsize} = $this -> __getBootSize ();
	}
	#==========================================
	# check for jump partition
	#------------------------------------------
	if (($firmware eq "efi")  ||
		($firmware eq "uefi") ||
		($firmware eq "vboot")
	) {
		$this->{jumpsize} = 5;
		$this -> __updateDiskSize ($this->{jumpsize});
		$needJumpP = 1;
	}
	#==========================================
	# add boot space if syslinux based
	#------------------------------------------
	if ($bootfs =~ /^fat/) {
		my $fatstorage = $cmdL->getFatStorage();
		if (defined $fatstorage) {
			if ($this->{bootsize} < $fatstorage) {
				$kiwi -> info ("Fat Storage option set:\n");
				$kiwi -> info (
					"Set Fat boot partition space to: ".$fatstorage."M\n"
				);
				$this->{bootsize} = $fatstorage;
			}
		}
	}
	#==========================================
	# Update raw disk size if boot part is used
	#------------------------------------------
	if (($needBootP) && ($imgtype ne "split")) {
		$this -> __updateDiskSize ($this->{bootsize});
	}
	#==========================================
	# Check and Update to custom disk size
	#------------------------------------------
	$this -> __updateCustomDiskSize ();
	#==========================================
	# create/use disk
	#------------------------------------------
	my $dmap; # device map
	my $root; # root device
	if (! defined $system) {
		$kiwi -> error  ("No system image given");
		$kiwi -> failed ();
		return;
	}
	$kiwi -> info ("Setup disk image/device...");
	while (1) {
		if ($this->{gdata}->{StudioNode}) {
			#==========================================
			# Call custom image creation tool...
			#------------------------------------------
			$status = qxx ("$this->{gdata}->{StudioNode} $this->{vmsize} 2>&1");
			$result = $? >> 8;
			chomp $status;
			if (($result != 0) || (! -b $status)) {
				$kiwi -> failed ();
				$kiwi -> error  (
					"Failed creating Studio storage device: $status"
				);
				$kiwi -> failed ();
				return;
			}
			$haveDiskDevice = $status;
			$this->{loop} = $haveDiskDevice;
		} elsif (! $haveDiskDevice) {
			#==========================================
			# loop setup a disk device as file...
			#------------------------------------------
			$status = qxx ("qemu-img create $diskname $this->{vmsize} 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Failed creating virtual disk: $status");
				$kiwi -> failed ();
				return;
			}
			#==========================================
			# setup loop device for virtual disk
			#------------------------------------------
			if (! $this -> bindDiskDevice($diskname)) {
				return;
			}
		} else {
			#==========================================
			# Use specified disk device...
			#------------------------------------------
			$this->{loop} = $haveDiskDevice;
			if (! -b $this->{loop}) {
				$kiwi -> failed ();
				$kiwi -> error  ("No such block device: $this->{loop}");
				$kiwi -> failed ();
				return;
			}
		}
		#==========================================
		# create disk partition
		#------------------------------------------
		if (! $lvm) {
			if ($needParts == 3) {
				if ($needJumpP) {
					# xda1 jump | xda2 boot | xda3 root-ro | xda4 root-rw
					@commands = (
						"n","p","1",".","+".$this->{jumpsize}."M",
						"n","p","2",".","+".$this->{bootsize}."M",
						"n","p","3",".","+".$syszip."M",
						"n","p","4",".",".",
						"t","2",$partid,
						"t","3",$rootid,
						"a","1","w","q"
					);
					$this->{partids}{root}      = '3';
					$this->{partids}{readonly}  = '3';
					$this->{partids}{readwrite} = '4';
					$this->{partids}{boot}      = '2';
					$this->{partids}{jump}      = '1';
				} else {
					# xda1 boot | xda2 root-ro | xda3 root-rw
					@commands = (
						"n","p","1",".","+".$this->{bootsize}."M",
						"n","p","2",".","+".$syszip."M",
						"n","p","3",".",".",
						"t","1",$partid,
						"t","2",$rootid,
						"a","1","w","q"
					);
					$this->{partids}{root}      = '2';
					$this->{partids}{readonly}  = '2';
					$this->{partids}{readwrite} = '3';
					$this->{partids}{boot}      = '1';
				}
			} elsif ($needParts == 2) {
				if ($needJumpP) {
					# xda1 jump | xda2 boot | xda3 root-rw
					@commands = (
						"n","p","1",".","+".$this->{jumpsize}."M",
						"n","p","2",".","+".$this->{bootsize}."M",
						"n","p","3",".",".",
						"t","2",$partid,
						"t","3",$rootid,
						"a","1","w","q"
					);
					$this->{partids}{root} = '3';
					$this->{partids}{boot} = '2';
					$this->{partids}{jump} = '1';
				} else {
					# xda1 boot | xda2 root-rw
					@commands = (
						"n","p","1",".","+".$this->{bootsize}."M",
						"n","p","2",".",".",
						"t","1",$partid,
						"t","2",$rootid,
						"a","1","w","q"
					);
					$this->{partids}{root} = '2';
					$this->{partids}{boot} = '1';
				}
			} else {
				# xda1 root-rw
				@commands = (
					"n","p","1",".",".",
					"a","1","w","q"
				);
				$this->{partids}{boot} = '1';
				$this->{partids}{root} = '1';
			}
		} else {
			my $lvmsize = $this->{vmmbyte} - $this->{bootsize};
			my $bootpartsize = "+".$this->{bootsize}."M";
			if ($needJumpP) {
				# xda1 jump | xda2 boot | xda3 lvm
				@commands = (
					"n","p","1",".","+".$this->{jumpsize}."M",
					"n","p","2",".",$bootpartsize,
					"n","p","3",".",".",
					"t","2",$partid,
					"t","3",$rootid,
					"a","1","w","q"
				);
				if (($syszip) || ($haveSplit)) {
					$this->{partids}{root}         = '3';
					$this->{partids}{root_lv}      = 'LVComp';
					$this->{partids}{readonly_lv}  = 'LVComp';
					$this->{partids}{readwrite_lv} = 'LVRoot';
					$this->{partids}{boot}         = '2';
					$this->{partids}{jump}         = '1';
				} else {
					$this->{partids}{root}     = '3';
					$this->{partids}{root_lv}  = 'LVRoot';
					$this->{partids}{boot}     = '2';
					$this->{partids}{jump}     = '1';
				}
			} else {
				# xda1 boot | xda2 lvm
				@commands = (
					"n","p","1",".",$bootpartsize,
					"n","p","2",".",".",
					"t","1",$partid,
					"t","2",$rootid,
					"a","1","w","q"
				);
				if (($syszip) || ($haveSplit)) {
					$this->{partids}{root}         = '2';
					$this->{partids}{root_lv}      = 'LVComp';
					$this->{partids}{readonly_lv}  = 'LVComp';
					$this->{partids}{readwrite_lv} = 'LVRoot';
					$this->{partids}{boot}         = '1';
				} else {
					$this->{partids}{root}     = '2';
					$this->{partids}{root_lv}  = 'LVRoot';
					$this->{partids}{boot}     = '1';
				}
			}
		}
		if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create partition table");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		if ((! $haveDiskDevice ) || ($haveDiskDevice =~ /nbd|aoe/)) {
			#==========================================
			# setup device mapper
			#------------------------------------------
			if (! $this -> bindDiskPartitions ($this->{loop})) {
				$kiwi -> failed ();
				$this -> cleanStack ();
				return;
			}
			#==========================================
			# Create loop device mapping table
			#------------------------------------------
			%deviceMap = $this -> setLoopDeviceMap ($this->{loop});
		} else {
			#==========================================
			# Create disk device mapping table
			#------------------------------------------
			%deviceMap = $this -> setDefaultDeviceMap ($this->{loop});
		}
		#==========================================
		# setup md device if requested
		#------------------------------------------
		if ($md) {
			%deviceMap = $this -> setMD (\%deviceMap,$md);
			if (! %deviceMap) {
				$this -> cleanStack ();
				return;
			}
		}
		#==========================================
		# setup volume group if requested
		#------------------------------------------
		if ($lvm) {
			%deviceMap = $this -> setVolumeGroup (
				\%deviceMap,$this->{loop},$syszip,$haveSplit,\%lvmparts
			);
			if (! %deviceMap) {
				$this -> cleanStack ();
				return;
			}
		}
		#==========================================
		# set root device name from deviceMap
		#------------------------------------------
		$root = $deviceMap{root};
		#==========================================
		# check system partition size
		#------------------------------------------
		my $sizeOK = 1;
		my $splitPSize  = 1;
		my $splitISize  = 0;
		my $systemPSize = $this->getStorageSize ($root);
		my $systemISize = KIWIGlobals -> instance() -> isize ($system);
		$systemISize /= 1024;
		chomp $systemPSize;
		#print "_______A $systemPSize : $systemISize\n";
		if ($haveSplit) {
			$splitPSize = $this->getStorageSize ($deviceMap{readwrite});
			$splitISize = KIWIGlobals -> instance() -> isize ($splitfile);
			$splitISize /= 1024;
			chomp $splitPSize;
			#print "_______B $splitPSize : $splitISize\n";
		}
		if (($systemPSize <= $systemISize) || ($splitPSize <= $splitISize)) {
			#==========================================
			# system partition(s) still too small
			#------------------------------------------
			if ($haveDiskDevice) {
				$kiwi -> failed();
				$kiwi -> error (
					"Sorry given disk $haveDiskDevice is too small"
				);
				$kiwi -> failed();
				return;
			}
			sleep (1);
			$this -> deleteVolumeGroup();
			$this -> cleanStack();
			$this -> __updateDiskSize (10);
		} else {
			#==========================================
			# looks good go for it
			#------------------------------------------
			last;
		}
		$kiwi -> note (".");
	}
	$kiwi -> done();
	#==========================================
	# Create partition IDs meta data file
	#------------------------------------------
	$kiwi -> info ("Create partition IDs meta data...");
	if (! $this -> setupPartIDs ($partidfile)) {
		return;
	}
	$kiwi -> done();
	#==========================================
	# Setup initrd for boot
	#------------------------------------------
	$kiwi -> info ("Repack initrd with boot flags...");
	if (! $this -> setupBootFlags()) {
		return;
	}
	$kiwi -> done();
	#==========================================
	# Create Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		return;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		return;
	}
	#==========================================
	# add extra Xen boot options if necessary
	#------------------------------------------
	my $extra = "";
	#==========================================
	# Create boot loader configuration
	#------------------------------------------
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$bootfix,$extra)) {
		return;
	}
	#==========================================
	# Dump system image on disk
	#------------------------------------------
	if (! $haveTree) {
		$kiwi -> info ("Dumping system image on disk");
		$status = qxx ("dd if=$system of=$root bs=32k 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump image to disk: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		$kiwi -> done();
		$result = 0;
		my $mapper = $root;
		my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($root);
		if ($fsattr{type} eq "luks") {
			$mapper = $this -> luksResize ($root,"luks-resize");
			if (! $mapper) {
				$this -> luksClose();
				return;
			}
			%fsattr= KIWIGlobals -> instance() -> checkFileSystem ($mapper);
		}
		my $expanded = $this -> __expandFS (
			$fsattr{type},'system', $mapper
		);
		if (! $expanded ) {
			return;
		}
		if (($haveSplit) && (-f $splitfile)) {
			$kiwi -> info ("Dumping split read/write part on disk");
			$root = $deviceMap{readwrite};
			$status = qxx ("dd if=$splitfile of=$root bs=32k 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't dump split file: $status");
				$kiwi -> failed ();
				$this -> cleanStack ();
				return;
			}
			$kiwi -> done();
			$result = 0;
			$mapper = $root;
			my %fsattr = KIWIGlobals -> instance() -> checkFileSystem ($root);
			if ($fsattr{type} eq "luks") {
				$mapper = $this -> luksResize ($root,"luks-resize");
				if (! $mapper) {
					$this -> luksClose();
					return;
				}
				%fsattr = KIWIGlobals
					-> instance()
					-> checkFileSystem ($mapper);
			}
			my $expanded = $this -> __expandFS (
				$fsattr{type},'split', $mapper
			);
			if (! $expanded ) {
				return;
			}
		}
	} else {
		#==========================================
		# Create fs on system image partition
		#------------------------------------------
		if (! $this -> setupFilesystem ($FSTypeRO,$root,"root")) {
			return;
		}
		#==========================================
		# Mount system image partition
		#------------------------------------------
		if (! KIWIGlobals
			-> instance()
			-> mount ($root,$loopdir,$type{fsmountoptions})) {
			$this -> cleanStack ();
			return;
		}
		#==========================================
		# Create LVM volumes filesystems
		#------------------------------------------
		if (($lvm) && (%lvmparts)) {
			my $VGroup = $this->{lvmgroup};
			my @paths  = ();
			my %phash  = ();
			#==========================================
			# Create path names in correct order
			#------------------------------------------
			foreach my $name (keys %lvmparts) {
				my $pname  = $name; $pname =~ s/_/\//g;
				$pname =~ s/^\///;
				$pname =~ s/\s*$//;
				push @paths,$pname;
			}
			foreach my $name (@paths) {
				my @parts = split (/\//,$name);
				my $part  = @parts;
				push @{$phash{$part}},$name;
			}
			#==========================================
			# Create filesystems and Mount LVM volumes
			#------------------------------------------
			foreach my $level (sort {($a <=> $b) || ($a cmp $b)} keys %phash) {
				foreach my $pname (@{$phash{$level}}) {
					my $lname = $pname; $lname =~ s/\//_/g;
					my $device = "/dev/$VGroup/LV$lname";
					$status = qxx ("mkdir -p $loopdir/$pname 2>&1");
					$result = $? >> 8;
					if ($result != 0) {
						$kiwi -> error (
							"Can't create mount point $loopdir/$pname"
						);
						$this -> cleanStack ();
						return;
					}
					if (! $this -> setupFilesystem ($FSTypeRO,$device,$pname)) {
						$this -> cleanStack ();
						return;
					}
					$kiwi -> loginfo ("Mounting logical volume: $pname\n");
					if (! KIWIGlobals -> instance() ->
						mount ($device,"$loopdir/$pname",$type{fsmountoptions})
					) {
						$this -> cleanStack ();
						return;
					}
				}
			}
		}
		#==========================================
		# Setup filesystem specific environment
		#------------------------------------------
		if ($FSTypeRW eq 'btrfs') {
			if (! KIWIGlobals
				-> instance()
				-> setupBTRFSSubVolumes ($loopdir)) {
				$this -> cleanStack ();
				return;
			}
		}
		#==========================================
		# Copy root tree to disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on disk");
		if (-e $loopdir.'/@') {
			$status = qxx (
				'rsync -aHXA --one-file-system '.$system.'/ '.$loopdir.'/@ 2>&1'
			);
		} else {
			$status = qxx (
				"rsync -aHXA --one-file-system $system/ $loopdir 2>&1"
			);
		}
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't copy image tree to disk: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		$kiwi -> done();
		if (($haveDiskDevice) && (! $this->{gdata}->{StudioNode})) {
			#==========================================
			# fill disk device with zero bytes
			#------------------------------------------
			$kiwi -> info ("Filling target device with zero bytes...");
			qxx ("dd if=/dev/zero of=$loopdir/abc 2>&1");
			qxx ("rm -f $loopdir/abc");
			$kiwi -> done();
		}
		#==========================================
		# Umount system image partition
		#------------------------------------------
		KIWIGlobals -> instance() -> umount();
	}
	#==========================================
	# create read/write filesystem if needed
	#------------------------------------------
	if (($syszip) && (! $haveSplit) && (! $rawRW)) {
		$root = $deviceMap{root};
		if ($haveluks) {
			my $cipher = $type{luks};
			my $name   = "luksReadWrite";
			$kiwi -> info ("Creating LUKS->ext3 read-write filesystem");
			$status = qxx ("echo $cipher|cryptsetup -q luksFormat $root 2>&1");
			$result = $? >> 8;
			if ($status != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't setup luks format: $root");
				$kiwi -> failed ();
				return;
			}
			$status = qxx ("echo $cipher|cryptsetup luksOpen $root $name 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't open luks device: $status");
				$kiwi -> failed ();
				return;
			}
			$root = "/dev/mapper/$name";
			$this->{luks} = $name;
		} else {
			$kiwi -> info ("Creating ext3 read-write filesystem");
		}
		my %FSopts = KIWIGlobals -> instance() -> checkFSOptions(
			@{$cmdL -> getFilesystemOptions()}
		);
		my $fsopts = $FSopts{ext3};
		if (! $fsopts) {
			$fsopts = '';
		}
		my $fstool = "mkfs.ext3";
		$status = qxx ("$fstool $fsopts $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			$this -> luksClose();
			$this -> cleanStack ();
			return;
		}
		$this -> luksClose();
		$kiwi -> done();
	}
	#==========================================
	# create bootloader filesystem if needed
	#------------------------------------------
	if ($needBootP) {
		#==========================================
		# check for boot device node
		#------------------------------------------
		$boot = $deviceMap{boot};
		#==========================================
		# build boot filesystem
		#------------------------------------------
		if (! $this -> setupFilesystem ($bootfs,$boot,"boot","BOOT")) {
			$this -> cleanStack ();
			return;
		}
		if ($needJumpP) {
			#==========================================
			# build jump boot filesystem
			#------------------------------------------
			my $jump = $deviceMap{jump};
			if (! $this -> setupFilesystem ('fat16',$jump,"jump","EFI")) {
				$this -> cleanStack ();
				return;
			}
		}
	}
	#==========================================
	# Dump boot image on disk
	#------------------------------------------
	$kiwi -> info ("Copying boot image to disk");
	#==========================================
	# Mount boot space on this disk
	#------------------------------------------
	if ($needBootP) {
		$boot = $deviceMap{boot};
	} else {
		$boot = $root;
	}
	if (! KIWIGlobals -> instance() -> mount ($boot, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image boot device: $boot");
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	if (($firmware eq "efi") || ($firmware eq "uefi")) {
		#==========================================
		# Mount efi jump boot space on this disk
		#------------------------------------------
		my $jump = $deviceMap{jump};
		qxx ("mkdir -p $loopdir/EFI");
		if (! KIWIGlobals -> instance() -> mount ($jump, "$loopdir/EFI")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount image jump device: $boot");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
	}
	#==========================================
	# Copy boot data on system image
	#------------------------------------------
	if (! $this -> copyBootCode ($tmpdir,$loopdir,$bootloader)) {
		KIWIGlobals -> instance() -> umount();
		return;
	}
	if (($firmware eq "efi") || ($firmware eq "uefi")) {
		#==========================================
		# Adapt efi boot path on jump partition
		#------------------------------------------
		qxx ("mkdir -p $loopdir/EFI/EFI");
		qxx ("mv $loopdir/EFI/BOOT $loopdir/EFI/EFI");
	}
	#==========================================
	# umount entire boot space
	#------------------------------------------
	KIWIGlobals -> instance() -> umount();
	$kiwi -> done();
	#==========================================
	# Install boot loader on disk
	#------------------------------------------
	my $bootdevice = $diskname;
	if ($haveDiskDevice) {
		$bootdevice = $this->{loop};
	}
	if (! $this->installBootLoader ($bootloader,$bootdevice)) {
		$this -> cleanStack ();
		return;
	}
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	$this -> cleanStack();
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	if (($haveDiskDevice) && (! $this->{gdata}->{StudioNode})) {
		if (
			($type{installiso}   ne "true") && 
			($type{installstick} ne "true") &&
			($type{installpxe}   ne "true")
		) {
			#==========================================
			# create image file from disk device
			#------------------------------------------
			$kiwi -> info ("Dumping image file from $this->{loop}...");
			$status = qxx (
				"qemu-img convert -f raw -O raw $this->{loop} $diskname 2>&1"
			);
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error ("Image dump failed: $status");
				$kiwi -> failed ();
				return;
			}
			$kiwi -> done();
		}
	}
	#==========================================
	# Create image described by given format
	#------------------------------------------
	if ($initrd =~ /oemboot/) {
		#==========================================
		# OEM Install CD...
		#------------------------------------------
		if (($type{installiso}) && ($type{installiso} eq "true")) {
			$this -> {system} = $diskname;
			if ($haveDiskDevice) {
				$this -> {system} = $this->{loop};
			}
			$kiwi -> info ("--> Creating install ISO image\n");
			$this -> cleanStack ();
			if (! $this -> setupInstallCD()) {
				return;
			}
		}
		#==========================================
		# OEM Install Stick...
		#------------------------------------------
		if (($type{installstick}) && ($type{installstick} eq "true")) {
			$this -> {system} = $diskname;
			if ($haveDiskDevice) {
				$this -> {system} = $this->{loop};
			}
			$kiwi -> info ("--> Creating install USB Stick image\n");
			$this -> cleanStack ();
			if (! $this -> setupInstallStick()) {
				return;
			}
		}
		#==========================================
		# OEM Install PXE...
		#------------------------------------------
		if (($type{installpxe}) && ($type{installpxe} eq "true")) {
			$this -> {system} = $diskname;
			if ($haveDiskDevice) {
				$this -> {system} = $this->{loop};
			}
			$kiwi -> info ("--> Creating install PXE data set\n");
			$this -> cleanStack ();
			if (! $this -> setupInstallPXE()) {
				return;
			}
		}
	}
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	$this -> cleanStack ();
	return $this;
}

#==========================================
# setupInstallFlags
#------------------------------------------
sub setupInstallFlags {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $initrd = $this->{initrd};
	my $system = $this->{system};
	my $xml    = $this->{xml};
	my $zipper = $this->{gdata}->{Gzip};
	my $newird;
	my $irddir = qxx ("mktemp -qdt kiwiird.XXXXXX"); chomp $irddir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create tmp dir: $irddir: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# unpack initrd files
	#------------------------------------------
	my $unzip  = "$this->{gdata}->{Gzip} -cd $initrd 2>&1";
	my $status = qxx ("$unzip | (cd $irddir && cpio -di 2>&1)");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to extract initrd data: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return;
	}
	#==========================================
	# Include Partition ID information
	#------------------------------------------
	if (defined $system) {
		my $partidfile = $system;
		$partidfile =~ s/\.raw$/\.pids/;
		if (! -f $partidfile) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't find partid metadata: $partidfile");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return;
		}
		my $status = qxx ("cp $partidfile $irddir/config.partids 2>&1");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to copy partid metadata: $result");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return;
		}
	}
	#==========================================
	# Include MBR ID to initrd
	#------------------------------------------
	my $FD;
	qxx ("mkdir -p $irddir/boot");
	if (! open ($FD, '>', "$irddir/boot/mbrid")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create mbrid file: $!");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return;
	}
	print $FD "$this->{mbrid}";
	close $FD;
	#===========================================
	# add image.md5 / config.vmxsystem to initrd
	#-------------------------------------------
	if (defined $system) {
		my $imd5 = $system;
		$imd5 =~ s/\.raw$/\.md5/;
		my $status = qxx ("cp $imd5 $irddir/etc/image.md5 2>&1");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing md5 file: $status");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return;
		}
		my $namecd = basename ($system);
		if (! -f $imd5) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't find md5 file");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return;
		}
		my $FD;
		if (! open ($FD,'>',"$irddir/config.vmxsystem")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create image boot configuration");
			$kiwi -> failed ();
			return;
		}
		print $FD "IMAGE='".$namecd."'\n";
		close $FD;
	}
	#==========================================
	# create new initrd with vmxsystem file
	#------------------------------------------
	$newird = $initrd;
	$newird =~ s/\.gz/\.install\.gz/;
	$status = qxx (
		"(cd $irddir && find|cpio --quiet -oH newc | $zipper) > $newird"
	);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to re-create initrd: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return;
	}
	qxx ("rm -rf $irddir");
	#==========================================
	# recreate splash data to initrd
	#------------------------------------------
	my $splash = $initrd;
	if (! ($splash =~ s/splash\.gz/spl/)) {
		$splash =~ s/gz/spl/;
	}
	if (-f $splash) {
		qxx ("cat $splash >> $newird");
	}
	return $newird;
}

#==========================================
# setupBootFlags
#------------------------------------------
sub setupBootFlags {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $initrd = $this->{initrd};
	my $zipper = $this->{gdata}->{Gzip};
	my $newird;
	my $irddir = qxx ("mktemp -qdt kiwiird.XXXXXX"); chomp $irddir;
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $irddir: $!");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# resolve if link
	#------------------------------------------
	if (-l $initrd) {
		my $dirname = dirname $initrd;
		my $lnkname = readlink $initrd;
		$initrd = $dirname.'/'.$lnkname;
	}
	#==========================================
	# unpack initrd files
	#------------------------------------------
	my $unzip  = "$this->{gdata}->{Gzip} -cd $initrd 2>&1";
	my $status = qxx ("$unzip | (cd $irddir && cpio -di 2>&1)");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to extract initrd data: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return;
	}
	#==========================================
	# Include Partition ID information
	#------------------------------------------
	if (! $this -> setupPartIDs ("$irddir/config.partids")) {
		qxx ("rm -rf $irddir");
		return;
	}
	#==========================================
	# Include mdadm.conf of mdraid is active
	#------------------------------------------
	if ($this->{mddev}) {
		qxx ("mkdir -p $irddir/etc");
		$status = qxx (
			"mdadm -Db $this->{mddev} > $irddir/etc/mdadm.conf 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to extract raid configuration: $status");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return;
		}
	}
	#==========================================
	# Include MBR ID to initrd
	#------------------------------------------
	my $FD;
	qxx ("mkdir -p $irddir/boot");
	if (! open ($FD, '>', "$irddir/boot/mbrid")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create mbrid file: $!");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return;
	}
	print $FD "$this->{mbrid}";
	close $FD;
	#==========================================
	# create new initrd with mbr information
	#------------------------------------------
	$newird = $initrd;
	$newird =~ s/\.gz/\.mbrinfo\.gz/;
	$status = qxx (
		"(cd $irddir && find|cpio --quiet -oH newc | $zipper) > $newird"
	);
	$result = $? >> 8;
	if ($result == 0) {
		$status = qxx ("mv $newird $initrd 2>&1");
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to re-create initrd: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return;
	}
	qxx ("rm -rf $irddir");
	#==========================================
	# update splash.gz initrd if required
	#------------------------------------------
	my $splashird = $initrd;
	$splashird =~ s/\.gz$/\.splash.gz/;
	if (($initrd !~ /splash\.gz$/) && (-f $splashird)) {
		qxx ("cp $initrd $splashird 2>&1");
		$initrd = $splashird;
	}
	#==========================================
	# recreate splash data to initrd
	#------------------------------------------
	my $splash = $initrd;
	if (! ($splash =~ s/splash\.gz/spl/)) {
		$splash =~ s/gz/spl/;
	}
	if (-f $splash) {
		qxx ("cat $splash >> $initrd");
	}
	return $initrd;
}

#==========================================
# setupPartIDs
#------------------------------------------
sub setupPartIDs {
	# ...
	# create information about device ID for root,boot
	# readonly/readwrite partitions created for this
	# appliance. The information is read by the initrd
	# code to assign the correct partition device
	# ----
	my $this = shift;
	my $file = shift;
	my $kiwi = $this->{kiwi};
	if ($this->{partids}) {
		my $ID_FD = FileHandle -> new();
		if (! $ID_FD -> open (">$file")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create partition ID information");
			$kiwi -> failed ();
			return;
		}
		if ($this->{md}) {
			print $ID_FD "kiwi_RaidPart=\"$this->{partids}{root}\"\n";
			print $ID_FD "kiwi_RaidDev=/dev/md0\n";
		}
		if ($this->{lvm}) {
			if ($this->{partids}{root_lv}) {
				print $ID_FD "kiwi_RootPart=\"$this->{partids}{root_lv}\"\n";
			}
			if ($this->{partids}{readonly_lv}) {
				print $ID_FD "kiwi_ROPart=\"$this->{partids}{readonly_lv}\"\n";
			}
			if ($this->{partids}{readwrite_lv}) {
				print $ID_FD "kiwi_RWPart=\"$this->{partids}{readwrite_lv}\"\n";
			}
		} else {
			if ($this->{partids}{root}) {
				print $ID_FD "kiwi_RootPart=\"$this->{partids}{root}\"\n";
			}
			if ($this->{partids}{readonly}) {
				print $ID_FD "kiwi_ROPart=\"$this->{partids}{readonly}\"\n";
			}
			if ($this->{partids}{readwrite}) {
				print $ID_FD "kiwi_RWPart=\"$this->{partids}{readwrite}\"\n";
			}
		}
		if ($this->{partids}{boot}) {
			print $ID_FD "kiwi_BootPart=\"$this->{partids}{boot}\"\n";
		}
		if ($this->{partids}{jump}) {
			print $ID_FD "kiwi_JumpPart=\"$this->{partids}{jump}\"\n";
		}
		$ID_FD -> close();
	}
	return $this;
}

#==========================================
# setupSplash
#------------------------------------------
sub setupSplash {
	# ...
	# setup kernel based bootsplash
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $initrd = $this->{initrd};
	my $destdir= dirname ($initrd);
	my $isxen  = $this->{isxen};
	my $zipped = 0;
	my $status;
	my $newird;
	my $splfile;
	my $result;
	#==========================================
	# setup file names
	#------------------------------------------
	if ($initrd =~ /\.gz$/) {
		$zipped = 1;
	}
	if ($zipped) {
		$newird = $initrd; $newird =~ s/\.gz/\.splash.gz/;
		$splfile= $initrd; $splfile =~ s/\.gz/\.spl/;
	} else {
		$newird = $initrd.".splash.gz";
		$splfile= $initrd.".spl";
	}
	my $plymouth = $destdir."/plymouth.splash.active";
	#==========================================
	# check if splash initrd is already there
	#------------------------------------------
	if ((! -l $newird) && (-f $newird)) {
		# splash initrd already created...
		return $newird;
	}
	$kiwi -> info ("Setting up splash screen...\n");
	#==========================================
	# setup splash in initrd
	#------------------------------------------
	my $spllink = 0;
	if (-f $plymouth) {
		$status = "--> plymouth splash system will be used";
		qxx ("rm -f $plymouth");
		$spllink= 1;
	} elsif ($isxen) {
		$status = "--> skip splash initrd attachment for xen";
		$spllink= 1;
		qxx ("rm -f $splfile");
	} elsif (-f $splfile) {
		qxx ("cat $initrd $splfile > $newird");
		$status = "--> kernel splash system will be used";
		$spllink= 0;
	} else {
		$status = "--> Can't find splash file: $splfile";
		$spllink= 1;
	}
	$kiwi -> info ($status);
	$kiwi -> done ();
	#==========================================
	# check splash compat status
	#------------------------------------------
	if ($spllink) {
		$kiwi -> info ("Creating compat splash link...");
		$status = $this -> setupSplashLink ($newird);
		if ($status ne "ok") {
			$kiwi -> failed();
			$kiwi -> error ($status);
			$kiwi -> failed();
		} else {
			$kiwi -> done();
		}
		return $initrd;
	}
	#==========================================
	# build md5 sum for real new splash initrd
	#------------------------------------------
	my $newmd5 = $newird;
	$newmd5 =~ s/gz$/md5/;
	$this -> buildMD5Sum ($newird,$newmd5);
	return $newird;
}

#==========================================
# setupSplashLink
#------------------------------------------
sub setupSplashLink {
	# ...
	# This function only makes sure the .splash.gz
	# file exists. This is done by creating a link to the
	# original initrd file
	# ---
	my $this   = shift;
	my $newird = shift;
	my $initrd = $this->{initrd};
	my $status;
	my $result;
	if ($initrd !~ /.gz$/) {
		$status = qxx ("$this->{gdata}->{Gzip} -f $initrd 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			return ("Failed to compress initrd: $status");
		}
		$initrd = $initrd.".gz";
	}
	my $dirname = dirname  $initrd;
	my $curfile = basename $initrd;
	my $newfile = basename $newird;
	$status = qxx (
		"cd $dirname && rm -f $newfile && ln -s $curfile $newfile"
	);
	$result = $? >> 8;
	if ($result != 0) {
		return ("Failed to create splash link $!");
	}
	return "ok";
}

#==========================================
# cleanStack
#------------------------------------------
sub cleanStack {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $cStack = $this->{cleanupStack};
	my $status;
	my $result;
	if (! $cStack) {
		return;
	}
	#==========================================
	# make sure data is written
	#------------------------------------------
	qxx ("sync");
	#==========================================
	# umount from global space
	#------------------------------------------
	KIWIGlobals -> instance() -> umount();
	#==========================================
	# cleanup device bindings from this object
	#------------------------------------------
	my @cStack = @{$cStack};
	foreach my $cmd (reverse @cStack) {
		$status = qxx ("$cmd 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> warning ("cleanStack failed: $cmd: $status\n");
		}
	}
	#==========================================
	# reset cleanupStack
	#-----------------------------------------
	$this->{cleanupStack} = [];
	return;
}

#==========================================
# buildMD5Sum
#------------------------------------------
sub buildMD5Sum {
	my $this = shift;
	my $file = shift;
	my $outf = shift;
	my $kiwi = $this->{kiwi};
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = KIWIGlobals -> instance() -> isize ($file);
	my $primes = qxx ("factor $size"); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 8192);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qxx ("cat $file | md5sum - | cut -f 1 -d-");
	chomp $sum;
	if ($outf) {
		$file = $outf;
	}
	if ($file =~ /\.raw$/) {
		$file =~ s/raw$/md5/;
	}
	qxx ("echo \"$sum $blocks $blocksize\" > $file");
	$kiwi -> done();
	return $this;
}

#==========================================
# writeMBRDiskLabel
#------------------------------------------
sub writeMBRDiskLabel {
	# ...
	# writes a 4byte random ID into the MBR of the
	# previosly installed boot manager. The function
	# returns the written ID or undef on error
	# ---
	my $this  = shift;
	my $file  = shift;
	my $kiwi  = $this->{kiwi};
	my $nid   = $this->{mbrid};
	if (! defined $nid) {
		$kiwi -> failed ();
		$kiwi -> error  ("MBR: don't have a mbr id");
		$kiwi -> failed ();
		return;
	}
	my $pid = pack "V", eval $nid; ## no critic
	my $FD = FileHandle -> new();
	if (! $FD -> open("+<$file")) {
		$kiwi -> failed ();
		$kiwi -> error  ("MBR: failed to open file: $file: $!");
		$kiwi -> failed ();
		return;
	}
	seek $FD,440,0;
	my $done = syswrite ($FD,$pid,4);
	if ((! $done) || ($done != 4)) {
		$kiwi -> failed ();
		if ($done) {
			$kiwi -> error  ("MBR: only $done bytes written");
		} else {
			$kiwi -> error  ("MBR: syswrite to $file failed: $!");
		}
		$kiwi -> failed ();
		seek $FD,0,2;
		$FD -> close();
		return;
	}
	seek $FD,0,2;
	$FD -> close();
	return $this;
}

#==========================================
# setupBootLoaderStages
#------------------------------------------
sub setupBootLoaderStages {
	my $this     = shift;
	my $loader   = shift;
	my $type     = shift;
	my $kiwi     = $this->{kiwi};
	my $tmpdir   = $this->{tmpdir};
	my $initrd   = $this->{initrd};
	my $zipped   = $this->{zipped};
	my $zipper   = $this->{gdata}->{Gzip};
	my $firmware = $this->{firmware};
	my $arch     = $this->{arch};
	my $status   = 0;
	my $result   = 0;
	#==========================================
	# Grub2
	#------------------------------------------
	if ($loader eq "grub2") {
		my $efipc    = 'x86_64-efi';
		my $grubpc   = 'i386-pc';
		my $figure   = "'usr/share/grub2/themes/*'";
		my $bootbios = "$tmpdir/boot/grub2/bootpart.cfg";
		my $bootefi  = "$tmpdir/boot/grub2-efi/bootpart.cfg";
		my $unzip    = "$zipper -cd $initrd 2>&1";
		my %stages   = ();
		my $test     = "cat $initrd";
		my $grub     = 'grub2-efi';
		my $lib      = 'lib';
		if ($zipped) {
			$test = $unzip;
		}
		$status = qxx ("$test | cpio -it --quiet | grep -q lib/grub2-efi 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$grub = 'grub2';
		}
		$status = qxx ("$test | cpio -it --quiet | grep -q lib64/efi 2>&1");
		$result = $? >> 8;
		if ($result == 0) {
			$lib = 'lib64';
		}
		#==========================================
		# boot id in grub2 context
		#------------------------------------------
		my $boot_id = 1;
		if ($this->{partids}) {
			$boot_id = $this->{partids}{boot};
		}
		#==========================================
		# Stage files
		#------------------------------------------
		$stages{bios}{initrd}   = "'usr/lib/$grub/$grubpc/*'";
		$stages{bios}{stageSRC} = "/usr/lib/$grub/$grubpc";
		$stages{bios}{stageDST} = "/boot/grub2/$grubpc";
		if (($firmware eq "efi") || ($firmware eq "uefi")) {
			$stages{efi}{initrd}   = "'usr/lib/$grub/$efipc/*'";
			$stages{efi}{stageSRC} = "/usr/lib/$grub/$efipc";
			$stages{efi}{stageDST} = "/boot/grub2-efi/$efipc";
		}
		if ($firmware eq "uefi") {
			$stages{efi}{data}      = "'usr/$lib/efi/*'";
			$stages{efi}{shim_ms}   = "usr/$lib/efi/shim.efi";
			$stages{efi}{shim_suse} = "usr/$lib/efi/shim-opensuse.efi";
			$stages{efi}{signed}    = "usr/$lib/efi/grub.efi";
		}
		#==========================================
		# Module lists for self created grub images
		#------------------------------------------
		my @bios_core_modules = (
			'biosdisk','part_msdos','part_gpt','ext2',
			'iso9660','chain','normal','linux','echo',
			'vga','vbe','png','video_bochs','video_cirrus',
			'gzio','multiboot','search','configfile','fat'
		);
		my @efi_core_modules = (
			'fat','ext2','part_gpt','efi_gop','iso9660','chain',
			'linux','echo','configfile','boot','search_label',
			'search_fs_file','search','search_fs_uuid','ls',
			'video','video_fb','normal'
		);
		#==========================================
		# Boot directories
		#------------------------------------------
		my @bootdir = ();
		if (($firmware eq "efi") || ($firmware eq "uefi")) {
			push @bootdir,"$tmpdir/boot/grub2-efi/$efipc";
			push @bootdir,"$tmpdir/boot/grub2/$efipc";
			push @bootdir,"$tmpdir/EFI/BOOT";
		} else {
			push @bootdir,"$tmpdir/boot/grub2/$grubpc";
		}
		$status = qxx ("mkdir -p @bootdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating boot manager directory: $status");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Create boot partition file
		#------------------------------------------
		$kiwi -> info ("Creating grub2 boot partition map");
		foreach my $bootfile ($bootbios,$bootefi) {
			next if (($bootfile eq $bootbios) && ($firmware =~ /efi/));
			next if (($bootfile eq $bootefi)  && ($firmware eq 'bios'));
			my $bpfd = FileHandle -> new();
			if (! $bpfd -> open(">$bootfile")) {
				$kiwi -> failed ();
				$kiwi -> error ("Couldn't create grub2 bootpart map: $!");
				$kiwi -> failed ();
				return;
			}
			print $bpfd "search -f /boot/$this->{mbrid} --set"."\n";
			if ($bootfile =~ /grub2-efi/) {
				print $bpfd 'set prefix=($root)/boot/grub2-efi'."\n";
			} else {
				print $bpfd 'set prefix=($root)/boot/grub2'."\n";
			}
			$bpfd -> close();
		}
		$kiwi -> done();
		#==========================================
		# Get Grub2 stage and theming files
		#------------------------------------------
		$kiwi -> info ("Importing grub2 stage and theming files");
		my $s_efi = $stages{efi}{initrd};
		my $s_bio = $stages{bios}{initrd};
		if (! $s_efi) {
			$s_efi = "";
		}
		if (! $s_bio) {
			$s_bio = "";
		}
		if ($zipped) {
			$status= qxx (
				"$unzip | \\
				(cd $tmpdir && cpio -i -d $figure -d $s_bio -d $s_efi 2>&1)"
			);
		} else {
			$status= qxx (
				"cat $initrd | \\
				(cd $tmpdir && cpio -i -d $figure -d $s_bio -d $s_efi 2>&1)"
			);
		}
		#==========================================
		# import Grub2 theme files...
		#------------------------------------------
		if (-d "$tmpdir/usr/share/grub2/themes") {
			$status = qxx (
				"mv $tmpdir/usr/share/grub2/themes $tmpdir/boot/grub2 2>&1"
			);
		}
		#==========================================
		# import Grub2 stage files...
		#------------------------------------------
		foreach my $stage ('bios','efi') {
			next if (($stage eq "bios") && ($firmware =~ /efi/));
			next if (($stage eq "efi")  && ($firmware eq 'bios'));
			my $stageD = $stages{$stage}{stageSRC};
			my $stageT = $stages{$stage}{stageDST};
			if (glob($tmpdir.$stageD.'/*')) {
				$status = qxx (
					'cp '.$tmpdir.$stageD.'/* '.$tmpdir.$stageT.' 2>&1'
				);
			} else {
				$kiwi -> skipped ();
				$kiwi -> warning ("No grub2 stage files found in boot image");
				$kiwi -> skipped ();
				$kiwi -> info (
					"Trying to use grub2 stages from local machine"
				);
				$status = qxx (
					'cp '.$stageD.'/* '.$tmpdir.$stageT.' 2>&1'
				);
			}
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Failed importing grub2 stages: $status");
				$kiwi -> failed ();
				return;
			}
		}
		$kiwi -> done();
		#==========================================
		# Lookup grub2 mkimage tool
		#------------------------------------------
		my $locator = KIWILocator -> instance();
		my $grub2_mkimage = $locator -> getExecPath ("grub2-mkimage");
		if ($firmware =~ /efi/) {
			my $grub2_efi_mkimage = $locator -> getExecPath (
				"grub2-efi-mkimage"
			);
			if ($grub2_efi_mkimage) {
				$grub2_mkimage = $grub2_efi_mkimage;
			}
		}
		if (! $grub2_mkimage) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't find grub2 mkimage tool");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Create core efi boot image, standard EFI
		#------------------------------------------
		if ($firmware eq "efi") {
			$kiwi -> info ("Creating grub2 efi boot image");
			my $core    = "$tmpdir/EFI/BOOT/bootx64.efi";
			my @modules = (
				'fat','ext2','part_gpt','efi_gop','iso9660','chain',
				'linux','echo','configfile','boot','search_label',
				'search_fs_file','search','search_fs_uuid','ls',
				'video','video_fb','normal'
			);
			my $fo = 'x86_64-efi';
			if ($arch ne 'x86_64') {
				$fo = 'i386-efi';
			}
			$status = qxx (
				"$grub2_mkimage -O $fo -o $core -c $bootefi @modules 2>&1"
			);
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create efi boot image: $status");
				$kiwi -> failed ();
				return;
			}
			$kiwi -> done();
		}
		#==========================================
		# Use signed EFI modules from packages UEFI
		#------------------------------------------
		if ($firmware eq "uefi") {
			$kiwi -> info ("Importing grub2 shim/signed efi modules");
			my $s_data      = $stages{efi}{data};
			my $s_shim_ms   = $stages{efi}{shim_ms};
			my $s_shim_suse = $stages{efi}{shim_suse};
			my $s_signed    = $stages{efi}{signed};
			$result = 0;
			if ($zipped) {
				$status= qxx (
					"$unzip | (cd $tmpdir && cpio -i -d $s_data 2>&1)"
				);
			} else {
				$status= qxx (
					"cat $initrd | (cd $tmpdir && cpio -i -d $s_data 2>&1)"
				);
			}
			if ((! -e "$tmpdir/$s_shim_ms") && (! -e "$tmpdir/$s_shim_suse")) {
				my $s_shim = "$tmpdir/$s_shim_ms";
				if (-e $s_shim) {
					$s_shim = "$tmpdir/$s_shim_suse"
				}
				$kiwi -> failed ();
				$kiwi -> error  (
					"Can't find shim $s_shim in initrd");
				$kiwi -> failed ();
				return;
			}
			if (! -e "$tmpdir/$s_signed") {
				$kiwi -> failed ();
				$kiwi -> error  (
					"Can't find grub2 $s_signed in initrd");
				$kiwi -> failed ();
				return;
			}
			$status = qxx (
				"cp $tmpdir/$s_shim_ms $tmpdir/EFI/BOOT/bootx64.efi 2>&1"
			);
			$result = $? >> 8;
			if ($result != 0) {
				$status = qxx (
					"cp $tmpdir/$s_shim_suse $tmpdir/EFI/BOOT/bootx64.efi 2>&1"
				);
				$result = $? >> 8;
			}
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error ("Failed to copy shim module: $status");
				$kiwi -> failed ();
				return;
			}
			$status = qxx (
				"cp $tmpdir/$s_signed $tmpdir/EFI/BOOT/grub.efi 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error ("Failed to copy signed module: $status");
				$kiwi -> failed ();
				return;
			}
			$kiwi -> done();
		}
		#==========================================
		# Create core grub2 boot images
		#------------------------------------------
		if ($firmware eq 'bios') {
			$kiwi -> info ("Creating grub2 core boot image");
			my $format   = $grubpc;
			my $bootconf = $bootbios;
			my @modules  = @bios_core_modules;
			my $core     = "$tmpdir/boot/grub2/$format/core.img";
			my $cdimg    = "$tmpdir/boot/grub2/$format/eltorito.img";
			my $cdcore   = "$tmpdir/boot/grub2/$format/cdboot.img";
			my $status = qxx (
				"$grub2_mkimage -O $format -o $core -c $bootconf @modules 2>&1"
			);
			my $result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create core boot image: $status");
				$kiwi -> failed ();
				return;
			}
			$kiwi -> done();
			#==========================================
			# Create eltorito grub2 boot image
			#------------------------------------------
			if ((defined $type) && ($type eq "iso")) {
				$kiwi -> info ("Creating grub2 eltorito boot image");
				$status = qxx ("cat $cdcore $core > $cdimg");
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("Couldn't create eltorito image: $status");
					$kiwi -> failed ();
					return;
				}
				$kiwi -> done();
			}
		}
	}
	#==========================================
	# Grub
	#------------------------------------------
	if ($loader eq "grub") {
		my $stages = "'usr/lib/grub/*'";
		my $figure = "'image/loader/message'";
		my $unzip  = "$zipper -cd $initrd 2>&1";
		$status = qxx ( "mkdir -p $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating boot manager directory: $status");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Get Grub graphics boot message
		#------------------------------------------
		$kiwi -> info ("Importing graphics boot message and stage files");
		if ($zipped) {
			$status= qxx (
				"$unzip | (cd $tmpdir && cpio -i -d $figure -d $stages 2>&1)"
			);
		} else {
			$status= qxx (
				"cat $initrd|(cd $tmpdir && cpio -i -d $figure -d $stages 2>&1)"
			);
		}
		if (-e $tmpdir."/image/loader/message") {
			$status = qxx ("mv $tmpdir/$figure $tmpdir/boot/message 2>&1");
			$result = $? >> 8;
			$kiwi -> done();
		} else {
			$kiwi -> skipped();
		}
		#==========================================
		# check Grub stage files...
		#------------------------------------------
		if (glob($tmpdir."/usr/lib/grub/*")) {
			$status = qxx (
				"mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1"
			);
			$result = $? >> 8;
			if (($result == 0) && (defined $type) && ($type eq "iso")) {
				my $src = "$tmpdir/boot/grub/stage2_eltorito";
				my $dst = "$tmpdir/boot/grub/stage2";
				$status = qxx ("mv $src $dst 2>&1");
				$result = $? >> 8;
			}
		} else {
			$kiwi -> warning ("No grub stage files found in boot image");
			$kiwi -> skipped ();
			$kiwi -> info    ("Trying to use grub stages from local machine");
			$status = qxx ( "cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1" );
			$result = $? >> 8;
			if (($result == 0) && (defined $type) && ($type eq "iso")) {
				my $src = "$tmpdir/boot/grub/stage2_eltorito";
				my $dst = "$tmpdir/boot/grub/stage2";
				$status = qxx ("mv $src $dst 2>&1");
				$result = $? >> 8;
			}
			if ($result != 0) {
				$kiwi -> error  ("Failed importing grub stages: $status");
				$kiwi -> failed ();
				return;
			}
		}
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader =~ /(sys|ext)linux/) {
		my $message= "'image/loader/*'";
		my $unzip  = "$zipper -cd $initrd 2>&1";
		#==========================================
		# Create syslinux boot data directory
		#------------------------------------------
		qxx ("mkdir -p $tmpdir/boot/syslinux 2>&1");
		#==========================================
		# Get syslinux graphics data
		#------------------------------------------
		$kiwi -> info ("Importing graphics boot message");
		if ($zipped) {
			$status= qxx ("$unzip | (cd $tmpdir && cpio -di $message 2>&1)");
		} else {
			$status= qxx ("cat $initrd|(cd $tmpdir && cpio -di $message 2>&1)");
		}
		if (-d $tmpdir."/image/loader") {
			$status = qxx (
				"mv $tmpdir/image/loader/* $tmpdir/boot/syslinux 2>&1"
			);
			$result = $? >> 8;
			$kiwi -> done();
		} else {
			$kiwi -> skipped();
		}
		#==========================================
		# Cleanup tmpdir
		#------------------------------------------
		qxx ("rm -rf $tmpdir/image 2>&1");
	}
	#==========================================
	# yaboot
	#------------------------------------------
	if ($loader eq "yaboot") {
		my $chrp  = "'lib/lilo/chrp/yaboot.chrp'";
		my $unzip = "$zipper -cd $initrd 2>&1";
		#==========================================
		# Create yaboot boot data directory
		#------------------------------------------
		qxx ("mkdir -p $tmpdir/boot 2>&1");
		#==========================================
		# Get lilo chrp data
		#------------------------------------------
		$kiwi -> info ("Importing yaboot.chrp file");
		if ($zipped) {
			$status= qxx ("$unzip | (cd $tmpdir && cpio -di $chrp 2>&1)");
		} else {
			$status= qxx ("cat $initrd|(cd $tmpdir && cpio -di $chrp 2>&1)");
		}
		if (-e $tmpdir."/lib/lilo/chrp/yaboot.chrp") {
			qxx ("mv $tmpdir/lib/lilo/chrp/yaboot.chrp $tmpdir/boot/yaboot");
		} else {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to import yaboot.chrp file: $status");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# uboot stages
	#------------------------------------------
	if ($loader eq "uboot") {
		my $loaders= "'image/loader/*'";
		my $unzip  = "$zipper -cd $initrd 2>&1";
		#==========================================
		# Create uboot boot data directory
		#------------------------------------------
		qxx ("mkdir -p $tmpdir/boot 2>&1");
		#==========================================
		# Get uboot/MLO loaders
		#------------------------------------------
		$kiwi -> info ("Importing uboot loaders");
		if ($zipped) {
			$status= qxx ("$unzip | (cd $tmpdir && cpio -di $loaders 2>&1)");
		} else {
			$status= qxx ("cat $initrd|(cd $tmpdir && cpio -di $loaders 2>&1)");
		}
		if (-d $tmpdir."/image/loader") {
			$status = qxx (
				"mv $tmpdir/image/loader/* $tmpdir/boot 2>&1"
			);
			$result = $? >> 8;
			$kiwi -> done();
		} else {
			$kiwi -> skipped();
		}
		#==========================================
		# Cleanup tmpdir
		#------------------------------------------
		qxx ("rm -rf $tmpdir/image 2>&1");
	}
	#==========================================
	# more boot managers to come...
	#------------------------------------------
	return $this;
}

#==========================================
# setupBootLoaderConfiguration
#------------------------------------------
sub setupBootLoaderConfiguration {
	my $this     = shift;
	my $loader   = shift;
	my $type     = shift;
	my $extra    = shift;
	my $iso      = shift;
	my $cmdL     = $this->{cmdL};
	my $system   = $this->{system};
	my $kiwi     = $this->{kiwi};
	my $tmpdir   = $this->{tmpdir};
	my $initrd   = $this->{initrd};
	my $isxen    = $this->{isxen};
	my $xendomain= $this->{xendomain};
	my $imgtype  = $this->{imgtype};
	my $label    = $this->{bootlabel};
	my $vga      = $this->{vga};
	my $lvm      = $this->{lvm};
	my $vgroup   = $this->{lvmgroup};
	my $xml      = $this->{xml};
	my $firmware = $this->{firmware};
	my $bloader  = "grub";
	my $failsafe = 1;
	my $cmdline;
	my %type;
	my $title;
	#==========================================
	# set empty label if not defined
	#------------------------------------------
	if (! $label) {
		$label = "";
	}
	#==========================================
	# Failsafe boot options
	#------------------------------------------
	my @failsafe = (
		'ide=nodma',
		'apm=off',
		'noresume',
		'edd=off',
		'powersaved=off',
		'nohz=off',
		'highres=off',
		'processsor.max+cstate=1',
		'nomodeseet',
		'x11failsafe'
	);
	#==========================================
	# store loader type in object instance
	#------------------------------------------
	$this->{loader} = $loader;
	#==========================================
	# setup boot loader default boot label/nr
	#------------------------------------------
	my $defaultBootNr = 0;
	if ($xml) {
		%type = %{$xml->getImageTypeAndAttributes_legacy()};
		$cmdline  = $type{cmdline};
	}
	if ($type =~ /^KIWI (CD|USB) Boot/) {
		# /.../
		# use predefined set of parameters for simple boot CD
		# not including a system image
		# ----
		$type{installboot} = "install";
		$type{boottimeout} = 1;
		$type{fastboot}    = 1;
		$cmdline="kiwistderr=/dev/hvc0";
		$vga="normal";
	}
	if ($type =~ /^KIWI (CD|USB)/) {
		# In install mode we have the following menu layout
		# ----
		# 0 -> Boot from Hard Disk
		# 1 -> Install $label
		# 2 -> [ Failsafe -- Install $label ]
		# ----
		if ($type{installboot}) {
			if ($type{installboot} eq "install") {
				$defaultBootNr = 1;
			}
			if ($type{installboot} eq "failsafe-install") {
				$defaultBootNr = 2;
			}
		}
		if (($type{installprovidefailsafe}) &&
			($type{installprovidefailsafe} eq "false")
		) {
			$failsafe = 0;
			if ($defaultBootNr == 2) {
				$defaultBootNr = 1;
			}
		}
	}
	#==========================================
	# setup boot loader type
	#------------------------------------------
	if ($type{bootloader}) {
		$bloader = $type{bootloader};
	}
	#==========================================
	# report additional cmdline options
	#------------------------------------------
	if ($cmdline) {
		$kiwi -> loginfo (
			"Additional commandline options: \"$cmdline\""
		);
	}
	#==========================================
	# join common options, finish with '\n'
	#------------------------------------------
	$cmdline .= " $extra" if $extra;
	$cmdline .= " VGROUP=$vgroup" if $lvm;
	$cmdline .= " COMBINED_IMAGE=yes" if $imgtype eq "split";
	$cmdline .= " showopts\n";
	# ensure exactly one space at start
	$cmdline =~ s/^\s*/ /;
	#==========================================
	# Create MBR id file for boot device check
	#------------------------------------------
	$kiwi -> info ("Saving disk label boot/mbrid: $this->{mbrid}...");
	qxx ("mkdir -p $tmpdir/boot");
	my $FD;
	if (! open ($FD,'>',"$tmpdir/boot/mbrid")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create mbrid file: $!");
		$kiwi -> failed ();
		return;
	}
	print $FD "$this->{mbrid}";
	close $FD;
	$kiwi -> done();
	#==========================================
	# Grub2
	#------------------------------------------
	if ($loader eq "grub2") {
		#==========================================
		# root/boot id's in grub2 context
		#------------------------------------------
		my $boot_id = 1;
		my $root_id = 1;
		if ($this->{partids}) {
			$boot_id = $this->{partids}{boot};
			$root_id = $this->{partids}{root};
		}
		#==========================================
		# kernel loader command
		#------------------------------------------
		my $efi_suffix = '';
		if ($firmware eq "uefi") {
			$efi_suffix = 'efi';
		}
		#==========================================
		# Theme and Fonts table
		#------------------------------------------
		my @theme = $xml -> getBootTheme_legacy();
		my $theme = $theme[1];
		my $ascii = 'ascii.pf2';
		my $fodir = '/boot/grub2/themes/';
		my @fonts = (
			"DejaVuSans-Bold14.pf2",
			"DejaVuSans10.pf2",
			"DejaVuSans12.pf2",
			"ascii.pf2"
		);
		#==========================================
		# BIOS modules
		#------------------------------------------
		my @x86mods = (
			'fat','ext2','gettext','part_msdos','chain',
			'vbe','vga','video_bochs','video_cirrus','gzio',
			'search','configfile','png'
		);
		#==========================================
		# EFI modules
		#------------------------------------------
		my @efimods = (
			'fat','ext2','gettext','part_gpt','efi_gop',
			'chain','video','video_bochs','video_cirrus',
			'gzio','efi_uga','search','configfile','png'
		);
		#==========================================
		# config file name
		#------------------------------------------
		my @config = ('grub2');
		if (($firmware eq "efi") || ($firmware eq "uefi")) {
			push @config,'grub2-efi';
		}
		#==========================================
		# gfxpayload mapping table
		#------------------------------------------
		my %vesa;
		$vesa{'0x301'} = ["640x480x8"   , "640x480"  ];
		$vesa{'0x310'} = ["640x480x16"  , "640x480"  ];
		$vesa{'0x311'} = ["640x480x24"  , "640x480"  ];
		$vesa{'0x312'} = ["640x480x32"  , "640x480"  ];
		$vesa{'0x303'} = ["800x600x8"   , "800x600"  ];
		$vesa{'0x313'} = ["800x600x16"  , "800x600"  ];
		$vesa{'0x314'} = ["800x600x24"  , "800x600"  ];
		$vesa{'0x315'} = ["800x600x32"  , "800x600"  ];
		$vesa{'0x305'} = ["1024x768x8"  , "1024x768" ];
		$vesa{'0x316'} = ["1024x768x16" , "1024x768" ];
		$vesa{'0x317'} = ["1024x768x24" , "1024x768" ];
		$vesa{'0x318'} = ["1024x768x32" , "1024x768" ];
		$vesa{'0x307'} = ["1280x1024x8" , "1280x1024"];
		$vesa{'0x319'} = ["1280x1024x16", "1280x1024"];
		$vesa{'0x31a'} = ["1280x1024x24", "1280x1024"];
		$vesa{'0x31b'} = ["1280x1024x32", "1280x1024"];
		#==========================================
		# add unicode font for grub2
		#------------------------------------------
		my $font = "/usr/share/grub2/unicode.pf2";
		if (-e $font) {
			qxx ("cp $font $tmpdir/boot");
		} else {
			$kiwi -> warning ("Can't find unicode font for grub2");
			$kiwi -> skipped ();
		}
		#==========================================
		# Create grub.cfg file
		#------------------------------------------
		$kiwi -> info ("Creating grub2 configuration file...");
		foreach my $config (@config) {
			qxx ("mkdir -p $tmpdir/boot/$config");
			my $FD = FileHandle -> new();
			if (! $FD -> open(">$tmpdir/boot/$config/grub.cfg")) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create $config/grub.cfg: $!");
				$kiwi -> failed ();
				return;
			}
			#==========================================
			# General grub2 setup
			#------------------------------------------
			if ($config eq "grub2") {
				foreach my $module (@x86mods) {
					print $FD "insmod $module"."\n";
				}
			} else {
				foreach my $module (@efimods) {
					print $FD "insmod $module"."\n";
				}
			}
			print $FD "search -f /boot/$this->{mbrid} --set"."\n";
			print $FD "set default=$defaultBootNr\n";
			print $FD "set font=/boot/unicode.pf2"."\n";
			print $FD 'if loadfont $font ;then'."\n";
			print $FD "\t"."set gfxmode=$vesa{$vga}->[0]"."\n";
			print $FD "\t".'insmod gfxterm'."\n";
			print $FD "\t".'insmod gfxmenu'."\n";
			print $FD "\t".'terminal_input gfxterm'."\n";
			print $FD "\t".'if terminal_output gfxterm; then true; else'."\n";
			print $FD "\t\t".'terminal gfxterm'."\n";
			print $FD "\t".'fi'."\n";
			print $FD 'fi'."\n";
			print $FD 'if loadfont '.$fodir.$theme.'/'.$ascii.';then'."\n";
			foreach my $font (@fonts) {
				print $FD "\t".'loadfont '.$fodir.$theme.'/'.$font."\n";
			}
			print $FD "\t".'set theme='.$fodir.$theme.'/theme.txt'."\n";
			print $FD "\t".'background_image -m stretch ';
			print $FD $fodir.$theme.'/background.png'."\n";
			print $FD 'fi'."\n";
			my $bootTimeout = 10;
			if (defined $type{boottimeout}) {
				$bootTimeout = $type{boottimeout};
			}
			if ($type{fastboot}) {
				$bootTimeout = 0;
			}
			print $FD "set timeout=$bootTimeout\n";
			if ($type =~ /^KIWI (CD|USB)/) {
				my $dev = $1 eq 'CD' ? '(cd)' : '(hd0,0)';
				print $FD 'menuentry "Boot from Hard Disk"';
				print $FD ' --class opensuse --class os {'."\n";
				if (($firmware eq "efi") || ($firmware eq "uefi")) {
					print $FD "\t"."set root='hd0,1'"."\n";
					print $FD "\t".'chainloader /EFI/BOOT/bootx64.efi'."\n";
				} else {
					print $FD "\t"."set root='hd0'"."\n";
					if ($dev eq '(cd)') {
						print $FD "\t".'chainloader +1'."\n";
					} else {
						print $FD "\t".'chainloader /boot/grub2/bootnext'."\n";
						my $bootnext = $this -> addBootNext (
							"$tmpdir/boot/grub2/bootnext", hex $this->{mbrid}
						);
						if (! defined $bootnext) {
							$kiwi -> failed ();
							$kiwi -> error  ("Failed to write bootnext\n");
							$kiwi -> failed ();
							$FD -> close();
							return;
						}
					}
					print $FD "\t".'boot'."\n";
				}
				print $FD '}'."\n";
				$title = $this -> quoteLabel ("Install $label");
			} else {
				$title = $this -> quoteLabel ("$label [ $type ]");
			}
			print $FD 'menuentry "'.$title.'"';
			print $FD ' --class opensuse --class os {'."\n";
			#==========================================
			# Standard boot
			#------------------------------------------
			if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
				if ($iso) {
					print $FD "\t"."echo Loading linux...\n";
					print $FD "\t"."set gfxpayload=keep"."\n";
					print $FD "\t"."linux$efi_suffix /boot/linux";
					print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
					print $FD " cdinst=1 loader=$bloader splash=silent";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD "\t"."echo Loading linux.vmx...\n";
					print $FD "\t"."set gfxpayload=keep"."\n";
					print $FD "\t"."linux$efi_suffix /boot/linux.vmx";
					print $FD " loader=$bloader splash=silent";
				} else {
					print $FD "\t"."echo Loading linux...\n";
					print $FD "\t"."set gfxpayload=keep"."\n";
					print $FD "\t"."linux$efi_suffix /boot/linux";
					print $FD " loader=$bloader splash=silent";
				}
				print $FD $cmdline;
				if ($iso) {
					print $FD "\t"."echo Loading initrd...\n";
					print $FD "\t"."initrd$efi_suffix /boot/initrd\n";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD "\t"."echo Loading initrd.vmx...\n";
					print $FD "\t"."initrd$efi_suffix /boot/initrd.vmx\n";
				} else {
					print $FD "\t"."echo Loading initrd...\n";
					print $FD "\t"."initrd$efi_suffix /boot/initrd\n";
				}
				print $FD "}\n";
			} else {
				if ($iso) {
					print $FD "\t"."echo Loading Xen\n";
					print $FD "\t"."multiboot /boot/xen.gz dummy\n";
					print $FD "\t"."echo Loading linux...\n";
					print $FD "\t"."set gfxpayload=keep"."\n";
					print $FD "\t"."module /boot/linux dummy";
					print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
					print $FD " cdinst=1 loader=$bloader splash=silent";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD "\t"."echo Loading Xen\n";
					print $FD "\t"."multiboot /boot/xen.gz dummy\n";
					print $FD "\t"."echo Loading linux.vmx...\n";
					print $FD "\t"."set gfxpayload=keep"."\n";
					print $FD "\t".'module /boot/linux.vmx dummy';
					print $FD " loader=$bloader splash=silent";
				} else {
					print $FD "\t"."echo Loading Xen\n";
					print $FD "\t"."multiboot /boot/xen.gz dummy\n";
					print $FD "\t"."echo Loading linux...\n";
					print $FD "\t"."set gfxpayload=keep"."\n";
					print $FD "\t".'module /boot/linux dummy';
					print $FD " loader=$bloader splash=silent";
				}
				print $FD $cmdline;
				if ($iso) {
					print $FD "\t"."echo Loading initrd...\n";
					print $FD "\t"."module /boot/initrd dummy\n";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD "\t"."echo Loading initrd.vmx...\n";
					print $FD "\t"."module /boot/initrd.vmx dummy\n";
				} else {
					print $FD "\t"."echo Loading initrd...\n";
					print $FD "\t"."module /boot/initrd dummy\n";
				}
				print $FD "}\n";
			}
			#==========================================
			# Failsafe boot
			#------------------------------------------
			if ($failsafe) {
				$title = $this -> quoteLabel ("Failsafe -- $title");
				print $FD 'menuentry "'.$title.'"';
				print $FD ' --class opensuse --class os {'."\n";
				if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
					if ($iso) {
						print $FD "\t"."echo Loading linux...\n";
						print $FD "\t"."set gfxpayload=keep"."\n";
						print $FD "\t"."linux$efi_suffix /boot/linux";
						print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
						print $FD " cdinst=1 loader=$bloader splash=silent";
					} elsif (
						($type=~ /^KIWI USB/) ||
						($imgtype=~ /vmx|oem|split/)
					) {
						print $FD "\t"."echo Loading linux.vmx...\n";
						print $FD "\t"."set gfxpayload=keep"."\n";
						print $FD "\t"."linux$efi_suffix /boot/linux.vmx";
						print $FD " loader=$bloader splash=silent";
					} else {
						print $FD "\t"."echo Loading linux...\n";
						print $FD "\t"."set gfxpayload=keep"."\n";
						print $FD "\t"."linux$efi_suffix /boot/linux";
						print $FD " loader=$bloader splash=silent";
					}
					print $FD " @failsafe";
					print $FD $cmdline;
					if ($iso) {
						print $FD "\t"."echo Loading initrd...\n";
						print $FD "\t"."initrd$efi_suffix /boot/initrd\n";
					} elsif (
						($type=~ /^KIWI USB/) ||
						($imgtype=~ /vmx|oem|split/)
					) {
						print $FD "\t"."echo Loading initrd.vmx...\n";
						print $FD "\t"."initrd$efi_suffix /boot/initrd.vmx\n";
					} else {
						print $FD "\t"."echo Loading initrd...\n";
						print $FD "\t"."initrd$efi_suffix /boot/initrd\n";
					}
					print $FD "}\n";
				} else {
					if ($iso) {
						print $FD "\t"."echo Loading Xen\n";
						print $FD "\t"."multiboot /boot/xen.gz dummy\n";
						print $FD "\t"."echo Loading linux...\n";
						print $FD "\t"."set gfxpayload=keep"."\n";
						print $FD "\t"."module /boot/linux dummy";
						print $FD ' ramdisk_size=512000 ramdisk_blocksize=4096';
						print $FD " cdinst=1 loader=$bloader splash=silent";
					} elsif (
						($type=~ /^KIWI USB/) || 
						($imgtype=~ /vmx|oem|split/)
					) {
						print $FD "\t"."echo Loading Xen\n";
						print $FD "\t"."multiboot /boot/xen.gz dummy\n";
						print $FD "\t"."echo Loading linux.vmx...\n";
						print $FD "\t"."set gfxpayload=keep"."\n";
						print $FD "\t".'module /boot/linux.vmx dummy';
						print $FD " loader=$bloader splash=silent";
					} else {
						print $FD "\t"."echo Loading Xen\n";
						print $FD "\t"."multiboot /boot/xen.gz dummy\n";
						print $FD "\t"."echo Loading linux...\n";
						print $FD "\t"."set gfxpayload=keep"."\n";
						print $FD "\t".'module /boot/linux dummy';
						print $FD " loader=$bloader splash=silent";
					}
					print $FD " @failsafe";
					print $FD $cmdline;
					if ($iso) {
						print $FD "\t"."echo Loading initrd...\n";
						print $FD "\t"."module /boot/initrd dummy\n";
					} elsif (
						($type=~ /^KIWI USB/) || 
						($imgtype=~ /vmx|oem|split/)
					) {
						print $FD "\t"."echo Loading initrd.vmx...\n";
						print $FD "\t"."module /boot/initrd.vmx dummy\n";
					} else {
						print $FD "\t"."echo Loading initrd...\n";
						print $FD "\t"."module /boot/initrd dummy\n";
					}
					print $FD "}\n";
				}
			}
			$FD -> close();
			#==========================================
			# copy grub2 config file to efi path too
			#------------------------------------------
			if ($config eq 'grub2-efi') {
				qxx ("cp $tmpdir/boot/$config/grub.cfg $tmpdir/EFI/BOOT 2>&1");
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# Grub
	#------------------------------------------
	if ($loader eq "grub") {
		#==========================================
		# boot id in grub context
		#------------------------------------------
		my $boot_id = 0;
		if ($this->{partids}) {
			$boot_id = $this->{partids}{boot} - 1;
		}
		#==========================================
		# Create menu.lst file
		#------------------------------------------
		$kiwi -> info ("Creating grub menu list file...");
		qxx ("mkdir -p $tmpdir/boot/grub");
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$tmpdir/boot/grub/menu.lst")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create menu.lst: $!");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# Compat link
		#------------------------------------------
		qxx ("cd $tmpdir/boot/grub && ln -s menu.lst grub.conf");
		#==========================================
		# General grub setup
		#------------------------------------------
		binmode($FD, ":encoding(UTF-8)");
		print $FD "color cyan/blue white/blue\n";
		print $FD "default $defaultBootNr\n";
		my $bootTimeout = 10;
		if (defined $type{boottimeout}) {
			$bootTimeout = $type{boottimeout};
		}
		if ($type{fastboot}) {
			$bootTimeout = 0;
		}
		print $FD "timeout $bootTimeout\n";
		if ($type =~ /^KIWI (CD|USB)/) {
			my $dev = $1 eq 'CD' ? '(cd)' : "(hd0,$boot_id)";
			if (! $type{fastboot}) {
				if (-e "$tmpdir/boot/grub/splash.xpm.gz") {
					print $FD "splashimage=$dev/boot/grub/splash.xpm.gz\n"
				} elsif (-e "$tmpdir/boot/message") {
					print $FD "gfxmenu $dev/boot/message\n";
				}
			}
			print $FD "title Boot from Hard Disk\n";
			if ($dev eq '(cd)') {
				print $FD " rootnoverify (hd0)\n";
				print $FD " chainloader (hd0)+1\n";
			} else {
				print $FD " chainloader $dev/boot/grub/bootnext\n";
				my $bootnext = $this -> addBootNext (
					"$tmpdir/boot/grub/bootnext", hex $this->{mbrid}
				);
				if (! defined $bootnext) {
					$kiwi -> failed ();
					$kiwi -> error  ("Failed to write bootnext\n");
					$kiwi -> failed ();
					$FD -> close();
					return;
				}
			}
			$title = $this -> makeLabel ("Install $label");
			print $FD "title $title\n";
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
			if (-e "$tmpdir/boot/grub/splash.xpm.gz") {
				print $FD "splashimage=(hd0,$boot_id)/boot/grub/splash.xpm.gz\n"
			} elsif (-e "$tmpdir/boot/message") {
				print $FD "gfxmenu (hd0,$boot_id)/boot/message\n";
			}
			print $FD "title $title\n";
		}
		#==========================================
		# Standard boot
		#------------------------------------------
		if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
			if ($iso) {
				print $FD " kernel (cd)/boot/linux vga=$vga splash=silent";
				print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
				print $FD " cdinst=1 loader=$bloader";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD " root (hd0,$boot_id)\n";
				print $FD " kernel /boot/linux.vmx vga=$vga";
				print $FD " loader=$bloader splash=silent";
			} else {
				print $FD " root (hd0,$boot_id)\n";
				print $FD " kernel /boot/linux vga=$vga";
				print $FD " loader=$bloader splash=silent";
			}
			print $FD $cmdline;
			if ($iso) {
				print $FD " initrd (cd)/boot/initrd\n";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD " initrd /boot/initrd.vmx\n";
			} else {
				print $FD " initrd /boot/initrd\n";
			}
		} else {
			if ($iso) {
				print $FD " kernel (cd)/boot/xen.gz\n";
				print $FD " module /boot/linux vga=$vga splash=silent";
				print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
				print $FD " cdinst=1 loader=$bloader";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD " root (hd0,$boot_id)\n";
				print $FD " kernel /boot/xen.gz.vmx\n";
				print $FD " module /boot/linux.vmx vga=$vga";
				print $FD " loader=$bloader splash=silent";
			} else {
				print $FD " root (hd0,$boot_id)\n";
				print $FD " kernel /boot/xen.gz\n";
				print $FD " module /boot/linux vga=$vga";
				print $FD " loader=$bloader splash=silent";
			}
			print $FD $cmdline;
			if ($iso) {
				print $FD " module (cd)/boot/initrd\n";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD " module /boot/initrd.vmx\n";
			} else {
				print $FD " module /boot/initrd\n";
			}
		}
		#==========================================
		# Failsafe boot
		#------------------------------------------
		if ($failsafe) {
			$title = $this -> makeLabel ("Failsafe -- $title");
			print $FD "title $title\n";
			if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
				if ($iso) {
					print $FD " kernel (cd)/boot/linux vga=$vga splash=silent";
					print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
					print $FD " cdinst=1 loader=$bloader";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD " root (hd0,$boot_id)\n";
					print $FD " kernel /boot/linux.vmx vga=$vga";
					print $FD " loader=$bloader splash=silent";
				} else {
					print $FD " root (hd0,$boot_id)\n";
					print $FD " kernel /boot/linux vga=$vga";
					print $FD " loader=$bloader splash=silent";
				}
				print $FD " @failsafe";
				print $FD $cmdline;
				if ($iso) {
					print $FD " initrd (cd)/boot/initrd\n";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD " initrd /boot/initrd.vmx\n";
				} else {
					print $FD " initrd /boot/initrd\n";
				}
			} else {
				if ($iso) {
					print $FD " kernel (cd)/boot/xen.gz\n";
					print $FD " module (cd)/boot/linux vga=$vga splash=silent";
					print $FD " ramdisk_size=512000 ramdisk_blocksize=4096";
					print $FD " cdinst=1 loader=$bloader";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD " root (hd0,$boot_id)\n";
					print $FD " kernel /boot/xen.gz.vmx\n";
					print $FD " module /boot/linux.vmx vga=$vga";
					print $FD " loader=$bloader splash=silent";
				} else {
					print $FD " root (hd0,$boot_id)\n";
					print $FD " kernel /boot/xen.gz\n";
					print $FD " module /boot/linux vga=$vga";
					print $FD " loader=$bloader splash=silent";
				}
				print $FD " @failsafe";
				print $FD $cmdline;
				if ($iso) {
					print $FD " module (cd)/boot/initrd\n"
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD " module /boot/initrd.vmx\n"
				} else {
					print $FD " module /boot/initrd\n";
				}
			}
		}
		$FD -> close();
		$kiwi -> done();
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader =~ /(sys|ext)linux/) {
		#==========================================
		# Create syslinux config file
		#------------------------------------------
		my $syslconfig = "syslinux.cfg";
		if ($loader eq "extlinux") {
			$syslconfig = "extlinux.conf";
		}
		$kiwi -> info ("Creating $syslconfig config file...");
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$tmpdir/boot/syslinux/$syslconfig")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $syslconfig: $!");
			$kiwi -> failed ();
			return;
		}
		my $syslinux_new_format = 0;
		my $gfx = "$tmpdir/boot/syslinux";
		if (-f "$gfx/gfxboot.com" || -f "$gfx/gfxboot.c32") {
			$syslinux_new_format = 1;
		}
		#==========================================
		# General syslinux setup
		#------------------------------------------
		print $FD "implicit 1"."\n";
		print $FD "prompt   1"."\n";
		my $bootTimeout = 100;
		if (defined $type{boottimeout}) {
			$bootTimeout = $type{boottimeout};
			if (int ($bootTimeout) == 0) {
				# /.../
				# a timeout value of 0 disables the timeout in syslinux
				# therefore we set the smallest possible value in that case
				# which is 1/10 sec
				# ----
				$bootTimeout = 1;
			}
		}
		print $FD "timeout  $bootTimeout"."\n";
		print $FD "display isolinux.msg"."\n";
		my @labels = ();
		if (-f "$gfx/bootlogo") {
			if ($syslinux_new_format) {
				print $FD "ui gfxboot bootlogo isolinux.msg"."\n";
			} else {
				print $FD "gfxboot bootlogo"."\n";
			}
		}
		#==========================================
		# Setup default title
		#------------------------------------------
		if ($type =~ /^KIWI (CD|USB)/) {
			if ($defaultBootNr == 0) {
				$title = $this -> makeLabel ("Boot from Hard Disk");
			} elsif ($defaultBootNr == 1) {
				$title = $this -> makeLabel ("Install $label");
			} else {
				$title = $this -> makeLabel (
					"Failsafe -- Install $label"
				);
			}
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
		}
		print $FD "default $title"."\n";
		if ($type =~ /^KIWI (CD|USB)/) {
			$title = $this -> makeLabel ("Boot from Hard Disk");
			print $FD "label $title\n";
			print $FD "localboot 0x80\n";
			$title = $this -> makeLabel ("Install $label");
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
		}
		print $FD "label $title"."\n";
		push @labels,$title;
		#==========================================
		# Standard boot
		#------------------------------------------
		if (! $isxen) {
			if ($iso) {
				print $FD "kernel linux\n";
				print $FD "append initrd=initrd ";
				print $FD "vga=$vga loader=$bloader splash=silent ";
				print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
				print $FD "cdinst=1 kiwi_hybrid=1";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD "kernel /boot/linux.vmx\n";
				print $FD "append initrd=/boot/initrd.vmx ";
				print $FD "vga=$vga loader=$bloader splash=silent";
			} else {
				print $FD "kernel /boot/linux\n";
				print $FD "append initrd=/boot/initrd ";
				print $FD "vga=$vga loader=$bloader splash=silent";
			}
		} else {
			if ($iso) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen cdinst not supported ***");
				$kiwi -> failed ();
				return;
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen boot not supported ***");
				$kiwi -> failed ();
				return;
			} else {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen boot not supported ***");
				$kiwi -> failed ();
				return;
			}
		}
		print $FD $cmdline;
		#==========================================
		# Failsafe boot
		#------------------------------------------
		if ($failsafe) {
			if ($iso) {
				$title = $this -> makeLabel ("Failsafe -- Install $label");
				print $FD "label $title"."\n";
			} elsif ($type =~ /^KIWI USB/) {
				$title = $this -> makeLabel ("Failsafe -- Install $label");
				print $FD "label $title"."\n";
			} else {
				$title = $this -> makeLabel ("Failsafe -- $label [ $type ]");
				print $FD "label $title"."\n";
			}
			push @labels,$title;
			if (! $isxen) {
				if ($iso) {
					print $FD "kernel linux\n";
					print $FD "append initrd=initrd ";
					print $FD "vga=$vga loader=$bloader splash=silent ";
					print $FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
					print $FD "cdinst=1 kiwi_hybrid=1";
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					print $FD "kernel /boot/linux.vmx\n";
					print $FD "append initrd=/boot/initrd.vmx ";
					print $FD "vga=$vga loader=$bloader splash=silent";
				} else {
					print $FD "kernel /boot/linux\n";
					print $FD "append initrd=/boot/initrd ";
					print $FD "vga=$vga loader=$bloader splash=silent";
				}
				print $FD " @failsafe";
			} else {
				if ($iso) {
					$kiwi -> failed ();
					$kiwi -> error  (
						"*** syslinux: Xen cdinst not supported ***"
					);
					$kiwi -> failed ();
					return;
				} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
					$kiwi -> failed ();
					$kiwi -> error  (
						"*** syslinux: Xen boot not supported ***"
					);
					$kiwi -> failed ();
					return;
				} else {
					$kiwi -> failed ();
					$kiwi -> error  (
						"*** syslinux: Xen boot not supported ***"
					);
					$kiwi -> failed ();
					return;
				}
				print $FD " @failsafe";
			}
			print $FD $cmdline;
		}
		$FD -> close();
		#==========================================
		# setup isolinux.msg file
		#------------------------------------------
		my $isofd = FileHandle -> new();
		if (! $isofd -> open (">$tmpdir/boot/syslinux/isolinux.msg")) {
			$kiwi -> failed();
			$kiwi -> error  ("Failed to create isolinux.msg: $!");
			$kiwi -> failed ();
			return;
		}
		print $isofd "\n"."Welcome !"."\n\n";
		foreach my $label (@labels) {
			print $isofd "$label"."\n";
		}
		print $isofd "\n\n";
		print $isofd "Have a lot of fun..."."\n";
		$isofd -> close();
		$kiwi -> done();
	}
	#==========================================
	# Zipl
	#------------------------------------------
	if ($loader eq "zipl") {
		#==========================================
		# Create zipl.conf
		#------------------------------------------
		qxx ("mkdir -p $tmpdir/boot/zipl");
		$cmdline =~ s/\n//g;
		my $ziplconfig = "zipl.conf";
		$kiwi -> info ("Creating $ziplconfig config file...");
		if ($isxen) {
			$kiwi -> failed ();
			$kiwi -> error  ("*** zipl: Xen boot not supported ***");
			$kiwi -> failed ();
			return;
		}
		if (! -e "/boot/zipl") {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't find bootloader: /boot/zipl");
			$kiwi -> failed ();
			return;
		}
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$tmpdir/boot/$ziplconfig")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $ziplconfig: $!");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# General zipl setup
		#------------------------------------------
		my $title_standard;
		my $title_failsafe;
		if ($type =~ /^KIWI (CD|USB)/) {
			$title_standard = $this -> makeLabel (
				"Install $label"
			);
			$title_failsafe = $this -> makeLabel (
				"Failsafe -- Install $label"
			);
		} else {
			$title_standard = $this -> makeLabel (
				"$label ( $type )"
			);
			$title_failsafe = $this -> makeLabel (
				"Failsafe -- $label ( $type )"
			);
		}
		print $FD "[defaultboot]"."\n";
		print $FD "defaultmenu = menu"."\n\n";
		print $FD ":menu"."\n";
		print $FD "\t"."default = 1"."\n";
		print $FD "\t"."prompt  = 1"."\n";
		print $FD "\t"."target  = boot/zipl"."\n";
		print $FD "\t"."timeout = 200"."\n";
		print $FD "\t"."1 = $title_standard"."\n";
		print $FD "\t"."2 = $title_failsafe"."\n\n";
		#==========================================
		# Standard boot
		#------------------------------------------
		print $FD "[$title_standard]"."\n";
		if ($iso) {
			$kiwi -> failed ();
			$kiwi -> error  ("*** zipl: CD boot not supported ***");
			$kiwi -> failed ();
			return;
		} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
			print $FD "\t"."image   = boot/linux.vmx"."\n";
			print $FD "\t"."target  = boot/zipl"."\n";
			print $FD "\t"."ramdisk = boot/initrd.vmx,0x4000000"."\n";
		} else {
			print $FD "\t"."image   = boot/linux"."\n";
			print $FD "\t"."target  = boot/zipl"."\n";
			print $FD "\t"."ramdisk = boot/initrd,0x4000000"."\n";
		}
		print $FD "\t"."parameters = \"loader=$bloader";
		print $FD " $cmdline\""."\n";
		#==========================================
		# Failsafe boot
		#------------------------------------------
		if ($failsafe) {
			print $FD "[$title_failsafe]"."\n";
			if ($iso) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** zipl: CD boot not supported ***");
				$kiwi -> failed ();
				return;
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD "\t"."image   = boot/linux.vmx"."\n";
				print $FD "\t"."target  = boot/zipl"."\n";
				print $FD "\t"."ramdisk = boot/initrd.vmx,0x4000000"."\n";
			} else {
				print $FD "\t"."image   = boot/linux"."\n";
				print $FD "\t"."target  = boot/zipl"."\n";
				print $FD "\t"."ramdisk = boot/initrd,0x4000000"."\n";
			}
			print $FD "\t"."parameters = \"x11failsafe loader=$bloader";
			print $FD " $cmdline\""."\n";
		}
		$FD -> close();
		$kiwi -> done();
	}
	#==========================================
	# yaboot
	#------------------------------------------
	if ($loader eq "yaboot") {
		#==========================================
		# Create yaboot.cnf
		#------------------------------------------
		$kiwi -> info ("Creating lilo/yaboot config file...");
		$cmdline =~ s/\n//g;
		my $bootTimeout = 80;
		if (defined $type{boottimeout}) {
			$bootTimeout = $type{boottimeout};
		}
		#==========================================
		# Standard boot
		#------------------------------------------
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$tmpdir/boot/yaboot.cnf")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create yaboot.cnf: $!");
			$kiwi -> failed ();
			return;
		}
		#==========================================
		# General yaboot setup
		#------------------------------------------
		if ($type =~ /^KIWI (CD|USB)/) {
			$title = $this -> makeLabel ("Install $label");
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
		}
		print $FD "default = $title\n";
		print $FD "timeout = $bootTimeout\n";
		#==========================================
		# Standard boot
		#------------------------------------------
		if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
			if ($iso) {
				print $FD "\t"."label = $title\n";
				print $FD "\t"."image  = /boot/linux\n";
				print $FD "\t"."initrd = /boot/initrd\n";
				print $FD "\t"."append = \"$cmdline loader=$bloader cdinst=1\"";
				print $FD "\n";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print $FD "\t"."label = $title\n";
				print $FD "\t"."image  = /boot/linux.vmx"."\n";
				print $FD "\t"."initrd = /boot/initrd.vmx\n";
				print $FD "\t"."append = \"$cmdline loader=$bloader\"\n";
			} else {
				print $FD "\t"."label = $title\n";
				print $FD "\t"."image  = /boot/linux"."\n";
				print $FD "\t"."initrd = /boot/initrd\n";
				print $FD "\t"."append = \"$cmdline loader=$bloader\"\n";
			}
		} else {
			$kiwi -> failed ();
			$kiwi -> error  ("*** not implemented ***");
			$kiwi -> failed ();
			return;
		}
		$FD -> close();
		$kiwi -> done();
		#==========================================
		# Create bootinfo.txt
		#------------------------------------------
		my $binfofd = FileHandle -> new();
		if (! $binfofd -> open (">$tmpdir/boot/bootinfo.txt")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create bootinfo.txt: $!");
			$kiwi -> failed ();
			return;
		}
		print $binfofd "<chrp-boot>\n";
		print $binfofd "<description>$title</description>\n";
		print $binfofd "<os-name>$title</os-name>\n";
		print $binfofd "<boot-script>boot &device;:1,yaboot</boot-script>\n";
		print $binfofd "</chrp-boot>\n";
		$binfofd -> close();
		$kiwi -> done ();
	}
	#==========================================
	# uboot
	#------------------------------------------
	if ($loader eq "uboot") {
		#==========================================
		# Create uboot image file from initrd
		#------------------------------------------
		$kiwi -> info ("Creating uBoot initrd image...");
		$cmdline =~ s/\n//g;
		my $mkopts = "-A arm -O linux -T ramdisk -C none -a 0x0 -e 0x0";
		my $inputf = "$tmpdir/boot/initrd.vmx";
		my $result = "$tmpdir/boot/initrd.uboot";
		my $data = qxx ("mkimage $mkopts -n 'Initrd' -d $inputf $result");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to create uboot initrd image: $data");
			$kiwi -> failed ();
			return;
		}
		qxx ("rm -f $inputf 2>&1");
		$kiwi -> done();
		#==========================================
		# Create boot.script
		#------------------------------------------
		$kiwi -> info ("Creating boot.script uboot config file...");
		#==========================================
		# Standard boot
		#------------------------------------------
		# this is only the generic part of the boot script. The
		# custom parts needs to be added via the editbootconfig
		# script hook
		# ----
		my $FD = FileHandle -> new();
		if (! $FD -> open (">$tmpdir/boot/boot.script")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create boot.script: $!");
			$kiwi -> failed ();
			return;
		}
		print $FD 'setenv ramdisk boot/initrd.uboot'."\n";
		print $FD 'setenv kernel boot/linux.vmx'."\n";
		print $FD 'setenv initrd_high "0xffffffff"'."\n";
		print $FD 'setenv fdt_high "0xffffffff"'."\n";
		if ($iso) {
			$kiwi -> failed ();
			$kiwi -> error  ("*** uboot: CD boot not supported ***");
			$kiwi -> failed ();
			return;
		} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
			print $FD "setenv bootargs loader=$bloader $cmdline \${append}\n";
		} else {
			print $FD "setenv bootargs loader=$bloader $cmdline \${append}\n"
		}
		$FD -> close();
		$kiwi -> done();
	}
	#==========================================
	# more boot managers to come...
	#------------------------------------------
	#==========================================
	# Check for edit boot config
	#------------------------------------------
	if ($cmdL) {
		my $editBoot = $cmdL -> getEditBootConfig();
		my $idesc;
		if ((! $editBoot) && ($xml)) {
			$editBoot = $xml -> getEditBootConfig_legacy();
		}
		if ($editBoot) {
			if ($this->{originXMLPath}) {
				$editBoot = $this->{originXMLPath}."/".$editBoot;
			}
			if (-f $editBoot) {
				$kiwi -> info ("Calling pre bootloader install script:\n");
				$kiwi -> info ("--> $editBoot\n");
				my @opts = ();
				if ($type{bootfilesystem}) {
					push @opts,$type{bootfilesystem};
				}
				if ($this->{partids}) {
					push @opts,$this->{partids}{boot};
				}
				system ("cd $tmpdir && chmod u+x $editBoot");
				system ("cd $tmpdir && bash --norc -c \"$editBoot @opts\"");
				my $result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error ("Call failed, see console log");
					$kiwi -> failed ();
					return;
				}
			} else {
				$kiwi -> warning (
					"Can't find pre bootloader install script: $editBoot..."
				);
				$kiwi -> skipped ();
			}
		}
	}
	return $this;
}

#==========================================
# copyBootCode
#------------------------------------------
sub copyBootCode {
	my $this     = shift;
	my $source   = shift;
	my $dest     = shift;
	my $loader   = shift;
	my $kiwi     = $this->{kiwi};
	my $firmware = $this->{firmware};
	my $status   = qxx ("cp -dR $source/boot $dest 2>&1");
	my $result   = $? >> 8;
	if ($result != 0) {
		$kiwi -> oops ();
		$kiwi -> warning ("Copy of boot data returned: $status");
	}
	if (! $this->{needBootP}) {
		return $this;
	}
	#==========================================
	# EFI
	#------------------------------------------
	if (($firmware eq "efi") || ($firmware eq "uefi")) {
		$status = qxx ("cp -a $source/EFI $dest");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't copy EFI loader to final path: $status");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Uboot
	#------------------------------------------
	if ($loader eq "uboot") {
		$status = qxx ("mv $dest/boot/boot.scr $dest");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't move boot script: $status");
			$kiwi -> failed ();
			return;
		}
		if (-f "$dest/boot/u-boot.bin") {
			$status = qxx ("mv $dest/boot/u-boot.bin $dest");
			$result = $? >> 8;
		}
		if (-f "$dest/boot/MLO") {
			$status = qxx ("mv $dest/boot/MLO $dest");
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error (
				"Couldn't move uboot/MLO loaders to final path: $status"
			);
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# YaBoot
	#------------------------------------------
	if ($loader eq "yaboot") {
		$status = qxx ("mv $dest/boot/bootinfo.txt $dest");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't move bootinfo.txt: $status");
			$kiwi -> failed ();
			return;
		}
		$status = qxx ("mv $dest/boot/yaboot.cnf $dest");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't move yaboot config: $status");
			$kiwi -> failed ();
			return;
		}
		$status = qxx ("mv $dest/boot/yaboot $dest");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't move yaboot loader: $status");
			$kiwi -> failed ();
			return;
		}
	}
	return $this;
}

#==========================================
# installBootLoader
#------------------------------------------
sub installBootLoader {
	my $this     = shift;
	my $loader   = shift;
	my $diskname = shift;
	my $kiwi     = $this->{kiwi};
	my $tmpdir   = $this->{tmpdir};
	my $chainload= $this->{chainload};
	my $lvm	     = $this->{lvm};
	my $cmdL     = $this->{cmdL};
	my $xml      = $this->{xml};
	my $firmware = $this->{firmware};
	my $system   = $this->{system};
	my $locator  = KIWILocator -> instance();
	my $bootdev;
	my $result;
	my $status;
	#==========================================
	# Setup boot device name
	#------------------------------------------
	my $boot_id = 1;
	if ($this->{partids}) {
		$boot_id = $this->{partids}{boot};
	}
	if ((! $this->{bindloop}) && (-b $diskname)) {
		$bootdev = $this -> __getPartBase ($diskname).$boot_id;
	} else {
		$bootdev = $this->{bindloop}.$boot_id;
	}
	#==========================================
	# Grub2
	#------------------------------------------
	if ($loader eq "grub2") {
		#==========================================
		# No install required with EFI bios
		#------------------------------------------
		if (($firmware ne "efi") && ($firmware ne "uefi")) {
			$kiwi -> info ("Installing grub2 on device: $diskname");
			#==========================================
			# Create device map for the disk
			#------------------------------------------
			my $dmfile = "$tmpdir/boot/grub2/device.map";
			my $dmfd = FileHandle -> new();
			if (! $dmfd -> open(">$dmfile")) {
				$kiwi -> failed ();
				$kiwi -> error ("Couldn't create grub2 device map: $!");
				$kiwi -> failed ();
				return;
			}
			print $dmfd "(hd0) $diskname\n";
			$dmfd -> close();
			#==========================================
			# Install grub2
			#------------------------------------------
			my $stages = "/mnt/boot/grub2/i386-pc";
			$status = qxx ("mount $bootdev /mnt 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error ("Couldn't mount boot partition: $status");
				$kiwi -> failed ();
				return;
			}
			if ((! $chainload) && ($firmware ne "efi")) {
				#==========================================
				# install grub2 into MBR
				#------------------------------------------
				$status = qxx (
					"grub2-bios-setup -v -d $stages -m $dmfile $diskname 2>&1"
				);
				$result = $? >> 8;
			} else {
				#==========================================
				# install grub2 into partition
				#------------------------------------------
				my $bdev = readlink ($bootdev);
				$bdev =~ s/\.\./\/dev/;
				$status = qxx (
					"grub2-bios-setup -vf -d $stages -m $dmfile $bdev 2>&1"
				);
				$result = $? >> 8;
			}
			qxx ("umount /mnt");
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  (
					"Couldn't install $loader on $diskname: $status"
				);
				$kiwi -> failed ();
				$this -> cleanStack ();
				return;
			}
			#==========================================
			# Clean loop maps
			#------------------------------------------
			$this -> cleanStack ();
			#==========================================
			# Check for chainloading
			#------------------------------------------
			if ($chainload) {
				# /.../
				# chainload grub with master-boot-code
				# zero out sectors between 0x200 - 0x3f0 for preload process
				# store a copy of the master-boot-code at 0x800
				# write FDST flag at 0x190
				# ---
				my $mbr = "/usr/lib/boot/master-boot-code";
				my $opt = "conv=notrunc";
				#==========================================
				# write master-boot-code
				#------------------------------------------
				$status = qxx (
					"dd if=$mbr of=$diskname bs=1 count=446 $opt 2>&1"
				);
				$result= $? >> 8;
				if ($result != 0) {
					$kiwi -> failed ();
					$kiwi -> error  (
						"Couldn't install master boot code: $status"
					);
					$kiwi -> failed ();
					return;
				}
				#==========================================
				# write FDST flag
				#------------------------------------------
				my $fdst = "perl -e \"printf '%s', pack 'A4', eval 'FDST';\"";
				qxx (
					"$fdst| \\
					dd of=$diskname bs=1 count=4 seek=\$((0x190)) $opt 2>&1"
				);
			}
			$kiwi -> done();
		}
	}
	#==========================================
	# Grub
	#------------------------------------------
	if ($loader eq "grub") {
		$kiwi -> info ("Installing grub on device: $diskname");
		#==========================================
		# re-init bootid, legacy grub starts at 0
		#------------------------------------------
		$boot_id = 0;
		if ($this->{partids}) {
			$boot_id = $this->{partids}{boot} - 1;
		}
		#==========================================
		# Clean loop maps
		#------------------------------------------
		$this -> cleanStack();
		#==========================================
		# Create device map for the disk
		#------------------------------------------
		my $dmfile = "$tmpdir/grub-device.map";
		my $dmfd = FileHandle -> new();
		if (! $dmfd -> open(">$dmfile")) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't create grub device map: $!");
			$kiwi -> failed ();
			return;
		}
		print $dmfd "(hd0) $diskname\n";
		$dmfd -> close();
		#==========================================
		# Create command list to install grub
		#------------------------------------------
		my $cmdfile = "$tmpdir/grub-device.cmds";
		if (! $dmfd -> open(">$cmdfile")) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't create grub command list: $!");
			$kiwi -> failed ();
			return;
		}
		print $dmfd "device (hd0) $diskname\n";
		print $dmfd "root (hd0,$boot_id)\n";
		if ($chainload) {
			print $dmfd "setup (hd0,$boot_id)\n";
		} else {
			print $dmfd "setup (hd0)\n";
		}
		print $dmfd "quit\n";
		$dmfd -> close();
		#==========================================
		# Install grub in batch mode
		#------------------------------------------
		my $grub = $locator -> getExecPath ('grub');
		if (! $grub) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't locate grub binary");
			$kiwi -> failed ();
			return;
		}
		my $grubOptions = "--device-map $dmfile --no-floppy --batch";
		if (-d "/boot/grub") {
			qxx ("mount --bind $tmpdir/boot/grub /boot/grub");
		}
		qxx ("$grub $grubOptions < $cmdfile &> $tmpdir/grub.log");
		qxx ("umount /boot/grub &>/dev/null");
		my $glog;
		if ($dmfd -> open ("$tmpdir/grub.log")) {
			my @glog = <$dmfd>; $dmfd -> close();
			if ($dmfd -> open ($cmdfile)) {
				my @cmdlog = <$dmfd>; $dmfd -> close();
				push @glog,"GRUB: commands:";
				push @glog,@cmdlog;
			}
			$result = grep { /^\s*Running.*succeeded$/ } @glog;
			if (($result) && (! $chainload)) {
				$result = grep { /^\s*Running.*are embedded\.$/ } @glog;
			}
			if ($result) {
				# found stage information, set good result exit code
				$result = 0;
			}
			$glog = join ("\n",@glog);
			$kiwi -> loginfo ("GRUB: $glog\n");
		}
		if ($result == 0) {
			my $boot = "'boot sector'";
			my $null = "/dev/null";
			$status= qxx (
				"dd if=$diskname bs=512 count=1 2>$null|file - | grep -q $boot"
			);
			$result= $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install grub on $diskname: $glog");
			$kiwi -> failed ();
			return;
		}
		if ($chainload) {
			# /.../
			# chainload grub with master-boot-code
			# zero out sectors between 0x200 - 0x3f0 for preload process
			# store a copy of the master-boot-code at 0x800
			# write FDST flag at 0x190
			# ---
			my $mbr = "/usr/lib/boot/master-boot-code";
			my $opt = "conv=notrunc";
			#==========================================
			# write master-boot-code
			#------------------------------------------
			$status = qxx (
				"dd if=$mbr of=$diskname bs=1 count=446 $opt 2>&1"
			);
			$result= $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't install master boot code: $status");
				$kiwi -> failed ();
				return;
			}
			#==========================================
			# write backup MBR with partition table
			#------------------------------------------
			#my $bmbr= $diskname.".mbr";
			#$status = qxx (
			#	"dd if=$diskname of=$bmbr bs=1 count=512 2>&1"
			#);
			#$result= $? >> 8;
			#if ($result != 0) {
			#	$kiwi -> failed ();
			#	$kiwi -> error  ("Couldn't store backup MBR: $status");
			#	$kiwi -> failed ();
			#	return;
			#}
			#$status = qxx (
			#  "dd if=$bmbr of=$diskname bs=512 count=1 seek=3 skip=0 $opt 2>&1"
			#);
			#unlink $bmbr;
			#==========================================
			# write FDST flag
			#------------------------------------------
			my $fdst = "perl -e \"printf '%s', pack 'A4', eval 'FDST';\"";
			qxx (
				"$fdst|dd of=$diskname bs=1 count=4 seek=\$((0x190)) $opt 2>&1"
			);
		}
		$kiwi -> done();
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader =~ /(sys|ext)linux/) {
		#==========================================
		# Install sys/extlinux on boot device
		#------------------------------------------
		if ($loader eq "syslinux") {
			$kiwi -> info ("Installing syslinux on device: $bootdev");
			$status = qxx ("syslinux $bootdev 2>&1");
			$result = $? >> 8;
		} else {
			$kiwi -> info ("Installing extlinux on device: $bootdev");
			$status = qxx ("mount $bootdev /mnt 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx ("extlinux --install /mnt/boot/syslinux 2>&1");
				$result = $? >> 8;
			}
			$status = qxx ("umount /mnt 2>&1");
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install $loader on $bootdev: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		#==========================================
		# Clean loop maps
		#------------------------------------------
		$this -> cleanStack();
		#==========================================
		# Write syslinux master boot record
		#------------------------------------------
		my $syslmbr = "/usr/share/syslinux/mbr.bin";
		$status = qxx (
			"dd if=$syslmbr of=$diskname bs=512 count=1 conv=notrunc 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install syslinux MBR on $diskname");
			$kiwi -> failed ();
			return;
		}
		$kiwi -> done();
	}
	#==========================================
	# Zipl
	#------------------------------------------
	if ($loader eq "zipl") {
		$kiwi -> info ("Installing zipl on device: $diskname");
		my $offset;
		my $haveRealDevice = 1;
		if (! -b $diskname) {
			#==========================================
			# detect disk offset of disk image file
			#------------------------------------------
			$offset = $this -> diskOffset ($diskname);
			if (! $offset) {
				$kiwi -> failed ();
				$kiwi -> error  ("Failed to detect disk offset");
				$kiwi -> failed ();
				return;
			}
			$haveRealDevice = 0;
		}
		#==========================================
		# mount boot device...
		#------------------------------------------
		$status = qxx ("mount $bootdev /mnt 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't mount boot partition: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		my $mount = "/mnt";
		my $config = "$mount/boot/zipl.conf";
		if (! $haveRealDevice) {
			#==========================================
			# rewrite zipl.conf with additional params
			#------------------------------------------
			my $readzconf = FileHandle -> new();
			if (! $readzconf -> open ($config)) {
				$kiwi -> failed ();
				$kiwi -> error  ("Can't open config file for reading: $!");
				$kiwi -> failed ();
				qxx ("umount $mount 2>&1");
				$this -> cleanStack ();
				return;
			}
			my @data = <$readzconf>;
			$readzconf -> close();
			my $zconffd = FileHandle -> new();
			if (! $zconffd -> open (">$config")) {
				$kiwi -> failed ();
				$kiwi -> error  ("Can't open config file for writing: $!");
				$kiwi -> failed ();
				qxx ("umount $mount 2>&1");
				$this -> cleanStack ();
				return;
			}
			$kiwi -> loginfo ("zipl.conf target values:\n");
			foreach my $line (@data) {
				print $zconffd $line;
				if ($line =~ /^:menu/) {
					$kiwi -> loginfo ("targetbase = $this->{loop}\n");
					$kiwi -> loginfo ("targetbase = SCSI\n");
					$kiwi -> loginfo ("targetblocksize = 512\n");
					$kiwi -> loginfo ("targetoffset = $offset\n");
					print $zconffd "\t"."targetbase = $this->{loop}"."\n";
					print $zconffd "\t"."targettype = SCSI"."\n";
					print $zconffd "\t"."targetblocksize = 512"."\n";
					print $zconffd "\t"."targetoffset = $offset"."\n";
				}
			}
			$zconffd -> close();
		}
		#==========================================
		# call zipl...
		#------------------------------------------
		$status = qxx ("cd $mount && zipl -c $config 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install zipl on $diskname: $status");
			$kiwi -> failed ();
			qxx ("umount $mount 2>&1");
			$this -> cleanStack ();
			return;
		}
		qxx ("umount $mount 2>&1");
		$kiwi -> done();
		#==========================================
		# clean loop maps
		#------------------------------------------
		$this -> cleanStack ();
	}
	#==========================================
	# install yaboot/lilo
	#------------------------------------------
	if ($loader eq "yaboot") {
		# presence of yaboot binary in the boot partition is already done
	}
	#==========================================
	# install uboot
	#------------------------------------------
	if ($loader eq "uboot") {
		# There is no generic way to do this, use editbootinstall script hook
	}
	#==========================================
	# more boot managers to come...
	#------------------------------------------
	#==========================================
	# Check for edit boot install
	#------------------------------------------
	if ($cmdL) {
		my $editBoot = $cmdL -> getEditBootInstall();
		my $idesc;
		if ((! $editBoot) && ($xml)) {
			$editBoot = $xml -> getEditBootInstall_legacy();
		}
		if ($editBoot) {
			if ($this->{originXMLPath}) {
				$editBoot = $this->{originXMLPath}."/".$editBoot;
			}
			if (-f $editBoot) {
				$kiwi -> info ("Calling post bootloader install script:\n");
				$kiwi -> info ("--> $editBoot\n");
				my @opts = ($diskname,$bootdev);
				system ("cd $tmpdir && chmod u+x $editBoot");
				system ("cd $tmpdir && bash --norc -c \"$editBoot @opts\"");
				my $result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error ("Call failed, see console log");
					$kiwi -> failed ();
					return;
				}
			} else {
				$kiwi -> warning (
					"Can't find post bootloader install script: $editBoot..."
				);
				$kiwi -> skipped ();
			}
		}
	}
	#==========================================
	# clean loop maps
	#------------------------------------------
	$this -> cleanStack ();
	#==========================================
	# Write custom disk label ID to MBR
	#------------------------------------------
	if ($loader ne "yaboot") {
		$kiwi -> info ("Saving disk label in MBR: $this->{mbrid}...");
		if (! $this -> writeMBRDiskLabel ($diskname)) {
			return;
		}
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# bindDiskDevice
#------------------------------------------
sub bindDiskDevice {
	my $this   = shift;
	my $system = shift;
	my $kiwi   = $this->{kiwi};
	my @cStack = @{$this->{cleanupStack}};
	my $status;
	my $result;
	my $loop;
	#==========================================
	# bind file to loop device
	#------------------------------------------
	$status = qxx ("/sbin/losetup -f --show $system 2>&1"); chomp $status;
	$result = $? >> 8;
	if ($result != 0) {
		# /.../
		# first losetup call has failed, try to find free loop
		# device manually even though it's most likely that this
		# search will fail too. The following is only useful for
		# older version of losetup which doesn't understand the
		# option combination -f --show
		# ----
		my $loopfound = 0;
		for (my $id=0;$id<=7;$id++) {
			$status.= qxx ( "/sbin/losetup /dev/loop$id $system 2>&1" );
			$result = $? >> 8;
			if ($result == 0) {
				$loopfound = 1;
				$loop = "/dev/loop".$id;
				$this->{loop} = $loop;
				push @cStack,"losetup -d $loop";
				$this->{cleanupStack} = \@cStack;
				last;
			}
		}
		if (! $loopfound) {
			$kiwi -> loginfo ("Failed binding loop device: $status");
			return;
		}
		return $this;
	}
	$loop = $status;
	$this->{loop} = $loop;
	push @cStack,"losetup -d $loop";
	$this->{cleanupStack} = \@cStack;
	return $this;
}

#==========================================
# bindDiskPartitions
#------------------------------------------
sub bindDiskPartitions {
	# ...
	# make sure we can access the partitions of the
	# loop mounted disk file
	# ---
	my $this   = shift;
	my $disk   = shift;
	my $kiwi   = $this->{kiwi};
	my @cStack = @{$this->{cleanupStack}};
	my $status;
	my $result;
	my $part;
	$status = qxx ("/sbin/kpartx -a $disk 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ("Failed mapping partition: $status");
		return;
	}
	push @cStack,"kpartx -d $disk";
	$this->{cleanupStack} = \@cStack;
	$disk =~ s/dev\///;
	$part = "/dev/mapper".$disk."p";
	$this->{bindloop} = $part;
	return $this;
}

#==========================================
# getGeometry
#------------------------------------------
sub getGeometry {
	# ...
	# obtain number of sectors from the given
	# disk device and return it
	# ---
	my $this     = shift;
	my $disk     = shift;
	my $kiwi     = $this->{kiwi};
	my $cmdL     = $this->{cmdL};
	my $loader   = $this->{bootloader};
	my $firmware = $this->{firmware};
	my $secsz    = $cmdL -> getDiskBIOSSectorSize();
	my $label    = 'msdos';
	my $status;
	my $result;
	my $parted;
	my $locator = KIWILocator -> instance();
	my $parted_exec = $locator -> getExecPath("parted");
	$status = qxx ("dd if=/dev/zero of=$disk bs=512 count=1 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	if (($firmware eq "efi")  ||
		($firmware eq "uefi") ||
		($firmware eq "vboot")
	) {
		$label = 'gpt';
	}
	$status = qxx ("$parted_exec -s $disk mklabel $label 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	$parted = "$parted_exec -m $disk unit s print";
	$status = qxx (
		"$parted | head -n 3 | tail -n 1 | cut -f2 -d:"
	);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	chomp $status;
	$status =~ s/s//;
	if ($label eq 'gpt') {
		$status -= 128;
	} else {
		$status --;
	}
	$this->{pDiskSectors} = $status;
	$kiwi -> loginfo (
		"Disk Sector count is: $this->{pDiskSectors}\n"
	);
	return $status;
}

#==========================================
# getSector
#------------------------------------------
sub getSector {
	# ...
	# turn the given size in MB to the number of
	# required sectors aligned to the value of
	# getDiskAlignment (default 4MB)
	# ----
	my $this  = shift;
	my $size  = shift;
	my $cmdL  = $this->{cmdL};
	my $count = $this->{pDiskSectors};
	my $secsz = $cmdL->getDiskBIOSSectorSize();
	my $align = $cmdL->getDiskAlignment();
	my $sectors;
	if ($size =~ /\+(.*)M$/) {
		# turn value into bytes
		$size = $1;
		$size*= 1048576;
	} else {
		# use entire rest space
		$size = $count * $secsz;
	}
	if ($size < $align) {
		$size = $align;
	}
	$size = (int ($size / $align) * $align) + $align;
	$sectors = sprintf ("%.0f",$size / $secsz);
	$sectors-= 1;
	return $sectors;
}

#==========================================
# resetGeometry
#------------------------------------------
sub resetGeometry {
	# ...
	# reset global disk geometry information
	# ---
	my $this = shift;
	undef $this->{pDiskSectors};
	undef $this->{pStart};
	undef $this->{pStopp};
	return $this;
}

#==========================================
# initGeometry
#------------------------------------------
sub initGeometry {
	# ...
	# setup start sector and stop sector for the given size at
	# first invocation the start sector is set to the default
	# value from the global space or to the value specified on
	# the commandline. On any subsequent call the start sector is
	# calculated from the end sector of the previos partition
	# and the new value gets aligned to the value of getDiskAlignment
	# The function returns the number of sectors which represents
	# the given size
	# ---
	my $this   = shift;
	my $device = shift;
	my $size   = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $align  = $cmdL->getDiskAlignment();
	my $secsz  = $cmdL->getDiskBIOSSectorSize();
	my $align_sectors = int ($align / $secsz);
	my $locator= KIWILocator -> instance();
	if (! defined $this->{pStart}) {
		$this->{pStart} = $cmdL->getDiskStartSector();
	} else {
		sleep (1);
		my $parted_exec = $locator -> getExecPath("parted");
		my $parted = "$parted_exec -m $device unit s print";
		my $status = qxx (
			"$parted | grep :$this->{pStart} | cut -f3 -d:"
		);
		$status=~ s/s//;
		if ($status >= $align_sectors) {
			$status = int ($status / $align_sectors);
			$status*= $align_sectors;
			$status+= $align_sectors;
		}
		$this->{pStart} = $status;
	}
	my $sector = $this -> getSector ($size);
	$this->{pStopp} = $this->{pStart} + $sector;
	if ($this->{pStopp} > $this->{pDiskSectors}) {
		$this->{pStopp} = $this->{pDiskSectors}
	}
	return $sector;
}

#==========================================
# setStoragePartition
#------------------------------------------
sub setStoragePartition {
	# ...
	# creates the partition table on the given device
	# according to the command argument list
	# ---
	my $this     = shift;
	my $device   = shift;
	my $cmdref   = shift;
	my $tool     = $this->{ptool};
	my $kiwi     = $this->{kiwi};
	my $xml      = $this->{xml};
	my $tmpdir   = $this->{tmpdir};
	my @commands = @{$cmdref};
	my $result;
	my $status;
	my $ignore;
	my $action;
	my $locator = KIWILocator -> instance();
	my $parted_exec = $locator -> getExecPath("parted");
	if (! defined $tool) {
		$tool = "parted";
	}
	SWITCH: for ($tool) {
		#==========================================
		# fdasd
		#------------------------------------------
		/^fdasd/  && do {
			$kiwi -> loginfo (
				"FDASD input: $device [@commands]"
			);
			$status = qxx ("dd if=/dev/zero of=$device bs=4096 count=10 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> loginfo ($status);
				return;
			}
			my $FD = FileHandle -> new();
			if (! $FD -> open ("|fdasd $device &> $tmpdir/fdasd.log")) {
				return;
			}
			print $FD "y\n";
			foreach my $cmd (@commands) {
				if ($cmd =~ /[ntwq]$/) {
					$action = $cmd;
				}
				if (($ignore) && ($cmd =~ /[ntwq]$/)) {
					undef $ignore;
				} elsif ($ignore) {
					next;
				}
				if ($cmd eq "a") {
					$ignore=1;
					next;
				}
				if ($cmd eq "p") {
					next;
				}
				if (($cmd =~ /^[0-9]$/) && ($action ne "t")) {
					next;
				}
				if (($cmd eq "83") || ($cmd eq "8e")) {
					$cmd = 1;
				}
				if ($cmd eq "82") {
					$cmd = 2;
				}
				if ($cmd eq ".") {
					print $FD "\n";
				} else {
					print $FD "$cmd\n";
				}
			}
			$FD -> close();
			$result = $? >> 8;
			my $flog;
			my $flogfd = FileHandle -> new();
			if ($flogfd -> open ("$tmpdir/fdasd.log")) {
				my @flog = <$flogfd>;
				$flogfd -> close();
				$flog = join ("\n",@flog);
				$kiwi -> loginfo ("FDASD: $flog");
			}
			last SWITCH;
		};
		#==========================================
		# parted
		#------------------------------------------
		/^parted/  && do {
			my $p_cmd = ();
			$this -> resetGeometry();
			$this -> getGeometry ($device);
			for (my $count=0;$count<@commands;$count++) {
				my $cmd = $commands[$count];
				if ($cmd eq "n") {
					my $size = $commands[$count+4];
					$this -> initGeometry ($device,$size);
					$p_cmd = "mkpart primary $this->{pStart} $this->{pStopp}";
					$kiwi -> loginfo ("PARTED input: $device [$p_cmd]\n");
					qxx ("$parted_exec -s $device unit s $p_cmd 2>&1");
				}
				if ($cmd eq "t") {
					my $index= $commands[$count+1];
					my $type = $commands[$count+2];
					$p_cmd = "set $index type 0x$type";
					$kiwi -> loginfo ("PARTED input: $device [$p_cmd]\n");
					qxx ("$parted_exec -s $device unit s $p_cmd 2>&1");
				}
				if ($cmd eq "a") {
					my $index= $commands[$count+1];
					$p_cmd = "set $index boot on";
					$kiwi -> loginfo ("PARTED input: $device [$p_cmd]\n");
					qxx ("$parted_exec -s $device unit s $p_cmd 2>&1");
				}
			}
			last SWITCH;
		}
	}
	return $this;
}

#==========================================
# getStorageID
#------------------------------------------
sub getStorageID {
	# ...
	# return the partition id of the given
	# partition. If the call fails the function
	# returns 0
	# ---
	my $this   = shift;
	my $device = shift;
	my $partid = shift;
	my $status = qxx ("sfdisk --id $device $partid 2>&1");
	my $result = $? >> 8;
	if ($result == 0) {
		chomp  $status;
		return $status;
	}
	return 0;
}

#==========================================
# getStorageSize
#------------------------------------------
sub getStorageSize {
	# ...
	# return the size of the given disk or disk
	# partition in Kb. If the call fails the function
	# returns 0
	# --- 
	my $this = shift;
	my $pdev = shift;
	my $status = qxx ("blockdev --getsize64 $pdev 2>&1");
	my $result = $? >> 8;
	if ($result == 0) {
		return int ($status / 1024);
	}
	return 0;
}

#==========================================
# setDefaultDeviceMap
#------------------------------------------
sub setDefaultDeviceMap {
	# ...
	# set default device map which creates a mapping for
	# device names to a number
	# ---
	my $this   = shift;
	my $device = shift;
	my %result;
	if (! defined $device) {
		return;
	}
	if ($this->{partids}{root}) {
		$result{root} = $this -> __getPartDevice (
			$device,$this->{partids}{root}
		);
	}
	if ($this->{partids}{readonly}) {
		$result{readonly} = $this -> __getPartDevice (
			$device,$this->{partids}{readonly}
		);
	}
	if ($this->{partids}{readwrite}) {
		$result{readwrite} = $this -> __getPartDevice (
			$device,$this->{partids}{readwrite}
		);
	}
	if ($this->{partids}{boot}) {
		$result{boot} = $this -> __getPartDevice (
			$device,$this->{partids}{boot}
		);
	}
	if ($this->{partids}{jump}) {
		$result{jump} = $this -> __getPartDevice (
			$device,$this->{partids}{jump}
		);
	}
	return %result;
}

#==========================================
# setLoopDeviceMap
#------------------------------------------
sub setLoopDeviceMap {
	# ...
	# set loop device map which creates a mapping for
	# /dev/mapper loop device names to a number
	# ---
	my $this   = shift;
	my $device = shift;
	my %result;
	if (! defined $device) {
		return;
	}
	if ($this->{partids}{root}) {
		$result{root} = $this -> __getPartDevice (
			$device,$this->{partids}{root}
		);
	}
	if ($this->{partids}{readonly}) {
		$result{readonly} = $this -> __getPartDevice (
			$device,$this->{partids}{readonly}
		);
	}
	if ($this->{partids}{readwrite}) {
		$result{readwrite} = $this -> __getPartDevice (
			$device,$this->{partids}{readwrite}
		);
	}
	if ($this->{partids}{boot}) {
		$result{boot} = $this -> __getPartDevice (
			$device,$this->{partids}{boot}
		);
	}
	if ($this->{partids}{jump}) {
		$result{jump} = $this -> __getPartDevice (
			$device,$this->{partids}{jump}
		);
	}
	return %result;
}

#==========================================
# setLVMDeviceMap
#------------------------------------------
sub setLVMDeviceMap {
	# ...
	# set LVM device map which creates a mapping for
	# /dev/VG/name volume group device names to a number
	# ---
	my $this   = shift;
	my $group  = shift;
	my $device = shift;
	my $names  = shift;
	my @names  = @{$names};
	my %result;
	if (! defined $group) {
		return;
	}
	if ($this->{partids}{root_lv}) {
		$result{root} = "/dev/$group/".$this->{partids}{root_lv};
	}
	if ($this->{partids}{readonly_lv}) {
		$result{readonly} = "/dev/$group/".$this->{partids}{readonly_lv};
	}
	if ($this->{partids}{readwrite_lv}) {
		$result{readwrite} = "/dev/$group/".$this->{partids}{readwrite_lv}
	}
	if ($this->{partids}{boot}) {
		$result{boot} = $this -> __getPartDevice (
			$device,$this->{partids}{boot}
		);
	}
	if ($this->{partids}{jump}) {
		$result{jump} = $this -> __getPartDevice (
			$device,$this->{partids}{jump}
		);
	}
	return %result;
}

#==========================================
# setMD
#------------------------------------------
sub setMD {
	# ...
	# create md device for software raid capabilities
	# The function returns a new device map which has
	# the root device overwritten by the md device
	# ---
	my $this      = shift;
	my $map       = shift;
	my $raidtype  = shift;
	my $kiwi      = $this->{kiwi};
	my @cStack    = @{$this->{cleanupStack}};
	my %deviceMap = %{$map};
	my $mdcnt     = 0;
	my $level     = 1;
	my $mddev;
	my $status;
	my $result;
	if ($raidtype eq "striping") {
		$level = 0;
	}
	my $array = "--level=$level --raid-disks=2 $deviceMap{root} missing";
	while ($mdcnt <= 9) {
		$mddev  = '/dev/md'.$mdcnt;
		$status = qxx ("mdadm --create --run $mddev $array 2>&1");
		$result+= $? >> 8;
		if ($result == 0) {
			last;
		}
		$mdcnt++;
	}
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Software raid array creation failed: $status");
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	push @cStack,"mdadm --stop $mddev";
	$this->{cleanupStack} = \@cStack;
	$deviceMap{root} = $mddev;
	$this->{mddev} = $mddev;
	return %deviceMap;
}

#==========================================
# setVolumeGroup
#------------------------------------------
sub setVolumeGroup {
	# ...
	# create volume group and required logical
	# volumes. The function returns a new device map
	# including the volume device names
	# ---
	my $this      = shift;
	my $map       = shift;
	my $device    = shift;
	my $syszip    = shift;
	my $haveSplit = shift;
	my $parts     = shift;
	my @cStack    = @{$this->{cleanupStack}};
	my $cmdL      = $this->{cmdL};
	my $kiwi      = $this->{kiwi};
	my $system    = $this->{system};
	my %deviceMap = %{$map};
	my %lvmparts  = %{$parts};
	my $VGroup    = $this->{lvmgroup};
	my $fsopts    = $cmdL -> getFilesystemOptions();
	my $inoderatio= $fsopts->[2];
	my %newmap;
	my $status;
	my $result;
	$status = qxx ("vgremove --force $VGroup 2>&1");
	$status = qxx ("test -d /dev/$VGroup && rm -rf /dev/$VGroup 2>&1");
	$status = qxx ("pvcreate $deviceMap{root} 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating physical extends: $status");
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	$status = qxx ("vgcreate $VGroup $deviceMap{root} 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating volume group: $status");
		$kiwi -> failed ();
		$this -> cleanStack ();
		return;
	}
	push @cStack,"vgchange -an $VGroup";
	$this->{cleanupStack} = \@cStack;
	if (($syszip) || ($haveSplit)) {
		$status = qxx ("lvcreate -L $syszip -n LVComp $VGroup 2>&1");
		$result = $? >> 8;
		$status.= qxx ("lvcreate -l +100%FREE -n LVRoot $VGroup 2>&1");
		$result+= $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Logical volume(s) setup failed: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		%newmap = $this -> setLVMDeviceMap (
			$VGroup,$device,["LVComp","LVRoot"]
		);
	} else {
		if (%lvmparts) {
			my %ihash = ();
			foreach my $name (keys %lvmparts) {
				my $pname  = $name; $pname =~ s/_/\//g;
				my $lvsize = $lvmparts{$name}->[2];
				my $lvdev  = "/dev/$VGroup/LV$name";
				my $inodes = 2 * int ($lvsize * 1048576 / $inoderatio);
				if ($inodes < $this->{gdata}->{FSMinInodes}) {
					$inodes = $this->{gdata}->{FSMinInodes};
				}
				$ihash{$lvdev} = $inodes;
				$status = qxx ("lvcreate -L $lvsize -n LV$name $VGroup 2>&1");
				$result = $? >> 8;
				if ($result != 0) {
					last;
				}
			}
			$this->{deviceinodes} = \%ihash;
		}
		if ($result == 0) {
			$status = qxx ("lvcreate -l +100%FREE -n LVRoot $VGroup 2>&1");
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Logical volume(s) setup failed: $status");
			$kiwi -> failed ();
			$this -> cleanStack ();
			return;
		}
		%newmap = $this -> setLVMDeviceMap (
			$VGroup,$device,["LVRoot"]
		);
	}
	return %newmap;
}

#==========================================
# deleteVolumeGroup
#------------------------------------------
sub deleteVolumeGroup {
	my $this   = shift;
	my $lvm    = $this->{lvm};
	my $VGroup = $this->{lvmgroup};
	if ($lvm) {
		qxx ("vgremove --force $VGroup 2>&1");
		qxx ("test -d /dev/$VGroup && rm -rf /dev/$VGroup 2>&1");
	}
	return $this;
}

#==========================================
# makeLabel
#------------------------------------------
sub makeLabel {
	# ...
	# grub handles spaces as "_", so we replace
	# each space with an underscore
	# ----
	my $this  = shift;
	my $label = shift;
	my $loader= $this->{loader};
	if ($loader ne "grub2") {
		$label =~ s/ /_/g;
	}
	return $label;
}

#==========================================
# quoteLabel
#------------------------------------------
sub quoteLabel {
	my $this  = shift;
	my $label = shift;
	return KIWIConfigure::quoteshell ($label);
}

#==========================================
# luksResize
#------------------------------------------
sub luksResize {
	my $this   = shift;
	my $source = shift;
	my $name   = shift;
	my $kiwi   = $this->{kiwi};
	my $cipher = $this->{gdata}->{LuksCipher};
	my $status;
	my $result;
	my $hald;
	#==========================================
	# open luks device
	#------------------------------------------
	if ($cipher) {
		$status = qxx (
			"echo $cipher | cryptsetup luksOpen $source $name 2>&1"
		);
	} else {
		$status = qxx ("cryptsetup luksOpen $source $name 2>&1");
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't open luks device: $status");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# resize luks header
	#------------------------------------------
	$this->{luks} = $name;
	$status = qxx ("cryptsetup resize $name");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't resize luks device: $status");
		$kiwi -> failed ();
		$this -> luksClose();
		return;
	}
	#==========================================
	# return mapped device name
	#------------------------------------------
	return "/dev/mapper/".$name;
}

#==========================================
# luksClose
#------------------------------------------
sub luksClose {
	my $this = shift;
	if ($this->{luks}) {
		qxx ("cryptsetup luksClose $this->{luks} 2>&1");
		undef $this->{luks};
	}
	return $this;
}

#==========================================
# umountDevice
#------------------------------------------
sub umountDevice {
	# ...
	# umount all mounted filesystems from the given
	# storage device. The functions searches the
	# /proc/mounts table and umounts all corresponding
	# mount entries
	# ----
	my $this = shift;
	my $disk = shift;
	my $kiwi = $this->{kiwi};
	my $MOUNTS;
	if (! defined $disk) {
		$kiwi -> loginfo ("umountDevice: no disk prefix provided, skipped");
		return;
	}
	if (! open ($MOUNTS, '<', '/proc/mounts')) {
		$kiwi -> loginfo ("umountDevice: failed to open proc/mounts: $!");
		return;
	}
	my @mounts = <$MOUNTS>; close $MOUNTS;
	for my $mount (@mounts) {
		if ($mount =~ /^$disk/) {
			my ($device, $mountpoint, $rest) = split / /, $mount, 3;
			qxx ("umount $device 2>&1");
		}
	}
	return $this;
}

#==========================================
# setupFilesystem
#------------------------------------------
sub setupFilesystem {
	# ...
	# create filesystem according to selected type
	# ----
	my $this   = shift;
	my $fstype = shift;
	my $device = shift;
	my $name   = shift;
	my $bootp  = shift;
	my $inodes = $this->{deviceinodes};
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $cmdL   = $this->{cmdL};
	my %type   = ();
	if ($xml) {
		%type = %{$xml->getImageTypeAndAttributes_legacy()};
	} else {
		$type{fsnocheck} = 'true';
	}
	my %FSopts = KIWIGlobals -> instance() -> checkFSOptions(
		@{$cmdL -> getFilesystemOptions()}
	);
	my $iorig  = $this->{inodes};
	my $result;
	my $status;
	if (($inodes) && ($inodes->{$device})) {
		if ($inodes->{$device} ne "no-opts") {
			$this->{inodes} = $inodes->{$device};
		} else {
			undef $this->{inodes};
		}
	}
	SWITCH: for ($fstype) {
		/^ext[234]/     && do {
			$kiwi -> info ("Creating $_ $name filesystem");
			my $fsopts = $FSopts{$_};
			if (! $fsopts) {
				$fsopts = '';
			}
			my $fstool = "mkfs.".$fstype;
			if ($this->{inodes}) {
				$fsopts.= " -N $this->{inodes}";
			}
			if ($bootp) {
				$fsopts.= " -L '".$bootp."'";
				$type{fsnocheck} = 'true';
			}
			my $tuneopts = '';
			if (($type{fsnocheck}) && ($type{fsnocheck} eq "true")) {
				$tuneopts = "-c 0 -i 0 ";
			}
			if ($FSopts{extfstune}) {
				$tuneopts .= $FSopts{extfstune};
			}
			$status = qxx ("$fstool $fsopts $device 2>&1");
			$result = $? >> 8;
			if (!$result && $tuneopts) {
				$status .= qxx ("/sbin/tune2fs $tuneopts $device 2>&1");
				$result = $? >> 8;
			}
			last SWITCH;
		};
		/^fat16|fat32/  && do {
			my $fstool = 'mkdosfs';
			my $fsopts = '';
			if ($fstype eq 'fat16') {
				$kiwi -> info ("Creating DOS [Fat16] filesystem");
				$fsopts.= " -F 16";
			} else {
				$kiwi -> info ("Creating DOS [Fat32] filesystem");
				$fsopts.= " -F 32";
			}
			if ($bootp) {
				$fsopts.= " -n '".$bootp."'";
			}
			$status = qxx ("$fstool $fsopts $device 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		/^reiserfs/     && do {
			$kiwi -> info ("Creating reiserfs $name filesystem");
			my $fsopts = $FSopts{reiserfs};
			if (! $fsopts) {
				$fsopts = '';
			}
			$fsopts.= " -f";
			$status = qxx (
				"/sbin/mkreiserfs $fsopts $device 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		/^btrfs/        && do {
			$kiwi -> info ("Creating btrfs $name filesystem");
			my $fsopts = $FSopts{btrfs};
			if (! $fsopts) {
				$fsopts = '';
			}
			$status = qxx (
				"/sbin/mkfs.btrfs $fsopts $device 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		/^xfs/          && do {
			$kiwi -> info ("Creating xfs $name filesystem");
			my $fsopts = $FSopts{xfs};
			if (! $fsopts) {
				$fsopts = '';
			}
			$status = qxx (
				"/sbin/mkfs.xfs $fsopts $device 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported filesystem type: $fstype");
		$kiwi -> failed ();
		$this->{inodes} = $iorig;
		return;
	};
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create $fstype filesystem: $status");
		$kiwi -> failed ();
		$this->{inodes} = $iorig;
		return;
	}
	$kiwi -> done();
	$this->{inodes} = $iorig;
	return $this;
}

#==========================================
# addBootNext
#------------------------------------------
sub addBootNext {
	# ...
	# Write boot program that boots the firsts drive that
	# does _not_ have our mbr id. The boot program source which
	# creates $bootnext below is added in the git repo below
	# tools/bootnext
	# ---
	my $this = shift;
	my $file = shift;
	my $id   = shift;
	my $bootnext =
		"\x8c\xc8\x8e\xd0\x31\xe4\x8e\xd8\x8e\xc0\xfc\xfb\xbe\x00\x7c\xbf" .
		"\x00\x60\xb9\x00\x01\xf3\xa5\xea\x1c\x60\x00\x00\xb4\x08\x31\xff" .
		"\xb2\x80\xcd\x13\x73\x02\xb2\x01\x80\xfa\x01\xb0\x80\x10\xc2\x88" .
		"\x16\x29\x61\xa2\x2a\x61\xe8\x8b\x00\x73\x10\xa0\x2a\x61\x40\x3a" .
		"\x06\x29\x61\x72\xee\xbe\x2d\x61\xe9\xb3\x00\x80\x3e\x2a\x61\x80" .
		"\x74\x03\xe8\x07\x00\xb2\x80\xea\x00\x7c\x00\x00\xa1\x13\x04\x48" .
		"\xa3\x13\x04\xc1\xe0\x06\x2d\x00\x06\x66\x8b\x16\x4c\x00\x66\x89" .
		"\x16\x25\x61\x50\x68\x89\x60\x66\x8f\x06\x4c\x00\x50\x07\xbe\x00" .
		"\x60\x89\xf7\xb9\x00\x01\xf3\xa5\xc3\x9c\x2e\x88\x16\x2b\x61\x2e" .
		"\x88\x26\x2c\x61\x2e\x3a\x16\x2a\x61\x75\x04\xb2\x80\xeb\x0a\x80" .
		"\xfa\x80\x75\x05\x2e\x8a\x16\x2a\x61\x2e\xff\x1e\x25\x61\x50\x9f" .
		"\x67\x88\x64\x24\x06\x58\x2e\x80\x3e\x2c\x61\x08\x74\x05\x2e\x8a" .
		"\x16\x2b\x61\xcf\xe8\x10\x00\x72\x0d\x66\xa1\xb8\x61\x66\x3b\x06" .
		"\xb8\x7d\xf9\x74\x01\xf8\xc3\xb8\x01\x02\xb9\x01\x00\xb6\x00\x8a" .
		"\x16\x2a\x61\xbb\x00\x7c\xcd\x13\x72\x13\x66\x83\x3e\x00\x7c\x00" .
		"\xf9\x74\x0a\x81\x3e\xfe\x7d\x55\xaa\xf9\x75\x01\xf8\xc3\xe8\x15" .
		"\x00\xbe\x44\x61\xe8\x0f\x00\xb4\x00\xcd\x16\xbe\x41\x61\xe8\x05" .
		"\x00\xcd\x19\xf4\xeb\xfd\xac\x08\xc0\x74\x09\xbb\x07\x00\xb4\x0e" .
		"\xcd\x10\xeb\xf2\xc3\x00\x00\x00\x00\x00\x00\x00\x00\x4e\x6f\x20" .
		"\x6f\x70\x65\x72\x61\x74\x69\x6e\x67\x20\x73\x79\x73\x74\x65\x6d" .
		"\x2e\x0d\x0a\x00\x0a\x50\x72\x65\x73\x73\x20\x61\x20\x6b\x65\x79" .
		"\x20\x74\x6f\x20\x72\x65\x62\x6f\x6f\x74\x2e\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" .
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x55\xaa";

	# we really need a valid id
	return unless $id;

	substr $bootnext, 0x1b8, 4, pack("V", $id);

	my $bn = FileHandle -> new();
	if (! $bn -> open (">$file")) {
		return;
	}
	print $bn $bootnext;
	$bn -> close();
	return $this;
}

#==========================================
# diskOffset
#------------------------------------------
sub diskOffset {
	# ...
	# find the offset to the start of the first partition
	# ---
	my $this = shift;
	my $disk = shift;
	my $offset;
	my @table = qx (parted -m $disk unit s print 2>&1);
	chomp @table;
	foreach my $entry (@table) {
		if ($entry =~ /^[1-4]:/) {
			my @items = split (/:/,$entry);
			$offset = $items[1];
			chop $offset;
			last;
		}
	}
	if (! $offset) {
		return;
	}
	return $offset;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	my $dirs = $this->{tmpdirs};
	foreach my $dir (@{$dirs}) {
		qxx ("rm -rf $dir 2>&1");
	}
	return $this -> cleanStack ();
}

#==========================================
# Private methods
#------------------------------------------
#==========================================
# __getBootSize
#------------------------------------------
sub __getBootSize {
	# ...
	# set minimum boot size or the specified value from the
	# XML description. The function returns the size in
	# M-Bytes
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my %type   = %{$xml->getImageTypeAndAttributes_legacy()};
	my $needMB = 200;
	my $wantMB = 200;
	if ($type{bootpartsize}) {
		$wantMB = $type{bootpartsize};
	}
	if ($wantMB > $needMB) {
		$needMB = $wantMB;
	} else {
		$kiwi -> loginfo ("Specified boot space of $wantMB MB is too small\n");
		$kiwi -> loginfo ("Using default value of $needMB MB\n");
	}
	$kiwi -> info ("Set boot partition space to: ".$needMB."M\n");
	return $needMB;
}

#==========================================
# __expandFS
#------------------------------------------
sub __expandFS {
	# ...
	# Expand the file system to its maximum size
	# ---
	my $this      = shift;
	my $fsType    = shift;
	my $diskType  = shift;
	my $mapper    = shift;
	my $kiwi      = $this->{kiwi};
	my $locator   = KIWILocator -> instance();
	my $result    = 1;
	my $status;
	$kiwi->loginfo ("Resize Operation: Device: $mapper\n");
	$kiwi->loginfo ("Resize Operation: Image Disk Type: $diskType\n");
	$kiwi->loginfo ("Resize Operation: Filesystem Type: $fsType\n");
	SWITCH: for ($fsType) {
		/^ext\d/    && do {
			$kiwi -> info ("Resizing $diskType $fsType filesystem");
			my $resize = $locator -> getExecPath ('resize2fs');
			if (! $resize) {
				$kiwi -> error ('Could not locate resize2fs');
				$kiwi -> failed ();
				return;
			}
			$status = qxx ("$resize -f -F -p $mapper 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		/^reiserfs/ && do {
			$kiwi -> info ("Resizing $diskType $fsType filesystem");
			my $resize = $locator -> getExecPath ('resize_reiserfs');
			if (! $resize) {
				$kiwi -> error ('Could not locate resize_reiserfs');
				$kiwi -> failed ();
				return;
			}
			$status = qxx ("$resize $mapper 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		/^btrfs/    && do {
			$kiwi -> info ("Resizing $diskType $fsType filesystem");
			my $bfsctl = $locator -> getExecPath('btrfsctl');
			if (! $bfsctl) {
				$kiwi -> error ('Could not locate btrfsctl');
				$kiwi -> failed ();
				return;
			}
			my $bctl = "$bfsctl -r max /mnt";
			$status = qxx ("
					mount $mapper /mnt && $bctl; umount /mnt 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		/^xfs/      && do {
			$kiwi -> info ("Resizing $diskType $fsType filesystem");
			my $xfsGrow = $locator -> getExecPath('xfs_growfs');
			if (! $xfsGrow) {
				$kiwi -> error ('Could not locate xfs_grow');
				$kiwi -> failed ();
				return;
			}
			$status = qxx ("
					mount $mapper /mnt && $xfsGrow /mnt; umount /mnt 2>&1"
			 );
			$result = $? >> 8;
			last SWITCH;
		};
		$kiwi->loginfo ("Resize Operation: no resize\n");
		$result = 0;
	};
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't resize $fsType filesystem $status");
		$kiwi -> failed ();
		$this -> luksClose();
		return;
	}
	$this -> luksClose();
	if ($status) {
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# __initDiskSize
#------------------------------------------
sub __initDiskSize {
	# ...
	# setup initial disk size value
	# ---
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $minBytes  = shift;
	my $cmdlsize  = shift;
	my $XMLBytes  = shift;
	my $vmsize    = 0;
	my $vmmbyte   = 0;
	#==========================================
	# Store size values from cmdline and XML
	#------------------------------------------
	$this->{cmdlsize} = $cmdlsize;
	$this->{XMLBytes} = $XMLBytes;
	#==========================================
	# Create vmsize MB string and vmmbyte value
	#------------------------------------------
	$vmsize  = $minBytes / 1048576;
	$vmsize  = sprintf ("%.0f", $vmsize);
	$vmmbyte = $vmsize;
	$vmsize  = $vmsize."M";
	$kiwi -> loginfo (
		"Starting with disk size: $vmsize\n"
	);
	$this->{vmmbyte} = $vmmbyte;
	$this->{vmsize}  = $vmsize;
	return $this;
}

#==========================================
# __updateDiskSize
#------------------------------------------
sub __updateDiskSize {
	# ...
	# increase the current virtual disk size value
	# by the specified value. value is treated as
	# number in MB
	# ---
	my $this   = shift;
	my $addMB  = shift;
	my $kiwi   = $this->{kiwi};
	my $vmsize = $this->{vmmbyte} + $addMB;
	$vmsize = sprintf ("%.0f", $vmsize);
	$this->{vmmbyte} = $vmsize;
	$vmsize = $vmsize."M";
	$this->{vmsize}  = $vmsize;
	$kiwi->loginfo (
		"Increasing disk size by ".$addMB."M to: ".$vmsize."\n"
	);
	return $this;
}

#==========================================
# __updateCustomDiskSize
#------------------------------------------
sub __updateCustomDiskSize {
	# ...
	# if a custom disk size is set via the commandline
	# or the <size> element from XML, this function uses
	# the custom value if it is smaller than the currently
	# calculcated disk size value
	# ---
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $cmdlsize  = $this->{cmdlsize};
	my $XMLBytes  = $this->{XMLBytes};
	my $cmdlBytes = 0;
	my $vmsize    = 0;
	my $vmmbyte   = 0;
	my $reqBytes  = 0;
	#===========================================
	# turn optional size from cmdline into bytes
	#-------------------------------------------
	if (($cmdlsize) && ($cmdlsize =~ /^(\d+)([MG])$/i)) {
		my $value= $1;
		my $unit = $2;
		if ($unit eq "G") {
			# convert GB to MB...
			$value *= 1024;
		}
		# convert MB to Byte
		$cmdlBytes = $value * 1048576;
	}
	#===========================================
	# adapt req size according to cmdline or XML
	#-------------------------------------------
	if ($cmdlBytes > 0) {
		$reqBytes = $cmdlBytes;
	} elsif (("$XMLBytes" ne "auto") && ($XMLBytes > 0)) {
		$reqBytes = $XMLBytes;
	}
	if ($reqBytes == 0) {
		return $this;
	}
	my $reqMBytes = int ($reqBytes / 1048576);
	if ($reqMBytes < $this->{vmmbyte}) {
		$kiwi -> warning (
			"given disk size is smaller than calculated size"
		);
		$kiwi -> skipped ();
		return $this;
	}
	#==========================================
	# Create vmsize MB string and vmmbyte value
	#------------------------------------------
	$vmmbyte = $reqMBytes;
	$vmsize  = $reqMBytes."M";
	$kiwi -> loginfo (
		"Using custom disk size: $vmsize\n"
	);
	$this->{vmmbyte} = $vmmbyte;
	$this->{vmsize}  = $vmsize;
	return $this;
}

#==========================================
# __getPartID
#------------------------------------------
sub __getPartID {
	# ...
	# try to find the partition number which references
	# the provided flag like "boot" or "lvm"
	# ---
	my $this = shift;
	my $disk = shift;
	my $flag = shift;
	my $fd   = FileHandle -> new();
	if ($fd -> open ("parted -m $disk print | cut -f1,7 -d:|")) {
		while (my $line = <$fd>) {
			if ($line =~ /^(\d):[ ,]*$flag/) {
				return $1;
			}
		}
		$fd -> close();
	}
	return 0;
}

#==========================================
# __getPartBase
#------------------------------------------
sub __getPartBase {
	# ...
	# find the correct partition device for a
	# given disk device by checking for the first
	# two partitions
	# ---
	my $this = shift;
	my $disk = shift;
	my $devcopy = $disk;
	my $devbase = basename $devcopy;
	my @checklist = (
		"/dev/mapper/".$devbase."p1",
		"/dev/mapper/".$devbase."p2",
		"/dev/".$devbase."p1",
		"/dev/".$devbase."p2",
		"/dev/".$devbase."1",
		"/dev/".$devbase."2"
	);
	foreach my $device (@checklist) {
		if (-b $device) {
			chop $device;
			return $device;
		}
	}
	return;
}

#==========================================
# __getPartDevice
#------------------------------------------
sub __getPartDevice {
	# ...
	# find the correct partition device according
	# to the disk device and partition number
	# ---
	my $this = shift;
	my $disk = shift;
	my $part = shift;
	my $devcopy = $disk;
	my $devbase = basename $devcopy;
	my @checklist = (
		"/dev/mapper/".$devbase."p".$part,
		"/dev/".$devbase."p".$part,
		"/dev/".$devbase.$part
	);
	foreach my $device (@checklist) {
		if (-b $device) {
			return $device;
		}
	}
	return;
}

1;
