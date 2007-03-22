#!/usr/bin/perl
#================
# FILE          : kiwi.pl
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This is the main script to provide support
#               : for creating operating system images
#               : 
#               :
# STATUS        : $LastChangedBy: ms $
#               : $LastChangedRevision: 1 $
#----------------
use lib './modules';
use lib '/usr/share/kiwi/modules';
use strict;

use Getopt::Long;
use KIWIRoot;
use KIWIXML;
use KIWILog;
use KIWIImage;
use KIWIBoot;

our $Version = "1.2";
our $System  = "/usr/share/kiwi/image";
our $Scheme  = "/usr/share/kiwi/modules/KIWIScheme.xsd";
#============================================
# Globals
#--------------------------------------------
our $Prepare;         # control XML file for building chroot extend
our $Create;          # image description for building image extend
our $Destination;     # destination directory for logical extends
our $LogFile;         # optional file name for logging
our $RootTree;        # optional root tree destination
our $Survive;         # if set to "yes" don't exit kiwi
our $BootStick;       # deploy initrd booting from USB stick
our $BootStickSystem; # system image to be copied on an USB stick
our $BootVMSystem;    # system image to be copied on a VM disk
our $BootVMDisk;      # deploy initrd booting from a VM 
our $BootVMSize;      # size of virtual disk
our $BootCD;          # deploy initrd booting from CD
our $InstallCD;       # deploy initrd installing from cD
our $InstallCDSystem; # system image to be deployed via CD
our $StripImage;      # strip shared objects and binaries
our $CreatePassword;  # create crypt password string
our $ImageName;       # filename of current image, used in Modules
our %ForeignRepo;     # may contain XML::LibXML::Element objects

#============================================
# Globals
#--------------------------------------------
my $kiwi;       # global logging handler object
my $root;       # KIWIRoot  object for installations
my $image;      # KIWIImage object for logical extends

#==========================================
# main
#------------------------------------------
sub main {
	# ...
	# This is the KIWI project to prepare and build operating
	# system images from a given installation source. The system
	# will create a chroot environment representing the needs
	# of a XML control file. Once prepared KIWI can create several
	# OS image types.
	# ---
	#==========================================
	# Create logger object
	#------------------------------------------
	$kiwi = new KIWILog();

	#==========================================
	# Initialize and check options
	#------------------------------------------
	init();

	#==========================================
	# Setup logging location
	#------------------------------------------
	if (defined $LogFile) {
		$kiwi -> info ("Setting log file to: $LogFile\n");
		if (! $kiwi -> setLogFile ( $LogFile )) {
			my $code = kiwiExit (1); return $code;
		}
	}

	#========================================
	# Prepare image and build chroot system
	#----------------------------------------
	if (defined $Prepare) {
		$kiwi -> info ("Reading image description...");
		my $xml = new KIWIXML ( $kiwi,$Prepare,\%ForeignRepo );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		$kiwi -> done();
		#==========================================
		# Check for inheritance
		#------------------------------------------
		if (! $xml -> setupImageInheritance()) {
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Initialize root system
		#------------------------------------------
		$root = new KIWIRoot (
			$kiwi,$xml,$Prepare,$RootTree,
			"/base-system"
		);
		if (! defined $root) {
			$kiwi -> error ("Couldn't create root object");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		if (! defined $root -> init ()) {
			$kiwi -> error ("Base initialization failed");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Install root system
		#------------------------------------------
		if (! $root -> install ()) {
			$kiwi -> error ("Image installation failed");
			$kiwi -> failed ();
			$root -> cleanMount ();
			my $code = kiwiExit (1); return $code;
		}
		if (! $root -> setup ()) {
			$kiwi -> error ("Couldn't setup image system");
			$kiwi -> failed ();
			$root -> cleanMount ();
			my $code = kiwiExit (1); return $code;
		}
		$root -> cleanMount ();
		kiwiExit (0);
	}

	#==========================================
	# Create image from chroot system
	#------------------------------------------
	if (defined $Create) {
		$kiwi -> info ("Reading image description...");
		my $xml = new KIWIXML ( $kiwi,"$Create/image" );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		$kiwi -> done();
		#==========================================
		# Initialize logical image extend
		#------------------------------------------
		$image = new KIWIImage ( $kiwi,$xml,$Create,$Destination,$StripImage );
		my $type = $xml->getImageType();
		my $ok;
		SWITCH: for ($type) {
			/^ext2/       && do {
				$ok = $image -> createImageEXT2 ();
				last SWITCH;
			};
			/^ext3/       && do {
				$ok = $image -> createImageEXT3 ();
				last SWITCH;
			};
			/^reiserfs/   && do {
				$ok = $image -> createImageReiserFS ();
				last SWITCH;
			};
			/^squashfs/   && do {
				$ok = $image -> createImageSquashFS ();
				last SWITCH;
			};
			/^cpio/       && do {
				$ok = $image -> createImageCPIO ();
				last SWITCH;
			};
			/^iso:(.*)/   && do {
				$ok = $image -> createImageLiveCD ( $1 );
				last SWITCH;
			};
			/^split:(.*)/ && do {
				$ok = $image -> createImageSplit ( $1 );
				last SWITCH;
			};
			/^usb:(.*)/   && do {
				$ok = $image -> createImageUSB ( $1 );
				last SWITCH;
			};
			/^vmx:(.*)/   && do {
				$ok = $image -> createImageVMX ( $1 );
				last SWITCH;
			};
			/^xen:(.*)/   && do {
				$ok = $image -> createImageXen ( $1 );
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		if ($ok) {
			my $code = kiwiExit (0); return $code;
		} else {
			my $code = kiwiExit (1); return $code;
		}
	}

	#==========================================
	# Create a crypted password and print it
	#------------------------------------------
	if (defined $CreatePassword) {
		my $word2 = 2;
		my $word1 = 1;
		my $salt  = (getpwuid ($<))[1];
		while ($word1 ne $word2) {
			$kiwi -> info ("Enter Password: ");
			system "stty -echo";
			chomp ($word1 = <STDIN>);
			system "stty echo";
			$kiwi -> done ();
			$kiwi -> info ("Reenter Password: ");
			system "stty -echo";
			chomp ($word2 = <STDIN>);
			system "stty echo";
			if ( $word1 ne $word2 ) {
				$kiwi -> failed ();
				$kiwi -> info ("*** Passwords differ, please try again ***");
				$kiwi -> failed ();
			}
		}
		$kiwi -> done ();
		my $pwd = crypt ($word1, $salt);
		$kiwi -> info ("Your password:\n\t$pwd\n");
	}

	#==========================================
	# Write an initrd image to a boot USB stick
	#------------------------------------------
	if (defined $BootStick) {
		$kiwi -> info ("Creating boot USB stick from: $BootStick...\n");
		my $boot = new KIWIBoot ($kiwi,$BootStick,$BootStickSystem);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootStick()) {
			my $code = kiwiExit (1); return $code;
		}
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create an initrd .iso for CD boot
	#------------------------------------------
	if (defined $BootCD) {
		$kiwi -> info ("Creating boot ISO from: $BootCD...\n");
		my $boot = new KIWIBoot ($kiwi,$BootCD);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootCD()) {
			my $code = kiwiExit (1); return $code;
		}
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create an initrd .iso for CD install
	#------------------------------------------
	if (defined $InstallCD) {
		$kiwi -> info ("Creating install ISO from: $InstallCD...\n");
		if (! defined $InstallCDSystem) {
			$kiwi -> failed ();
			$kiwi -> error ("No CD system specified");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}

		my $boot = new KIWIBoot ($kiwi,$InstallCD);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootCD ($InstallCDSystem)) {
			my $code = kiwiExit (1); return $code;
		}

		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create a virtual disk image
	#------------------------------------------
	if (defined $BootVMDisk) {
		$kiwi -> info ("Creating boot VM disk from: $BootVMDisk...\n");
		if (! defined $BootVMSystem) {
			$kiwi -> failed ();
			$kiwi -> error  ("No VM system specified");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}
		qx ( file $BootVMSystem | grep -q 'gzip compressed data' );
		my $code = $? >> 8;
		if ($code == 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't use compressed VM system");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}
		my $boot = new KIWIBoot (
			$kiwi,$BootVMDisk,$BootVMSystem,$BootVMSize
		);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootDisk()) {
			my $code = kiwiExit (1); return $code;
		}
		my $code = kiwiExit (0); return $code;
	}
	return 1;
}

#==========================================
# init
#------------------------------------------
sub init {
	# ...
	# initialize, check privilege and options. KIWI
	# requires you to perform at least one action.
	# An action is either to prepare or create an image
	# ---
	$SIG{"HUP"}      = \&quit;
	$SIG{"TERM"}     = \&quit;
	$SIG{"INT"}      = \&quit;

	my $result = GetOptions(
		"version"             => \&version,
		"logfile=s"           => \$LogFile,
		"prepare|p=s"         => \$Prepare,
		"list|l"              => \&listImage,
		"create|c=s"          => \$Create,
		"destdir|d=s"         => \$Destination,
		"root|r=s"            => \$RootTree,
		"bootstick=s"         => \$BootStick,
		"bootvm=s"            => \$BootVMDisk,
		"bootstick-system=s"  => \$BootStickSystem,
		"bootvm-system=s"     => \$BootVMSystem,
		"bootvm-disksize=s"   => \$BootVMSize,
		"bootcd=s"            => \$BootCD,
		"installcd=s"         => \$InstallCD,
		"installcd-system=s"  => \$InstallCDSystem,
		"strip|s"             => \$StripImage,
		"createpassword"      => \$CreatePassword,
		"help|h"              => \&usage,
		"<>"                  => \&usage
	);
	my $user = qx (whoami);
	if ($user !~ /root/i) {
		$kiwi -> info ("Only root can do this");
		$kiwi -> failed ();
		usage();
	}
	if ( $result != 1 ) {
		usage();
	}
	if (
		(! defined $Prepare) && (! defined $Create) &&
		(! defined $BootStick) && (! defined $BootCD) &&
		(! defined $InstallCD) &&
		(! defined $BootVMDisk) && (! defined $CreatePassword)
	) {
		$kiwi -> info ("No operation specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $Create) && (! defined $Destination)) {
		$kiwi -> info ("No destination directory specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	#==========================================
	# remove pre-defined smart channels
	#------------------------------------------
	qx ( rm -f /etc/smart/channels/* );
}

#==========================================
# usage
#------------------------------------------
sub usage {
	# ...
	# Explain the available options for this
	# image creation system
	# ---
	print "Linux KIWI setup  (image builder) (2006-06-05)\n";
	print "Copyright (c) 2006 - SUSE LINUX Products GmbH\n";
	print "\n";

	print "Usage:\n";
	print "  kiwi -l | --list\n";
	print "  kiwi -p | --prepare <image-path>\n";
	print "  kiwi -c | --create  <image-root>\n";
	print "  kiwi --bootstick <initrd> [ --bootstick-system <systemImage> ]\n";
	print "  kiwi --bootvm <initrd> --bootvm-system <systemImage> \\\n";
	print "     [ --bootvm-disksize <size> ]\n";
	print "  kiwi --bootcd <initrd>\n";
	print "  kiwi --installcd <initrd> --installcd-system <systemImage>\n";
	print "  kiwi --createpassword\n";
	print "--\n";
	print "  [ -d | --destdir <destination-path> ]\n";
	print "    Specify an alternative destination directory for\n";
	print "    storing the logical extends. By default the current\n";
	print "    directory is used\n";
	print "\n";
	print "  [ -r | --root <root-path> ]\n";
	print "    Setup the physical extend, chroot system below the\n";
	print "    given root-path path. By default a mktmp directory\n";
	print "    will be used\n";
	print "\n";
	print "  [ -s | --strip ]\n";
	print "    Strip shared objects and executables\n";
	print "    makes only sense in combination with --create\n";
	print "\n";
	print "  [ --logfile <filename> ]\n";
	print "    Write to the log file \`<filename>' instead of\n";
	print "    the terminal.\n";
	print "--\n";
	exit 1;
}

#==========================================
# listImage
#------------------------------------------
sub listImage {
	# ...
	# list known image descriptions and exit
	# ---
	opendir (FD,$System);
	my @images = readdir (FD); closedir (FD);
	foreach my $image (@images) {
		if ($image =~ /^\./) {
			next;
		}
		if (-l "$System/$image") {
			next;
		}
		if (open (HD,"$System/$image/VERSION")) {
			my $version = <HD>;
			my $line = sprintf ("%-20s -> Version: %s",$image,$version);
			$kiwi -> info ("Image: $line");
			close HD;
		}
	}
	exit 0;
}

#==========================================
# exit
#------------------------------------------
sub kiwiExit {
	# ...
	# private Exit function, exit safely
	# ---
	my $code = $_[0];
	if ($Survive eq "yes") {
		if ($code != 0) {
			return undef;
		}
		return $code;
	}
	if ($code != 0) {
		$kiwi -> error  ("KIWI exited with error(s)");
		$kiwi -> done ();
	} else {
		$kiwi -> info ("KIWI exited successfully");
		$kiwi -> done ();
	}
	exit $code;
}

#==========================================
# quit
#------------------------------------------
sub quit {
	# ...
	# signal received, exit safely
	# ---
	$kiwi -> info ("\nReceived signal $_[0]");
	$kiwi -> done ();
	if (defined $root) {
		$root  -> cleanMount  ();
		$root  -> cleanSource ();
	}
	if (defined $image) {
		$image -> cleanMount ();
	}
	exit 1;
}

#==========================================
# version
#------------------------------------------
sub version {
	# ...
	# Version information
	# ---
	$kiwi -> info ("kiwi version v$Version\n");
	exit 0;
}

main();
