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

#============================================
# perl debugger setup
#--------------------------------------------
$DB::inhibit_exit = 0;

#============================================
# Modules
#--------------------------------------------
use warnings;
use Carp qw (cluck);
use Getopt::Long;
use KIWIRoot;
use KIWIXML;
use KIWILog;
use KIWIImage;
use KIWIBoot;
use KIWIMigrate;
use KIWIOverlay;
use KIWIQX;
use KIWITest;

#============================================
# Globals (Version)
#--------------------------------------------
our $Version       = "2.96";
our $Publisher     = "SUSE LINUX Products GmbH";
our $Preparer      = "KIWI - http://kiwi.berlios.de";
our $openSUSE      = "http://download.opensuse.org/repositories/";
our $ConfigFile    = "$ENV{'HOME'}/.kiwirc";
our $ConfigName    = "config.xml";
our $Partitioner   = "fdisk";
our $TT            = "Trace Level ";
our $ConfigStatus  = 0;
our $TL            = 1;
our $BT;
#============================================
# Read $HOME/.kiwirc
#--------------------------------------------
if ( -f $ConfigFile) {
	my $kiwi = new KIWILog("tiny");
	if (! do $ConfigFile) {
		$kiwi -> warning ("Invalid $ConfigFile file...");
		$kiwi -> skipped ();
	} else {
		$kiwi -> info ("Using $ConfigFile");
		$kiwi -> done ();
		$ConfigStatus = 1;
	}
}
#============================================
# Globals
#--------------------------------------------
our $BasePath;         # configurable base kiwi path
our $System;           # configurable baes kiwi image desc. path
our $JabberServer;     # configurable jabber server
our $JabberPort;       # configurable jabber port
our $JabberUserName;   # configurable jabber user name
our $JabberPassword;   # configurable jabber password
our $JabberRessource;  # configurable jabber ressource
our $JabberComponent;  # configurable jabber component
our $LogServerPort;    # configurable log server port
our $Gzip;             # configurable gzip command
if (! defined $LogServerPort) {
	$LogServerPort = "off";
}
if (! defined $Gzip) {
	$Gzip = "gzip -9";
}
if (! defined $JabberPort) {
	$JabberPort = 5223;
}
if ( ! defined $BasePath ) {
	$BasePath = "/usr/share/kiwi";
}
if ( ! defined $System ) {
	$System  = $BasePath."/image";
}
our $Tools    = $BasePath."/tools";
our $Scheme   = $BasePath."/modules/KIWIScheme.rng";
our $SchemeTST= $BasePath."/modules/KIWISchemeTest.rng";
our $KConfig  = $BasePath."/modules/KIWIConfig.sh";
our $KMigrate = $BasePath."/modules/KIWIMigrate.txt";
our $Revision = $BasePath."/.revision";
our $TestBase = $BasePath."/tests";
our @SchemeCVT= (
	$BasePath."/xsl/convert14to20.xsl",
	$BasePath."/xsl/convert20to24.xsl"
);

#==========================================
# Globals (Supported filesystem names)
#------------------------------------------
our %KnownFS;
$KnownFS{ext3}{tool}      = "/sbin/mkfs.ext3";
$KnownFS{ext2}{tool}      = "/sbin/mkfs.ext2";
$KnownFS{squashfs}{tool}  = "/usr/bin/mksquashfs";
$KnownFS{cromfs}{tool}    = "/usr/bin/mkcromfs";
$KnownFS{unified}{tool}   = "/usr/bin/mksquashfs";
$KnownFS{compressed}{tool}= "/usr/bin/mksquashfs";
$KnownFS{reiserfs}{tool}  = "/sbin/mkreiserfs";
$KnownFS{cpio}{tool}      = "/usr/bin/cpio";
$KnownFS{ext3}{ro}        = 0;
$KnownFS{ext2}{ro}        = 0;
$KnownFS{squashfs}{ro}    = 1;
$KnownFS{cromfs}{ro}      = 1;
$KnownFS{unified}{ro}     = 1;
$KnownFS{compressed}{ro}  = 1;
$KnownFS{reiserfs}{ro}    = 0;
$KnownFS{cpio}{ro}        = 0;

#============================================
# Globals
#--------------------------------------------
our $Prepare;               # control XML file for building chroot extend
our $Create;                # image description for building image extend
our $CreateInstSource;      # create installation source from meta packages
our $Upgrade;               # upgrade physical extend
our $Destination;           # destination directory for logical extends
our $RunTestSuite;          # run tests on prepared tree
our @RunTestName;           # run specified tests
our $LogFile;               # optional file name for logging
our $RootTree;              # optional root tree destination
our $Survive;               # if set to "yes" don't exit kiwi
our $BootStick;             # deploy initrd booting from USB stick
our $BootStickSystem;       # system image to be copied on an USB stick
our $BootStickDevice;       # device to install stick image on
our $BootVMSystem;          # system image to be copied on a VM disk
our $BootVMFormat;          # virtual disk format supported by qemu-img
our $BootVMDisk;            # deploy initrd booting from a VM 
our $BootVMSize;            # size of virtual disk
our $InstallCD;             # Installation initrd booting from CD
our $InstallCDSystem;       # virtual disk system image to be installed on disk
our $BootCD;                # Boot initrd booting from CD
our $BootUSB;               # Boot initrd booting from Stick
our $InstallStick;          # Installation initrd booting from USB stick
our $InstallStickSystem;    # virtual disk system image to be installed on disk
our $StripImage;            # strip shared objects and binaries
our $CreateHash;            # create .checksum.md5 for given description
our $SetupSplash;           # setup splash screen (bootsplash or splashy)
our $ImageName;             # filename of current image, used in Modules
our %ForeignRepo;           # may contain XML::LibXML::Element objects
our @AddRepository;         # add repository for building physical extend
our @AddRepositoryType;     # add repository type
our @AddRepositoryAlias;    # alias name for the repository
our @AddRepositoryPriority; # priority for the repository
our @AddPackage;            # add packages to the image package list
our $IgnoreRepos;           # ignore repositories specified so far
our $SetRepository;         # set first repository for building physical extend
our $SetRepositoryType;     # set firt repository type
our $SetRepositoryAlias;    # alias name for the repository
our $SetRepositoryPriority; # priority for the repository
our $SetImageType;          # set image type to use, default is primary type
our $Migrate;               # migrate running system to image description
our @Exclude;               # exclude directories in migrate search
our $Report;                # create report on root/ tree migration only
our @Profiles;              # list of profiles to include in image
our $ListProfiles;          # lists the available profiles in image
our $ForceNewRoot;          # force creation of new root directory
our $BaseRoot;              # use given path as base system
our $BaseRootMode;          # specify base-root mode copy | union
our $NoColor;               # do not used colored output (done/failed messages)
our $LogPort;               # specify alternative log server port
our $GzipCmd;               # command to run to gzip things
our $PrebuiltBootImage;     # directory where a prepared boot image may be found
our $PreChrootCall;         # program name called before chroot switch
our $listXMLInfo;           # list XML information for this operation
our $Compress;              # set compression level
our $CreatePassword;        # create crypted password
our $ISOCheck;              # create checkmedia boot entry
our $PackageManager;        # package manager to use for this image
our $FSBlockSize;           # filesystem block size
our $FSInodeSize;           # filesystem inode size
our $FSJournalSize;         # filesystem journal size
our $kiwi;                  # global logging handler object

#============================================
# Globals
#--------------------------------------------
my $root;       # KIWIRoot  object for installations
my $image;      # KIWIImage object for logical extends
my $boot;       # KIWIBoot  object for logical extends
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
	# Initialize and check options
	#------------------------------------------
	if ((! defined $Survive) || ($Survive ne "yes")) {
		init();
	}
	#==========================================
	# Create logger object
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog();
	}
	#==========================================
	# remove pre-defined smart channels
	#------------------------------------------
	if (glob ("/etc/smart/channels/*")) {
		qxx ( "rm -f /etc/smart/channels/*" );
	}
	#==========================================
	# Check for nocolor option
	#------------------------------------------
	if (defined $NoColor) {
		$kiwi -> info ("Switching off colored output\n");
		if (! $kiwi -> setColorOff ()) {
			my $code = kiwiExit (1); return $code;
		}
	}
	#==========================================
	# Setup logging location
	#------------------------------------------
	if (defined $LogFile) {
		if ((! defined $Survive) || ($Survive ne "yes")) {
			$kiwi -> info ("Setting log file to: $LogFile\n");
			if (! $kiwi -> setLogFile ( $LogFile )) {
				my $code = kiwiExit (1); return $code;
			}
		}
	}

	#========================================
	# Prepare image and build chroot system
	#----------------------------------------
	if (defined $Prepare) {
		$kiwi -> info ("Reading image description [Prepare]...\n");
		my $xml = new KIWIXML ( $kiwi,$Prepare,\%ForeignRepo,undef,\@Profiles );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $xml -> haveMD5File()) {
			$kiwi -> warning ("Description provides no MD5 hash, check");
			$kiwi -> skipped ();
		}
		#==========================================
		# Check for bootprofile in xml descr.
		#------------------------------------------
		if (! @Profiles) {
			my %type = %{$xml->getImageTypeAndAttributes()};
			if (($type{"type"} eq "cpio") && ($type{bootprofile})) {
				@Profiles = split (/,/,$type{bootprofile});
				if (! $xml -> checkProfiles (\@Profiles)) {
					my $code = kiwiExit (1); return $code;
				}
			}
		}
		#==========================================
		# Check for default root in XML
		#------------------------------------------	
		if (! defined $RootTree) {
			$kiwi -> info ("Checking for default root in XML data...");
			$RootTree = $xml -> getImageDefaultRoot();
			if ($RootTree) {
				if ($RootTree !~ /^\//) {
					my $workingDir = qxx ( "pwd" ); chomp $workingDir;
					$RootTree = $workingDir."/".$RootTree;
				}
				$kiwi -> done();
			} else {
				undef $RootTree;
				$kiwi -> notset();
			}
		}
		#==========================================
		# Check for default base root in XML
		#------------------------------------------
		if (! defined $BaseRoot) {
			$kiwi -> info ("Checking for default baseroot in XML data...");
			$BaseRoot = $xml -> getImageDefaultBaseRoot();
			if ($BaseRoot) {
				$kiwi -> done();
			} else {
				undef $BaseRoot;
				$kiwi -> notset();
			}
		}
		#==========================================
		# Check for ignore-repos option
		#------------------------------------------
		if (defined $IgnoreRepos) {
			$xml -> ignoreRepositories ();
		}
		#==========================================
		# Check for set-repo option
		#------------------------------------------
		if (defined $SetRepository) {
			$xml -> setRepository (
				$SetRepositoryType,$SetRepository,
				$SetRepositoryAlias,$SetRepositoryPriority
			);
		}
		#==========================================
		# Check for add-repo option
		#------------------------------------------
		if (defined @AddRepository) {
			$xml -> addRepository (
				\@AddRepositoryType,\@AddRepository,
				\@AddRepositoryAlias,\@AddRepositoryPriority
			);
		}
		#==========================================
		# Validate repo types
		#------------------------------------------
		$xml -> setValidateRepositoryType();
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
			"/base-system",undef,undef,$BaseRoot,$BaseRootMode
		);
		if (! defined $root) {
			$kiwi -> error ("Couldn't create root object");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		if (! defined $BaseRoot) {
			if (! defined $root -> init ()) {
				$kiwi -> error ("Base initialization failed");
				$kiwi -> failed ();
				my $code = kiwiExit (1); return $code;
			}
		}
		#==========================================
		# Check for pre chroot call
		#------------------------------------------
		if (defined $PreChrootCall) {
			$kiwi -> info ("Calling pre-chroot program: $PreChrootCall");
			my $path = $root -> getRootPath();
			my $data = qxx ("$PreChrootCall $path 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> info   ($data);
				$kiwi -> failed ();
				my $code = kiwiExit (1); return $code;
			} else {
				$kiwi -> loginfo ("$PreChrootCall: $data");
			}
			$kiwi -> done ();
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
		#==========================================
		# Cleanup the tree according to prev runs
		#------------------------------------------
		if (-f "$Create/rootfs.tar") {
			qxx ("rm -f $Create/rootfs.tar");
		}
		if (-f "$Create/recovery.tar.gz") {
			qxx ("rm -f $Create/recovery.tar.gz");
		}
		#==========================================
		# Check for overlay requirements
		#------------------------------------------
		my $overlay;
		my $origroot;
		if (defined $BaseRoot) {
			if ((defined $BaseRootMode) && ($BaseRootMode eq "union")) {
				$overlay = new KIWIOverlay ( $kiwi,$BaseRoot,$Create );
				if (! defined $overlay) {
					my $code = kiwiExit (1); return $code;
				}
				if (defined $BaseRootMode) {
					$overlay -> setMode ($BaseRootMode);
				}
				$origroot = $Create;
				$Create = $overlay -> mountOverlay();
				if (! defined $Create) {
					my $code = kiwiExit (1); return $code;
				}
			}
		}
		#==========================================
		# Check for bootprofile in xml descr
		#------------------------------------------
		my $xml;
		if (! @Profiles) {
			$kiwi -> info ("Reading image description [Create]...\n");
			$xml = new KIWIXML (
				$kiwi,"$Create/image",\%ForeignRepo,$SetImageType
			);
			if (! defined $xml) {
				if (defined $BaseRoot) {
					$overlay -> resetOverlay();
				}
				my $code = kiwiExit (1); return $code;
			}
			my %type = %{$xml->getImageTypeAndAttributes()};
			if (($type{"type"} eq "cpio") && ($type{bootprofile})) {
				@Profiles = split (/,/,$type{bootprofile});
				if (! $xml -> checkProfiles (\@Profiles)) {
					my $code = kiwiExit (1); return $code;
				}
			}
		}
		if (! defined $xml) {
			$kiwi -> info ("Reading image description [Create]...\n");
			$xml = new KIWIXML (
				$kiwi,"$Create/image",undef,$SetImageType,\@Profiles
			);
			if (! defined $xml) {
				if (defined $BaseRoot) {
					$overlay -> resetOverlay();
				}
				my $code = kiwiExit (1); return $code;
			}
		}
		#==========================================
		# Update .profile env, current type
		#------------------------------------------
		$kiwi -> info ("Updating type in .profile environment");
		my $type = $xml -> getImageTypeAndAttributes() -> {type};
		qxx (
			"sed -i -e s#kiwi_type=$type=.*#kiwi_type=$type# $Create/.profile"
		);
		$kiwi -> done();
		#==========================================
		# Check for default destination in XML
		#------------------------------------------
		if (! defined $Destination) {
			$kiwi -> info ("Checking for defaultdestination in XML data...");
			$Destination = $xml -> getImageDefaultDestination();
			if (! $Destination) {
				$kiwi -> failed ();
				$kiwi -> info   ("No destination directory specified");
				$kiwi -> failed ();
				if (defined $BaseRoot) {
					$overlay -> resetOverlay();
				}
				my $code = kiwiExit (1); return $code;
			}
			$kiwi -> done();
		}
		#==========================================
		# Check if destdir exists or not 
		#------------------------------------------
		if (! -d $Destination) {
			my $prefix = $kiwi -> getPrefix (1);
			my $answer = "unknown";
			$kiwi -> info ("Destination: $Destination doesn't exist\n");
			while ($answer !~ /^yes$|^no$/) {
				print STDERR $prefix,
					"Would you like kiwi to create it [yes/no] ? ";
				chomp ($answer = <>);
			}
			if ($answer eq "yes") {
				qxx ("mkdir -p $Destination");
			}
		}
		#==========================================
		# Check for default base root in XML
		#------------------------------------------
		if (! defined $BaseRoot) {
			$kiwi -> info ("Checking for default baseroot in XML data...");
			$BaseRoot = $xml -> getImageDefaultBaseRoot();
			if ($BaseRoot) {
				$kiwi -> done();
			} else {
				undef $BaseRoot;
				$kiwi -> notset();
			}
        }
		#==========================================
		# Check for --compress option
		#------------------------------------------
		if (defined $Compress) {
			$kiwi -> info ("Set compression level to: $Compress");
			$xml  -> setCompressed ($Compress);
			$kiwi -> done();
		}
		#==========================================
		# Check type params and create image obj
		#------------------------------------------
		$image = new KIWIImage (
			$kiwi,$xml,$Create,$Destination,$StripImage,
			"/base-system",$origroot
		);
		if (! defined $image) {
			if (defined $BaseRoot) {
				$overlay -> resetOverlay();
			}
			my $code = kiwiExit (1); return $code;
		}
		my %type = %{$xml->getImageTypeAndAttributes()};
		my $para = checkType ( \%type );
		if (! defined $para) {
			if (defined $BaseRoot) {
				$overlay -> resetOverlay();
			}
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
				if (defined $BaseRoot) {
					$overlay -> resetOverlay();
				}
				my $code = kiwiExit (1); return $code;
			}
			$main::Survive = "default";
			$main::Create  = $main::Upgrade;
			undef $main::Upgrade;
		}
		#==========================================
		# Create recovery archive if specified
		#------------------------------------------
		if ($type eq "oem") {
			my $configure = new KIWIConfigure (
				$kiwi,$xml,$Create,$Create."/image"
			);
			if (! defined $configure) {
				if (defined $BaseRoot) {
					$overlay -> resetOverlay();
				}
				my $code = kiwiExit (1); return $code;
			}
			if (! $configure -> setupRecoveryArchive()) {
				if (defined $BaseRoot) {
					$overlay -> resetOverlay();
				}
				my $code = kiwiExit (1); return $code;
			}
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
			/^cromfs/   && do {
				$ok = $image -> createImageCromFS ();
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
			/^oem/      && do {
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
			/^ec2/      && do {
				$ok = $image -> createImageEC2 ( $para );
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $type{type}");
			$kiwi -> failed ();
			if (defined $BaseRoot) {
				$overlay -> resetOverlay();
			}
			my $code = kiwiExit (1); return $code;
		}
		if (defined $BaseRoot) {
			$overlay -> resetOverlay();
		}
		if ($ok) {
			my $code = kiwiExit (0); return $code;
		} else {
			my $code = kiwiExit (1); return $code;
		}
	}

	#==========================================
	# Run test suite on prepared root tree 
	#------------------------------------------
	if (defined $RunTestSuite) {
		#==========================================
		# install testing packages if any
		#------------------------------------------
		$kiwi -> info ("Reading image description [TestSuite]...\n");
		my $xml = new KIWIXML (
			$kiwi,"$RunTestSuite/image",undef,undef,\@Profiles
		);
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		my @testingPackages = $xml -> getTestingList();
		if (@testingPackages) {
			#==========================================
			# Check for default base root in XML
			#------------------------------------------
			if (! defined $BaseRoot) {
				$kiwi -> info ("Checking for default baseroot in XML data...");
				$BaseRoot = $xml -> getImageDefaultBaseRoot();
				if ($BaseRoot) {
					$kiwi -> done();
				} else {
					undef $BaseRoot;
					$kiwi -> notset();
				}
			}
			#==========================================
			# Initialize root system, use existing root
			#------------------------------------------
			$root = new KIWIRoot (
				$kiwi,$xml,$RunTestSuite,undef,
				"/base-system",$RunTestSuite,undef,$BaseRoot,$BaseRootMode
			);
			if (! defined $root) {
				$kiwi -> error ("Couldn't create root object");
				$kiwi -> failed ();
				my $code = kiwiExit (1); return $code;
			}
			if (! $root -> prepareTestingEnvironment()) {
				$root -> cleanMount ();
				my $code = kiwiExit (1); return $code;
			}
			if (! $root -> installTestingPackages(\@testingPackages)) {
				$root -> cleanMount ();
				my $code = kiwiExit (1); return $code;
			}
		}
		#==========================================
		# create package manager for operations
		#------------------------------------------
		my $manager = new KIWIManager (
			$kiwi,$xml,$xml,$RunTestSuite,$xml -> getPackageManager()
		);
		#==========================================
		# set default tests if no names are set
		#------------------------------------------
		if (! @RunTestName) {
			@RunTestName = ("rpm","ldd");
		}
		#==========================================
		# run all tests in @RunTestName
		#------------------------------------------
		my $testCount = @RunTestName;
		my $result_success = 0;
		my $result_failed  = 0;
		$kiwi -> info ("Test suite, evaluating ".$testCount." test(s)\n");
		foreach my $run (@RunTestName) {
			my $runtest = $run;
			if ($runtest !~ /^\.*\//) {
				# if test does not begin with '/' or './' add default path
				$runtest = $TestBase."/".$run;
			}
			my $test = new KIWITest (
				$runtest,$RunTestSuite,$SchemeTST,$manager
			);
			my $testResult = $test -> run();
			$kiwi -> info (
				"Testcase ".$test->getName()." - ".$test->getSummary()
			);
			if ($testResult == 0) {
				$kiwi -> done();
				$result_success += 1;
			} else {
				$kiwi -> failed();
				$result_failed +=1;
				my @outputArray = @{$test -> getAllResults()};
				$kiwi -> warning ("Error message : \n");
				my $txtmsg=$test->getOverallMessage();
				$kiwi -> note($txtmsg);
			}
		}
		#==========================================
		# uninstall testing packages
		#------------------------------------------
		if (@testingPackages) {
			if (! $root -> uninstallTestingPackages(\@testingPackages)) {
				$root -> cleanupTestingEnvironment();
				$root -> cleanMount ();
				my $code = kiwiExit (1); return $code;
			}
			$root -> cleanupTestingEnvironment();
			$root -> cleanMount ();
		}
		#==========================================
		# print test report
		#------------------------------------------	
		if ($result_failed == 0) {
			$kiwi -> info (
				"Tests finished : ".$result_success.
				" test passed, "
			);
			$kiwi -> done();
			kiwiExit (0);
		} else {
			$kiwi -> info (
				"Tests finished : ". $result_failed .
				" of ". ($result_failed+$result_success) .
				" tests failed"
			);
			$kiwi -> failed();
			kiwiExit (1);
		}
	}	

	#==========================================
	# Upgrade image in chroot system
	#------------------------------------------
	if (defined $Upgrade) {
		$kiwi -> info ("Reading image description [Upgrade]...\n");
		my $xml = new KIWIXML ( $kiwi,"$Upgrade/image" );
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Check for default base root in XML
		#------------------------------------------
		if (! defined $BaseRoot) {
			$kiwi -> info ("Checking for default baseroot in XML data...");
			$BaseRoot = $xml -> getImageDefaultBaseRoot();
			if ($BaseRoot) {
				$kiwi -> done();
			} else {
				undef $BaseRoot;
				$kiwi -> notset();
			}
		}
		#==========================================
		# Check for ignore-repos option
		#------------------------------------------
		if (defined $IgnoreRepos) {
			$xml -> ignoreRepositories ();
		}
		#==========================================
		# Check for set-repo option
		#------------------------------------------
		if (defined $SetRepository) {
			$xml -> setRepository (
				$SetRepositoryType,$SetRepository,
				$SetRepositoryAlias,$SetRepositoryPriority
			);
		}
		#==========================================
		# Check for add-repo option
		#------------------------------------------
		if (defined @AddRepository) {
			$xml -> addRepository (
				\@AddRepositoryType,\@AddRepository,
				\@AddRepositoryAlias,\@AddRepositoryPriority
			);
		}
		#==========================================
		# Validate repo types
		#------------------------------------------
		$xml -> setValidateRepositoryType();
		#==========================================
		# Initialize root system, use existing root
		#------------------------------------------
		$root = new KIWIRoot (
			$kiwi,$xml,$Upgrade,undef,
			"/base-system",$Upgrade,\@AddPackage,$BaseRoot,$BaseRootMode
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
			$kiwi,$Destination,$Migrate,\@Exclude,$Report,
			\@AddRepository,\@AddRepositoryType,
			\@AddRepositoryAlias,\@AddRepositoryPriority,
			$SetRepository,$SetRepositoryType,
			$SetRepositoryAlias,$SetRepositoryPriority
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
	# setup a splash initrd
	#------------------------------------------
	if (defined $SetupSplash) {
		$boot = new KIWIBoot ($kiwi,$SetupSplash);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		$boot -> setupSplash();
		$boot -> cleanTmp();
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Write a initrd/system image to USB stick
	#------------------------------------------
	if (defined $BootStick) {
		$kiwi -> info ("Creating boot USB stick from: $BootStick...\n");
		$boot = new KIWIBoot (
			$kiwi,$BootStick,$BootStickSystem,undef,
			$BootStickDevice
		);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootStick()) {
			$boot -> cleanTmp();
			my $code = kiwiExit (1); return $code;
		}
		$boot -> cleanTmp();
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create a boot Stick (USB)
	#------------------------------------------
	if (defined $BootUSB) {
		$kiwi -> info ("Creating boot USB stick from: $BootUSB...\n");
		$boot = new KIWIBoot ($kiwi,$BootUSB);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupInstallStick()) {
			my $code = kiwiExit (1); return $code;
		}
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create a boot CD (ISO)
	#------------------------------------------
	if (defined $BootCD) {
		$kiwi -> info ("Creating boot ISO from: $BootCD...\n");
		$boot = new KIWIBoot ($kiwi,$BootCD);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupInstallCD()) {
			my $code = kiwiExit (1); return $code;
		}
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create an install CD (ISO)
	#------------------------------------------
	if (defined $InstallCD) {
		$kiwi -> info ("Creating install ISO from: $InstallCD...\n");
		if (! defined $InstallCDSystem) {
			$kiwi -> error  ("No Install system image specified");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}
		$boot = new KIWIBoot ($kiwi,$InstallCD,$InstallCDSystem);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupInstallCD()) {
			$boot -> cleanTmp();
			my $code = kiwiExit (1); return $code;
		}
		$boot -> cleanTmp();
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create an install USB stick
	#------------------------------------------
	if (defined $InstallStick) {
		$kiwi -> info ("Creating install Stick from: $InstallStick...\n");
		if (! defined $InstallStickSystem) {
			$kiwi -> error  ("No Install system image specified");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}
		$boot = new KIWIBoot ($kiwi,$InstallStick,$InstallStickSystem);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupInstallStick()) {
			$boot -> cleanTmp();
			my $code = kiwiExit (1); return $code;
		}
		$boot -> cleanTmp();
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create a virtual disk image
	#------------------------------------------
	if (defined $BootVMDisk) {
		$kiwi -> info ("Creating boot VM disk from: $BootVMDisk...\n");
		if (! defined $BootVMSystem) {
			$kiwi -> error  ("No VM system image specified");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}
		qxx ( "file $BootVMSystem | grep -q 'gzip compressed data'" );
		my $code = $? >> 8;
		if ($code == 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("Can't use compressed VM system");
			$kiwi -> failed ();
			my $code = kiwiExit (1);
			return $code;
		}
		$boot = new KIWIBoot (
			$kiwi,$BootVMDisk,$BootVMSystem,
			$BootVMSize,undef,$BootVMFormat
		);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootDisk()) {
			$boot -> cleanTmp();
			my $code = kiwiExit (1); return $code;
		}
		$boot -> cleanTmp();
		$code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create crypted password
	#------------------------------------------
	if (defined $CreatePassword) {
		createPassword();
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
	my $kiwi = new KIWILog("tiny");
	#==========================================
	# get options and call non-root tasks
	#------------------------------------------
	my $result = GetOptions(
		"version"               => \&version,
		"logfile=s"             => \$LogFile,
		"prepare|p=s"           => \$Prepare,
		"add-profile=s"         => \@Profiles,
		"migrate|m=s"           => \$Migrate,
		"exclude|e=s"           => \@Exclude,
		"report"                => \$Report,
		"list|l"                => \&listImage,
		"create|c=s"            => \$Create,
		"testsuite=s"           => \$RunTestSuite,
		"test=s"                => \@RunTestName,
		"create-instsource=s"   => \$CreateInstSource,
		"ignore-repos"          => \$IgnoreRepos,
		"add-repo=s"            => \@AddRepository,
		"add-repotype=s"        => \@AddRepositoryType,
		"add-repoalias=s"       => \@AddRepositoryAlias,
		"add-repopriority=i"    => \@AddRepositoryPriority,
		"add-package=s"         => \@AddPackage,
		"set-repo=s"            => \$SetRepository,
		"set-repotype=s"        => \$SetRepositoryType,
		"set-repoalias=s"       => \$SetRepositoryAlias,
		"set-repopriority=i"    => \$SetRepositoryPriority,
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
		"installcd=s"           => \$InstallCD,
		"installcd-system=s"    => \$InstallCDSystem,
		"bootcd=s"              => \$BootCD,
		"bootusb=s"             => \$BootUSB,
		"installstick=s"        => \$InstallStick,
		"installstick-system=s" => \$InstallStickSystem,
		"strip|s"               => \$StripImage,
		"createpassword"        => \$CreatePassword,
		"isocheck"              => \$ISOCheck,
		"createhash=s"          => \$CreateHash,
		"setup-splash=s"        => \$SetupSplash,
		"list-profiles|i=s"     => \$ListProfiles,
		"force-new-root"        => \$ForceNewRoot,
		"base-root=s"           => \$BaseRoot,
		"base-root-mode=s"      => \$BaseRootMode,
		"nocolor"               => \$NoColor,
		"log-port=i"            => \$LogPort,
		"gzip-cmd=s"            => \$GzipCmd,
		"package-manager=s"     => \$PackageManager,
		"prebuiltbootimage=s"   => \$PrebuiltBootImage,
		"prechroot-call=s"      => \$PreChrootCall,
		"list-xmlinfo|x=s"      => \$listXMLInfo,
		"compress=s"            => \$Compress,
		"fs-blocksize=i"        => \$FSBlockSize,
		"fs-journalsize=i"      => \$FSJournalSize,
		"fs-inodesize=i"        => \$FSInodeSize,
		"partitioner=s"         => \$Partitioner,
		"help|h"                => \&usage,
		"<>"                    => \&usage
	);
	#========================================
	# non root task: create inst source
	#----------------------------------------
	if (defined $CreateInstSource) {
		createInstSource();
	}
	#==========================================
	# non root task: create md5 hash
	#------------------------------------------
	if (defined $CreateHash) {
		createHash();
	}
	#==========================================
	# non root task: Handle ListProfiles option 
	#------------------------------------------
	if (defined $ListProfiles) {
		listProfiles();
	}
	#==========================================
	# non root task: Handle listXMLInfo option
	#------------------------------------------
	if (defined $listXMLInfo) {
		listXMLInfo();
	}
	#==========================================
	# Check for root privileges
	#------------------------------------------
	if ($< != 0) {
		$kiwi -> error ("Only root can do this");
		$kiwi -> failed ();
		usage();
	}
	if ( $result != 1 ) {
		usage();
	}
	#==========================================
	# Check option combination/values
	#------------------------------------------
	if (
		(! defined $Prepare)            &&
		(! defined $Create)             &&
		(! defined $BootStick)          &&
		(! defined $InstallCD)          &&
		(! defined $Upgrade)            &&
		(! defined $SetupSplash)        &&
		(! defined $BootVMDisk)         &&
		(! defined $Migrate)            &&
		(! defined $ListProfiles)       &&
		(! defined $InstallStick)       &&
		(! defined $listXMLInfo)        &&
		(! defined $CreatePassword)     &&
		(! defined $BootCD)             &&
		(! defined $BootUSB)            &&
		(! defined $RunTestSuite)
	) {
		$kiwi -> error ("No operation specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $IgnoreRepos) && (defined $SetRepository)) {
		$kiwi -> error ("Can't use ignore repos together with set repos");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined @AddRepository) && (! defined @AddRepositoryType)) {
		$kiwi -> error ("No repository type specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $RootTree) && ($RootTree !~ /^\//)) {
		my $workingDir = qxx ( "pwd" ); chomp $workingDir;
		$RootTree = $workingDir."/".$RootTree;
	}
	if ((defined $Migrate) && (! defined $Destination)) {
		$kiwi -> error ("No migration destination directory specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if (defined $LogPort) {
		$kiwi -> info ("Setting log server port to: $LogPort");
		$LogServerPort = $LogPort;
		$kiwi -> done ();
	}
	if (defined $GzipCmd) {
		$kiwi -> info ("Setting gzip command to: $GzipCmd");
		$Gzip = $GzipCmd;
		$kiwi -> done ();
	}
	if ((defined $BaseRootMode) && (! defined $BaseRoot)) {
		$kiwi -> error ("base root mode specified but no base root tree");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;   
	}
	if ((defined $BaseRootMode) &&
		($BaseRootMode !~ /^copy$|^union$|^recycle$/)
	) {
		$kiwi -> error ("Invalid baseroot mode,allowed are copy|union|recycle");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $BaseRootMode) && ($BaseRootMode eq "recycle")) {
		if (defined $RootTree) {
			$kiwi -> warning ("--root ignored in recycle base root mode !");
			$kiwi -> skipped ();
		}
		$RootTree = $BaseRoot;
	}
	if ((defined $Compress) && ($Compress !~ /^yes$|^no$/)) {
		$kiwi -> error ("Invalid compress argument, expected yes|no");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $PreChrootCall) && (! -x $PreChrootCall)) {
		$kiwi -> error ("pre-chroot program: $PreChrootCall");
		$kiwi -> failed ();
		$kiwi -> error ("--> 1) no such file or directory\n");
		$kiwi -> error ("--> 2) and/or not in executable format\n");
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $BootStick) && (! defined $BootStickSystem)) {
		$kiwi -> error ("USB stick setup must specify a bootstick-system");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $BootVMDisk) && (! defined $BootVMSystem)) {
		$kiwi -> error ("Virtual Disk setup must specify a bootvm-system");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if (defined $Partitioner) {
		if (($Partitioner ne "fdisk") && ($Partitioner ne "parted")) {
			$kiwi -> error ("Invalid partitioner, expected fdisk|parted");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
	}
}

#==========================================
# usage
#------------------------------------------
sub usage {
	# ...
	# Explain the available options for this
	# image creation system
	# ---
	my $kiwi = new KIWILog("tiny");
	my $date = qxx ( "LANG=POSIX date -I" ); chomp $date;
	print "Linux KIWI setup  (image builder) ($date)\n";
	print "Copyright (c) 2007 - SUSE LINUX Products GmbH\n";
	print "\n";

	print "Usage:\n";
	print "  kiwi -l | --list\n";
	print "Image Preparation/Creation:\n";
	print "  kiwi -p | --prepare <image-path>\n";
	print "     [ --base-root <base-path> ]\n";
	print "     [ --base-root-mode <copy|union|recycle> ]\n";
	print "     [ --add-profile <profile-name> ]\n";
	print "  kiwi -c | --create  <image-root>\n";
	print "     [ --base-root <base-path> ]\n";
	print "     [ --base-root-mode <copy|union|recycle> ]\n";
	print "     [ --prebuiltbootimage <directory>]\n";
	print "     [ --isocheck ]\n";
	print "Image Upgrade:\n";
	print "  kiwi -u | --upgrade <image-root>\n";
	print "     [ --base-root <base-path> ]\n";
	print "System to Image migration:\n";
	print "  kiwi -m | --migrate <name> --destdir <destination-path>\n";
	print "     [ --exclude <directory> --exclude <...> ]\n";
	print "     [ --report ]\n";
	print "Image postprocessing modes:\n";
	print "  kiwi --bootstick <initrd> --bootstick-system <systemImage>\n";
	print "     [ --bootstick-device <device> ]\n";
	print "  kiwi --bootvm <initrd> --bootvm-system <systemImage>\n";
	print "     [ --bootvm-disksize <size> ]\n";
	print "     [ --bootvm-format <format> ]\n";
	print "  kiwi --bootcd  <initrd>\n";
	print "  kiwi --bootusb <initrd>\n";
	print "  kiwi --installcd <initrd>\n";
	print "     [ --installcd-system <vmx-system-image> ]\n";
	print "  kiwi --installstick <initrd>\n";
	print "     [ --installstick-system <vmx-system-image> ]\n";
	print "Helper Tools:\n";
	print "  kiwi --testsuite <image-root> [ --test name --test name ... ]\n";
	print "  kiwi --createpassword\n";
	print "  kiwi --createhash <image-path>\n";
	print "  kiwi --list-profiles <image-path>\n";
	print "  kiwi --list-xmlinfo <image-path> [--type <image-type>]\n";
	print "  kiwi --setup-splash <initrd>\n";
	print "Options:\n";
	print "--\n";
	print "  [ --createpassword ]\n";
	print "    Create a crypted password hash\n";
	print "\n";
	print "  [ --createhash <image-path> ]\n";
	print "    Sign your image description with a md5sum\n";
	print "\n";
	print "  [ -i | --list-profiles <image-path> ]\n";  
	print "    List the profile names of the image description if any\n";
	print "\n";
	print "  [ -x | --list-xmlinfo <image-path> ]\n";
	print "    List general information about the image description\n";
	print "\n"; 
	print "  [ --setup-splash <initrd> ]\n";
	print "    Create splash screen from the data inside the initrd\n";
	print "    and re-create the initrd with the splash screen attached\n";
	print "    to the initrd cpio archive. This enables the kernel\n";
	print "    to load the splash screen at boot time. If splashy is used\n";
	print "    only a link to the original initrd will be created\n";
	print "\n";
	print "  [ -d | --destdir <destination-path> ]\n";
	print "    Specify destination directory to store the image file(s)\n";
	print "    If not specified the the attribute <defaultdestination>\n";
	print "    is used. If no destination can be found an error occurs\n";
	print "\n";
	print "  [ -t | --type <image-type> ]\n";
	print "    Specify the output image type to use for this image\n";
	print "    The type must exist in the xml description\n";
	print "    By the default the primary type will be used. If there is\n";
	print "    no primary attribute set the first type entry of the\n";
	print "    preferences section is the primary type\n"; 
	print "    makes only sense in combination with --create\n";
	print "\n";
	print "  [ -r | --root <root-path> ]\n";
	print "    Setup the physical extend, chroot system below the\n";
	print "    given root-path path. If no --root option is given kiwi\n";
	print "    will search for the attribute defaultroot in the xml\n";
	print "    description. If no root directory is known a mktmp directory\n";
	print "    will be created and used as root directory\n";
	print "\n";
	print "  [ --base-root <base-path> ]\n";
	print "    Refers to an already prepared root tree. Kiwi will use\n";
	print "    this tree to skip the first stage of the prepare step\n"; 
	print "    and run the second stage directly\n";
	print "\n";
	print "  [ -s | --strip ]\n";
	print "    Strip shared objects and executables\n";
	print "    makes only sense in combination with --create\n";
	print "\n";
	print "  [ --add-repo <repo-path> --add-repotype <type> ]\n";
	print "    Add the given repository and type for this run of an\n";
	print "    image prepare/upgrade or migrate process.\n";
	print "    Multiple --add-repo/--add-repotype options are possible\n";
	print "    The change will not be written to the xml description\n";
	print "\n";
	print "  [ --(add|set)-repoalias <alias name> ]\n";
	print "    Alias name to be used for this repository. This is an\n";
	print "    optional free form text. If not set the source attribute\n";
	print "    value is used and builds the alias name by replacing\n";
	print "    each '/' with a '_'. An alias name should be set if the\n";
	print "    source argument doesn't really explain what this repository\n";
	print "    contains\n";
	print "\n";
	print "  [ --(add|set)-repoprio <number> ]\n";
	print "    Channel priority assigned to all packages available in\n";
	print "    this channel (0 if not set). If the exact same package\n";
	print "    is available in more than one channel, the highest\n";
	print "    priority is used\n";
	print "\n";
	print "  [ --ignore-repos ]\n";
	print "    Ignore all repositories specified so-far, in XML or\n";
	print "    otherwise.  This option should be used in conjunction\n";
	print "    with subsequent calls to --add-repo to specify\n";
	print "    repositories at the command-line that override previous\n";
	print "    specifications.\n";
	print "\n";
	print "  [ --set-repo <repo-path> [ --set-repotype <type> ]]\n";
	print "    set the given repository and optional type for the first\n";
	print "    repository entry within the xml description. The change\n";
	print "    will not be written to the xml file and is valid for this\n";
	print "    run of image prepare/upgrade or migrate process.\n";
	print "\n";
	print "  [ --add-package <package> ]\n";
	print "    Add the given package name to the list of image packages\n";
	print "    multiple --add-package options are possible. The change\n";
	print "    will not be written to the xml description\n";
	print "\n";
	print "  [ --logfile <filename> | terminal ]\n";
	print "    Write to the log file \`<filename>' instead of\n";
	print "    the terminal.\n";
	print "\n";
	print "  [ --gzip-cmd <cmd> ]\n";
	print "    Specify an alternate command to run when compressing boot\n";
	print "    and system images.  Command must accept gzip options.\n";
	print "\n";
	print "  [ --force-new-root ]\n";
	print "    Force creation of new root directory. If the directory\n";
	print "    already exists, it is deleted.\n";
	print "\n";
	print "  [ --log-port <port-number> ]\n";
	print "    Set the log server port. By default port 9000 is used\n";
	print "    If multiple kiwi processes runs on one system it's\n";
	print "    recommended to set the logging port per process\n";
	print "\n";
	print "  [ --prebuiltbootimage <directory> ]\n";
	print "    search in <directory> for pre-built boot images\n";
	print "\n";
	print "  [ --isocheck ]\n";
	print "    in case of an iso image the checkmedia program generates\n";
	print "    a md5sum into the iso header. If the --isocheck option is\n";
	print "    specified a new boot menu entry will be generated which\n";
	print "    allows to check this media\n";
	print "\n";
	print "  [ --testsuite <image-root> [ --test name --test name ... ]\n";
	print "    run test(s) on prepared image root tree.\n";
	print "    If additional name is omitted default set of tests will be\n";
	print "    used. Otherwise only provided tests will be executed\n";
	print "\n";
	print "  [ --package-manager <smart|zypper> ]\n";
	print "    set the package manager to use for this image. If set it\n";
	print "    will temporarly overwrite the value set in the xml\n";
	print "    description\n";
	print "\n";
	print "  [ --fs-blocksize <number> ]\n";
	print "    When calling kiwi in creation mode this option will set\n";
	print "    the block size in bytes. For ISO images with the old style\n";
	print "    ramdisk setup a blocksize of 4096 bytes is required\n";
	print "\n";
	print "  [ --fs-journalsize <number> ]\n";
	print "    When calling kiwi in creation mode this option will set\n";
	print "    the journal size in mega bytes for ext[23] based filesystems\n";
	print "    and in blocks if the reiser filesystem is used\n"; 
	print "\n";
	print "  [ --fs-inodesize <number> ]\n";
	print "    When calling kiwi in creation mode this option will set\n";
	print "    the inode size in bytes. This option has no effect if the\n";
	print "    reiser filesystem is used\n";
	print "\n";
	print "  [ --partitioner <fdisk|parted ]\n";
	print "    Select the tool to create partition tables. Supported are\n";
	print "    fdisk (sfdisk) and parted. By default fdisk is used\n";
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
	my $kiwi = new KIWILog("tiny");
	opendir (FD,$System);
	my @images = readdir (FD); closedir (FD);
	foreach my $image (@images) {
		if ($image =~ /^\./) {
			next;
		}
		if (-l "$System/$image") {
			next;
		}
		if (getControlFile ($System."/".$image)) {
			$kiwi -> info ($image);
			my $xml = new KIWIXML ( $kiwi,$System."/".$image);
			if (! $xml) {
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
# listProfiles
#------------------------------------------
sub listProfiles {
	# ...
	# list the available profiles in image
	# ---
	my $kiwi = new KIWILog("tiny");
	$kiwi -> info ("Reading image description [ListProfiles]...\n");
	my $xml  = new KIWIXML ($kiwi, $ListProfiles);
	if (! defined $xml) {
		exit 1;
	}
	my @profiles = $xml -> getProfiles ();
	if ((scalar @profiles) == 0) {
		$kiwi -> info ("No profiles available");
		$kiwi -> done ();
		exit 0;
	}
	foreach my $profile (@profiles) {
		my $name = $profile -> {name};
		my $desc = $profile -> {description};
		$kiwi -> info ("$name: [ $desc ]");
		$kiwi -> done ();
	}
	exit 0;
}

#==========================================
# listXMLInfo
#------------------------------------------
sub listXMLInfo {
	# ...
	# print information about the XML description. The
	# information listed here is for information only and
	# not specified in its format
	# ---
	my $kiwi = new KIWILog("tiny");
	$kiwi -> info ("Reading image description [ListXMLInfo]...\n");
	my $xml  = new KIWIXML ($kiwi,$listXMLInfo,undef,$SetImageType);
	if (! defined $xml) {
		exit 1;
	}
	my %type = %{$xml->getImageTypeAndAttributes()};
	#==========================================
	# print boot information of type section
	#------------------------------------------
	if (defined $type{boot}) {
		$kiwi -> info ("Boot Type: $type{type} @ $type{boot}\n");
	} else {
		$kiwi -> info ("Boot Type: $type{type}\n");
	}
	#==========================================
	# more to come...
	#------------------------------------------
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
	if ((defined $Survive) && ($Survive eq "yes")) {
		if ($code != 0) {
			return undef;
		}
		return $code;
	}
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	$kiwi -> setLogHumanReadable();
	if ($code != 0) {
		$kiwi -> printBackTrace();
		$kiwi -> printLogExcerpt();
		$kiwi -> error  ("KIWI exited with error(s)");
		$kiwi -> done ();
	} else {
		$kiwi -> info ("KIWI exited successfully");
		$kiwi -> done ();
	}
	if (! defined $LogFile) {
		my $rootLog = $kiwi -> getRootLog();
		if ((defined $rootLog) &&
			(-f $rootLog) && ($rootLog =~ /(.*)\..*\.screenrc\.log/)
		) {
			my $logfile = $1;
			$logfile = "$logfile.log";
			$kiwi -> info ("Complete logfile at: $logfile");
			qxx ("mv $rootLog $logfile 2>&1");
			$kiwi -> done ();
		}
	}
	$kiwi -> cleanSweep();
	exit $code;
}

#==========================================
# quit
#------------------------------------------
sub quit {
	# ...
	# signal received, exit safely
	# ---
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	} else {
		$kiwi -> reopenRootChannel();
	}
	$kiwi -> note ("\n*** $$: Received signal $_[0] ***\n");
	$kiwi -> cleanSweep();
	if (defined $CreatePassword) {
		system "stty echo";
	}
	if (defined $boot) {
		$boot -> cleanLoop ();
	}
	if (defined $root) {
		$root  -> cleanLock   ();
		$root  -> cleanManager();
		$root  -> cleanSource ();
		$root  -> cleanMount  ();
	}
	if (defined $image) {
		$image -> cleanMount ();
		$image -> restoreCDRootData ();
		$image -> restoreSplitExtend ();
	}
	if (defined $migrate) {
		$migrate -> cleanMount ();
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
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	my $rev  = "unknown";
	if (open FD,$Revision) {
		$rev = <FD>; close FD;
	}
	$kiwi -> info ("kiwi version v$Version SVN: Revision: $rev\n");
	$kiwi -> cleanSweep();
	exit 0;
}

#==========================================
# createPassword
#------------------------------------------
sub createPassword {
	# ...
	# Create a crypted password which can be used in the xml descr.
	# users sections. The crypt() call requires root rights because
	# dm-crypt is used to access the crypto pool
	# ----
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
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
	my $code = kiwiExit (0); return $code;
}

#==========================================
# createHash
#------------------------------------------
sub createHash {
	# ...
	# Sign your image description with a md5 sum. The created
	# file .checksum.md5 is clecked on runtime with the md5sum
	# command
	# ----
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	$kiwi -> info ("Creating MD5 sum for $CreateHash...");
	if (! -d $CreateHash) {
		$kiwi -> failed ();
		$kiwi -> error  ("Not a directory: $CreateHash: $!");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if (! getControlFile ($CreateHash)) {
		$kiwi -> failed ();
		$kiwi -> error  ("Not a kiwi description: no xml description found");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	my $cmd  = "find -L -type f | grep -v .svn | grep -v .checksum.md5";
	my $status = qxx (
		"cd $CreateHash && $cmd | xargs md5sum > .checksum.md5"
	);
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error  ("Failed creating md5 sum: $status: $!");
		$kiwi -> failed ();
	}
	$kiwi -> done();
	my $code = kiwiExit (0); return $code;
}

#==========================================
# checkType
#------------------------------------------
sub checkType {
	my (%type) = %{$_[0]};
	my $para   = "ok";
	#==========================================
	# check for required filesystem tool(s)
	#------------------------------------------
	if (defined $type{filesystem}) {
		my @fs = split (/,/,$type{filesystem});
		if ((defined $type{flags}) && ($type{flags} ne "")) {
			push (@fs,$type{flags});
		}
		foreach my $fs (@fs) {
			my %result = checkFileSystem ($fs);
			if (%result) {
				if (! $result{hastool}) {
					$kiwi -> error ("Can't find mkfs tool for: $result{type}");
					$kiwi -> failed ();
					return undef;
				}
			} else {
				$kiwi -> error ("Can't check filesystem attributes from: $fs");
				$kiwi -> failed ();
				return undef;
			}
		}
	}
	#==========================================
	# build and check KIWIImage method params
	#------------------------------------------
	SWITCH: for ($type{type}) {
		/^iso/ && do {
			if (! defined $type{boot}) {
				$kiwi -> error ("$type{type}: No boot image specified");
				$kiwi -> failed ();
				return undef;
			}
			$para = $type{boot};
			if ((defined $type{flags}) && ($type{flags} ne "")) {
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
			if (defined $type{boot}) {
				$para .= ":".$type{boot};
			}
			last SWITCH;
		};
		/^usb|vmx|oem|xen|pxe/ && do {
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
		/^ec2/ && do {
			if (defined $type{boot}) {
				$para = $type{boot};
			}
			last SWITCH;
		};
	}
	return $para;
}

#==========================================
# checkFSOptions
#------------------------------------------
sub checkFSOptions {
	# /.../
	# checks the $FS* option values and build an option
	# string for the relevant filesystems
	# ---
	my %result = ();
	foreach my $fs (keys %KnownFS) {
		my $blocksize;   # block size in bytes
		my $journalsize; # journal size in MB (ext) or blocks (reiser)
		my $inodesize;   # inode size in bytes (ext only)
		SWITCH: for ($fs) {
			#==========================================
			# EXT2 and EXT3
			#------------------------------------------
			/ext[32]/   && do {
				if ($FSBlockSize)   {$blocksize   = "-b $FSBlockSize"}
				if ($FSInodeSize)   {$inodesize   = "-I $FSInodeSize"}
				if ($FSJournalSize) {$journalsize = "-J size=$FSJournalSize"}
				last SWITCH;
			};
			#==========================================
			# reiserfs
			#------------------------------------------
			/reiserfs/  && do {
				if ($FSBlockSize)   {$blocksize   = "-b $FSBlockSize"}
				if ($FSJournalSize) {$journalsize = "-s $FSJournalSize"}
				last SWITCH;
			};
			# no options for this filesystem...
		};
		if (defined $inodesize) {
			$result{$fs} .= $inodesize." ";
		}
		if (defined $blocksize) {
			$result{$fs} .= $blocksize." ";
		}
		if (defined $journalsize) {
			$result{$fs} .= $journalsize." ";
		}
	}
	return %result;
}

#==========================================
# checkFileSystem
#------------------------------------------
sub checkFileSystem {
	# /.../
	# checks attributes of the given filesystem(s) and returns
	# a summary hash containing the following information
	# ---
	# $filesystem{hastool}  --> has the tool to create the filesystem
	# $filesystem{readonly} --> is a readonly filesystem
	# $filesystem{type}     --> what filesystem type is this
	# ---
	my $fs     = shift;
	my %result = ();
	if (defined $KnownFS{$fs}) {
		#==========================================
		# got a known filesystem type
		#------------------------------------------
		$result{type}     = $fs;
		$result{readonly} = $KnownFS{$fs}{ro};
		$result{hastool}  = 0;
		if (-x $KnownFS{$fs}{tool}) {
			$result{hastool} = 1;
		}
	} else {
		#==========================================
		# got a file, block special or something
		#------------------------------------------
		if (-e $fs) {
			my $data = qxx ("dd if=$fs bs=128k count=1 2>/dev/null | file -");
			my $code = $? >> 8;
			my $type;
			if ($code != 0) {
				$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
				return undef;
			}
			SWITCH: for ($data) {
				/ext3/      && do {
					$type = "ext3";
					last SWITCH;
				};
				/ext2/      && do {
					$type = "ext2";
					last SWITCH;
				};
				/ReiserFS/  && do {
					$type = "reiserfs";
					last SWITCH;
				};
				/Squashfs/  && do {
					$type = "squashfs";
					last SWITCH;
				};
				/CROMFS/    && do {
					$type = "cromfs";
					last SWITCH;
				};
				# unknown filesystem type use auto...
				$type = "auto";
			};
			$result{type}     = $type;
			$result{readonly} = $KnownFS{$type}{ro};
			$result{hastool}  = 0;
			if (defined $KnownFS{$type}{tool}) {
				if (-x $KnownFS{$type}{tool}) {
					$result{hastool} = 1;
				}
			}
		} else {
			$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
			return undef;
		}
	}
	return %result;
}

#==========================================
# getControlFile
#------------------------------------------
sub getControlFile {
	# /.../
	# This function receives a directory as parameter
	# and searches for a kiwi xml description in it.
	# ----
	my $dir    = shift;
	my $config = "$dir/$ConfigName";
	if (! -d $dir) {
		$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
		return undef;
	}
	if (-f $config) {
		return $config;
	}
	my @globsearch = glob ($dir."/*.kiwi");
	my $globitems  = @globsearch;
	if ($globitems == 0) {
		$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
		return undef;
	} elsif ($globitems > 1) {
		$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
		return undef;
	} else {
		$config = pop @globsearch;
	}
	return $config;
}

#==========================================
# createInstSource
#------------------------------------------
sub createInstSource {
	# /.../
	# create instsource requires the module "KIWICollect.pm".
	# If it is not available, the option cannot be used.
	# kiwi then issues a warning and exits.
	# ----
	$kiwi = new KIWILog("tiny");
	eval "require KIWICollect";
	if($@) {
		$kiwi->error("Module KIWICollect is not available!");
		my $code = kiwiExit (3);
		return $code;
	}
	else {
		$kiwi->info("Module KIWICollect loaded successfully...");
		$kiwi->done();
	}
	$kiwi -> info ("Reading image description [InstSource]...\n");
	my $xml = new KIWIXML ( $kiwi,$CreateInstSource );
	if (! defined $xml) {
		my $code = kiwiExit (1); return $code;
	}
	#==========================================
	# Initialize installation source tree
	#------------------------------------------
	my @root = $xml -> createTmpDirectory ( undef, $RootTree );
	my $root = $root[1];
	if (! defined $root) {
		$kiwi -> error ("Couldn't create instsource root");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	#==========================================
	# Create object...
	#----------------------------------------
	my $collect = new KIWICollect ( $kiwi, $xml, $root );
	if (! defined( $collect) ) {
		$kiwi -> error( "Unable to create KIWICollect module." );
		$kiwi -> failed ();
		my $code = kiwiExit( 1 ); return $code;
	}
	if (! defined( $collect -> Init () ) ) {
		$kiwi -> error( "Object initialisation failed!" );
		$kiwi -> failed ();
		my $code = kiwiExit( 1 ); return $code;
	}
	#==========================================
	# Call the *CENTRAL* method for it...
	#----------------------------------------
	if (! defined( $collect -> mainTask () ) ) {
		$kiwi -> error( "KIWICollect could not be invoked successfully." );
		$kiwi -> failed ();
		my $code = kiwiExit ( 1 ); return $code;
	}
	$kiwi->info( "KIWICollect completed successfully." );
	$kiwi->done();
	kiwiExit (0);
}

main();
