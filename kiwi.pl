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
our $Version       = "3.42";
our $Publisher     = "SUSE LINUX Products GmbH";
our $Preparer      = "KIWI - http://kiwi.berlios.de";
our $openSUSE      = "http://download.opensuse.org";
our @openSUSE      = ("distribution","repositories");
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
our $LogServerPort;    # configurable log server port
our $Gzip;             # configurable gzip command
if (! defined $LogServerPort) {
	$LogServerPort = "off";
}
if (! defined $Gzip) {
	$Gzip = "gzip -9";
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
our $KSplit   = $BasePath."/modules/KIWISplit.txt";
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
$KnownFS{dmsquash}{tool}  = "/usr/bin/mksquashfs";
$KnownFS{unified}{tool}   = "/usr/bin/mksquashfs";
$KnownFS{compressed}{tool}= "/usr/bin/mksquashfs";
$KnownFS{reiserfs}{tool}  = "/sbin/mkreiserfs";
$KnownFS{cpio}{tool}      = "/usr/bin/cpio";
$KnownFS{ext3}{ro}        = 0;
$KnownFS{ext2}{ro}        = 0;
$KnownFS{squashfs}{ro}    = 1;
$KnownFS{dmsquash}{ro}    = 1;
$KnownFS{unified}{ro}     = 1;
$KnownFS{compressed}{ro}  = 1;
$KnownFS{reiserfs}{ro}    = 0;
$KnownFS{cpio}{ro}        = 0;

#============================================
# Globals
#--------------------------------------------
our $Build;                 # run prepare and create in one step
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
our @RemovePackage;         # remove package by adding them to the remove list
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
our $FSNumInodes;           # filesystem max inodes
our $Verbosity = 0;         # control the verbosity level
our $TargetArch;            # target architecture -> writes zypp.conf
our $CheckKernel;           # check for kernel matches in boot and system image
our $LVM;                   # use LVM partition setup for virtual disk
our $Debug;                 # activates the internal stack trace output
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
	# Prepare and Create in one step
	#----------------------------------------
	if (defined $Build) {
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
		# Setup prepare 
		#------------------------------------------
		$main::Prepare = $Build;
		$main::RootTree= $Destination."/image-root";
		$main::Survive = "yes";
		$main::ForceNewRoot = 1;
		undef $main::Build;
		if (! defined main::main()) {
			$main::Survive = "default";
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Setup create 
		#------------------------------------------
		undef $main::Prepare;
		undef $main::ForceNewRoot;
		$main::Survive = "default";
		$main::Create = $RootTree;
		main::main();
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
		my %type = %{$xml->getImageTypeAndAttributes()};
		if (! @Profiles) {
			if ($type{"type"} eq "cpio") {
				if ($type{bootprofile}) {
					push @Profiles, split (/,/,$type{bootprofile});
				}
				if ($type{bootkernel}) {
					push @Profiles, split (/,/,$type{bootkernel});
				}
			}
		}
		#==========================================
		# Check for bootkernel in xml descr.
		#------------------------------------------		
		if ($type{"type"} eq "cpio") {
			my %phash = ();
			my $found = 0;
			my @pname = $xml -> getProfiles();
			foreach my $profile (@pname) {
				my $name = $profile -> {name};
				my $descr= $profile -> {description};
				if ($descr =~ /KERNEL:/) {
					$phash{$name} = $profile -> {description};
				}
			}
			foreach my $profile (@Profiles) {
				if ($phash{$profile}) {
					# /.../
					# ok, a kernel from the profile list is
					# already selected
					# ----
					$found = 1;
					last;
				}
			}
			if (! $found) {
				# /.../
				# no kernel profile selected use standard (std)
				# profile which is defined in each boot image
				# description
				# ----
				push @Profiles, "std";
			}
			if (! $xml -> checkProfiles (\@Profiles)) {
				my $code = kiwiExit (1); return $code;
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
		# Check for del-package option
		#------------------------------------------
		if (defined @RemovePackage) {
			$xml -> addRemovePackages (@RemovePackage);
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
			"/base-system",undef,undef,undef,$BaseRoot,
			$BaseRootMode,$TargetArch
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
		# Check the tree first...
		#------------------------------------------
		if (-f "$Create/.broken") {
			$kiwi -> error  ("Image root tree $Create is broken");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Cleanup the tree according to prev runs
		#------------------------------------------
		if (-f "$Create/rootfs.tar") {
			qxx ("rm -f $Create/rootfs.tar");
		}
		if (-f "$Create/recovery.tar.gz") {
			qxx ("rm -f $Create/recovery.tar.*");
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
			"sed -i -e 's#kiwi_type=.*#kiwi_type=\"$type\"#' $Create/.profile"
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
		# Check tool set
		#------------------------------------------
		my %type = %{$xml->getImageTypeAndAttributes()};
		my $para = checkType ( \%type );
		if (! defined $para) {
			if (defined $BaseRoot) {
				$overlay -> resetOverlay();
			}
			my $code = kiwiExit (1); return $code;
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
		#==========================================
		# Check for packages updates if needed
		#------------------------------------------
		my @addonList;   # install this packages
		my @deleteList;  # remove this packages
		my %replace;
		my %replids;
		$xml -> getBaseList();
		%replace = $xml -> getReplacePackageHash();
		%replids = getReplaceIDHash (\%replace,\%replids);
		$xml -> getInstallList();
		%replace = $xml -> getReplacePackageHash();
		%replids = getReplaceIDHash (\%replace,\%replids);
		if ($type{type} eq "vmx") {
			$kiwi -> info ("Creating VMware package list");
			@addonList = $xml -> getVMwareList();
			%replace = $xml -> getReplacePackageHash();
			%replids = getReplaceIDHash (\%replace,\%replids);
			$kiwi -> done();
		}
		if ($type{type} eq "xen") {
			$kiwi -> info ("Creating Xen package list");
			@addonList = $xml -> getXenList();
			%replace = $xml -> getReplacePackageHash();
			%replids = getReplaceIDHash (\%replace,\%replids);
			$kiwi -> done();
		}
		if (%replids) {
			my %add = ();
			my %del = ();
			foreach my $id (keys %replids) {
				foreach my $new (keys %{$replids{$id}}) {
					$del{$replids{$id}{$new}} = 1;
					$add{$new} = 1;
				}
			}
			foreach my $del (keys %del) {
				if (defined $add{$del}) {
					undef $add{$del};
				}
			}
			push @addonList, keys %add;
			push @deleteList,keys %del;
		}
		if ((@addonList) || (@deleteList)) {
			$kiwi -> info ("Image update:");
			if (@addonList) {
				$kiwi -> info ("--> Install/Update: @addonList\n");
			}
			if (@deleteList) {
				$kiwi -> info ("--> Remove: @deleteList\n");
			}
			$main::Survive = "yes";
			$main::Upgrade = $Create;
			@main::AddPackage    = @addonList;
			@main::RemovePackage = @deleteList;
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
			/^dmsquash/ && do {
				$ok = $image -> createImageDMSquashExt3 ();
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
				"/base-system",$RunTestSuite,undef,undef,$BaseRoot,
				$BaseRootMode,$TargetArch
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
			$kiwi,$xml,$xml,$RunTestSuite,
			$xml->getPackageManager(),$TargetArch
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
			"/base-system",$Upgrade,\@AddPackage,\@RemovePackage,
			$BaseRoot,$BaseRootMode,$TargetArch
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
			$BootStickDevice,undef,$LVM
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
			$BootVMSize,undef,$BootVMFormat,$LVM
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
		"v|verbose+"            => \$Verbosity,
		"logfile=s"             => \$LogFile,
		"build|b=s"             => \$Build,
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
		"del-package=s"         => \@RemovePackage,
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
		"fs-maxinodes=i"        => \$FSNumInodes,
		"partitioner=s"         => \$Partitioner,
		"target-arch=s"         => \$TargetArch,
		"check-kernel"          => \$CheckKernel,
		"lvm"                   => \$LVM,
		"debug"                 => \$Debug,
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
		(! defined $Build)              &&
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
	if ((defined $Build) && (! defined $Destination)) {
		$kiwi -> error  ("No destination directory specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if (defined $listXMLInfo) {
		listXMLInfo();
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
	my $date = qxx ( "bash -c 'LANG=POSIX date -I'" ); chomp $date;
	print "Linux KIWI setup  (image builder) ($date)\n";
	print "Copyright (c) 2007 - SUSE LINUX Products GmbH\n";
	print "\n";

	print "Usage:\n";
	print "    kiwi -l | --list\n";
	print "Image Creation in one step:\n";
	print "    kiwi -b | --build <image-path> -d <destination>\n";
	print "Image Preparation/Creation in two steps:\n";
	print "    kiwi -p | --prepare <image-path>\n";
	print "       [ --root <image-root> ]\n";
	print "    kiwi -c | --create  <image-root> -d <destination>\n";
	print "       [ --type <image-type> ]\n";
	print "Image Upgrade:\n";
	print "    kiwi -u | --upgrade <image-root>\n";
	print "       [ --add-package <name> ]\n";
	print "System to Image migration:\n";
	print "    kiwi -m | --migrate <name> --destdir <destination-path>\n";
	print "       [ --exclude <directory> --exclude <...> ]\n";
	print "       [ --report ]\n";
	print "Image postprocessing modes:\n";
	print "    kiwi --bootstick <initrd> --bootstick-system <systemImage>\n";
	print "       [ --bootstick-device <device> ]\n";
	print "    kiwi --bootvm <initrd> --bootvm-system <systemImage>\n";
	print "       [ --bootvm-disksize <size> ]\n";
	print "       [ --bootvm-format <format> ]\n";
	print "    kiwi --bootcd  <initrd>\n";
	print "    kiwi --bootusb <initrd>\n";
	print "    kiwi --installcd <initrd>\n";
	print "       [ --installcd-system <vmx-system-image> ]\n";
	print "    kiwi --installstick <initrd>\n";
	print "       [ --installstick-system <vmx-system-image> ]\n";
	print "Installation source creation:\n";
	print "    kiwi --root <targetpath> --create-instsource <config>\n";
	print "       [ -v|--verbose <1|2|3> ]\n";
	print "Testsuite:\n";
	print "    kiwi --testsuite <image-root> \n";
	print "       [ --test name --test name ... ]\n";
	print "Helper Tools:\n";
	print "    kiwi --createpassword\n";
	print "    kiwi --createhash <image-path>\n";
	print "    kiwi --list-profiles <image-path>\n";
	print "    kiwi --list-xmlinfo <image-path> [--type <image-type>]\n";
	print "    kiwi --setup-splash <initrd>\n";
	print "\n";

	print "Global Options:\n";
	print "    [ --base-root <base-path> ]\n";
	print "      Use an already prepared root tree as reference.\n";
	print "\n";
	print "    [ --base-root-mode <copy|union|recycle> ]\n";
	print "      Specifies the overlay mode for the base root tree.\n";
	print "      This can be either a copy, a union or the tree itself\n";
	print "\n";
	print "    [ --add-profile <profile-name> ]\n";
	print "      Use the specified profile.\n";
	print "\n";
	print "    [ --set-repo <URL> ]\n";
	print "      Set/Overwrite repo URL for the first listed repo.\n";
	print "\n";
	print "    [ --set-repoalias <name> ]\n";
	print "      Set/Overwrite alias name for the first listed repo.\n";
	print "\n";
	print "    [ --set-repoprio <number> ]\n";
	print "      Set/Overwrite priority for the first listed repo.\n";
	print "      Works with the smart packagemanager only\n";
	print "\n";
	print "    [ --set-repotype <type> ]\n";
	print "      Set/Overwrite repo type for the first listed repo.\n";
	print "\n";
	print "    [ --add-repo <repo-path> --add-repotype <type> ]\n";
	print "      [ --add-repotype <type> ]\n";
	print "      [ --add-repoalias <name> ]\n";
	print "      [ --add-repoprio <number> ]\n";
	print "      Add the repository to the list of repos.\n";
	print "\n";
	print "    [ --ignore-repos ]\n";
	print "      Ignore all repos specified so-far, in XML or otherwise.\n";
	print "\n";
	print "    [ --logfile <filename> | terminal ]\n";
	print "      Write to the log file \`<filename>'\n";
	print "\n";
	print "    [ --gzip-cmd <cmd> ]\n";
	print "      Specify an alternate gzip command\n";
	print "\n";
	print "    [ --log-port <port-number> ]\n";
	print "      Set the log server port. By default port 9000 is used.\n";
	print "\n";
	print "    [ --package-manager <smart|zypper> ]\n";
	print "      Set the package manager to use for this image.\n";
	print "\n";
	print "    [ -A | --target-arch <i586|x86_64|armv5tel|ppc> ]\n";
	print "      Set a special target-architecture. This overrides the \n";
	print "      used architecture for the image-packages in zypp.conf.\n";
	print "      When used with smart this option doesn't have any effect.\n";
	print "\n";
	print "    [ --debug ]\n";
	print "      Prints a stack trace in case of internal errors\n";
	print "\n";
	print "    [ -v | --verbose <1|2|3> ]\n";
	print "      Controls the verbosity level for the instsource module\n";
	print "\n";

	print "Image Preparation Options:\n";
	print "    [ -r | --root <image-root> ]\n";
	print "      Use the given directory as new image root path\n";
	print "\n";
	print "    [ --force-new-root ]\n";
	print "      Force creation of new root directory. If the directory\n";
	print "      already exists, it is deleted.\n";
	print "\n";

	print "Image Upgrade/Preparation Options:\n";
	print "    [ --add-package <package> ]\n";
	print "      Adds the given package name to the list of image packages.\n";
	print "\n";
	print "    [ --del-package <package> ]\n";
	print "      Removes the given package by adding it the list of packages\n";
	print "      to become removed.\n";
	print "\n";

	print "Image Creation Options:\n";
	print "    [ -d | --destdir <destination-path> ]\n";
	print "      Specify destination directory to store the image file(s)\n";
	print "\n";
	print "    [ -t | --type <image-type> ]\n";
	print "      Specify the output image type. The selected type must be\n";
	print "      part of the XML description\n";
	print "\n";
	print "    [ -s | --strip ]\n";
	print "      Strip shared objects and executables.\n";
	print "\n";
	print "    [ --prebuiltbootimage <directory> ]\n";
	print "      search in <directory> for pre-built boot images\n";
	print "\n";
	print "    [ --isocheck ]\n";
	print "      in case of an iso image the checkmedia program generates\n";
	print "      a md5sum into the iso header. If the --isocheck option is\n";
	print "      specified a new boot menu entry will be generated which\n";
	print "      allows to check this media\n";
	print "\n";
	print "    [ --lvm ]\n";
	print "      use the logical volume manager for disk images\n";
	print "\n";
	print "    [ --fs-blocksize <number> ]\n";
	print "      Set the block size in Bytes. For ramdisk based ISO images\n";
	print "      a blocksize of 4096 bytes is required\n";
	print "\n";
	print "    [ --fs-journalsize <number> ]\n";
	print "      Set the journal size in MB for ext[23] based filesystems\n";
	print "      and in blocks if the reiser filesystem is used\n"; 
	print "\n";
	print "    [ --fs-inodesize <number> ]\n";
	print "      Set the inode size in Bytes. This option has no effect\n";
	print "      if the reiser filesystem is used\n";
	print "\n";
	print "    [ --fs-maxinodes <number> ]\n";
	print "      Set the maximum number of inodes. This option has no effect\n";
	print "      if the reiser filesystem is used\n";
	print "\n";
	print "    [ --partitioner <fdisk|parted> ]\n";
	print "      Select the tool to create partition tables. Supported are\n";
	print "      fdisk (sfdisk) and parted. By default fdisk is used\n";
	print "\n";
	print "    [ --check-kernel ]\n";
	print "      Activates check for matching kernels between boot and\n";
	print "      system image. The kernel check also tries to fix the boot\n";
	print "      image if no matching kernel was found.\n";
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
	my %type = %{$xml->getImageTypeAndAttributes()};
	#==========================================
	# print boot information of type section
	#------------------------------------------
	if (defined $type{boot}) {
		$kiwi -> info ("Primary image type: $type{type} @ $type{boot}\n");
	} else {
		$kiwi -> info ("Primary image type: $type{type}\n");
	}
	#==========================================
	# print repo information
	#------------------------------------------
	foreach my $url (@{$xml->{urllist}}) {
		$kiwi -> info ("Source URL: $url\n");
	}
	#==========================================
	# print install size information
	#------------------------------------------
	my ($meta,$delete) = $xml -> getInstallSize();
	my %meta = %{$meta};
	my $size = 0;
	foreach my $p (keys %meta) {
		$size += $meta{$p};
	}
	if ($size > 0) {
		$kiwi -> info ("Install size for root tree: $size kB\n");
	}
	#==========================================
	# print deletion size information
	#------------------------------------------
	$size = 0;
	if ($delete) {
		foreach my $del (@{$delete}) {
			if ($meta{$del}) {
				$size += $meta{$del};
			}
		}
	}
	if ($size > 0) {
		$kiwi -> info ("Deletion size for root tree; $size kB\n");
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
	#==========================================
	# Survive because kiwi called itself
	#------------------------------------------
	if ((defined $Survive) && ($Survive eq "yes")) {
		if ($code != 0) {
			return undef;
		}
		if ($root) {
			$root -> cleanBroken();
		}
		return $code;
	}
	#==========================================
	# Really exit kiwi now...
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	$kiwi -> setLogHumanReadable();
	if ($code != 0) {
		if (defined $Debug) {
			$kiwi -> printBackTrace();
		}
		if ($root) {
			$root -> copyBroken();
		}
		$kiwi -> printLogExcerpt();
		$kiwi -> error  ("KIWI exited with error(s)");
		$kiwi -> done ();
	} else {
		if ($root) {
			$root -> cleanBroken();
		}
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
	$kiwi -> setLogHumanReadable();
	$kiwi -> cleanSweep();
	if (defined $CreatePassword) {
		system "stty echo";
	}
	if (defined $boot) {
		$boot -> cleanLoop ();
	}
	if (defined $root) {
		$root  -> copyBroken  ();
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
	$kiwi -> info ("kiwi version v$Version\n");
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
# getReplaceIDHash
#------------------------------------------
sub getReplaceIDHash {
	# ...
	# takes the result of getReplacePackageHash() hash and
	# turns it into a new hash. The function appends
	# the new data to an optionally given hash variable
	# as second argument and returns the result hash
	# ---
	my %hash   = %{$_[0]};
	my %result = %{$_[1]};
	foreach my $key (keys %hash) {
		my @id = ($key,$hash{$key});
		my $id = join (".",sort @id);
		$result{$id}{$key} = $hash{$key};
	}
	return %result;
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
	if ((defined $type{filesystem}) || (defined $type{flags})) {
		my @fs = ();
		if (defined $type{filesystem}) {
			@fs = split (/,/,$type{filesystem});
		}
		if ((defined $type{flags}) && ($type{flags} ne "")) {
			push (@fs,$type{flags});
		}
		foreach my $fs (@fs) {
			my %result = checkFileSystem ($fs);
			if (%result) {
				if (! $result{hastool}) {
					my $tool = $KnownFS{$result{type}}{tool};
					$kiwi -> error ("Can't find $tool tool for: $result{type}");
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
		my $numinodes;   # maximum number of inodes (ext only)
		SWITCH: for ($fs) {
			#==========================================
			# EXT2 and EXT3
			#------------------------------------------
			/ext[32]/   && do {
				if ($FSBlockSize)   {$blocksize   = "-b $FSBlockSize"}
				if ($FSInodeSize)   {$inodesize   = "-I $FSInodeSize"}
				if ($FSJournalSize) {$journalsize = "-J size=$FSJournalSize"}
 				if ($FSNumInodes)   {$numinodes   = "-N $FSNumInodes"}
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
		if (defined $numinodes) {
			$result{$fs} .= $numinodes." ";
		}
	}
	return %result;
}

#==========================================
# mountLoop
#------------------------------------------
sub mountLoop {
	# /.../
	# implements a loop mount function for all supported
	# file system types
	# ---
	my $file = shift;
	my $dest = shift;
	my $type = shift;
	my $status = qxx ("mount -t $type -o loop $file $dest 2>&1");
	my $result = $? >> 8;
	if ($result != 0) {
		$kiwi -> error ("Failed to loop mount $file to: $dest: $status");
		$kiwi -> failed ();
		return undef;
	}
	if (-f $dest."/fsdata.ext3") {
		$type = "ext3";
		$file = $dest."/fsdata.ext3";
		$status = qxx ("mount -t $type -o loop $file $dest 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount $file to: $dest: $status");
			$kiwi -> failed ();
			return undef;
		}
	}
	return $dest;
}

#==========================================
# umountLoop
#------------------------------------------
sub umountLoop {
	# /.../
	# implements an umount function for filesystems mounted
	# via mountFileSystemLoop. The same mount point could be
	# used twice therefore we umount two times to be safe
	# ---
	my $dest = shift;
	my $status = qxx ("umount $dest && umount $dest 2>&1");
	return $dest;
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
	$kiwi -> deactivateBackTraceOutput();
	my $mod = "KIWICollect";
	eval "require $mod";
	if($@) {
		$kiwi->error("Module <$mod> is not available!");
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
	my $collect = new KIWICollect ( $kiwi, $xml, $root, $Verbosity );
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
		$kiwi -> warning( "KIWICollect could not be invoked successfully." );
		$kiwi -> skipped ();
		my $code = kiwiExit ( 0 ); return $code;
	}
	$kiwi->info( "KIWICollect completed successfully." );
	$kiwi->done();
	kiwiExit (0);
}

main();
