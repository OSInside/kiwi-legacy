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
use strict;
use KIWILog;
use FileHandle;
use File::Basename;
use File::Spec;
use Math::BigFloat;

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
	my $syszip = 0;
	my $sysird = 0;
	my $kernel;
	my $knlink;
	my $tmpdir;
	my $result;
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	if (! -f $initrd) {
		$kiwi -> error  ("Couldn't find initrd file: $initrd");
		$kiwi -> failed ();
		return undef;
	}
	if (defined $system) {
		if (-f $system) {
			my $status = qx ( file $system | grep -qi squashfs 2>&1 );
			my $result = $? >> 8;
			if ($result == 0) {
				$syszip = -s $system;
				$syszip+= 20 * 1024 * 1024;
			} else {
				$syszip = 0;
			}
		} elsif (! -d $system) {
			$kiwi -> error  ("Couldn't find image file/directory: $system");
			$kiwi -> failed ();
			return undef;
		}
	}
	$kernel = $initrd;
	$kernel =~ s/gz$/kernel/;
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
	$tmpdir = qx ( mktemp -q -d /tmp/kiwiboot.XXXXXX ); chomp $tmpdir;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	if ((! defined $vmsize) && (defined $system)) {
		my $kernelSize = -s $kernel; # the kernel
		my $initrdSize = -s $initrd; # the boot image
		my $systemSize; # the system image
		if (-d $system) {
			$systemSize = qx (du -bs $system | cut -f1 2>&1);
			chomp $systemSize;
		} else {
			$systemSize = -s $system;
		}
		if ($syszip) {
			$vmsize = $kernelSize + $initrdSize + $syszip;
		} else {
			$vmsize = $kernelSize + $initrdSize + $systemSize;
			$vmsize+= $vmsize * 0.3 # and 30% free space
		}
		$vmsize = $vmsize / 1024 / 1024;
		$vmsize = int $vmsize;
		$vmsize = $vmsize."M";
	}
	#$kiwi -> done ();
	if ($syszip) {
		$syszip = $syszip / 1024 / 1024;
		$syszip = int $syszip;
	}
	my $arch = qx (uname -m); chomp $arch;
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi}   = $kiwi;
	$this->{initrd} = $initrd;
	$this->{system} = $system;
	$this->{kernel} = $kernel;
	$this->{tmpdir} = $tmpdir;
	$this->{vmsize} = $vmsize;
	$this->{syszip} = $syszip;
	$this->{device} = $device;
	$this->{format} = $format;
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
	my $lname  = "linux";
	my $iname  = "initrd";
	my $status;
	my $result;
	if (defined $loc) {
		$lname  = $lname.".".$loc;
		$iname  = $iname.".".$loc;
	}
	if ($initrd !~ /splash\.gz$/) {
		$initrd = $this -> setupSplashForGrub();
	}
	$kiwi -> info ("Creating initial boot structure");
	$status = qx ( mkdir -p $tmpdir/boot/grub 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating initial directories: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx ( cp $initrd $tmpdir/boot/$iname 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing initrd: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$status = qx ( cp $kernel $tmpdir/boot/$lname 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing kernel: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
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
					if (! open (FD,$isremovable)) {
						next;
					}
					$isremovable = <FD>; close FD;
					if ($isremovable == 1) {
						my $status = qx (/sbin/sfdisk -s $description 2>&1);
						my $result = $? >> 8;
						if ($result == 0) {
							$devices{$description} = $serial;
						}
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
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $tmpdir = $this->{tmpdir};
	my $initrd = $this->{initrd};
	my $system = $this->{system};
	my $syszip = $this->{syszip};
	my $device = $this->{device};
	my $sysird;
	my $status;
	my $result;
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
	my $unzip  = "gzip -cd $initrd 2>&1";
	$kiwi -> info ("Importing grub stages for stick boot");
	$status = qx ($unzip | (cd $tmpdir && cpio -di $stages 2>&1));
	$result = $? >> 8;
	if ($result == 0) {
		$status = qx ( mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qx ( cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
	}
	$kiwi -> done ();
	#==========================================
	# Find USB stick devices
	#------------------------------------------
	my %storage = getRemovableUSBStorageDevices();
	if (! %storage) {
		$kiwi -> error  ("Couldn't find any removable USB storage devices");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
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
			qx (rm -rf $tmpdir);
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
		qx (rm -rf $tmpdir);
		return undef;
	}
	my $label = $this -> getImageName();
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,0)/image/loader/message\n";
	print FD "\n";
	print FD "title $label [ USB ]\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux vga=0x314 splash=silent showopts\n";
	print FD " initrd /boot/initrd\n";
	print FD "title Failsafe -- $label [ USB ]\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux vga=0x314 splash=silent showopts";
	print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
	print FD " noapic maxcpus=0 edd=off\n";
	print FD " initrd /boot/initrd\n";
	close FD;
	$kiwi -> done();
	#==========================================
	# Create ext2 image
	#------------------------------------------
	$kiwi -> info ("Creating stick image");
	my $name = $initrd; $name =~ s/gz$/stickboot/;
	my $size = qx (du -ms $tmpdir | cut -f1 2>&1);
	my $ddev = "/dev/zero";
	chomp ($size); $size += 1; # add 1M free space for filesystem
	$sysird = $size;
	$status = qx (dd if=$ddev of=$name bs=1M seek=$sysird count=1 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create image file: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$sysird += 1; # add another 1M free space because of sparse seek
	$status = qx (/sbin/mkfs.ext2 -b 4096 -F $name 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create filesystem: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$status = qx (mount -o loop $name /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$status = qx (mv $tmpdir/boot /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install image: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	#==========================================
	# check for message file in initrd
	#------------------------------------------
	my $message = "'image/loader/message'";
	my $unzip   = "gzip -cd $initrd 2>&1";
	$status = qx ($unzip | (cd /mnt/ && cpio -d -i $message 2>&1));
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find message file: $status");
		$kiwi -> failed ();
		qx (umount /mnt/ 2>&1);
		qx (rm -rf $tmpdir);
		return undef;
	}
	qx (umount /mnt/ 2>&1);
	$kiwi -> done();
	#==========================================
	# Create new partition table on stick
	#------------------------------------------
	$kiwi -> info ("Creating partition table on: $stick");
	my $pinfo = "$tmpdir/sfdisk.input";
	if (! open (FD,">$pinfo")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create temporary partition data: $!");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	#==========================================
	# Prepare sfdisk input file
	#------------------------------------------
	if (defined $system) {
		if ($syszip > 0) {
			print FD ",$sysird,L,*\n"; # xda1  boot
			print FD ",$syszip,L\n";   # xda2  ro
			print FD ",,L\n";          # xda3  rw
		} else {
			print FD ",$sysird,L,*\n"; # xda1  boot
			print FD ",,L\n";          # xda2  rw
		}
	} else {
		print FD ",,L,*\n";
	}
	close FD;
	$status = qx ( dd if=/dev/zero of=$stick bs=512 count=1 2>&1 );	
	$result = $? >> 8;
	sleep 1;
	$status = qx ( /sbin/sfdisk -uM --force $stick < $pinfo 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create partition table: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Clean tmp
	#------------------------------------------
	unlink $pinfo;
	qx ( rm -rf $tmpdir );

	#==========================================
	# Dump initrd image on stick
	#------------------------------------------
	$kiwi -> info ("Dumping initrd image to stick");
	$status = qx ( umount $stick"1" 2>&1 );
	$status = qx (dd if=$name of=$stick"1" bs=32k 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't dump image to stick: $status");
		$kiwi -> failed ();
		return undef;
	}
	unlink $name;
	$kiwi -> done();
	#==========================================
	# Dump system image on stick
	#------------------------------------------
	if (defined $system) {
		$kiwi -> info ("Dumping system image to stick");
		$status = qx ( umount $stick"1" 2>&1 );
		$status = qx ( umount $stick"2" 2>&1 );
		$status = qx (dd if=$system of=$stick"2" bs=32k 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump image to stick: $status");
			$kiwi -> failed ();
			return undef;
		}
		$kiwi -> done();
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
			$status = qx (mount $stick"2" /mnt/ 2>&1);
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't mount stick image: $status");
				$kiwi -> failed ();
				return undef;
			}
			if (-d "/mnt/boot") {
				$status = qx (rm -r /mnt/boot 2>&1);
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
			qx (umount /mnt/ 2>&1);
		}
	}
	#==========================================
	# Install grub on USB stick
	#------------------------------------------
	$kiwi -> info ("Installing grub on USB stick");
	if (! open (FD,"|/usr/sbin/grub --batch >/dev/null 2>&1")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't call grub: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD "device (hd0) $stick\n";
	print FD "root (hd0,0)\n";
	print FD "setup (hd0)\n";
	print FD "quit\n";
	close FD;
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on USB stick: $!");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupInstallCD
#------------------------------------------
sub setupInstallCD {
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $tmpdir  = $this->{tmpdir};
	my $initrd  = $this->{initrd};
	my $system  = $this->{system};
	my $oldird  = $this->{initrd};
	my $gotsys  = 1;
	my $status;
	my $result;
	my $ibasename;
	#==========================================
	# check if system image is given
	#------------------------------------------
	if (! defined $system) {
		$system = $initrd;
		$gotsys = 0;
	}
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $namecd = basename ($system);
	if ($gotsys) {
		if ($namecd !~ /(.*)-(\d+\.\d+\.\d+)\.raw$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$ibasename = $1;
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		qx (rm -rf $tmpdir);
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
	my $unzip  = "gzip -cd $initrd 2>&1";
	$status = qx ($unzip | (cd $tmpdir && cpio -d -i $message 2>&1));
	$result = $? >> 8;
	if ($result == 0) {
		$status = qx ($unzip | (cd $tmpdir && cpio -d -i $stage1 2>&1));
		$result = $? >> 8;
		if ($result == 0) {
			$status = qx ($unzip | (cd $tmpdir && cpio -d -i $stage2 2>&1));
		}
	}
	if ($result == 0) {
		$status = qx (mv $tmpdir/$message $tmpdir/boot/message 2>&1);
		$result = $? >> 8;
		if ($result == 0) {
			$status = qx (mv $tmpdir/$stage1 $tmpdir/boot/grub/stage1 2>&1);
			$result = $? >> 8;
			if ($result == 0) {
				$status = qx (mv $tmpdir/$stage2 $tmpdir/boot/grub/stage2 2>&1);
				$result = $? >> 8;
			}
		}
	}
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qx ( cp /$stage1 $tmpdir/boot/grub/stage1 2>&1 );
		$status = qx ( cp /$stage2 $tmpdir/boot/grub/stage2 2>&1 );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			$this->{initrd} = $oldird;
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
	}
	qx (rm -rf $tmpdir/usr 2>&1);
	qx (rm -rf $tmpdir/image 2>&1);
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
		qx (rm -rf $tmpdir);
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
	print FD " kernel (cd)/boot/linux vga=0x314 splash=silent";
	print FD " ramdisk_size=512000 ramdisk_blocksize=4096 showopts\n";
	print FD " initrd (cd)/boot/initrd\n";
	print FD "title Failsafe -- $title\n";
	print FD " kernel (cd)/boot/linux vga=0x314 splash=silent";
	print FD " ramdisk_size=512000 ramdisk_blocksize=4096 showopts";
	print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
	print FD " noapic maxcpus=0 edd=off\n";
	print FD " initrd (cd)/boot/initrd\n";
	close FD;
	$kiwi -> done();

	#==========================================
	# Copy system image if given
	#------------------------------------------
	if ($gotsys) {
		$kiwi -> info ("Importing system image: $system");
		$status = qx (cp $system $tmpdir/$ibasename 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
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
		my $workingDir = qx ( pwd ); chomp $workingDir;
		$name = $workingDir."/".$name;
	}
	$status = qx (cd $tmpdir && mkisofs $base $opts -o $name . 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating ISO image: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# Clean tmp
	#------------------------------------------
	qx (rm -rf $tmpdir);
	$kiwi -> info ("Created $name to be burned on CD");
	$kiwi -> done ();
	return $this;
}

#==========================================
# setupInstallStick
#------------------------------------------
sub setupInstallStick {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $tmpdir    = $this->{tmpdir};
	my $initrd    = $this->{initrd};
	my $system    = $this->{system};
	my $oldird    = $this->{initrd};
	my $vmsize    = $this->{vmsize};
	my $diskname  = $system.".install.raw";
	my $loop      = "/dev/loop0";
	my $loopfound = 0;
	my $gotsys    = 1;
	my $status;
	my $result;
	my $ibasename;
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
		$status = qx ( /sbin/losetup /dev/loop$id 2>&1 );
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
		qx (rm -rf $tmpdir);
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Setup image basename
	#------------------------------------------
	my $nameusb = basename ($system);
	if ($gotsys) {
		if ($nameusb !~ /(.*)-(\d+\.\d+\.\d+)\.raw$/) {
			$kiwi -> error  ("Couldn't extract version information");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$ibasename = $1;
	}
	#==========================================
	# Setup initrd for install purpose
	#------------------------------------------
	$initrd = $this -> setupInstallFlags();
	if (! defined $initrd) {
		qx (rm -rf $tmpdir);
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
	my $unzip  = "gzip -cd $initrd 2>&1";
	$kiwi -> info ("Importing grub stages for VM boot");
	$status = qx ($unzip | (cd $tmpdir && cpio -di $stages 2>&1));
	$result = $? >> 8;
	if ($result == 0) {
		$status = qx ( mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
		$result = $? >> 8;
	}
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qx ( cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			$this->{initrd} = $oldird;
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
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
		qx (rm -rf $tmpdir);
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
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux.vmx vga=0x314 splash=silent showopts\n";
	print FD " initrd /boot/initrd.vmx\n";
	print FD "title Failsafe -- $title\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux.vmx vga=0x314 splash=silent showopts";
	print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
	print FD " noapic maxcpus=0 edd=off\n";
	print FD " initrd /boot/initrd.vmx\n";
	close FD;
	$this->{initrd} = $oldird;
	$kiwi -> done();
	#==========================================
	# create virtual disk
	#------------------------------------------
	$kiwi -> info ("Creating virtual disk...");
	$status = qx (qemu-img create $diskname $vmsize 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual disk: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$kiwi -> done();
	$kiwi -> info ("Binding virtual disk to loop device");
	$status = qx ( /sbin/losetup $loop $diskname 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed binding virtual disk: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
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
		qx ( losetup -d $loop );
		return undef;
	}
	my @commands = (
		"n","p","1",".","+30M",
		"n","p","2",".",".","w","q"
	);
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
	$status = qx ( /sbin/kpartx -a $loop 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed mapping virtual partition: $status");
		$kiwi -> failed ();
		qx ( /sbin/losetup -d $loop );
		qx (rm -rf $tmpdir);
		return undef;
	}
	my $dmap = $loop; $dmap =~ s/dev\///;
	my $boot = "/dev/mapper".$dmap."p1";
	my $data = "/dev/mapper".$dmap."p2";
	$kiwi -> done();
	#==========================================
	# Create filesystem on virtual partitions
	#------------------------------------------
	foreach my $root ($boot,$data) {
		$kiwi -> info ("Creating filesystem on $root partition");
		$status = qx ( /sbin/mke2fs -j -q $root 2>&1 );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed creating filesystem: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
	}
	#==========================================
	# Copy boot data on first partition
	#------------------------------------------
	$kiwi -> info ("Installing boot data to virtual disk");
	$status = qx (mount $boot /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount boot partition: $status");
		$kiwi -> failed ();
		qx ( /sbin/kpartx  -d $loop );
		qx ( /sbin/losetup -d $loop );
		qx (rm -rf $tmpdir);
		return undef;
	}
	$status = qx (cp -a $tmpdir/boot /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install boot data: $status");
		$kiwi -> failed ();
		qx ( umount /mnt/ 2>&1 );
		qx ( /sbin/kpartx  -d $loop );
		qx ( /sbin/losetup -d $loop );
		qx (rm -rf $tmpdir);
		return undef;
	}
	my $message = "'image/loader/message'";
	my $unzip   = "gzip -cd $initrd 2>&1";
	$status = qx ($unzip | ( cd /mnt/ && cpio -di $message 2>&1));
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find message file: $status");
		$kiwi -> failed ();
		qx ( umount /mnt/ 2>&1 );
		qx ( /sbin/kpartx  -d $loop );
		qx ( /sbin/losetup -d $loop );
		qx (rm -rf $tmpdir);
		return undef;
	}
	qx ( umount /mnt/ 2>&1 );
	$kiwi -> done();
	#==========================================
	# Copy system image if defined
	#------------------------------------------
	if ($gotsys) {
		$kiwi -> info ("Installing image data to virtual disk");
		$status = qx (mount $data /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount data partition: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		$status = qx (cp $system /mnt/$ibasename 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing system image: $status");
			$kiwi -> failed ();
			qx ( umount /mnt/ 2>&1 );
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		qx ( umount /mnt/ 2>&1 );
		$kiwi -> done();
	}
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	qx ( /sbin/kpartx  -d $loop );
	qx (rm -rf $tmpdir);
	#==========================================
	# Install grub on virtual disk
	#------------------------------------------
	$kiwi -> info ("Installing grub on virtual disk");
	if (! open (FD,"|/usr/sbin/grub --batch >/dev/null 2>&1")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't call grub: $!");
		$kiwi -> failed ();
		qx ( /sbin/losetup -d $loop );
		return undef;
	}
	print FD "device (hd0) $diskname\n";
	print FD "root (hd0,0)\n";
	print FD "setup (hd0)\n";
	print FD "quit\n";
	close FD;
	$result = $? >> 8;
	if ($result != 0) { 
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on virtual disk: $!");
		$kiwi -> failed ();
		qx ( /sbin/losetup -d $loop );
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	qx ( /sbin/losetup -d $loop );
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
	my $diskname  = $system.".raw";
	my $label     = $this -> getImageName();
	my $loop      = "/dev/loop0";
	my $loopfound = 0;
	my $haveTree  = 0;
	my $version;
	my $fstype;
	my $sysname;
	my $sysird;
	my $result;
	my $status;
	my $destdir;
	#==========================================
	# check if system is tree or image file
	#------------------------------------------
	if ( -d $system ) {
		my $xml = new KIWIXML ( $kiwi,$system."/image",undef,"vmx" );
		if (! defined $xml) {
			qx (rm -rf $tmpdir);
			return undef;
		}
		#==========================================
		# build disk name and label from xml data
		#------------------------------------------
		$destdir  = dirname ($initrd);
		$label    = $xml -> getImageName();
		$version  = $xml -> getImageVersion();
		$diskname = $label;
		$diskname = $destdir."/".$diskname.".".$arch."-".$version.".raw";
		$haveTree = 1;
		#==========================================
		# obtain filesystem type from xml data
		#------------------------------------------
		my %type = %{$xml->getImageTypeAndAttributes()};
		$fstype  = $type{filesystem};
		if (! $fstype) {
			$kiwi -> error  ("Can't find filesystem type in image tree");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		if ($fstype eq "squashfs") {
			$kiwi -> error ("Can't copy data into requested RO filesystem");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
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
		$status = qx ( /sbin/losetup /dev/loop$id 2>&1 );
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
		qx (rm -rf $tmpdir);
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
	my $unzip  = "gzip -cd $initrd 2>&1";
	$kiwi -> info ("Importing grub stages for VM boot");
	$status = qx ($unzip | (cd $tmpdir && cpio -di $message 2>&1));
	$result = $? >> 8;
	if ($result == 0) {
		$status = qx (mv $tmpdir/$message $tmpdir/boot/message 2>&1);
		$result = $? >> 8;
		if ($result == 0) {
			$status = qx ($unzip | (cd $tmpdir && cpio -di $stages 2>&1));
			$result = $? >> 8;
			if ($result == 0) {
				$status = qx (mv $tmpdir/usr/lib/grub/* $tmpdir/boot/grub 2>&1);
				$result = $? >> 8;
			}
		}
	}
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> error   ("Failed importing grub stages: $status");
		$kiwi -> skipped ();
		$kiwi -> info    ("Trying to use grub stages from local machine");
		$status = qx ( cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Failed importing grub stages: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();	
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
		qx (rm -rf $tmpdir);
		return undef;
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,0)/boot/message\n";
	print FD "\n";
	print FD "title $label [ VMX ]\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux.vmx vga=0x314 splash=silent showopts\n";
	print FD " initrd /boot/initrd.vmx\n";
	print FD "title Failsafe -- $label [ VMX ]\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux.vmx vga=0x314 splash=silent showopts";
	print FD " ide=nodma apm=off acpi=off noresume selinux=0 nosmp";
	print FD " noapic maxcpus=0 edd=off\n";
	print FD " initrd /boot/initrd.vmx\n";
	close FD;
	$kiwi -> done();
	#==========================================
	# Create ext2 image if syszip is active
	#------------------------------------------
	if ($syszip > 0) {
		$kiwi -> info ("Creating VM boot image");
		$sysname= $initrd; $sysname =~ s/gz$/vmboot/;
		my $ddev = "/dev/zero";
		my $size = qx (du -ms $tmpdir | cut -f1 2>&1);
		chomp ($size); $size += 1; # add 1M free space for filesystem
		$sysird = $size;
		$status = qx (dd if=$ddev of=$sysname bs=1M seek=$sysird count=1 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create image file: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$sysird += 1; # add another 1M free space because of sparse seek
		$status = qx (/sbin/mkfs.ext2 -b 4096 -F $sysname 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$status = qx (mount -o loop $sysname /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount image: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$status = qx (mv $tmpdir/boot /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install image: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		qx (umount /mnt/ 2>&1);
		$kiwi -> done();
	}
	#==========================================
	# create virtual disk
	#------------------------------------------
	$kiwi -> info ("Creating virtual disk...");
	if (! defined $system) {
		$kiwi -> failed ();
		$kiwi -> error  ("No system image given");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}	
	$status = qx (qemu-img create $diskname $vmsize 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual disk: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	$status = qx ( /sbin/losetup $loop $diskname 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed binding virtual disk: $status");
		$kiwi -> failed ();
		qx (rm -rf $tmpdir);
		return undef;
	}
	#==========================================
	# create virtual disk partition
	#------------------------------------------
	if (! open (FD,"|/sbin/fdisk $loop &>/dev/null")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual partition");
		$kiwi -> failed ();
		qx ( losetup -d $loop );
		qx (rm -rf $tmpdir);
		return undef;
	}
	my @commands;
	if ($syszip > 0) {
		# xda1 boot / xda2 ro / xda3 rw
		@commands = (
			"n","p","1",".","+".$sysird."M",
			"n","p","2",".","+".$syszip."M",
			"n","p","3",".",".","w","q"
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
	$status = qx ( /sbin/kpartx -a $loop 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed mapping virtual partition: $status");
		$kiwi -> failed ();
		qx ( /sbin/losetup -d $loop );
		qx (rm -rf $tmpdir);
		return undef;
	}
	my $dmap = $loop; $dmap =~ s/dev\///;
	my $root = "/dev/mapper".$dmap."p1";
	if ($syszip > 0) {
		$root = "/dev/mapper".$dmap."p2";
	}
	#==========================================
	# Dump system image on virtual disk
	#------------------------------------------
	$kiwi -> done();
	if (! $haveTree) {
		$kiwi -> info ("Dumping system image on virtual disk");
		$status = qx (dd if=$system of=$root bs=32k 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump image to virtual disk: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
	} else {
		#==========================================
		# Create filesystem on system image part.
		#------------------------------------------
		SWITCH: for ($fstype) {
			/^ext2/     && do {
				$kiwi -> info ("Creating ext2 root filesystem");
				my $fsopts = "-q -F";
				$status = qx (/sbin/mke2fs $fsopts $root 2>&1);
				$result = $? >> 8;
				last SWITCH;
			};
			/^ext3/     && do {
				$kiwi -> info ("Creating ext3 root filesystem");
				my $fsopts = "-O dir_index -b 4096 -j -J size=4 -q -F";
				$status = qx (/sbin/mke2fs $fsopts $root 2>&1);
				$result = $? >> 8;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$kiwi -> info ("Creating reiserfs root filesystem");
				$status = qx (/sbin/mkreiserfs -q -f -s 513 -b 4096 $root 2>&1);
				$result = $? >> 8;
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported filesystem type: $fstype");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		};
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create $fstype filesystem: $status");
			$kiwi -> failed ();
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Mount system image partition
		#------------------------------------------
		$status = qx (mount $root /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount partition: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		#==========================================
		# Copy root tree to virtual disk
		#------------------------------------------
		$kiwi -> info ("Copying system image tree on virtual disk");
		$status = qx (cp -a $system/* /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't copy image tree to virtual disk: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		$kiwi -> done();
		#==========================================
		# Umount system image partition
		#------------------------------------------
		qx ( umount /mnt/ 2>&1 );
	}
	#==========================================
	# Dump boot image on virtual disk
	#------------------------------------------
	$kiwi -> info ("Dumping boot image to virtual disk");
	if ($syszip > 0) {
		$root = "/dev/mapper".$dmap."p1";
		$status = qx (dd if=$sysname of=$root bs=32k 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump image: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		unlink $sysname;
	} else {
		#==========================================
		# Mount system image
		#------------------------------------------
		$status = qx (mount $root /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount image: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		#==========================================
		# Copy boot data on system image
		#------------------------------------------
		$status = qx (cp -a $tmpdir/boot /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Couldn't copy boot data to system image: $status");
			$kiwi -> failed ();
			qx ( umount /mnt/ 2>&1 );
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		#==========================================
		# check for message file in initrd
		#------------------------------------------
		my $message = "'image/loader/message'";
		my $unzip   = "gzip -cd $initrd 2>&1";
		$status = qx ($unzip | (cd /mnt/ && cpio -di $message 2>&1));
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't find message file: $status");
			$kiwi -> failed ();
			qx ( umount /mnt/ 2>&1 );
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx (rm -rf $tmpdir);
			return undef;
		}
		qx ( umount /mnt/ 2>&1 );
	}
	$kiwi -> done();
	#==========================================
	# cleanup device maps and part mount
	#------------------------------------------
	qx ( /sbin/kpartx  -d $loop );
	qx (rm -rf $tmpdir);

	#==========================================
	# Install grub on virtual disk
	#------------------------------------------
	$kiwi -> info ("Installing grub on virtual disk");
	if (! open (FD,"|/usr/sbin/grub --batch >/dev/null 2>&1")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't call grub: $!");
		$kiwi -> failed ();
		qx ( /sbin/losetup -d $loop );
		return undef;
	}
	print FD "device (hd0) $diskname\n";
	print FD "root (hd0,0)\n";
	print FD "setup (hd0)\n";
	print FD "quit\n";
	close FD;
	$result = $? >> 8;
	if ($result != 0) { 
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on virtual disk: $!");
		$kiwi -> failed ();
		qx ( /sbin/losetup -d $loop );
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
			qx ( /sbin/losetup -d $loop );
			if (! $this -> setupInstallCD()) {
				return undef;
			}
		} elsif ($format eq "usb") {
			$this -> {system} = $diskname;
			$kiwi -> info ("Creating install USB Stick image\n");
			qx ( /sbin/losetup -d $loop );
			if (! $this -> setupInstallStick()) {
				return undef;
			}
		} else {
			$kiwi -> info ("Creating $format image");
			my $fname = $diskname;
			$fname  =~ s/\.raw$/\.$format/;
			$status = qx ( qemu-img convert -f raw $loop -O $format $fname );
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("Couldn't create $format image: $status");
				$kiwi -> failed ();
				qx ( /sbin/losetup -d $loop );
				return undef;
			}
			$kiwi -> done ();
		}
	}
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	qx ( /sbin/losetup -d $loop 2>&1 );
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
	my $unzip  = "gzip -cd $initrd 2>&1";
	my $status = qx ($unzip | (cd $irddir && cpio -di 2>&1));
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to extract initrd data: $!");
		$kiwi -> failed ();
		qx (rm -rf $irddir);
		return undef;
	}
	#===========================================
	# add image.md5 / config.vmxsystem to initrd
	#-------------------------------------------
	if (defined $system) {
		my $imd5 = $system;
		$imd5 =~ s/\.raw/\.md5/;
		my $status = qx (cp $imd5 $irddir/etc/image.md5 2>&1);
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Failed importing md5 file: $status");
			$kiwi -> failed ();
			qx (rm -rf $irddir);
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
			qx (rm -rf $irddir);
			return undef;
		}
		$ibasename = $1;
		$iversion  = $2;
		if (! -f $imd5) {
			$kiwi -> error  ("Couldn't find md5 file");
			$kiwi -> failed ();
			qx (rm -rf $irddir);
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
	$status = qx ((cd $irddir && find|cpio --quiet -oH newc|gzip -9) > $newird);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed to re-create initrd: $status");
		$kiwi -> failed ();
		qx (rm -rf $irddir);
		return undef;
	}
	qx (rm -rf $irddir);
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
	my $newird = $initrd; $newird =~ s/\.gz/\.splash.gz/;
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
	my $unzip  = "gzip -cd $initrd 2>&1";
	my $status = qx ($unzip | (cd $irddir && cpio -di 2>&1));
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> warning ("Failed to extract data: $!");
		$kiwi -> skipped ();
		qx (rm -rf $spldir);
		return $initrd;
	}
	#==========================================
	# move splash files
	#------------------------------------------
	$status = qx (mv $irddir/image/loader/*.spl $newspl 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> skipped ();
		$kiwi -> warning ("No splash files found in initrd");
		$kiwi -> skipped ();
		qx (rm -rf $spldir);
		return $initrd;
	}
	#==========================================
	# create new splash with all pictures
	#------------------------------------------
	while (my $splash = glob("$newspl/*.spl")) {
		mkdir "$splash.dir";
		qx (gzip -cd $splash > $splash.bob);
		my $count = $this -> extractCPIO ( $splash.".bob" );
		for (my $id=1; $id <= $count; $id++) {
			qx (cat $splash.bob.$id |(cd $splash.dir && cpio -i 2>&1));
		}
		qx (cp -a $splash.dir/etc $newspl);
		$result = 1;
		if (-e "$splash.dir/bootsplash") {
			qx (cat $splash.dir/bootsplash >> $newspl/bootsplash);
			$result = $? >> 8;
		}
		qx (rm -rf $splash.dir);
		qx (rm -f $splash.bob*);
		qx (rm -f $splash);
		if ($result != 0) {
			my $splfile = basename ($splash);
			$kiwi -> skipped ();
			$kiwi -> warning ("No bootsplash file found in $splfile cpio");
			$kiwi -> skipped ();
			qx (rm -rf $spldir);
			return $initrd;
		}
	}
	qx ((cd $newspl && find|cpio --quiet -oH newc | gzip -9) > $spldir/all.spl);
	qx ((cd $irddir && find|cpio --quiet -oH newc | gzip -9) > $newird);
	#==========================================
	# create splash initrd
	#------------------------------------------
	qx (cat $spldir/all.spl >> $newird);
	qx (rm -rf $spldir);
	$kiwi -> done();
	return $newird;
}

#==========================================
# cleanTmp
#------------------------------------------
sub cleanTmp {
	my $this = shift;
	my $tmpdir = $this->{tmpdir};
	qx (rm -rf $tmpdir);
	return $this;
}

#==========================================
# cleanLoop
#------------------------------------------
sub cleanLoop {
	my $this = shift;
	my $tmpdir = $this->{tmpdir};
	my $loop   = $this->{loop};
	if (defined $loop) {
		qx ( umount /mnt/ 2>&1 );
		qx ( /sbin/kpartx  -d $loop 2>&1 );
		qx ( /sbin/losetup -d $loop 2>&1 );
		undef $this->{loop};
	}
	qx ( rm -rf $tmpdir );
	return $this;
}

#==========================================
# getImageName
#------------------------------------------
sub getImageName {
	my $this   = shift;
	my $system = $this->{system};
	my $arch   = $this->{arch};
	my $label  = basename ($system);
	$label =~ s/\.$arch.*$//;
	return $label;
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
	my $primes = qx (factor $size); $primes =~ s/^.*: //;
	my $blocksize = 1;
	for my $factor (split /\s/,$primes) {
		last if ($blocksize * $factor > 8192);
		$blocksize *= $factor;
	}
	my $blocks = $size / $blocksize;
	my $sum  = qx (cat $file | md5sum - | cut -f 1 -d-);
	chomp $sum;
	if ($file =~ /\.raw$/) {
		$file =~ s/raw$/md5/;
	}
	qx (echo "$sum $blocks $blocksize" > $file);
	$kiwi -> done();
	return $this;
}

1; 
