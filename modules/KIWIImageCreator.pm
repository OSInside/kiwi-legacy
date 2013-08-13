#================
# FILE          : KIWIImageCreator.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
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
use File::Basename;
use File::Spec;
require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWICommandLine;
use KIWIGlobals;
use KIWIImageBuildFactory;
use KIWIImageFormat;
use KIWILocator;
use KIWILog;
use KIWIProfileFile;
use KIWIQX qw (qxx);
use KIWIRoot;
use KIWIRuntimeChecker;
use KIWIXML;
use KIWIXMLDefStripData;
use KIWIXMLSystemdiskData;
use KIWIXMLValidator;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT_OK = qw ();

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
	my $cmdL = shift;
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if (! defined $cmdL) {
		my $msg = 'KIWIImageCreator: expecting KIWICommandLine object as '
			. 'argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{kiwi}  = $kiwi;
	$this->{cmdL}  = $cmdL;
	$this->{gdata} = $global -> getKiwiConfig();
	#==========================================
	# Store object data
	#------------------------------------------
	$this -> initialize();
	return $this;
}

#==========================================
# initialize
#------------------------------------------
sub initialize {
	my $this = shift;
	my $cmdL = $this->{cmdL};
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
	$this->{initrd}           = $cmdL -> getInitrdFile();
	$this->{sysloc}           = $cmdL -> getSystemLocation();
	$this->{disksize}         = $cmdL -> getImageDiskSize();
	$this->{targetdevice}     = $cmdL -> getImageTargetDevice();
	$this->{format}           = $cmdL -> getImageFormat();
	$this->{configDir}        = $cmdL -> getConfigDir();
	$this->{buildType}        = $cmdL -> getBuildType();
	return 1;
}

#==========================================
# getBootImageName
#------------------------------------------
sub getBootImageName {
	my $this = shift;
	return $this->{bootImageName};
}

#==========================================
# prepareBootImage
#------------------------------------------
sub prepareBootImage {
	# ...
	# Prepare the boot image
	# ---
	my $this       = shift;
	my $systemXML  = shift;
	my $rootTgtDir = shift;
	my $systemTree = shift;
	my $changeset  = shift;
	my $cmdL       = $this->{cmdL};
	my $kiwi       = $this->{kiwi};
	if (! $systemXML) {
		my $msg = 'prepareBootImage: no system XML description object given';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (ref($systemXML) ne 'KIWIXML') {
		my $msg = 'prepareBootImage: expecting KIWIXML object as first '
			. 'argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (! $rootTgtDir) {
		$kiwi -> error ('prepareBootImage: no root traget defined');
		$kiwi -> failed ();
		return;
	}
	if (! $systemTree) {
		$kiwi -> error ('prepareBootImage: no system image directory defined');
		$kiwi -> failed ();
		return;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return;
	}
	#==========================================
	# Determine the location of the boot image
	#------------------------------------------
	my $locator = KIWILocator -> instance();
	my $bootDescript = $systemXML -> getImageType() -> getBootImageDescript();
	if (! $bootDescript) {
		my $msg = 'prepareBootImage: error, trying to create a boot image '
			. 'for a type that has not boot description defined.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my $configDir = $locator -> getBootImageDescription($bootDescript);
	if (! $configDir) {
		return;
	}
	#==========================================
	# Read boot image description
	#------------------------------------------
	$kiwi -> info ("--> Prepare boot image (initrd)...\n");
	my $bootXML = KIWIXML -> new(
		$configDir,undef,undef,$cmdL,$changeset
	);
	if (! $bootXML) {
		return;
	}
	#==========================================
	# Store XML instance
	#------------------------------------------
	$this->{bootXML} = $bootXML;
	#==========================================
	# Store boot image name
	#------------------------------------------
	my $bootImageName = KIWIGlobals	-> instance()
		-> generateBuildImageName ($bootXML);
	$this->{bootImageName} = $bootImageName;
	#==========================================
	# Check for prebuild boot image
	#------------------------------------------
	my $pblt = $systemXML -> getImageType() -> getCheckPrebuilt();
	if (($pblt) && ($pblt eq "true")) {
		$kiwi -> info ("Checking for pre-built boot image");
		my $lookup = $configDir."-prebuilt/";
		my $prebuiltPath = $cmdL -> getPrebuiltBootImagePath();
		if (defined $prebuiltPath) {
			$lookup = $prebuiltPath."/";
		} else {
			my $defaultPath = $systemXML
				-> getPreferences() -> getDefaultPreBuilt();
			if ($defaultPath) {
				$lookup =  $defaultPath . '/';
			}
		}
		my $pinitrd = $lookup.$bootImageName.".gz";
		my $psplash;
		if (-f $lookup.$bootImageName.'.spl') {
			$psplash = $lookup.$bootImageName.'.spl';
		}
		my $plinux  = $lookup.$bootImageName.".kernel";
		if (! -f $pinitrd) {
			$pinitrd = $lookup.$bootImageName;
		}
		if ((! -f $pinitrd) || (! -f $plinux)) {
			$kiwi -> skipped();
			$kiwi -> info ("Can't find pre-built boot image in $lookup");
			$kiwi -> skipped();
		} else {
			$kiwi -> done();
			$kiwi -> info ("Found pre-built boot image, return early");
			$this->{prebuilt} = basename $pinitrd;
			$this->{psplash}  = $psplash;
			$this->{pinitrd}  = $pinitrd;
			$this->{plinux}   = $plinux;
			$kiwi -> done();
			return $this;
		}
	}
	#==========================================
	# Inherit system XML data to the boot
	#------------------------------------------
	#==========================================
	# merge/update repositories
	#------------------------------------------
	my $status = $bootXML -> discardReplacableRepos();
	if (! $status) {
		return;
	}
	my $repos = $systemXML -> getRepositories();
	$status = $bootXML -> addRepositories($repos, 'default');
	if (! $status) {
		return;
	}
	#==========================================
	# merge/update drivers
	#------------------------------------------
	my $drivers = $systemXML -> getDrivers();
	if ($drivers) {
		$status = $bootXML -> addDrivers($drivers, 'default');
		if (! $status) {
			return;
		}
	}
	#==========================================
	# merge/update strip
	#------------------------------------------
	my $res = $this -> __addStripDataToBootXML($systemXML, $bootXML);
	if (! $res) {
		return;
	}
	#==========================================
	# merge/update boot incl. packages/archives
	#------------------------------------------
	my $bootArchives = $systemXML -> getBootIncludeArchives();
	my $bootAddPacks = $systemXML -> getBootIncludePackages();
	my $bootDelPacks = $systemXML -> getBootDeletePackages();
	if (@{$bootArchives}) {
		$kiwi -> info ("Boot including archive(s) [bootstrap]:\n");
		for my $archive (@{$bootArchives}) {
			my $name = $archive -> getName();
			$kiwi -> info ("--> $name\n");
		}
		$bootXML -> addBootstrapArchives ($bootArchives);
	}
	if (@{$bootAddPacks}) {
		$kiwi -> info ("Boot including package(s) [bootstrap]:\n");
		for my $package (@{$bootAddPacks}) {
			my $name = $package -> getName();
			$kiwi -> info ("--> $name\n");
		}
		$bootXML -> addBootstrapPackages ($bootAddPacks);
	}
	if (@{$bootDelPacks}) {
		$kiwi -> info ("Boot included package(s) marked for deletion:\n");
		for my $package (@{$bootDelPacks}) {
			my $name = $package -> getName();
			$kiwi -> info ("--> $name\n");
		}
		$bootXML -> addPackagesToDelete ($bootDelPacks);
	}
	# TODO: more to come
	#==========================================
	# update boot profiles
	#------------------------------------------
	$bootXML -> setBootProfiles (
		$systemXML -> getBootProfile(),
		$systemXML -> getBootKernel()
	);
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$bootXML = $this -> __applyBaseXMLOverrides($bootXML);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	return $this -> __prepareTree (
		$bootXML,$configDir,$rootTgtDir,$systemTree
	);
}

#==========================================
# upgradeImage
#------------------------------------------
sub upgradeImage {
	my $this      = shift;
	my $upStatus  = shift;
	my $configDir = $this -> {configDir};
	my $kiwi      = $this -> {kiwi};
	my $cmdL      = $this -> {cmdL};
	if (! $configDir) {
		$kiwi -> error ('upgradeImage: no configuration directory defined');
		$kiwi -> failed ();
		return;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return;
	}
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	$configDir .= "/image";
	my $locator = KIWILocator -> instance();
	my $controlFile = $locator -> getControlFile ($configDir);
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	#==========================================
	# Read system image description
	#------------------------------------------
	$kiwi -> info ("Reading image description [Upgrade]...\n");
	my $buildProfs = $this -> {buildProfiles};
	my $xml = KIWIXML -> new(
		$configDir, undef, $buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	my $krc = KIWIRuntimeChecker -> new(
		$this -> {cmdL}, $xml
	);
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$xml = $this -> __applyBaseXMLOverrides($xml);
	$xml = $this -> __applyAdditionalXMLOverrides($xml);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	if (! $krc -> prepareChecks()) {
		return;
	}
	return $this -> __upgradeTree(
		$xml,$this->{configDir},$upStatus
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
	my $rootTgtDir= $this -> {rootTgtDir};
	my $kiwi      = $this -> {kiwi};
	my $cmdL      = $this -> {cmdL};
	if (! $configDir) {
		$kiwi -> error ('prepareImage: no configuration directory defined');
		$kiwi -> failed ();
		return;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return;
	}
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	my $locator = KIWILocator -> instance();
	my $controlFile = $locator -> getControlFile ($configDir);;
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	#==========================================
	# Read system image description
	#------------------------------------------
	$kiwi -> info ("Reading image description [Prepare]...\n");
	my $buildProfs = $this -> {buildProfiles};
	my $xml = KIWIXML -> new(
		$configDir, $this->{buildType}, $buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	my $krc = KIWIRuntimeChecker -> new(
		$this -> {cmdL}, $xml
	);
	#==========================================
	# Verify we have a prepare target directory
	#------------------------------------------
	if (! $rootTgtDir) {
		$kiwi -> info ("Checking for default root in XML data...");
		my $rootTgt =  $xml -> getImageDefaultRoot_legacy();
		if ($rootTgt) {
			$this -> {cmdL} -> setRootTargetDir($rootTgt);
			$this -> {rootTgtDir} = $rootTgt;
			$rootTgtDir = $rootTgt;
			$kiwi -> done();
		} else {
			my $msg = 'No target directory set for the unpacked image tree.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$xml = $this -> __applyBaseXMLOverrides($xml);
	$xml = $this -> __applyAdditionalXMLOverrides($xml);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	if (! $krc -> prepareChecks()) {
		return;
	}
	#==========================================
	# Remove cached repos for new build
	#------------------------------------------
	# The repo setup for the package managers smart and yum are cleaned
	# up at the end of each build by resetInstallationSource(). zypper
	# makes an exception here and we keep the repo setup for performance
	# reasons. Thus at the beginning a a new prepare run we should clean
	# up the repo files to match the new repos from the XML setup
	# ----
	qxx ("rm -f /var/cache/kiwi/zypper/repos/* 2>&1");
	#==========================================
	# Run prepare
	#------------------------------------------
	return $this -> __prepareTree(
		$xml,$this->{configDir},$rootTgtDir
	);
}

#==========================================
# createBootImage
#------------------------------------------
sub createBootImage {
	# ...
	# Create the boot image
	# ---
	my $this         = shift;
	my $systemXML    = shift;
	my $configDir    = shift;
	my $destination  = shift;
	my $kiwi         = $this->{kiwi};
	my $pkgMgr       = $this->{packageManager};
	my $ignore       = $this->{ignoreRepos};
	my $cmdL         = $this->{cmdL};
	my $bootXML      = $this->{bootXML};
	my $status;
	#==========================================
	# Check for prebuild boot image
	#------------------------------------------
	if ($this->{prebuilt}) {
		$kiwi -> info ("Copying pre-built boot image to destination");
		my $lookup = $this->{prebuilt};
		if (-f "$destination/$lookup") {
			#==========================================
			# Already exists in destination dir
			#------------------------------------------
			$kiwi -> done();
		} else {
			#==========================================
			# Needs to be copied...
			#------------------------------------------
			if ($this->{psplash}) {
				qxx ("cp -a $this->{psplash} $destination 2>&1");
			}
			my $data = qxx ("cp -a $this->{pinitrd} $destination 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$kiwi -> error ("Can't copy pre-built initrd: $data");
				$kiwi -> failed();
				return;
			} else {
				$data = qxx ("cp -a $this->{plinux}* $destination 2>&1");
				$code = $? >> 8;
				if ($code != 0) {
					$kiwi -> failed();
					$kiwi -> error ("Can't copy pre-built kernel: $data");
					$kiwi -> failed();
					return;
				} else {
					$kiwi -> done();
				}
			}
		}
		return $this;
	}
	#==========================================
	# Access boot image description
	#------------------------------------------
	$kiwi -> info ("--> Create boot image (initrd)...\n");
	if (! defined $bootXML) {
		return;
	}
	#==========================================
	# Inherit system XML data to the boot
	#------------------------------------------
	#==========================================
	# merge/update systemdisk
	#------------------------------------------
	my $systemdisk = $systemXML -> getSystemDiskConfig();
	if ($systemdisk) {
		my $lvmgroup = $systemdisk -> getVGName();
		if (! $lvmgroup) {
			$lvmgroup = 'kiwiVG';
		}
		my $sdk = KIWIXMLSystemdiskData -> new();
		$sdk -> setVGName ($lvmgroup);
		$bootXML -> addSystemDisk ($sdk);
	}
	#==========================================
	# merge/update drivers
	#------------------------------------------
	my $drivers = $systemXML -> getDrivers();
	if ($drivers) {
		$status = $bootXML -> addDrivers($drivers, 'default');
		if (! $status) {
			return;
		}
	}
	#==========================================
	# merge/update strip
	#------------------------------------------
	if (! $this -> __addStripDataToBootXML($systemXML, $bootXML)) {
		return;
	}
	#==========================================
	# merge/update machine attribs in type
	#------------------------------------------
	if (! $this -> __addVMachineDomainToBootXML ($systemXML, $bootXML)) {
		return;
	}
	#==========================================
	# merge/update oemconfig
	#------------------------------------------
	if (! $this -> __addOEMConfigDataToBootXML ($systemXML, $bootXML)) {
		return;
	}
	# TODO: more to come
	#==========================================
	# update boot profiles
	#------------------------------------------
	$bootXML -> setBootProfiles (
		$systemXML -> getBootProfile(),
		$systemXML -> getBootKernel()
	);
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$bootXML = $this -> __applyBaseXMLOverrides($bootXML);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	#==========================================
	# Create destdir if needed
	#------------------------------------------
	my $dirCreated = KIWIGlobals -> instance() -> createDirInteractive(
		$destination,$cmdL -> getDefaultAnswer()
	);
	if (! defined $dirCreated) {
		return;
	}
	#==========================================
	# Create KIWIImage object
	#------------------------------------------
	my $image = KIWIImage -> new(
		$bootXML,$configDir,$destination,undef,
		"/base-system",$configDir,undef,$cmdL
	);
	if (! defined $image) {
		return;
	}
	$this->{image} = $image;
	#==========================================
	# Update .profile environment
	#------------------------------------------
	if (! $this -> __updateProfileEnvironment ($bootXML,$destination)) {
		return;
	}
	#==========================================
	# Create cpio image
	#------------------------------------------
	if (! $image -> createImageCPIO()) {
		undef $image;
		return;
	}
	return 1;
}

#==========================================
# createImage
#------------------------------------------
sub createImage {
	# ...
	# Create the image
	# ---
	my $this         = shift;
	my $configDir    = $this -> {configDir};
	my $buildProfs   = $this -> {buildProfiles};
	my $kiwi         = $this -> {kiwi};
	my $pkgMgr       = $this -> {packageManager};
	my $ignore       = $this -> {ignoreRepos};
	my $cmdL         = $this -> {cmdL};
	my $targetDevice = $this -> {targetdevice};
	#==========================================
	# Check the tree first...
	#------------------------------------------
	if (! defined $configDir) {
		return;
	}
	if (-f "$configDir/.broken") {
		$kiwi -> error  ("Image root tree $configDir is broken");
		$kiwi -> failed ();
		return;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return;
	}
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	my $locator = KIWILocator -> instance();
	my $controlFile = $locator -> getControlFile ($configDir);
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	$kiwi -> info ("Reading image description [Create]...\n");
	my $xml = KIWIXML -> new(
		$configDir,$this->{buildType},
		$buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	my $krc = KIWIRuntimeChecker -> new(
		$cmdL,$xml
	);
	#==========================================
	# Check for default destination in XML
	#------------------------------------------
	if (! $cmdL -> getImageTargetDir()) {
		$kiwi -> info ("Checking for defaultdestination in XML data...");
		my $defaultDestination = $xml -> getPreferences() -> getDefaultDest();
		if (! $defaultDestination) {
			$kiwi -> failed ();
			$kiwi -> info   ("No destination directory specified");
			$kiwi -> failed ();
			return;
		}
		$cmdL -> setImageTargetDir ($defaultDestination);
		$kiwi -> done();
	}
	my $destination = $cmdL -> getImageTargetDir();
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$xml = $this -> __applyBaseXMLOverrides($xml);
	$xml = $this -> __applyAdditionalXMLOverrides($xml);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	if (! $krc -> createChecks()) {
		return;
	}
	#==========================================
	# Create destdir if needed
	#------------------------------------------
	my $dirCreated = KIWIGlobals -> instance() -> createDirInteractive(
		$destination,$cmdL -> getDefaultAnswer()
	);
	if (! defined $dirCreated) {
		return;
	}
	# /.../
	# The directory creation here will become obsolete when
	# all image creation code has been converted to the *Builder
	# infrastructure
	# ----
	my $type = $xml -> getImageType();
	my $typeName =  $type -> getTypeName();
	my $activeProfs = $xml -> getActiveProfileNames();
	my $workDirName = $typeName;
	for my $prof (@{$activeProfs}) {
		$workDirName .= '-' . $prof;
	}
	$destination .= "/" . $workDirName;
	if (-d $destination) {
		qxx ("rm -rf $destination 2>&1");
	}
	if ((! -d $destination) && (! mkdir $destination)) {
		$kiwi -> error  ("Failed to create destination subdir: $!");
		$kiwi -> failed ();
		return;
	}
	$cmdL -> setImageIntermediateTargetDir ($destination);
	# ----
	#==========================================
	# Check tool set
	#------------------------------------------
	my $para = $this -> __checkType ( $xml, $configDir );
	if (! defined $para) {
		return;
	}
	#==========================================
	# Check for packages updates if needed
	#------------------------------------------
	my @addonList;   # install this packages
	my @deleteList;  # remove this packages
	my $bootstrapPacks= $xml -> getBootstrapPackages();
	my $imagePackages = $xml -> getPackages();
	for my $package ((@{$bootstrapPacks},@{$imagePackages})) {
		if ($package -> getPackageToReplace()) {
			my $add = $package -> getName();
			my $del = $package -> getPackageToReplace();
			if ($del ne 'none') {
				push @deleteList,$del;
			}
			push @addonList ,$add;
		}
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
		$kiwi -> info ("Image update:\n");
		if (@addonList) {
			$kiwi -> info ("--> Install/Update: @addonList\n");
		}
		if (@deleteList) {
			$kiwi -> info ("--> Remove: @deleteList\n");
		}
		#==========================================
		# upgrade the tree
		#------------------------------------------
		my $addp = $cmdL -> getAdditionalPackages();
		my $delp = $cmdL -> getPackagesToRemove();
		if ($addp) {
			push @addonList,@{$addp};
		}
		if ($delp) {
			push @deleteList,@{$delp};
		}
		$cmdL -> setAdditionalPackages (\@addonList);
		$cmdL -> setPackagesToRemove (\@deleteList);
		my $kic  = KIWIImageCreator -> new($cmdL);
		if (! $kic) {
			return;
		}
		if (! $kic -> upgradeImage("NoDistUpgrade")) {
			return;
		}
		$cmdL -> setAdditionalPackages ([]);
		$cmdL -> setPackagesToRemove ([]);
	}
	#==========================================
	# Create KIWIImage object
	#------------------------------------------
	my $image = KIWIImage -> new(
		$xml,$configDir,$destination,$cmdL->getStripImage(),
		"/base-system",$configDir,undef,$cmdL
	);
	if (! defined $image) {
		return;
	}
	$this->{image} = $image;
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
	qxx ("rm -f $destination/config-cdroot.tgz");
	if (-f "$tree/image/config-cdroot.tgz") {
		qxx ("mv $tree/image/config-cdroot.tgz $destination");
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	qxx ("rm -f $destination/config-cdroot.sh");
	if (-f "$tree/image/config-cdroot.sh") {
		qxx ("mv $tree/image/config-cdroot.sh $destination");
	}
	#==========================================
	# Update .profile environment
	#------------------------------------------
	if (! $this -> __updateProfileEnvironment ($xml,$destination)) {
		return;
	}
	#==========================================
	# Create recovery archive if specified
	#------------------------------------------
	if ($typeName eq "oem") {
		my $filesys = $type -> getFilesystem();
		my $configure = KIWIConfigure -> new(
			$xml,$tree,$tree."/image",$destination
		);
		if (! defined $configure) {
			return;
		}
		if (! $configure -> setupRecoveryArchive ($filesys)) {
			return;
		}
	}
	#==========================================
	# Create package content and verification
	#------------------------------------------
	if (-f "$tree/var/lib/rpm/Packages") {
		$kiwi -> info ("Creating unpacked image tree meta data");
		my $idest = $cmdL -> getImageIntermediateTargetDir();
		my $query = '%{NAME}|%{VERSION}|%{RELEASE}|%{ARCH}|%{DISTURL}\n';
		my $name  = KIWIGlobals
			-> instance() -> generateBuildImageName($xml);
		my $path = File::Spec->rel2abs ($tree);
		qxx ("rpm --root $path -qa --qf \"$query\" &> $idest/$name.packages");
		my $result = $? >> 8;
		if ($result == 0) {
			qxx ("rpm --root $path -Va &> $idest/$name.verified");
		}
		if ($result != 0) {
			my $msg;
			$kiwi -> failed ();
			$msg  = 'meta data creation failed, ';
			$msg .= "see $idest/$name.packages for details";
			$kiwi -> warning ($msg);
			$kiwi -> skipped ();
		} else {
			$kiwi -> done();
		}
	}
	#==========================================
	# Build image using KIWIImageBuilder
	#------------------------------------------
	my $factory = KIWIImageBuildFactory -> new ($xml, $cmdL, $image);
	my $builder = $factory -> getImageBuilder();
	my $checkFormat = 0;
	my $status = 0;
	my $buildResultDir;
	if ($builder) {
		$status = $builder -> createImage();
		if ($status) {
			$buildResultDir = $builder -> getBaseBuildDirectory();
		}
	}
	#==========================================
	# Build image using KIWIImage
	#------------------------------------------
	if (! $status) {
		SWITCH: for ($typeName) {
			/^ext2/     && do {
				$status = $image -> createImageEXT2 ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^ext3/     && do {
				$status = $image -> createImageEXT3 ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^ext4/     && do {
				$status = $image -> createImageEXT4 ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^reiserfs/ && do {
				$status = $image -> createImageReiserFS ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^btrfs/    && do {
				$status = $image -> createImageBTRFS ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^squashfs/ && do {
				$status = $image -> createImageSquashFS ();
				last SWITCH;
			};
			/^clicfs/   && do {
				$status = $image -> createImageClicFS ();
				last SWITCH;
			};
			/^cpio/     && do {
				$status = $image -> createImageCPIO ();
				last SWITCH;
			};
			/^iso/      && do {
				$status = $image -> createImageLiveCD ( $para );
				last SWITCH;
			};
			/^split/    && do {
				$status = $image -> createImageSplit ( $para );
				last SWITCH;
			};
			/^vmx/      && do {
				$status = $image -> createImageVMX ( $para );
				last SWITCH;
			};
			/^oem/      && do {
				$status = $image -> createImageVMX ( $para );
				last SWITCH;
			};
			/^pxe/      && do {
				$status = $image -> createImagePXE ( $para );
				last SWITCH;
			};
			/^xfs/    && do {
				$status = $image -> createImageXFS ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			/^zfs/    && do {
				$status = $image -> createImageZFS ( $targetDevice );
				$checkFormat = 1;
				last SWITCH;
			};
			$kiwi -> error  ("Unsupported type: $typeName");
			$kiwi -> failed ();
			undef $image;
			return;
		}
	}
	if ($status) {
		my $imgName = KIWIGlobals
			-> instance()
			-> generateBuildImageName ($xml);
		my $imgFormat = $type -> getFormat();
		if ($checkFormat && $imgFormat) {
			my $imgfile= $destination."/".$imgName;
			my $format = KIWIImageFormat -> new(
				$imgfile,$cmdL,$imgFormat,$xml,$image->{targetDevice}
			);
			if (! $format) {
				return;
			}
			if (! $format -> createFormat()) {
				return;
			}
			$format -> createMachineConfiguration();
		}
		undef $image;
		#==========================================
		# Package build result into an archive
		#------------------------------------------
		my $basedest = dirname  $destination;
		if (! $buildResultDir) {
			$buildResultDir = $cmdL -> getImageIntermediateTargetDir();
		}
		my $basesubd = basename $buildResultDir;
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
				return;
			}
			$kiwi -> done();
		}
		#==========================================
		# Move build result(s) to destination dir
		#------------------------------------------
		my $status = qxx ("mv -f $buildResultDir/* $basedest 2>&1");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error (
				"Failed to move result image file(s) to destination: $status"
			);
			$kiwi -> failed ();
			return;
		}
		rmdir $buildResultDir;
		$kiwi -> info ("Find build results at: $basedest");
		$kiwi -> done ();
		return 1;
	} else {
		undef $image;
		return;
	}
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
	my $cmdL = $this->{cmdL};
	my $prof = $this->{buildProfiles};
	my $boot = KIWIBoot -> new (
		$ird,$cmdL,undef,undef,undef,$prof
	);
	if (! defined $boot) {
		return;
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
	my $cmdL = $this->{cmdL};
	my $prof = $this->{buildProfiles};
	$kiwi -> info ("Creating boot USB stick from: $ird...\n");
	my $boot = KIWIBoot -> new (
		$ird,$cmdL,undef,undef,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallStick()) {
		undef $boot;
		return;
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
	my $cmdL = $this->{cmdL};
	my $prof = $this->{buildProfiles};
	$kiwi -> info ("Creating boot ISO from: $ird...\n");
	my $boot = KIWIBoot -> new (
		$ird,$cmdL,undef,undef,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallCD()) {
		undef $boot;
		return;
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
	my $cmdL = $this->{cmdL};
	my $prof = $this->{buildProfiles};
	$kiwi -> info ("Creating install ISO from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new (
		$ird,$cmdL,$sys,undef,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallCD()) {
		undef $boot;
		return;
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
	my $cmdL = $this->{cmdL};
	my $prof = $this->{buildProfiles};
	$kiwi -> info ("Creating install Stick from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new (
		$ird,$cmdL,$sys,undef,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallStick()) {
		undef $boot;
		return;
	}
	undef $boot;
	return 1;
}

#==========================================
# createImageInstallPXE
#------------------------------------------
sub createImageInstallPXE {
	# ...
	# create all data required for OEM PXE install
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ird  = $this->{initrd};
	my $sys  = $this->{sysloc};
	my $cmdL = $this->{cmdL};
	my $prof = $this->{buildProfiles};
	$kiwi -> info ("Creating install PXE data set from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new (
		$ird,$cmdL,$sys,undef,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupInstallPXE()) {
		undef $boot;
		return;
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
	my $cmdL = $this->{cmdL};
	$kiwi -> info ("--> Creating boot VM disk from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No VM system image specified");
		$kiwi -> failed ();
		return;
	}
	qxx ( "file $sys | grep -q 'gzip compressed data'" );
	my $code = $? >> 8;
	if ($code == 0) {
		$kiwi -> failed ();
		$kiwi -> error  ("Can't use compressed VM system");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new(
		$ird,$cmdL,$sys,$size,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupBootDisk($tdev)) {
		return;
	}
	$boot -> cleanStack ();
	undef $boot;
	return 1;
}

#==========================================
# createImageFormat
#------------------------------------------
sub createImageFormat {
	my $this   = shift;
	my $xml    = shift;
	my $kiwi   = $this->{kiwi};
	my $format = $this->{format};
	my $sys    = $this->{sysloc};
	my $cmdL   = $this->{cmdL};
	$kiwi -> info ("--> Starting image format conversion...\n");
	my $imageformat = KIWIImageFormat -> new(
		$sys,$cmdL,$format,$xml,$this->{targetdevice}
	);
	if (! $imageformat) {
		return;
	}
	if (! $imageformat -> createFormat()) {
		return;
	}
	$imageformat -> createMachineConfiguration();
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __applyAdditionalXMLOverrides
#------------------------------------------
sub __applyAdditionalXMLOverrides {
	# ...
	# Apply XML overrides from command line applicable to some
	# procedures
	# ---
	my $this = shift;
	my $xml  = shift;
	my @addPacks;
	my @addCollections;
	my @delPacks;
	#==========================================
	# additional image packages
	#------------------------------------------
	if ($this -> {addlPackages}) {
		for my $name (@{$this -> {addlPackages}}) {
			my %pckgData = (
				name => $name
			);
			my $pckgObj = KIWIXMLPackageData
				-> new (\%pckgData);
			push @addPacks, $pckgObj;
		}
		$xml -> addPackages (\@addPacks);
	}
	#==========================================
	# additional image collections
	#------------------------------------------
	if ($this -> {addlPatterns}) {
		for my $name (@{$this -> {addlPatterns}}) {
			my %collectData = (
				name => $name
			);
			my $collectObj = KIWIXMLPackageCollectData
				-> new (\%collectData);
			push @addCollections, $collectObj;
		}
		$xml -> addPackageCollections (\@addCollections);
	}
	#==========================================
	# additional image packages to delete
	#------------------------------------------
	if ($this -> {removePackages}) {
		for my $name (@{$this -> {removePackages}}) {
			my %pckgData = (
				name => $name
			);
			my $pckgObj = KIWIXMLPackageData
				-> new (\%pckgData);
			push @delPacks, $pckgObj;
		}
		$xml -> addPackagesToDelete (\@addPacks);
	}
	return $xml;
}

#==========================================
# __applyBaseXMLOverrides
#------------------------------------------
sub __applyBaseXMLOverrides {
	# ...
	# Apply XML overrides from command line common to all procedures
	# ---
	my $this = shift;
	my $xml  = shift;
	if ($this -> {packageManager}) {
		$xml -> getPreferences() -> setPackageManager (
			$this -> {packageManager}
		);
	}
	if ($this -> {ignoreRepos}) {
		$xml -> ignoreRepositories();
	}
	if ($this->{addlRepos}) {
		$xml -> addRepositories($this->{addlRepos}, 'default');
	}
	if ($this -> {replRepo}) {
		$xml -> setRepository($this -> {replRepo});
	}
	return $xml;
}

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
			return;
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
	my $upStatus  = shift;
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
	my $root = KIWIRoot -> new(
		$xml,$configDir,undef,'/base-system',
		$configDir,$this->{addlPackages},$this->{removePackages},
		$cacheRoot,$this->{imageArch},
		$this->{cmdL}
	);
	if (! defined $root) {
		$kiwi -> error ("Couldn't create root object");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# store root pointer for destructor code
	#------------------------------------------
	$this->{root} = $root;
	#==========================================
	# Upgrade root system
	#------------------------------------------
	if (! $root -> upgrade ($upStatus)) {
		$kiwi -> error ("Image Upgrade failed");
		$kiwi -> failed ();
		return;
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
	my $cacheData = $configDir."/image/kiwi-root.cache";
	my $kiwi = $this -> {kiwi};
	my $cmdL = $this -> {cmdL};
	if ( ! $this -> {cacheDir}) {
		return;
	}
	if (($cacheMode eq "remount") && (! -f "$cacheData")) {
		return;
	}
	my $icache = KIWICache -> new(
		$xml,$this->{cacheDir},$this->{gdata}->{BasePath},
		$this->{buildProfiles},$configDir,$cmdL
	);
	if (! $icache) {
		return;
	}
	my $cacheInit = $icache -> initializeCache ($cmdL);
	if ($cacheInit) {
		return $icache->selectCache ($cacheInit);
	}
	return;
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
	my $systemTree = shift;
	my $kiwi       = $this -> {kiwi};
	my $cmdL       = $this -> {cmdL};
	my %attr       = %{$xml->getImageTypeAndAttributes_legacy()};
	my $cacheMode  = "initial";
	#==========================================
	# Select cache if requested and exists
	#------------------------------------------
	my $cacheRoot = $this -> __selectCache ($xml,$configDir,$cacheMode);
	if ($cacheRoot) {
		#==========================================
		# Add bootstrap packages to image section
		#------------------------------------------
		my $bootstrapPacks = $xml -> getBootstrapPackages();
		if (@{$bootstrapPacks}) {
			$xml -> addPackages ($bootstrapPacks);
		}
	}
	#==========================================
	# Check for setup of boot theme
	#------------------------------------------
	if ($attr{"type"} eq "cpio") {
		my @theme = $xml -> getBootTheme_legacy();
		if (@theme) {
			$kiwi -> info ("Using bootsplash theme: $theme[0]");
			$kiwi -> done ();
			$kiwi -> info ("Using bootloader theme: $theme[1]");
			$kiwi -> done ();
		} else {
			$kiwi -> warning ("No boot theme set, default is openSUSE");
			$kiwi -> done ();
		}
	}
	#==========================================
	# Initialize root system
	#------------------------------------------
	my $root = KIWIRoot -> new(
		$xml,$configDir,$rootTgtDir,'/base-system',
		$this -> {recycleRootDir},undef,undef,$cacheRoot,
		$this -> {imageArch},
		$this -> {cmdL}
	);
	if (! defined $root) {
		$kiwi -> error ("Couldn't create root object");
		$kiwi -> failed ();
		return;
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
		return;
	}
	#==========================================
	# Install root system
	#------------------------------------------
	if (! $root -> install ()) {
		$kiwi -> error ("Image installation failed");
		$kiwi -> failed ();
		return;
	}
	if (! $root -> installArchives ($systemTree)) {
		$kiwi -> error ("Archive installation failed");
		$kiwi -> failed ();
		return;
	}
	if (! $root -> setup ()) {
		$kiwi -> error ("Couldn't setup image system");
		$kiwi -> failed ();
		return;
	}
	if (! $xml -> writeXMLDescription_legacy ($root->getRootPath())) {
		$kiwi -> error ("Couldn't write XML description");
		$kiwi -> failed ();
		return;
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
	my $image= $this->{image};
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
		$boot -> cleanStack ();
		undef $boot;
	}
	if ($image) {
		$image -> cleanMount ();
	}
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
sub __addOEMConfigDataToBootXML {
	# ...
	# add the oemconfig information from the system XML data to the
	# boot XML data by cloning the oemconfig section. kiwi's boot
	# image descriptions does not contain oemconfig section data
	# thus it's ok to to just add a copy of the system XML oemconfig
	# section. The data is only copied if an oemconfig sectiom
	# exists in the system XML data set
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemXML = shift;
	my $bootXML   = shift;
	my $systemOEMconf = $systemXML -> getOEMConfig();
	if ($systemOEMconf) {
		$bootXML -> setOEMConfig ($systemOEMconf);
		my $data = $bootXML -> getOEMConfig() -> getDataReport();
		foreach my $key (keys %{$data}) {
			$kiwi -> info ("Updating OEM element $key: $data->{$key}");
			$kiwi -> done ();
		}
	}
	return $this;
}

#==========================================
# __addVMachineDomainToBootXML
#------------------------------------------
sub __addVMachineDomainToBootXML {
	# ...
	# add the domain information from the system XML data to the
	# boot XML data by cloning the machine section. kiwi's boot
	# image descriptions does not contain machine section data
	# thus it's ok to to just add a copy of the system XML machine
	# section. The data is only copied if the system XML machine
	# section contains a domain information
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemXML = shift;
	my $bootXML   = shift;
	my $systemVConf = $systemXML -> getVMachineConfig();
	if ($systemVConf) {
		my $domain = $systemVConf -> getDomain();
		if ($domain) {
			$kiwi -> info ("Updating machine attribute domain: $domain");
			$bootXML -> setVMachineConfig ($systemVConf);
			$kiwi -> done();
		}
	}
	return $this;
}

#==========================================
# __addStripDataToBootXML
#------------------------------------------
sub __addStripDataToBootXML {
	# ...
	# Add default strip data and the strip data from the user to the
	# boot image description.
	# ---
	my $this = shift;
	my $systemXML = shift;
	my $bootXML = shift;
	my $defStrip = KIWIXMLDefStripData -> new();
	# Add the default strip data
	$bootXML -> addFilesToDelete($defStrip -> getFilesToDelete());
	$bootXML -> addLibsToKeep($defStrip -> getLibsToKeep());
	$bootXML -> addToolsToKeep($defStrip -> getToolsToKeep());
	# Add the user defined strip data
	my $stripDelete = $systemXML -> getFilesToDelete();
	if ($stripDelete) {
		$bootXML -> addFilesToDelete ($stripDelete);
	}
	my $stripLibs = $systemXML -> getLibsToKeep();
	if ($stripLibs) {
		$bootXML -> addLibsToKeep ($stripLibs);
	}
	my $stripTools  = $systemXML -> getToolsToKeep();
	if ($stripTools) {
		$bootXML -> addToolsToKeep ($stripTools);
	}
	return 1;
}

#==========================================
# __checkType
#------------------------------------------
sub __checkType {
	# ...
	# Check the image type
	# ---
	my $this = shift;
	my $xml  = shift;
	my $root = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $type = $xml -> getImageType();
	my $para   = "ok";
	#==========================================
	# check for required image attributes
	#------------------------------------------
	if ($cmdL->getFatStorage()) {
		# /.../
		# if the option --fat-storage is set, we set grub2
		# as bootloader because it works well on USB sticks.
		# Additionally we use LVM because it allows to better
		# resize the stick
		# ----
		# Using the new data structure here does not work yet,
		# too much black magic, fix another time:
		# ----
		# $type -> setBootLoader('grub2');
		# $type -> setBootImageFileSystem('fat16');
		# $xml  -> updateType($type);
		# my $sysDisk = $xml -> getSystemDiskConfig();
		# if (! $sysDisk) {
		# 	%sysDisk = ();
		# 	$sDisk = KIWIXMLSystemdiskData -> new(\%sysDisk);
		# 	$xml -> addSystemDisk($sDisk);
		# 	$xml -> writeXML ($root . '/config.xml');
		# }
		# ----
		$xml -> __setTypeAttribute ("bootloader","grub2");
		$xml -> __setTypeAttribute ("bootfilesystem","fat16");
		$xml -> __setSystemDiskElement ();
		$xml -> writeXMLDescription_legacy ($root);
	} elsif ($cmdL->getLVM()) {
		# /.../
		# if the option --lvm is set, we add/update a systemdisk
		# element which triggers the use of LVM
		# ----
		# Using the new data structure here does not work yet,
		# too much black magic, fix another time:
		# ----
		# my $sysDisk = $xml -> getSystemDiskConfig();
		# if (! $sysDisk) {
		#	%sysDisk = ();
		#	$sDisk = KIWIXMLSystemdiskData -> new(\%sysDisk);
		#	$xml -> addSystemDisk($sDisk);
		# }
		# $xml -> writeXML ($root . '/config.xml');
		# ----
		$xml -> __setSystemDiskElement ();
		$xml -> writeXMLDescription_legacy ($root);
	}
	#==========================================
	# check for required filesystem tool(s)
	#------------------------------------------
	my $typeName   = $type -> getTypeName();
	my $flags      = $type -> getFlags();
	my $filesystem = $type -> getFilesystem();
	if (($flags) || ($filesystem)) {
		my @fs = ();
		if (($flags) && ($typeName eq "iso")) {
			push (@fs, $flags);
		} else {
			@fs = split (/,/, $filesystem);
		}
		foreach my $fs (@fs) {
			my %result = KIWIGlobals -> instance() -> checkFileSystem ($fs);
			if (%result) {
				if (! $result{hastool}) {
					$kiwi -> error (
						"Can't find filesystem tool for: $result{type}"
					);
					$kiwi -> failed ();
					return;
				}
			} else {
				$kiwi -> error ("Can't check filesystem attributes from: $fs");
				$kiwi -> failed ();
				return;
			}
		}
	}
	#==========================================
	# check tool/driver compatibility
	#------------------------------------------
	my $check_mksquashfs = 0;
	if ($typeName eq "squashfs") {
		$check_mksquashfs = 1;
	}
	my $instISO = $type -> getInstallIso();
	my $instStick = $type -> getInstallStick();
	if ( $instISO || $instStick ) {
		$check_mksquashfs = 1;
	}
	if (($filesystem) && ($filesystem =~ /squashfs/)) {
		$check_mksquashfs = 1;
	}
	if (($flags) && ($flags =~ /compressed/)) {
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
			my $msg = "--> squashfs tool/driver mismatch";
			if (($error == 2) && ($mktool_vs ne $module_vs)) {
				$kiwi -> error (
					"$msg: $mktool_vs vs $module_vs"
				);
				$kiwi -> failed ();
				return;
			}
		}
	}
	#==========================================
	# build and check KIWIImage method params
	#------------------------------------------
	my $bootImg = $type -> getBootImageDescript();
	SWITCH: for ($typeName) {
		/^iso/ && do {
			if (! $bootImg) {
				$kiwi -> error ("$typeName: No boot image specified");
				$kiwi -> failed ();
				return;
			}
			$para = $bootImg;
			if ((defined $flags) && ($flags ne "")) {
				$para .= ",$flags";
			} 
			last SWITCH;
		};
		/^split/ && do {
			my $fsro = $type -> getFSReadOnly();
			my $fsrw = $type -> getFSReadWrite();
			if (! $fsro || ! $fsrw) {
				$kiwi -> error ("$typeName: No filesystem pair specified");
				$kiwi -> failed ();
				return;
			}
			$para = "$fsrw,$fsro";
			if (defined $bootImg) {
				$para .= ":".$bootImg;
			}
			last SWITCH;
		};
		/^vmx|oem|pxe/ && do {
			if (! defined $filesystem) {
				$kiwi -> error ("$typeName: No filesystem specified");
				$kiwi -> failed ();
				return;
			}
			if (! defined $bootImg) {
				$kiwi -> error ("$typeName: No boot image specified");
				$kiwi -> failed ();
				return;
			}
			$para = $filesystem . ":" . $bootImg;
			last SWITCH;
		};
	}
	return $para;
}

#==========================================
# __updateProfileEnvironment
#------------------------------------------
sub __updateProfileEnvironment {
	# ...
	# update the contents of the .profile file due to
	# changes given on the command line e.g image type
	# or by inherited data when building boot (initrd)
	# images
	# ---
	my $this  = shift;
	my $xml   = shift;
	my $dest  = shift;
	my $kiwi  = $this->{kiwi};
	my $image = $this->{image};
	$kiwi -> info ("Updating .profile environment");
	my $tree = $image -> getImageTree();
	my $configure = KIWIConfigure -> new(
		$xml,$tree,$tree."/image",$dest
	);
	if (! defined $configure) {
		return;
	}
	# Add entries that are handled through the old data structure
	my %config = $xml -> getImageConfig_legacy();
	my $PFD = FileHandle -> new();
	if (! $PFD -> open (">$tree/.profile")) {
		$kiwi -> failed ();
		$kiwi -> error  ("Failed to open $tree/.profile: $!");
		$kiwi -> failed ();
		return;
	}
	binmode($PFD, ":encoding(UTF-8)");
	foreach my $key (keys %config) {
		$kiwi -> loginfo ("[PROFILE]: $key=\"$config{$key}\"\n");
		print $PFD "$key=\"$config{$key}\"\n";
	}
	$PFD -> close();
	# Add entries that are handled through the new XML data structure
	my $profile = KIWIProfileFile -> new();
	my $status;
	if (! $profile) {
		return;
	}
	$status = $profile -> updateFromHash (\%config);
	if (! $status) {
		return;
	}
	$status = $profile -> updateFromXML ($xml);
	if (! $status) {
		return;
	}
	$status = $profile -> writeProfile ($tree);
	if (! $status) {
		return;
	}
	$configure -> quoteFile ("$tree/.profile");
	if (-d "$tree/image") {
		qxx ("cp $tree/.profile $tree/image/.profile");
	}
	$kiwi -> done();
	return $this;
}

1;

