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
use dbusdevice;
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
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $syszip    = 0;
	my $sysird    = 0;
	my $zipped    = 0;
	my $loopfound = 0;
	my $loop      = "/dev/loop0";
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
	$tmpdir = qxx ( "mktemp -q -d /tmp/kiwiboot.XXXXXX" ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	$loopdir = qxx ( "mktemp -q -d /tmp/kiwiloop.XXXXXX" ); chomp $loopdir;
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
			$xml = new KIWIXML ($kiwi,$system."/image");
		} else {
			my %fsattr = main::checkFileSystem ($system);
			if (! $fsattr{type}) {
				#==========================================
				# search free loop device
				#------------------------------------------
				$kiwi -> info ("Searching for free loop device...");
				for (my $id=0;$id<=7;$id++) {
					$status = qxx ( "/sbin/losetup /dev/loop$id 2>&1" );
					$result = $? >> 8;
					if ($result eq 1) {
						$loopfound = 1;
						$loop = "/dev/loop".$id;
						$this->{loop} = $loop;
						last;
					}
				}
				if (! $loopfound) {
					$kiwi -> failed ();
					$kiwi -> error  ("Couldn't find free loop device");
					$kiwi -> failed ();
					$this -> cleanTmp ();
					return undef;
				}
				$kiwi -> done();
				#==========================================
				# bind $system to loop device
				#------------------------------------------
				$kiwi -> info ("Binding virtual disk to loop device");
				$status = qxx ( "/sbin/losetup $loop $system 2>&1" );
				$result = $? >> 8;
				if ($result != 0) {
					$kiwi -> failed ();
					$kiwi -> error  ("Failed binding virtual disk: $status");
					$kiwi -> failed ();
					$this -> cleanTmp ();
					return undef;
				}
				$kiwi -> done();
				#==========================================
				# setup device mapper
				#------------------------------------------
				$kiwi -> info ("Setup device mapper for ISO install image");
				$status = qxx ( "/sbin/kpartx -a $loop 2>&1" );
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
				my $dmap = $loop; $dmap =~ s/dev\///;
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
				$xml = new KIWIXML ( $kiwi,$tmpdir."/image");
				#==========================================
				# clean up
				#------------------------------------------
				qxx ("umount $tmpdir 2>&1");
				qxx ("kpartx -d $loop");
				qxx ("losetup -d $loop");
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
				$xml = new KIWIXML ( $kiwi,$tmpdir."/image");
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
		my $kernelSize = -s $kernel; # the kernel
		my $initrdSize = -s $initrd; # the boot image
		my $systemSXML = 1; # system size set by XML file
		my $systemSize = 0; # the system image size in bytes
		# /.../
		# Note: In case of a split system the vmsize value will
		# be increased according to the size of the split portion
		# This happens within the function which requires it but
		# not at the following code
		# ----
		if (-d $system) {
			$systemSXML = $xml -> getImageSizeBytes();
			$systemSize = qxx ("du -bs $system | cut -f1 2>&1");
			chomp $systemSize;
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
			# use the calculated value plus 30% free space 
			$vmsize+= $vmsize * 0.3;
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
		$initrd = $this -> setupSplashForGrub();
		$zipped = 1;
	}
	$kiwi -> info ("Creating initial boot structure");
	$status = qxx ( "mkdir -p $tmpdir/boot/grub 2>&1" );
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
					my @bdevs = glob ($description);
					$description = "/dev/".$bdevs[0];
					$isremovable = $description."/".$bdevs[0]."/removable";
				}
				if (! open (FD,$isremovable)) {
					next;
				}
				$isremovable = <FD>; close FD;
				if ($isremovable == 1) {
					my $status = qxx ("/sbin/sfdisk -s $description 2>&1");
					my $result = $? >> 8;
					if ($result == 0) {
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
	my $imgtype   = "usb";
	my $haveSplit = 0;
	my $haveTree  = 0;
	my $FSTypeRW;
	my $FSTypeRO;
	my $sysird;
	my $status;
	my $result;
	my $hald;
	my $xml;
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
	# check image split portion
	#------------------------------------------
	my $destdir  = dirname ($initrd);
	my $label    = $xml -> getImageName();
	my $version  = $xml -> getImageVersion();
	my $splitfile= $destdir."/".$label."-read-write.".$arch."-".$version;
	if ($imgtype eq "split") {
		if (-f $splitfile) {
			$haveSplit = 1;
		}
	}
	#==========================================
	# obtain filesystem type from xml data
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes()};
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
	if (! $this -> createBootStructure()) {
		return undef;
	}
	#==========================================
	# Import grub stages
	#------------------------------------------
	my $stages = "'usr/lib/grub/*'";
	my $unzip  = "$main::Gzip -cd $initrd 2>&1";
	$kiwi -> info ("Importing grub stages for stick boot");
	if ($zipped) {
		$status = qxx ("$unzip | (cd $tmpdir && cpio -di $stages 2>&1)");
	} else {
		$status = qxx ("cat $initrd | (cd $tmpdir && cpio -di $stages 2>&1)");
	}
	$result = $? >> 8;
	if ($result == 0) {
		$status = qxx ( "mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> skipped (); chomp $status;
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qxx ( "cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
	}
	$kiwi -> done ();
	#==========================================
	# Find USB stick devices
	#------------------------------------------
	my %storage = getRemovableUSBStorageDevices();
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
	# Creating menu.lst for the grub
	#------------------------------------------
	$kiwi -> info ("Creating grub menu list file...");
	if (! open (FD,">$tmpdir/boot/grub/menu.lst")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create menu.lst: $!");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,0)/image/loader/message\n";
	print FD "\n";
	print FD "title $label [ USB ]\n";
	if (! $isxen) {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/linux vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " initrd /boot/initrd\n";
	} else {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/xen.gz\n";
		print FD " module /boot/linux vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " module /boot/initrd\n";
	}
	print FD "title Failsafe -- $label [ USB ]\n";
	if (! $isxen) {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/linux vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts";
		} else {
			print FD " showopts";
		}
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off\n";
		print FD " initrd /boot/initrd\n";
	} else {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/xen.gz\n";
		print FD " module /boot/linux vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts";
		} else {
			print FD " showopts";
		}
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off\n";
		print FD " module /boot/initrd\n";
	}
	close FD;
	$kiwi -> done();
	#==========================================
	# Create ext2 image for boot image
	#------------------------------------------
	$kiwi -> info ("Creating stick image");
	my $name = $initrd.".stickboot";
	if ($zipped) {
		$name = $initrd; $name =~ s/gz$/stickboot/;
	}
	my $size = qxx ("du -ms $tmpdir | cut -f1 2>&1");
	my $ddev = "/dev/zero";
	chomp ($size); $size += 1; # add 1M free space for filesystem
	$sysird = $size;
	$status = qxx ("dd if=$ddev of=$name bs=1M seek=$sysird count=1 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create image file: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$sysird += 1; # add another 1M free space because of sparse seek
	$status = qxx ("/sbin/mkfs.ext2 -b 4096 -F $name 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create filesystem: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$status = qxx ("mount -o loop $name $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$status = qxx ("mv $tmpdir/boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install image: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# check for message file in initrd
	#------------------------------------------
	my $message = "'image/loader/message'";
	$unzip = "$main::Gzip -cd $initrd 2>&1";
	if ($zipped) {
		$status = qxx ("$unzip | (cd $loopdir && cpio -d -i $message 2>&1)");
	} else {
		$status = qxx ("cat $initrd | (cd $loopdir&&cpio -d -i $message 2>&1)");
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find message file: $status");
		$kiwi -> failed ();
		qxx ("umount $loopdir 2>&1");
		$this -> cleanTmp ();
		return undef;
	}
	qxx ("umount $loopdir 2>&1");
	$kiwi -> done();
	#==========================================
	# umount stick mounted by hal before lock
	#------------------------------------------
	for (my $i=1;$i<=4;$i++) {
		qxx ( "umount $stick$i 2>&1" );
	}
	#==========================================
	# Wait for umount to settle
	#------------------------------------------
	sleep (1);
	#==========================================
	# Establish HAL lock for $stick
	#------------------------------------------
	$kiwi -> info ("Establish HAL lock for: $stick");
	$hald = new dbusdevice::HalConnection;
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
	# Create new partition table on stick
	#------------------------------------------
	$kiwi -> info ("Creating partition table on: $stick");
	my $pinfo = "$tmpdir/sfdisk.input";
	if (! open (FD,">$pinfo")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create temporary partition data: $!");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanTmp ();
		return undef;
	}
	#==========================================
	# Prepare sfdisk input file
	#------------------------------------------
	if (defined $system) {
		if (($syszip) || ($haveSplit)) {
			print FD ",$sysird,L,*\n"; # xda1  boot
			print FD ",$syszip,L\n";   # xda2  ro
			print FD ",,L\n";          # xda3  rw
			$kiwi -> loginfo (
				"USB sfdisk input: [,$sysird,L,*][,$syszip,L][,,L]"
			);
		} else {
			print FD ",$sysird,L,*\n"; # xda1  boot
			print FD ",,L\n";          # xda2  rw
			$kiwi -> loginfo (
				"USB sfdisk input: [,$sysird,L,*][,,L]"
			);
		}
	} else {
		print FD ",,L,*\n";
		$kiwi -> loginfo ("USB sfdisk input: [,,L,*]");
	}
	close FD;
	$status = qxx ( "dd if=/dev/zero of=$stick bs=512 count=1 2>&1" );	
	$result = $? >> 8;
	$status = qxx ( "/sbin/sfdisk -uM --force $stick < $pinfo 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create partition table: $!");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanTmp ();
		return undef;
	}
	$kiwi -> done();
	$kiwi -> loginfo ("USB Partitions: $status");
	for (my $i=1;$i<=3;$i++) {
		qxx ( "umount $stick$i 2>&1" );
	}
	$kiwi -> info ("Rereading partition table on: $stick");
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
	$kiwi -> done();
	#==========================================
	# Clean partition info file
	#------------------------------------------
	unlink $pinfo;
	#==========================================
	# Wait for new partition table to settle
	#------------------------------------------
	sleep (1);
	#==========================================
	# Dump initrd image on stick
	#------------------------------------------
	$kiwi -> info ("Dumping initrd image to stick");
	$status = qxx ( "umount $stick'1' 2>&1" );
	$status = qxx ("dd if=$name of=$stick'1' bs=32k 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't dump boot image to stick: $status");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanTmp ();
		return undef;
	}
	unlink $name;
	$kiwi -> done();
	#==========================================
	# Dump system image on stick
	#------------------------------------------
	if (! $haveTree) {
		$kiwi -> info ("Dumping system image to stick");
		$status = qxx ( "umount $stick'1' 2>&1" );
		$status = qxx ( "umount $stick'2' 2>&1" );
		$status = qxx ("dd if=$system of=$stick'2' bs=32k 2>&1");
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
			$status = qxx ("dd if=$splitfile of=$stick'3' bs=32k 2>&1");
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
		SWITCH: for ($FSTypeRO) {
			/^ext2/     && do {
				$kiwi -> info ("Creating ext2 root filesystem");
				my $fsopts = "-q -F";
				$status = qxx ("/sbin/mke2fs $fsopts $stick'2' 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^ext3/     && do {
				$kiwi -> info ("Creating ext3 root filesystem");
				my $fsopts = "-O dir_index -b 4096 -j -J size=4 -q -F";
				$status = qxx ("/sbin/mke2fs $fsopts $stick'2' 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Creating reiserfs root filesystem");
				$status = qxx (
					"/sbin/mkreiserfs -q -f -s 513 -b 4096 $stick'2' 2>&1"
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
		$status = qxx ("mount $stick'2' $loopdir 2>&1");
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
			$status = qxx ("/sbin/resize2fs -f -F -p $stick'2' 2>&1");
			$result = $? >> 8;
			last SWITCH;
		};
		/^reiserfs/ && do {
			$kiwi -> info ("Resizing system $FSTypeRO filesystem");
			$status = qxx ("/sbin/resize_reiserfs $stick'2' 2>&1");
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
				$status = qxx ("/sbin/resize2fs -f -F -p $stick'3' 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Resizing split $FSTypeRW filesystem");
				$status = qxx ("/sbin/resize_reiserfs $stick'3' 2>&1");
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
	# Mount system img for removal of boot data
	#------------------------------------------
	# Remove /boot from system image, we are booting from
	# the kiwi initrd image and so the system image doesn't need
	# any boot kernel/initrd. Problem is if the system image is
	# a read-only image we can't remove data from it
	# ---
	if (! $syszip) {
		$kiwi -> info ("Removing unused boot kernel/initrd from stick");
		$status = qxx ("mount $stick'2' $loopdir 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount stick image: $status");
			$kiwi -> failed ();
			$this -> cleanDbus();
			$this -> cleanTmp ();
			return undef;
		}
		if (-d "/mnt/boot") {
			$status = qxx ("rm -r /mnt/boot 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> skipped ();
				$kiwi -> warning ("Couldn't remove data: $status");
				$kiwi -> skipped ();
			} else {
				$kiwi -> done();
			}
		} else {
			$kiwi -> done();
		}
		qxx ("umount $loopdir 2>&1");
	}
	#==========================================
	# Install grub on USB stick
	#------------------------------------------
	$kiwi -> info ("Installing grub on USB stick");
	if (! open (FD,"|/usr/sbin/grub --batch &> $tmpdir/grub.log")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't call grub: $!");
		$kiwi -> failed ();
		$this -> cleanDbus();
		$this -> cleanTmp ();
		return undef;
	}
	print FD "device (hd0) $stick\n";
	print FD "root (hd0,0)\n";
	print FD "setup (hd0)\n";
	print FD "quit\n";
	close FD;
	my $glog;
	if (open (FD,"$tmpdir/grub.log")) {
		my @glog = <FD>; close FD;
		$glog = join ("\n",@glog);
		$kiwi -> loginfo ("GRUB: $glog");
	}
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# check grub installation
	#------------------------------------------
	qxx ("file $stick | grep -q 'boot sector'");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on USB stick: $glog");
		$kiwi -> failed ();
		$this -> cleanDbus();
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# Remove dbus lock for $stick
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
	my $loop      = "/dev/loop0";
	my $imgtype   = "oem";
	my $gotsys    = 1;
	my $loopfound = 0;
	my $status;
	my $result;
	my $ibasename;
	my $tmpdir;
	#==========================================
	# create tmp directory
	#------------------------------------------
	$tmpdir = qxx ( "mktemp -q -d /tmp/kiwicdinst.XXXXXX" ); chomp $tmpdir;
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
		# search free loop device
		#------------------------------------------
		$kiwi -> info ("Searching for free loop device...");
		for (my $id=0;$id<=7;$id++) {
			$status = qxx ( "/sbin/losetup /dev/loop$id 2>&1" );
			$result = $? >> 8;
			if ($result eq 1) {
				$loopfound = 1;
				$loop = "/dev/loop".$id;
				$this->{loop} = $loop;
				last;
			}
		}
		if (! $loopfound) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't find free loop device");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# bind $system to loop device
		#------------------------------------------
		$kiwi -> info ("Binding virtual disk to loop device");
		$status = qxx ( "/sbin/losetup $loop $system 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed binding virtual disk: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# setup device mapper
		#------------------------------------------
		$kiwi -> info ("Setup device mapper for virtual partition access");
		$status = qxx ( "/sbin/kpartx -a $loop 2>&1" );
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
		my $dmap = $loop; $dmap =~ s/dev\///;
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
		$status = qxx ("/sbin/kpartx  -d $loop 2>&1");
		$status = qxx ("/sbin/losetup -d $loop 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to umount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	}
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $namecd = basename ($system);
	if ($gotsys) {
		if ($namecd !~ /(.*)-(\d+\.\d+\.\d+)\.raw$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$ibasename = $1;
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		$this -> cleanTmp ();
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
	# Import grub stages
	#------------------------------------------
	$kiwi -> info ("Importing grub stages for CD boot");
	my $stage1 = "'usr/lib/grub/stage1'";
	my $stage2 = "'usr/lib/grub/stage2_eltorito'";
	my $message= "'image/loader/message'";
	my $unzip  = "$main::Gzip -cd $initrd 2>&1";
	$status = qxx ("$unzip | (cd $tmpdir && cpio -d -i $message 2>&1)");
	$result = $? >> 8;
	if ($result == 0) {
		$status = qxx ("$unzip | (cd $tmpdir && cpio -d -i $stage1 2>&1)");
		$result = $? >> 8;
		if ($result == 0) {
			$status = qxx ("$unzip | (cd $tmpdir && cpio -d -i $stage2 2>&1)");
		}
	}
	if ($result == 0) {
		$status = qxx ("mv $tmpdir/$message $tmpdir/boot/message 2>&1");
		$result = $? >> 8;
		if ($result == 0) {
			$status = qxx ("mv $tmpdir/$stage1 $tmpdir/boot/grub/stage1 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx (
					"mv $tmpdir/$stage2 $tmpdir/boot/grub/stage2 2>&1"
				);
				$result = $? >> 8;
			}
		}
	}
	if ($result != 0) {
		$kiwi -> skipped (); chomp $status;
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qxx ( "cp /$stage1 $tmpdir/boot/grub/stage1 2>&1" );
		$status = qxx ( "cp /$stage2 $tmpdir/boot/grub/stage2 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			$this->{initrd} = $oldird;
			$this -> cleanTmp ();
			return undef;
		}
	}
	qxx ("rm -rf $tmpdir/usr 2>&1");
	qxx ("rm -rf $tmpdir/image 2>&1");
	$this->{initrd} = $oldird;
	$kiwi -> done ();

	#==========================================
	# Creating menu.lst for the grub
	#------------------------------------------
	$kiwi -> info ("Creating grub menu");
	if (! open (FD,">$tmpdir/boot/grub/menu.lst")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create menu.lst: $!");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	my $title = "KIWI CD Installation";
	if (! $gotsys) {
		$title = "KIWI CD Boot: $namecd";
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (cd)/boot/message\n";
	print FD "title $title\n";
	if (! $isxen) {
		print FD " kernel (cd)/boot/linux vga=0x314 splash=silent";
		print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " initrd (cd)/boot/initrd\n";
	} else {
		print FD " kernel (cd)/boot/xen.gz\n";
		print FD " module /boot/linux vga=0x314 splash=silent";
		print FD " ramdisk_size=512000 ramdisk_blocksize=4096";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " module (cd)/boot/initrd\n" 
	}
	print FD "title Failsafe -- $title\n";
	if (! $isxen) {
		print FD " kernel (cd)/boot/linux vga=0x314 splash=silent";
		print FD " ramdisk_size=512000 ramdisk_blocksize=4096 showopts";
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes\n";
		} else {
			print FD "\n";
		}
		print FD " initrd (cd)/boot/initrd\n";
	} else {
		print FD " kernel (cd)/boot/xen.gz\n";
		print FD " module /boot/linux vga=0x314 splash=silent";
		print FD " ramdisk_size=512000 ramdisk_blocksize=4096 showopts";
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes\n";
		} else {
			print FD "\n";
		}
		print FD " module (cd)/boot/initrd\n"
	}
	close FD;
	$kiwi -> done();

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
			return undef;
		}
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
	my $base = "-R -b boot/grub/stage2";
	my $opts = "-no-emul-boot -boot-load-size 4 -boot-info-table";
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
	my $diskname  = $system.".install.raw";
	my $loop      = "/dev/loop0";
	my $imgtype   = "oem";
	my $loopfound = 0;
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
	# search free loop device
	#------------------------------------------
	$kiwi -> info ("Searching for free loop device...");
	for (my $id=0;$id<=7;$id++) {
		$status = qxx ( "/sbin/losetup /dev/loop$id 2>&1" );
		$result = $? >> 8;
		if ($result eq 1) {
			$loopfound = 1;
			$loop = "/dev/loop".$id;
			$this->{loop} = $loop;
			last;
		}
	}
	if (! $loopfound) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find free loop device");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# check image type
	#------------------------------------------
	if ($gotsys) {
		#==========================================
		# bind $system to loop device
		#------------------------------------------
		$kiwi -> info ("Binding virtual disk to loop device");
		$status = qxx ( "/sbin/losetup $loop $system 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed binding virtual disk: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# setup device mapper
		#------------------------------------------
		$kiwi -> info ("Setup device mapper for virtual partition access");
		$status = qxx ( "/sbin/kpartx -a $loop 2>&1" );
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
		my $dmap = $loop; $dmap =~ s/dev\///;
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
		$status = qxx ("/sbin/kpartx  -d $loop 2>&1");
		$status = qxx ("/sbin/losetup -d $loop 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed to umount system partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
	}
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $nameusb = basename ($system);
	if ($gotsys) {
		if ($nameusb !~ /(.*)-(\d+\.\d+\.\d+)\.raw$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		$ibasename = $1;
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		$this -> cleanTmp ();
		return undef;
	}
	$this->{initrd} = $initrd;
	#==========================================
	# Create Virtual Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		$this->{initrd} = $oldird;
		return undef;
	}
	#==========================================
	# Import grub stages
	#------------------------------------------
	my $stages = "'usr/lib/grub/*'";
	my $unzip  = "$main::Gzip -cd $initrd 2>&1";
	$kiwi -> info ("Importing grub stages for VM boot");
	$status = qxx ("$unzip | (cd $tmpdir && cpio -di $stages 2>&1)");
	$result = $? >> 8;
	if ($result == 0) {
		$status = qxx ( "mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> skipped (); chomp $status;
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qxx ( "cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			$this->{initrd} = $oldird;
			$this -> cleanTmp ();
			return undef;
		}
	}
	$kiwi -> done ();
	#==========================================
	# Creating menu.lst for the grub
	#------------------------------------------
	$kiwi -> info ("Creating grub menu and device map");
	if (! open (FD,">$tmpdir/boot/grub/menu.lst")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create menu.lst: $!");
		$kiwi -> failed ();
		$this->{initrd} = $oldird;
		$this -> cleanTmp ();
		return undef;
	}
	my $title = "KIWI USB-Stick Installation";
	if (! $gotsys) {
		$title = "KIWI USB Boot: $nameusb";
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,0)/image/loader/message\n";
	print FD "\n";
	print FD "title $title\n";
	if (! $isxen) {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/linux.vmx vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " initrd /boot/initrd.vmx\n";
	} else {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/xen.gz.vmx\n";
		print FD " module /boot/linux.vmx vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " module /boot/initrd.vmx"
	}
	print FD "title Failsafe -- $title\n";
	if (! $isxen) {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/linux.vmx vga=0x314 splash=silent showopts";
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes\n";
		} else {
			print FD "\n";
		}
		print FD " initrd /boot/initrd.vmx\n";
	} else {
		print FD " root (hd0,0)\n";
		print FD " kernel /boot/xen.gz.vmx\n";
		print FD " module /boot/linux.vmx vga=0x314 splash=silent showopts";
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes\n";
		} else {
			print FD "\n";
		}
		print FD " module /boot/initrd.vmx"
	}
	close FD;
	$this->{initrd} = $oldird;
	$kiwi -> done();
	#==========================================
	# create virtual disk
	#------------------------------------------
	$kiwi -> info ("Creating virtual disk...");
	if (! $gotsys) {
		$vmsize = -s $initrd;
		$vmsize+= $vmsize * 1.3;
		$vmsize/= 1024;
		$vmsize = sprintf ("%.0f", $vmsize);
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
	$kiwi -> done();
	$kiwi -> info ("Binding virtual disk to loop device");
	$status = qxx ( "/sbin/losetup $loop $diskname 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed binding virtual disk: $status");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# create virtual disk partitions
	#------------------------------------------
	$kiwi -> info ("Create partition table for virtual disk");
	if (! open (FD,"|/sbin/fdisk $loop &>/dev/null")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual partition");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	my @commands = ();
	if ($gotsys) {
		@commands = (
			"n","p","1",".","+30M",
			"n","p","2",".",".","w","q"
		);
	} else {
		@commands = (
			"n","p","1",".",".","w","q"
		);
	}
	foreach my $cmd (@commands) {
		if ($cmd eq ".") {
			print FD "\n";
		} else {
			print FD "$cmd\n";
		}
	}
	close FD;
	$kiwi -> done();
	#==========================================
	# setup device mapper
	#------------------------------------------
	$kiwi -> info ("Setup device mapper for virtual partition access");
	$status = qxx ( "/sbin/kpartx -a $loop 2>&1" );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed mapping virtual partition: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	my $dmap = $loop; $dmap =~ s/dev\///;
	my $boot = "/dev/mapper".$dmap."p1";
	my $data;
	if ($gotsys) {
		$data = "/dev/mapper".$dmap."p2";
	}
	$kiwi -> done();
	#==========================================
	# Create filesystem on virtual partitions
	#------------------------------------------
	foreach my $root ($boot,$data) {
		next if ! defined $root;
		$kiwi -> info ("Creating filesystem on $root partition");
		$status = qxx ( "/sbin/mke2fs -j -q $root 2>&1" );
		$result = $? >> 8;
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
	$kiwi -> info ("Installing boot data to virtual disk");
	$status = qxx ("mount $boot $loopdir 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
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
	my $message = "'image/loader/message'";
	$unzip  = "$main::Gzip -cd $initrd 2>&1";
	$status = qxx ("$unzip | ( cd $loopdir && cpio -di $message 2>&1)");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find message file: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
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
			return undef;
		}
		$status = qxx ("cp $system $loopdir/$ibasename 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		qxx ( "umount $loopdir 2>&1" );
		$kiwi -> done();
	}
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	qxx ( "/sbin/kpartx -d $loop" );
	#==========================================
	# Install grub on virtual disk
	#------------------------------------------
	$kiwi -> info ("Installing grub on virtual disk");
	if (! open (FD,"|/usr/sbin/grub --batch &> $tmpdir/grub.log")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't call grub: $!");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		$this -> cleanTmp();
		return undef;
	}
	print FD "device (hd0) $diskname\n";
	print FD "root (hd0,0)\n";
	print FD "setup (hd0)\n";
	print FD "quit\n";
	close FD;
	my $glog;
	if (open (FD,"$tmpdir/grub.log")) {
		my @glog = <FD>; close FD;
		$glog = join ("\n",@glog);
		$kiwi -> loginfo ("GRUB: $glog");
	}
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# check grub installation
	#------------------------------------------
	qxx ("file $diskname | grep -q 'boot sector'");
	$result = $? >> 8;
	if ($result != 0) { 
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on virtual disk: $glog");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	qxx ( "/sbin/losetup -d $loop" );
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
	my $diskname  = $system.".raw";
	my $loop      = "/dev/loop0";
	my $imgtype   = "vmx";
	my $loopfound = 0;
	my $haveTree  = 0;
	my $haveSplit = 0;
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
	# build disk name and label from xml data
	#------------------------------------------
	$destdir  = dirname ($initrd);
	$label    = $xml -> getImageName();
	$version  = $xml -> getImageVersion();
	$diskname = $label;
	$diskname = $destdir."/".$diskname.".".$arch."-".$version.".raw";
	$splitfile= $destdir."/".$label."-read-write.".$arch."-".$version;
	#==========================================
	# check image split portion
	#------------------------------------------
	if ($imgtype eq "split") {
		if (-f $splitfile) {
			my $splitsize = -s $splitfile; $splitsize /= 1048576;
			$vmsize = $this->{vmmbyte} + $splitsize * 1.3;
			$vmsize = sprintf ("%.0f", $vmsize);
			$vmsize = $vmsize."M";
			$haveSplit = 1;
		}
	}
	#==========================================
	# obtain filesystem type from xml data
	#------------------------------------------
	my %type = %{$xml->getImageTypeAndAttributes()};
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
	# search free loop device
	#------------------------------------------
	$kiwi -> info ("Using virtual disk size of: $vmsize");
	$kiwi -> done ();
	$kiwi -> info ("Searching for free loop device...");
	for (my $id=0;$id<=7;$id++) {
		$status = qxx ( "/sbin/losetup /dev/loop$id 2>&1" );
		$result = $? >> 8;
		if ($result == 1) {
			$loopfound = 1;
			$loop = "/dev/loop".$id;
			$this->{loop} = $loop;
			last;
		}
	}
	if (! $loopfound) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find free loop device");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Create Virtual Disk boot structure
	#------------------------------------------
	if (! $this -> createBootStructure("vmx")) {
		return undef;
	}
	#==========================================
	# Import grub stages
	#------------------------------------------
	my $stages = "'usr/lib/grub/*'";
	my $message= "'image/loader/message'";
	my $unzip  = "$main::Gzip -cd $initrd 2>&1";
	$kiwi -> info ("Importing grub stages for VM boot");
	if ($zipped) {
		$status = qxx ("$unzip | (cd $tmpdir && cpio -di $message 2>&1)");
	} else {
		$status = qxx ("cat $initrd | (cd $tmpdir && cpio -di $message 2>&1)");
	}
	$result = $? >> 8;
	if ($result == 0) {
		$status = qxx ("mv $tmpdir/$message $tmpdir/boot/message 2>&1");
		$result = $? >> 8;
		if ($result == 0) {
			if ($zipped) {
				$status= qxx ("$unzip | (cd $tmpdir && cpio -di $stages 2>&1)");
			} else {
				$status= qxx (
					"cat $initrd|(cd $tmpdir && cpio -di $stages 2>&1)"
				);
			}
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx (
					"mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1"
				);
				$result = $? >> 8;
			}
		}
	}
	if ($result != 0) {
		$kiwi -> skipped (); chomp $status;
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qxx ( "cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
	}
	$kiwi -> done ();
	#==========================================
	# Creating menu.lst for the grub
	#------------------------------------------
	$kiwi -> info ("Creating grub menu and device map");
	if (! open (FD,">$tmpdir/boot/grub/menu.lst")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create menu.lst: $!");
		$kiwi -> failed ();
		$this -> cleanTmp ();
		return undef;
	}
	my $bootpart = "0";
	if (($syszip) || ($haveSplit)) {
		$bootpart = "1";
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,$bootpart)/boot/message\n";
	print FD "\n";
	print FD "title $label [ VMX ]\n";
	if (! $isxen) {
		print FD " root (hd0,$bootpart)\n";
		print FD " kernel /boot/linux.vmx vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " initrd /boot/initrd.vmx\n";
	} else {
		print FD " root (hd0,$bootpart)\n";
		print FD " kernel /boot/xen.gz.vmx\n";
		print FD " module /boot/linux.vmx vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts\n";
		} else {
			print FD " showopts\n";
		}
		print FD " module /boot/initrd.vmx"
	}
	print FD "title Failsafe -- $label [ VMX ]\n";
	if (! $isxen) {
		print FD " root (hd0,$bootpart)\n";
		print FD " kernel /boot/linux.vmx vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts";
		} else {
			print FD " showopts";
		}
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off\n";
		print FD " initrd /boot/initrd.vmx\n";
	} else {
		print FD " root (hd0,$bootpart)\n";
		print FD " kernel /boot/xen.gz.vmx\n";
		print FD " module /boot/linux.vmx vga=0x314 splash=silent";
		if ($imgtype eq "split") {
			print FD " COMBINED_IMAGE=yes showopts";
		} else {
			print FD " showopts";
		}
		print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
		print FD " noapic maxcpus=0 edd=off\n";
		print FD " module /boot/initrd.vmx"
	}
	close FD;
	$kiwi -> done();
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
		$status = qxx ( "/sbin/losetup $loop $diskname 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed binding virtual disk: $status");
			$kiwi -> failed ();
			$this -> cleanTmp ();
			return undef;
		}
		#==========================================
		# create virtual disk partition
		#------------------------------------------
		if (! open (FD,"|/sbin/fdisk $loop &>/dev/null")) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating virtual partition");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		my @commands;
		if (($syszip) || ($haveSplit)) {
			# xda1 ro / xda2 rw
			@commands = (
				"n","p","1",".","+".$syszip."M",
				"n","p","2",".",".","w","q"
			);
		} else {
			# xda1 rw
			@commands = ( "n","p","1",".",".","w","q");
		}
		foreach my $cmd (@commands) {
			if ($cmd eq ".") {
				print FD "\n";
			} else {
				print FD "$cmd\n";
			}
		}
		close FD;
		#==========================================
		# setup device mapper
		#------------------------------------------
		$status = qxx ( "/sbin/kpartx -a $loop 2>&1" );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed mapping virtual partition: $status");
			$kiwi -> failed ();
			$this -> cleanLoop ();
			return undef;
		}
		$dmap = $loop; $dmap =~ s/dev\///;
		$root = "/dev/mapper".$dmap."p1";
		#==========================================
		# check partition sizes
		#------------------------------------------
		if ($syszip > 0) {
			my $sizeOK = 1;
			my $systemPSize = qxx ("/sbin/sfdisk -s /dev/mapper".$dmap."p1");
			my $systemISize = -s $system; $systemISize /= 1024;
			chomp $systemPSize;
			#print "_______A $systemPSize : $systemISize\n";
			if ($systemPSize < $systemISize) {
				$syszip += 10;
				$sizeOK = 0;
			}
			my $initrdPSize = qxx ("/sbin/sfdisk -s /dev/mapper".$dmap."p2"); 
			my $initrdISize = -s $sysname; $initrdISize /= 1024;
			chomp $initrdPSize;
			#print "_______B $initrdPSize : $initrdISize\n";
			if ($initrdPSize < $initrdISize) {
				$sysird += 1;
				$sizeOK = 0;
			}
			if (! $sizeOK) {
				#==========================================
				# bad partition alignment try again
				#------------------------------------------
				sleep (1); qxx ("/sbin/kpartx  -d $loop");
				sleep (1); qxx ("/sbin/losetup -d $loop"); 
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
			$root = "/dev/mapper".$dmap."p2";
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
		SWITCH: for ($FSTypeRO) {
			/^ext2/     && do {
				$kiwi -> info ("Creating ext2 root filesystem");
				my $fsopts = "-q -F";
				$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^ext3/     && do {
				$kiwi -> info ("Creating ext3 root filesystem");
				my $fsopts = "-O dir_index -b 4096 -j -J size=4 -q -F";
				$status = qxx ("/sbin/mke2fs $fsopts $root 2>&1");
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Creating reiserfs root filesystem");
				$status = qxx (
					"/sbin/mkreiserfs -q -f -s 513 -b 4096 $root 2>&1"
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
	if (($syszip) || ($haveSplit)) {
		$root = "/dev/mapper".$dmap."p2";
		if (! $haveSplit) {
			$kiwi -> info ("Creating ext2 read-write filesystem");
			$status = qxx ("/sbin/mke2fs -q -F $root 2>&1");
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
	#==========================================
	# check for message file in initrd
	#------------------------------------------
	$message = "'image/loader/message'";
	$unzip   = "$main::Gzip -cd $initrd 2>&1";
	if ($zipped) {
		$status = qxx ("$unzip | (cd $loopdir && cpio -di $message 2>&1)");
	} else {
		$status = qxx (
			"cat $initrd | (cd $loopdir && cpio -di $message 2>&1)"
		);
	}
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find message file: $status");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	qxx ( "umount $loopdir 2>&1" );
	$kiwi -> done();
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	qxx ( "/sbin/kpartx -d $loop" );

	#==========================================
	# Install grub on virtual disk
	#------------------------------------------
	$kiwi -> info ("Installing grub on virtual disk");
	if (! open (FD,"|/usr/sbin/grub --batch &> $tmpdir/grub.log")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't call grub: $!");
		$kiwi -> failed ();
		$this -> cleanLoop ();
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
	}
	#==========================================
	# cleanup temp directory
	#------------------------------------------
	qxx ("rm -rf $tmpdir");
	#==========================================
	# check grub installation
	#------------------------------------------
	qxx ("file $diskname | grep -q 'boot sector'");
	$result = $? >> 8;
	if ($result != 0) { 
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on virtual disk: $glog");
		$kiwi -> failed ();
		$this -> cleanLoop ();
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# Create image described by given format
	#------------------------------------------
	if (defined $format) {
		if ($format eq "iso") {
			$this -> {system} = $diskname;
			$kiwi -> info ("Creating install ISO image\n");
			$this -> buildMD5Sum ($diskname);
			qxx ( "/sbin/losetup -d $loop" );
			if (! $this -> setupInstallCD()) {
				return undef;
			}
		} elsif ($format eq "usb") {
			$this -> {system} = $diskname;
			$kiwi -> info ("Creating install USB Stick image\n");
			$this -> buildMD5Sum ($diskname);
			qxx ( "/sbin/losetup -d $loop" );
			if (! $this -> setupInstallStick()) {
				return undef;
			}
		} else {
			$kiwi -> info ("Creating $format image");
			my $fname = $diskname;
			$fname  =~ s/\.raw$/\.$format/;
			my %vmwc;
			if ($format eq "vmdk") {
				%vmwc   = $xml  -> getPackageAttributes ("vmware");
			}
			if (($vmwc{disk}) && ($vmwc{disk} =~ /^scsi/)) {
				$status = qxx (
					"qemu-img convert -f raw $loop -O $format -s $fname 2>&1"
				);
			} else {
				$status = qxx (
					"qemu-img convert -f raw $loop -O $format $fname 2>&1"
				);
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
	qxx ( "/sbin/losetup -d $loop 2>&1" );
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
		$imd5 =~ s/\.raw/\.md5/;
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
		print FD "IMAGE=nope;$ibasename;$iversion\n";
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
# setupSplashForGrub
#------------------------------------------
sub setupSplashForGrub {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $initrd = $this->{initrd};
	my $spldir = $initrd."_".$$.".splash";
	my $newspl = "$spldir/splash";
	my $irddir = "$spldir/initrd";
	my $zipped = 0;
	my $newird;
	my $status;
	my $result;
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
	mkdir $newspl;
	mkdir $irddir;
	#==========================================
	# unpack initrd files
	#------------------------------------------
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
	# move splash files
	#------------------------------------------
	$status = qxx ("mv $irddir/image/loader/*.spl $newspl 2>&1");
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> warning ("No splash files found in initrd");
		$kiwi -> skipped ();
		qxx ("rm -rf $spldir");
		return $initrd;
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
		qxx ("rm -f $splash.bob*");
		qxx ("rm -f $splash");
		if ($result != 0) {
			my $splfile = basename ($splash);
			$kiwi -> skipped ();
			$kiwi -> warning ("No bootsplash file found in $splfile cpio");
			$kiwi -> skipped ();
			qxx ("rm -rf $spldir");
			return $initrd;
		}
	}
	qxx ("
		(cd $newspl && find|cpio --quiet -oH newc|$main::Gzip)>$spldir/all.spl"
	);
	qxx ("
		(cd $irddir && find|cpio --quiet -oH newc|$main::Gzip)>$newird"
	);
	#==========================================
	# create splash initrd
	#------------------------------------------
	qxx ("cat $spldir/all.spl >> $newird");
	qxx ("rm -rf $spldir");
	$kiwi -> done();
	return $newird;
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
	if (defined $loop) {
		qxx ( "umount $loopdir 2>&1" );
		qxx ( "/sbin/kpartx  -d $loop 2>&1" );
		qxx ( "/sbin/losetup -d $loop 2>&1" );
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
	$kiwi -> info ("Relocating boot catalog from sector ");
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
	if ($boot_catalog == $path_table - 1) {
		$kiwi -> skipped ();
		$kiwi -> info ("Boot catalog already relocated");
		$kiwi -> done ();
		return $this;
	}
	my $vol_descr2 = read_sector $path_table - 2;
	my $vol_id2 = substr($vol_descr2, 0, 7);
	if ($vol_id2 ne "\xffCD001\x01") {
		$kiwi -> failed ();
		$kiwi -> error  ("Unexpected layout");
		$kiwi -> failed ();
		return undef;
	}
	my $version_descr = read_sector $path_table - 1;
	if (
		($version_descr ne ("\x00" x 0x800)) &&
		(substr($version_descr, 0, 4) ne "MKI ")
	) {
		$kiwi -> failed ();
		$kiwi -> error  ("Unexpected layout");
		$kiwi -> failed ();
		return undef;
	}
	my $boot_catalog_data = read_sector $boot_catalog;
	#==========================================
	# now reloacte to $path_table - 1
	#------------------------------------------
	substr($eltorito_descr, 0x47, 4) = pack "V", $path_table - 1;
	write_sector $path_table - 1, $boot_catalog_data;
	write_sector 0x11, $eltorito_descr;
	close ISO;
	my $new_catalog = $path_table - 1;
	$kiwi -> note ("$boot_catalog to $new_catalog");
	$kiwi -> done();
	return $this;
}

1; 
