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
use KIWIMigrate;

#============================================
# Globals (Version)
#--------------------------------------------
our $Version       = "1.44";
our $SchemeVersion = "1.4";
our $openSUSE      = "http://software.opensuse.org/download/";
#============================================
# Globals
#--------------------------------------------
our $System  = "/usr/share/kiwi/image";
our $Tools   = "/usr/share/kiwi/tools";
our $Scheme  = "/usr/share/kiwi/modules/KIWIScheme.xsd";
our $KConfig = "/usr/share/kiwi/modules/KIWIConfig.sh";
our $KMigrate= "/usr/share/kiwi/modules/KIWIMigrate.txt";
#============================================
# Globals
#--------------------------------------------
our $Prepare;           # control XML file for building chroot extend
our $Create;            # image description for building image extend
our $CreateInstSource;  # create installation source from meta packages
our $Upgrade;           # upgrade physical extend
our $Destination;       # destination directory for logical extends
our $LogFile;           # optional file name for logging
our $RootTree;          # optional root tree destination
our $Survive;           # if set to "yes" don't exit kiwi
our $BootStick;         # deploy initrd booting from USB stick
our $BootStickSystem;   # system image to be copied on an USB stick
our $BootStickDevice;   # device to install stick image on
our $BootVMSystem;      # system image to be copied on a VM disk
our $BootVMFormat;      # virtual disk format supported by qemu-img
our $BootVMDisk;        # deploy initrd booting from a VM 
our $BootVMSize;        # size of virtual disk
our $BootCD;            # deploy initrd booting from CD
our $InstallCD;         # deploy initrd installing from cD
our $InstallCDSystem;   # system image to be deployed via CD
our $StripImage;        # strip shared objects and binaries
our $CreatePassword;    # create crypt password string
our $ImageName;         # filename of current image, used in Modules
our %ForeignRepo;       # may contain XML::LibXML::Element objects
our @AddRepository;     # add repository for building physical extend
our @AddRepositoryType; # add repository type
our @AddPackage;        # add packages to the image package list
our $SetRepository;     # set first repository for building physical extend
our $SetRepositoryType; # set firt repository type
our $SetImageType;      # set image type to use, default is primary type
our $Migrate;           # migrate running system to image description
our @Exclude;           # exclude directories in migrate search
our $Report;            # create report on root/ tree migration only

#============================================
# Globals
#--------------------------------------------
my $kiwi;       # global logging handler object
my $root;       # KIWIRoot  object for installations
my $image;      # KIWIImage object for logical extends
my $migrate;    # KIWIMigrate object for system to image migration

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
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
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
	# Create instsource from meta packages
	#----------------------------------------
	if (defined $CreateInstSource) {
		$kiwi -> info ("Reading image description...");
		my $xml = new KIWIXML ( $kiwi,$CreateInstSource );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		$kiwi -> done();
		#==========================================
		# Initialize installation source tree
		#------------------------------------------
		my $root = $xml -> createTmpDirectory ( $RootTree );
		if (! defined $root) {
			$kiwi -> error ("Couldn't create instsource root");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		# TODO
		# test code only...
		print "*** DIR = $root\n";
		my %source = $xml -> getInstSourceRepository();
		my @slist  = keys %source;
		print "*** SOURCE = @slist\n";
		my @arch = $xml -> getInstSourceArchList();
		print "*** ARCH(S): @arch\n";
		my %metapacks = $xml -> getInstSourceMetaPackageList();
		my %metafiles = $xml -> getInstSourceMetaFiles();
		my %pack = $xml -> getInstSourcePackageList();
		foreach (keys %metapacks) {
			my $p = $_;
			my $a = $metapacks{$p};
			print "$p -> ";
			if (defined $a) {
				print "$a\n";
			} else {
				print "undefined\n";
			}
		}
		foreach (keys %metafiles) {
			print "URL: $_\n";
		}
		my $surl=$source{other_repo}{source};
		my $file="$surl/kiwi-desc-usbboot.*\.rpm";
		if (! $xml->getInstSourceFile ($file,$root)) {
			$kiwi -> error ("Couldn't download file");
			$kiwi -> failed ();
		}
		# TODO
		# Hi Jan, this is your playground :-) Have fun
		# ...
		kiwiExit (0);
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
		# Check for set-repo option
		#------------------------------------------
		if (defined $SetRepository) {
			$xml -> setRepository ($SetRepositoryType,$SetRepository);
		}
		#==========================================
		# Check for add-repo option
		#------------------------------------------
		if (defined @AddRepository) {
			$xml -> addRepository (\@AddRepositoryType,\@AddRepository);
		}
		#==========================================
		# Check for add-package option
		#------------------------------------------
		if (defined @AddPackage) {
			$xml -> addImagePackages (@AddPackage);
		}
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
		my $xml = new KIWIXML ( $kiwi,"$Create/image",undef,$SetImageType );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		$kiwi -> done();
		#==========================================
		# Check type params and create image obj
		#------------------------------------------
		$image = new KIWIImage (
			$kiwi,$xml,$Create,$Destination,$StripImage,
			"/base-system"
		);
		my %type = %{$xml->getImageTypeAndAttributes()};
		my $para = checkType ( \%type );
		if (! defined $para) {
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Check for type packages if any
		#------------------------------------------
		my @addonList;
		if ($type{type} eq "vmx") {
			$kiwi -> info ("Creating VMware package list");
			@addonList = $xml -> getVMwareList();
			$kiwi -> done();
		}
		if ($type{type} eq "xen") {
			$kiwi -> info ("Creating Xen package list");
			@addonList = $xml -> getXenList();
			$kiwi -> done();
		}
		if (@addonList) {
			$kiwi -> info ("Installing packages: @addonList...\n");
			$kiwi -> warning (
				"*** Packages installed here won't be removed later ***\n"
			);
			$main::Survive = "yes";
			$main::Upgrade = $Create;
			@main::AddPackage = @addonList;
			undef $main::Create;
			if (! defined main::main()) {
				$main::Survive = "default";
				my $code = kiwiExit (1); return $code;
			}
			$main::Survive = "default";
			$main::Create  = $main::Upgrade;
			undef $main::Upgrade;
		}
		#==========================================
		# Initialize logical image extend
		#------------------------------------------
		my $ok;
		SWITCH: for ($type{type}) {
			/^ext2/     && do {
				$ok = $image -> createImageEXT2 ();
				last SWITCH;
			};
			/^ext3/     && do {
				$ok = $image -> createImageEXT3 ();
				last SWITCH;
			};
			/^reiserfs/ && do {
				$ok = $image -> createImageReiserFS ();
				last SWITCH;
			};
			/^squashfs/ && do {
				$ok = $image -> createImageSquashFS ();
				last SWITCH;
			};
			/^cpio/     && do {
				$ok = $image -> createImageCPIO ();
				last SWITCH;
			};
			/^iso/      && do {
				$ok = $image -> createImageLiveCD ( $para );
				last SWITCH;
			};
			/^split/    && do {
				$ok = $image -> createImageSplit ( $para );
				last SWITCH;
			};
			/^usb/      && do {
				$ok = $image -> createImageUSB ( $para );
				last SWITCH;
			};
			/^vmx/      && do {
				$ok = $image -> createImageVMX ( $para );
				last SWITCH;
			};
			/^xen/      && do {
				$ok = $image -> createImageXen ( $para );
				last SWITCH;
			};
			/^pxe/      && do {
				$ok = $image -> createImagePXE ( $para );
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type{type}");
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
	# Upgrade image in chroot system
	#------------------------------------------
	if (defined $Upgrade) {
		$kiwi -> info ("Reading image description...");
		my $xml = new KIWIXML ( $kiwi,"$Upgrade/image" );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		$kiwi -> done();
		#==========================================
		# Check for set-repo option
		#------------------------------------------
		if (defined $SetRepository) {
			$xml -> setRepository ($SetRepositoryType,$SetRepository);
		}
		#==========================================
		# Check for add-repo option
		#------------------------------------------
		if (defined @AddRepository) {
			$xml -> addRepository (\@AddRepositoryType,\@AddRepository);
		}
		#==========================================
		# Initialize root system, use existing root
		#------------------------------------------
		$root = new KIWIRoot (
			$kiwi,$xml,$Upgrade,undef,
			"/base-system",$Upgrade,\@AddPackage
		);
		if (! defined $root) {
			$kiwi -> error ("Couldn't create root object");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Upgrade root system
		#------------------------------------------
		if (! $root -> upgrade ()) {
			$kiwi -> error ("Image Upgrade failed");
			$kiwi -> failed ();
			$root -> cleanMount ();
			my $code = kiwiExit (1); return $code;
		}
		$root -> cleanMount ();
		kiwiExit (0);
	}

	#==========================================
	# Migrate systm to image description
	#------------------------------------------
	if (defined $Migrate) {
		$kiwi -> info ("Starting system to image migration");
		$migrate = new KIWIMigrate (
			$kiwi,$Destination,$Migrate,\@Exclude,$Report
		);
		if (! defined $migrate) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $migrate -> setTemplate()) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $migrate -> setServiceList()) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $migrate -> setSystemConfiguration()) {
			my $code = kiwiExit (1); return $code;
		}
		kiwiExit (0);
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
		my $boot = new KIWIBoot (
			$kiwi,$BootStick,$BootStickSystem,undef,
			$BootStickDevice
		);
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
			$kiwi,$BootVMDisk,$BootVMSystem,
			$BootVMSize,undef,$BootVMFormat
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
		"version"               => \&version,
		"logfile=s"             => \$LogFile,
		"prepare|p=s"           => \$Prepare,
		"migrate|m=s"           => \$Migrate,
		"exclude|e=s"           => \@Exclude,
		"report"                => \$Report,
		"list|l"                => \&listImage,
		"create|c=s"            => \$Create,
		"create-instsource=s"   => \$CreateInstSource,
		"add-repo=s"            => \@AddRepository,
		"add-repotype=s"        => \@AddRepositoryType,
		"add-package=s"         => \@AddPackage,
		"set-repo=s"            => \$SetRepository,
		"set-repotype=s"        => \$SetRepositoryType,
		"type|t=s"              => \$SetImageType,
		"upgrade|u=s"           => \$Upgrade,
		"destdir|d=s"           => \$Destination,
		"root|r=s"              => \$RootTree,
		"bootstick=s"           => \$BootStick,
		"bootvm=s"              => \$BootVMDisk,
		"bootstick-system=s"    => \$BootStickSystem,
		"bootstick-device=s"    => \$BootStickDevice,
		"bootvm-system=s"       => \$BootVMSystem,
		"bootvm-format=s"       => \$BootVMFormat,
		"bootvm-disksize=s"     => \$BootVMSize,
		"bootcd=s"              => \$BootCD,
		"installcd=s"           => \$InstallCD,
		"installcd-system=s"    => \$InstallCDSystem,
		"strip|s"               => \$StripImage,
		"createpassword"        => \$CreatePassword,
		"help|h"                => \&usage,
		"<>"                    => \&usage
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
		(! defined $InstallCD) && (! defined $Upgrade) &&
		(! defined $BootVMDisk) && (! defined $CreatePassword) &&
		(! defined $CreateInstSource) && (! defined $Migrate)
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
	if ((defined @AddRepository) && (! defined @AddRepositoryType)) {
		$kiwi -> info ("No repository type specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $RootTree) && ($RootTree !~ /^\//)) {
		my $workingDir = qx ( pwd ); chomp $workingDir;
		$RootTree = $workingDir."/".$RootTree;
	}
	if ((defined $Migrate) && (! defined $Destination)) {
		$kiwi -> info ("No migration destination directory specified");
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
	print "Image Preparation/Creation:\n";
	print "  kiwi -p | --prepare <image-path>\n";
	print "  kiwi -c | --create  <image-root>\n";
	print "Image Upgrade:\n";
	print "  kiwi -u | --upgrade <image-root>\n";
	print "System to Image migration:\n";
	print "  kiwi -m | --migrate <name> --destdir <destination-path> \\\n";
	print "     [ --exclude <directory> --exclude ... ] \\\n";
	print "     [ --report ]\n";
	print "Image postprocessing modes:\n";
	print "  kiwi --bootstick <initrd> \\\n";
	print "     [ --bootstick-system <systemImage> ] \\\n";
	print "     [ --bootstick-device <device> ] \\\n";
	print "  kiwi --bootvm <initrd> --bootvm-system <systemImage> \\\n";
	print "     [ --bootvm-disksize <size> ]\n";
	print "     [ --bootvm-format <format> ]\n";
	print "  kiwi --bootcd <initrd>\n";
	print "  kiwi --installcd <initrd> --installcd-system <systemImage>\n";
	print "Helper Tools:\n";
	print "  kiwi --createpassword\n";
	print "  kiwi --create-instsource <image-path>\n";
	print "Options:\n";
	print "--\n";
	print "  [ -d | --destdir <destination-path> ]\n";
	print "    Specify an alternative destination directory for\n";
	print "    storing the logical extends. By default the current\n";
	print "    directory is used\n";
	print "\n";
	print "  [ -t | --type <image-type> ]\n";
	print "    Specify the output image type to use for this image\n";
	print "    The type must exist in the config.xml description\n";
	print "    By the default the primary type will be used. If there is\n";
	print "    no primary attribute set the first type entry of the\n";
	print "    preferences section is the primary type\n"; 
	print "    makes only sense in combination with --create\n";
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
	print "  [ --add-repo <repo-path> --add-repotype <type> ]\n";
    print "    Add the given repository and type for this run of an\n";
	print "    image prepare or upgrade process.\n";
	print "    Multiple --add-repo/--add-repotype options are possible\n";
	print "    The change will not be written to the config.xml file\n";
	print "\n";
	print "  [ --set-repo <repo-path> [ --set-repotype <type> ]]\n";
	print "    set the given repository and optional type for the first\n";
	print "    repository entry within the config.xml. The change will not\n";
	print "    be written to the xml file and is valid for this run of\n";
	print "    image prepare or upgrade process.\n";
	print "\n";
	print "  [ --add-package <package> ]\n";
	print "    Add the given package name to the list of image packages\n";
	print "    multiple --add-package options are possible. The change\n";
	print "    will not be written to the config.xml file\n";
	print "\n";
	print "  [ --logfile <filename> | terminal ]\n";
	print "    Write to the log file \`<filename>' instead of\n";
	print "    the terminal.\n";
	print "--\n";
	version();
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
		if (-f "$System/$image/config.xml") {
			$kiwi -> info ("$image");
			my $xml = new KIWIXML ( $kiwi,"$System/$image" );
			if (! $xml) {
				$kiwi -> failed();
				next;
			}
			my $version = $xml -> getImageVersion();
			$kiwi -> note (" -> Version: $version");
			$kiwi -> done();
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
	if (! defined $LogFile) {
		my $rootLog = $kiwi -> getRootLog();
		if (( -f $rootLog) && ($rootLog =~ /(.*)\/.*/)) {
			my $logfile = $1;
			$logfile =~ s/\/$//;
			$logfile = "$logfile.log";
			$kiwi -> info ("Logfile available at: $logfile");
			$kiwi -> done ();
			qx (mv $rootLog $logfile 2>&1);
		}
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
	$kiwi -> note ("\n*** Received signal $_[0] ***\n");
	if (defined $root) {
		$root  -> cleanMount  ();
		$root  -> cleanSource ();
	}
	if (defined $image) {
		$image -> cleanMount ();
		$image -> restoreSplitExtend ();
	}
	if (defined $migrate) {
		$migrate -> cleanMount ();
	}
	$kiwi -> error ("KIWI exited on signal: $_[0]");
	$kiwi -> done  ();
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

#==========================================
# checkType
#------------------------------------------
sub checkType {
	my (%type) = %{$_[0]};
	my $para   = "ok";
	SWITCH: for ($type{type}) {
		/^iso/ && do {
			if (! defined $type{boot}) {
				$kiwi -> error ("$type{type}: No boot image specified");
				$kiwi -> failed ();
				return undef;
			}
			$para = $type{boot};
			if (defined $type{flags}) {
				$para .= ",$type{flags}";
			} 
			last SWITCH;
		};
		/^split/ && do {
			if (! defined $type{filesystem}) {
				$kiwi -> error ("$type{type}: No filesystem pair specified");
				$kiwi -> failed ();
				return undef;
			}
			$para = $type{filesystem};
			last SWITCH;
		};
		/^usb|vmx|xen|pxe/ && do {
			if (! defined $type{filesystem}) {
				$kiwi -> error ("$type{type}: No filesystem specified");
				$kiwi -> failed ();
				return undef;
			}
			if (! defined $type{boot}) {
				$kiwi -> error ("$type{type}: No boot image specified");
				$kiwi -> failed ();
				return undef;
			}
			$para = $type{filesystem}.":".$type{boot};
			last SWITCH;
		};
	}
	return $para;
}

main();
