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
use File::Basename;
use KIWIQX qw (qxx);
use Carp qw (cluck);
use Getopt::Long;
use File::Spec;
use KIWICommandLine;
use KIWIRoot;
use KIWIXML;
use KIWILocator;
use KIWILog;
use KIWIImage;
use KIWIBoot;
use KIWIMigrate;
use KIWIOverlay;
use KIWIQX;
use KIWIRuntimeChecker;
use KIWIImageFormat;
use KIWIXMLInfo;
use KIWIXMLValidator;

#============================================
# UTF-8 for output to stdout
#--------------------------------------------
binmode(STDOUT, ":utf8");

#============================================
# Globals (Version)
#--------------------------------------------
our $Version       = "4.85.97";
our $Publisher     = "SUSE LINUX Products GmbH";
our $Preparer      = "KIWI - http://kiwi.berlios.de";
our $ConfigFile    = "$ENV{'HOME'}/.kiwirc";
our $ConfigName    = "config.xml";
our $Partitioner   = "parted";
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
our $Gzip;             # configurable gzip command
our $LogServerPort;    # configurable log server port
our $LuksCipher;       # stored luks passphrase
our $System;           # configurable baes kiwi image desc. path
our @UmountStack;      # command list to umount
if ( ! defined $BasePath ) {
	$BasePath = "/usr/share/kiwi";
}
if (! defined $Gzip) {
	$Gzip = "gzip -9";
}
if (! defined $LogServerPort) {
	$LogServerPort = "off";
}
if ( ! defined $System ) {
	$System  = $BasePath."/image";
}
our $Tools    = $BasePath."/tools";
our $Schema   = $BasePath."/modules/KIWISchema.rng";
our $SchemaTST= $BasePath."/modules/KIWISchemaTest.rng";
our $KConfig  = $BasePath."/modules/KIWIConfig.sh";
our $KMigrate = $BasePath."/modules/KIWIMigrate.txt";
our $KRegion  = $BasePath."/modules/KIWIEC2Region.txt";
our $KMigraCSS= $BasePath."/modules/KIWIMigrate.tgz";
our $KSplit   = $BasePath."/modules/KIWISplit.txt";
our $repoURI  = $BasePath."/modules/KIWIURL.txt";
our $Revision = $BasePath."/.revision";
our $TestBase = $BasePath."/tests";
our $SchemaCVT= $BasePath."/xsl/master.xsl";
our $Pretty   = $BasePath."/xsl/print.xsl";
our $InitCDir = "/var/cache/kiwi/image";

#==========================================
# Globals (Supported filesystem names)
#------------------------------------------
our %KnownFS;
our $locator = new KIWILocator();
$KnownFS{ext4}{tool}      = $locator -> getExecPath("mkfs.ext4");
$KnownFS{ext3}{tool}      = $locator -> getExecPath("mkfs.ext3");
$KnownFS{ext2}{tool}      = $locator -> getExecPath("mkfs.ext2");
$KnownFS{squashfs}{tool}  = $locator -> getExecPath("mksquashfs");
$KnownFS{clicfs}{tool}    = $locator -> getExecPath("mkclicfs");
$KnownFS{clic}{tool}      = $locator -> getExecPath("mkclicfs");
$KnownFS{unified}{tool}   = $locator -> getExecPath("mksquashfs");
$KnownFS{compressed}{tool}= $locator -> getExecPath("mksquashfs");
$KnownFS{reiserfs}{tool}  = $locator -> getExecPath("mkreiserfs");
$KnownFS{btrfs}{tool}     = $locator -> getExecPath("mkfs.btrfs");
$KnownFS{xfs}{tool}       = $locator -> getExecPath("mkfs.xfs");
$KnownFS{cpio}{tool}      = $locator -> getExecPath("cpio");
$KnownFS{ext3}{ro}        = 0;
$KnownFS{ext4}{ro}        = 0;
$KnownFS{ext2}{ro}        = 0;
$KnownFS{squashfs}{ro}    = 1;
$KnownFS{clicfs}{ro}      = 1;
$KnownFS{clic}{ro}        = 1;
$KnownFS{unified}{ro}     = 1;
$KnownFS{compressed}{ro}  = 1;
$KnownFS{reiserfs}{ro}    = 0;
$KnownFS{btrfs}{ro}       = 0;
$KnownFS{xfs}{ro}         = 0;
$KnownFS{cpio}{ro}        = 0;

#============================================
# Globals
#--------------------------------------------
our $Build;                 # run prepare and create in one step
our $ArchiveImage;          # archive image results into a tarball
our $Prepare;               # control XML file for building chroot extend
our $Create;                # image description for building image extend
our $CheckConfig;           # Configuration file to check
our $InitCache;             # create image cache(s) from given description
our $CreateInstSource;      # create installation source from meta packages
our $Upgrade;               # upgrade physical extend
our $Destination;           # destination directory for logical extends
our $LogFile;               # optional file name for logging
our $RootTree;              # optional root tree destination
our $Survive;               # if set to "yes" don't exit kiwi
our $BootVMSystem;          # system image to be copied on a VM disk
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
our @AddRepository;         # add repository for building physical extend
our @AddRepositoryType;     # add repository type
our @AddRepositoryAlias;    # alias name for the repository
our @AddRepositoryPriority; # priority for the repository
our @AddPackage;            # add packages to the image package list
our @AddPattern;            # add patterns to the image package list
our $ImageCache;            # build an image cache for later re-use
our @RemovePackage;         # remove package by adding them to the remove list
our $IgnoreRepos;           # ignore repositories specified so far
our $SetRepository;         # set first repository for building physical extend
our $SetRepositoryType;     # set firt repository type
our $SetRepositoryAlias;    # alias name for the repository
our $SetRepositoryPriority; # priority for the repository
our $SetImageType;          # set image type to use, default is primary type
our $Migrate;               # migrate running system to image description
our @Exclude;               # exclude directories in migrate search
our @Skip;                  # skip this package in migration mode
our @Profiles;              # list of profiles to include in image
our @ProfilesOrig;          # copy of original Profiles option value 
our $ForceNewRoot;          # force creation of new root directory
our $CacheRoot;             # Cache file set via selectCache()
our $CacheRootMode;         # Cache mode set via selectCache()
our $NoColor;               # do not used colored output (done/failed messages)
our $LogPort;               # specify alternative log server port
our $GzipCmd;               # command to run to gzip things
our $PrebuiltBootImage;     # directory where a prepared boot image may be found
our $PreChrootCall;         # program name called before chroot switch
our $CreatePassword;        # create crypted password
our $ISOCheck;              # create checkmedia boot entry
our $FSBlockSize;           # filesystem block size
our $FSInodeSize;           # filesystem inode size
our $FSJournalSize;         # filesystem journal size
our $FSMaxMountCount;       # filesystem (ext2-4) max mount count between checks
our $FSCheckInterval;       # filesystem (ext2-4) max interval between fs checks
our $FSInodeRatio;          # filesystem bytes/inode ratio
our $FSMinInodes;           # filesystem min inodes
our $Verbosity = 0;         # control the verbosity level
our $TargetArch;            # target architecture -> writes zypp.conf
our $CheckKernel;           # check for kernel matches in boot and system image
our $Clone;                 # clone existing image description
our $LVM;                   # use LVM partition setup for virtual disk
our $Debug;                 # activates the internal stack trace output
our $GrubChainload;         # install grub loader in first partition not MBR
our $MigrateNoFiles;        # migrate: don't create overlay files
our $MigrateNoTemplate;     # migrate: don't create image description template
our $Convert;               # convert image into given format/configuration
our $Format;                # format to convert to, vmdk, ovf, etc...
our $defaultAnswer;         # default answer to any questions
our $targetDevice;          # alternative device instead of a loop device
our $targetStudio;          # command to run to create nodes for SuSE Studio
our %XMLChangeSet;          # internal data set for update of XML objects
our $ImageDescription;      # uniq path to image description due to caller opts
our $RecycleRoot;           # use existing root directory incl. contents
our $FatStorage;            # specify size of fat partition if syslinux is used
our $cmdL;                  # command line storage object
our $kiwi;                  # global logging handler object
our $MBRID;                 # custom mbrid value
our $ListXMLInfo;           # list XML information

#============================================
# Globals
#--------------------------------------------
my $root;       # KIWIRoot  object for installations
my $image;      # KIWIImage object for logical extends
my $boot;       # KIWIBoot  object for logical extends
my $migrate;    # KIWIMigrate object for system to image migration

#============================================
# createDirInteractive
#--------------------------------------------
sub createDirInteractive {
	my $kiwi = shift;
	my $targetDir = shift;
	if (! -d $targetDir) {
		my $prefix = $kiwi -> getPrefix (1);
		my $answer = (defined $defaultAnswer) ? "yes" : "unknown";
		$kiwi -> info ("Destination: $Destination doesn't exist\n");
		while ($answer !~ /^yes$|^no$/) {
			print STDERR $prefix,
				"Would you like kiwi to create it [yes/no] ? ";
			chomp ($answer = <>);
		}
		if ($answer eq "yes") {
			qxx ("mkdir -p $Destination");
			return 1;
		}
	} else {
		# Directory exists
		return 1;
	}
	# Directory does not exist and user did
	# not request dir creation.
	return undef;
}

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
		# Create destdir if needed
		#------------------------------------------
		my $dirCreated = createDirInteractive($kiwi, $Destination);
		if (! defined $dirCreated) {
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Setup prepare 
		#------------------------------------------
		$main::Prepare = $Build;
		$main::RootTree= $Destination."/build/image-root";
		$main::Survive = "yes";
		$main::ForceNewRoot = 1;
		undef $main::Build;
		mkdir $Destination."/build";
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
	# Create image cache(s)
	#----------------------------------------
	if (defined $InitCache) {
		#==========================================
		# Process system image description
		#------------------------------------------
		$kiwi -> info ("Reading image description [Cache]...\n");
		my $xml = new KIWIXML (
			$kiwi,$InitCache,undef,\@Profiles
		);
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		my $pkgMgr = $cmdL -> getPackageManager();
		if ($pkgMgr) {
			$xml -> setPackageManager($pkgMgr);
		}
		my %type = %{$xml->getImageTypeAndAttributes()};
		#==========================================
		# Create cache(s)...
		#------------------------------------------
		if (! defined $ImageCache) {
			$ImageCache = $main::InitCDir;
		}
		my $cacheInit = initializeCache($xml,\%type,$InitCache);
		if (! createCache ($xml,$cacheInit)) {
			my $code = kiwiExit (1); return $code;
		}
		kiwiExit (0);
	}

	#========================================
	# Prepare image and build chroot system
	#----------------------------------------
	if (defined $Prepare) {
		#==========================================
		# Process system image description
		#------------------------------------------
		$kiwi -> info ("Reading image description [Prepare]...\n");
		if (! checkImageIntegrity($Prepare)) {
			my $code = kiwiExit (1); return $code;
		}
		my $xml = new KIWIXML (
			$kiwi,$Prepare,undef,\@Profiles
		);
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		my $pkgMgr = $cmdL -> getPackageManager();
		if ($pkgMgr) {
			$xml -> setPackageManager($pkgMgr);
		}
		my $krc = new KIWIRuntimeChecker ($kiwi,$cmdL,$xml);
		if (! $krc -> prepareChecks()) {
			my $code = kiwiExit (1); return $code;
		}
		my %type = %{$xml->getImageTypeAndAttributes()};
		#==========================================
		# print boot theme information
		#------------------------------------------
		if ($type{"type"} eq "cpio") {
			my $theme = $xml -> getBootTheme();
			if ($theme) {
				$kiwi -> info ("Using boot theme: $theme");
			} else {
				$kiwi -> warning ("No boot theme set, default is openSUSE");
			}
			$kiwi -> done ();
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
		if (@AddRepository) {
			$xml -> addRepository (
				\@AddRepositoryType,\@AddRepository,
				\@AddRepositoryAlias,\@AddRepositoryPriority
			);
		}
		#==========================================
		# Check for add-package option
		#------------------------------------------
		if (@AddPackage) {
			$xml -> addImagePackages (@AddPackage);
		}
		#==========================================
		# Check for add-pattern option
		#------------------------------------------
		if (@AddPattern) {
			$xml -> addImagePatterns (@AddPattern);
		}
		#==========================================
		# Check for del-package option
		#------------------------------------------
		if (@RemovePackage) {
			$xml -> addRemovePackages (@RemovePackage);
		}
		#==========================================
		# Select cache if requested and exists
		#------------------------------------------
		if ($ImageCache) {
			my $cacheInit = initializeCache($xml,\%type,$Prepare);
			selectCache ($xml,$cacheInit);
		}
		if ($ImageCache) {
			#==========================================
			# Add bootstrap packages to image section
			#------------------------------------------
			my @initPacs = $xml -> getBaseList();
			if (@initPacs) {
				$xml -> addImagePackages (@initPacs);
			}
		}
		#==========================================
		# Initialize root system
		#------------------------------------------
		$root = new KIWIRoot (
			$kiwi,$xml,$Prepare,$RootTree,
			"/base-system",$RecycleRoot,undef,undef,
			$CacheRoot,$CacheRootMode,
			$TargetArch
		);
		if (! defined $root) {
			$kiwi -> error ("Couldn't create root object");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		if (! defined $root -> init ()) {
			$kiwi -> error ("Base initialization failed");
			$kiwi -> failed ();
			$root -> copyBroken();
			undef $root;
			my $code = kiwiExit (1); return $code;
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
				$root -> copyBroken();
				undef $root;
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
			$root -> copyBroken();
			undef $root;
			my $code = kiwiExit (1); return $code;
		}
		if (! $root -> installArchives ()) {
			$kiwi -> error ("Archive installation failed");
			$kiwi -> failed ();
			$root -> cleanMount ();
			$root -> copyBroken();
			undef $root;
			my $code = kiwiExit (1); return $code;
		}
		if (! $root -> setup ()) {
			$kiwi -> error ("Couldn't setup image system");
			$kiwi -> failed ();
			$root -> cleanMount ();
			$root -> copyBroken();
			undef $root;
			my $code = kiwiExit (1); return $code;
		}
		if (! $xml -> writeXMLDescription ($root->getRootPath())) {
			$kiwi -> error ("Couldn't write XML description");
			$kiwi -> failed ();
			$root -> cleanMount ();
			$root -> copyBroken();
			undef $root;
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Clean up
		#------------------------------------------
		$root -> cleanMount ();
		$root -> cleanBroken();
		undef $root;
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
		# Process system image description
		#------------------------------------------
		$kiwi -> info ("Reading image description [Create]...\n");
		my $xml = new KIWIXML (
			$kiwi,"$Create/image",$SetImageType,\@Profiles
		);
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		my $pkgMgr = $cmdL -> getPackageManager();
		if ($pkgMgr) {
			$xml -> setPackageManager($pkgMgr);
		}
		my $krc = new KIWIRuntimeChecker ($kiwi,$cmdL,$xml);
		if (! $krc -> createChecks()) {
			my $code = kiwiExit (1); return $code;
		}
		my %attr = %{$xml->getImageTypeAndAttributes()};
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
		if (@AddRepository) {
			$xml -> addRepository (
				\@AddRepositoryType,\@AddRepository,
				\@AddRepositoryAlias,\@AddRepositoryPriority
			);
		}
		#==========================================
		# Create destdir if needed
		#------------------------------------------
		my $dirCreated = createDirInteractive($kiwi, $Destination);
		if (! defined $dirCreated) {
			my $code = kiwiExit (1); return $code;
		}
		if ($attr{type} ne "cpio") {
			my $profileNames = join ("-",@{$xml->{reqProfiles}});
			if ($profileNames) {
				$Destination.="/".$attr{type}."-".$profileNames;
			} else {
				$Destination.="/".$attr{type};
			}
			if ((! -d $Destination) && (! mkdir $Destination)) {
				$kiwi -> error  ("Failed to create destination subdir: $!");
				$kiwi -> failed ();
				my $code = kiwiExit (1); return $code;
			}
		}
		#==========================================
		# Check tool set
		#------------------------------------------
		my $para = checkType ( $xml,\%attr,$Create );
		if (! defined $para) {
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Check for packages updates if needed
		#------------------------------------------
		my @addonList;   # install this packages
		my @deleteList;  # remove this packages
		my @replAdd;
		my @replDel;
		$xml -> getBaseList();
		@replAdd = $xml -> getReplacePackageAddList();
		@replDel = $xml -> getReplacePackageDelList();
		if (@replAdd) {
			push @addonList,@replAdd;
		}
		if (@replDel) {
			push @deleteList,@replDel;
		}
		$xml -> getInstallList();
		@replAdd = $xml -> getReplacePackageAddList();
		@replDel = $xml -> getReplacePackageDelList();
		if (@replAdd) {
			push @addonList,@replAdd;
		}
		if (@replDel) {
			push @deleteList,@replDel;
		}
		$xml -> getTypeList();
		@replAdd = $xml -> getReplacePackageAddList();
		@replDel = $xml -> getReplacePackageDelList();
		if (@replAdd) {
			push @addonList,@replAdd;
		}
		if (@replDel) {
			push @deleteList,@replDel;
		}
		if (@addonList) {
			my %uniq;
			foreach my $item (@addonList) { $uniq{$item} = $item; }
			@addonList = keys %uniq;
		}
		if (@deleteList) {
			my %uniq;
			foreach my $item (@deleteList) { $uniq{$item} = $item; }
			@deleteList = keys %uniq;
		}
		if ((@addonList) || (@deleteList)) {
			$kiwi -> info ("Image update:");
			if (@addonList) {
				$kiwi -> info ("--> Install/Update: @addonList\n");
			}
			if (@deleteList) {
				$kiwi -> info ("--> Remove: @deleteList\n");
			}
			my $resetVariables   = createResetClosure();
			$main::Survive       = "yes";
			$main::Upgrade       = $main::Create;
			@main::AddPackage    = @addonList;
			@main::RemovePackage = @deleteList;
			undef $main::Create;
			if (! defined main::main()) {
				&{$resetVariables};
				my $code = kiwiExit (1); return $code;
			}
			&{$resetVariables};
			undef $main::Upgrade;
		}
		#==========================================
		# Create KIWIImage object
		#------------------------------------------
		$image = new KIWIImage (
			$kiwi,$xml,$Create,$Destination,$StripImage,
			"/base-system",$Create
		);
		if (! defined $image) {
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Obtain currently used image tree path
		#------------------------------------------
		my $tree = $image -> getImageTree();
		#==========================================
		# Cleanup the tree according to prev runs
		#------------------------------------------
		if (-f "$tree/rootfs.tar") {
			qxx ("rm -f $tree/rootfs.tar");
		}
		if (-f "$tree/recovery.tar.gz") {
			qxx ("rm -f $tree/recovery.*");
		}
		#==========================================
		# Check for optional config-cdroot archive
		#------------------------------------------
		qxx ("rm -f $Destination/config-cdroot.tgz");
		if (-f "$tree/image/config-cdroot.tgz") {
			qxx ("mv $tree/image/config-cdroot.tgz $Destination");
		}
		#==========================================
		# Check for optional config-cdroot.sh
		#------------------------------------------
		qxx ("rm -f $Destination/config-cdroot.sh");
		if (-f "$tree/image/config-cdroot.sh") {
			qxx ("mv $tree/image/config-cdroot.sh $Destination");
		}
		#==========================================
		# Update .profile env, current type
		#------------------------------------------
		$kiwi -> info ("Updating type in .profile environment");
		my $type = $attr{type};
		qxx (
			"sed -i -e 's#kiwi_type=.*#kiwi_type=\"$type\"#' $tree/.profile"
		);
		$kiwi -> done();
		#==========================================
		# Create recovery archive if specified
		#------------------------------------------
		if ($type eq "oem") {
			my $configure = new KIWIConfigure (
				$kiwi,$xml,$tree,$tree."/image",$Destination
			);
			if (! defined $configure) {
				my $code = kiwiExit (1); return $code;
			}
			if (! $configure -> setupRecoveryArchive($attr{filesystem})) {
				my $code = kiwiExit (1); return $code;
			}
		}
		#==========================================
		# Initialize logical image extend
		#------------------------------------------
		my $ok;
		my $checkFormat = 0;
		my $imgName = $image -> buildImageName();
		SWITCH: for ($attr{type}) {
			/^ext2/     && do {
				$ok = $image -> createImageEXT2 ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^ext3/     && do {
				$ok = $image -> createImageEXT3 ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^ext4/     && do {
				$ok = $image -> createImageEXT4 ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$ok = $image -> createImageReiserFS ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^btrfs/    && do {
				$ok = $image -> createImageBTRFS ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^squashfs/ && do {
				$ok = $image -> createImageSquashFS ();
				last SWITCH;
			};
			/^clicfs/   && do {
				$ok = $image -> createImageClicFS ();
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
			/^vmx/      && do {
				$ok = $image -> createImageVMX ( $para );
				last SWITCH;
			};
			/^oem/      && do {
				$ok = $image -> createImageVMX ( $para );
				last SWITCH;
			};
			/^pxe/      && do {
				$ok = $image -> createImagePXE ( $para );
				last SWITCH;
			};
			/^xfs/    && do {
				$ok = $image -> createImageXFS ();
				$checkFormat = 1;
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $attr{type}");
			$kiwi -> failed ();
			undef $image;
			my $code = kiwiExit (1); return $code;
		}
		if ($ok) {
			if (($checkFormat) && ($attr{format})) {
				my $haveFormat = $attr{format};
				my $imgfile= $main::Destination."/".$imgName;
				my $format = new KIWIImageFormat (
					$kiwi,$imgfile,$haveFormat,$xml,$image->{targetDevice}
				);
				if (! $format) {
					my $code = kiwiExit (1); return $code;
				}
				if (! $format -> createFormat()) {
					my $code = kiwiExit (1); return $code;
				}
			}
			undef $image;
			if ($attr{type} ne "cpio") {
				#==========================================
				# Package build result into an archive
				#------------------------------------------
				my $basedest = dirname  $Destination;
				my $basesubd = basename $Destination;
				my $tarfile  = $imgName."-".$basesubd.".tgz";
				if ($cmdL -> getArchiveImage()) {
					$kiwi -> info ("Archiving image build result...");
					my $status = qxx (
						"cd $basedest && tar -czSf $tarfile $basesubd 2>&1"
					);
					my $result = $? >> 8;
					if ($result != 0) {
						$kiwi -> error (
							"Failed to archive image build result: $status"
						);
						$kiwi -> failed ();
						my $code = kiwiExit (1); return $code;
					}
					$kiwi -> done();
				}
				#==========================================
				# Move build result(s) to destination dir
				#------------------------------------------
				my $status = qxx ("mv -f $Destination/* $basedest 2>&1");
				my $result = $? >> 8;
				if ($result != 0) {
					$kiwi -> error (
						"Failed to move image file(s) to destination: $status"
					);
					$kiwi -> failed ();
					my $code = kiwiExit (1); return $code;
				}
				rmdir $Destination;
				my $code = kiwiExit (0); return $code;
			}
		} else {
			undef $image;
			my $code = kiwiExit (1); return $code;
		}
	}

	#==========================================
	# Upgrade image in chroot system
	#------------------------------------------
	if (defined $Upgrade) {
		$kiwi -> info ("Reading image description [Upgrade]...\n");
		my $xml = new KIWIXML (
			$kiwi,"$Upgrade/image",undef,\@ProfilesOrig
		);
		if (! defined $xml) {
			my $code = kiwiExit (1); return $code;
		}
		my $pkgMgr = $cmdL -> getPackageManager();
		if ($pkgMgr) {
			$xml -> setPackageManager($pkgMgr);
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
		if (@AddRepository) {
			$xml -> addRepository (
				\@AddRepositoryType,\@AddRepository,
				\@AddRepositoryAlias,\@AddRepositoryPriority
			);
		}
		#==========================================
		# Check for add-pattern option
		#------------------------------------------
		if (@AddPattern) {
			foreach my $pattern (@AddPattern) {
				push (@AddPackage,"pattern:$pattern");
			}
		}
		#==========================================
		# Initialize root system, use existing root
		#------------------------------------------
		$root = new KIWIRoot (
			$kiwi,$xml,$Upgrade,undef,
			"/base-system",$Upgrade,\@AddPackage,\@RemovePackage,
			$CacheRoot,$CacheRootMode,
			$TargetArch
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
			$root -> copyBroken();
			undef $root;
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# clean up
		#------------------------------------------ 
		$root -> cleanMount ();
		$root -> cleanBroken();
		undef $root;
		kiwiExit (0);
	}

	#==========================================
	# Migrate system to image description
	#------------------------------------------
	if (defined $Migrate) {
		$kiwi -> info ("Starting system to image migration");
		$Destination = "/tmp/$Migrate";
		$migrate = new KIWIMigrate (
			$kiwi,$Destination,$Migrate,\@Exclude,\@Skip,
			\@AddRepository,\@AddRepositoryType,
			\@AddRepositoryAlias,\@AddRepositoryPriority
		);
		#==========================================
		# Check object and repo setup, mandatory
		#------------------------------------------
		if (! defined $migrate) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $migrate -> getRepos()) {
			$migrate -> cleanMount();
			my $code = kiwiExit (1); return $code;
		}
		#==========================================
		# Create report HTML file, errors allowed
		#------------------------------------------
		if (! $MigrateNoFiles) {
			$migrate -> setSystemOverlayFiles();
		}
		$migrate -> getPackageList();
		$migrate -> createReport();
		if (! $MigrateNoTemplate) {
			if (! $migrate -> setTemplate()) {
				$migrate -> cleanMount();
				my $code = kiwiExit (1); return $code;
			}
			if (! $migrate -> setPrepareConfigSkript()) {
				$migrate -> cleanMount();
				my $code = kiwiExit (1); return $code;
			}
			if (! $migrate -> setInitialSetup()) {
				$migrate -> cleanMount();
				my $code = kiwiExit (1); return $code;
			}
		}
		$migrate -> cleanMount();
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
		undef $boot;
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
			undef $boot;
			my $code = kiwiExit (1); return $code;
		}
		undef $boot;
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
			undef $boot;
			my $code = kiwiExit (1); return $code;
		}
		undef $boot;
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
			undef $boot;
			my $code = kiwiExit (1); return $code;
		}
		undef $boot;
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
			undef $boot;
			my $code = kiwiExit (1); return $code;
		}
		undef $boot;
		my $code = kiwiExit (0); return $code;
	}

	#==========================================
	# Create a virtual disk image
	#------------------------------------------
	if (defined $BootVMDisk) {
		$kiwi -> info ("--> Creating boot VM disk from: $BootVMDisk...\n");
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
			$BootVMSize,undef,\@ProfilesOrig
		);
		if (! defined $boot) {
			my $code = kiwiExit (1); return $code;
		}
		if (! $boot -> setupBootDisk($targetDevice)) {
			undef $boot;
			my $code = kiwiExit (1); return $code;
		}
		undef $boot;
		$code = kiwiExit (0); return $code;
	}
	
	#==========================================
	# Convert image into format/configuration
	#------------------------------------------
	if (defined $Convert) {
		$kiwi -> info ("Starting image format conversion...\n");
		my $format = new KIWIImageFormat (
			$kiwi,$Convert,$Format,$main::ConvertXML,$targetDevice
		);
		if (! $format) {
			my $code = kiwiExit (1);
			return $code;
		}
		$format -> createFormat();
		$format -> createMaschineConfiguration();
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
	my $Help;
	my @ListXMLInfoSelection;  # info selection for listXMLInfo
	my $PackageManager;
	my $Version;

	$kiwi = new KIWILog("tiny");
	$cmdL = new KIWICommandLine($kiwi);
	#==========================================
	# get options and call non-root tasks
	#------------------------------------------
	my $result = GetOptions(
		"archive-image"         => \$ArchiveImage,
		"add-package=s"         => \@AddPackage,
		"add-pattern=s"         => \@AddPattern,
		"add-profile=s"         => \@Profiles,
		"add-repo=s"            => \@AddRepository,
		"add-repoalias=s"       => \@AddRepositoryAlias,
		"add-repopriority=i"    => \@AddRepositoryPriority,
		"add-repotype=s"        => \@AddRepositoryType,
		"bootcd=s"              => \$BootCD,
		"bootusb=s"             => \$BootUSB,
		"bootvm=s"              => \$BootVMDisk,
		"bootvm-disksize=s"     => \$BootVMSize,
		"bootvm-system=s"       => \$BootVMSystem,
		"build|b=s"             => \$Build,
		"cache=s"               => \$ImageCache,
		"check-config=s"        => \$CheckConfig,
		"check-kernel"          => \$CheckKernel,
		"clone|o=s"             => \$Clone,
		"convert=s"             => \$Convert,
		"create|c=s"            => \$Create,
		"create-instsource=s"   => \$CreateInstSource,
		"createhash=s"          => \$CreateHash,
		"createpassword"        => \$CreatePassword,
		"debug"                 => \$Debug,
		"del-package=s"         => \@RemovePackage,
		"destdir|d=s"           => \$Destination,
		"exclude|e=s"           => \@Exclude,
		"fat-storage=i"         => \$FatStorage,
		"force-new-root"        => \$ForceNewRoot,
		"format|f=s"            => \$Format,
		"fs-blocksize=i"        => \$FSBlockSize,
		"fs-check-interval=i"   => \$FSCheckInterval,
		"fs-inoderatio=i"       => \$FSInodeRatio,
		"fs-inodesize=i"        => \$FSInodeSize,
		"fs-journalsize=i"      => \$FSJournalSize,
		"fs-max-mount-count=i"  => \$FSMaxMountCount,
		"grub-chainload"        => \$GrubChainload,
		"gzip-cmd=s"            => \$GzipCmd,
		"help|h"                => \$Help,
		"ignore-repos"          => \$IgnoreRepos,
		"info|i=s"              => \$ListXMLInfo,
		"init-cache=s"          => \$InitCache,
		"installcd=s"           => \$InstallCD,
		"installcd-system=s"    => \$InstallCDSystem,
		"installstick=s"        => \$InstallStick,
		"installstick-system=s" => \$InstallStickSystem,
		"isocheck"              => \$ISOCheck,
		"list|l"                => \&listImage,
		"log-port=i"            => \$LogPort,
		"logfile=s"             => \$LogFile,
		"lvm"                   => \$LVM,
		"mbrid=o"               => \$MBRID,
		"migrate|m=s"           => \$Migrate,
		"nocolor"               => \$NoColor,
		"nofiles"               => \$MigrateNoFiles,
		"notemplate"            => \$MigrateNoTemplate,
		"package-manager=s"     => \$PackageManager,
		"partitioner=s"         => \$Partitioner,
		"prebuiltbootimage=s"   => \$PrebuiltBootImage,
		"prechroot-call=s"      => \$PreChrootCall,
		"prepare|p=s"           => \$Prepare,
		"recycle-root"          => \$RecycleRoot,
		"root|r=s"              => \$RootTree,
		"select=s"              => \@ListXMLInfoSelection,
		"set-repo=s"            => \$SetRepository,
		"set-repoalias=s"       => \$SetRepositoryAlias,
		"set-repopriority=i"    => \$SetRepositoryPriority,
		"set-repotype=s"        => \$SetRepositoryType,
		"setup-splash=s"        => \$SetupSplash,
		"skip=s"                => \@Skip,
		"strip|s"               => \$StripImage,
		"target-arch=s"         => \$TargetArch,
		"targetdevice=s"        => \$targetDevice,
		"targetstudio=s"        => \$targetStudio,
		"type|t=s"              => \$SetImageType,
		"upgrade|u=s"           => \$Upgrade,
		"v|verbose+"            => \$Verbosity,
		"version"               => \$Version,
		"yes|y"                 => \$defaultAnswer,
	);
	#========================================
	# check if repositories are to be added
	#----------------------------------------
	if (@AddRepository) {
		my $res = $cmdL -> setAdditionalRepos(
			\@AddRepository,
			\@AddRepositoryAlias,
			\@AddRepositoryPriority,
			\@AddRepositoryType
		);
		if (! $res) {
			my $code = kiwiExit (1); return $code;
		}
	}
	#========================================
	# check if archive-image option is set
	#----------------------------------------
	if (defined $ArchiveImage) {
		$cmdL -> setArchiveImage ($ArchiveImage);
	}
	#========================================
	# check if repositories are to be ignored
	#----------------------------------------
	if (defined $IgnoreRepos) {
		$cmdL -> setIgnoreRepos(1);
	}
	#========================================
	# check if we are doing caching
	#----------------------------------------
	if (defined $InitCache) {
		$cmdL -> setAdditionalRepos(
			\@AddRepository,
			\@AddRepositoryAlias,
			\@AddRepositoryPriority,
			\@AddRepositoryType
		);
		$cmdL -> setBuildProfiles(\@Profiles);
		$cmdL -> setConfigDir($InitCache);
		my $res = $cmdL -> setIgnoreRepos($IgnoreRepos);
		if (! $res) {
			my $code = kiwiExit (1); return $code;
		}
		if (defined $LogFile) {
			$res = $cmdL -> setLogFile($LogFile);
		}
		if (defined $PackageManager) {
			$res = $cmdL -> setPackageManager($PackageManager);
		}
		if (defined $SetRepository) {
			$res = $cmdL -> setReplacementRepo(
				$SetRepository,
				$SetRepositoryAlias,
				$SetRepositoryPriority,
				$SetRepositoryType
			);
		}
		if (! $res) {
			my $code = kiwiExit (1); return $code;
		}
	}
	#========================================
	# check if a specifc logfile has been defined
	#----------------------------------------
	if (defined $LogFile) {
		$cmdL -> setLogFile($LogFile);
	}
	#========================================
	# check if a package manager is specified
	#----------------------------------------
	if (defined $PackageManager) {
		my $result = $cmdL -> setPackageManager($PackageManager);
		if (! $result) {
			my $code = kiwiExit (1); return $code;
		}
	}
	#========================================
	# check if recycle-root is used
	#----------------------------------------
	if (defined $RecycleRoot) {
		$RecycleRoot = $RootTree;
	}
	#========================================
	# check replacement repo information
	#----------------------------------------
	if (defined $SetRepository) {
		my $result = $cmdL -> setReplacementRepo(
			$SetRepository,
			$SetRepositoryAlias,
			$SetRepositoryPriority,
			$SetRepositoryType
		);
		if (! $result) {
			my $code = kiwiExit (1); return $code;
		}
	}
	#============================================
	# check Partitioner according to device
	#--------------------------------------------
	if (($targetDevice) && ($targetDevice =~ /\/dev\/dasd/)) {
		$Partitioner = "fdasd";
	}
	#========================================
	# turn destdir into absolute path
	#----------------------------------------
	if (defined $Destination) {
		$Destination = File::Spec->rel2abs ($Destination);
		$cmdL -> setImagetargetDir ($Destination);
	}
	#========================================
	# check prepare/create/cache paths
	#----------------------------------------
	if (defined $CacheRoot) {
		if (($CacheRoot !~ /^\//) && (! -d $CacheRoot)) {
			$CacheRoot = $System."/".$CacheRoot;
		}
		$CacheRoot =~ s/\/$//;
	}
	if (defined $Prepare) {
		if (($Prepare !~ /^\//) && (! -d $Prepare)) {
			$Prepare = $System."/".$Prepare;
		}
		$Prepare =~ s/\/$//;
	}
	if (defined $Create) {
		if (($Create !~ /^\//) && (! -d $Create)) {
			$Create = $System."/".$Create;
		}
		$Create =~ s/\/$//;
	}
	if (defined $Build) {
		if (($Build !~ /^\//) && (! -d $Build)) {
			$Build = $System."/".$Build;
		}
		$Build =~ s/\/$//;
	}
	if (defined $ListXMLInfo) {
		if (($ListXMLInfo !~ /^\//) && (! -d $ListXMLInfo)) {
			$ListXMLInfo = $System."/".$ListXMLInfo;
		}
		$ListXMLInfo =~ s/\/$//;
	}
	#========================================
	# store uniq path to image description
	#----------------------------------------
	if (defined $Prepare) {
		$ImageDescription = $Prepare;
		$cmdL -> setConfigDir ($ImageDescription);
	}
	if (defined $Create) {
		if (open FD,"$Create/image/main::Prepare") {
			$ImageDescription = <FD>; close FD;
		}
	}
	#========================================
	# store original value of Profiles
	#----------------------------------------
	@ProfilesOrig = @Profiles;
	$cmdL -> setBuildProfiles (\@Profiles);
	#========================================
	# set default inode ratio for ext2/3
	#----------------------------------------
	if (! defined $FSInodeRatio) {
		$FSInodeRatio = 16384;
	}
	#========================================
	# set default min inode count
	#----------------------------------------
	if (! defined $FSMinInodes) {
		$FSMinInodes = 20000;
	}
	#========================================
	# set default inode size for ext2/3
	#----------------------------------------
	if (! defined $FSInodeSize) {
		$FSInodeSize = 256;
	}
	#==========================================
	# non root task: Check XML configuration
	#------------------------------------------
	if (defined $CheckConfig) {
		checkConfig();
	}
	#==========================================
	# non root task: Create crypted password
	#------------------------------------------
	if (defined $CreatePassword) {
		createPassword();
	}
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
	# non root task: Clone image 
	#------------------------------------------
	if (defined $Clone) {
		cloneImage();
	}
	#==========================================
	# non root task: Help
	#------------------------------------------
	if (defined $Help) {
		usage(0);
	}
	#==========================================
	# non root task: Version
	#------------------------------------------
	if (defined $Version) {
		version(0);
	}
	#==========================================
	# Check result of options parsing
	#------------------------------------------
	if ( $result != 1 ) {
		usage(1);
	}
	#==========================================
	# Check for root privileges
	#------------------------------------------
	if ($< != 0) {
		$kiwi -> error ("Only root can do this");
		$kiwi -> failed ();
		usage(1);
	}
	#==========================================
	# Check option combination/values
	#------------------------------------------
	if (
		(! defined $Build)              &&
		(! defined $Prepare)            &&
		(! defined $Create)             &&
		(! defined $InitCache)          &&
		(! defined $InstallCD)          &&
		(! defined $Upgrade)            &&
		(! defined $SetupSplash)        &&
		(! defined $BootVMDisk)         &&
		(! defined $Migrate)            &&
		(! defined $InstallStick)       &&
		(! defined $ListXMLInfo)        &&
		(! defined $CreatePassword)     &&
		(! defined $BootCD)             &&
		(! defined $BootUSB)            &&
		(! defined $Clone)              &&
		(! defined $CheckConfig)        &&
		(! defined $Convert)
	) {
		$kiwi -> error ("No operation specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if (($InitCache) && ($LogFile)) {
		$kiwi -> warning ("Logfile set to terminal in init-cache mode");
		$kiwi -> done ();
		$LogFile = "terminal";
		$cmdL -> setLogFile($LogFile);
	}
	if (($targetDevice) && (! -b $targetDevice)) {
		$kiwi -> error ("Target device $targetDevice doesn't exist");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $IgnoreRepos) && (defined $SetRepository)) {
		$kiwi -> error ("Can't use ignore repos together with set repos");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $RootTree) && ($RootTree !~ /^\//)) {
		my $workingDir = qxx ( "pwd" ); chomp $workingDir;
		$RootTree = $workingDir."/".$RootTree;
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
	if ((defined $PreChrootCall) && (! -x $PreChrootCall)) {
		$kiwi -> error ("pre-chroot program: $PreChrootCall");
		$kiwi -> failed ();
		$kiwi -> error ("--> 1) no such file or directory\n");
		$kiwi -> error ("--> 2) and/or not in executable format\n");
		my $code = kiwiExit (1); return $code;
	}
	if ((defined $BootVMDisk) && (! defined $BootVMSystem)) {
		$kiwi -> error ("Virtual Disk setup must specify a bootvm-system");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	}
	if (defined $Partitioner) {
		if (
			($Partitioner ne "parted") &&
			($Partitioner ne "fdasd")
		) {
			$kiwi -> error ("Invalid partitioner, expected parted|fdasd");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
	}
	if ((defined $Build) && (! defined $Destination)) {
		$kiwi -> error  ("No destination directory specified");
		$kiwi -> failed ();
		my $code = kiwiExit (1); return $code;
	} elsif (defined $Build) {
		$cmdL -> setTargetDirsForBuild();
	}
	if (defined $ListXMLInfo) {
		$cmdL -> setAdditionalRepos(
			\@AddRepository,
			\@AddRepositoryAlias,
			\@AddRepositoryPriority,
			\@AddRepositoryType
		);
		$cmdL -> setBuildProfiles(\@Profiles);
		$cmdL -> setConfigDir($ListXMLInfo);
		my $res = $cmdL -> setIgnoreRepos($IgnoreRepos);
		if (! $res) {
			my $code = kiwiExit (1); return $code;
		}
		if (defined $LogFile) {
			$res = $cmdL -> setLogFile($LogFile);
		}
		if (defined $PackageManager) {
			$res = $cmdL -> setPackageManager($PackageManager);
		}
		if (defined $SetRepository) {
			$res = $cmdL -> setReplacementRepo(
				$SetRepository,
				$SetRepositoryAlias,
				$SetRepositoryPriority,
				$SetRepositoryType
			);
		}
		if (! $res) {
			my $code = kiwiExit (1); return $code;
		}
		my $info = new KIWIXMLInfo($kiwi, $cmdL);
		if (! $info) {
			my $code = kiwiExit (1); return $code;
		}
		$res = $info -> printXMLInfo(\@ListXMLInfoSelection);
		if (! $res) {
			my $code = kiwiExit (1); return $code;
		}
		my $code = kiwiExit (0); return $code;
	}
	if (defined $SetImageType) {
		$cmdL -> setBuildType($SetImageType);
	}
	if (defined $MBRID) {
		if ($MBRID < 0 || $MBRID > 0xffffffff) {
			$kiwi -> error ("Invalid mbrid");
			$kiwi -> failed ();
			my $code = kiwiExit (1); return $code;
		}
		$MBRID = sprintf ("0x%08x", $MBRID);
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
	my $exit = shift;
	my $kiwi = new KIWILog("tiny");
	my $date = qxx ( "bash -c 'LANG=POSIX date -I'" ); chomp $date;
	print "Linux KIWI setup  (image builder) ($date)\n";
	print "Copyright (c) 2007 - SUSE LINUX Products GmbH\n";
	print "\n";

	print "Usage:\n";
	print "    kiwi -l | --list\n";
	print "Configuration check:\n";
	print "    kiwi --check-config <path-to-xml-file-to-check>\n";
	print "Image Cloning:\n";
	print "    kiwi -o | --clone <image-path> -d <destination>\n";
	print "Image Creation in one step:\n";
	print "    kiwi -b | --build <image-path> -d <destination>\n";
	print "Image Preparation/Creation in two steps:\n";
	print "    kiwi -p | --prepare <image-path>\n";
	print "       [ --root <image-root> --cache <dir> ]\n";
	print "    kiwi -c | --create  <image-root> -d <destination>\n";
	print "       [ --type <image-type> ]\n";
	print "Image Cache:\n";
	print "    kiwi --init-cache <image-path>\n";
	print "       [ --cache <dir> ]\n";
	print "Image Upgrade:\n";
	print "    kiwi -u | --upgrade <image-root>\n";
	print "       [ --add-package <name> --add-pattern <name> ]\n";
	print "System to Image migration:\n";
	print "    kiwi -m | --migrate <name>\n";
	print "       [ --exclude <directory> --exclude <...> ]\n";
	print "       [ --skip <package> --skip <...> ]\n";
	print "       [ --nofiles --notemplate ]\n";
	print "Image postprocessing modes:\n";
	print "    kiwi --bootvm <initrd> --bootvm-system <systemImage>\n";
	print "       [ --bootvm-disksize <size> ]\n";
	print "    kiwi --bootcd  <initrd>\n";
	print "    kiwi --bootusb <initrd>\n";
	print "    kiwi --installcd <initrd>\n";
	print "       [ --installcd-system <vmx-system-image> ]\n";
	print "    kiwi --installstick <initrd>\n";
	print "       [ --installstick-system <vmx-system-image> ]\n";
	print "Image format conversion:\n";
	print "    kiwi --convert <systemImage> [ --format <vmdk|ovf|qcow2|vhd|..> ]\n";
	print "Helper Tools:\n";
	print "    kiwi --createpassword\n";
	print "    kiwi --createhash <image-path>\n";
	print "    kiwi --info <image-path> --select <\n";
	print "           repo-patterns|patterns|types|sources|\n";
	print "           size|profiles|packages|version\n";
	print "         > --select ...\n";
	print "    kiwi --setup-splash <initrd>\n";
	print "\n";

	print "Global Options:\n";
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
	print "    [ -y | --yes ]\n";
	print "      Answer any interactive questions with yes\n";
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
	print "    [ --add-pattern <name> ]\n";
	print "      Adds the given pattern name to the list of image patters.\n";
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
	print "    [ --archive-image ]\n";
	print "      When calling kiwi --create this option allows to pack\n";
	print "      the build result(s) into a tar archive\n";
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
	print "    [ --fs-inoderatio <number> ]\n";
	print "      Set the bytes/inode ratio. This option has no\n";
	print "      effect if the reiser filesystem is used\n";
	print "\n";
	print "    [ --fs-max-mount-count <number> ]\n";
	print "      Set the number of mounts after which the filesystem will\n";
	print "      be checked for ext[234]. Set to 0 to disable checks.\n";
	print "\n";
	print "    [ --fs-check-interval <number> ]\n";
	print "      Set the maximal time between two filesystem checks for\n";
	print "      ext[234]. Set to 0 to disable time-dependent checks.\n";
	print "\n";
	print "    [ --fat-storage <size in MB> ]\n";
	print "      This option turns on the syslinux bootloader and makes\n";
	print "      the image to use LVM for the operating system. The size\n";
	print "      of the syslinux required bootpartition is set to the\n";
	print "      specified value. This is useful if the fat space is not\n";
	print "      only used for booting the system but also for custom\n";
	print "      Therefore this option makes sense when building Windows\n";
	print "      friendly USB stick images\n";
	print "\n";
	print "    [ --partitioner <parted|fdasd> ]\n";
	print "      Select the tool to create partition tables. Supported are\n";
	print "      parted and fdasd (s390). By default parted is used\n";
	print "\n";
	print "    [ --check-kernel ]\n";
	print "      Activates check for matching kernels between boot and\n";
	print "      system image. The kernel check also tries to fix the boot\n";
	print "      image if no matching kernel was found.\n";
	print "\n";
	print "    [ --mbrid <number>]\n";
	print "      Sets the disk id to the given value. The default is to\n";
	print "      generate a random id.\n";
	print "--\n";
	version ($exit);
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
		if ($image =~ /(iso|net|oem|vmx)boot/) {
			next;
		}
		my $controlFile = $locator -> getControlFile (
			"$System/$image"
		);
		if ($controlFile) {
			$kiwi -> info ($image);
			my $xml = new KIWIXML (
				$kiwi,$System."/".$image,undef,undef
			);
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
# checkConfig
#------------------------------------------
sub checkConfig {
	# ...
	# Check the specified configuration file
	# ---
	my $kiwi = new KIWILog("tiny");
	if (! -f $CheckConfig) {
		$kiwi -> error (
			"Could not access specified file to check: $CheckConfig"
		);
		$kiwi -> failed ();
		exit 1;
	}
	my $validator = new KIWIXMLValidator (
		$kiwi,$CheckConfig,$Revision,$Schema,$SchemaCVT
	);
	if (! $validator) {
		exit 1;
	}
	my $isValid = $validator -> validate();
	if (! defined $isValid) {
		$kiwi -> error ('Validation failed');
		$kiwi -> failed ();
		exit 1;
	}
	$kiwi -> info ('Validation passed');
	$kiwi -> done ();
	exit 0;
}

#==========================================
# cloneImage
#------------------------------------------
sub cloneImage {
	# ...
	# clone an existing image description by copying
	# the tree to the given destination the possibly
	# existing checksum will be removed as we assume
	# that the clone will be changed
	# ----
	my $answer = "unknown";
	#==========================================
	# Check destination definition
	#------------------------------------------
	my $kiwi = new KIWILog("tiny");
	if (! defined $Destination) {
		$kiwi -> error  ("No destination directory specified");
		$kiwi -> failed ();
		kiwiExit (1);
	} else {
		$kiwi -> info ("Cloning image $Clone -> $Destination...");
	}
	#==========================================
	# Evaluate image path or name 
	#------------------------------------------
	if (($Clone !~ /^\//) && (! -d $Clone)) {
		$Clone = $main::System."/".$Clone;
	}
	my $cfg = $Clone."/".$main::ConfigName;
	my $md5 = $Destination."/.checksum.md5";
	if (! -f $cfg) {
		my @globsearch = glob ($Clone."/*.kiwi");
		my $globitems  = @globsearch;
		if ($globitems == 0) {
			$kiwi -> failed ();
			$kiwi -> error ("Cannot find control file: $cfg");
			$kiwi -> failed ();
			kiwiExit (1);
		} elsif ($globitems > 1) {
			$kiwi -> failed ();
			$kiwi -> error ("Found multiple *.kiwi control files");
			$kiwi -> failed ();
			kiwiExit (1);
		} else {
			$cfg = pop @globsearch;
		}
	}
	#==========================================
	# Check if destdir exists or not 
	#------------------------------------------
	if (! -d $Destination) {
		my $prefix = $kiwi -> getPrefix (1);
		$kiwi -> note ("\n");
		$kiwi -> info ("Destination: $Destination doesn't exist\n");
		while ($answer !~ /^yes$|^no$/) {
			print STDERR $prefix,
				"Would you like kiwi to create it [yes/no] ? ";
			chomp ($answer = <>);
		}
		if ($answer eq "yes") {
			qxx ("mkdir -p $Destination");
		} else {
			kiwiExit (1);
		}
	}
	#==========================================
	# Copy path to destination 
	#------------------------------------------
	my $data = qxx ("cp -a $Clone/* $Destination 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		$kiwi -> failed ();
		$kiwi -> error ("Failed to copy $Clone: $data");
		$kiwi -> failed ();
		kiwiExit (1);
	}
	#==========================================
	# Remove checksum 
	#------------------------------------------
	if (-f $md5) {
		qxx ("rm -f $md5 2>&1");
	}
	if ($answer ne "yes") {
		$kiwi -> done();
	}
	kiwiExit (0);
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
	# Write temporary XML changes to logfile
	#------------------------------------------
	if (defined $kiwi) {
		$kiwi -> writeXML();
	}
	#==========================================
	# Survive because kiwi called itself
	#------------------------------------------
	if ((defined $Survive) && ($Survive eq "yes")) {
		if ($code != 0) {
			return undef;
		}
		return $code;
	}
	#==========================================
	# Create log object if we don't have one...
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# Reformat log file for human readers...
	#------------------------------------------
	$kiwi -> setLogHumanReadable();
	#==========================================
	# Check for backtrace and clean flag...
	#------------------------------------------
	if ($code != 0) {
		if (defined $Debug) {
			$kiwi -> printBackTrace();
		}
		$kiwi -> printLogExcerpt();
		$kiwi -> error  ("KIWI exited with error(s)");
		$kiwi -> done ();
	} else {
		$kiwi -> info ("KIWI exited successfully");
		$kiwi -> done ();
	}
	#==========================================
	# Move process log to final logfile name...
	#------------------------------------------
	$kiwi -> finalizeLog();
	#==========================================
	# Cleanup and exit now...
	#------------------------------------------
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
	my $exit = shift;
	if (! defined $exit) {
		$exit = 0;
	}
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	my $rev  = "unknown";
	if (open FD,$Revision) {
		$rev = <FD>; close FD;
	}
	$kiwi -> info ("kiwi version v$Version\nGIT Commit: $rev\n");
	$kiwi -> cleanSweep();
	exit ($exit);
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
	my $pwd = shift;
	my @legal_enc = ('.', '/', '0'..'9', 'A'..'Z', 'a'..'z');
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	my $word2 = 2;
	my $word1 = 1;
	my $tmp = (time + $$) % 65536;
	my $salt;
	srand ($tmp);
	$salt = $legal_enc[sprintf "%u", rand (@legal_enc)];
	$salt.= $legal_enc[sprintf "%u", rand (@legal_enc)];
	if (defined $pwd) {
		$word1 = $word2 = $pwd;
	}
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
	my $encrypted = crypt ($word1, $salt);
	if (defined $pwd) {
		return $encrypted;
	}
	$kiwi -> done ();
	$kiwi -> info ("Your password:\n\t$encrypted\n");
	my $code = kiwiExit (0); return $code;
}
#==========================================
# createHash
#------------------------------------------
sub createHash {
	# ...
	# Sign your image description with a md5 sum. The created
	# file .checksum.md5 is checked on runtime with the md5sum
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
	if (! $locator -> getControlFile ($CreateHash)) {
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
	my $xml    = $_[0];
	my (%type) = %{$_[1]};
	my $root   = $_[2];
	my $para   = "ok";
	my $type  = $type{type};
	my $flags = $type{flags};
	my $fs    = $type{filesystem};
	#==========================================
	# check for required image attributes
	#------------------------------------------
	if (defined $main::FatStorage) {
		# /.../
		# if the option --fat-storage is set, we set syslinux
		# as bootloader because it works better on USB sticks.
		# Additionally we use LVM because it allows to better
		# resize the stick
		# ----
		$xml -> __setTypeAttribute ("bootloader","syslinux");
		$xml -> __setSystemDiskElement ();
		$xml -> writeXMLDescription ($root);
	} elsif (defined $main::LVM) {
		# /.../
		# if the option --lvm is set, we add/update a systemdisk
		# element which triggers the use of LVM
		# ----
		$xml -> __setSystemDiskElement ();
		$xml -> writeXMLDescription ($root);
	}
	#==========================================
	# check for required filesystem tool(s)
	#------------------------------------------
	if (($flags) || ($fs)) {
		my @fs = ();
		if (($flags) && ($type eq "iso")) {
			push (@fs,$type{flags});
		} else {
			@fs = split (/,/,$type{filesystem});
		}
		foreach my $fs (@fs) {
			my %result = checkFileSystem ($fs);
			if (%result) {
				if (! $result{hastool}) {
					$kiwi -> error (
						"Can't find filesystem tool for: $result{type}"
					);
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
	# check tool/driver compatibility
	#------------------------------------------
	my $check_mksquashfs = 0;
	if ($type{type} eq "squashfs") {
		$check_mksquashfs = 1;
	}
	if (($type{installiso}) || ($type{installstick})) {
		$check_mksquashfs = 1;
	}
	if (($fs) && ($fs =~ /squashfs/)) {
		$check_mksquashfs = 1;
	}
	if (($flags) && ($flags =~ /compressed|unified/)) {
		$check_mksquashfs = 1;
	}
	#==========================================
	# squashfs...
	#------------------------------------------
	if ($check_mksquashfs) {
		my $km = glob ("$root/lib/modules/*/kernel/fs/squashfs/squashfs.ko");
		if ($km) {
			my $mktool_vs = qxx ("mksquashfs -version 2>&1 | head -n 1");
			my $module_vs = qxx ("modinfo -d $km 2>&1");
			my $error = 0;
			if ($mktool_vs =~ /^mksquashfs version (\d)\.\d \(/) {
				$mktool_vs = $1;
				$error++;
			}
			if ($module_vs =~ /^squashfs (\d)\.\d,/) {
				$module_vs = $1;
				$error++;
			}
			$kiwi -> loginfo ("squashfs mktool major version: $mktool_vs\n");
			$kiwi -> loginfo ("squashfs module major version: $module_vs\n");
			if (($error == 2) && ($mktool_vs ne $module_vs)) {
				$kiwi -> error (
					"--> squashfs tool/driver mismatch: $mktool_vs vs $module_vs"
				);
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
		/^vmx|oem|pxe/ && do {
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

#==========================================
# checkFSOptions
#------------------------------------------
sub checkFSOptions {
	# /.../
	# checks the $FS* option values and build an option
	# string for the relevant filesystems
	# ---
	my %result = ();
	my $fs_maxmountcount;
	my $fs_checkinterval;
	foreach my $fs (keys %KnownFS) {
		my $blocksize;   # block size in bytes
		my $journalsize; # journal size in MB (ext) or blocks (reiser)
		my $inodesize;   # inode size in bytes (ext only)
		my $inoderatio;  # bytes/inode ratio
		my $fsfeature;   # filesystem features (ext only)
		SWITCH: for ($fs) {
			#==========================================
			# EXT2-4
			#------------------------------------------
			/ext[432]/   && do {
				if ($FSBlockSize)   {$blocksize   = "-b $FSBlockSize"}
				if (($FSInodeSize) && ($FSInodeSize != 256)) {
					$inodesize = "-I $FSInodeSize"
				}
				if ($FSInodeRatio)  {$inoderatio  = "-i $FSInodeRatio"}
				if ($FSJournalSize) {$journalsize = "-J size=$FSJournalSize"}
				if ($FSMaxMountCount) {
					$fs_maxmountcount = " -c $FSMaxMountCount";
				}
				if ($FSCheckInterval) {
					$fs_checkinterval = " -i $FSCheckInterval";
				}
				$fsfeature = "-F -O resize_inode";
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
		if (defined $inoderatio) {
			$result{$fs} .= $inoderatio." ";
		}
		if (defined $blocksize) {
			$result{$fs} .= $blocksize." ";
		}
		if (defined $journalsize) {
			$result{$fs} .= $journalsize." ";
		}
		if (defined $fsfeature) {
			$result{$fs} .= $fsfeature." ";
		}
	}
	if ($fs_maxmountcount || $fs_checkinterval) {
		$result{extfstune} = "$fs_maxmountcount$fs_checkinterval";
	}
	return %result;
}

#==========================================
# mount
#------------------------------------------
sub mount {
	# /.../
	# implements a generic mount function for all supported
	# file system types
	# ---
	my $source= shift;
	my $dest  = shift;
	my $salt  = int (rand(20));
	my %fsattr = main::checkFileSystem ($source);
	my $type   = $fsattr{type};
	my $cipher = $main::LuksCipher;
	my $status;
	my $result;
	#==========================================
	# Check result of filesystem detection
	#------------------------------------------
	if (! %fsattr) {
		$kiwi -> error  ("Couldn't detect filesystem on: $source");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Check for DISK file
	#------------------------------------------
	if (-f $source) {
		my $boot = "'boot sector'";
		my $null = "/dev/null";
		$status= qxx (
			"dd if=$source bs=512 count=1 2>$null|file - | grep -q $boot"
		);
		$result= $? >> 8;
		if ($result == 0) {			
			$status = qxx ("/sbin/losetup -s -f $source 2>&1"); chomp $status;
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> error  (
					"Couldn't loop bind disk file: $status"
				);
				$kiwi -> failed (); umount();
				return undef;
			}
			my $loop = $status;
			push @UmountStack,"losetup -d $loop";
			$status = qxx ("kpartx -a $loop 2>&1");
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> error (
					"Couldn't loop bind disk partition(s): $status"
				);
				$kiwi -> failed (); umount();
				return undef;
			}
			push @UmountStack,"kpartx -d $loop";
			$loop =~ s/\/dev\///;
			$source = "/dev/mapper/".$loop."p1";
			if (! -b $source) {
				$kiwi -> error ("No such block device $source");
				$kiwi -> failed (); umount();
				return undef;
			}
		}
	}
	#==========================================
	# Check for LUKS extension
	#------------------------------------------
	if ($type eq "luks") {
		if (-f $source) {
			$status = qxx ("/sbin/losetup -s -f $source 2>&1"); chomp $status;
			$result = $? >> 8;
			if ($result != 0) {
				$kiwi -> error  ("Couldn't loop bind logical extend: $status");
				$kiwi -> failed (); umount();
				return undef;
			}
			$source = $status;
			push @UmountStack,"losetup -d $source";
		}
		if ($cipher) {
			$status = qxx (
				"echo $cipher | cryptsetup luksOpen $source luks-$salt 2>&1"
			);
		} else {
			$status = qxx ("cryptsetup luksOpen $source luks-$salt 2>&1");
		}
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error  ("Couldn't open luks device: $status");
			$kiwi -> failed (); umount();
			return undef;
		}
		$source = "/dev/mapper/luks-".$salt;
		push @UmountStack,"cryptsetup luksClose luks-$salt";
	}
	#==========================================
	# Mount device or loop mount file
	#------------------------------------------
	if ((-f $source) && ($type ne "clicfs")) {
		$status = qxx ("mount -o loop $source $dest 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount $source to: $dest: $status");
			$kiwi -> failed (); umount();
			return undef;
		}
	} else {
		if ($type eq "clicfs") {
			$status = qxx ("clicfs -m 512 $source $dest 2>&1");
			$result = $? >> 8;
			if ($result == 0) {
				$status = qxx ("resize2fs $dest/fsdata.ext3 2>&1");
				$result = $? >> 8;
			}
		} else {
			$status = qxx ("mount $source $dest 2>&1");
			$result = $? >> 8;
		}
		if ($result != 0) {
			$kiwi -> error ("Failed to mount $source to: $dest: $status");
			$kiwi -> failed (); umount();
			return undef;
		}
	}
	push @UmountStack,"umount $dest";
	#==========================================
	# Post mount actions
	#------------------------------------------
	if (-f $dest."/fsdata.ext3") {
		$source = $dest."/fsdata.ext3";
		$status = qxx ("mount -o loop $source $dest 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error ("Failed to loop mount $source to: $dest: $status");
			$kiwi -> failed (); umount();
			return undef;
		}
		push @UmountStack,"umount $dest";
	}
	return $dest;
}

#==========================================
# umount
#------------------------------------------
sub umount {
	# /.../
	# implements an umount function for filesystems mounted
	# via main::mount(). The function walks through the
	# contents of the UmountStack list
	# ---
	my $status;
	my $result;
	qxx ("sync");
	foreach my $cmd (reverse @UmountStack) {
		$status = qxx ("$cmd 2>&1");
		$result = $? >> 8;
		if ($result != 0) {
			$kiwi -> warning ("UmountStack failed: $cmd: $status\n");
		}
	}
	@UmountStack = ();
}

#==========================================
# isize
#------------------------------------------
sub isize {
	# /.../
	# implements a size function like the -s operator
	# but also works for block specials using blockdev
	# ---
	my $target = shift;
	if (! defined $target) {
		return 0;
	}
	if (-b $target) {
		my $size = qxx ("blockdev --getsize64 $target 2>&1");
		my $code = $? >> 8;
		if ($code == 0) {
			chomp  $size;
			return $size;
		}
	} elsif (-f $target) {
		return -s $target;
	}
	return 0;
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
		if (($KnownFS{$fs}{tool}) && (-x $KnownFS{$fs}{tool})) {
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
				if ($main::kiwi -> trace()) {
					$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
				}
				return undef;
			}
			SWITCH: for ($data) {
				/ext4/      && do {
					$type = "ext4";
					last SWITCH;
				};
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
				/BTRFS/     && do {
					$type = "btrfs";
					last SWITCH;
				};
				/Squashfs/  && do {
					$type = "squashfs";
					last SWITCH;
				};
				/LUKS/      && do {
					$type = "luks";
					last SWITCH;
				};
				/XFS/     && do {
					$type = "xfs";
					last SWITCH;
				};
				# unknown filesystem type check clicfs...
				$data = qxx (
					"dd if=$fs bs=128k count=1 2>/dev/null | grep -q CLIC"
				);
				$code = $? >> 8;
				if ($code == 0) {
					$type = "clicfs";
					last SWITCH;
				}
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
			if ($main::kiwi -> trace()) {
				$main::BT.=eval { Carp::longmess ($main::TT.$main::TL++) };
			}
			return ();
		}
	}
	return %result;
}

#==========================================
# checkImageIntegrity
#------------------------------------------
sub checkImageIntegrity {
	# /../
	# Check the image description integrity if a checksum file exists
	# ---
	my $imageDesc = shift;
	my $checkmdFile = $imageDesc."/.checksum.md5";
	if (-f $checkmdFile) {
		my $data = qxx ("cd $imageDesc && md5sum -c .checksum.md5 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			chomp $data;
			$kiwi -> error ("Integrity check for $imageDesc failed:\n$data");
			$kiwi -> failed ();
			return undef;
		}
	} else {
		$kiwi -> warning ("Description provides no MD5 hash, check");
		$kiwi -> skipped ();
	}
	return 1;
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
	$kiwi -> deactivateBackTrace();
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
	my $xml = new KIWIXML (
		$kiwi,$CreateInstSource,undef,undef
	);
	if (! defined $xml) {
		my $code = kiwiExit (1); return $code;
	}
	my $pkgMgr = $cmdL -> getPackageManager();
	if ($pkgMgr) {
		$xml -> setPackageManager($pkgMgr);
	}
	#==========================================
	# Initialize installation source tree
	#------------------------------------------
	my $root = $xml -> createTmpDirectory ( undef, $RootTree );
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
	my $ret = $collect -> mainTask ();
	if ( $ret != 0 ) {
		$kiwi -> warning( "KIWICollect had runtime error." );
		$kiwi -> skipped ();
		my $code = kiwiExit ( $ret ); return $code;
	}
	$kiwi->info( "KIWICollect completed successfully." );
	$kiwi->done();
	kiwiExit (0);
}

#==========================================
# initializeCache
#------------------------------------------
sub initializeCache {
	$kiwi -> info ("Initialize image cache...\n");
	#==========================================
	# Variable setup
	#------------------------------------------
	my $xml  = $_[0];
	my %type = %{$_[1]};
	my $mode = $_[2];
	#==========================================
	# Variable setup
	#------------------------------------------
	my $CacheDistro;   # cache base name
	my @CachePatterns; # image patterns building the cache
	my @CachePackages; # image packages building the cache
	my $CacheScan;     # image scan, for cache package check
	#==========================================
	# Check boot type of the image
	#------------------------------------------
	my $name = $xml -> getImageName();
	if (($type{boot}) && ($type{boot} =~ /.*\/(.*)/)) {
		$CacheDistro = $1;
	} elsif (
		($type{type} =~ /ext2|cpio/) && ($name =~ /initrd-.*boot-(.*)/)
	) {
		$CacheDistro = $1;
	} else {
		$kiwi -> warning ("Can't setup cache without a boot type");
		$kiwi -> skipped ();
		undef $ImageCache;
		return undef;
	}
	#==========================================
	# Check for cachable patterns
	#------------------------------------------
	my @sections = ("bootstrap","image");
	foreach my $section (@sections) {
		my @list = $xml -> getList ($section);
		foreach my $pac (@list) {
			if ($pac =~ /^pattern:(.*)/) {
				push @CachePatterns,$1;
			} elsif ($pac =~ /^product:(.*)/) {
				# no cache for products at the moment
			} else {
				push @CachePackages,$pac;
			}
		}
	}
	if ((! @CachePatterns) && (! @CachePackages)) {
		$kiwi -> warning ("No cachable patterns/packages in this image");
		$kiwi -> skipped ();
		undef $ImageCache;
		return undef;
	}
	#==========================================
	# Create image package list
	#------------------------------------------
	$cmdL -> setConfigDir($mode);
	my $info = new KIWIXMLInfo($kiwi, $cmdL);
	my @infoReq = ('packages', 'sources');
	$CacheScan = $info -> getXMLInfoTree(\@infoReq);
	if (! $CacheScan) {
		undef $ImageCache;
		return undef;
	}
	#==========================================
	# Return result list
	#------------------------------------------
	return [
		$CacheDistro,\@CachePatterns,
		\@CachePackages,$CacheScan
	];
}

#==========================================
# selectCache
#------------------------------------------
sub selectCache {
	my $xml  = $_[0];
	my $init = $_[1];
	if ((! $init) || (! $ImageCache)) {
		return undef;
	}
	my $CacheDistro   = $init->[0];
	my @CachePatterns = @{$init->[1]};
	my @CachePackages = @{$init->[2]};
	my $CacheScan     = $init->[3];
	my $haveCache     = 0;
	my %plist         = ();
	my %Cache         = ();
	#==========================================
	# Search for a suitable cache
	#------------------------------------------
	my @packages = $CacheScan -> getElementsByTagName ("package");
	foreach my $node (@packages) {
		my $name = $node -> getAttribute ("name");
		my $arch = $node -> getAttribute ("arch");
		my $pver = $node -> getAttribute ("version");
		$plist{"$name-$pver.$arch"} = $name;
	}
	my $pcnt = keys %plist;
	my @file = ();
	#==========================================
	# setup cache file names...
	#------------------------------------------
	if (@CachePackages) {
		my $cstr = $xml -> getImageName();
		my $cdir = $ImageCache."/".$CacheDistro."-".$cstr.".ext2";
		push @file,$cdir;
	}
	foreach my $pattern (@CachePatterns) {
		my $cdir = $ImageCache."/".$CacheDistro."-".$pattern.".ext2";
		push @file,$cdir;
	}
	#==========================================
	# walk through cache files
	#------------------------------------------
	foreach my $clic (@file) {
		my $meta = $clic;
		$meta =~ s/\.ext2$/\.cache/;
		#==========================================
		# check cache files
		#------------------------------------------
		my $CACHE_FD;
		if (! open ($CACHE_FD,$meta)) {
			next;
		}
		#==========================================
		# read cache file
		#------------------------------------------
		my @cpac = <$CACHE_FD>; chomp @cpac;
		my $ccnt = @cpac; close $CACHE_FD;
		$kiwi -> loginfo (
			"Cache: $meta $ccnt packages, Image: $pcnt packages\n"
		);
		#==========================================
		# check validity of cache
		#------------------------------------------
		my $invalid = 0;
		if ($ccnt > $pcnt) {
			# cache is bigger than image solved list
			$invalid = 1;
		} else {
			foreach my $p (@cpac) {
				if (! defined $plist{$p}) {
					# cache package not part of image solved list
					$kiwi -> loginfo (
						"Cache: $meta $p not in image list\n"
					);
					$invalid = 1; last;
				}
			}
		}
		#==========================================
		# store valid cache
		#------------------------------------------
		if (! $invalid) {
			$Cache{$clic} = int (100 * ($ccnt / $pcnt));
			$haveCache = 1;
		}
	}
	#==========================================
	# Use/select cache if possible
	#------------------------------------------
	if ($haveCache) {
		my $max = 0;
		#==========================================
		# Find best match
		#------------------------------------------
		$kiwi -> info ("Cache list:\n");
		foreach my $clic (keys %Cache) {
			$kiwi -> info ("--> [ $Cache{$clic}% packages ]: $clic\n");
			if ($Cache{$clic} > $max) {
				$max = $Cache{$clic};
			}
		}
		#==========================================
		# Setup overlay for best match
		#------------------------------------------
		foreach my $clic (keys %Cache) {
			if ($Cache{$clic} == $max) {
				$kiwi -> info ("Using cache: $clic");
				$CacheRoot = $clic;
				$CacheRootMode = "union";
				$kiwi -> done();
				return $CacheRoot;
			}
		}
	}
	undef $ImageCache;
	return undef;
}

#==========================================
# createCache
#------------------------------------------
sub createCache {
	my $xml  = $_[0];
	my $init = $_[1];
	if ((! $init) || (! $ImageCache)) {
		return undef;
	}
	#==========================================
	# Variable setup and reset function
	#------------------------------------------
	my $resetVariables     = createResetClosure();
	my $CacheDistro        = $init->[0];
	my @CachePatterns      = @{$init->[1]};
	my @CachePackages      = @{$init->[2]};
	my $CacheScan          = $init->[3];
	my $imageCacheDir      = $ImageCache;
	my $imagePrepareDir    = $main::Prepare;
	#==========================================
	# undef ImageCache for recursive kiwi call
	#------------------------------------------
	undef $ImageCache;
	undef $InitCache;
	#==========================================
	# setup variables for kiwi prepare call
	#------------------------------------------
	qxx ("mkdir -p $imageCacheDir 2>&1");
	if (@CachePackages) {
		push @CachePatterns,"package-cache"
	}
	#==========================================
	# setup repositories for building
	#------------------------------------------
	$main::IgnoreRepos = 1;
	my @repos = $CacheScan -> getElementsByTagName ("source");
	foreach my $node (@repos) {
		my $path = $node -> getAttribute ("path");
		my $type = $node -> getAttribute ("type");
		push @main::AddRepository, $path;
		push @main::AddRepositoryType, $type;
	}
	#==========================================
	# walk through cachable patterns
	#------------------------------------------
	foreach my $pattern (@CachePatterns) {
		if ($pattern eq "package-cache") {
			$pattern = $xml -> getImageName();
			push @CachePackages,$xml->getPackageManager();
			undef @main::AddPattern;
			@main::AddPackage = @CachePackages;
			$kiwi -> info (
				"--> Building cache file for plain package list\n"
			);
		} else {
			@main::AddPackage = $xml->getPackageManager();
			@main::AddPattern = $pattern;
			$kiwi -> info (
				"--> Building cache file for pattern: $pattern\n"
			);
		}
		#==========================================
		# use KIWICache.kiwi for cache creation
		#------------------------------------------
		$main::Prepare      = $BasePath."/modules";
		$main::RootTree     = $imageCacheDir."/";
		$main::RootTree    .= $CacheDistro."-".$pattern;
		$main::Survive      = "yes";
		$main::ForceNewRoot = 1;
		undef @main::Profiles;
		undef $main::Create;
		undef $main::kiwi;
		#==========================================
		# Prepare new cache tree
		#------------------------------------------
		if (! defined main::main()) {
			&{$resetVariables}; return undef;
		}
		#==========================================
		# Create cache meta data
		#------------------------------------------
		my $meta   = $main::RootTree.".cache";
		my $root   = $main::RootTree;
		my $ignore = "'gpg-pubkey|bundle-lang'";
		my $rpmopts= "'%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n'";
		my $rpm    = "rpm --root $root";
		qxx ("$rpm -qa --qf $rpmopts | grep -vE $ignore > $meta");
		qxx ("rm -f $root/image/config.xml");
		qxx ("rm -f $root/image/*.kiwi");
		#==========================================
		# Turn cache into ext2 fs image
		#------------------------------------------
		$kiwi -> info (
			"--> Building ext2 cache...\n"
		);
		# /.../
		# tell the system that we are in cache mode
		# and prevent kernel extraction from image
		# cache
		# ----
		$InitCache = "active";
		my $cxml  = new KIWIXML ($kiwi,$BasePath."/modules");
		my $pkgMgr = $cmdL -> getPackageManager();
		if ($pkgMgr) {
			$cxml -> setPackageManager($pkgMgr);
		}
		my $image = new KIWIImage (
			$kiwi,$cxml,$root,$imageCacheDir,undef,"/base-system"
		);
		if (! defined $image) {
			&{$resetVariables}; return undef;
		}
		if (! $image -> createImageEXT2 ()) {
			&{$resetVariables}; return undef;
		}
		my $name= $imageCacheDir."/".$cxml -> buildImageName();
		qxx ("mv $name $main::RootTree.ext2");
		qxx ("rm -f  $name.ext2");
		qxx ("rm -f  $imageCacheDir/initrd-*");
		qxx ("rm -rf $main::RootTree");
		#==========================================
		# Reformat log file for human readers...
		#------------------------------------------
		$kiwi -> setLogHumanReadable();
		#==========================================
		# Move process log to final cache log...
		#------------------------------------------
		$kiwi -> finalizeLog();
		#==========================================
		# unset cache mode
		#------------------------------------------
		undef $InitCache;
	}
	&{$resetVariables};
	return $imageCacheDir;
}

#==========================================
# createResetClosure
#------------------------------------------
sub createResetClosure {
	my $backupSurvive           = $main::Survive;
	my @backupProfiles          = @main::Profiles;
	my $backupCreate            = $main::Create;
	my $backupPrepare           = $main::Prepare;
	my $backupRootTree          = $main::RootTree;
	my $backupForceNewRoot      = $main::ForceNewRoot;
	my @backupPatterns          = @main::AddPattern;
	my @backupPackages          = @main::AddPackage;
	my @backupRemovePackages    = @main::RemovePackage;
	my $backupIgnoreRepos       = $main::IgnoreRepos;
	my @backupAddRepository     = @main::AddRepository;
	my @backupAddRepositoryType = @main::AddRepositoryType;
	return sub {
		@main::Profiles          = @backupProfiles;
		$main::Prepare           = $backupPrepare;
		$main::Create            = $backupCreate;
		$main::ForceNewRoot      = $backupForceNewRoot;
		@main::AddPattern        = @backupPatterns;
		@main::AddPackage        = @backupPackages;
		@main::RemovePackage     = @backupRemovePackages;
		$main::IgnoreRepos       = $backupIgnoreRepos;
		@main::AddRepository     = @backupAddRepository;
		@main::AddRepositoryType = @backupAddRepositoryType;
		$main::RootTree          = $backupRootTree;
		$main::Survive           = $backupSurvive;
	}
}

#==========================================
# getMBRDiskLabel
#------------------------------------------
sub getMBRDiskLabel {
	# ...
	# set the mbrid to either the value given at the
	# commandline or a random 4byte MBR disk label ID
	# ---
	my $this  = shift;
	my $range = 0xfe;
	if (defined $main::MBRID) {
		return $main::MBRID;
	} else {
		my @bytes;
		for (my $i=0;$i<4;$i++) {
			$bytes[$i] = 1 + int(rand($range));
			redo if $bytes[0] <= 0xf;
		}
		my $nid = sprintf ("0x%02x%02x%02x%02x",
			$bytes[0],$bytes[1],$bytes[2],$bytes[3]
		);
		return $nid;
	}
}

#==========================================
# umountSystemFileSystems
#------------------------------------------
sub umountSystemFileSystems {
	# /.../
	# umount system filesystems like proc within the given
	# root tree. This is called after a custom script call
	# to cleanup the environment
	# ----
	my $root = shift;
	my @sysfs= ("/proc");
	if (! -d $root) {
		return;
	}
	foreach my $path (@sysfs) {
		qxx ("chroot $root umount -l $path 2>&1");
	}
	return $root;
}

main();

# vim: set noexpandtab:
