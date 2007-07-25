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
use File::Basename;
use File::Spec;

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
		if (! -f $system) {
			$kiwi -> error  ("Couldn't find system image file: $system");
			$kiwi -> failed ();
			return undef;
		} else {
			my $status = qx ( file $system | grep -qi squashfs 2>&1 );
			my $result = $? >> 8;
			if ($result == 0) {
				$syszip = -s $system;
				$syszip /= 1024 * 1024;
				$syszip = int $syszip + 70;
			} else {
				$syszip = 0;
			}
		}
	}
	if (! -d "/usr/lib/grub") {
		$kiwi -> error  ("Couldn't find the grub");
		$kiwi -> failed ();
		return undef;
	}
	$kernel = $initrd;
	$kernel =~ s/gz$/kernel/;
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
	$tmpdir = qx ( mktemp -q -d /tmp/kiwiboot.XXXXXX );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Couldn't create tmp dir: $tmpdir: $!");
		$kiwi -> failed ();
		return undef;
	}
	if (! defined $vmsize) {
		my $kernelSize = -s $kernel; # the kernel
		my $initrdSize = -s $initrd; # the boot image
		my $systemSize = -s $system; # the system image
		$vmsize = $kernelSize + $initrdSize + $systemSize;
		my $sparesSize = 0.2 * $vmsize; # and 20% free space
		$vmsize = $vmsize + $sparesSize;
		$vmsize = $vmsize / 1024 / 1024;
		$vmsize = int $vmsize;
		$vmsize = $vmsize."M";
		$kiwi -> info ("Using computed virtual disk size of: $vmsize"); 
	} else {
		$kiwi -> info ("Using given virtual disk size of: $vmsize");
	}
	$kiwi -> done ();
	chomp  $tmpdir;
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
		return undef;
	}
	$status = qx ( cp $kernel $tmpdir/boot/$lname 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing kernel: $status");
		$kiwi -> failed ();
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
					$isremovable = <FD>;
					close FD;
					if ($isremovable == 1) {
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
	$kiwi -> info ("Importing grub stages for stick boot");
	$status = qx ( cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing grub stages: $status");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# Find USB stick devices
	#------------------------------------------
	my %storage = getRemovableUSBStorageDevices();
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
		return undef;
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,0)/image/loader/message\n";
	print FD "\n";
	print FD "title KIWI Stick boot\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux vga=0x318\n";
	print FD " initrd /boot/initrd\n"; 
	close FD;
	$kiwi -> done();
	#==========================================
	# Create ext2 image
	#------------------------------------------
	$kiwi -> info ("Creating stick image");
	my $name = $initrd; $name =~ s/gz$/stickboot/;
	my $size = qx (du -ks $tmpdir | cut -f1 2>&1);
	chomp ($size); $size += 2048;
	$sysird = int ( $size / 1024 );
	$sysird = $sysird + 1;
	$status = qx (dd if=/dev/zero of=$name bs=1k count=$size 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create image file: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx (/sbin/mkfs.ext2 -F $name 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create filesystem: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx (mount -o loop $name /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount image: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx (mv $tmpdir/boot /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install image: $status");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# check for message file in initrd
	#------------------------------------------
	my $message = "'image/loader/message'";
	$status = qx (gzip -cd $initrd | (cd /mnt && cpio -d -i $message 2>&1));
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find message file: $status");
		$kiwi -> failed ();
		qx (umount /mnt/ 2>&1);
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
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Clean tmp
	#------------------------------------------
	unlink $pinfo;
	rmdir  $tmpdir;

	#==========================================
	# Dump initrd image on stick
	#------------------------------------------
	$kiwi -> info ("Dumping initrd image to stick");
	$status = qx ( umount $stick"1" 2>&1 );
	$status = qx (dd if=$name of=$stick"1" bs=8k 2>&1);
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
		$status = qx (dd if=$system of=$stick"2" bs=8k 2>&1);
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
# setupBootCD
#------------------------------------------
sub setupBootCD {
	my $this      = shift;
	my $imageData = shift;
	my $kiwi      = $this->{kiwi};
	my $tmpdir    = $this->{tmpdir};
	my $initrd    = $this->{initrd};
	my $status;
	my $result;
	if (defined $imageData) {
		my $imageDataMd5 = "$imageData.md5";
		my $imageDataConfig = "$imageData.config";
		qx ( mkdir -p $tmpdir/image 2>&1 );
		qx ( cp $imageData $tmpdir/image 2>&1 );
		qx ( cp $imageDataMd5 $tmpdir/image 2>&1 );
		qx ( cp $imageDataConfig $tmpdir/config.isoclient 2>&1 );
	}
	#==========================================
	# Create CD structure
	#------------------------------------------
	if (! $this -> createBootStructure()) {
		return undef;
	}
	#==========================================
	# Import grub stages
	#------------------------------------------
	$kiwi -> info ("Importing grub stages for CD boot");
	my $stage1 = "/usr/lib/grub/stage1";
	my $stage2 = "/usr/lib/grub/stage2_eltorito";
	$status = qx ( cp $stage1 $tmpdir/boot/grub/stage1 2>&1 );
	$status = qx ( cp $stage2 $tmpdir/boot/grub/stage2 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing grub stages: $status");
		$kiwi -> failed ();
		return undef; 
	}
	$kiwi -> done ();

	#==========================================
	# Creating menu.lst for the grub
	#------------------------------------------
	$kiwi -> info ("Creating grub menu");
	if (! open (FD,">$tmpdir/boot/grub/menu.lst")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create menu.lst: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "framebuffer 1\n";
	print FD "title KIWI CD boot\n";
	print FD " kernel (cd)/boot/linux vga=0x318 ramdisk_size=256000\n";
	print FD " initrd (cd)/boot/initrd\n";
	close FD;
	$kiwi -> done();

	#==========================================
	# Create an iso image from the tree
	#------------------------------------------
	$kiwi -> info ("Creating ISO image");
	my $name = $initrd; $name =~ s/gz$/cdboot.iso/;
	my $base = "-R -b boot/grub/stage2";
	my $opts = "-no-emul-boot -boot-load-size 4 -boot-info-table";
	$status = qx (cd $tmpdir && mkisofs $base $opts -o $name . 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating ISO image: $status");
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> done ();
	#==========================================
	# Clean tmp
	#------------------------------------------
	qx (rm -rf $tmpdir);
	$kiwi -> info ("Created $name to be burned on CD");
	$kiwi -> done ();
}

#==========================================
# setupBootDisk
#------------------------------------------
sub setupBootDisk {
	my $this      = shift;
	my $kiwi      = $this->{kiwi};
	my $system    = $this->{system};
	my $vmsize    = $this->{vmsize};
	my $format    = $this->{format};
	my $syszip    = $this->{syszip};
	my $tmpdir    = $this->{tmpdir};
	my $initrd    = $this->{initrd};
	my $diskname  = $system.".raw";
	my $loop      = "/dev/loop0";
	my $loopfound = 0;
	my $sysname;
	my $sysird;
	my $result;
	my $status;
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
			last;
		}
	}
	if (! $loopfound) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't find free loop device");
		$kiwi -> failed ();
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
	$kiwi -> info ("Importing grub stages for VM boot");
	$status = qx ( cp /usr/lib/grub/* $tmpdir/boot/grub 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing grub stages: $status");
		$kiwi -> failed ();
		return undef;
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
		return undef;
	}
	print FD "color cyan/blue white/blue\n";
	print FD "default 0\n";
	print FD "timeout 10\n";
	print FD "gfxmenu (hd0,0)/image/loader/message\n";
	print FD "\n";
	print FD "title KIWI VM boot\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux.vmx vga=0x318\n";
	print FD " initrd /boot/initrd.vmx\n";
	close FD;
	$kiwi -> done();
	#==========================================
	# Create ext2 image if syszip is active
	#------------------------------------------
	if ($syszip > 0) {
		$kiwi -> info ("Creating VM boot image");
		$sysname= $initrd; $sysname =~ s/gz$/vmboot/;
		my $size = qx (du -ks $tmpdir | cut -f1 2>&1);
		chomp ($size); $size += 2048;
		$sysird = int ( $size / 1024 );
		$sysird = $sysird + 1;
		$status = qx (dd if=/dev/zero of=$sysname bs=1k count=$size 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create image file: $status");
			$kiwi -> failed ();
			return undef;
		}
		$status = qx (/sbin/mkfs.ext2 -F $sysname 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't create filesystem: $status");
			$kiwi -> failed ();
			return undef;
		}
		$status = qx (mount -o loop $sysname /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't mount image: $status");
			$kiwi -> failed ();
			return undef;
		}
		$status = qx (mv $tmpdir/boot /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install image: $status");
			$kiwi -> failed ();
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
		return undef;
	}	
	$status = qx (qemu-img create $diskname $vmsize 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating virtual disk: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx ( /sbin/losetup $loop $diskname 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed binding virtual disk: $status");
		$kiwi -> failed ();
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
	$kiwi -> info ("Dumping system image on virtual disk");
	$status = qx (dd if=$system of=$root bs=8k 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't dump image to virtual disk: $status");
		$kiwi -> failed ();
		qx ( /sbin/kpartx  -d $loop );
		qx ( /sbin/losetup -d $loop );
		return undef;
	}
	$kiwi -> done();
	#==========================================
	# Dump boot image on virtual disk
	#------------------------------------------
	$kiwi -> info ("Dumping boot image to virtual disk");
	if ($syszip > 0) {
		$root = "/dev/mapper".$dmap."p1";
		$status = qx (dd if=$sysname of=$root bs=8k 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't dump image: $status");
			$kiwi -> failed ();
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
			return undef;
		}
		#==========================================
		# Copy boot data on system image
		#------------------------------------------
		$status = qx (cp -a $tmpdir/boot /mnt/ 2>&1);
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't install image: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx ( umount /mnt/ 2>&1 );
			return undef;
		}
		#==========================================
		# check for message file in initrd
		#------------------------------------------
		my $message = "'image/loader/message'";
		$status = qx (gzip -cd $initrd | (cd /mnt && cpio -d -i $message 2>&1));
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Couldn't find message file: $status");
			$kiwi -> failed ();
			qx ( /sbin/kpartx  -d $loop );
			qx ( /sbin/losetup -d $loop );
			qx ( umount /mnt/ 2>&1 );
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
		$kiwi -> info ("Creating $format image");
		my $formatname = $system.".".$format;
		$status = qx ( qemu-img convert -f raw $loop -O $format $formatname );
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
	#==========================================
	# cleanup loop setup and device mapper
	#------------------------------------------
	qx ( /sbin/losetup -d $loop );
	return $this;
}

1; 
