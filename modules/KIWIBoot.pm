#================
# FILE          : KIWIBoot.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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

#==========================================
# Modules
#------------------------------------------
use strict;
use Carp qw (cluck);
use KIWILog;
use KIWIIsoLinux;
use FileHandle;
use File::Basename;
use File::Spec;
use Math::BigFloat;
use KIWILocator;
use KIWIQX;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create a new KIWIBoot object which is used to create bootable
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
	my $kiwi   = shift;
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
	# create log object if not done
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# check initrd file parameter
	#------------------------------------------
	if ((defined $initrd) && (! -f $initrd)) {
		$kiwi -> error  ("Couldn't find initrd file: $initrd");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# check for split system
	#------------------------------------------
	if (-f "$system/rootfs.tar") {
		$kiwi -> error ("Can't use split root tree, run create first");
		$kiwi -> failed ();
		return undef;
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
			my %fsattr = $main::global -> checkFileSystem ($system);
			if (($fsattr{readonly}) || ($fsattr{type} eq "luks")) {
				$syszip = $main::global -> isize ($system);
			} else {
				$syszip = 0;
			}
		} elsif (! -d $system) {
			$kiwi -> error  ("Couldn't find image file/directory: $system");
			$kiwi -> failed ();
			return undef;
		} elsif (-f "$system/kiwi-root.cow") {
			#==========================================
			# Check for overlay structure
			#------------------------------------------
			$this->{overlay} = new KIWIOverlay ($kiwi,$system);
			if (! $this->{overlay}) {
				return undef;
			}
			$system = $this->{overlay} -> mountOverlay();
			if (! -d $system) {
				return undef;
			}
		}
	}
	#==========================================
	# check if we got the tree or image file
	#------------------------------------------
	if (-d $system) {
		$haveTree = 1;
	}
	#==========================================
	# compressed initrd used...
	#------------------------------------------
	if ($initrd =~ /\.gz$/) {
		$zipped = 1;
	}
	#==========================================
	# find kernel file
	#------------------------------------------
	$kernel = $initrd;
	if ($kernel =~ /gz$/) {
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
		return undef;
	}
	#==========================================
	# check if Xen system is used
	#------------------------------------------
	$isxen = 0;
	$xengz = $initrd;
	$xengz =~ s/\.gz$//;
	$xengz =~ s/\.splash$//;
	foreach my $xen (glob ("$xengz*xen*.gz")) {
		$isxen = 1;
		$xengz = $xen;
		last;
	}
	#==========================================
	# create tmp dir for operations
	#------------------------------------------
	$tmpdir = qxx ("mktemp -q -d /tmp/kiwiboot.XXXXXX"); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$loopdir = qxx ("mktemp -q -d /tmp/kiwiloop.XXXXXX"); chomp $loopdir;
	$result  = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $loopdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Store object data (1)
	#------------------------------------------
	$this->{gdata}    = $main::global -> getGlobals();
	$this->{tmpdir}   = $tmpdir;
	$this->{loopdir}  = $loopdir;
	$this->{lvmgroup} = $vgroup;
	$this->{tmpdirs}  = [ $tmpdir, $loopdir ];
	$this->{haveTree} = $haveTree;
	$this->{kiwi}     = $kiwi;
	$this->{bootsize} = 100;

	#==========================================
	# setup pointer to XML configuration
	#------------------------------------------
	if (defined $system) {
		if (-d $system) {
			my $locator = new KIWILocator($kiwi);
			my $controlFile = $locator -> getControlFile ($system."/image");
			my $validator = new KIWIXMLValidator (
				$kiwi,$controlFile,
				$this->{gdata}->{Revision},
				$this->{gdata}->{Schema},
				$this->{gdata}->{SchemaCVT}
			);
			my $isValid = $validator ? $validator -> validate() : undef;
			if (! $isValid) {
				return undef;
			}
			$xml = new KIWIXML (
				$kiwi,$system."/image",$cmdL->getBuildType(),$profile,$cmdL
			);
			#==========================================
			# Determine size of /boot area
			#------------------------------------------
			if (defined $initrd) {
				$this ->{bootsize} = $this -> __getBootSize ($system);
			}
		} else {
			my %fsattr = $main::global -> checkFileSystem ($system);
			if ((! $fsattr{type}) || ($fsattr{type} eq "auto")) {
				#==========================================
				# bind $system to loop device
				#------------------------------------------
				$kiwi -> info ("Binding disk to loop device");
				if (! $this -> bindDiskDevice($system)) {
					$kiwi -> failed ();
					return undef;
				}
				$kiwi -> done();
				#==========================================
				# setup device mapper
				#------------------------------------------
				$kiwi -> info ("Setup device mapper for partition access");
				if (! $this -> bindDiskPartitions ($this->{loop})) {
					$kiwi -> failed ();
					$this -> cleanLoop ();
					return undef;
				}
				$kiwi -> done();
				#==========================================
				# find partition and mount it
				#------------------------------------------
				my $sdev = $this->{bindloop}."1";
				#==========================================
				# check for activated volume group
				#------------------------------------------
				$sdev = $this -> checkLVMbind ($sdev,$this->{loop});
				#==========================================
				# perform mount call
				#------------------------------------------
				if (! $main::global -> mount($sdev, $tmpdir)) {
					$kiwi -> error ("System image mount failed: $status");
					$kiwi -> failed ();
					$this -> cleanLoop ();
					return undef;
				}
				#==========================================
				# read disk image XML description
				#------------------------------------------
				my $locator = new KIWILocator($kiwi);
				my $controlFile = $locator -> getControlFile ($tmpdir."/image");
				my $validator = new KIWIXMLValidator (
					$kiwi,$controlFile,
					$this->{gdata}->{Revision},
					$this->{gdata}->{Schema},
					$this->{gdata}->{SchemaCVT}
				);
				my $isValid = $validator ? $validator -> validate() : undef;
				if (! $isValid) {
					$this -> cleanLoop ();
					return undef;
				}
				$xml = new KIWIXML (
					$kiwi,$tmpdir."/image",$cmdL->getBuildType(),$profile,$cmdL
				);
				#==========================================
				# Determine size of /boot area
				#------------------------------------------
				if (defined $initrd) {
					$this ->{bootsize} = $this -> __getBootSize ($tmpdir);
				}
				#==========================================
				# clean up
				#------------------------------------------
				$this -> cleanLoop ();
			} else {
				#==========================================
				# loop mount system image
				#------------------------------------------
				if (! $main::global -> mount ($system,$tmpdir)) {
					return undef;
				}
				#==========================================
				# check for split type
				#------------------------------------------
				if (-f "$tmpdir/rootfs.tar") {
					$cmdL -> setBuildType ("split");
					$haveSplit = 1;
				}
				#==========================================
				# read disk image XML description
				#------------------------------------------
				my $locator = new KIWILocator($kiwi);
				my $controlFile = $locator -> getControlFile ($tmpdir."/image");
				my $validator = new KIWIXMLValidator (
					$kiwi,$controlFile,
					$this->{gdata}->{Revision},
					$this->{gdata}->{Schema},
					$this->{gdata}->{SchemaCVT}
				);
				my $isValid = $validator ? $validator -> validate() : undef;
				if (! $isValid) {
					$main::global -> umount();
					return undef;
				}
				$xml = new KIWIXML (
					$kiwi,$tmpdir."/image",$cmdL->getBuildType(),$profile,$cmdL
				);
				#==========================================
				# Determine size of /boot area
				#------------------------------------------
				if (defined $initrd) {
					$this ->{bootsize} = $this -> __getBootSize ($tmpdir);
				}
				#==========================================
				# clean up
				#------------------------------------------
				$main::global -> umount();
			}
		}
		if (! defined $xml) {
			return undef;
		}
	}
	#==========================================
	# find Xen domain configuration
	#------------------------------------------
	if ($isxen && defined $xml) {
		my %xenc = $xml -> getXenConfig();
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
		my $kernelSize   = $main::global -> isize ($kernel);
		my $initrdSize   = $main::global -> isize ($initrd);
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
			$sizeBytes = $main::global -> isize ($system);
			$sizeBytes+= $kernelSize;
			$sizeBytes+= $initrdSize;
			$sizeBytes+= $spare;
		}
		#==========================================
		# Store optional size setup from XML
		#------------------------------------------
		my $sizeXMLAddBytes = $xml -> getImageSizeAdditiveBytes();
		if ($sizeXMLAddBytes) {
			$sizeXMLBytes = $sizeBytes + $sizeXMLAddBytes;
		} else {
			$sizeXMLBytes = $xml -> getImageSizeBytes();
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
			$this->{inodes} = int ($this->{vmmbytes} / $inoderatio);
			$kiwi -> loginfo (
				"Using ".$this->{inodes}." inodes for the root filesystem\n"
			);
		}
	}
	#==========================================
	# round compressed image size
	#------------------------------------------
	if ($syszip) {
		$syszip = $syszip / 1048576;
		$syszip = sprintf ("%.0f", $syszip);
	}
	#==========================================
	# Store a disk label ID for this object
	#------------------------------------------
	$this->{mbrid} = $main::global -> getMBRDiskLabel (
		$cmdL -> getMBRID()
	);
	#==========================================
	# find system architecture
	#------------------------------------------
	my $arch = qxx ("uname -m"); chomp $arch;
	#==========================================
	# check framebuffer vga value
	#------------------------------------------
	if (defined $xml) {
		my %type = %{$xml->getImageTypeAndAttributes()};
		if ($type{vga}) {
			$vga = $type{vga};
		}
		if ($type{luks}) {
			$main::global -> setGlobals ("LuksCipher",$type{luks});
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
		return undef;
	}
	if ($zipped) {
		if ($isxen) {
			# deflate/inflate initrd to make xen happy
			my $irdunc = $initrd;
			$irdunc =~ s/\.gz//;
			qxx ("$zipper -d $initrd && $zipper $irdunc");
		}
		$status = qxx ( "cp $initrd $tmpdir/boot/$iname 2>&1" );
	} else {
		$status = qxx ( "cat $initrd | $zipper > $tmpdir/boot/$iname" );
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing initrd: $!");
		$kiwi -> failed ();
		return undef;
	}
	$status = qxx ( "cp $kernel $tmpdir/boot/$lname 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing kernel: $!");
		$kiwi -> failed ();
		return undef;
	}
	if (($isxen) && ($xendomain eq "dom0")) {
		$status = qxx ( "cp $xengz $tmpdir/boot/$xname 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing Xen dom0 kernel: $!");
			$kiwi -> failed ();
			return undef;
		}
	}
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
					if (open (FD,$serial)) {
						$serial = <FD>;
						chomp $serial;
						close FD;
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
				if (! open (FD,$isremovable)) {
					next;
				}
				$isremovable = <FD>; close FD;
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
	my $md5name   = $system;
	my $destdir   = dirname ($initrd);
	my $gotsys    = 1;
	my $volid     = "-V \"KIWI CD/DVD Installation\"";
	my $bootloader;
	if ($arch =~ /ppc|ppc64/) {
		$bootloader = "lilo";
	} else {
		$bootloader = "grub";
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
	if (-b $system) {
		$haveDiskDevice = $system;
		$version = $xml -> getImageVersion();
		$system  = $xml -> getImageName();
		$system  = $destdir."/".$system.".".$arch."-".$version.".raw";
		$md5name = $system;
		$this->{system} = $system;
	}
	#==========================================
	# read MBR disk label
	#------------------------------------------
	if (! open $FD,"dd 2>/dev/null if=$system bs=1 count=4 skip=\$((0x1b8))|") {
		$kiwi -> error  ("Couldn't open: $system: $!");
		$kiwi -> failed ();
		return undef;
	}
	my $mbrid = sprintf "0x%08x", unpack "V", <$FD>;
	if (($this->{mbrid}) && ($mbrid ne $this->{mbrid})) {
		$this->{mbrid} = $mbrid;
	}
	close $FD;
	#==========================================
	# read config XML attributes
	#------------------------------------------
	if (defined $xml) {
		%type = %{$xml->getImageTypeAndAttributes()};
	}
	#==========================================
	# check for volume id
	#------------------------------------------
	if ((%type) && ($type{volid})) {
		$volid = " -V \"$type{volid}\"";
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
		return undef;
	}
	$this->{tmpdir} = $tmpdir;
	push @{$this->{tmpdirs}},$tmpdir;
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# check if system image is given
	#------------------------------------------
	if (! $system) {
		$system = $initrd;
		$gotsys = 0;
	}
	#==========================================
	# check image type
	#------------------------------------------
	if ($gotsys) {
		#==========================================
		# build label from xml data
		#------------------------------------------
		$this->{bootlabel} = $xml -> getImageDisplayName();
		if (! $haveDiskDevice) {
			#==========================================
			# bind $system to loop device
			#------------------------------------------
			$kiwi -> info ("Binding disk to loop device");
			if (! $this -> bindDiskDevice($system)) {
				$kiwi -> failed ();
				return undef;
			}
			$kiwi -> done();
			#==========================================
			# setup device mapper
			#------------------------------------------
			$kiwi -> info ("Setup device mapper for partition access");
			if (! $this -> bindDiskPartitions ($this->{loop})) {
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
			$kiwi -> done();
		} else {
			$kiwi -> info ("Using disk device: $haveDiskDevice");
			$this->{loop}     = $haveDiskDevice;
			$this->{bindloop} = $haveDiskDevice;
			qxx ("vgchange -a y 2>&1");
			$kiwi -> done();
		}
		#==========================================
		# find partition to check
		#------------------------------------------
		my $sdev;
		if ($arch =~ /ppc|ppc64/) {
			$sdev = $this->{bindloop}."2";
		} else {
			$sdev = $this->{bindloop}."1";
			if (! -e $sdev) {
				$sdev = $this->{bindloop}."2";
			}
		}
		#==========================================
		# check for activated volume group
		#------------------------------------------
		$sdev = $this -> checkLVMbind ($sdev,$this->{loop});
		#==========================================
		# perform mount call
		#------------------------------------------
		if (! $main::global -> mount ($sdev, $tmpdir)) {
			$kiwi -> error ("Failed to mount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$this -> cleanLoop();
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
		if ($haveDiskDevice) {
			$status = qxx ("cat $haveDiskDevice > $system");
		}
		$status = qxx (
			"mksquashfs $system $md5name $system.squashfs -no-progress 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to compress system image: $status");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
		$system = $system.".squashfs";
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		return undef;
	}
	#==========================================
	# Create CD structure
	#------------------------------------------
	$this->{initrd} = $initrd;
	if (! $this -> createBootStructure()) {
		$this->{initrd} = $oldird;
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader,"iso")) {
		return undef;
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
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$title)) {
		return undef;
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
			return undef;
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
			return undef;
		} else {
			$kiwi -> loginfo ("config-cdroot.sh: $status");
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy system image if given
	#------------------------------------------
	if ($gotsys) {
		if (! open (FD,">$tmpdir/config.isoclient")) {
			$kiwi -> error  ("Couldn't create CD install flag file");
			$kiwi -> failed ();
			return undef;
		}
		print FD "IMAGE='".$namecd."'\n";
		close FD;
		$kiwi -> info ("Importing system image: $system");
		$status = qxx ("mv $system $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			return undef;
		}
		$system =~ s/\.squashfs$//;
		$kiwi -> done();
	}
	#==========================================
	# Create an iso image from the tree
	#------------------------------------------
	$kiwi -> info ("Creating ISO image...");
	my $name = $system;
	if ($gotsys) {
		$name =~ s/raw$/iso/;
	} else {
		$name =~ s/gz$/iso/;
	}
	my $base;
	my $opts;
	if ($bootloader eq "grub") {
		# let isolinux run grub second stage...
		$base = "-R -J -f -b boot/grub/stage2 -no-emul-boot $volid";
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
		$base = "-R -J -f -b boot/loader/isolinux.bin -no-emul-boot $volid";
		$opts = "-boot-load-size 4 -boot-info-table -udf -allow-limited-size ";
		$opts.= "-pad -joliet-long";
	} elsif ($bootloader eq "lilo") {
		$base = "-r";
		$opts = "-U -chrp-boot -pad -joliet-long";
	} else {
		# don't know how to use this bootloader together with isolinux
		$kiwi -> failed ();
		$kiwi -> error  ("Bootloader not supported for CD inst: $bootloader");
		$kiwi -> failed ();
		return undef;
	}
	my $wdir = qxx ("pwd"); chomp $wdir;
	if ($name !~ /^\//) {
		$name = $wdir."/".$name;
	}
	my $iso = new KIWIIsoLinux (
		$kiwi,$tmpdir,$name,undef,"checkmedia",$this->{cmdL}
	);
	if (! defined $iso) {
		return undef;
	}
	my $tool= $iso -> getTool();
	if ($bootloader =~ /(sys|ext)linux/) {
		$iso -> createISOLinuxConfig ("/boot");
	}
	$status = qxx ("cd $tmpdir && $tool $base $opts -o $name . 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating ISO image: $status");
		$kiwi -> failed ();
		$iso  -> cleanISO ();
		return undef;
	}
	$kiwi -> done ();
	if ($bootloader =~ /(sys|ext)linux/) {
		if (! $iso->createHybrid($this->{mbrid})) {
			return undef;
		}
	}
	if ($arch !~ /ppc|ppc64/) {
		if (! $iso -> relocateCatalog ()) {
			$iso  -> cleanISO ();
			return undef;
		}
	}
	#==========================================
	# Clean tmp
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	$kiwi -> info ("Created $name to be burned on CD");
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
	my $xml       = $this->{xml};
	my $cmdL      = $this->{cmdL};
	my $irdsize   = $main::global -> isize ($initrd);
	my $vmsize    = $main::global -> isize ($system);
	my $diskname  = $system.".install.raw";
	my $md5name   = $system;
	my $destdir   = dirname ($initrd);
	my %deviceMap = ();
	my @commands  = ();
	my $gotsys    = 1;
	my $bootloader= "grub";
	my $haveDiskDevice;
	my $status;
	my $result;
	my $version;
	my $tmpdir;
	my %type;
	my $stick;
	#==========================================
	# Check for disk device
	#------------------------------------------
	if (-b $system) {
		$haveDiskDevice = $system;
		$version = $xml -> getImageVersion();
		$system  = $xml -> getImageName();
		$system  = $destdir."/".$system.".".$arch."-".$version.".raw";
		$diskname= $system.".install.raw";
		$md5name = $system;
		$this->{system} = $system;
	}
	#==========================================
	# read config XML attributes
	#------------------------------------------
	if (defined $xml) {
		%type = %{$xml->getImageTypeAndAttributes()};
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
	$tmpdir = qxx ( "mktemp -q -d /tmp/kiwistickinst.XXXXXX" ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$this->{tmpdir} = $tmpdir;
	push @{$this->{tmpdirs}},$tmpdir;
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# check if system image is given
	#------------------------------------------
	if (! defined $system) {
		$system   = $initrd;
		$diskname = $initrd;
		$diskname =~ s/gz$/raw/;
		$gotsys   = 0;
	}
	#==========================================
	# check image type
	#------------------------------------------
	if ($gotsys) {
		#==========================================
		# build label from xml data
		#------------------------------------------
		$this->{bootlabel} = $xml -> getImageDisplayName();
		if (! $haveDiskDevice) {
			#==========================================
			# bind $system to loop device
			#------------------------------------------
			$kiwi -> info ("Binding disk to loop device");
			if (! $this -> bindDiskDevice ($system)) {
				$kiwi -> failed ();
				return undef;
			}
			$kiwi -> done();
			#==========================================
			# setup device mapper
			#------------------------------------------
			$kiwi -> info ("Setup device mapper for partition access");
			if (! $this -> bindDiskPartitions ($this->{loop})) {
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
			$kiwi -> done();
		} else {
			$kiwi -> info ("Using disk device: $haveDiskDevice");
			$this->{loop}     = $haveDiskDevice;
			$this->{bindloop} = $haveDiskDevice;
			qxx ("vgchange -a y 2>&1");
			$kiwi -> done();
		}
		#==========================================
		# find partition to check
		#------------------------------------------
		my $sdev = $this->{bindloop}."1";
		if (! -e $sdev) {
			$sdev = $this->{bindloop}."2";
		}
		#==========================================
		# check for activated volume group
		#------------------------------------------
		$sdev = $this -> checkLVMbind ($sdev,$this->{loop});
		#==========================================
		# perform mount call
		#------------------------------------------
		if (! $main::global -> mount ($sdev, $tmpdir)) {
			$kiwi -> error  ("Failed to mount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$this -> cleanLoop();
	}
	$this->{bootpart}= 0;
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
	# Compress system image
	#------------------------------------------
	if ($gotsys) {
		$md5name =~ s/\.raw$/\.md5/;
		$kiwi -> info ("Compressing installation image...");
		if ($haveDiskDevice) {
			$status = qxx ("cat $haveDiskDevice > $system");
		}
		$status = qxx (
			"mksquashfs $system $md5name $system.squashfs -no-progress 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to compress system image: $status");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
		$system = $system.".squashfs";
		$vmsize = -s $system;
	}
	#==========================================
	# setup required disk size
	#------------------------------------------
	$irdsize= ($irdsize / 1e6) + 20;
	$irdsize= sprintf ("%.0f", $irdsize);
	$vmsize = ($vmsize / 1e6) * 1.3 + $irdsize;
	$vmsize = sprintf ("%.0f", $vmsize);
	$vmsize = $vmsize."M";
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $nameusb = basename ($system);
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		return undef;
	}
	$this->{initrd} = $initrd;
	#==========================================
	# Create Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this->{initrd} = $oldird;
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		return undef;
	}
	#==========================================
	# Creating boot loader configuration
	#------------------------------------------
	my $title = "KIWI USB-Stick Installation";
	if (! $gotsys) {
		$title = "KIWI USB Boot: $nameusb";
	}
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$title)) {
		return undef;
	}
	$this->{initrd} = $oldird;
	#==========================================
	# create/use disk
	#------------------------------------------
	if (! $haveDiskDevice) {
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
			return undef;
		}
		$kiwi -> done();
		$kiwi -> info ("Binding virtual disk to loop device");
		if (! $this -> bindDiskDevice ($diskname)) {
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
	} else {
		#==========================================
		# Find USB stick devices
		#------------------------------------------
		my $stick = $this -> searchUSBStickDevice ();
		if (! $stick) {
			return undef;
		}
		$this->{loop} = $stick;
	}
	#==========================================
	# create disk partitions
	#------------------------------------------
	$kiwi -> info ("Create partition table for disk");
	my $partid = "83";
	if ($bootloader eq "syslinux" ) {
		$partid = "c";
	}
	if ($gotsys) {
		@commands = (
			"n","p","1",".","+".$irdsize."M",
			"n","p","2",".",".",
			"t","1",$partid,
			"a","1","w","q"
		);
	} else {
		@commands = (
			"n","p","1",".",".",
			"t","1",$partid,
			"a","1","w","q"
		);
	}
	if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create partition table");
		$kiwi -> failed ();
		$this -> cleanLoop();
		return undef;
	}
	$kiwi -> done();
	if (! $haveDiskDevice ) {
		#==========================================
		# setup device mapper
		#------------------------------------------
		$kiwi -> info ("Setup device mapper for partition access");
		if (! $this -> bindDiskPartitions ($this->{loop})) {
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Create loop device mapping table
		#------------------------------------------
		%deviceMap = $this -> setLoopDeviceMap ($this->{loop});
	} else {
		#==========================================
		# Create disk device mapping table
		#------------------------------------------
		%deviceMap = $this -> setDefaultDeviceMap ($this->{loop});
		#==========================================
		# Umount possible mounted stick partitions
		#------------------------------------------
		$this -> umountDevice ($this->{loop});
		for (my $try=0;$try>=2;$try++) {
			$status = qxx ("/sbin/blockdev --rereadpt $this->{loop} 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				sleep (1); next;
			}
			last;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't reread partition table: $status");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# Wait for new partition table to settle
		#------------------------------------------
		sleep (1);
		#==========================================
		# Umount possible mounted stick partitions
		#------------------------------------------
		$this -> umountDevice ($this->{loop});
	}
	if ($bootloader eq "extlinux") {
		$deviceMap{extlinux} = $deviceMap{1};
	}
	if ($bootloader eq "syslinux") {
		$deviceMap{fat} = $deviceMap{1};
	}
	my $boot = $deviceMap{1};
	my $data;
	if ($gotsys) {
		$data = $deviceMap{2};
	}
	#==========================================
	# Create filesystem on partitions
	#------------------------------------------
	foreach my $root ($boot,$data) {
		next if ! defined $root;
		if (($root eq $boot) && ($bootloader eq "syslinux")) {
			$kiwi -> info ("Creating DOS boot filesystem");
			$status = qxx ("/sbin/mkdosfs $root 2>&1");
			$result = $? >> 8;
		} else {
			$kiwi -> info ("Creating ext3 filesystem on $root partition");
			my %FSopts = $main::global -> checkFSOptions(
				@{$cmdL -> getFilesystemOptions()}
			);
			my $fsopts = $FSopts{ext3};
			my $fstool = "mkfs.ext3";
			if (($root eq $data) && ($this->{inodes})) {
				$fsopts.= " -N $this->{inodes}";
			}
			$status = qxx ( "$fstool $fsopts $root 2>&1" );
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy boot data on first partition
	#------------------------------------------
	$kiwi -> info ("Installing boot data to disk");
	if (! $main::global -> mount ($boot, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount boot partition: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$status = qxx ("cp -a $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install boot data: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$main::global -> umount();
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
			return undef;
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
			return undef;
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
		if (! $main::global -> mount($data, $loopdir)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount data partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$status = qxx ("mv $system $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		if (! open (FD,">$loopdir/config.usbclient")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create USB install flag file");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		print FD "IMAGE='".$nameusb."'\n";
		close FD;
		$main::global -> umount();
		$kiwi -> done();
	}
	#==========================================
	# Install boot loader on disk
	#------------------------------------------
	my $bootdevice = $diskname;
	if ($haveDiskDevice) {
		$bootdevice = $this->{loop};
	}
	if (! $this -> installBootLoader ($bootloader, $bootdevice, \%deviceMap)) {
		$this -> cleanLoopMaps();
		$this -> cleanLoop ();
		return undef;
	}
	$this -> cleanLoopMaps();
	$this -> cleanLoop();
	if (! $haveDiskDevice) {
		$kiwi -> info ("Created $diskname to be dd'ed on Stick");
	} else {
		$kiwi -> info ("Successfully created install stick on $this->{loop}");
	}
	$kiwi -> done ();
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
	my $bootsize  = $this->{bootsize};
	my $diskname  = $system.".raw";
	my %deviceMap = ();
	my @commands  = ();
	my $bootfix   = "VMX";
	my $dmapper   = 0;
	my $haveluks  = 0;
	my $needBootP = 0;
	my $bootloader;
	my $boot;
	if ($arch =~ /ppc|ppc64/) {
		$bootloader = "lilo";
	} else {
		$bootloader = "grub";
	}
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
	# check if we got a real device
	#------------------------------------------
	if ($device) {
		$haveDiskDevice = $device;
	}
	#==========================================
	# load type attributes...
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes()};
	#==========================================
	# Check for LVM...
	#------------------------------------------
	if (($type{lvm} =~ /true|yes/i) || ($lvm)) {
		#==========================================
		# add boot space if lvm based
		#------------------------------------------
		$lvm = 1;
		$this->{lvm}= $lvm;
		#==========================================
		# set volume group name
		#------------------------------------------
		my $vgroupName = $xml -> getLVMGroupName();
		if ($vgroupName) {
			$this->{lvmgroup} = $vgroupName;
		}
		#==========================================
		# check and set LVM volumes setup
		#------------------------------------------
		%lvmparts = $xml -> getLVMVolumes();
		if (%lvmparts) {
			if ( ! -d $system ) {
				$kiwi -> error (
					"LVM volumes setup requires root tree but got image file"
				);
				$kiwi -> failed ();
				return undef;
			}
			foreach my $vol (keys %lvmparts) {
				#==========================================
				# check directory per volume
				#------------------------------------------
				my $pname  = $vol; $pname =~ s/_/\//g;
				if (! -d "$system/$pname") {
					$kiwi -> error ("LVM: No such directory $system/$pname");
					$kiwi -> failed ();
					return undef;
				}
				#==========================================
				# store volume sizes in lvmparts
				#------------------------------------------
				my $space = 0;
				my $diff  = 0;
				my $haveAbsolute;
				if ($lvmparts{$vol}) {
					$space = $lvmparts{$vol}->[0];
					$haveAbsolute = $lvmparts{$vol}->[1];
				}
				my $lvsize = qxx (
					"du -s --block-size=1 $system/$pname | cut -f1"
				);
				chomp $lvsize;
				$lvsize /= 1048576;
				if ($haveAbsolute) {
					if ($space > ($lvsize + 30)) {
						$diff = $space - $lvsize;
						$lvsize = $space;
					} else {
						$lvsize += 30;
					}
				} else {
					$lvsize = int ( 30 + $lvsize + $space);
				}
				$lvmparts{$vol}->[2] = $lvsize;
				#==========================================
				# increase total vm disk size
				#------------------------------------------
				$kiwi->loginfo ("Increasing disk size for volume $pname\n");
				if ($haveAbsolute) {
					$this -> __updateDiskSize ($diff + 30);
				} else {
					$this -> __updateDiskSize ($space+ 30);
				}
			}
		}
	}
	#==========================================
	# check for overlay filesystems
	#------------------------------------------
	if ($type{filesystem} eq "clicfs") {
		$this->{dmapper} = 1;
		$dmapper  = 1;
	}
	#==========================================
	# check if fs requires a boot partition
	#------------------------------------------
	if (($type{filesystem} eq "btrfs") || ($type{filesystem} eq "xfs")) {
		$needBootP  = 1;
	}
	#==========================================
	# check for LUKS extension
	#------------------------------------------
	if ($type{luks}) {
		$haveluks   = 1;
	}
	#==========================================
	# setup boot loader type
	#------------------------------------------
	if ($type{bootloader}) {
		$bootloader = $type{bootloader};
	}
	$this->{bootloader} = $bootloader;
	#==========================================
	# add boot space if syslinux based
	#------------------------------------------
	if ($bootloader =~ /(sys|ext)linux/) {
		my $fatstorage = $cmdL->getFatStorage();
		if (defined $fatstorage) {
			if ($bootsize < $fatstorage) {
				$bootsize = $fatstorage;
			}
		}
	}
	#==========================================
	# build disk name and label from xml data
	#------------------------------------------
	$destdir  = dirname ($initrd);
	$label    = $xml -> getImageDisplayName();
	$version  = $xml -> getImageVersion();
	$diskname = $xml -> getImageName();
	$diskname = $destdir."/".$diskname.".".$arch."-".$version.".raw";
	$splitfile= $destdir."/".$label."-read-write.".$arch."-".$version;
	$this->{bootlabel}= $label;
	#==========================================
	# build bootfix for the bootloader on oem
	#------------------------------------------
	if ($initrd =~ /oemboot/) {
		my $oemtitle = $xml -> getOEMBootTitle();
		if ($oemtitle) {
			$this->{bootlabel} = $oemtitle;
			$bootfix = "OEM";
		}
	}
	#==========================================
	# increase disk size for in-place recovery
	#------------------------------------------
	my $inplace = $xml -> getOEMRecoveryInPlace();
	if (($inplace) && ("$inplace" eq "true")) {
		my ($FD,$recoMB);
		my $sizefile = "$destdir/recovery.partition.size";
		if (open ($FD,$sizefile)) {
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
		my $splitsize = $main::global -> isize ($splitfile);
		my $splitMB = $splitsize / 1048576;
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
		my %fsattr = $main::global -> checkFileSystem ($FSTypeRW);
		if ($fsattr{readonly}) {
			$kiwi -> error ("Can't copy data into requested RO filesystem");
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# Create Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		return undef;
	}
	#==========================================
	# Setup boot partition ID
	#------------------------------------------
	my $bootpart = "0";
	if (($syszip) || ($haveSplit) || ($haveluks) || ($needBootP)) {
		$bootpart = "1";
	}
	if ((($syszip) || ($haveSplit)) && ($haveluks)) {
		$bootpart = "2";
	}
	if ($dmapper) {
		$bootpart = "2"
	}
	if ($lvm) {
		$bootpart = "0";
	}
	$this->{bootpart} = $bootpart;
	#==========================================
	# Update raw disk size if boot part is used
	#------------------------------------------
	if (($syszip)    ||
		($haveSplit) ||
		($haveluks)  ||
		($needBootP) ||
		($dmapper)   ||
		($lvm)
	) {
		$this -> __updateDiskSize ($bootsize);
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		return undef;
	}
	#==========================================
	# add extra Xen boot options if necessary
	#------------------------------------------
	my $extra = "";
	#==========================================
	# Create boot loader configuration
	#------------------------------------------
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$bootfix,$extra)) {
		return undef;
	}
	#==========================================
	# create/use disk
	#------------------------------------------
	my $dmap; # device map
	my $root; # root device
	if (! defined $system) {
		$kiwi -> error  ("No system image given");
		$kiwi -> failed ();
		return undef;
	}
	if (! $haveDiskDevice) {
		$kiwi -> info ("Creating virtual disk...");
	} else {
		$kiwi -> info ("Using disk device $haveDiskDevice...");
	}
	while (1) {
		if (! $haveDiskDevice) {
			$status = qxx ("qemu-img create $diskname $this->{vmsize} 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Failed creating virtual disk: $status");
				$kiwi -> failed ();
				return undef;
			}
			#==========================================
			# setup loop device for virtual disk
			#------------------------------------------
			if (! $this -> bindDiskDevice($diskname)) {
				return undef;
			}
		} else {
			# /.../
			# the following is required for suse studio to determine the
			# size of the image target disk. It has no relevance for the
			# standard build process and is therefore called without any
			# return value check. 
			qxx ("qemu-img create $diskname $this->{vmsize} 2>&1");
			# ----
			$this->{loop} = $haveDiskDevice;
			if (! -b $this->{loop}) {
				$kiwi -> failed ();
				$kiwi -> error  ("No such block device: $this->{loop}");
				$kiwi -> failed ();
				return undef;
			}
		}
		#==========================================
		# create disk partition
		#------------------------------------------
		if ($arch =~ /ppc|ppc64/) {
			my $prepsize = $bootsize;
			if (! $lvm) {
				@commands = (
					"n","p","1",".","+".$prepsize."M",
					"n","p","2",".",".",
					"t","1","41",
					"t","2","83",
					"a","1","w","q"
				);
			} else {
				@commands = (
					"n","p","1",".","+".$bootsize."M",
					"n","p","2",".",".",
					"t","1","c",
					"t","2","8e",
					"a","1","w","q"
				);
			}
		} else {
		if (! $lvm) {
			if (($syszip) || ($haveSplit) || ($dmapper)) {
				# xda1 ro / xda2 rw
				if ($bootloader =~ /(sys|ext)linux/) {
					my $partid = "c";
					if ($bootloader eq "extlinux" ) {
						$partid = "83";
					}
					my $syslsize = $this->{vmmbyte} - $bootsize - $syszip;
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".","+".$syslsize."M",
						"n","p","3",".",".",
						"t","3",$partid,
						"a","3","w","q"
					);
				} elsif ($dmapper) {
					my $dmsize = $this->{vmmbyte} - $bootsize - $syszip;
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".","+".$dmsize."M",
						"n","p","3",".",".",
						"a","3","w","q"
					);
				} elsif ($haveluks) {
					my $lukssize = $this->{vmmbyte} - $bootsize - $syszip;
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".","+".$lukssize."M",
						"n","p","3",".",".",
						"a","3","w","q"
					);
				} else {
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".",".",
						"a","2","w","q"
					);
				}
			} else {
				# xda1 rw
				if ($bootloader =~ /(sys|ext)linux/) {
					my $partid = "c";
					if ($bootloader eq "extlinux" ) {
						$partid = "83";
					}
					my $syslsize = $this->{vmmbyte} - $bootsize;
					@commands = (
						"n","p","1",".","+".$syslsize."M",
						"n","p","2",".",".",
						"t","2",$partid,
						"a","2","w","q"
					);
				} elsif (($haveluks) || ($needBootP)) {
					my $lukssize = $this->{vmmbyte} - $bootsize;
					@commands = (
						"n","p","1",".","+".$lukssize."M",
						"n","p","2",".",".",
						"a","2","w","q"
					);
				} else {
					@commands = (
						"n","p","1",".",".",
						"a","1","w","q"
					);
				}
			}
		} else {
			if ($bootloader =~ /(sys|ext)linux/) {
				my $partid = "c";
				if ($bootloader eq "extlinux" ) {
					$partid = "83";
				}
				my $lvmsize = $this->{vmmbyte} - $bootsize;
				my $bootpartsize = "+".$bootsize."M";
				@commands = (
					"n","p","1",".",$bootpartsize,
					"n","p","2",".",".",
					"t","1",$partid,
					"t","2","8e",
					"a","1","w","q"
				);
			} else {
				my $lvmsize = $this->{vmmbyte} - $bootsize;
				my $bootpartsize = "+".$bootsize."M";
				@commands = (
					"n","p","1",".",$bootpartsize,
					"n","p","2",".",".",
					"t","2","8e",
					"a","1","w","q"
				);
			}
		}
		}
		if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create partition table");
			$kiwi -> failed ();
			$this -> cleanLoop();
			return undef;
		}
		if (! $haveDiskDevice ) {
			#==========================================
			# setup device mapper
			#------------------------------------------
			if (! $this -> bindDiskPartitions ($this->{loop})) {
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
			#==========================================
			# Create loop device mapping table
			#------------------------------------------
			%deviceMap = $this -> setLoopDeviceMap ($this->{loop});
		} else {
			#==========================================
			# Create disk device mapping table
			#------------------------------------------
			if ($arch =~ /ppc|ppc64/) {
				%deviceMap = $this -> setPPCDeviceMap ($this->{loop});
			} else {
				%deviceMap = $this -> setDefaultDeviceMap ($this->{loop});
			}
			#==========================================
			# Umount possible mounted stick partitions
			#------------------------------------------
			$this -> umountDevice ($this->{loop});
			for (my $try=0;$try>=2;$try++) {
				$status = qxx ("/sbin/blockdev --rereadpt $this->{loop} 2>&1");
				$result = $? >> 8;
				if ($result != 0) {
					sleep (1); next;
				}
				last;
			}
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't reread partition table: $status");
				$kiwi -> failed ();
				return undef;
			}
			#==========================================
			# Wait for new partition table to settle
			#------------------------------------------
			sleep (1);
			#==========================================
			# Umount possible mounted stick partitions
			#------------------------------------------
			$this -> umountDevice ($this->{loop});
		}
		#==========================================
		# setup volume group if requested
		#------------------------------------------
		if ($lvm) {
			%deviceMap = $this -> setVolumeGroup (
				\%deviceMap,$this->{loop},$syszip,$haveSplit,\%lvmparts
			);
			if (! %deviceMap) {
				$this -> cleanLoop ();
				return undef;
			}
		}
		#==========================================
		# set root device name from deviceMap
		#------------------------------------------
		if (($arch =~ /ppc|ppc64/) && (!$lvm)) {
			$root = $deviceMap{2};
		} else {
			$root = $deviceMap{1};
		}
		#==========================================
		# check partition sizes
		#------------------------------------------
		if ($syszip > 0) {
			my $sizeOK = 1;
			my $systemPSize = $this->getStorageSize ($deviceMap{1});
			my $systemISize = $main::global -> isize ($system);
			$systemISize /= 1024;
			chomp $systemPSize;
			#print "_______A $systemPSize : $systemISize\n";
			if ($systemPSize < $systemISize) {
				$syszip += 10;
				$sizeOK = 0;
			}
			if (! $sizeOK) {
				#==========================================
				# bad partition alignment try again
				#------------------------------------------
				sleep (1);
				$this -> deleteVolumeGroup();
				$this -> cleanLoopMaps();
				qxx ("/sbin/losetup -d $this->{loop}");
			} else {
				#==========================================
				# looks good go for it
				#------------------------------------------
				last;
			}
		} else {
			#==========================================
			# entire disk used
			#------------------------------------------
			last;
		}
		$kiwi -> note (".");
	}
	$kiwi -> done();
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
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		$result = 0;
		my $mapper = $root;
		my %fsattr = $main::global -> checkFileSystem ($root);
		if ($fsattr{type} eq "luks") {
			$mapper = $this -> luksResize ($root,"luks-resize");
			if (! $mapper) {
				$this -> luksClose();
				return undef;
			}
			%fsattr= $main::global -> checkFileSystem ($mapper);
		}
		my $expanded = $this -> __expandFS (
			$fsattr{type},'system', $mapper
		);
		if (! $expanded ) {
			return undef;
		}
		if ($haveSplit) {
			$kiwi -> info ("Dumping split read/write part on disk");
			$root = $deviceMap{2};
			$status = qxx ("dd if=$splitfile of=$root bs=32k 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't dump split file: $status");
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
			$kiwi -> done();
			$result = 0;
			$mapper = $root;
			my %fsattr = $main::global -> checkFileSystem ($root);
			if ($fsattr{type} eq "luks") {
				$mapper = $this -> luksResize ($root,"luks-resize");
				if (! $mapper) {
					$this -> luksClose();
					return undef;
				}
				%fsattr= $main::global -> checkFileSystem ($mapper);
			}
			my $expanded = $this -> __expandFS (
				$fsattr{type},'split', $mapper
			);
			if (! $expanded ) {
				return undef;
			}
		}
	} else {
		#==========================================
		# Create fs on system image partition
		#------------------------------------------
		if (! $this -> setupFilesystem ($FSTypeRO,$root,"root")) {
			return undef;
		}
		#==========================================
		# Mount system image partition
		#------------------------------------------
		if (! $main::global -> mount ($root, $loopdir)) {
			$this -> cleanLoop ();
			return undef;
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
			sub numeric {
				($a <=> $b) || ($a cmp $b);
			}
			foreach my $name (keys %lvmparts) {
				my $pname  = $name; $pname =~ s/_/\//g;
				$pname =~ s/^\///;
				$pname =~ s/\s*$//;
				push @paths,$pname;
			}
			foreach my $name (@paths) {
				my $part = split (/\//,$name);
				push @{$phash{$part}},$name;
			}
			#==========================================
			# Create filesystems and Mount LVM volumes
			#------------------------------------------
			foreach my $level (sort numeric keys %phash) {
				foreach my $pname (@{$phash{$level}}) {
					my $lname = $pname; $lname =~ s/\//_/g;
					my $device = "/dev/$VGroup/LV$lname";
					$status = qxx ("mkdir -p $loopdir/$pname 2>&1");
					$result = $? >> 8;
					if ($result != 0) {
						$kiwi -> error ("Can't create mount point $loopdir/$pname");
						$this -> cleanLoop ();
						return undef;
					}
					if (! $this -> setupFilesystem ($FSTypeRO,$device,$pname)) {
						$this -> cleanLoop ();
						return undef;
					}
					$kiwi -> loginfo ("Mounting logical volume: $pname\n");
					if (! $main::global -> mount ($device, "$loopdir/$pname")) {
						$this -> cleanLoop ();
						return undef;
					}
				}
			}
		}
		#==========================================
		# Copy root tree to disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on disk");
		$status = qxx (
			"tar --one-file-system -cf - -C $system . | tar -x -C $loopdir 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't copy image tree to disk: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		if ($haveDiskDevice) {
			#==========================================
			# fill disk device with zero bytes
			#------------------------------------------
			qxx ("dd if=/dev/zero of=$loopdir/abc 2>&1");
			qxx ("rm -f $loopdir/abc");
		}
		$kiwi -> done();
		#==========================================
		# Umount system image partition
		#------------------------------------------
		$main::global -> umount();
	}
	#==========================================
	# create read/write filesystem if needed
	#------------------------------------------
	if (($syszip) && (! $haveSplit) && (! $dmapper)) {
		$root = $deviceMap{2};
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
				return undef;
			}
			$status = qxx ("echo $cipher|cryptsetup luksOpen $root $name 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't open luks device: $status");
				$kiwi -> failed ();
				return undef;
			}
			$root = "/dev/mapper/$name";
			$this->{luks} = $name;
		} else {
			$kiwi -> info ("Creating ext3 read-write filesystem");
		}
		my %FSopts = $main::global -> checkFSOptions(
			@{$cmdL -> getFilesystemOptions()}
		);
		my $fsopts = $FSopts{ext3};
		my $fstool = "mkfs.ext3";
		$status = qxx ("$fstool $fsopts $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			$this -> luksClose();
			$this -> cleanLoop ();
			return undef;
		}
		$this -> luksClose();
		$kiwi -> done();
	}
	#==========================================
	# create bootloader filesystem if needed
	#------------------------------------------
	if ($bootloader eq "syslinux") {
		$root = $deviceMap{fat};
		$kiwi -> info ("Creating DOS boot filesystem");
		$status = qxx ("/sbin/mkdosfs $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create DOS filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
	} elsif (($arch =~ /ppc|ppc64/) && ($lvm)) {
		$boot = $deviceMap{fat};
		$kiwi -> info ("Creating DOS boot filesystem");
		$status = qxx ("/sbin/mkdosfs -F 16 $boot 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create DOS filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	} elsif (
		($dmapper) || ($haveluks) || ($needBootP) ||
		($lvm) || ($bootloader eq "extlinux")
	) {
		$root = $deviceMap{dmapper};
		$kiwi -> info ("Creating ext3 boot filesystem");
		if (($haveluks) || ($needBootP)) {
			if (($syszip) || ($haveSplit) || ($dmapper)) {
				$root = $deviceMap{3};
			} else {
				$root = $deviceMap{2};
			}
		}
		if ($lvm) {
			$root = $deviceMap{0};
		}
		if ($bootloader eq "extlinux") {
			$root = $deviceMap{extlinux};
		}
		my %FSopts = $main::global -> checkFSOptions(
			@{$cmdL -> getFilesystemOptions()}
		);
		my $fsopts = $FSopts{ext3};
		my $fstool = "mkfs.ext3";
		$status = qxx ("$fstool $fsopts $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Dump boot image on disk
	#------------------------------------------
	$kiwi -> info ("Copying boot image to disk");
	#==========================================
	# Mount system image / or rw partition
	#------------------------------------------
	if ($bootloader eq "syslinux") {
		$root = $deviceMap{fat};
	} elsif ($bootloader eq "extlinux") {
		$root = $deviceMap{extlinux};
	} elsif ($dmapper) {
		$root = $deviceMap{dmapper};
	} elsif ($arch =~ /ppc|ppc64/){
		if ($lvm) {
			$boot = $deviceMap{fat};
			$root = $deviceMap{1};
		} else {
			$root = $deviceMap{2};
		}
	} elsif (($syszip) || ($haveSplit) || ($lvm)) {
		$root = $deviceMap{2};
		if ($haveluks) {
			$root = $deviceMap{3};
		}
		if ($lvm) {
			$root = $deviceMap{0};
		}
	} elsif (($haveluks) || ($needBootP)) {
		$root = $deviceMap{2};
	} else {
		$root = $deviceMap{1};
	}
	if (! $main::global -> mount ($root, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image: $root");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	if (($arch =~/ppc|ppc64/) && ($lvm)) {
		$status = qxx ("mkdir -p $loopdir/vfat");
		$boot = $deviceMap{fat};
		if (! $main::global -> mount ($boot, $loopdir."/vfat")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount image: $boot");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	}
	#==========================================
	# Copy boot data on system image
	#------------------------------------------
	$status = qxx ("cp -dR $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($arch =~ /ppc|ppc64/) {
		#==========================================
		# Copy yaboot.conf
		#------------------------------------------
		if (! $lvm) {
			$status = qxx ("cp $tmpdir/etc/yaboot.conf $loopdir/etc/ 2>&1");
			$result = $? >> 8;
		} else {
			$status = qxx (
				"cp $tmpdir/etc/yaboot.conf $loopdir/vfat/yaboot.cnf 2>&1"
			);
			$result = $? >> 8;
			$status = qxx ("cp $loopdir/boot/linux.vmx  $loopdir/vfat");
			$status = qxx ("cp $loopdir/boot/initrd.vmx $loopdir/vfat");
			$result = $? >> 8;
			$status = qxx (
				"cp $loopdir/lib/lilo/chrp/yaboot.chrp $loopdir/vfat/yaboot"
			);
			$result = $? >> 8;
			$status = qxx ("cp -a $tmpdir/ppc $loopdir/vfat/");
			$result = $? >> 8;
			$main::global -> umount($boot);
			$status = qxx ("rm -rf $loopdir/vfat");
			$result = $? >> 8;
		}
	}
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Couldn't copy boot data to system image: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$main::global -> umount();
	$kiwi -> done();
	#==========================================
	# Install boot loader on disk
	#------------------------------------------
	my $bootdevice = $diskname;
	if ($haveDiskDevice) {
		$bootdevice = $this->{loop};
	}
	if (! $this->installBootLoader ($bootloader,$bootdevice,\%deviceMap)) {
		$this -> cleanLoop ();
		return undef;
	}
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	if ($lvm) {
		qxx ("vgchange -an $this->{lvmgroup} 2>&1");
	}
	$this -> cleanLoopMaps();
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	if ($haveDiskDevice)  {
		#==========================================
		# create image file from disk device
		#------------------------------------------
		$kiwi -> info ("Dumping image file from $this->{loop}...");
		$status = qxx ("dd if=$this->{loop} of=$diskname bs=32k 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Image dump failed: $status");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Create image described by given format
	#------------------------------------------
	if ($initrd =~ /oemboot/) {
		#==========================================
		# OEM Install CD...
		#------------------------------------------
		if ($type{installiso} =~ /true|yes/i) {
			$this -> {system} = $diskname;
			if ($haveDiskDevice) {
				$this -> {system} = $this->{loop};
			}
			$kiwi -> info ("--> Creating install ISO image\n");
			$this -> cleanLoop ();
			if (! $this -> setupInstallCD()) {
				return undef;
			}
		}
		#==========================================
		# OEM Install Stick...
		#------------------------------------------
		if ($type{installstick} =~ /true|yes/i) {
			$this -> {system} = $diskname;
			if ($haveDiskDevice) {
				$this -> {system} = $this->{loop};
			}
			$kiwi -> info ("--> Creating install USB Stick image\n");
			$this -> cleanLoop ();
			if (! $this -> setupInstallStick()) {
				return undef;
			}
		}
	}
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	$this -> cleanLoop ();
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
	my $irddir = $initrd."_".$$.".vmxsystem";
	my $xml    = $this->{xml};
	my $zipper = $this->{gdata}->{Gzip};
	my $newird;
	if (! mkdir $irddir) {
		$kiwi -> error  ("Failed to create vmxsystem directory");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# unpack initrd files
	#------------------------------------------
	my $unzip  = "$this->{gdata}->{Gzip} -cd $initrd 2>&1";
	my $status = qxx ("$unzip | (cd $irddir && cpio -di 2>&1)");
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to extract initrd data: $!");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return undef;
	}
	#===========================================
	# add image.md5 / config.vmxsystem to initrd
	#-------------------------------------------
	if (defined $system) {
		my $imd5 = $system;
		$imd5 =~ s/\.raw$/\.md5/;
		my $status = qxx ("cp $imd5 $irddir/etc/image.md5 2>&1");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed importing md5 file: $status");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return undef;
		}
		if (! open (FD,">$irddir/config.vmxsystem")) {
			$kiwi -> error  ("Couldn't create image boot configuration");
			$kiwi -> failed ();
			return undef;
		}
		my $namecd = basename ($system);
		if (! -f $imd5) {
			$kiwi -> error  ("Couldn't find md5 file");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return undef;
		}
		print FD "IMAGE='".$namecd."'\n";
		close FD;
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
		$kiwi -> error  ("Failed to re-create initrd: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return undef;
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
# setupSplash
#------------------------------------------
sub setupSplash {
	# ...
	# we can either use bootsplash or splashy to display
	# a splash screen. If /usr/sbin/splashy exists we will
	# prefer splashy over bootsplash
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $initrd = $this->{initrd};
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
	#==========================================
	# check if splash initrd is already there
	#------------------------------------------
	if ((! -l $newird) && (-f $newird)) {
		# splash initrd already created...
		return $newird;
	}
	$kiwi -> info ("Setting up splash screen...");
	#==========================================
	# setup splash in initrd
	#------------------------------------------
	if (-f $splfile) {
		qxx ("cat $initrd $splfile > $newird");
		$status = "ok";
	} else {
		$status = "Can't find splash file: $splfile";
	}
	#==========================================
	# check status and return
	#------------------------------------------
	if ($status ne "ok") {
		$kiwi -> skipped ();
		$kiwi -> warning ($status);
		$kiwi -> skipped ();
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
	$kiwi -> done();
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
# cleanLoop
#------------------------------------------
sub cleanLoop {
	my $this = shift;
	my $tmpdir = $this->{tmpdir};
	my $loop   = $this->{loop};
	my $lvm    = $this->{lvm};
	my $loopdir= $this->{loopdir};
	$main::global -> umount();
	if ((defined $loop) && ($loop =~ /loop/)) {
		if (defined $lvm) {
			qxx ("vgchange -an 2>&1");
		}
		$this -> cleanLoopMaps();
		qxx ("/sbin/losetup -d $loop 2>&1");
		undef $this->{loop};
	}
	return $this;
}

#==========================================
# cleanLoopMaps
#------------------------------------------
sub cleanLoopMaps {
	my $this = shift;
	my $dev  = shift;
	my $loop = $this->{loop};
	if ($dev) {
		$loop = $dev;
	}
	if ($loop =~ /dev\/(.*)/) {
		$loop = $1;
	}
	foreach my $d (glob ("/dev/mapper/$loop*")) {
		qxx ("dmsetup remove $d 2>&1");
	}
	return $this;
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
	my $size = $main::global -> isize ($file);
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
		return undef;
	}
	my $pid = pack "V", eval $nid;
	if (! open (FD,"+<$file")) {
		$kiwi -> failed ();
		$kiwi -> error  ("MBR: failed to open file: $file: $!");
		$kiwi -> failed ();
		return undef;
	}
	seek FD,440,0;
	my $done = syswrite (FD,$pid,4);
	if ($done != 4) {
		$kiwi -> failed ();
		$kiwi -> error  ("MBR: only $done bytes written");
		$kiwi -> failed ();
		seek FD,0,2; close FD;
		return undef;
	}
	seek FD,0,2; close FD;
	return $this;
}

#==========================================
# setupBootLoaderStages
#------------------------------------------
sub setupBootLoaderStages {
	my $this   = shift;
	my $loader = shift;
	my $type   = shift;
	my $kiwi   = $this->{kiwi};
	my $tmpdir = $this->{tmpdir};
	my $initrd = $this->{initrd};
	my $zipped = $this->{zipped};
	my $zipper = $this->{gdata}->{Gzip};
	my $status = 0;
	my $result = 0;
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
			return undef;
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
			chomp $status;
			$kiwi -> error   ("Failed importing grub stages: $status");
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
				return undef;
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
	# more boot managers to come...
	#------------------------------------------
	# ...
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
	my $kiwi     = $this->{kiwi};
	my $tmpdir   = $this->{tmpdir};
	my $initrd   = $this->{initrd};
	my $isxen    = $this->{isxen};
	my $xendomain= $this->{xendomain};
	my $imgtype  = $this->{imgtype};
	my $bootpart = $this->{bootpart};
	my $label    = $this->{bootlabel};
	my $vga      = $this->{vga};
	my $lvm      = $this->{lvm};
	my $vgroup   = $this->{lvmgroup};
	my $xml      = $this->{xml};
	my $bloader  = "grub";
	my $cmdline;
	my %type;
	my $title;
	#==========================================
	# setup boot loader default boot label/nr
	#------------------------------------------
	my $defaultBootNr = 0;
	if ($xml) {
		%type = %{$xml->getImageTypeAndAttributes()};
		$cmdline  = $type{cmdline};
	}
	if ($type =~ /^KIWI CD Boot/) {
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
	if ((($type =~ /^KIWI (CD|USB)/)) && ($type{installboot})) {
		# In install mode we have the following menu layout
		# ----
		# 0 -> Boot from Hard Disk
		# 1 -> Install/Restore $label
		# 2 -> Failsafe -- Install/Restore $label
		# ----
		if ($type{installboot} eq "install") {
			$defaultBootNr = 1;
		}
		if ($type{installboot} eq "failsafe-install") {
			$defaultBootNr = 2;
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
	# Check boot partition number
	#------------------------------------------
	if (! defined $bootpart) {
		$bootpart = 0;
	}
	#==========================================
	# Grub
	#------------------------------------------
	if ($loader eq "grub") {
		#==========================================
		# Create MBR id file for boot device check
		#------------------------------------------
		$kiwi -> info ("Saving disk label on disk: $this->{mbrid}...");
		if (! open (FD,">$tmpdir/boot/grub/mbrid")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create mbrid file: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "$this->{mbrid}";
		close FD;
		$kiwi -> done();
		#==========================================
		# Create menu.lst file
		#------------------------------------------
		$kiwi -> info ("Creating grub menu list file...");
		if (! open (FD,">$tmpdir/boot/grub/menu.lst")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create menu.lst: $!");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# Compat link
		#------------------------------------------
		qxx ("cd $tmpdir/boot/grub && ln -s menu.lst grub.conf");
		#==========================================
		# General grub setup
		#------------------------------------------
		print FD "color cyan/blue white/blue\n";
		print FD "default $defaultBootNr\n";
		my $bootTimeout = 10;
		if (defined $type{boottimeout}) {
			$bootTimeout = $type{boottimeout};
		}
		if ($type{fastboot}) {
			$bootTimeout = 0;
		}
		print FD "timeout $bootTimeout\n";
		if ($type =~ /^KIWI (CD|USB)/) {
			my $dev = $1 eq 'CD' ? '(cd)' : '(hd0,0)';
			if (! $type{fastboot}) {
				if (-e "$tmpdir/boot/grub/splash.xpm.gz") {
					print FD "splashimage=$dev/boot/grub/splash.xpm.gz\n"
				} elsif (-e "$tmpdir/boot/message") {
					print FD "gfxmenu $dev/boot/message\n";
				}
			}
			print FD "title Boot from Hard Disk\n";
			if ($dev eq '(cd)') {
				print FD " rootnoverify (hd0)\n";
				print FD " chainloader (hd0)+1\n";
			}
			else {
				print FD " chainloader $dev/boot/grub/bootnext\n";
				my $bootnext = $this -> addBootNext (
					"$tmpdir/boot/grub/bootnext", hex $this->{mbrid}
				);
				if (! defined $bootnext) {
					$kiwi -> failed ();
					$kiwi -> error  ("Failed to write bootnext\n");
					$kiwi -> failed ();
					return undef;
				}
			}
			$title = $this -> makeLabel ("Install/Restore $label");
			print FD "title $title\n";
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
			if (-e "$tmpdir/boot/grub/splash.xpm.gz") {
				print FD "splashimage=(hd0,$bootpart)/boot/grub/splash.xpm.gz\n"
			} elsif (-e "$tmpdir/boot/message") {
				print FD "gfxmenu (hd0,$bootpart)/boot/message\n";
			}
			print FD "title $title\n";
		}
		#==========================================
		# Standard boot
		#------------------------------------------
		if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
			if ($type =~ /^KIWI CD/) {
				print FD " kernel (cd)/boot/linux vga=$vga splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
				print FD " cdinst=1 loader=$bloader";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux.vmx vga=$vga";
				print FD " loader=$bloader splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux vga=$vga";
				print FD " loader=$bloader splash=silent";
			}
			print FD $cmdline;
			if ($type =~ /^KIWI CD/) {
				print FD " initrd (cd)/boot/initrd\n";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " initrd /boot/initrd.vmx\n";
			} else {
				print FD " initrd /boot/initrd\n";
			}
		} else {
			if ($type =~ /^KIWI CD/) {
				print FD " kernel (cd)/boot/xen.gz\n";
				print FD " module /boot/linux vga=$vga splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
				print FD " cdinst=1 loader=$bloader";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz.vmx\n";
				print FD " module /boot/linux.vmx vga=$vga";
				print FD " loader=$bloader splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz\n";
				print FD " module /boot/linux vga=$vga";
				print FD " loader=$bloader splash=silent";
			}
			print FD $cmdline;
			if ($type =~ /^KIWI CD/) {
				print FD " module (cd)/boot/initrd\n";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " module /boot/initrd.vmx\n";
			} else {
				print FD " module /boot/initrd\n";
			}
		}
		#==========================================
		# Failsafe boot
		#------------------------------------------
		$title = $this -> makeLabel ("Failsafe -- $title");
		print FD "title $title\n";
		if ((! $isxen) || ($isxen && $xendomain eq "domU")) {
			if ($type =~ /^KIWI CD/) {
				print FD " kernel (cd)/boot/linux vga=$vga splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
				print FD " cdinst=1 loader=$bloader";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux.vmx vga=$vga";
				print FD " loader=$bloader splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux vga=$vga";
				print FD " loader=$bloader splash=silent";
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
			print FD $cmdline;
			if ($type =~ /^KIWI CD/) {
				print FD " initrd (cd)/boot/initrd\n";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " initrd /boot/initrd.vmx\n";
			} else {
				print FD " initrd /boot/initrd\n";
			}
		} else {
			if ($type =~ /^KIWI CD/) {
				print FD " kernel (cd)/boot/xen.gz\n";
				print FD " module (cd)/boot/linux vga=$vga splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
				print FD " cdinst=1 loader=$bloader";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz.vmx\n";
				print FD " module /boot/linux.vmx vga=$vga";
				print FD " loader=$bloader splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz\n";
				print FD " module /boot/linux vga=$vga";
				print FD " loader=$bloader splash=silent";
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
			print FD $cmdline;
			if ($type =~ /^KIWI CD/) {
				print FD " module (cd)/boot/initrd\n"
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD " module /boot/initrd.vmx\n"
			} else {
				print FD " module /boot/initrd\n";
			}
		}
		close FD;
		$kiwi -> done();
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader =~ /(sys|ext)linux/) {
		#==========================================
		# Create MBR id file for boot device check
		#------------------------------------------
		$kiwi -> info ("Saving disk label on disk: $this->{mbrid}...");
		qxx ("mkdir -p $tmpdir/boot/grub");
		if (! open (FD,">$tmpdir/boot/grub/mbrid")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create mbrid file: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "$this->{mbrid}";
		close FD;
		$kiwi -> done();
		#==========================================
		# Create syslinux config file
		#------------------------------------------
		my $syslconfig = "syslinux.cfg";
		if ($loader eq "extlinux") {
			$syslconfig = "extlinux.conf";
		}
		$kiwi -> info ("Creating $syslconfig config file...");
		if (! open (FD,">$tmpdir/boot/syslinux/$syslconfig")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $syslconfig: $!");
			$kiwi -> failed ();
			return undef;
		}
		my $syslinux_new_format = 0;
		my $gfx = "$tmpdir/boot/syslinux";
		if (-f "$gfx/gfxboot.com" || -f "$gfx/gfxboot.c32") {
			$syslinux_new_format = 1;
		}
		#==========================================
		# General syslinux setup
		#------------------------------------------
		print FD "implicit 1"."\n";
		print FD "prompt   1"."\n";
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
		print FD "timeout  $bootTimeout"."\n";
		print FD "display isolinux.msg"."\n";
		my @labels = ();
		if (-f "$gfx/bootlogo") {
			if ($syslinux_new_format) {
				print FD "ui gfxboot bootlogo isolinux.msg"."\n";
			} else {
				print FD "gfxboot bootlogo"."\n";
			}
		}
		#==========================================
		# Setup default title
		#------------------------------------------
		if ($type =~ /^KIWI (CD|USB)/) {
			if ($defaultBootNr == 0) {
				$title = $this -> makeLabel ("Boot from Hard Disk");
			} elsif ($defaultBootNr == 1) {
				$title = $this -> makeLabel ("Install/Restore $label");
			} else {
				$title = $this -> makeLabel (
					"Failsafe -- Install/Restore $label"
				);
			}
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
		}
		print FD "default $title"."\n";
		if ($type =~ /^KIWI (CD|USB)/) {
			$title = $this -> makeLabel ("Boot from Hard Disk");
			print FD "label $title\n";
			print FD "localboot 0x80\n";
			$title = $this -> makeLabel ("Install/Restore $label");
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
		}
		print FD "label $title"."\n";
		push @labels,$title;
		#==========================================
		# Standard boot
		#------------------------------------------
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				print FD "kernel linux\n";
				print FD "append initrd=initrd ";
				print FD "vga=$vga loader=$bloader splash=silent ";
				print FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
				print FD "cdinst=1 kiwi_hybrid=1";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD "kernel /boot/linux.vmx\n";
				print FD "append initrd=/boot/initrd.vmx ";
				print FD "vga=$vga loader=$bloader splash=silent";
			} else {
				print FD "kernel /boot/linux\n";
				print FD "append initrd=/boot/initrd ";
				print FD "vga=$vga loader=$bloader splash=silent";
			}
		} else {
			if ($type =~ /^KIWI CD/) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen cdinst not supported ***");
				$kiwi -> failed ();
				return undef;
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen boot not supported ***");
				$kiwi -> failed ();
				return undef;
			} else {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen boot not supported ***");
				$kiwi -> failed ();
				return undef;
			}
		}
		print FD $cmdline;
		#==========================================
		# Failsafe boot
		#------------------------------------------
		if ($type =~ /^KIWI CD/) {
			$title = $this -> makeLabel ("Failsafe -- Install/Restore $label");
			print FD "label $title"."\n";
		} elsif ($type =~ /^KIWI USB/) {
			$title = $this -> makeLabel ("Failsafe -- Install/Restore $label");
			print FD "label $title"."\n";
		} else {
			$title = $this -> makeLabel ("Failsafe -- $label [ $type ]");
			print FD "label $title"."\n";
		}
		push @labels,$title;
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				print FD "kernel linux\n";
				print FD "append initrd=initrd ";
				print FD "vga=$vga loader=$bloader splash=silent ";
				print FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
				print FD "cdinst=1 kiwi_hybrid=1";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				print FD "kernel /boot/linux.vmx\n";
				print FD "append initrd=/boot/initrd.vmx ";
				print FD "vga=$vga loader=$bloader splash=silent";
			} else {
				print FD "kernel /boot/linux\n";
				print FD "append initrd=/boot/initrd ";
				print FD "vga=$vga loader=$bloader splash=silent";
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
		} else {
			if ($type =~ /^KIWI CD/) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen cdinst not supported ***");
				$kiwi -> failed ();
				return undef;
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen boot not supported ***");
				$kiwi -> failed ();
				return undef;
			} else {
				$kiwi -> failed ();
				$kiwi -> error  ("*** syslinux: Xen boot not supported ***");
				$kiwi -> failed ();
				return undef;
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
		}
		print FD $cmdline;
		close FD;
		#==========================================
		# setup isolinux.msg file
		#------------------------------------------
		if (! open (FD,">$tmpdir/boot/syslinux/isolinux.msg")) {
			$kiwi -> failed();
			$kiwi -> error  ("Failed to create isolinux.msg: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "\n"."Welcome !"."\n\n";
		foreach my $label (@labels) {
			print FD "$label"."\n";
		}
		print FD "\n\n";
		print FD "Have a lot of fun..."."\n";
		close FD;
		$kiwi -> done();
	}
	#==========================================
	# Zipl
	#------------------------------------------
	if ($loader eq "zipl") {
		#==========================================
		# Create MBR id file for boot device check
		#------------------------------------------
		$kiwi -> info ("Saving disk label on disk: $this->{mbrid}...");
		qxx ("mkdir -p $tmpdir/boot/grub");
		qxx ("mkdir -p $tmpdir/boot/zipl");
		if (! open (FD,">$tmpdir/boot/grub/mbrid")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create mbrid file: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "$this->{mbrid}";
		close FD;
		$kiwi -> done();
		#==========================================
		# Create zipl.conf
		#------------------------------------------
		$cmdline =~ s/\n//g;
		my $ziplconfig = "zipl.conf";
		$kiwi -> info ("Creating $ziplconfig config file...");
		if ($isxen) {
			$kiwi -> failed ();
			$kiwi -> error  ("*** zipl: Xen boot not supported ***");
			$kiwi -> failed ();
			return undef;
		}
		if (! -e "/boot/zipl") {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't find bootloader: /boot/zipl");
			$kiwi -> failed ();
			return undef;
		}
		if (! open (FD,">$tmpdir/boot/$ziplconfig")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $ziplconfig: $!");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# General zipl setup
		#------------------------------------------
		my $title_standard;
		my $title_failsafe;
		if ($type =~ /^KIWI (CD|USB)/) {
			$title_standard = $this -> makeLabel (
				"Install/Restore $label"
			);
			$title_failsafe = $this -> makeLabel (
				"Failsafe -- Install/Restore $label"
			);
		} else {
			$title_standard = $this -> makeLabel (
				"$label ( $type )"
			);
			$title_failsafe = $this -> makeLabel (
				"Failsafe -- $label ( $type )"
			);
		}
		print FD "[defaultboot]"."\n";
		print FD "defaultmenu = menu"."\n\n";
		print FD ":menu"."\n";
		print FD "\t"."default = 1"."\n";
		print FD "\t"."prompt  = 1"."\n";
		print FD "\t"."target  = boot/zipl"."\n";
		print FD "\t"."timeout = 200"."\n";
		print FD "\t"."1 = $title_standard"."\n";
		print FD "\t"."2 = $title_failsafe"."\n\n";
		#==========================================
		# Standard boot
		#------------------------------------------
		print FD "[$title_standard]"."\n";
		if ($type =~ /^KIWI CD/) {
			$kiwi -> failed ();
			$kiwi -> error  ("*** zipl: CD boot not supported ***");
			$kiwi -> failed ();
			return undef;
		} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
			print FD "\t"."image   = boot/linux.vmx"."\n";
			print FD "\t"."target  = boot/zipl"."\n";
			print FD "\t"."ramdisk = boot/initrd.vmx,0x4000000"."\n";
		} else {
			print FD "\t"."image   = boot/linux"."\n";
			print FD "\t"."target  = boot/zipl"."\n";
			print FD "\t"."ramdisk = boot/initrd,0x4000000"."\n";
		}
		print FD "\t"."parameters = \"loader=$bloader";
		print FD " $cmdline\""."\n";
		#==========================================
		# Failsafe boot
		#------------------------------------------
		print FD "[$title_failsafe]"."\n";
		if ($type =~ /^KIWI CD/) {
			$kiwi -> failed ();
			$kiwi -> error  ("*** zipl: CD boot not supported ***");
			$kiwi -> failed ();
			return undef;
		} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split/)) {
			print FD "\t"."image   = boot/linux.vmx"."\n";
			print FD "\t"."target  = boot/zipl"."\n";
			print FD "\t"."ramdisk = boot/initrd.vmx,0x4000000"."\n";
		} else {
			print FD "\t"."image   = boot/linux"."\n";
			print FD "\t"."target  = boot/zipl"."\n";
			print FD "\t"."ramdisk = boot/initrd,0x4000000"."\n";
		}
		print FD "\t"."parameters = \"x11failsafe loader=$bloader";
		print FD " $cmdline\""."\n";
		close FD;
		$kiwi -> done();
	}
	#==========================================
	# lilo
	#------------------------------------------
	if ($loader eq "lilo") {
		$cmdline =~ s/\n//g;
		my $title_standard;
		$title_standard = $this -> makeLabel ("$label");
		#==========================================
		# Standard boot
		#------------------------------------------
		qxx ("mkdir -p $tmpdir/etc");
		if (! open (FD,">$tmpdir/etc/yaboot.conf")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create yaboot.conf: $!");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# CD NON-LVM BOOT
		#-------------------------------------------
		if (($type =~ /^KIWI CD/) && (!$lvm)) {
			print FD "default = $title_standard\n";
			print FD "image = /boot/linux\n";
			print FD "\t"."label = $title_standard\n";
			print FD "\t"."append = \"$cmdline\"\n";
			print FD "\t"."initrd = /boot/initrd\n";
			close FD;
		} elsif (($type =~ /^KIWI CD/) && ($lvm)) {
			#==========================================
			# CD LVM Boot
			#-------------------------------------------
			print FD "default = $title_standard\n";
			print FD "image = /boot/linux\n";
			print FD "\t"."label = $title_standard\n";
			print FD "\t"."append = \"$cmdline\"\n";
			print FD "\t"."initrd = /boot/initrd\n";
			close FD;
		} elsif (!($type =~ /^KIWI CD/) && (!$lvm)) {
			#==========================================
			# RAW NON-LVM
			#------------------------------------------
			print FD "partition = 2\n";
			print FD "timeout = 80\n";
			print FD "default = $title_standard\n";
			print FD "image = /boot/linux.vmx"."\n";
			print FD "\t"."label = $title_standard\n";
			print FD "\t"."root = /dev/sda2\n";
			print FD "\t"."append = \"$cmdline\"\n";
			print FD "\t"."initrd = /boot/initrd.vmx\n";
			close FD;
		} elsif (!($type =~ /^KIWI CD/) && ($lvm)) {
			#==========================================
			# RAW LVM
			#-------------------------------------------
			print FD "default = $title_standard\n";
			print FD "image = linux.vmx"."\n";
			print FD "\t"."label = $title_standard\n";
			print FD "\t"."append = \"$cmdline\"\n";
			print FD "\t"."initrd = initrd.vmx\n";
			close FD;
		}
		#==========================================
		# Create bootinfo.txt (CD and LVM setups)
		#-------------------------------------------
		if ($type =~ /^KIWI CD/)  {
			qxx ("mkdir -p $tmpdir/ppc/");
			if (! open (FD,">$tmpdir/ppc/bootinfo.txt")) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create bootinfo.txt: $!");
				$kiwi -> failed ();
				return undef;
			}
			print FD "<chrp-boot>\n";
			print FD "<description>$title_standard</description>\n";
			print FD "<os-name>$title_standard</os-name>\n";
			print FD "<boot-script>boot &device;:1,\\suseboot\\yaboot.ibm";
			print FD "</boot-script>\n";
			print FD "</chrp-boot>\n";
			close FD;
			qxx ("mkdir $tmpdir/suseboot");
			qxx ("cp /lib/lilo/chrp/yaboot.chrp $tmpdir/suseboot/yaboot.ibm");
			qxx ("cp $tmpdir/etc/yaboot.conf $tmpdir/suseboot/yaboot.cnf");
		} elsif (!($type =~ /^KIWI CD/) && ($lvm)) {
			qxx ("mkdir -p $tmpdir/ppc/");
			if (! open (FD,">$tmpdir/ppc/bootinfo.txt")) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create bootinfo.txt: $!");
				$kiwi -> failed ();
				return undef;
			}
			print FD "<chrp-boot>\n";
			print FD "<description>$title_standard</description>\n";
			print FD "<os-name>$title_standard</os-name>\n";
			print FD "<boot-script>boot &device;:1,yaboot</boot-script>\n";
			print FD "</chrp-boot>\n";
			close FD;
		}
		$kiwi -> done ();
	}
	#==========================================
	# more boot managers to come...
	#------------------------------------------
	# ...
	return $this;
}

#==========================================
# installBootLoader
#------------------------------------------
sub installBootLoader {
	my $this     = shift;
	my $loader   = shift;
	my $diskname = shift;
	my $deviceMap= shift;
	my $kiwi     = $this->{kiwi};
	my $tmpdir   = $this->{tmpdir};
	my $bootpart = $this->{bootpart};
	my $chainload= $this->{chainload};
	my $lvm	     = $this->{lvm};
	my $cmdL     = $this->{cmdL};
	my $locator  = new KIWILocator($kiwi);
	my $result;
	my $status;
	#==========================================
	# Check for edit boot config
	#------------------------------------------
	if ($cmdL) {
		my $editBoot = $cmdL -> getEditBootConfig();
		if (($editBoot) && (-e $editBoot)) {
			system ("cd $tmpdir && bash --norc -c $editBoot");
		}
	}
	#==========================================
	# Check boot partition number
	#------------------------------------------
	if (! defined $bootpart) {
		$bootpart = 0;
	}
	#==========================================
	# Grub
	#------------------------------------------
	if ($loader eq "grub") {
		$kiwi -> info ("Installing grub on device: $diskname");
		#==========================================
		# Clean loop maps
		#------------------------------------------
		$this -> cleanLoopMaps();
		$this -> cleanLoop();
		#==========================================
		# Create device map for the disk
		#------------------------------------------
		my $dmfile = "$tmpdir/grub-device.map";
		my $dmfd = new FileHandle;
		if (! $dmfd -> open(">$dmfile")) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't create grub device map: $!");
			$kiwi -> failed ();
			return undef;
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
			return undef;
		}
		print $dmfd "device (hd0) $diskname\n";
		print $dmfd "root (hd0,$bootpart)\n";
		if ($chainload) {
			print $dmfd "setup (hd0,0)\n";
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
			return undef;
		}
		my $grubOptions = "--device-map $dmfile --no-floppy --batch";
		qxx ("mount --bind $tmpdir/boot/grub /boot/grub");
		qxx ("$grub $grubOptions < $cmdfile &> $tmpdir/grub.log");
		qxx ("umount /boot/grub");
		my $glog;
		if ($dmfd -> open ("$tmpdir/grub.log")) {
			my @glog = <$dmfd>; $dmfd -> close();
			if ($dmfd -> open ("$cmdfile")) {
				my @cmdlog = <$dmfd>; $dmfd -> close();
				push @glog,"GRUB: commands:";
				push @glog,@cmdlog;
			}
			my $stage1 = grep { /^\s*Running.*succeeded$/ } @glog;
			my $stage1_5 = grep { /^\s*Running.*are embedded\.$/ } @glog;
			$result = !(($stage1 == 1) && ($stage1_5 == 1));
			$glog = join ("\n",@glog);
			$kiwi -> loginfo ("GRUB: $glog\n");
		}
		if ($result != 1) {
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
			return undef;
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
				return undef;
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
			#	return undef;
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
			#==========================================
			# zero out preload range
			#------------------------------------------
			$status = qxx (
				"dd if=/dev/zero of=$diskname bs=1 count=496 seek=512 $opt 2>&1"
			);
		}
		$kiwi -> done();
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader =~ /(sys|ext)linux/) {
		if (! $deviceMap) {
			$kiwi -> failed ();
			$kiwi -> error  ("No device map available");
			$kiwi -> failed ();
			return undef;
		}
		my %deviceMap = %{$deviceMap};
		my $device = $deviceMap{fat};
		if ($loader eq "extlinux") {
			$device = $deviceMap{extlinux};
		}
		if (($device =~ /mapper/) && (! -e $device)) {
			if (! $this -> bindDiskPartitions ($diskname)) {
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
		}
		if ($loader eq "syslinux") {
			$kiwi -> info ("Installing syslinux on device: $device");
			$status = qxx ("syslinux $device 2>&1");
			$result = $? >> 8;
		} else {
			$kiwi -> info ("Installing extlinux on device: $device");
			$status = qxx ("mount $device /mnt 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx ("extlinux --install /mnt/boot/syslinux 2>&1");
				$result = $? >> 8;
			}
			$status = qxx ("umount /mnt 2>&1");
		}
		if ($device =~ /mapper/) {
			$this -> cleanLoopMaps ($diskname);
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install $loader on $device: $status");
			$kiwi -> failed ();
			return undef;
		}
		my $syslmbr = "/usr/share/syslinux/mbr.bin";
		$status = qxx (
			"dd if=$syslmbr of=$diskname bs=512 count=1 conv=notrunc 2>&1"
		);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install syslinux MBR on $diskname");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Zipl
	#------------------------------------------
	if ($loader eq "zipl") {
		$kiwi -> info ("Installing zipl on device: $diskname");
		my $bootdev;
		my $offset;
		my $haveRealDevice = 0;
		if ($diskname !~ /\/dev\//) {
			#==========================================
			# clean loop maps
			#------------------------------------------
			$this -> cleanLoop ();
			#==========================================
			# detect disk offset of disk image file
			#------------------------------------------
			$offset = $this -> diskOffset ($diskname);
			if (! $offset) {
				$kiwi -> failed ();
				$kiwi -> error  ("Failed to detect disk offset");
				$kiwi -> failed ();
				return undef;
			}
			#==========================================
			# loop mount disk image file
			#------------------------------------------
			if (! $this->bindDiskDevice ($diskname)) {
				return undef;
			}
			if (! $this -> bindDiskPartitions ($this->{loop})) {
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
			#==========================================
			# find boot partition
			#------------------------------------------
			$bootdev = $this->{bindloop}."2";
			if (! -e $bootdev) {
				$bootdev = $this->{bindloop}."1";
			} else {
				my $type = qxx ("blkid $bootdev -s TYPE -o value");
				if ($type =~ /LVM/) {
					$bootdev = $this->{bindloop}."1";
				}
			}
			if (! -e $bootdev) {
				$kiwi -> failed ();
				$kiwi -> error  ("Can't find loop map: $bootdev");
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
		} else {
			#==========================================
			# find boot partition
			#------------------------------------------
			$bootdev = $diskname."2";
			if (! -e $bootdev) {
				$bootdev = $diskname."1";
			} else {
				my $type = qxx ("blkid $bootdev -s TYPE -o value");
				if ($type =~ /LVM/) {
					$bootdev = $diskname."1";
				}
			}
			$haveRealDevice = 1;
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
			$this -> cleanLoop ();
			return undef;
		}
		my $mount = "/mnt";
		my $config = "$mount/boot/zipl.conf";
		if (! $haveRealDevice) {
			#==========================================
			# rewrite zipl.conf with additional params
			#------------------------------------------
			if (! open (FD,$config)) {
				$kiwi -> failed ();
				$kiwi -> error  ("Can't open config file for reading: $!");
				$kiwi -> failed ();
				qxx ("umount $mount 2>&1");
				$this -> cleanLoop ();
				return undef;
			}
			my @data = <FD>; close FD;
			if (! open (FD,">$config")) {
				$kiwi -> failed ();
				$kiwi -> error  ("Can't open config file for writing: $!");
				$kiwi -> failed ();
				qxx ("umount $mount 2>&1");
				$this -> cleanLoop ();
				return undef;
			}
			$kiwi -> loginfo ("zipl.conf target values:\n");
			foreach my $line (@data) {
				print FD $line;
				if ($line =~ /^:menu/) {
					$kiwi -> loginfo ("targetbase = $this->{loop}\n");
					$kiwi -> loginfo ("targetbase = SCSI\n");
					$kiwi -> loginfo ("targetblocksize = 512\n");
					$kiwi -> loginfo ("targetoffset = $offset\n");
					print FD "\t"."targetbase = $this->{loop}"."\n";
					print FD "\t"."targettype = SCSI"."\n";
					print FD "\t"."targetblocksize = 512"."\n";
					print FD "\t"."targetoffset = $offset"."\n";
				}
			}
			close FD;
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
			$this -> cleanLoop ();
			return undef;
		}
		qxx ("umount $mount 2>&1");
		$this -> cleanLoop ();
		$kiwi -> done();
	}
	#==========================================
	# install lilo
	#------------------------------------------
	if ($loader eq "lilo") {
		#==========================================
		# Activate devices
		#------------------------------------------
		if (! $this -> bindDiskPartitions ($this->{loop})) {
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		#==========================================
		# install yaboot on PReP partition
		#------------------------------------------
		if (!$lvm) {
			my %deviceMap = %{$deviceMap};
			my $device = $deviceMap{1};
			$kiwi -> info ("Installing yaboot on device: $device");
			$status = qxx ("dd if=/lib/lilo/chrp/yaboot.chrp of=$device 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't install yaboot on $device: $status");
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
		}
	}
	#==========================================
	# more boot managers to come...
	#------------------------------------------
	# ...
	#==========================================
	# Write custom disk label ID to MBR
	#------------------------------------------
	if ($loader ne "lilo") {
		$kiwi -> info ("Saving disk label in MBR: $this->{mbrid}...");
		if (! $this -> writeMBRDiskLabel ($diskname)) {
			return undef;
		}
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# bindDiskDevice
#------------------------------------------
sub bindDiskDevice {
	my $this   = shift;
	my $system = shift;
	my $kiwi   = $this->{kiwi};
	my $status;
	my $result;
	my $loop;
	#==========================================
	# bind file to loop device
	#------------------------------------------
	$status = qxx ("/sbin/losetup -s -f $system 2>&1"); chomp $status;
	$result = $? >> 8;
	if ($result != 0) {
		# /.../
		# first losetup call has failed, try to find free loop
		# device manually even though it's most likely that this
		# search will fail too. The following is only useful for
		# older version of losetup which doesn't understand the
		# option combination -s -f
		# ----
		my $loopfound = 0;
		for (my $id=0;$id<=7;$id++) {
			$status.= qxx ( "/sbin/losetup /dev/loop$id $system 2>&1" );
			$result = $? >> 8;
			if ($result == 0) {
				$loopfound = 1;
				$loop = "/dev/loop".$id;
				$this->{loop} = $loop;
				last;
			}
		}
		if (! $loopfound) {
			$kiwi -> loginfo ("Failed binding loop device: $status");
			return undef;
		}
		return $this;
	}
	$loop = $status;
	$this->{loop} = $loop;
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
	my $status;
	my $result;
	my $part;
	$status = qxx ("/sbin/kpartx -a $disk 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ("Failed mapping partition: $status");
		return undef;
	}
	$disk =~ s/dev\///;
	$part = "/dev/mapper".$disk."p";
	$this->{bindloop} = $part;
	return $this;
}

#==========================================
# checkLVMbind
#------------------------------------------
sub checkLVMbind {
	# ...
	# check if the volume group was activated due to a
	# previos call of kpartx. In this case the image has
	# LVM enabled and we have to use the LVM devices
	# ---
	my $this = shift;
	my $sdev = shift;
	my $disk = shift;
	my @groups;
	#==========================================
	# check for lvm flag on disk
	#------------------------------------------
	if (! $this-> __getPartID ($disk,"lvm")) {
		return $sdev;
	}
	#==========================================
	# activate volume groups
	#------------------------------------------
	open (my $SCAN,"vgscan 2>/dev/null |");
	while (my $line = <$SCAN>) {
		if ($line =~ /\"(.*)\"/) {
			push (@groups,$1);
		}
	}
	close $SCAN;
	#==========================================
	# check the device node names for kiwi lvm
	#------------------------------------------
	foreach my $lvmgroup (@groups) {
		qxx ("vgchange -a y $lvmgroup 2>&1");
		for (my $try=0;$try<=3;$try++) {
			if (defined (my $lvroot = glob ("/dev/mapper/*-LVRoot"))) {
				$this->{lvm} = 1;
				$sdev = $lvroot;
				if (defined ($lvroot = glob ("/dev/mapper/*-LVComp"))) {
					$sdev = $lvroot;
				}
				if ($lvroot =~ /mapper\/(.*)-.*/) {
					$this->{lvmgroup} = $1;
				}
				last;
			}
			sleep 1;
		}
		if ($this->{lvm} == 1) {
			last;
		}
	}
	return $sdev;
}

#==========================================
# getCylinderSizeAndCount
#------------------------------------------
sub getCylinderSizeAndCount {
	# ...
	# obtain cylinder size and count for the specified disk.
	# The function returns the size in kB (10^3 B) or zero on error
	# ---
	my $this = shift;
	my $disk = shift;
	my $kiwi = $this->{kiwi};
	my $status;
	my $result;
	my $parted;
	my $locator = new KIWILocator($kiwi);
	my $parted_exec = $locator -> getExecPath("parted");
	$status = qxx ("dd if=/dev/zero of=$disk bs=512 count=1 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	$status = qxx ("$parted_exec -s $disk mklabel msdos 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	$parted = "$parted_exec -m $disk unit cyl print";
	$status = qxx (
		"$parted | head -n 3 | tail -n 1 | cut -f4 -d: | tr -d 'kB;'"
	);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	chomp $status;
	$this->{pDiskCylinderSize} = $status;
	$status = qxx (
		"$parted | head -n 3 | tail -n 1 | cut -f1 -d:"
	);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	chomp $status;
	$this->{pDiskCylinders} = $status;
	$kiwi -> loginfo (
		"Disk Cylinder size is: $this->{pDiskCylinderSize} kB\n"
	);
	$kiwi -> loginfo (
		"Disk Cylinder count is: $this->{pDiskCylinders}\n"
	);
	return $status;
}

#==========================================
# getCylinder
#------------------------------------------
sub getCylinder {
	# ...
	# given a size in MB this function calculates the
	# aligned cylinder count according to the used disk
	# if no size is given the maximum value is used
	# ---
	my $this  = shift;
	my $size  = shift;
	my $csize = $this->{pDiskCylinderSize};
	my $count = $this->{pDiskCylinders};
	my $cyls;
	if (! defined $csize) {
		return 0;
	}
	if ($size =~ /\+(.*)M$/) {
		$cyls = sprintf ("%.0f",($size * 1048576) / ($csize * 1000));
	} else {
		$cyls = $count;
	}
	return $cyls;
}

#==========================================
# resetCylinder
#------------------------------------------
sub resetCylinder {
	# ...
	# reset global cylinder size and count
	# ---
	my $this = shift;
	undef $this->{pDiskCylinders};
	undef $this->{pDiskCylinderSize};
	undef $this->{pStart};
	undef $this->{pStopp};
	return $this;
}

#==========================================
# initCylinders
#------------------------------------------
sub initCylinders {
	# ...
	# calculate cylinder size and count for parted to create
	# the appropriate partition. On success the cylinder count
	# will be returned, on error zero is returned
	# ---
	my $this   = shift;
	my $device = shift;
	my $size   = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $cylsize= $this->{pDiskCylinderSize};
	my $secsize= 512;
	my $cyls   = 0;
	my $status;
	my $result;
	if (! defined $this->{pDiskCylinders}) {
		my $cylcount = $this -> getCylinderSizeAndCount($device);
		if ($cylcount == 0) {
			return 0;
		}
		$cylsize= $this->{pDiskCylinderSize};
	}
	$cyls = $this -> getCylinder ($size);
	if ($cyls == 0) {
		return 0;
	}
	if (! defined $this->{pStart}) {
		$cylsize *= 1024;
		$this->{pStart} = sprintf (
			"%.0f",(($cmdL->getDiskStartSector() * $secsize) / $cylsize)
		);
	} else {
		$this->{pStart} = $this->{pStopp};
	}
	$this->{pStopp} = $this->{pStart} + $cyls;
	if ($this->{pStopp} > $this->{pDiskCylinders}) {
		$this->{pStopp} = $this->{pDiskCylinders}
	}
	return $cyls;
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
	my $locator = new KIWILocator($kiwi);
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
				return undef;
			}
			if (! open (FD,"|/sbin/fdasd $device &> $tmpdir/fdasd.log")) {
				return undef;
			}
			print FD "y\n";
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
					print FD "\n";
				} else {
					print FD "$cmd\n";
				}
			}
			close FD;
			$result = $? >> 8;
			my $flog;
			if (open (FD,"$tmpdir/fdasd.log")) {
				my @flog = <FD>; close FD;
				$flog = join ("\n",@flog);
				$kiwi -> loginfo ("FDASD: $flog");
			}
			last SWITCH;
		};
		#==========================================
		# parted
		#------------------------------------------
		/^parted/  && do {
			my @p_cmd = ();
			$this -> resetCylinder();
			for (my $count=0;$count<@commands;$count++) {
				my $cmd = $commands[$count];
				if ($cmd eq "n") {
					my $size = $commands[$count+4];
					$this -> initCylinders ($device,$size);
					push (@p_cmd,
						"mkpart primary $this->{pStart} $this->{pStopp}"
					);
				}
				if ($cmd eq "t") {
					my $index= $commands[$count+1];
					my $type = $commands[$count+2];
					push (@p_cmd,"set $index type 0x$type");
				}
				if ($cmd eq "a") {
					my $index= $commands[$count+1];
					push (@p_cmd,"set $index boot on");
				}
			}
			$kiwi -> loginfo (
				"PARTED input: $device [@p_cmd]\n"
			);
			my $align="";
			$status = qxx ("$parted_exec --help | grep -q align=");
			$result = $? >> 8;
			if ($result == 0) {
				$align="-a cyl";
			}
			foreach my $p_cmd (@p_cmd) {
				$status= qxx (
					"$parted_exec $align -s $device unit cyl $p_cmd 2>&1"
				);
				$result= $? >> 8;
				$kiwi -> loginfo ($status);
				sleep (1);
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
# setPPCDeviceMap
#------------------------------------------
sub setPPCDeviceMap {
	# ...
	# set default devuce map for PowerSystems
	# ---
	my $this   = shift;
	my $device = shift;
	my $loader = $this->{bootloader};
	my $dmapper= $this->{dmapper};
	my $search = "41";
	my %result;
	if (! defined $device) {
		return undef;
	}
	for (my $i=1;$i<=3;$i++) {
		$result{$i} = $device.$i;
	}
	if ($loader eq "lilo") {
		for (my $i=1;$i<=2;$i++) {
			my $type = $this -> getStorageID ($device,$i);
			if ($type = $search) {
				$result{prep} = $device.$i;
			}
			last;
		}
	} elsif ($dmapper) {
		$result{dmapper} = $device."3";
	}
	return %result;
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
	my $loader = $this->{bootloader};
	my $dmapper= $this->{dmapper};
	my %result;
	if (! defined $device) {
		return undef;
	}
	for (my $i=1;$i<=3;$i++) {
		$result{$i} = $device.$i;
	}
	if ($loader =~ /(sys|ext)linux/) {
		my $search = "c";
		if ($loader eq "extlinux" ) {
			$search = "83";
		}
		for (my $i=3;$i>=1;$i--) {
			my $type = $this -> getStorageID ($device,$i);
			if ($type eq $search) {
				if ($loader eq "syslinux" ) {
					$result{fat} = $device.$i;
				} else {
					$result{extlinux} = $device.$i;
				}
				last;
			}
		}
	} elsif ($dmapper) {
		$result{dmapper} = $device."3";
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
	my $loader = $this->{bootloader};
	my $dmapper= $this->{dmapper};
	my %result;
	if (! defined $device) {
		return undef;
	}
	my $dmap = $device; $dmap =~ s/dev\///;
	for (my $i=1;$i<=3;$i++) {
		$result{$i} = "/dev/mapper".$dmap."p$i";
	}
	if ($loader =~ /(sys|ext)linux/) {
		my $search = "c";
		if ($loader eq "extlinux" ) {
			$search = "83";
		}
		for (my $i=3;$i>=1;$i--) {
			my $type = $this -> getStorageID ($device,$i);
			if ("$type" eq "$search") {
				if ($loader eq "syslinux") {
					$result{fat} = "/dev/mapper".$dmap."p$i";
				} else {
					$result{extlinux} = "/dev/mapper".$dmap."p$i";
				}
				last;
			}
		}
	} elsif ($dmapper) {
		$result{dmapper} = "/dev/mapper".$dmap."p3";
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
	my $arch   = $this->{arch};
	my $loader = $this->{bootloader};
	my $dmapper= $this->{dmapper};
	my %result;
	if (! defined $group) {
		return undef;
	}
	if ($device =~ /loop/) {
		my $dmap = $device; $dmap =~ s/dev\///;
		$result{0} = "/dev/mapper".$dmap."p1";
	} else {
		$result{0} = $device."1";
	}
	for (my $i=0;$i<@names;$i++) {
		$result{$i+1} = "/dev/$group/".$names[$i];
	}
	if (($arch =~ /ppc|ppc64/) || ($loader =~ /(sys|ext)linux/)) {
		if ($device =~ /loop/) {
			my $dmap = $device; $dmap =~ s/dev\///;
			if (($arch =~ /ppc|ppc64/) || ($loader =~ /syslinux/)) {
				$result{fat} = "/dev/mapper".$dmap."p1";
			} else {
				$result{extlinux} = "/dev/mapper".$dmap."p1";
			}
		} else {
			if ($loader eq "syslinux") {
				$result{fat} = $device."1";
			} else {
				$result{extlinux} = $device."1";
			}
		}
	} elsif ($dmapper) {
		if ($device =~ /loop/) {
			my $dmap = $device; $dmap =~ s/dev\///;
			$result{dmapper} = "/dev/mapper".$dmap."p1";
		} else {
			$result{dmapper} = $device."1";
		}
	}
	return %result;
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
	my $kiwi      = $this->{kiwi};
	my $system    = $this->{system};
	my %deviceMap = %{$map};
	my %lvmparts  = %{$parts};
	my $VGroup    = $this->{lvmgroup};
	my %newmap;
	my $status;
	my $result;
	$status = qxx ("vgremove --force $VGroup 2>&1");
	$status = qxx ("test -d /dev/$VGroup && rm -rf /dev/$VGroup 2>&1");
	$status = qxx ("pvcreate $deviceMap{2} 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating physical extends: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$status = qxx ("vgcreate $VGroup $deviceMap{2} 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating volume group: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	if (($syszip) || ($haveSplit)) {
		$status = qxx ("lvcreate -L $syszip -n LVComp $VGroup 2>&1");
		$result = $? >> 8;
		$status.= qxx ("lvcreate -l +100%FREE -n LVRoot $VGroup 2>&1");
		$result+= $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Logical volume(s) setup failed: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
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
				$ihash{$lvdev} = "no-opts";
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
			$this -> cleanLoop ();
			return undef;
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
	my $this = shift;
	my $label = shift;
	$label =~ s/ /_/g;
	return $label;
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
		return undef;
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
		return undef;
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
		return undef;
	}
	if (! open ($MOUNTS, '<', '/proc/mounts')) {
		$kiwi -> loginfo ("umountDevice: failed to open proc/mounts: $!");
		return undef;
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
	my $inodes = $this->{deviceinodes};
	my $kiwi   = $this->{kiwi};
	my $xml    = $this->{xml};
	my $cmdL   = $this->{cmdL};
	my %type   = %{$xml->getImageTypeAndAttributes()};
	my %FSopts = $main::global -> checkFSOptions(
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
			my $fstool = "mkfs.".$fstype;
			if ($this->{inodes}) {
				$fsopts.= " -N $this->{inodes}";
			}
			my $tuneopts = $type{fsnocheck} eq "true" ? "-c 0 -i 0" : "";
			$tuneopts = $FSopts{extfstune} if $FSopts{extfstune};
			$status = qxx ("$fstool $fsopts $device 2>&1");
			$result = $? >> 8;
			if (!$result && $tuneopts) {
				$status .= qxx ("/sbin/tune2fs $tuneopts $device 2>&1");
				$result = $? >> 8;
			}
			last SWITCH;
		};
		/^reiserfs/ && do {
			$kiwi -> info ("Creating reiserfs $name filesystem");
			my $fsopts = $FSopts{reiserfs};
			$fsopts.= "-f";
			$status = qxx (
				"/sbin/mkreiserfs $fsopts $device 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		/^btrfs/    && do {
			$kiwi -> info ("Creating btrfs $name filesystem");
			my $fsopts = $FSopts{btrfs};
			$status = qxx (
				"/sbin/mkfs.btrfs $fsopts $device 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		/^xfs/      && do {
			$kiwi -> info ("Creating xfs $name filesystem");
			my $fsopts = $FSopts{xfs};
			$status = qxx (
				"/sbin/mkfs.xfs $fsopts $device 2>&1"
			);
			$result = $? >> 8;
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported filesystem type: $fstype");
		$kiwi -> failed ();
		$this->{inodes} = $iorig;
		return undef;
	};
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create $fstype filesystem: $status");
		$kiwi -> failed ();
		$this->{inodes} = $iorig;
		return undef;
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
	my $bn;
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
	return undef unless $id;

	substr $bootnext, 0x1b8, 4, pack("V", $id);

	open $bn, ">$file" or return undef;
	print $bn $bootnext;
	close $bn;

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
		return undef;
	}
	return $offset;
}

#==========================================
# searchUSBStickDevice
#------------------------------------------
sub searchUSBStickDevice {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $device = $this->{device};
	my $stick;
	#==========================================
	# Find USB stick devices
	#------------------------------------------
	my %storage = $this -> getRemovableUSBStorageDevices();
	if (! %storage) {
		$kiwi -> error  ("Couldn't find any removable USB storage devices");
		$kiwi -> failed ();
		return undef;
	}
	my $prefix = $kiwi -> getPrefix (1);
	print STDERR $prefix,"Found following removable USB devices:\n";
	foreach my $dev (keys %storage) {
		print STDERR $prefix,"---> $storage{$dev} at $dev\n";
	}
	if (! defined $device) {
		#==========================================
		# Let the user select the device
		#------------------------------------------
		while (1) {
			$prefix = $kiwi -> getPrefix (1);
			print STDERR $prefix,"Your choice (enter device name): ";
			chomp ($stick = <>);
			my $found = 0;
			foreach my $dev (keys %storage) {
				if ($dev eq $stick) {
					$found = 1; last;
				}
			}
			if (! $found) {
				if ($stick) {
					print STDERR $prefix,"Couldn't find [ $stick ] in list\n";
				}
				next;
			}
			last;
		}
	} else {
		#==========================================
		# Check the given device
		#------------------------------------------
		$stick = $device;
		my $found = 0;
		foreach my $dev (keys %storage) {
			if ($dev eq $stick) {
				$found = 1; last;
			}
		}
		if (! $found) {
			print STDERR $prefix,"Couldn't find [ $stick ] in list\n";
			return undef;
		}
	}
	return $stick;
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
	return $this;
}

#==========================================
# Private methods
#------------------------------------------
#==========================================
# getBootSize
#------------------------------------------
sub __getBootSize {
	# ...
	# calculate required size of /boot. This is
	# needed if we have a separate boot partition
	# The function returns the size in M-Bytes
	# ---
	my $this   = shift;
	my $extend = shift;
	my $kiwi   = $this->{kiwi};
	my $boot   = $extend."/boot";
	my $bbytes = qxx ("du -s --block-size=1 $boot | cut -f1"); chomp $bbytes;
	# 3 times the size should be enough for kernel updates
	my $gotMB  = sprintf ("%.0f",(($bbytes / 1048576) * 3));
	my $minMB  = 150;
	if ($gotMB < $minMB) {
		$gotMB = $minMB;
	}
	$kiwi -> loginfo ("Set boot space to: ".$gotMB."M\n");
	return $gotMB;
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
	my $locator   = new KIWILocator($kiwi);
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
				return undef;
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
				return undef;
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
				return undef;
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
				return undef;
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
		return undef;
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
	my $cmdlBytes = 0;
	my $vmsize    = 0;
	my $vmmbyte   = 0;
	#===========================================
	# turn optional size from cmdline into bytes
	#-------------------------------------------
	if ($cmdlsize =~ /^(\d+)([MG])$/i) {
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
	# adapt min size according to cmdline or XML
	#-------------------------------------------
	if ($cmdlBytes > 0) {
		if ($cmdlBytes < $minBytes) {
			$kiwi -> warning (
				"given size is smaller than calculated min size"
			);
			$kiwi -> oops();
		}
		$minBytes = $cmdlBytes;
	} elsif ($XMLBytes > 0) {
		if ($XMLBytes < $minBytes) {
			$kiwi -> warning (
				"given size is smaller than calculated min size"
			);
			$kiwi -> oops();
		}
		$minBytes = $XMLBytes;
	}
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
	my $fd   = new FileHandle;
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

1;
