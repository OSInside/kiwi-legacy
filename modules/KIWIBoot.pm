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
# DESCRIPTION   : This module is used to create a boot usb stick
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
use KIWI::dbusdevice;
use KIWILog;
use KIWIIsoLinux;
use FileHandle;
use File::Basename;
use File::Spec;
use Math::BigFloat;
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
	my $system = shift;
	my $vmsize = shift;
	my $device = shift;
	my $format = shift;
	my $lvm    = shift;
	my $profile= shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $syszip    = 0;
	my $sysird    = 0;
	my $zipped    = 0;
	my $vga       = "0x314";
	my $vgroup    = "kiwiVG";
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
		$kiwi = new KIWILog();
	}
	#==========================================
	# check initrd file parameter
	#------------------------------------------
	if (! -f $initrd) {
		$kiwi -> error  ("Couldn't find initrd file: $initrd");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# check system image file parameter
	#------------------------------------------
	if (defined $system) {
		if (-f $system) {
			my %fsattr = main::checkFileSystem ($system);
			if ($fsattr{readonly}) {
				$syszip = -s $system;
			} else {
				$syszip = 0;
			}
		} elsif (! -d $system) {
			$kiwi -> error  ("Couldn't find image file/directory: $system");
			$kiwi -> failed ();
			return undef;
		}
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
	if (! -f $kernel) {
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
	#==========================================
	# Store object data (1)
	#------------------------------------------
	$this->{tmpdir}   = $tmpdir;
	$this->{loopdir}  = $loopdir;
	$this->{lvmgroup} = $vgroup;

	#==========================================
	# setup pointer to XML configuration
	#------------------------------------------
	if (defined $system) {
		if (-d $system) {
			$xml = new KIWIXML (
				$kiwi,$system."/image",undef,$main::SetImageType,$profile
			);
		} else {
			my %fsattr = main::checkFileSystem ($system);
			if ((! $fsattr{type}) || ($fsattr{type} eq "auto")) {
				#==========================================
				# bind $system to loop device
				#------------------------------------------
				$kiwi -> info ("Binding virtual disk to loop device");
				if (! $this -> bindLoopDevice($system)) {
					$kiwi -> failed ();
					$this -> cleanTmp ();
					return undef;
				}
				$kiwi -> done();
				#==========================================
				# setup device mapper
				#------------------------------------------
				$kiwi -> info ("Setup device mapper on image file");
				$status = qxx ( "/sbin/kpartx -a $this->{loop} 2>&1" );
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("Failed mapping vpartitions: $status");
					$kiwi -> failed ();
					$this -> cleanLoop ();
					return undef;
				}
				$kiwi -> done();
				#==========================================
				# find partition and mount it
				#------------------------------------------
				my $dmap = $this->{loop}; $dmap =~ s/dev\///;
				my $sdev = "/dev/mapper".$dmap."p1";
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
				if (! main::mount($sdev, $tmpdir)) {
					$kiwi -> error ("System image mount failed: $status");
					$kiwi -> failed ();
					$this -> cleanLoop ();
					return undef;
				}
				#==========================================
				# read disk image XML description
				#------------------------------------------
				$xml = new KIWIXML (
					$kiwi,$tmpdir."/image",undef,$main::SetImageType,$profile
				);
				#==========================================
				# clean up
				#------------------------------------------
				$this -> cleanLoop ("keep-mountpoints");
			} else {
				#==========================================
				# loop mount system image
				#------------------------------------------
				if (! main::mount ($system,$tmpdir)) {
					$this -> cleanTmp ();
					return undef;
				}
				#==========================================
				# read disk image XML description
				#------------------------------------------
				$xml = new KIWIXML (
					$kiwi,$tmpdir."/image",undef,$main::SetImageType,$profile
				);
				#==========================================
				# clean up
				#------------------------------------------
				main::umount();
			}
		}
		if (! defined $xml) {
			$this -> cleanTmp ();
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
	if (defined $system) {
		my $sizeBytes;
		my $minInodes;
		my $sizeXMLBytes = 0;
		my $cmdlBytes    = 0;
		my $spare        = 1.5;
		my $journal      = 12 * 1024 * 1024;
		#==========================================
		# Calculate minimum size of the system
		#------------------------------------------
		if (-d $system) {
			# System is specified as a directory...
			$minInodes = qxx ("find $system | wc -l");
			$sizeBytes = qxx ("du -s --block-size=1 $system | cut -f1");
			chomp $minInodes;
			chomp $sizeBytes;
			$minInodes*= 2;
			$sizeBytes+= $minInodes * $main::FSInodeSize;
			$sizeBytes*= $spare;
			$sizeBytes+= $journal;
		} else {
			# system is specified as a file...
			$sizeBytes = -s $system;
			$sizeBytes*= 1.1;
		}
		#==========================================
		# Decide for a size prefer 1)cmdline 2)XML
		#------------------------------------------
		my $sizeXMLAddBytes = $xml -> getImageSizeAdditiveBytes();
		if ($sizeXMLAddBytes) {
			$sizeXMLBytes = $sizeBytes + $sizeXMLAddBytes;
		} else {
			$sizeXMLBytes = $xml -> getImageSizeBytes();
		}
		if ($vmsize =~ /^(\d+)([MG])$/i) {
			my $value= $1;
			my $unit = $2;
			if ($unit eq "G") {
				# convert GB to MB...
				$value *= 1024;
			}
			# convert MB to Byte
			$cmdlBytes = $value * 1048576;
		}
		if ($cmdlBytes > $sizeBytes) {
			$sizeBytes = $cmdlBytes;
		} elsif ($sizeXMLBytes > $sizeBytes) {
			$sizeBytes = $sizeXMLBytes;
		}
		#==========================================
		# Sum up system + kernel + initrd
		#------------------------------------------
		# /.../
		# if system is a split system the vmsize will be
		# adapted within the image creation function accordingly
		# ----
		my $kernelSize = -s $kernel;
		my $initrdSize = -s $initrd;
		$vmsize = $kernelSize + $initrdSize + $sizeBytes;
		#==========================================
		# Calculate required inode count for root
		#------------------------------------------
		if (-d $system) {
			# /.../
			# if the system is a directory the root filesystem
			# will be created during the image creation. In this
			# case we need to create the inode count
			# ----
			$this->{inodes} = int ($sizeBytes / $main::FSInodeRatio);
			$kiwi -> loginfo (
				"Using ".$this->{inodes}." inodes for the root filesystem\n"
			);
		}
		#==========================================
		# Create vmsize MB string and vmmbyte value
		#------------------------------------------
		$vmsize  = $vmsize / 1048576;
		$vmsize  = sprintf ("%.0f", $vmsize);
		$vmmbyte = $vmsize;
		$vmsize  = $vmsize."M";
		$kiwi -> loginfo (
			"Starting with disk size: $vmsize\n"
		);
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
	$this -> getMBRDiskLabel();
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
			$main::LuksCipher = $type{luks};
		}
	}
	#==========================================
	# Store object data (2)
	#------------------------------------------
	$this->{kiwi}      = $kiwi;
	$this->{initrd}    = $initrd;
	$this->{system}    = $system;
	$this->{kernel}    = $kernel;
	$this->{vmmbyte}   = $vmmbyte;
	$this->{vmsize}    = $vmsize;
	$this->{syszip}    = $syszip;
	$this->{device}    = $device;
	$this->{format}    = $format;
	$this->{zipped}    = $zipped;
	$this->{isxen}     = $isxen;
	$this->{xengz}     = $xengz;
	$this->{arch}      = $arch;
	$this->{ptool}     = $main::Partitioner;
	$this->{chainload} = $main::GrubChainload;
	$this->{lvm}       = $lvm;
	$this->{vga}       = $vga;
	$this->{xml}       = $xml;
	$this->{xendomain} = $xendomain;
	$this->{profile}   = $profile;
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
			qxx ("$main::Gzip -d $initrd && $main::Gzip $irdunc");
		}
		$status = qxx ( "cp $initrd $tmpdir/boot/$iname 2>&1" );
	} else {
		$status = qxx ( "cat $initrd | $main::Gzip > $tmpdir/boot/$iname" );
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing initrd: $!");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$status = qxx ( "cp $kernel $tmpdir/boot/$lname 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing kernel: $!");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	if (($isxen) && ($xendomain eq "dom0")) {
		$status = qxx ( "cp $xengz $tmpdir/boot/$xname 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing Xen dom0 kernel: $!");
			$kiwi -> failed ();
			$this -> cleanTmp ();
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
# setupBootStick
#------------------------------------------
sub setupBootStick {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $arch      = $this->{arch};
	my $tmpdir    = $this->{tmpdir};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $syszip    = $this->{syszip};
	my $device    = $this->{device};
	my $loopdir   = $this->{loopdir};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $lvm       = $this->{lvm};
	my $profile   = $this->{profile};
	my %deviceMap = ();
	my @commands  = ();
	my $imgtype   = "usb";
	my $haveSplit = 0;
	my $haveTree  = 0;
	my $lvmbootMB = 0;
	my $luksbootMB= 0;
	my $syslbootMB= 0;
	my $dmbootMB  = 0;
	my $dmapper   = 0;
	my $haveluks  = 0;
	my $bootloader= "grub";
	my $lvmsize;
	my $syslsize;
	my $dmsize;
	my $lukssize;
	my $FSTypeRW;
	my $FSTypeRO;
	my $status;
	my $result;
	my $hald;
	my $xml;
	my %lvmparts;
	my $root;
	#==========================================
	# check if system is tree or image file
	#------------------------------------------
	if ( -d $system ) {
		#==========================================
		# check image type
		#------------------------------------------
		if (-f "$system/rootfs.tar") {
			$kiwi -> error ("Can't use split root tree, run create first");
			$kiwi -> failed ();
			return undef;
		}
		$xml = new KIWIXML ( $kiwi,$system."/image",undef,$imgtype,$profile );
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
		$haveTree = 1;
	} else {
		if (! main::mount ($system,$tmpdir)) {
			$this -> cleanTmp ();
			return undef;
		}
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
		}
		$xml = new KIWIXML ( $kiwi,$tmpdir."/image",undef,$imgtype,$profile );
		main::umount();
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
	}
	#==========================================
	# load type attributes...
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes()};
	#==========================================
	# use lvm together with system image only
	#------------------------------------------
	if (! defined $system) {
		undef $type{lvm};
		undef $lvm;
	}
	#==========================================
	# Check for LVM...
	#------------------------------------------
	if (($type{lvm} =~ /true|yes/i) || ($lvm)) {
		#==========================================
		# add boot space if lvm based
		#------------------------------------------
		$lvm = 1;
		$lvmbootMB  = 60;
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
				$this -> cleanTmp ();
				return undef;
			}
			foreach my $vol (keys %lvmparts) {
				#==========================================
				# check directory per volume
				#------------------------------------------
				my $pname  = $vol; $pname =~ s/_/\//g;
				if (! -d "$system/$pname") {
					$kiwi -> error ("Directory $system/$pname does not exist");
					$kiwi -> failed ();
					$this -> cleanTmp ();
					return undef;
				}
			}
		}
	}
	#==========================================
	# check for device mapper snapshot / clicfs
	#------------------------------------------
	if ($type{filesystem} eq "clicfs") {
		$this->{dmapper} = 1;
		$dmapper  = 1;
		$dmbootMB = 60;
	}
	#==========================================
	# check for LUKS extension
	#------------------------------------------
	if ($type{luks}) {
		$haveluks   = 1;
		$luksbootMB = 60;
	}
	#==========================================
	# setup boot loader type
	#------------------------------------------
	if ($type{bootloader}) {
		$bootloader = $type{bootloader};
	}
	$this->{bootloader} = $bootloader;
	$this->{imgtype}    = $imgtype;
	#==========================================
	# add boot space if syslinux based
	#------------------------------------------
	if ($bootloader =~ /(sys|ext)linux/) {
		$syslbootMB= 60;
	}
	#==========================================
	# check image split portion
	#------------------------------------------
	my $destdir  = dirname ($initrd);
	my $label    = $xml -> getImageDisplayName();
	my $version  = $xml -> getImageVersion();
	my $diskname = $xml -> getImageName();
	my $splitfile= $destdir."/".$diskname."-read-write.".$arch."-".$version;
	if ($imgtype eq "split") {
		if (-f $splitfile) {
			$haveSplit = 1;
		}
	}
	#==========================================
	# set boot partition number
	#------------------------------------------
	my $bootpart = "0";
	if (($syszip) || ($haveSplit) || ($lvm) || ($haveluks)) {
		$bootpart = "1";
	}
	if ((($syszip) || ($haveSplit)) && ($haveluks)) {
		$bootpart = "2";
	}
	if (($dmapper) && ($lvm)) {
		$bootpart = "1";
	} elsif ($dmapper) {
		$bootpart = "2"
	}
	$this->{bootpart} = $bootpart;
	$this->{bootlabel}= $label;
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
	#==========================================
	# Create Stick boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# Find USB stick devices
	#------------------------------------------
	my %storage = $this -> getRemovableUSBStorageDevices();
	if (! %storage) {
		$kiwi -> error  ("Couldn't find any removable USB storage devices");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	my $prefix = $kiwi -> getPrefix (1);
	print STDERR $prefix,"Found following removable USB devices:\n";
	foreach my $dev (keys %storage) {
		print STDERR $prefix,"---> $storage{$dev} at $dev\n";
	}
	my $stick;
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
			$this -> cleanTmp ();
			return undef;
		}
	}
	#==========================================
	# Creating boot loader configuration
	#------------------------------------------
	if (! $this -> setupBootLoaderConfiguration ($bootloader,"USB")) {
		return undef;
	}
	#==========================================
	# umount stick mounted by hal before lock
	#------------------------------------------
	$this -> umountDevice ($stick);
	#==========================================
	# Wait for umount to settle
	#------------------------------------------
	sleep (1);
	#==========================================
	# Establish HAL lock for $stick
	#------------------------------------------
	$kiwi -> info ("Establish HAL lock for: $stick");
	$hald = new KIWI::dbusdevice::HalConnection;
	if (! $hald -> open()) {
		$kiwi -> failed  ();
		$kiwi -> warning ($hald->state());
		$kiwi -> skipped ();
	} else {
		$this -> {hald} = $hald;
		if ($hald -> lock($stick)) {
			$kiwi -> failed  ();
			$kiwi -> warning ($hald->state());
			$kiwi -> skipped ();
		} else {
			$this -> {stick} = $stick;
			$kiwi -> loginfo ("HAL:".$hald->state());
			$kiwi -> done();
		}
	}
	#==========================================
	# Check if system fits on storage device
	#------------------------------------------
	my $hardSize = $this -> getStorageSize ($stick);
	my $softSize = -s $system;
	if (-f $splitfile) {
		$softSize += -s $splitfile;
	}
	$softSize /= 1024;
	$softSize += $lvmbootMB + $luksbootMB + $syslbootMB + $dmbootMB;
	if ($hardSize < $softSize) {
		$kiwi -> error  ("Stick too small: got $hardSize kB need $softSize kB");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# Create new partition table on stick
	#------------------------------------------
	$kiwi -> info ("Creating partition table on: $stick");
	while (1) {
		if (defined $system) {
			if (! $lvm) {
				if (($syszip) || ($haveSplit) || ($dmapper)) {
					if ($bootloader =~ /(sys|ext)linux/) {
						my $partid = 6;
						if ($bootloader eq "extlinux" ) {
							$partid = 83;
						}
						$syslsize = $hardSize;
						$syslsize /= 1024;
						$syslsize -= $syszip;
						$syslsize -= $syslbootMB;
						$syslsize = sprintf ("%.f",$syslsize);
						@commands = (
							"n","p","1",".","+".$syszip."M",
							"n","p","2",".","+".$syslsize."M",
							"n","p","3",".",".",
							"t","1","83",
							"t","2","83",
							"t","3",$partid,
							"a","3","w","q"
						);
					} elsif ($dmapper) {
						$dmsize = $hardSize;
						$dmsize /= 1024;
						$dmsize -= $syszip;
						$dmsize -= $dmbootMB;
						$dmsize = sprintf ("%.f",$dmsize);
						@commands = (
							"n","p","1",".","+".$syszip."M",
							"n","p","2",".","+".$dmsize."M",
							"n","p","3",".",".",
							"t","1","83",
							"t","2","83",
							"t","3","83",
							"a","3","w","q"
						);
					} elsif ($haveluks) {
						$lukssize = $hardSize;
						$lukssize /= 1024;
						$lukssize -= $syszip;
						$lukssize -= $luksbootMB;
						$lukssize = sprintf ("%.f",$lukssize);
						@commands = (
							"n","p","1",".","+".$syszip."M",
							"n","p","2",".","+".$lukssize."M",
							"n","p","3",".",".",
							"t","1","83",
							"t","2","83",
							"t","3","83",
							"a","3","w","q"
						);
					} else {
						@commands = (
							"n","p","1",".","+".$syszip."M",
							"n","p","2",".",".",
							"t","1","83",
							"t","2","83",
							"a","2","w","q"
						);
					}
				} else {
					if ($bootloader =~ /(sys|ext)linux/) {
						my $partid = 6;
						if ($bootloader eq "extlinux" ) {
							$partid = 83;
						}
						$syslsize = $hardSize;
						$syslsize /= 1024;
						$syslsize -= $syslbootMB;
						$syslsize = sprintf ("%.f",$syslsize);
						@commands = (
							"n","p","1",".","+".$syslsize."M","t","83",
							"n","p","2",".",".","t","2",$partid,
							"a","2","w","q"
						);
					} elsif ($haveluks) {
						$lukssize = $hardSize;
						$lukssize /= 1024;
						$lukssize -= $luksbootMB;
						$lukssize = sprintf ("%.f",$lukssize);
						@commands = (
							"n","p","1",".","+".$lukssize."M","t","83",
							"n","p","2",".",".",
							"a","2","w","q"
						);
					} else {
						@commands = (
							"n","p","1",".",".","t","83",
							"a","1","w","q"
						);
					}
				}
			} else {
				$lvmsize = $hardSize;
				$lvmsize /= 1024;
				$lvmsize -= $lvmbootMB;
				$lvmsize = sprintf ("%.f",$lvmsize);
				if ($bootloader =~ /(sys|ext)linux/) {
					my $partid = 6;
					if ($bootloader eq "extlinux" ) {
						$partid = 83;
					}
					@commands = (
						"n","p","1",".","+".$lvmsize."M",
						"n","p","2",".",".",
						"t","1","8e",
						"t","2",$partid,
						"a","2","w","q"
					);
				} else {
					@commands = (
						"n","p","1",".","+".$lvmsize."M",
						"n","p","2",".",".",
						"t","1","8e",
						"t","2","83",
						"a","2","w","q"
					);
				}
			}
		} else {
			if ($bootloader =~ /(sys|ext)linux/) {
				my $partid = 6;
				if ($bootloader eq "extlinux" ) {
					$partid = 83;
				}
				$syslsize = $hardSize;
				$syslsize /= 1024;
				$syslsize -= $syslbootMB;
				$syslsize = sprintf ("%.f",$syslsize);
				@commands = (
					"n","p","1",".","+".$syslsize."M","t","83",
					"n","p","2",".",".","t","2",$partid,
					"a","2","w","q"
				);
			} else {
				@commands = (
					"n","p","1",".",".","t","83",
					"a","1","w","q"
				);
			}
		}
		if (! $this -> setStoragePartition ($stick,\@commands)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create partition table");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# Create default device mapping table
		#------------------------------------------
		%deviceMap = $this -> setDefaultDeviceMap ($stick);
		#==========================================
		# Umount possible mounted stick partitions
		#------------------------------------------
		$this -> umountDevice ($stick);
		for (my $try=0;$try>=2;$try++) {
			$status = qxx ( "/sbin/blockdev --rereadpt $stick 2>&1" );
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
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# Wait for new partition table to settle
		#------------------------------------------
		sleep (1);
		#==========================================
		# Umount possible mounted stick partitions
		#------------------------------------------
		$this -> umountDevice ($stick);
		#==========================================
		# setup volume group if requested
		#------------------------------------------
		if ($lvm) {
			%deviceMap = $this -> setVolumeGroup (
				\%deviceMap,$stick,$syszip,$haveSplit,\%lvmparts
			);
			if (! %deviceMap) {
				$this -> cleanDbus();
				$this -> cleanTmp ();
				return undef;
			}
		}
		#==========================================
		# check partition sizes
		#------------------------------------------
		if ((defined $system) && (($syszip) || ($haveSplit))) {
			my $sizeOK = 1;
			my $systemPSize = $this -> getStorageSize ($deviceMap{1});
			my $systemISize = -s $system; $systemISize /= 1024;
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
	# Dump system image on stick
	#------------------------------------------
	if (! $haveTree) {
		$kiwi -> info ("Dumping system image to stick");
		$status = qxx ( "umount $deviceMap{1} 2>&1" );
		$status = qxx ( "umount $deviceMap{2} 2>&1" );
		$status = qxx ("dd if=$system of=$deviceMap{1} bs=32k 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump system image to stick: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		if ($haveSplit) {
			$kiwi -> info ("Dumping split read/write part to stick");
			$status = qxx ("dd if=$splitfile of=$deviceMap{2} bs=32k 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't dump split file: $status");
				$kiwi -> failed ();
				$this -> cleanDbus();
				$this -> cleanTmp ();
				return undef;
			}
			$kiwi -> done();
		} 
	} else {
		#==========================================
		# Create fs on system image partition
		#------------------------------------------
		if (! $this -> setupFilesystem ($FSTypeRO,$deviceMap{1},"root")) {
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# Mount system image partition
		#------------------------------------------
		if (! main::mount($deviceMap{1}, $loopdir)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount partition: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanLoop ();
			return undef;
		}
		#==========================================
		# Create LVM volumes filesystems
		#------------------------------------------
		if (($lvm) && (%lvmparts)) {
			my $VGroup = $this->{lvmgroup};
			foreach my $name (keys %lvmparts) {
				my $device = "/dev/$VGroup/LV$name";
				my $pname  = $name; $pname =~ s/_/\//g;
				$status = qxx ("mkdir -p $loopdir/$pname 2>&1");
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error ("Can't create mount point $loopdir/$pname");
					$this -> cleanDbus();
					$this -> cleanLoop ();
					return undef;
				}
				if (! $this -> setupFilesystem ($FSTypeRO,$device,$pname)) {
					$this -> cleanDbus();
					$this -> cleanLoop ();
					return undef;
				}
				if (! main::mount ($device, "$loopdir/$pname")) {
					$this -> cleanDbus();
					$this -> cleanLoop ();
					return undef;
				}
			}
		}
		#==========================================
		# Copy root tree to virtual disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on stick");
		$status = qxx ("cp -a -x $system/* $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't copy image tree on stick: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Umount system image partition
		#------------------------------------------
		main::umount();
	}
	#==========================================
	# Check and resize filesystems
	#------------------------------------------
	$result = 0;
	undef $status;
	my $mapper = $deviceMap{1};
	my %fsattr = main::checkFileSystem ($deviceMap{1});
	if ($fsattr{type} eq "luks") {
		$mapper = $this -> luksResize ($deviceMap{1},"luks-resize");
		if (! $mapper) {
			$this -> luksClose();
			return undef;
		}
		%fsattr= main::checkFileSystem ($mapper);
	}
	SWITCH: for ($fsattr{type}) {
		/^ext\d/    && do {
			$kiwi -> info ("Resizing system $fsattr{type} filesystem");
			$status = qxx ("/sbin/resize2fs -f -F -p $mapper 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		/^reiserfs/ && do {
			$kiwi -> info ("Resizing system $fsattr{type} filesystem");
			$status = qxx ("/sbin/resize_reiserfs $mapper 2>&1");
			$result = $? >> 8;
			last SWITCH;
		}
	};
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't resize $fsattr{type} filesystem: $status");
		$kiwi -> failed ();
		$this -> luksClose();
		$this -> cleanDbus();
		$this -> cleanLoop ();
		$this -> cleanTmp ();
		return undef;
	}
	$this -> luksClose();
	if ($status) {
		$kiwi -> done();
	}
	if ($haveSplit) {
		$result = 0;
		undef $status;
		$mapper = $deviceMap{2};
		my %fsattr = main::checkFileSystem ($deviceMap{2});
		if ($fsattr{type} eq "luks") {
			$mapper = $this -> luksResize ($deviceMap{2},"luks-resize");
			if (! $mapper) {
				$this -> luksClose();
				return undef;
			}
			%fsattr= main::checkFileSystem ($mapper);
		}
		SWITCH: for ($fsattr{type}) {
			/^ext\d/    && do {
				$kiwi -> info ("Resizing split $fsattr{type} filesystem");
				$status = qxx ("/sbin/resize2fs -f -F -p $mapper 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Resizing split $fsattr{type} filesystem");
				$status = qxx ("/sbin/resize_reiserfs $mapper 2>&1");
				$result = $? >> 8;
				last SWITCH;
			}
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error("Couldn't resize $fsattr{type} filesystem: $status");
			$kiwi -> failed ();
			$this -> luksClose();
			$this -> cleanDbus();
			$this -> cleanLoop ();
			$this -> cleanTmp ();
			return undef;
		}
		$this -> luksClose();
		if ($status) {
			$kiwi -> done();
		}
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
				$this -> cleanDbus();
				$this -> cleanLoop ();
				return undef;
			}
			$status = qxx ("echo $cipher|cryptsetup luksOpen $root $name 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't open luks device: $status");
				$kiwi -> failed ();
				$this -> cleanDbus();
				$this -> cleanLoop ();
				return undef;
			}
			$root = "/dev/mapper/$name";
			$this->{luks} = $name;
		} else {
			$kiwi -> info ("Creating ext3 read-write filesystem");
		}
		my %FSopts = main::checkFSOptions();
		my $fsopts = $FSopts{ext3};
		$fsopts.= "-F";
		$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			$this -> luksClose();
			$this -> cleanDbus();
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
			$this -> cleanDbus();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
	} elsif (
		($dmapper) || ($haveluks) || ($lvm) || ($bootloader eq "extlinux")
	) {
		$root = $deviceMap{dmapper};
		$kiwi -> info ("Creating ext2 boot filesystem");
		if ($haveluks) {
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
		my %FSopts = main::checkFSOptions();
		my $fsopts = $FSopts{ext2};
		$fsopts.= "-F";
		$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Dump boot image on virtual disk
	#------------------------------------------
	$kiwi -> info ("Copying boot data to stick");
	#==========================================
	# Mount system image / or rw partition
	#------------------------------------------
	if ($bootloader eq "syslinux") {
		$root = $deviceMap{fat};
	} elsif ($bootloader eq "extlinux") {
		$root = $deviceMap{extlinux};
	} elsif ($dmapper) {
		$root = $deviceMap{dmapper};
	} elsif (($syszip) || ($haveSplit) || ($lvm)) {
		$root = $deviceMap{2};
		if ($haveluks) {
			$root = $deviceMap{3};
		}
		if ($lvm) {
			$root = $deviceMap{0};
		}
	} elsif ($haveluks) {
		$root = $deviceMap{2};
	} else {
		$root = $deviceMap{1};
	}
	if (! main::mount($root, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount stick image: $status");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanLoop ();
		return undef;
	}
	#==========================================
	# Copy boot data on system image
	#------------------------------------------
	$status = qxx ("rm -rf $loopdir/boot");
	$status = qxx ("cp -dR $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't copy boot data to stick: $status");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanLoop ();
		return undef;
	}
	main::umount();
	$kiwi -> done();
	#==========================================
	# deactivate volume group
	#------------------------------------------
	if ($lvm) {
		qxx ("vgchange -an $this->{lvmgroup} 2>&1");
	}
	#==========================================
	# Install boot loader on USB stick
	#------------------------------------------
	if (! $this -> installBootLoader ($bootloader, $stick, \%deviceMap)) {
		$this -> cleanDbus();
		$this -> cleanTmp ();
	}
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# Remove dbus lock on stick
	#------------------------------------------
	$kiwi -> info ("Removing HAL lock");
	$this -> cleanDbus();
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupInstallCD
#------------------------------------------
sub setupInstallCD {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $oldird    = $this->{initrd};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $xml       = $this->{xml};
	my $pinst     = $xml->getOEMPartitionInstall();
	my $md5name   = $system;
	my $imgtype   = "oem";
	my $gotsys    = 1;
	my $volid     = "-V \"KIWI CD/DVD Installation\"";
	my $bootloader= "grub";
	my $status;
	my $result;
	my $ibasename;
	my $tmpdir;
	my %type;
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
	my $basedir = dirname ($system);
	$tmpdir = qxx ( "mktemp -q -d $basedir/kiwicdinst.XXXXXX" ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$this->{tmpdir} = $tmpdir;
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# check if system image is given
	#------------------------------------------
	if (! defined $system) {
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
		#==========================================
		# bind $system to loop device
		#------------------------------------------
		$kiwi -> info ("Binding virtual disk to loop device");
		if (! $this -> bindLoopDevice($system)) {
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# setup device mapper
		#------------------------------------------
		$kiwi -> info ("Setup device mapper for virtual partition access");
		$status = qxx ( "/sbin/kpartx -a $this->{loop} 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed mapping virtual partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# find partition to check
		#------------------------------------------
		my $dmap = $this->{loop}; $dmap =~ s/dev\///;
		my $sdev = "/dev/mapper".$dmap."p1";
		if (! -e $sdev) {
			$sdev = "/dev/mapper".$dmap."p2";
		}
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
		if (! main::mount ($sdev, $tmpdir)) {
			$kiwi -> error ("Failed to mount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
			$this->{imgtype} = $imgtype;
		}
		$this -> cleanLoop("keep-mountpoints");
	}
	$this->{imgtype} = $imgtype;
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	$this -> buildMD5Sum ($system);
	#==========================================
	# Compress system image
	#------------------------------------------
	$md5name =~ s/\.raw$/\.md5/;
	if (! $pinst) {
		$kiwi -> info ("Compressing installation image...");
		$status = qxx ("$main::Gzip -f $system 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to compress system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		$system = $system.".gz";
	}
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $namecd = basename ($system);
	if ($gotsys) {
		my $suffix = '\.raw\.gz';
		if ($pinst) {
			$suffix = '\.raw';
		}
		if ($namecd !~ /(.*)-(\d+\.\d+\.\d+)$suffix$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		if (! $pinst) {
			$ibasename = $1.".gz";
		} else {
			$ibasename = $1;
		}
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	#==========================================
	# Create CD structure
	#------------------------------------------
	$this->{initrd} = $initrd;
	if (! $this -> createBootStructure()) {
		$this->{initrd} = $oldird;
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader,"iso")) {
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
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
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	#==========================================
	# Copy system image if given
	#------------------------------------------
	if ($gotsys) {
		if (! open (FD,">$tmpdir/config.isoclient")) {
			$kiwi -> error  ("Couldn't create CD install flag file");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		print FD "IMAGE=$ibasename\n";
		close FD;
		$kiwi -> info ("Importing system image: $system");
		$status = qxx ("cp $system $tmpdir/$ibasename 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		$status = qxx ("cp $md5name $tmpdir/$ibasename.md5 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system md5 sum: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
			$system =~ s/\.gz$//;
		}
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
		$opts = "-boot-load-size 4 -boot-info-table -udf -allow-limited-size";
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
		$opts = "-boot-load-size 4 -boot-info-table -udf -allow-limited-size";
	} else {
		# don't know how to use this bootloader together with isolinux
		$kiwi -> failed ();
		$kiwi -> error  ("Bootloader not supported for CD inst: $bootloader");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	my $wdir = qxx ("pwd"); chomp $wdir;
	if ($name !~ /^\//) {
		$name = $wdir."/".$name;
	}
	my $iso = new KIWIIsoLinux (
		$kiwi,$tmpdir,$name,undef,"checkmedia"
	);
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
		$this -> cleanTmp ();
		$iso  -> cleanISO ();
		return undef;
	}
	$kiwi -> done ();
	if (! $iso -> relocateCatalog ($name)) {
		$iso  -> cleanISO ();
		return undef;
	}
	#==========================================
	# Clean tmp
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	$kiwi -> info ("Created $name to be burned on CD");
	$kiwi -> done ();
	$this -> cleanTmp ();
	$iso  -> cleanISO ();
	return $this;
}

#==========================================
# setupInstallStick
#------------------------------------------
sub setupInstallStick {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $oldird    = $this->{initrd};
	my $vmsize    = $this->{vmsize};
	my $loopdir   = $this->{loopdir};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $xml       = $this->{xml};
	my $pinst     = $xml->getOEMPartitionInstall();
	my $irdsize   = -s $initrd;
	my $diskname  = $system.".install.raw";
	my $md5name   = $system;
	my %deviceMap = ();
	my @commands  = ();
	my $imgtype   = "oem";
	my $gotsys    = 1;
	my $bootloader= "grub";
	my $status;
	my $result;
	my $ibasename;
	my $tmpdir;
	my %type;
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
	#==========================================
	# check if initrd is zipped
	#------------------------------------------
	if (! $zipped) {
		$kiwi -> error  ("Compressed boot image required");
		$kiwi -> failed ();
		$this -> cleanTmp ();
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
		#==========================================
		# bind $system to loop device
		#------------------------------------------
		$kiwi -> info ("Binding virtual disk to loop device");
		if (! $this -> bindLoopDevice ($system)) {
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# setup device mapper
		#------------------------------------------
		$kiwi -> info ("Setup device mapper for virtual partition access");
		$status = qxx ( "/sbin/kpartx -a $this->{loop} 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed mapping virtual partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# find partition to check
		#------------------------------------------
		my $dmap = $this->{loop}; $dmap =~ s/dev\///;
		my $sdev = "/dev/mapper".$dmap."p1";
		if (! -e $sdev) {
			$sdev = "/dev/mapper".$dmap."p2";
		}
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
		if (! main::mount ($sdev, $tmpdir)) {
			$kiwi -> error  ("Failed to mount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
			$this->{imgtype} = $imgtype;
		}
		$this -> cleanLoop("keep-mountpoints");
	}
	$this->{imgtype} = $imgtype;
	$this->{bootpart}= 0;
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	$this -> buildMD5Sum ($system);
	#==========================================
	# Compress system image
	#------------------------------------------
	$md5name=~ s/\.raw$/\.md5/;
	if (! $pinst) {
		$kiwi -> info ("Compressing installation image...");
		$status = qxx ("$main::Gzip -f $system 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed to compress system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		$system = $system.".gz";
	}
	#==========================================
	# setup required disk size
	#------------------------------------------
	$irdsize= ($irdsize / 1e6) + 20;
	$irdsize= sprintf ("%.0f", $irdsize);
	$vmsize = -s $system;
	$vmsize = ($vmsize / 1e6) * 1.3 + $irdsize;
	$vmsize = sprintf ("%.0f", $vmsize);
	$vmsize = $vmsize."M";
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $nameusb = basename ($system);
	if ($gotsys) {
		my $suffix = '\.raw\.gz';
		if ($pinst) {
			$suffix = '\.raw';
		}
		if ($nameusb !~ /(.*)-(\d+\.\d+\.\d+)$suffix$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		if (! $pinst) {
			$ibasename = $1.".gz";
		} else {
			$ibasename = $1;
		}
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	$this->{initrd} = $initrd;
	#==========================================
	# Create Virtual Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this->{initrd} = $oldird;
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
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
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	$this->{initrd} = $oldird;
	#==========================================
	# create virtual disk
	#------------------------------------------
	$kiwi -> info ("Creating virtual disk...");
	$status = qxx ("qemu-img create $diskname $vmsize 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual disk: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	$kiwi -> done();
	$kiwi -> info ("Binding virtual disk to loop device");
	if (! $this -> bindLoopDevice ($diskname)) {
		$kiwi -> failed ();
		$this -> cleanTmp ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# create virtual disk partitions
	#------------------------------------------
	$kiwi -> info ("Create partition table for virtual disk");
	if ($gotsys) {
		@commands = (
			"n","p","1",".","+".$irdsize."M",
			"n","p","2",".",".",
			"a","1","w","q"
		);
	} else {
		@commands = (
			"n","p","1",".",".",
			"a","1","w","q"
		);
	}
	if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create partition table");
		$kiwi -> failed ();
		$this -> cleanLoop();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Create loop device mapping table
	#------------------------------------------
	%deviceMap = $this -> setLoopDeviceMap ($this->{loop});
	#==========================================
	# setup device mapper
	#------------------------------------------
	$kiwi -> info ("Setup device mapper for virtual partition access");
	$status = qxx ( "/sbin/kpartx -a $this->{loop} 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed mapping virtual partition: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	my $boot = $deviceMap{1};
	my $data;
	if ($gotsys) {
		$data = $deviceMap{2};
	}
	$kiwi -> done();
	#==========================================
	# Create filesystem on virtual partitions
	#------------------------------------------
	foreach my $root ($boot,$data) {
		next if ! defined $root;
		$kiwi -> info ("Creating ext3 filesystem on $root partition");
		my %FSopts = main::checkFSOptions();
		my $fsopts = $FSopts{ext3};
		$fsopts.= "-j";
		if (($root eq $data) && ($this->{inodes})) {
			$fsopts.= " -N $this->{inodes}";
		}
		$status = qxx ( "/sbin/mke2fs $fsopts $root 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy boot data on first partition
	#------------------------------------------
	$kiwi -> info ("Installing boot data to virtual disk");
	if (! main::mount ($boot, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount boot partition: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	$status = qxx ("cp -a $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install boot data: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		return undef;
	}
	main::umount();
	$kiwi -> done();
	#==========================================
	# Copy system image if defined
	#------------------------------------------
	if ($gotsys) {
		$kiwi -> info ("Installing image data to virtual disk");
		if (! main::mount($data, $loopdir)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount data partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		$status = qxx ("cp $system $loopdir/$ibasename 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		$status = qxx ("cp $md5name $loopdir/$ibasename.md5 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system md5 sum: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		if (! open (FD,">$loopdir/config.usbclient")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create USB install flag file");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			if (! $pinst) {
				qxx ( "$main::Gzip -d $system" );
			}
			return undef;
		}
		print FD "IMAGE=$ibasename\n";
		close FD;
		main::umount();
		if (! $pinst) {
			qxx ( "$main::Gzip -d $system" );
		}
		$kiwi -> done();
	}
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	$this -> cleanLoopMaps();
	#==========================================
	# Install boot loader on virtual disk
	#------------------------------------------
	if (! $this -> installBootLoader ($bootloader, $diskname, \%deviceMap)) {
		$this -> cleanLoop ();
		$this -> cleanTmp();
	}
	$this -> cleanLoop();
	$kiwi -> info ("Created $diskname to be dd'ed on Stick");
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupBootDisk
#------------------------------------------
sub setupBootDisk {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $arch      = $this->{arch};
	my $system    = $this->{system};
	my $vmsize    = $this->{vmsize};
	my $format    = $this->{format};
	my $syszip    = $this->{syszip};
	my $tmpdir    = $this->{tmpdir};
	my $initrd    = $this->{initrd};
	my $loopdir   = $this->{loopdir};
	my $zipped    = $this->{zipped};
	my $isxen     = $this->{isxen};
	my $lvm       = $this->{lvm};
	my $profile   = $this->{profile};
	my $diskname  = $system.".raw";
	my %deviceMap = ();
	my @commands  = ();
	my $imgtype   = "vmx";
	my $bootfix   = "VMX";
	my $haveTree  = 0;
	my $haveSplit = 0;
	my $lvmbootMB = 0;
	my $luksbootMB= 0;
	my $syslbootMB= 0;
	my $dmbootMB  = 0;
	my $dmapper   = 0;
	my $haveluks  = 0;
	my $bootloader= "grub";
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
	my $xml;
	my %lvmparts;
	#==========================================
	# check if image type is oem
	#------------------------------------------
	if ($initrd =~ /oemboot/) {
		$imgtype = "oem";
	}
	#==========================================
	# check if system is tree or image file
	#------------------------------------------
	if ( -d $system ) {
		#==========================================
		# check image type
		#------------------------------------------
		if (-f "$system/rootfs.tar") {
			$kiwi -> error ("Can't use split root tree, run create first");
			$kiwi -> failed ();
			return undef;
		}
		$xml = new KIWIXML ( $kiwi,$system."/image",undef,$imgtype,$profile );
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
		$haveTree = 1;
	} else {
		#==========================================
		# build disk name and label from xml data
		#------------------------------------------
		if (! main::mount ($system,$tmpdir)) {
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# check image type
		#------------------------------------------
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
		}
		$xml = new KIWIXML ( $kiwi,$tmpdir."/image",undef,$imgtype,$profile );
		main::umount();
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
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
		$lvmbootMB  = 60;
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
				$this -> cleanTmp ();
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
					$this -> cleanTmp ();
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
				if ($haveAbsolute) {
					$vmsize = $this->{vmmbyte} + 30 + $diff;
				} else {
					$vmsize = $this->{vmmbyte} + 30 + $space;
				}
				$vmsize = sprintf ("%.0f", $vmsize);
				$this->{vmmbyte} = $vmsize;
				$vmsize = $vmsize."M";
				$this->{vmsize}  = $vmsize;
				$kiwi->loginfo (
					"Increasing disk size to: $vmsize for volume $pname\n"
				);
			}
		}
	}
	#==========================================
	# check for device mapper snapshot / clicfs
	#------------------------------------------
	if ($type{filesystem} eq "clicfs") {
		$this->{dmapper} = 1;
		$dmapper  = 1;
		$dmbootMB = 60;
	}
	#==========================================
	# check for LUKS extension
	#------------------------------------------
	if ($type{luks}) {
		$haveluks   = 1;
		$luksbootMB = 60;
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
		$syslbootMB = 60;
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
	$this->{imgtype}  = $imgtype;
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
	# increase vmsize if image split portion
	#------------------------------------------
	if (($imgtype eq "split") && (-f $splitfile)) {
		my $splitsize = -s $splitfile; $splitsize /= 1048576;
		$vmsize = $this->{vmmbyte} + ($splitsize * 1.5) + $lvmbootMB;
		$vmsize = sprintf ("%.0f", $vmsize);
		$this->{vmmbyte} = $vmsize;
		$vmsize = $vmsize."M";
		$this->{vmsize}  = $vmsize;
		$haveSplit = 1;
	}
	#==========================================
	# increase vmsize if single boot partition
	#------------------------------------------
	if (($dmbootMB) || ($syslbootMB) || ($lvmbootMB)) {
		$vmsize = $this->{vmmbyte} + (($dmbootMB+$syslbootMB+$lvmbootMB) * 1.3);
		$vmsize = sprintf ("%.0f", $vmsize);
		$this->{vmmbyte} = $vmsize;
		$vmsize = $vmsize."M";
		$this->{vmsize}  = $vmsize;
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
	if ($haveTree) {
		my %fsattr = main::checkFileSystem ($FSTypeRW);
		if ($fsattr{readonly}) {
			$kiwi -> error ("Can't copy data into requested RO filesystem");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
	}
	#==========================================
	# Create Virtual Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# Setup boot partition ID
	#------------------------------------------
	my $bootpart = "0";
	if (($syszip) || ($haveSplit) || ($lvm) || ($haveluks)) {
		$bootpart = "1";
	}
	if ((($syszip) || ($haveSplit)) && ($haveluks)) {
		$bootpart = "2";
	}
	if (($dmapper) && ($lvm)) {
		$bootpart = "1";
	} elsif ($dmapper) {
		$bootpart = "2"
	}
	$this->{bootpart} = $bootpart;
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ($bootloader)) {
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# add extra Xen boot options if necessary
	#==========================================
	my $extra = "";
	if ($type{bootprofile} eq "xen") {
		$extra = "xencons=tty ";
	}
	#==========================================
	# Create boot loader configuration
	#------------------------------------------
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$bootfix,$extra)) {
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# create virtual disk
	#------------------------------------------
	$kiwi -> info ("Creating virtual disk...");
	my $dmap; # device map
	my $root; # root device
	while (1) {
		if (! defined $system) {
			$kiwi -> failed ();
			$kiwi -> error  ("No system image given");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}	
		$status = qxx ("qemu-img create $diskname $vmsize 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating virtual disk: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# setup loop device for virtual disk
		#------------------------------------------
		if (! $this -> bindLoopDevice($diskname)) {
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# create virtual disk partition
		#------------------------------------------
		if (! $lvm) {
			if (($syszip) || ($haveSplit) || ($dmapper)) {
				# xda1 ro / xda2 rw
				if ($bootloader =~ /(sys|ext)linux/) {
					my $partid = 6;
					if ($bootloader eq "extlinux" ) {
						$partid = 83;
					}
					my $syslsize = $this->{vmmbyte} - $syslbootMB - $syszip;
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".","+".$syslsize."M",
						"n","p","3",".",".",
						"t","3",$partid,
						"a","3","w","q"
					);
				} elsif ($dmapper) {
					my $dmsize = $this->{vmmbyte} - $dmbootMB - $syszip;
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".","+".$dmsize."M",
						"n","p","3",".",".",
						"a","3","w","q"
					);
				} elsif ($haveluks) {
					my $lukssize = $this->{vmmbyte} - $luksbootMB - $syszip;
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
					my $partid = 6;
					if ($bootloader eq "extlinux" ) {
						$partid = 83;
					}
					my $syslsize = $this->{vmmbyte} - $syslbootMB;
					@commands = (
						"n","p","1",".","+".$syslsize."M",
						"n","p","2",".",".",
						"t","2",$partid,
						"a","2","w","q"
					);
				} elsif ($haveluks) {
					my $lukssize = $this->{vmmbyte} - $luksbootMB;
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
				my $partid = 6;
				if ($bootloader eq "extlinux" ) {
					$partid = 83;
				}
				my $lvmsize = $this->{vmmbyte} - $syslbootMB;
				@commands = (
					"n","p","1",".","+".$lvmsize."M",
					"n","p","2",".",".",
					"t","2",$partid,
					"t","1","8e",
					"a","2","w","q"
				);
			} else {
				my $lvmsize = $this->{vmmbyte} - $lvmbootMB;
				@commands = (
					"n","p","1",".","+".$lvmsize."M",
					"n","p","2",".",".",
					"t","1","8e",
					"a","2","w","q"
				);
			}
		}
		if (! $this -> setStoragePartition ($this->{loop},\@commands)) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create partition table");
			$kiwi -> failed ();
			$this -> cleanLoop();
			return undef;
		}
		#==========================================
		# Create loop device mapping table
		#------------------------------------------
		%deviceMap = $this -> setLoopDeviceMap ($this->{loop});
		#==========================================
		# setup device mapper
		#------------------------------------------
		$status = qxx ( "/sbin/kpartx -a $this->{loop} 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed mapping virtual partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
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
		$root = $deviceMap{1};
		#==========================================
		# check partition sizes
		#------------------------------------------
		if ($syszip > 0) {
			my $sizeOK = 1;
			my $systemPSize = $this->getStorageSize ($deviceMap{1});
			my $systemISize = -s $system; $systemISize /= 1024;
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
	# Dump system image on virtual disk
	#------------------------------------------
	if (! $haveTree) {
		$kiwi -> info ("Dumping system image on virtual disk");
		$status = qxx ("dd if=$system of=$root bs=32k 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump image to virtual disk: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		$result = 0;
		undef $status;
		my $mapper = $root;
		my %fsattr = main::checkFileSystem ($root);
		if ($fsattr{type} eq "luks") {
			$mapper = $this -> luksResize ($root,"luks-resize");
			if (! $mapper) {
				$this -> luksClose();
				return undef;
			}
			%fsattr= main::checkFileSystem ($mapper);
		}
		SWITCH: for ($fsattr{type}) {
			/^ext\d/    && do {
				$kiwi -> info ("Resizing system $fsattr{type} filesystem");
				$status = qxx ("/sbin/resize2fs -f -F -p $mapper 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Resizing system $fsattr{type} filesystem");
				$status = qxx ("/sbin/resize_reiserfs $mapper 2>&1");
				$result = $? >> 8;
				last SWITCH;
			}
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  (
				"Couldn't resize $fsattr{type} filesystem $status"
			);
			$kiwi -> failed ();
			$this -> luksClose();
			$this -> cleanTmp ();
			return undef;
		}
		$this -> luksClose();
		if ($status) {
			$kiwi -> done();
		}
		if ($haveSplit) {
			$kiwi -> info ("Dumping split read/write part on virtual disk");
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
			undef $status;
			$mapper = $root;
			my %fsattr = main::checkFileSystem ($root);
			if ($fsattr{type} eq "luks") {
				$mapper = $this -> luksResize ($root,"luks-resize");
				if (! $mapper) {
					$this -> luksClose();
					return undef;
				}
				%fsattr= main::checkFileSystem ($mapper);
			}
			SWITCH: for ($fsattr{type}) {
				/^ext\d/    && do {
					$kiwi -> info ("Resizing split $fsattr{type} filesystem");
					$status = qxx ("/sbin/resize2fs -f -F -p $mapper 2>&1");
					$result = $? >> 8;
					last SWITCH;
				};
				/^reiserfs/ && do {
					$kiwi -> info ("Resizing split $fsattr{type} filesystem");
					$status = qxx ("/sbin/resize_reiserfs $mapper 2>&1");
					$result = $? >> 8;
					last SWITCH;
				}
			};
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  (
					"Couldn't resize $fsattr{type} filesystem: $status"
				);
				$kiwi -> failed ();
				$this -> luksClose();
				$this -> cleanTmp ();
				return undef;
			}
			$this -> luksClose();
			if ($status) {
				$kiwi -> done();
			}
		}
	} else {
		#==========================================
		# Create fs on system image partition
		#------------------------------------------
		if (! $this -> setupFilesystem ($FSTypeRO,$root,"root")) {
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# Mount system image partition
		#------------------------------------------
		if (! main::mount ($root, $loopdir)) {
			$this -> cleanLoop ();
			return undef;
		}
		#==========================================
		# Create LVM volumes filesystems
		#------------------------------------------
		if (($lvm) && (%lvmparts)) {
			my $VGroup = $this->{lvmgroup};
			foreach my $name (keys %lvmparts) {
				my $device = "/dev/$VGroup/LV$name";
				my $pname  = $name; $pname =~ s/_/\//g;
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
				if (! main::mount ($device, "$loopdir/$pname")) {
					$this -> cleanLoop ();
					return undef;
				}
			}
		}
		#==========================================
		# Copy root tree to virtual disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on virtual disk");
		$status = qxx ("cp -a -x $system/* $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't copy image tree to virtual disk: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Umount system image partition
		#------------------------------------------
		main::umount();
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
		my %FSopts = main::checkFSOptions();
		my $fsopts = $FSopts{ext3};
		$fsopts.= "-F";
		$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
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
	} elsif (
		($dmapper) || ($haveluks) || ($lvm) || ($bootloader eq "extlinux")
	) {
		$root = $deviceMap{dmapper};
		$kiwi -> info ("Creating ext2 boot filesystem");
		if ($haveluks) {
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
		my %FSopts = main::checkFSOptions();
		my $fsopts = $FSopts{ext2};
		$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
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
	# Dump boot image on virtual disk
	#------------------------------------------
	$kiwi -> info ("Copying boot image to virtual disk");
	#==========================================
	# Mount system image / or rw partition
	#------------------------------------------
	if ($bootloader eq "syslinux") {
		$root = $deviceMap{fat};
	} elsif ($bootloader eq "extlinux") {
		$root = $deviceMap{extlinux};
	} elsif ($dmapper) {
		$root = $deviceMap{dmapper};
	} elsif (($syszip) || ($haveSplit) || ($lvm)) {
		$root = $deviceMap{2};
		if ($haveluks) {
			$root = $deviceMap{3};
		}
		if ($lvm) {
			$root = $deviceMap{0};
		}
	} elsif ($haveluks) {
		$root = $deviceMap{2};
	} else {
		$root = $deviceMap{1};
	}
	if (! main::mount ($root, $loopdir)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image: $root");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	#==========================================
	# Copy boot data on system image
	#------------------------------------------
	$status = qxx ("cp -dR $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Couldn't copy boot data to system image: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	main::umount();
	$kiwi -> done();
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	if ($lvm) {
		qxx ("vgchange -an $this->{lvmgroup} 2>&1");
	}
	$this -> cleanLoopMaps();
	#==========================================
	# Install boot loader on virtual disk
	#------------------------------------------
	if (! $this -> installBootLoader ($bootloader, $diskname, \%deviceMap)) {
		$this -> cleanLoop ();
	}
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# Create image described by given format
	#------------------------------------------
	if (defined $format) {
		if ($initrd =~ /oemboot/) {
			#==========================================
			# OEM formats...
			#------------------------------------------
			if ($format eq "iso") {
				$this -> {system} = $diskname;
				$kiwi -> info ("Creating install ISO image\n");
				$this -> cleanLoop ("keep-mountpoints");
				if (! $this -> setupInstallCD()) {
					return undef;
				}
			}
			if ($format eq "usb") {
				$this -> {system} = $diskname;
				$kiwi -> info ("Creating install USB Stick image\n");
				$this -> cleanLoop ("keep-mountpoints");
				if (! $this -> setupInstallStick()) {
					return undef;
				}
			}
		} else {
			#==========================================
			# VMX formats...
			#------------------------------------------
			if ($format eq "ovf") {
				$format = "vmdk";
			}
			$kiwi -> info ("Creating $format image");
			my %vmwc  = ();
			my $fname = $diskname;
			$fname =~ s/\.raw$/\.$format/;
			if ($format eq "vmdk") {
				%vmwc = $xml -> getVMwareConfig();
			}
			my $convert = "convert -f raw $this->{loop} -O $format";
			if (($vmwc{vmware_disktype}) && ($vmwc{vmware_disktype}=~/^scsi/)) {
				$status = qxx ("qemu-img $convert -s $fname 2>&1");
			} else {
				$status = qxx ("qemu-img $convert $fname 2>&1");
			}
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create $format image: $status");
				$kiwi -> failed ();
				$this -> cleanLoop ();
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	$this -> cleanLoop ();
	return $this;
}

#==========================================
# extractCPIO
#------------------------------------------
sub extractCPIO {
	my $this = shift;
	my $file = shift;
	if (! open FD,$file) {
		return 0;
	}
	local $/;
	my $data   = <FD>; close FD;
	my @data   = split (//,$data);
	my $stream = "";
	my $count  = 0;
	my $start  = 0;
	my $pos1   = -1;
	my $pos2   = -1;
	my @index;
	while (1) {
		my $pos1 = index ($data,"TRAILER!!!",$start);
		if ($pos1 >= $start) {
			$pos2 = index ($data,"07070",$pos1);
		} else {
			last;
		}
		if ($pos2 >= $pos1) {
			$pos2--;
			push (@index,$pos2);
			#print "$start -> $pos2\n";
			$start = $pos2;
		} else {
			$pos2 = @data; $pos2--;
			push (@index,$pos2);
			#print "$start -> $pos2\n";
			last;
		}
	}
	for (my $i=0;$i<@data;$i++) {
		$stream .= $data[$i];
		if ($i == $index[$count]) {
			$count++;
			if (! open FD,">$file.$count") {
				return 0;
			}
			print FD $stream;
			close FD;
			$stream = "";
		}
	}
	return $count;
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
	my $pinst  = $xml->getOEMPartitionInstall();
	my $ibasename;
	my $iversion;
	my $newird;
	if (! mkdir $irddir) {
		$kiwi -> error  ("Failed to create vmxsystem directory");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# unpack initrd files
	#------------------------------------------
	my $unzip  = "$main::Gzip -cd $initrd 2>&1";
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
		if ($namecd !~ /(.*)-(\d+\.\d+\.\d+)\.raw$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return undef;
		}
		$ibasename = $1;
		$iversion  = $2;
		if (! -f $imd5) {
			$kiwi -> error  ("Couldn't find md5 file");
			$kiwi -> failed ();
			qxx ("rm -rf $irddir");
			return undef;
		}
		if (! $pinst) {
			print FD "IMAGE=nope;$ibasename;$iversion;compressed\n";
		} else {
			print FD "IMAGE=nope;$ibasename;$iversion\n";
		}
		close FD;
	}
	#==========================================
	# create new initrd with vmxsystem file
	#------------------------------------------
	$newird = $initrd;
	$newird =~ s/\.gz/\.install\.gz/;
	$status = qxx (
		"(cd $irddir && find|cpio --quiet -oH newc | $main::Gzip) > $newird"
	);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to re-create initrd: $status");
		$kiwi -> failed ();
		qxx ("rm -rf $irddir");
		return undef;
	}
	qxx ("rm -rf $irddir");
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
	my $newird;
	my $result;
	#==========================================
	# create temp dir for operations
	#------------------------------------------
	$kiwi -> info ("Setting up splash screen...");
	my $spldir = qxx ("mktemp -q -d /tmp/kiwisplash.XXXXXX");
	my $status = $? >> 8;
	if ($status != 0) {
		$kiwi -> skipped ();
		$kiwi -> warning  ("Failed to create splash directory: $!");
		$kiwi -> skipped ();
		return $initrd;
	}
	chomp $spldir;
	my $irddir = "$spldir/initrd";
	#==========================================
	# check if compressed and setup splash.gz
	#------------------------------------------
	if ($initrd =~ /\.gz$/) {
		$zipped = 1;
	}
	if ($zipped) {
		$newird = $initrd; $newird =~ s/\.gz/\.splash.gz/;
	} else {
		$newird = $initrd.".splash.gz";
	}
	#==========================================
	# unpack initrd files
	#------------------------------------------
	mkdir $irddir;
	my $unzip  = "$main::Gzip -cd $initrd 2>&1";
	if ($zipped) {
		$status = qxx ("$unzip | (cd $irddir && cpio -di 2>&1)");
	} else {
		$status = qxx ("cat $initrd | (cd $irddir && cpio -di 2>&1)");
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Failed to extract data: $!");
		$kiwi -> skipped ();
		qxx ("rm -rf $spldir");
		return $initrd;
	}
	#==========================================
	# check for splash system
	#------------------------------------------
	if (-x $irddir."/usr/sbin/splashy") {
		$status = $this -> setupSplashy ($newird);
	} else {
		$status = $this -> setupSplashForGrub ($spldir,$newird);
	}
	#==========================================
	# cleanup
	#------------------------------------------
	qxx ("rm -rf $spldir");
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
		$status = qxx ("$main::Gzip -f $initrd 2>&1");
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
# setupSplashy
#------------------------------------------
sub setupSplashy {
	# ...
	# when booting with splashy no changes to the initrd are
	# required. This function only makes sure the .splash.gz
	# file exists. This is done by creating a link to the
	# original initrd file
	# ---
	my $this   = shift;
	my $newird = shift;
	my $status = $this -> setupSplashLink ($newird);
	return $status;
}

#==========================================
# setupSplashForGrub
#------------------------------------------
sub setupSplashForGrub {
	# ...
	# when booting with grub it is required to append the splash
	# files (cpio data) at the end of the boot image (initrd)
	# --- 
	my $this   = shift;
	my $spldir = shift;
	my $newird = shift;
	my $newspl = "$spldir/splash";
	my $irddir = "$spldir/initrd";
	my $status;
	my $result;
	#==========================================
	# move splash files
	#------------------------------------------
	mkdir $newspl;
	$status = qxx ("mv $irddir/image/loader/*.spl $newspl 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		return ("No splash files found in initrd");		
	}
	#==========================================
	# create new splash with all pictures
	#------------------------------------------
	while (my $splash = glob("$newspl/*.spl")) {
		mkdir "$splash.dir";
		qxx ("$main::Gzip -cd $splash > $splash.bob");
		my $count = $this -> extractCPIO ( $splash.".bob" );
		for (my $id=1; $id <= $count; $id++) {
			qxx ("cat $splash.bob.$id |(cd $splash.dir && cpio -i 2>&1)");
		}
		qxx ("cp -a $splash.dir/etc $newspl");
		$result = 1;
		if (-e "$splash.dir/bootsplash") {
			qxx ("cat $splash.dir/bootsplash >> $newspl/bootsplash");
			$result = $? >> 8;
		}
		qxx ("rm -rf $splash.dir");
		qxx ("rm -f  $splash.bob*");
		qxx ("rm -f  $splash");
		if ($result != 0) {
			my $splfile = basename ($splash);
			return ("No bootsplash file found in $splfile cpio");
		}
	}
	qxx (
		"(cd $newspl && \
		find|cpio --quiet -oH newc | $main::Gzip) > $spldir/all.spl"
	);
	qxx (
		"rm -f $newird && \
		(cd $irddir && find | cpio --quiet -oH newc | $main::Gzip) > $newird"
	);
	#==========================================
	# create splash initrd
	#------------------------------------------
	qxx ("cat $spldir/all.spl >> $newird");
	return "ok";
}

#==========================================
# cleanDbus
#------------------------------------------
sub cleanDbus {
	my $this = shift;
	my $stick= $this->{stick};
	my $hald = $this->{hald};
	if (! defined $hald) {
		return $this;
	}
	if (defined $stick) {
		$hald -> unlock ($stick);
	}
	$hald -> close();
	return $this;
}

#==========================================
# cleanTmp
#------------------------------------------
sub cleanTmp {
	my $this = shift;
	if ($this->{lvm}) {
		qxx ("vgchange -an $this->{lvmgroup} 2>&1");
	}
	my $tmpdir = $this->{tmpdir};
	my $loopdir= $this->{loopdir};
	qxx ("rm -rf $tmpdir 2>&1");
	qxx ("rm -rf $loopdir 2>&1");
	return $this;
}

#==========================================
# cleanLoop
#------------------------------------------
sub cleanLoop {
	my $this = shift;
	my $rmdir= shift;
	my $tmpdir = $this->{tmpdir};
	my $loop   = $this->{loop};
	my $lvm    = $this->{lvm};
	my $loopdir= $this->{loopdir};
	main::umount();
	if (defined $loop) {
		if (defined $lvm) {
			qxx ("vgchange -an $this->{lvmgroup} 2>&1");
		}
		$this -> cleanLoopMaps();
		qxx ("/sbin/losetup -d $loop 2>&1");
		if (! defined $rmdir) {
			undef $this->{loop};
		}
	}
	if (! defined $rmdir) {
		qxx ("rm -rf $tmpdir");
		qxx ("rm -rf $loopdir");
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
	my $kiwi = $this->{kiwi};
	$kiwi -> info ("Creating image MD5 sum...");
	my $size = -s $file;
	my $primes = qxx ("factor $size"); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 8192);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qxx ("cat $file | md5sum - | cut -f 1 -d-");
	chomp $sum;
	if ($file =~ /\.raw$/) {
		$file =~ s/raw$/md5/;
	}
	qxx ("echo \"$sum $blocks $blocksize\" > $file");
	$kiwi -> done();
	return $this;
}

#==========================================
# getMBRDiskLabel
#------------------------------------------
sub getMBRDiskLabel {
	# ...
	# create a random 4byte MBR disk label ID
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
	my $status = 0;
	my $result = 0;
	#==========================================
	# Grub
	#------------------------------------------
	if ($loader eq "grub") {
		my $stages = "'usr/lib/grub/*'";
		my $message= "'image/loader/message'";
		my $gbinary= "'usr/sbin/grub'";
		my $unzip  = "$main::Gzip -cd $initrd 2>&1";
		$status = qxx ( "mkdir -p $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating boot manager directory: $status");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# Get Grub binary from initrd
		#------------------------------------------
		$kiwi -> info ("Importing grub binary");
		if ($zipped) {
			$status= qxx ("$unzip | (cd $tmpdir && cpio -di $gbinary 2>&1)");
		} else {
			$status= qxx ("cat $initrd|(cd $tmpdir && cpio -di $gbinary 2>&1)");
		}
		if (! -e $tmpdir."/usr/sbin/grub" ) {
			$kiwi -> failed ();
			$kiwi -> error  ("No grub bootloader found in initrd: $status");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done ();
		#==========================================
		# Get Grub graphics boot message
		#------------------------------------------
		$kiwi -> info ("Importing graphics boot message");
		if ($zipped) {
			$status= qxx ("$unzip | (cd $tmpdir && cpio -di $message 2>&1)");
		} else {
			$status= qxx ("cat $initrd|(cd $tmpdir && cpio -di $message 2>&1)");
		}
		if (-e $tmpdir."/image/loader/message") {
			$status = qxx ("mv $tmpdir/$message $tmpdir/boot/message 2>&1");
			$result = $? >> 8;
			$kiwi -> done();
		} else {
			$kiwi -> skipped();
		}
		#==========================================
		# Get Grub stage files from initrd
		#------------------------------------------
		$kiwi -> info ("Importing grub stages");
		if ($zipped) {
			$status = qxx (
				"$unzip | (cd $tmpdir && cpio -di $stages 2>&1)"
			);
		} else {
			$status = qxx (
				"cat $initrd | (cd $tmpdir && cpio -di $stages 2>&1)"
			);
		}
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
			$kiwi -> skipped (); chomp $status;
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
				$kiwi -> failed ();
				$kiwi -> error  ("Failed importing grub stages: $status");
				$kiwi -> failed ();
				return undef;
			}
		}
		$kiwi -> done();
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader =~ /(sys|ext)linux/) {
		my $message= "'image/loader/*'";
		my $unzip  = "$main::Gzip -cd $initrd 2>&1";
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
	my %type     = %{$xml->getImageTypeAndAttributes()};
	my $cmdline  = $type{cmdline};
	my $bloader  = "grub";
	my $title;
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
		# General grub setup
		#------------------------------------------
		print FD "color cyan/blue white/blue\n";
		print FD "default 0\n";
		print FD "timeout 10\n";
		if ($type =~ /^KIWI (CD|USB)/) {
			my $dev = $1 eq 'CD' ? '(cd)' : '(hd0,0)';
			print FD "gfxmenu $dev/boot/message\n";
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
			print FD "gfxmenu (hd0,$bootpart)/boot/message\n";
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
		print FD "default  $label"."\n";
		print FD "implicit 1"."\n";
		print FD "prompt   1"."\n";
		print FD "timeout  200"."\n";
		if ($syslinux_new_format) {
			print FD "ui gfxboot bootlogo isolinux.msg"."\n";
		} else {
			print FD "gfxboot  bootlogo"."\n";
			print FD "display  isolinux.msg"."\n";
		}
		if ($type =~ /^KIWI (CD|USB)/) {
			$title = $this -> makeLabel ("Boot from Hard Disk");
			print FD "label $title\n";
			print FD "localboot 0x80\n";
			$title = $this -> makeLabel ("Install/Restore $label");
			print FD "label $title\n";
		} else {
			$title = $this -> makeLabel ("$label [ $type ]");
			print FD "label $title"."\n";
		}
		#==========================================
		# Standard boot
		#------------------------------------------
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				print FD "kernel linux\n";
				print FD "append initrd=initrd ";
				print FD "vga=$vga loader=$bloader splash=silent ";
				print FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
				print FD "cdinst=1";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				print FD "kernel linux\n";
				print FD "append initrd=initrd ";
				print FD "vga=$vga loader=$bloader splash=silent ";
				print FD "ramdisk_size=512000 ramdisk_blocksize=4096 ";
				print FD "cdinst=1";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
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
		$kiwi -> done();
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
	my $result;
	my $status;
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
		# Create device map for the virtual disk
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
		# Install grub in batch mode
		#------------------------------------------
		my $grub = $tmpdir."/usr/sbin/grub";
		my $grubOptions = "--device-map $dmfile --no-floppy --batch";
		$kiwi -> loginfo ("GRUB: $grub $grubOptions\n");
		if (! open (FD,"|$grub $grubOptions &> $tmpdir/grub.log")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't call grub: $!");
			$kiwi -> failed ();
			return undef;
		}
		print FD "device (hd0) $diskname\n";
		print FD "root (hd0,$bootpart)\n";
		if ($chainload) {
			print FD "setup (hd0,0)\n";
		} else {
			print FD "setup (hd0)\n";
		}
		print FD "quit\n";
		close FD;
		my $glog;
		if (open (FD,"$tmpdir/grub.log")) {
			my @glog = <FD>; close FD;
			$glog = join ("\n",@glog);
			$kiwi -> loginfo ("GRUB: $glog");
			if ($glog =~ /Error/) {
				$result = 1;
			}
		}
		if ($result != 1) {
			$status= qxx (
				"head -n 10 $diskname | file - | grep -q 'boot sector'"
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
		if ($device =~ /mapper/) {
			qxx ("kpartx -a $diskname");
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
	# more boot managers to come...
	#------------------------------------------
	# ...
	#==========================================
	# Write custom disk label ID to MBR
	#------------------------------------------
	$kiwi -> info ("Saving disk label in MBR: $this->{mbrid}...");
	if (! $this -> writeMBRDiskLabel ($diskname)) {
		return undef;
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# bindLoopDevice
#------------------------------------------
sub bindLoopDevice {
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
# getCylinderSizeAndCount
#------------------------------------------
sub getCylinderSizeAndCount {
	# ...
	# obtain cylinder size and count for the specified disk.
	# The function returns the size in kB or zero on error
	# ---
	my $this = shift;
	my $disk = shift;
	my $kiwi = $this->{kiwi};
	my $status;
	my $result;
	my $parted;
	$status = qxx ("dd if=/dev/zero of=$disk bs=512 count=1 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	$status = qxx ("/usr/sbin/parted -s $disk mklabel msdos 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> loginfo ($status);
		return 0;
	}
	$parted = "/usr/sbin/parted -m $disk unit cyl print";
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
		$cyls = sprintf ("%.0f",($size * 1024) / $csize);
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
	my $cyls   = 0;
	my $status;
	my $result;
	if (! defined $this->{pDiskCylinders}) {
		my $cylsize = $this -> getCylinderSizeAndCount($device);
		if ($cylsize == 0) {
			return 0;
		}
	}
	$cyls = $this -> getCylinder ($size);
	if ($cyls == 0) {
		return 0;
	}
	if (! defined $this->{pStart}) {
		$this->{pStart} = 0;
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
	my $tmpdir   = $this->{tmpdir};
	my @commands = @{$cmdref};
	my $result;
	my $status;
	if (! defined $tool) {
		$tool = "fdisk";
	}
	SWITCH: for ($tool) {
		#==========================================
		# fdisk
		#------------------------------------------
		/^fdisk/  && do {
			$kiwi -> loginfo (
				"FDISK input: $device [@commands]"
			);
			$status = qxx ("dd if=/dev/zero of=$device bs=512 count=1 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> loginfo ($status);
				return undef;
			}
			if (! open (FD,"|/sbin/fdisk $device &> $tmpdir/fdisk.log")) {
				return undef;
			}
			foreach my $cmd (@commands) {
				if ($cmd eq ".") {
					print FD "\n";
				} else {
					print FD "$cmd\n";
				}
			}
			close FD;
			$result = $? >> 8;
			my $flog;
			if (open (FD,"$tmpdir/fdisk.log")) {
				my @flog = <FD>; close FD;
				$flog = join ("\n",@flog);
				$kiwi -> loginfo ("FDISK: $flog");
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
				"PARTED input: $device [@p_cmd]"
			);
			foreach my $p_cmd (@p_cmd) {
				$status= qxx (
					"/usr/sbin/parted -s $device unit cyl $p_cmd 2>&1"
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
	my $this = shift;
	my $pdev = shift;
	my $tool = $this->{ptool};
	my $result;
	my $status;
	if (! defined $tool) {
		$tool = "fdisk";
	}
	SWITCH: for ($tool) {
		#==========================================
		# fdisk
		#------------------------------------------
		/^fdisk/  && do {
			my $disk;
			my $devnr= -1;
			if ($pdev =~ /mapper/) {
				if ($pdev =~ /mapper\/(.*)p(\d+)/) {
					$disk = "/dev/".$1;
					$devnr= $2;
				}
			} else {
				if ($pdev =~ /(.*)(\d+)/) {
					$disk = $1;
					$devnr= $2;
				}
			}
			$status = qxx ("/sbin/sfdisk -c $disk $devnr 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		#==========================================
		# parted
		#------------------------------------------
		/^parted/  && do {
			my $parted = "/usr/sbin/parted -m ";
			my $disk   = $pdev;
			if ($pdev =~ /mapper/) {
				if ($pdev =~ /mapper\/(.*)p(\d+)/) {
					$disk = "/dev/".$1;
					$pdev = "/dev/".$1.$2;
				}
			} else {
				if ($pdev =~ /(.*)(\d+)/) {
					$disk = $1;
				}
			}
			$parted .= '-s '.$disk.' print |';
			$parted .= 'sed -e "s@^\([0-4]\):@'.$disk.'\1:@" |';
			$parted .= 'grep ^'.$pdev.':|cut -f2 -d= | cut -f1 -d,';
			$status = qxx ($parted);
			$result = $? >> 8;
			if ((! $status) && ($pdev =~ /loop/)) {
				$status = qxx ("/usr/sbin/parted -s $pdev mklabel msdos 2>&1");
				$status = qxx ($parted);
				$result = $? >> 8;
			}
			last SWITCH;
		};
	}
	if ($result == 0) {
		return int $status;
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
		my $search = 6;
		if ($loader eq "extlinux" ) {
			$search = 83;
		}
		for (my $i=3;$i>=1;$i--) {
			my $type = $this -> getStorageID ($device.$i);
			if ($type == $search) {
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
		my $search = 6;
		if ($loader eq "extlinux" ) {
			$search = 83;
		}
		for (my $i=3;$i>=1;$i--) {
			my $type = $this -> getStorageID ("/dev/mapper".$dmap."p$i");
			if ($type == $search) {
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
	my $loader = $this->{bootloader};
	my $dmapper= $this->{dmapper};
	my %result;
	if (! defined $group) {
		return undef;
	}
	if ($device =~ /loop/) {
		my $dmap = $device; $dmap =~ s/dev\///;
		$result{0} = "/dev/mapper".$dmap."p2";
	} else {
		$result{0} = $device."2";
	}
	for (my $i=0;$i<@names;$i++) {
		$result{$i+1} = "/dev/$group/".$names[$i];
	}
	if ($loader =~ /(sys|ext)linux/) {
		my $search = 6;
		if ($loader eq "extlinux" ) {
			$search = 83;
		}
		if ($device =~ /loop/) {
			my $dmap = $device; $dmap =~ s/dev\///;
			for (my $i=3;$i>=1;$i--) {
				my $type = $this -> getStorageID ("/dev/mapper".$dmap."p$i");
				if ($type == $search) {
					if ($loader eq "syslinux") {
						$result{fat} = "/dev/mapper".$dmap."p$i";
					} else {
						$result{extlinux} = "/dev/mapper".$dmap."p$i";
					}
					last;
				}
			}
		} else {
			for (my $i=3;$i>=1;$i--) {
				my $type = $this -> getStorageID ($device.$i);
				if ($type == $search) {
					if ($loader eq "syslinux") {
						$result{fat} = $device.$i;
					} else {
						$result{extlinux} = $device.$i;
					}
					last;
				}
			}
		}
	} elsif ($dmapper) {
		if ($device =~ /loop/) {
			my $dmap = $device; $dmap =~ s/dev\///;
			$result{dmapper} = "/dev/mapper".$dmap."p2";
		} else {
			$result{dmapper} = $device."2";
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
	$status = qxx ("pvcreate $deviceMap{1} 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating physical extends: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$status = qxx ("vgcreate $VGroup $deviceMap{1} 2>&1");
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
		$status.= qxx ("lvcreate -l 100%FREE -n LVRoot $VGroup 2>&1");
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
			$status = qxx ("lvcreate -l 100%FREE -n LVRoot $VGroup 2>&1");
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
	my $cipher = $main::LuksCipher;
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
	# lock device for hal
	#------------------------------------------
	if ($source !~ /loop/) {
		$hald = new KIWI::dbusdevice::HalConnection;
		if (! $hald -> open()) {
			$kiwi -> loginfo ($hald->state());
		} else {
			$this -> {lhald} = $hald;
			if ($hald -> lock ("/dev/mapper/".$name)) {
				$kiwi -> loginfo ($hald->state());
			} else {
				$this -> {lhalddevice} = "/dev/mapper/".$name;
				$kiwi -> loginfo ("HAL:".$hald->state());
			}
		}
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
	if ($this->{lhald}) {
		$this->{lhald} -> unlock (
			$this->{lhalddevice}
		);
		undef $this->{lhald};
		undef $this->{lhalddevice};
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
	my %type   = %{$xml->getImageTypeAndAttributes()};
	my %FSopts = main::checkFSOptions();
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
			$fsopts .= /^ext2/ ? "-F" : "-j -F";
			if ($this->{inodes}) {
				$fsopts.= " -N $this->{inodes}";
			}
			my $tuneopts = $type{fsnocheck} eq "true" ? "-c 0 -i 0" : "";
			$tuneopts = $FSopts{extfstune} if $FSopts{extfstune};
			$status = qxx ("/sbin/mke2fs $fsopts $device 2>&1");
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

1; 
