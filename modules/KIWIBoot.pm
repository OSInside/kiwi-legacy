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

#==========================================
# Private
#------------------------------------------
my $kiwi;    # log handler
my $initrd;  # initrd file name
my $system;  # sytem image file name
my $kernel;  # kernel for initrd
my $tmpdir;  # temporary directory
my $result;  # result of external calls
my $status;  # output of last command

#==========================================
# Constructor
#------------------------------------------
sub new {
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	$kiwi   = shift;
	$initrd = shift;
	$system = shift;
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
	}
	}
	if (! -d "/usr/lib/grub") {
		$kiwi -> error  ("Couldn't find the grub");
		$kiwi -> failed ();
		return undef;
	}
	$kernel = $initrd;
	$kernel =~ s/gz$/kernel/;
	$kernel = glob ("$kernel*");
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
	chomp  $tmpdir;
	return $this;
}

#==========================================
# createBootStructure
#------------------------------------------
sub createBootStructure {
	my $this = shift;
	$kiwi -> info ("Creating initial boot structure");
	$status = qx ( mkdir -p $tmpdir/boot/grub 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed creating initial directories: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx ( cp $initrd $tmpdir/boot/initrd 2>&1 );
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed importing initrd: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx ( cp $kernel $tmpdir/boot/linux 2>&1 );
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
			my $description = glob ("$device/host*/target*/*/block*");
			my $isremovable = glob ("$device/host*/target*/*/block*/removable");
			if (! -d $description) {
				next;
			}
			my $serial;
			if ($description =~ /usb-storage\/(.*?):.*/) {
				$serial = "/sys/bus/usb/devices/$1/serial";
				if (! open (FD,$serial)) {
					next;
				}
				$serial = <FD>;
				chomp $serial;
				close FD;
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
	return %devices;
}

#==========================================
# setupBootStick
#------------------------------------------
sub setupBootStick {
	my $this = shift;
	#==========================================
	# Create Stick structure
	#------------------------------------------
	createBootStructure();

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
	print FD "framebuffer 1\n";
	print FD "title KIWI Stick boot\n";
	print FD " root (hd0,0)\n";
	print FD " kernel /boot/linux vga=normal ramdisk_size=256000\n";
	print FD " initrd /boot/initrd\n"; 
	close FD;
	if (! open (FD,">$tmpdir/boot/grub/device.map")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't create device.map: $!");
		$kiwi -> failed ();
		return undef;
	}
	print FD "(hd0) /dev/sda\n";
	close FD;
	$kiwi -> done();

	#==========================================
	# Create ext2 image
	#------------------------------------------
	$kiwi -> info ("Creating stick image");
	my $name = $initrd; $name =~ s/gz$/stickboot/;
	my $size = qx (du -ks $tmpdir | cut -f1 2>&1);
	chomp ($size); $size += 1024;
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
	qx (umount /mnt/ 2>&1);
	$kiwi -> done();

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
		print FD ",80,L,*\n";
		print FD ",,L\n";
	} else {
		print FD ",,L,*\n";
	}
	close FD;
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
	$status = qx (dd if=$name of=$stick"1" bs=1k 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't dump image to stick: $status");
		$kiwi -> failed ();
		return undef;
	}
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
	}
	#==========================================
	# Install grub on stick
	#------------------------------------------
	$kiwi -> info ("Installing boot manager on stick");
	$status = qx (mount $stick"1" /mnt/ 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't mount stick image: $status");
		$kiwi -> failed ();
		return undef;
	}
	$status = qx (/usr/sbin/grub-install --root-directory=/mnt/ $stick 2>&1);
	$result = $? >> 8;
	if ($result != 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Couldn't install grub on stick: $status");
		$kiwi -> failed ();
		qx (umount /mnt/ 2>&1);
		return undef;
	}
	qx (umount /mnt/ 2>&1);
	$kiwi -> done();
	return $this;
}

#==========================================
# setupBootCD
#------------------------------------------
sub setupBootCD {
	my $this = shift;
	#==========================================
	# Create CD structure
	#------------------------------------------
	createBootStructure();
    
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
	print FD " kernel (cd)/boot/linux vga=normal ramdisk_size=256000\n";
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

1;
