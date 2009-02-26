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
use FileHandle;
use File::Basename;
use File::Spec;
use Math::BigFloat;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw (relocateCatalog);

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
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $syszip    = 0;
	my $sysird    = 0;
	my $zipped    = 0;
	my $vmmbyte;
	my $kernel;
	my $knlink;
	my $tmpdir;
	my $loopdir;
	my $result;
	my $status;
	my $isxen;
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
	# xen kernel used...
	#------------------------------------------
	$isxen = 0;
	$xengz = $initrd;
	if ($zipped) {
		$xengz =~ s/\.gz$//;
	}
	foreach my $xen (glob ("$xengz*xen.gz")) {
		$isxen = 1;
		$xengz = $xen;
		last;
	}
	#==========================================
	# find kernel file
	#------------------------------------------
	$kernel = $initrd;
	if ($zipped) {
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
	$this->{tmpdir} = $tmpdir;
	$this->{loopdir}= $loopdir;

	#==========================================
	# setup pointer to XML configuration
	#------------------------------------------
	if (defined $system) {
		if (-d $system) {
			$xml = new KIWIXML (
				$kiwi,$system."/image",undef,$main::SetImageType
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
				$kiwi -> info ("Setup device mapper for ISO install image");
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
				%fsattr = main::checkFileSystem ($sdev);
				$status = qxx ("mount -t $fsattr{type} $sdev $tmpdir 2>&1");
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error ("System image mount failed: $status");
					$kiwi -> failed ();
					$this -> cleanLoop ();
					return undef;
				}
				#==========================================
				# read disk image XML description
				#------------------------------------------
				$xml = new KIWIXML (
					$kiwi,$tmpdir."/image",undef,$main::SetImageType
				);
				#==========================================
				# clean up
				#------------------------------------------
				qxx ("umount $tmpdir 2>&1");
				qxx ("kpartx -d $this->{loop}");
				qxx ("losetup -d $this->{loop}");
			} else {
				#==========================================
				# loop mount system image
				#------------------------------------------
				$status = qxx (
					"mount -t $fsattr{type} -o loop $system $tmpdir 2>&1"
				);
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error ("Loop mount failed: $system : $status");
					$kiwi -> failed ();
					$this -> cleanTmp ();
					return undef;
				}
				#==========================================
				# read disk image XML description
				#------------------------------------------
				$xml = new KIWIXML (
					$kiwi,$tmpdir."/image",undef,$main::SetImageType
				);
				#==========================================
				# clean up
				#------------------------------------------
				qxx ("umount $tmpdir 2>&1");
			}
		}
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
	}
	#==========================================
	# setup virtual disk size
	#------------------------------------------
	if ((! defined $vmsize) && (defined $system)) {
		my $kernelSize  = -s $kernel; # the kernel
		my $initrdSize  = -s $initrd; # the boot image
		my $systemSXML  = 1; # system size set by XML file
		my $systemSize  = 0; # the system image size in bytes
		my $systemInodes= 0; # the number of inodes the system uses
		# /.../
		# Note: In case of a split system the vmsize value will
		# be increased according to the size of the split portion
		# This happens within the function which requires it but
		# not at the following code
		# ----
		if (-d $system) {
			#==========================================
			# Find size on a per file basis first
			#------------------------------------------
			$systemSXML = $xml -> getImageSizeBytes();
			$systemSize = qxx (
				"du -s --block-size=1 $system | cut -f1"
			);
			chomp $systemSize;
			#==========================================
			# Calculate required inode count
			#------------------------------------------
			$systemInodes = qxx ("find $system | wc -l");
			$systemInodes *= 2;
			if ((defined $main::FSNumInodes) &&
				($main::FSNumInodes < $systemInodes)
			) {
				$kiwi -> warning ("Specified Inode count might be too small\n");
				$kiwi -> warning ("Copying of files to image could fail !\n");
			}
			if (! defined $main::FSNumInodes) {
				$main::FSNumInodes = $systemInodes;
			}
			if ($systemSXML eq "auto") {
				$systemSXML = 0;
			}
		} else {
			$systemSXML = $xml -> getImageSizeBytes();
			$systemSize = -s $system;
			if ($systemSXML eq "auto") {
				$systemSXML = 0;
			}
		}
		if ($syszip) {
			$vmsize = $kernelSize + $initrdSize + $syszip;
		} else {
			$vmsize = $kernelSize + $initrdSize + $systemSize;
		}
		if (($systemSXML) && ($systemSXML > $vmsize)) {
			# use the size information from the XML configuration
			$vmsize = $systemSXML;
		} else {
			# use the calculated value plus 10% free space 
			$vmsize+= $vmsize * 0.10;
			# check if additive size was specified
			$vmsize+= $xml -> getImageSizeAdditiveBytes();
		}
		$vmsize  = $vmsize / 1048576;
		$vmsize  = sprintf ("%.0f", $vmsize);
		$vmmbyte = $vmsize;
		$vmsize  = $vmsize."M";
	} elsif (defined $system) {
		$vmmbyte = $vmsize / 1048576;
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
	# Store object data (2)
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{initrd} = $initrd;
	$this->{system} = $system;
	$this->{kernel} = $kernel;
	$this->{vmmbyte}= $vmmbyte;
	$this->{vmsize} = $vmsize;
	$this->{syszip} = $syszip;
	$this->{device} = $device;
	$this->{format} = $format;
	$this->{zipped} = $zipped;
	$this->{isxen}  = $isxen;
	$this->{xengz}  = $xengz;
	$this->{arch}   = $arch;
	$this->{ptool}  = $main::Partitioner;
	$this->{lvm}    = $lvm;
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
	if ($isxen) {
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
	my $xengz     = $this->{xengz};
	my $lvm       = $this->{lvm};
	my %deviceMap = ();
	my @commands  = ();
	my $imgtype   = "usb";
	my $haveSplit = 0;
	my $haveTree  = 0;
	my $lvmbootMB = 0;
	my $syslbootMB= 0;
	my $bootloader= "grub";
	my $lvmsize;
	my $syslsize;
	my $FSTypeRW;
	my $FSTypeRO;
	my $status;
	my $result;
	my $hald;
	my $xml;
	#==========================================
	# use lvm together with system image only
	#------------------------------------------
	if (! defined $system) {
		undef $lvm;
	}
	#==========================================
	# add boot space if lvm based
	#------------------------------------------
	if ($lvm) {
		$lvmbootMB = 20;
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
		$xml = new KIWIXML ( $kiwi,$system."/image",undef,$imgtype );
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
		$haveTree = 1;
	} else {
		my %fsattr = main::checkFileSystem ($system);
		$status = qxx ("mount -t $fsattr{type} -o loop $system $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
		}
		$xml = new KIWIXML ( $kiwi,$tmpdir."/image",undef,$imgtype );
		$status = qxx ("umount $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to umount system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
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
	if ($bootloader eq "syslinux") {
		$syslbootMB= 20;
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
	if (($syszip) || ($haveSplit) || ($lvm)) {
		$bootpart = "1";
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
	for (my $i=1;$i<=4;$i++) {
		qxx ("umount $stick$i 2>&1");
	}
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
	$softSize += $lvmbootMB;
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
				if (($syszip) || ($haveSplit)) {
					if ($bootloader eq "syslinux") {
						$syslsize = $hardSize;
						$syslsize /= 1000;
						$syslsize -= $syszip;
						$syslsize -= $syslbootMB;
						$syslsize = sprintf ("%.f",$syslsize);
						@commands = (
							"n","p","1",".","+".$syszip."M",
							"n","p","2",".","+".$syslsize."M",
							"n","p","3",".",".",
							"t","1","83",
							"t","2","83",
							"t","3","6",
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
					if ($bootloader eq "syslinux") {
						$syslsize = $hardSize;
						$syslsize /= 1000;
						$syslsize -= $syslbootMB;
						$syslsize = sprintf ("%.f",$syslsize);
						@commands = (
							"n","p","1",".","+".$syslsize."M","t","83",
							"n","p","2",".",".","t","2","6",
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
				$lvmsize /= 1000;
				$lvmsize -= $lvmbootMB;
				$lvmsize = sprintf ("%.f",$lvmsize);
				if ($bootloader eq "syslinux") {
					@commands = (
						"n","p","1",".","+".$lvmsize."M",
						"n","p","2",".",".",
						"t","1","8e",
						"t","2","6",
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
			if ($bootloader eq "syslinux") {
				$syslsize = $hardSize;
				$syslsize /= 1000;
				$syslsize -= $syslbootMB;
				$syslsize = sprintf ("%.f",$syslsize);
				@commands = (
					"n","p","1",".","+".$syslsize."M","t","83",
					"n","p","2",".",".","t","2","6",
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
		for (my $i=1;$i<=2;$i++) {
			qxx ("umount $deviceMap{$i} 2>&1");
			if ($deviceMap{fat}) {
				qxx ("umount $deviceMap{fat} 2>&1");
			}
		}
		$status = qxx ( "/sbin/blockdev --rereadpt $stick 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't reread partition table: $!");
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
		for (my $i=1;$i<=2;$i++) {
			qxx ("umount $deviceMap{$i} 2>&1");
			if ($deviceMap{fat}) {
				qxx ("umount $deviceMap{fat} 2>&1");
			}
		}
		#==========================================
		# setup volume group if requested
		#------------------------------------------
		if ($lvm) {
			%deviceMap = $this -> setVolumeGroup (
				\%deviceMap,$stick,$syszip,$haveSplit
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
		} elsif ($syszip) {
			$kiwi -> info ("Creating ext3 read/write filesystem");
			my %FSopts = main::checkFSOptions();
			my $fsopts = $FSopts{ext3};
			$fsopts.= "-j -F";
			$status = qxx ("/sbin/mke2fs $fsopts $deviceMap{2} 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create ext3 filesystem: $status");
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
		my %FSopts = main::checkFSOptions();
		SWITCH: for ($FSTypeRO) {
			/^ext2/     && do {
				$kiwi -> info ("Creating ext2 root filesystem");
				my $fsopts = $FSopts{ext2};
				$fsopts.= "-F";
				$status = qxx ("/sbin/mke2fs $fsopts $deviceMap{1} 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^ext3/     && do {
				$kiwi -> info ("Creating ext3 root filesystem");
				my $fsopts = $FSopts{ext3};
				$fsopts.= "-j -F";
				$status = qxx ("/sbin/mke2fs $fsopts $deviceMap{1} 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Creating reiserfs root filesystem");
				my $fsopts = $FSopts{reiserfs};
				$fsopts.= "-f";
				$status = qxx (
					"/sbin/mkreiserfs $fsopts $deviceMap{1} 2>&1"
				);
				$result = $? >> 8;
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported filesystem type: $FSTypeRO");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $FSTypeRO filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Mount system image partition
		#------------------------------------------
		$status = qxx ("mount $deviceMap{1} $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount partition: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanLoop ();
			return undef;
		}
		#==========================================
		# Copy root tree to virtual disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on stick");
		$status = qxx ("cp -a $system/* $loopdir 2>&1");
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
		qxx ( "umount $loopdir 2>&1" );
	}
	#==========================================
	# Check and resize filesystems
	#------------------------------------------
	$result = 0;
	undef $status;
	SWITCH: for ($FSTypeRO) {
		/^ext\d/    && do {
			$kiwi -> info ("Resizing system $FSTypeRO filesystem");
			$status = qxx ("/sbin/resize2fs -f -F -p $deviceMap{1} 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		/^reiserfs/ && do {
			$kiwi -> info ("Resizing system $FSTypeRO filesystem");
			$status = qxx ("/sbin/resize_reiserfs $deviceMap{1} 2>&1");
			$result = $? >> 8;
			last SWITCH;
		}
	};
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't resize $FSTypeRO filesystem: $status");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanTmp ();
		return undef;
	}
	if ($status) {
		$kiwi -> done();
	}
	if ($haveSplit) {
		$result = 0;
		undef $status;
		SWITCH: for ($FSTypeRW) {
			/^ext\d/    && do {
				$kiwi -> info ("Resizing split $FSTypeRW filesystem");
				$status = qxx ("/sbin/resize2fs -f -F -p $deviceMap{2} 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Resizing split $FSTypeRW filesystem");
				$status = qxx ("/sbin/resize_reiserfs $deviceMap{2} 2>&1");
				$result = $? >> 8;
				last SWITCH;
			}
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error("Couldn't resize $FSTypeRW filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		if ($status) {
			$kiwi -> done();
		}
	}
	#==========================================
	# Dump boot image on virtual disk
	#------------------------------------------
	$kiwi -> info ("Copying boot data to stick");
	#==========================================
	# Mount system image / or rw partition
	#------------------------------------------
	if ($bootloader eq "syslinux") {
		$status = qxx ("/sbin/mkdosfs $deviceMap{fat} 2>&1");
		$result = $? >> 8;
		if ($result == 0) {
			$status = qxx ("mount $deviceMap{fat} $loopdir 2>&1");
			$result = $? >> 8;
		}
	} elsif ($lvm) {
		my %FSopts = main::checkFSOptions();
		my $fsopts = $FSopts{ext2};
		$fsopts.= "-F";
		$status = qxx ("/sbin/mke2fs $fsopts $deviceMap{0} 2>&1");
		$result = $? >> 8;
		if ($result == 0) {
			$status = qxx ("mount $deviceMap{0} $loopdir 2>&1");
			$result = $? >> 8;
		}
	} elsif (($syszip) || ($haveSplit)) {
		$status = qxx ("mount $deviceMap{2} $loopdir 2>&1");
		$result = $? >> 8;
	} else {
		$status = qxx ("mount $deviceMap{1} $loopdir 2>&1");
		$result = $? >> 8;
	}
	if ($result != 0) {
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
	qxx ("umount $loopdir");
	$kiwi -> done();
	#==========================================
	# deactivate volume group
	#------------------------------------------
	if ($lvm) {
		qxx ("vgchange -an 2>&1");
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
	my $xengz     = $this->{xengz};
	my $md5name   = $system;
	my $imgtype   = "oem";
	my $gotsys    = 1;
	my $status;
	my $result;
	my $ibasename;
	my $tmpdir;
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
		my $sdev = "/dev/mapper".$dmap."p2";
		if (! -e $sdev) {
			$sdev = "/dev/mapper".$dmap."p1";
		}
		my %fsattr = main::checkFileSystem ($sdev);
		$status = qxx ("mount -t $fsattr{type} $sdev $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to mount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
		}
		$status = qxx ("umount $tmpdir 2>&1"); sleep (1);
		$status = qxx ("/sbin/kpartx  -d $this->{loop} 2>&1");
		$status = qxx ("/sbin/losetup -d $this->{loop} 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to umount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	}
	$this->{imgtype} = $imgtype;
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	$this -> buildMD5Sum ($system);
	#==========================================
	# Compress system image
	#------------------------------------------
	$kiwi -> info ("Compressing installation image...");
	$md5name=~ s/\.raw$/\.md5/;
	$status = qxx ("$main::Gzip $system 2>&1");
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
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $namecd = basename ($system);
	if ($gotsys) {
		if ($namecd !~ /(.*)-(\d+\.\d+\.\d+)\.raw\.gz$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		$ibasename = $1.".gz";
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	#==========================================
	# Create CD structure
	#------------------------------------------
	$this->{initrd} = $initrd;
	if (! $this -> createBootStructure()) {
		$this->{initrd} = $oldird;
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ("grub","iso")) {
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
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
	if (! $this -> setupBootLoaderConfiguration ("grub",$title)) {
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	#==========================================
	# Copy system image if given
	#------------------------------------------
	if ($gotsys) {
		$kiwi -> info ("Importing system image: $system");
		$status = qxx ("cp $system $tmpdir/$ibasename 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		$status = qxx ("cp $md5name $tmpdir/$ibasename.md5 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system md5 sum: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		qxx ( "$main::Gzip -d $system" );
		$system =~ s/\.gz$//;
		$kiwi -> done();
	}
	#==========================================
	# Create an iso image from the tree
	#------------------------------------------
	$kiwi -> info ("Creating ISO image");
	my $name = $system;
	if ($gotsys) {
		$name =~ s/raw$/iso/;
	} else {
		$name =~ s/gz$/iso/;
	}
	my $base = "-R -b boot/grub/stage2 -no-emul-boot";
	my $opts = "-boot-load-size 4 -boot-info-table -udf -allow-limited-size";
	if ($name !~ /^\//) {
		my $workingDir = qxx ( "pwd" ); chomp $workingDir;
		$name = $workingDir."/".$name;
	}
	$status = qxx ("cd $tmpdir && mkisofs $base $opts -o $name . 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating ISO image: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$kiwi -> done ();
	if (! $this -> relocateCatalog ($name)) {
		return undef;
	}
	#==========================================
	# Clean tmp
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	$kiwi -> info ("Created $name to be burned on CD");
	$kiwi -> done ();
	$this -> cleanTmp ();
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
	my $xengz     = $this->{xengz};
	my $irdsize   = -s $initrd;
	my $diskname  = $system.".install.raw";
	my $md5name   = $system;
	my %deviceMap = ();
	my @commands  = ();
	my $imgtype   = "oem";
	my $gotsys    = 1;
	my $status;
	my $result;
	my $ibasename;
	my $tmpdir;
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
		my $sdev = "/dev/mapper".$dmap."p2";
		if (! -e $sdev) {
			$sdev = "/dev/mapper".$dmap."p1";
		}
		my %fsattr = main::checkFileSystem ($sdev);
		$status = qxx ("mount -t $fsattr{type} $sdev $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to mount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
		}
		$status = qxx ("umount $tmpdir 2>&1"); sleep (1);
		$status = qxx ("/sbin/kpartx  -d $this->{loop} 2>&1");
		$status = qxx ("/sbin/losetup -d $this->{loop} 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to umount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	}
	$this->{imgtype} = $imgtype;
	#==========================================
	# Build md5sum of system image
	#------------------------------------------
	$this -> buildMD5Sum ($system);
	#==========================================
	# Compress system image
	#------------------------------------------
	$kiwi -> info ("Compressing installation image...");
	$md5name=~ s/\.raw$/\.md5/;
	$status = qxx ("$main::Gzip $system 2>&1");
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
	#==========================================
	# setup required disk size
	#------------------------------------------
	$irdsize= ($irdsize / 1e6) + 10;
	$irdsize= sprintf ("%.0f", $irdsize);
	$vmsize = -s $system;
	$vmsize = ($vmsize / 1e6) * 1.1 + $irdsize;
	$vmsize = sprintf ("%.0f", $vmsize);
	$vmsize = $vmsize."M";
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $nameusb = basename ($system);
	if ($gotsys) {
		if ($nameusb !~ /(.*)-(\d+\.\d+\.\d+)\.raw\.gz$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		$ibasename = $1.".gz";
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	$this->{initrd} = $initrd;
	#==========================================
	# Create Virtual Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this->{initrd} = $oldird;
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	#==========================================
	# Import boot loader stages
	#------------------------------------------
	if (! $this -> setupBootLoaderStages ("grub")) {
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	#==========================================
	# Creating boot loader configuration
	#------------------------------------------
	my $title = "KIWI USB-Stick Installation";
	if (! $gotsys) {
		$title = "KIWI USB Boot: $nameusb";
	}
	if (! $this -> setupBootLoaderConfiguration ("grub",$title)) {
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
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
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	$kiwi -> done();
	$kiwi -> info ("Binding virtual disk to loop device");
	if (! $this -> bindLoopDevice ($diskname)) {
		$kiwi -> failed ();
		$this -> cleanTmp ();
		qxx ( "$main::Gzip -d $system" );
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
		qxx ( "$main::Gzip -d $system" );
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
		qxx ( "$main::Gzip -d $system" );
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
		$status = qxx ( "/sbin/mke2fs $fsopts $root 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy boot data on first partition
	#------------------------------------------
	$kiwi -> info ("Installing boot data to virtual disk");
	$status = qxx ("mount $boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount boot partition: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	$status = qxx ("cp -a $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install boot data: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		qxx ( "$main::Gzip -d $system" );
		return undef;
	}
	qxx ( "umount $loopdir 2>&1" );
	$kiwi -> done();
	#==========================================
	# Copy system image if defined
	#------------------------------------------
	if ($gotsys) {
		$kiwi -> info ("Installing image data to virtual disk");
		$status = qxx ("mount $data $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount data partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		$status = qxx ("cp $system $loopdir/$ibasename 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		$status = qxx ("cp $md5name $loopdir/$ibasename.md5 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system md5 sum: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			qxx ( "$main::Gzip -d $system" );
			return undef;
		}
		qxx ( "umount $loopdir 2>&1" );
		qxx ( "$main::Gzip -d $system" );
		$kiwi -> done();
	}
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	qxx ( "/sbin/kpartx -d $this->{loop}" );
	#==========================================
	# Install boot loader on virtual disk
	#------------------------------------------
	if (! $this -> installBootLoader ("grub", $diskname, \%deviceMap)) {
		$this -> cleanLoop ();
		$this -> cleanTmp();
	}
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	qxx ("/sbin/losetup -d $this->{loop}");
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
	my $xengz     = $this->{xengz};
	my $lvm       = $this->{lvm};
	my $diskname  = $system.".raw";
	my %deviceMap = ();
	my @commands  = ();
	my $imgtype   = "vmx";
	my $bootfix   = "VMX";
	my $haveTree  = 0;
	my $haveSplit = 0;
	my $lvmbootMB = 0;
	my $syslbootMB= 0;
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
	#==========================================
	# add boot space if lvm based
	#------------------------------------------
	if ($lvm) {
		$lvmbootMB = 20;
	}
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
		$xml = new KIWIXML ( $kiwi,$system."/image",undef,$imgtype );
		if (! defined $xml) {
			$this -> cleanTmp ();
			return undef;
		}
		$haveTree = 1;
	} else {
		#==========================================
		# build disk name and label from xml data
		#------------------------------------------
		my %fsattr = main::checkFileSystem ($system);
		$status = qxx ("mount -t $fsattr{type} -o loop $system $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# check image type
		#------------------------------------------
		if (-f "$tmpdir/rootfs.tar") {
			$imgtype = "split";
		}
		$xml = new KIWIXML ( $kiwi,$tmpdir."/image",undef,$imgtype );
		$status = qxx ("umount $tmpdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to umount system image: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
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
	# setup boot loader type
	#------------------------------------------
	if ($type{bootloader}) {
		$bootloader = $type{bootloader};
	}
	$this->{bootloader} = $bootloader;
	#==========================================
	# add boot space if syslinux based
	#------------------------------------------
	if ($bootloader eq "syslinux") {
		$syslbootMB = 20;
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
	# check image split portion
	#------------------------------------------
	if ($imgtype eq "split") {
		if (-f $splitfile) {
			my $splitsize = -s $splitfile; $splitsize /= 1048576;
			$vmsize = $this->{vmmbyte} + ($splitsize * 1.3) + $lvmbootMB;
			$vmsize = sprintf ("%.0f", $vmsize);
			$this->{vmmbyte} = $vmsize;
			$vmsize = $vmsize."M";
			$this->{vmsize}  = $vmsize;
			$haveSplit = 1;
		}
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
	if (($syszip) || ($haveSplit) || ($lvm)) {
		$bootpart = "1";
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
	# Create boot loader configuration
	#------------------------------------------
	if (! $this -> setupBootLoaderConfiguration ($bootloader,$bootfix)) {
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
			if (($syszip) || ($haveSplit)) {
				# xda1 ro / xda2 rw
				if ($bootloader eq "syslinux") {
					my $syslsize = $this->{vmmbyte} - $syslbootMB - $syszip;
					@commands = (
						"n","p","1",".","+".$syszip."M",
						"n","p","2",".","+".$syslsize."M",
						"n","p","3",".",".",
						"t","3","6",
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
				if ($bootloader eq "syslinux") {
					my $syslsize = $this->{vmmbyte} - $syslbootMB;
					@commands = (
						"n","p","1",".","+".$syslsize."M",
						"n","p","2",".",".",
						"t","2","6",
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
			if ($bootloader eq "syslinux") {
				my $lvmsize = $this->{vmmbyte} - $syslbootMB;
				@commands = (
					"n","p","1",".","+".$lvmsize."M",
					"n","p","2",".",".",
					"t","2","6",
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
				\%deviceMap,$this->{loop},$syszip,$haveSplit
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
				qxx ("/sbin/kpartx  -d $this->{loop}");
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
		SWITCH: for ($FSTypeRO) {
			/^ext\d/    && do {
				$kiwi -> info ("Resizing system $FSTypeRO filesystem");
				$status = qxx ("/sbin/resize2fs -f -F -p $root 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Resizing system $FSTypeRO filesystem");
				$status = qxx ("/sbin/resize_reiserfs $root 2>&1");
				$result = $? >> 8;
				last SWITCH;
			}
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't resize $FSTypeRO filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
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
			SWITCH: for ($FSTypeRW) {
				/^ext\d/    && do {
					$kiwi -> info ("Resizing split $FSTypeRW filesystem");
					$status = qxx ("/sbin/resize2fs -f -F -p $root 2>&1");
					$result = $? >> 8;
					last SWITCH;
				};
				/^reiserfs/ && do {
					$kiwi -> info ("Resizing split $FSTypeRW filesystem");
					$status = qxx ("/sbin/resize_reiserfs $root 2>&1");
					$result = $? >> 8;
					last SWITCH;
				}
			};
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error("Couldn't resize $FSTypeRW filesystem: $status");
				$kiwi -> failed ();
				$this -> cleanTmp ();
				return undef;
			}
			if ($status) {
				$kiwi -> done();
			}
		}
	} else {
		#==========================================
		# Create fs on system image partition
		#------------------------------------------
		my %FSopts = main::checkFSOptions();
		SWITCH: for ($FSTypeRO) {
			/^ext2/     && do {
				$kiwi -> info ("Creating ext2 root filesystem");
				my $fsopts = $FSopts{ext2};
				$fsopts.= "-F";
				$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^ext3/     && do {
				$kiwi -> info ("Creating ext3 root filesystem");
				my $fsopts = $FSopts{ext3};
				$fsopts.= "-j -F";
				$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Creating reiserfs root filesystem");
				my $fsopts = $FSopts{reiserfs};
				$fsopts.= "-f";
				$status = qxx (
					"/sbin/mkreiserfs $fsopts $root 2>&1"
				);
				$result = $? >> 8;
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported filesystem type: $FSTypeRO");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $FSTypeRO filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Mount system image partition
		#------------------------------------------
		$status = qxx ("mount $root $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		#==========================================
		# Copy root tree to virtual disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on virtual disk");
		$status = qxx ("cp -a $system/* $loopdir 2>&1");
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
		qxx ( "umount $loopdir 2>&1" );
	}
	#==========================================
	# create read/write filesystem if needed
	#------------------------------------------
	if (($syszip) || ($haveSplit) || ($lvm)) {
		$root = $deviceMap{2};
		if ($lvm) {
			$root = $deviceMap{0};
		}
		if ((! $haveSplit) || ($lvm)) {
			$kiwi -> info ("Creating ext3 read-write filesystem");
			my %FSopts = main::checkFSOptions();
			my $fsopts = $FSopts{ext3};
			$fsopts.= "-F";
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
	}
	if ($bootloader eq "syslinux") {
		$root = $deviceMap{fat};
		$status = qxx ("/sbin/mkdosfs $root 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Couldn't create DOS filesystem: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	}
	#==========================================
	# Dump boot image on virtual disk
	#------------------------------------------
	$kiwi -> info ("Copying boot image to virtual disk");
	#==========================================
	# Mount system image / or rw partition
	#------------------------------------------
	$status = qxx ("mount $root $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	#==========================================
	# Copy boot data on system image
	#------------------------------------------
	$status = qxx ("cp -a $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Couldn't copy boot data to system image: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	qxx ( "umount $loopdir 2>&1" );
	$kiwi -> done();
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	if ($lvm) {
		qxx ("vgchange -an 2>&1");
	}
	qxx ("/sbin/kpartx -d $this->{loop}");
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
		if ($imgtype eq "oem") {
			#==========================================
			# OEM formats...
			#------------------------------------------
			if ($format eq "iso") {
				$this -> {system} = $diskname;
				$kiwi -> info ("Creating install ISO image\n");
				qxx ("/sbin/losetup -d $this->{loop}");
				if (! $this -> setupInstallCD()) {
					return undef;
				}
			}
			if ($format eq "usb") {
				$this -> {system} = $diskname;
				$kiwi -> info ("Creating install USB Stick image\n");
				qxx ("/sbin/losetup -d $this->{loop}");
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
	qxx ( "/sbin/losetup -d $this->{loop} 2>&1" );
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
		print FD "IMAGE=nope;$ibasename;$iversion;compressed\n";
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
	my $spldir = $initrd."_".$$.".splash";
	my $irddir = "$spldir/initrd";
	my $zipped = 0;
	my $newird;
	my $status;
	my $result;
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
	$kiwi -> info ("Setting up splash screen...");
	if (! mkdir $spldir) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Failed to create splash directory");
		$kiwi -> skipped ();
		return $initrd;
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
		qxx ("vgchange -an 2>&1");
	}
	my $tmpdir = $this->{tmpdir};
	my $loopdir= $this->{loopdir};
	qxx ("rm -rf $tmpdir");
	qxx ("rm -rf $loopdir");
	return $this;
}

#==========================================
# cleanLoop
#------------------------------------------
sub cleanLoop {
	my $this = shift;
	my $tmpdir = $this->{tmpdir};
	my $loop   = $this->{loop};
	my $loopdir= $this->{loopdir};
	qxx ("umount $loopdir 2>&1");
	if (defined $loop) {
		if ($this->{lvm}) {
			qxx ("vgchange -an 2>&1");
		}
		qxx ("/sbin/kpartx  -d $loop 2>&1");
		qxx ("/sbin/losetup -d $loop 2>&1");
		undef $this->{loop};
	}
	qxx ("rm -rf $tmpdir");
	qxx ("rm -rf $loopdir");
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
# relocateCatalog
#------------------------------------------
sub relocateCatalog {
	# ...
	# mkisofs/genisoimage leave one sector empty (or fill it with
	# version info if the ISODEBUG environment variable is set) before
	# starting the path table. We use this space to move the boot
	# catalog there. It's important that the boot catalog is at the
	# beginning of the media to be able to boot on any machine
	# ---
	my $this = shift;
	my $iso  = shift;
	my $kiwi = $this->{kiwi};
	$kiwi -> info ("Relocating boot catalog ");
	sub read_sector {
		my $buf;
		if (! seek ISO, $_[0] * 0x800, 0) {
			return undef;
		}
		if (sysread(ISO, $buf, 0x800) != 0x800) {
			return undef;
		}
		return $buf;
	}
	sub write_sector {
		if (! seek ISO, $_[0] * 0x800, 0) {
			return undef;
		}
		if (syswrite(ISO, $_[1], 0x800) != 0x800) {
			return undef;
		}
	}
	if (! open ISO, "+<$iso") {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed opening iso file: $iso: $!");
		$kiwi -> failed ();
		return undef;
	}
	my $vol_descr = read_sector 0x10;
	my $vol_id = substr($vol_descr, 0, 7);
	if ($vol_id ne "\x01CD001\x01") {
		$kiwi -> failed ();
		$kiwi -> error  ("No iso9660 filesystem");
		$kiwi -> failed ();
		return undef;
	}
	my $path_table = unpack "V", substr($vol_descr, 0x08c, 4);
	if ($path_table < 0x11) {
		$kiwi -> failed ();
		$kiwi -> error  ("Strange path table location: $path_table");
		$kiwi -> failed ();
		return undef;
	}
	my $new_location = $path_table - 1;
	my $eltorito_descr = read_sector 0x11;
	my $eltorito_id = substr($eltorito_descr, 0, 0x1e);
	if ($eltorito_id ne "\x00CD001\x01EL TORITO SPECIFICATION") {
		$kiwi -> failed ();
		$kiwi -> error  ("Given iso is not bootable");
		$kiwi -> failed ();
		return undef;
	}
	my $boot_catalog = unpack "V", substr($eltorito_descr, 0x47, 4);
	if ($boot_catalog < 0x12) {
		$kiwi -> failed ();
		$kiwi -> error  ("Strange boot catalog location: $boot_catalog");
		$kiwi -> failed ();
		return undef;
	}
	my $vol_descr2 = read_sector $new_location - 1;
	my $vol_id2 = substr($vol_descr2, 0, 7);
	if($vol_id2 ne "\xffCD001\x01") {
		undef $new_location;
		for (my $i = 0x12; $i < 0x40; $i++) {
			$vol_descr2 = read_sector $i;
			$vol_id2 = substr($vol_descr2, 0, 7);
			if ($vol_id2 eq "\x00TEA01\x01" || $boot_catalog == $i + 1) {
				$new_location = $i + 1;
				last;
			}
		}
	}
	if (! defined $new_location) {
		$kiwi -> failed ();
		$kiwi -> error  ("Unexpected iso layout");
		$kiwi -> failed ();
		return undef;
	}
	if ($boot_catalog == $new_location) {
		$kiwi -> skipped ();
		$kiwi -> info ("Boot catalog already relocated");
		$kiwi -> done ();
		return $this;
	}
	my $version_descr = read_sector $new_location;
	if (
		($version_descr ne ("\x00" x 0x800)) &&
		(substr($version_descr, 0, 4) ne "MKI ")
	) {
		$kiwi -> skipped ();
		$kiwi -> info  ("Unexpected iso layout");
		$kiwi -> skipped ();
		return $this;
	}
	my $boot_catalog_data = read_sector $boot_catalog;
	#==========================================
	# now reloacte to $path_table - 1
	#------------------------------------------
	substr($eltorito_descr, 0x47, 4) = pack "V", $new_location;
	write_sector $new_location, $boot_catalog_data;
	write_sector 0x11, $eltorito_descr;
	close ISO;
	$kiwi -> note ("from sector $boot_catalog to $new_location");
	$kiwi -> done();
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
	if ($loader eq "syslinux") {
		my $message= "'image/loader/message'";
		my $unzip  = "$main::Gzip -cd $initrd 2>&1";
		#==========================================
		# Get syslinux graphics boot message
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
		# Get syslinux vesamenu extension
		#------------------------------------------
		$kiwi -> info ("Importing graphics boot message");
		qxx ("mkdir -p $tmpdir/boot/syslinux 2>&1");
		qxx ("cp /usr/share/syslinux/vesamenu.c32 $tmpdir/boot/syslinux 2>&1");
		if (-e $tmpdir."/boot/syslinux/vesamenu.c32") {
			$kiwi -> done();
		} else {
			$kiwi -> skipped();
		}
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
	my $kiwi     = $this->{kiwi};
	my $tmpdir   = $this->{tmpdir};
	my $initrd   = $this->{initrd};
	my $isxen    = $this->{isxen};
	my $imgtype  = $this->{imgtype};
	my $bootpart = $this->{bootpart};
	my $label    = $this->{bootlabel};
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
		if ($type =~ /^KIWI CD/) {
			print FD "gfxmenu (cd)/boot/message\n";
			print FD "title _".$type."_\n";
		} elsif ($type =~ /^KIWI USB/) {
			print FD "gfxmenu (hd0,0)/boot/message\n";
			print FD "title _".$type."_\n";
		} else {
			print FD "gfxmenu (hd0,$bootpart)/boot/message\n";
			print FD "title _".$label." [ ".$type." ]_\n";
		}
		#==========================================
		# Standard boot
		#------------------------------------------
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				print FD " kernel (cd)/boot/linux vga=0x314 splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux.vmx vga=0x314 splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux vga=0x314 splash=silent";
			}
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts";
			} else {
				print FD " showopts";
			}
			print FD "\n";
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
				print FD " module /boot/linux vga=0x314 splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz.vmx\n";
				print FD " module /boot/linux.vmx vga=0x314 splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz\n";
				print FD " module /boot/linux vga=0x314 splash=silent";
			}
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts";
			} else {
				print FD " showopts";
			}
			print FD "\n";
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
		if ($type =~ /^KIWI CD/) {
			print FD "title _Failsafe -- ".$type."_\n";
		} elsif ($type =~ /^KIWI USB/) {
			print FD "title _Failsafe -- ".$type."_\n";
		} else {
			print FD "title _Failsafe -- ".$label." [ ".$type." ]_\n";
		}
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				print FD " kernel (cd)/boot/linux vga=0x314 splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux.vmx vga=0x314 splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/linux vga=0x314 splash=silent";
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off\n";
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts";
			} else {
				print FD " showopts";
			}
			print FD "\n";
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
				print FD " module (cd)/boot/linux vga=0x314 splash=silent";
				print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz.vmx\n";
				print FD " module /boot/linux.vmx vga=0x314 splash=silent";
			} else {
				print FD " root (hd0,$bootpart)\n";
				print FD " kernel /boot/xen.gz\n";
				print FD " module /boot/linux vga=0x314 splash=silent";
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts";
			} else {
				print FD " showopts";
			}
			print FD "\n";
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
	if ($loader eq "syslinux") {
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
		# Create syslinux.cfg file
		#------------------------------------------
		$kiwi -> info ("Creating syslinux config file...");
		if (! open (FD,">$tmpdir/boot/syslinux/syslinux.cfg")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create syslinux.cfg: $!");
			$kiwi -> failed ();
			return undef;
		}
		#==========================================
		# General syslinux setup
		#------------------------------------------
		print FD "DEFAULT vesamenu.c32\n";
		print FD "TIMEOUT 100\n";
		if ($type =~ /^KIWI CD/) {
			# not supported yet..
		} elsif ($type =~ /^KIWI USB/) {
			print FD "LABEL Linux\n";
			print FD "MENU LABEL ".$type."\n";
		} else {
			print FD "LABEL Linux\n";
			print FD "MENU LABEL ".$label." [ ".$type." ]\n";
		}
		#==========================================
		# Standard boot
		#------------------------------------------
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				# not supported yet..
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				print FD "KERNEL /boot/linux.vmx\n";
				print FD "APPEND ro initrd=/boot/initrd.vmx ";
				print FD "vga=0x314 splash=silent";
			} else {
				print FD "KERNEL /boot/linux\n";
				print FD "APPEND ro initrd=/boot/initrd ";
				print FD "vga=0x314 splash=silent";
			}
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts\n";
			} else {
				print FD " showopts\n";
			}
		} else {
			if ($type =~ /^KIWI CD/) {
				# not supported yet..
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				# not supported yet..
			} else {
				# not supported yet..
			}
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts\n";
			} else {
				print FD " showopts\n";
			}
		}
		#==========================================
		# Failsafe boot
		#------------------------------------------
		if ($type =~ /^KIWI CD/) {
			# not supported yet..
		} elsif ($type =~ /^KIWI USB/) {
			print FD "LABEL Failsafe\n";
			print FD "MENU LABEL Failsafe -- ".$type."\n";
		} else {
			print FD "LABEL Failsafe\n";
			print FD "MENU LABEL Failsafe -- ".$label." [ ".$type." ]\n";
		}
		if (! $isxen) {
			if ($type =~ /^KIWI CD/) {
				# not supported yet..
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				print FD "KERNEL /boot/linux.vmx\n";
				print FD "APPEND ro initrd=/boot/initrd.vmx ";
				print FD "vga=0x314 splash=silent";
			} else {
				print FD "KERNEL /boot/linux\n";
				print FD "APPEND ro initrd=/boot/initrd ";
				print FD "vga=0x314 splash=silent";
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts\n";
			} else {
				print FD " showopts\n";
			}
		} else {
			if ($type =~ /^KIWI CD/) {
				# not supported yet..
			} elsif (($type=~ /^KIWI USB/)||($imgtype=~ /vmx|oem|split|usb/)) {
				# not supported yet..
			} else {
				# not supported yet..
			}
			print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
			print FD " noapic maxcpus=0 edd=off";
			if ($imgtype eq "split") {
				print FD " COMBINED_IMAGE=yes showopts\n";
			} else {
				print FD " showopts\n";
			}
		}
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
		print FD "setup (hd0)\n";
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
		$kiwi -> done();
	}
	#==========================================
	# syslinux
	#------------------------------------------
	if ($loader eq "syslinux") {
		if (! $deviceMap) {
			$kiwi -> failed ();
			$kiwi -> error  ("No device map available");
			$kiwi -> failed ();
			return undef;
		}
		my %deviceMap = %{$deviceMap};
		my $device = $deviceMap{fat};
		if ($device =~ /mapper/) {
			qxx ("kpartx -a $diskname");
		}
		$kiwi -> info ("Installing syslinux on device: $device");
		$status = qxx ("syslinux $device 2>&1");
		$result = $? >> 8;
		if ($device =~ /mapper/) {
			qxx ("kpartx -d $diskname");
		}
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install syslinux on $device: $status");
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
			$status = qxx ("/sbin/sfdisk -s $pdev 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		#==========================================
		# parted
		#------------------------------------------
		/^parted/  && do {
			my $parted = "/usr/sbin/parted -m ";
			my $disk   = $pdev;
			my $step   = 2;
			if ($pdev =~ /mapper/) {
				if ($pdev =~ /mapper\/(.*)p(\d+)/) {
					$disk = "/dev/".$1;
					$pdev = "/dev/".$1.$2;
					$step = 4;
				}
			} else {
				if ($pdev =~ /(.*)(\d+)/) {
					$disk = $1;
					$step = 4;
				}
			}
			$parted .= '-s '.$disk.' unit B print |';
			$parted .= 'sed -e "s@^\([0-4]\):@'.$disk.'\1:@" |';
			$parted .= 'grep ^'.$pdev.':|cut -f'.$step.' -d: | tr -d B';
			$status = qxx ($parted);
			$result = $? >> 8;
			if ((! $status) && ($pdev =~ /loop/)) {
				$status = qxx ("/usr/sbin/parted -s $pdev mklabel msdos 2>&1");
				$status = qxx ($parted);
				$result = $? >> 8;
			}
			$status /= 1000;
			last SWITCH;
		}
	}
	if ($result == 0) {
		return int $status;
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
	my %result;
	if (! defined $device) {
		return undef;
	}
	for (my $i=1;$i<=2;$i++) {
		$result{$i} = $device.$i;
	}
	if ($loader eq "syslinux") {
		for (my $i=1;$i<=3;$i++) {
			my $type = $this -> getStorageID ($device.$i);
			if ($type == 6) {
				$result{fat} = $device.$i;
				last;
			}
		}
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
	my %result;
	if (! defined $device) {
		return undef;
	}
	my $dmap = $device; $dmap =~ s/dev\///;
	for (my $i=1;$i<=2;$i++) {
		$result{$i} = "/dev/mapper".$dmap."p$i";
	}
	if ($loader eq "syslinux") {
		for (my $i=1;$i<=3;$i++) {
			my $type = $this -> getStorageID ("/dev/mapper".$dmap."p$i");
			if ($type == 6) {
				$result{fat} = "/dev/mapper".$dmap."p$i";
				last;
			}
		}
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
	if ($loader eq "syslinux") {
		if ($device =~ /loop/) {
			my $dmap = $device; $dmap =~ s/dev\///;
			for (my $i=1;$i<=3;$i++) {
				my $type = $this -> getStorageID ("/dev/mapper".$dmap."p$i");
				if ($type == 6) {
					$result{fat} = "/dev/mapper".$dmap."p$i";
					last;
				}
			}
		} else {
			for (my $i=1;$i<=3;$i++) {
				my $type = $this -> getStorageID ($device.$i);
				if ($type == 6) {
					$result{fat} = $device.$i;
					last;
				}
			}
		}
	}
	return %result;
}

#==========================================
# setVolumeGroup
#------------------------------------------
sub setVolumeGroup {
	# ...
	# create kiwiVG volume group and required logical 
	# volumes. The function returns a new device map
	# including the volume device names
	# ---
	my $this      = shift;
	my $map       = shift;
	my $device    = shift;
	my $syszip    = shift;
	my $haveSplit = shift;
	my $kiwi      = $this->{kiwi};
	my %deviceMap = %{$map};
	my $VGroup    = "kiwiVG";
	my %newmap;
	my $status;
	my $result;
	$status = qxx ("vgremove --force $VGroup 2>&1");
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
		$status = qxx ("lvcreate -l 100%FREE -n LVRoot $VGroup 2>&1");
		$result = $? >> 8;
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
	my $VGroup = "kiwiVG";
	if ($lvm) {
		qxx ("vgremove --force $VGroup 2>&1");
	}
	return $this;
}

1; 
