#================
# FILE          : KIWIImageCreator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to control the image creation process.
#               :
# STATUS        : Development
#----------------
package KIWIImageCreator;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIImageFormat;
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIRoot;
use KIWIRuntimeChecker;
use KIWIXML;
use KIWIXMLValidator;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the image creator object.
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
	my $kiwi = shift;
	my $cmdL = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if (! defined $cmdL) {
		my $msg = 'KIWIImageCreator: expecting KIWICommandLine object as '
			. 'second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{addlPackages}     = $cmdL -> getAdditionalPackages();
	$this->{addlPatterns}     = $cmdL -> getAdditionalPatterns();
	$this->{addlRepos}        = $cmdL -> getAdditionalRepos();
	$this->{buildProfiles}    = $cmdL -> getBuildProfiles();
	$this->{cacheDir}         = $cmdL -> getCacheDir();
	$this->{ignoreRepos}      = $cmdL -> getIgnoreRepos();
	$this->{imageArch}        = $cmdL -> getImageArchitecture();
	$this->{packageManager}   = $cmdL -> getPackageManager();
	$this->{recycleRootDir}   = $cmdL -> getRecycleRootDir();
	$this->{removePackages}   = $cmdL -> getPackagesToRemove();
	$this->{replRepo}         = $cmdL -> getReplacementRepo();
	$this->{rootTgtDir}       = $cmdL -> getRootTargetDir();
	$this->{rootInitrdTgtDir} = $cmdL -> getInitrdRootTargetDir();
	$this->{initrd}           = $cmdL -> getInitrdFile();
	$this->{sysloc}           = $cmdL -> getSystemLocation();
	$this->{disksize}         = $cmdL -> getImageDiskSize();
	$this->{targetdevice}     = $cmdL -> getImageTargetDevice();
	$this->{format}           = $cmdL -> getImageFormat();
	$this->{configDir}        = $cmdL -> getConfigDir();
	$this->{configInitrdDir}  = $cmdL -> getInitrdConfigDir();
	$this->{kiwi}             = $kiwi;
	$this->{cmdL}             = $cmdL;
	return $this;
}

#==========================================
# getBuildProfile
#------------------------------------------
sub getBuildProfile {
	# ...
	# Return the primary build profile (default build profile)
	# ---
}

#==========================================
# getBuildType
#------------------------------------------
sub getBuildType {
	# ...
	# Return the current build type
	# ---
}

#==========================================
# prepareBootImage
#------------------------------------------
sub prepareBootImage {
	# ...
	# Prepare the boot image
	# ---
	my $this       = shift;
	my $configDir  = $this->{configInitrdDir};
	my $rootTgtDir = $this->{rootInitrdTgtDir};
	my $kiwi       = $this->{kiwi};
	my $ignore     = $this -> {ignoreRepos};
	my $pkgMgr    = $this -> {packageManager};
	if (! $configDir) {
		$kiwi -> error ('prepareBootImage: no configuration directory defined');
		$kiwi -> failed ();
		return undef;
	}
	if (! -d $configDir) {
		my $msg = 'prepareBootImage: config dir "'
			. $configDir
			. '" does not exist';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return undef;
	}
	if (! $rootTgtDir) {
		$kiwi -> error ('prepareBootImage: no root traget defined');
		$kiwi -> failed ();
		return undef;
	}
	$kiwi -> info ("Prepare boot image (initrd)...\n");
	my $xml = new KIWIXML (
		$kiwi,$configDir,undef,undef
	);
	if (! defined $xml) {
		return undef;
	}
	return $this -> __prepareTree (
		$xml, $configDir, $rootTgtDir
	);
}

#==========================================
# upgradeImage
#------------------------------------------
sub upgradeImage {
	my $this      = shift;
	my $configDir = $this -> {configDir};
	my $kiwi      = $this -> {kiwi};
	my $ignore    = $this -> {ignoreRepos};
	if (! $configDir) {
		$kiwi -> error ('prepareBootImage: no configuration directory defined');
		$kiwi -> failed ();
		return undef;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return undef;
	}
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	$configDir .= "/image";
	my $locator = new KIWILocator($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);
	if (! $controlFile) {
		return undef;
	}
	my $validator = new KIWIXMLValidator (
		$kiwi,$controlFile,$main::Revision,$main::Schema,$main::SchemaCVT
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return undef;
	}
	$kiwi -> info ("Reading image description [Upgrade]...\n");
	my $buildProfs = $this -> {buildProfiles};
	my $xml = new KIWIXML (
		$kiwi, $configDir, undef, $buildProfs
	);
	if (! defined $xml) {
		return undef;
	}
	my $krc = new KIWIRuntimeChecker (
		$kiwi, $this -> {cmdL}, $xml
	);
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	if ($ignore) {
		$xml -> ignoreRepositories ();
	}
	if ($this -> {addlPackages}) {
		$xml -> addImagePackages (@{$this -> {addlPackages}});
	}
	if ($this -> {addlPatterns}) {
		$xml -> addImagePatterns (@{$this -> {addlPatterns}});
	}
	if ($this -> {addlRepos}) {
		my %addlRepos = %{$this -> {addlRepos}};
		$xml -> addRepository (
			$addlRepos{repositoryTypes},
			$addlRepos{repositories},
			$addlRepos{repositoryAlia},
			$addlRepos{repositoryPriorities}
		);
	}
	if ($this -> {removePackages}) {
		$xml -> addRemovePackages (@{$this -> {removePackages}});
	}
	if ($this -> {replRepo}) {
		my %replRepo = %{$this -> {replRepo}};
		$xml -> setRepository (
			$replRepo{repositoryType},
			$replRepo{repository},
			$replRepo{repositoryAlias},
			$replRepo{respositoryPriority}
		);
	}
	if (! $krc -> prepareChecks()) {
		return undef;
	}
	return $this -> __upgradeTree(
		$xml,$this->{configDir}
	);
}

#==========================================
# prepareImage
#------------------------------------------
sub prepareImage {
	# ...
	# Prepare the image
	# ---
	my $this      = shift;
	my $configDir = $this -> {configDir};
	my $kiwi      = $this -> {kiwi};
	my $pkgMgr    = $this -> {packageManager};
	my $ignore    = $this -> {ignoreRepos};
	if (! $configDir) {
		$kiwi -> error ('prepareBootImage: no configuration directory defined');
		$kiwi -> failed ();
		return undef;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return undef;
	}
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	my $locator = new KIWILocator($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);;
	if (! $controlFile) {
		return undef;
	}
	my $validator = new KIWIXMLValidator (
		$kiwi,$controlFile,$main::Revision,$main::Schema,$main::SchemaCVT
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return undef;
	}
	$kiwi -> info ("Reading image description [Prepare]...\n");
	my $buildProfs = $this -> {buildProfiles};
	my $xml = new KIWIXML (
		$kiwi, $configDir, undef, $buildProfs
	);
	if (! defined $xml) {
		return undef;
	}
	my $krc = new KIWIRuntimeChecker (
		$kiwi, $this -> {cmdL}, $xml
	);
	#==========================================
	# Verify we have a prepare target directory
	#------------------------------------------
	if (! $this -> {rootTgtDir}) {
		$kiwi -> info ("Checking for default root in XML data...");
		my $rootTgt =  $xml -> getImageDefaultRoot();
		if ($rootTgt) {
			$this -> {cmdL} -> setRootTargetDir($rootTgt);
			$this -> {rootTgtDir} = $this -> {cmdL} -> getRootTargetDir();
			$kiwi -> done();
		} else {
			my $msg = 'No target directory set for the unpacked image tree.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return undef;
		}
	}
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	if ($pkgMgr) {
		$xml -> setPackageManager($pkgMgr);
	}
	if ($ignore) {
		$xml -> ignoreRepositories ();
	}
	if ($this -> {addlPackages}) {
		$xml -> addImagePackages (@{$this -> {addlPackages}});
	}
	if ($this -> {addlPatterns}) {
		$xml -> addImagePatterns (@{$this -> {addlPatterns}});
	}
	if ($this -> {addlRepos}) {
		my %addlRepos = %{$this -> {addlRepos}};
		$xml -> addRepository (
			$addlRepos{repositoryTypes},
			$addlRepos{repositories},
			$addlRepos{repositoryAlia},
			$addlRepos{repositoryPriorities}
		);
	}
	if ($this -> {removePackages}) {
		$xml -> addRemovePackages (@{$this -> {removePackages}});
	}
	if ($this -> {replRepo}) {
		my %replRepo = %{$this -> {replRepo}};
		$xml -> setRepository (
			$replRepo{repositoryType},
			$replRepo{repository},
			$replRepo{repositoryAlias},
			$replRepo{respositoryPriority}
		);
	}
	if (! $krc -> prepareChecks()) {
		return undef;
	}
	return $this -> __prepareTree(
		$xml,$this->{configDir},$this->{rootTgtDir}
	);
}

#==========================================
# createSplash
#------------------------------------------
sub createSplash {
	# ...
	# create a splash screen on the stored initrd file
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	my $boot = new KIWIBoot ($kiwi,$ird);
	if (! defined $boot) {
		return undef;
	}
	$this->{boot} = $boot;
	$boot -> setupSplash();
	undef $boot;
	return 1;
}

#==========================================
# createImageBootUSB
#------------------------------------------
sub createImageBootUSB {
	# ...
	# create a bootable USB stick with the stored initrd
	# file. Note That this only creates a stick running the
	# initrd and not more
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	$kiwi -> info ("Creating boot USB stick from: $ird...\n");
	my $boot = new KIWIBoot ($kiwi,$ird);
	if (! defined $boot) {
		return undef;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallStick()) {
		undef $boot;
		return undef;
	}
	undef $boot;
	return 1;
}

#==========================================
# createImageBootCD
#------------------------------------------
sub createImageBootCD {
	# ...
	# create a bootable CD with the stored initrd
	# file. Note That this only creates a boot CD running the
	# initrd and not more
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	$kiwi -> info ("Creating boot ISO from: $ird...\n");
	my $boot = new KIWIBoot ($kiwi,$ird);
	if (! defined $boot) {
		return undef;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallCD()) {
		undef $boot;
		return undef;
	}
	undef $boot;
	return 1;
}

#==========================================
# createImageInstallCD
#------------------------------------------
sub createImageInstallCD {
	# ...
	# create an OEM install CD
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	my $sys  = $this->{sysloc};
	$kiwi -> info ("Creating install ISO from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return undef;
	}
	my $boot = new KIWIBoot ($kiwi,$ird,$sys);
	if (! defined $boot) {
		return undef;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallCD()) {
		undef $boot;
		return undef;
	}
	undef $boot;
	return 1;
}

#==========================================
# createImageInstallStick
#------------------------------------------
sub createImageInstallStick {
	# ...
	# create an OEM install Stick
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	my $sys  = $this->{sysloc};
	$kiwi -> info ("Creating install Stick from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return undef;
	}
	my $boot = new KIWIBoot ($kiwi,$ird,$sys);
	if (! defined $boot) {
		return undef;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallStick()) {
		undef $boot;
		return undef;
	}
	undef $boot;
	return 1;
}

#==========================================
# createImageDisk
#------------------------------------------
sub createImageDisk {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	my $sys  = $this->{sysloc};
	my $size = $this->{disksize};
	my $tdev = $this->{targetdevice};
	my $prof = $this->{buildProfiles};
	$kiwi -> info ("--> Creating boot VM disk from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No VM system image specified");
		$kiwi -> failed ();
		return undef;
	}
	qxx ( "file $sys | grep -q 'gzip compressed data'" );
	my $code = $? >> 8;
	if ($code == 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Can't use compressed VM system");
		$kiwi -> failed ();
		return undef;
	}
	my $boot = new KIWIBoot (
		$kiwi,$ird,$sys,$size,undef,$prof
	);
	if (! defined $boot) {
		return undef;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupBootDisk($tdev)) {
		undef $boot;
		return undef;
	}
	undef $boot;
	return 1;
}

#==========================================
# createImageFormat
#------------------------------------------
sub createImageFormat {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $sys    = $this->{sysloc};
	$kiwi -> info ("--> Starting image format conversion...\n");
	my $imageformat = new KIWIImageFormat ($kiwi,$sys,$format);
	if (! $imageformat) {
		return undef;
	}
	$imageformat -> createFormat();
	$imageformat -> createMaschineConfiguration();
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __checkImageIntegrity
#------------------------------------------
sub __checkImageIntegrity {
	# ...
	# Check the image description integrity if a checksum file exists
	# ---
	my $this = shift;
	my $configDir = $this -> {configDir};
	my $kiwi = $this -> {kiwi};
	my $checkmdFile = $configDir . '/.checksum.md5';
	if (-f $checkmdFile) {
		my $data = qxx ("cd $configDir && md5sum -c .checksum.md5 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			chomp $data;
			$kiwi -> error ("Integrity check for $configDir failed:\n$data");
			$kiwi -> failed ();
			return undef;
		}
	} else {
		$kiwi -> info ("Description provides no MD5 hash, check\n");
	}
	return 1;
}
#==========================================
# __upgradeTree
#------------------------------------------
sub __upgradeTree {
	# ...
	# Upgrade the existing tree using the packagemanager
	# upgrade functionality
	# ---
	my $this      = shift;
	my $xml       = shift;
	my $configDir = shift;
	my $kiwi      = $this -> {kiwi};
	my $cmdL      = $this -> {cmdL};
	my $cacheMode = "remount";
	#==========================================
	# Select cache if requested and exists
	#------------------------------------------
	my $cacheRoot = $this -> __selectCache ($xml,$configDir,$cacheMode);
	#==========================================
	# Initialize root system
	#------------------------------------------
	my $root = new KIWIRoot (
		$kiwi,$xml,$configDir,undef,'/base-system',
		$configDir,$this->{addlPackages},$this->{removePackages},
		$cacheRoot,$this->{imageArch},
		$this->{cmdL}
	);
	if (! defined $root) {
		$kiwi -> error ("Couldn't create root object");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# store root pointer for destructor code
	#------------------------------------------
	$this->{root} = $root;
	#==========================================
	# Upgrade root system
	#------------------------------------------
	if (! $root -> upgrade ()) {
		$kiwi -> error ("Image Upgrade failed");
		$kiwi -> failed ();
		return undef;
	}
	$this -> DESTROY(1);
	return 1;
}

#==========================================
# __selectCache
#------------------------------------------
sub __selectCache {
	my $this      = shift;
	my $xml       = shift;
	my $configDir = shift;
	my $cacheMode = shift;
	my $kiwi = $this -> {kiwi};
	my $cmdL = $this -> {cmdL};
	if ( ! $this -> {cacheDir}) {
		return undef;
	}
	if (($cacheMode eq "remount") && (! -f "$configDir/kiwi-root.cache")) {
		return undef;
	}
	my $icache = new KIWICache (
		$kiwi,$xml,$this->{cacheDir},$main::BasePath,
		$this->{buildProfiles},$configDir
	);
	if (! $icache) {
		return undef;
	}
	my $cacheInit = $icache -> initializeCache ($cmdL);
	if ($cacheInit) {
		return $icache->selectCache ($cacheInit);
	}
	return undef;
}

#==========================================
# __prepareTree
#------------------------------------------
sub __prepareTree {
	# ...
	# Prepare the tree for the specified configuration file
	# ---
	my $this       = shift;
	my $xml        = shift;
	my $configDir  = shift;
	my $rootTgtDir = shift;
	my $kiwi       = $this -> {kiwi};
	my $cmdL       = $this -> {cmdL};
	my %attr       = %{$xml->getImageTypeAndAttributes()};
	my $cacheMode  = "initial";
	#==========================================
	# Select cache if requested and exists
	#------------------------------------------
	my $cacheRoot = $this -> __selectCache ($xml,$configDir,$cacheMode);
	if ($cacheRoot) {
		#==========================================
		# Add bootstrap packages to image section
		#------------------------------------------
		my @initPacs = $xml -> getBaseList();
		if (@initPacs) {
			$xml -> addImagePackages (@initPacs);
		}
	}
	#==========================================
	# Check for setup of boot theme
	#------------------------------------------
	if ($attr{"type"} eq "cpio") {
		my $theme = $xml -> getBootTheme();
		if ($theme) {
			$kiwi -> info ("Using boot theme: $theme");
		} else {
			$kiwi -> warning ("No boot theme set, default is openSUSE");
		}
		$kiwi -> done ();
	}
	#==========================================
	# Initialize root system
	#------------------------------------------
	my $root = new KIWIRoot (
		$kiwi,$xml,$configDir,$rootTgtDir,'/base-system',
		$this -> {recycleRootDir},undef,undef,$cacheRoot,
		$this -> {imageArch},
		$this -> {cmdL}
	);
	if (! defined $root) {
		$kiwi -> error ("Couldn't create root object");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# store root pointer for destructor code
	#------------------------------------------
	$this->{root} = $root;
	#==========================================
	# Initialize root system
	#------------------------------------------
	if (! defined $root -> init ()) {
		$kiwi -> error ("Base initialization failed");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Install root system
	#------------------------------------------
	if (! $root -> install ()) {
		$kiwi -> error ("Image installation failed");
		$kiwi -> failed ();
		return undef;
	}
	if (! $root -> installArchives ()) {
		$kiwi -> error ("Archive installation failed");
		$kiwi -> failed ();
		return undef;
	}
	if (! $root -> setup ()) {
		$kiwi -> error ("Couldn't setup image system");
		$kiwi -> failed ();
		return undef;
	}
	if (! $xml -> writeXMLDescription ($root->getRootPath())) {
		$kiwi -> error ("Couldn't write XML description");
		$kiwi -> failed ();
		return undef;
	}
	#==========================================
	# Clean up
	#------------------------------------------
	$this -> DESTROY(1);
	return 1;
}

#==========================================
# Destructor
#------------------------------------------
sub DESTROY {
	my $this = shift;
	my $ok   = shift;
	my $root = $this->{root};
	my $boot = $this->{boot};
	if ($root) {
		if ($ok) {
			$root -> cleanBroken ();
		}
		$root -> cleanLock   ();
		$root -> cleanManager();
		$root -> cleanSource ();
		$root -> cleanMount  ();
		undef $root;
	}
	if ($boot) {
		undef $boot;
	}
}

1;
