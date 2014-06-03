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
use KIWIQX;
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
	if ( ! $this -> initialize()) {
		return;
	}
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
	#==========================================
	# Store default image type
	#------------------------------------------
	if (! $this->{buildType}) {
		my $xml = KIWIXML -> new(
			$this->{configDir},undef,
			$this->{buildProfiles}, $this->{cmdL}
		);
		if ($xml) {
			my $type = $xml -> getImageType();
			if ($type) {
				$this->{buildType} = $type -> getTypeName();
			}
		}
	}
	#==========================================
	# Store selected image type
	#------------------------------------------
	if (($this->{buildType}) && (! $cmdL->getOperationMode("convert"))) {
		my $configDir = $this->{configDir};
		if (! $configDir) {
			$configDir = $cmdL -> getSystemLocation();
		}
		my $xml = KIWIXML -> new(
			$configDir, $this->{buildType},
			$this->{buildProfiles}, $this->{cmdL}
		);
		if (! $xml) {
			return;
		}
		my $xmltype = $xml -> getImageType();
		if (! $xmltype) {
			return;
		}
		$this->{selectedBuildType}= $xmltype -> getTypeName();
		$this->{systemXML} = $xml;
	}
	return 1;
}

#==========================================
# getSelectedBuildType
#------------------------------------------
sub getSelectedBuildType {
	my $this = shift;
	return $this->{selectedBuildType};
}

#==========================================
# getSystemXML
#------------------------------------------
sub getSystemXML {
	my $this = shift;
	return $this->{systemXML};
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
	my $xmltype = $systemXML -> getImageType();
	my $buildtype = $xmltype -> getTypeName();
	my $bootDescript = $xmltype -> getBootImageDescript();
	if ((! $bootDescript) && ($buildtype ne 'cpio')) {
		my $msg = 'prepareBootImage: error, trying to create a boot image '
			. 'for a type that has no boot description defined.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my $configDir;
	if ($bootDescript) {
		$configDir = $locator -> getBootImageDescription($bootDescript);
	} else {
		$configDir = $cmdL -> getConfigDir();
	}
	if (! $configDir) {
		return;
	}
	#==========================================
	# Read boot image description
	#------------------------------------------
	$kiwi -> info ("--> Prepare boot image (initrd)...\n");
	my $bootXML;
	if ($bootDescript) {
		$bootXML = KIWIXML -> new(
			$configDir,undef,undef,$cmdL
		);
	} else {
		$bootXML = $systemXML;
	}
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
		my $pinitrd = $lookup.$bootImageName.".".$this->{gdata}->{IrdZipperSuffix};
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
	# Add default strip information
	#------------------------------------------
	$this -> __addDefaultStripData ($bootXML);
	#==========================================
	# Inherit system XML data to the boot
	#------------------------------------------
	if ($bootDescript) {
		#==========================================
		# merge/update displayname
		#------------------------------------------
		my $displayname = $systemXML -> getImageDisplayName();
		if ($displayname) {
			$kiwi -> info (
				"Updating image attribute: displayname: $displayname"
			);
			$bootXML -> setImageDisplayName ($displayname);
			$kiwi -> done();
		}
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
		if (! $this -> __addStripDataToBootXML($systemXML, $bootXML)) {
			return;
		}
		#==========================================
		# merge/update preferences
		#------------------------------------------
		if (! $this -> __addPreferencesToBootXML ($systemXML, $bootXML)) {
			return;
		}
		#==========================================
		# merge/update boot incl. packages/archives
		#------------------------------------------
		if (! $this -> __addPackagesToBootXML ($systemXML, $bootXML)) {
			return;
		}
		#==========================================
		# merge/update type
		#------------------------------------------
		if (! $this -> __addTypeToBootXML ($systemXML, $bootXML)) {
			return;
		}
		#==========================================
		# merge/update systemdisk
		#------------------------------------------
		if (! $this -> __addSystemDiskToBootXML ($systemXML, $bootXML)) {
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
		#==========================================
		# update boot profiles
		#------------------------------------------
		$bootXML -> setBootProfiles (
			$systemXML -> getBootProfile(),
			$systemXML -> getBootKernel()
		);
	}
	$this -> __printProfileInfo ($bootXML,'Using boot profile(s):');
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$bootXML = $this -> __applyBaseXMLOverrides($bootXML);
	$bootXML = $this -> __applyAdditionalXMLOverrides($bootXML);
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
		$configDir, $this->{buildType}, $buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	$this -> __printProfileInfo ($xml);
	my $krc = KIWIRuntimeChecker -> new(
		$this -> {cmdL}, $xml
	);
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$xml = $this -> __applyBaseXMLOverrides($xml);
	$xml = $this -> __applyAdditionalXMLOverrides($xml);
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
	$this -> __printProfileInfo ($xml);
	my $krc = KIWIRuntimeChecker -> new(
		$this -> {cmdL}, $xml
	);
	#==========================================
	# Verify we have a prepare target directory
	#------------------------------------------
	if (! $rootTgtDir) {
		$kiwi -> info ("Checking for default root in XML data...");
		my $rootTgt;
		my $pref = $xml -> getPreferences();
		if ($pref) {
			$rootTgt = $pref -> getDefaultRoot();
		}
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
	KIWIQX::qxx ("rm -f /var/cache/kiwi/zypper/repos/* 2>&1");
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
				KIWIQX::qxx ("cp -a $this->{psplash} $destination 2>&1");
			}
			my $data = KIWIQX::qxx ("cp -a $this->{pinitrd} $destination 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed();
				$kiwi -> error ("Can't copy pre-built initrd: $data");
				$kiwi -> failed();
				return;
			} else {
				$data = KIWIQX::qxx ("cp -a $this->{plinux}* $destination 2>&1");
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
		# /.../
		# if only the initrd is build by local kiwi commands
		# on the commandline, the systemXML is the same as the
		# boot XML
		# ----
		$bootXML = $this->{systemXML};
		if (! defined $bootXML) {
			return;
		}
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
	$this -> __printProfileInfo ($xml);
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
		KIWIQX::qxx ("rm -rf $destination 2>&1");
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
	my $para = KIWIGlobals
		-> instance() -> checkType ( $xml,$configDir,$cmdL );
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
		KIWIQX::qxx ("rm -f $tree/rootfs.tar");
	}
	if (-f "$tree/recovery.tar.gz") {
		KIWIQX::qxx ("rm -f $tree/recovery.*");
	}
	#==========================================
	# Check for optional config-cdroot archive
	#------------------------------------------
	KIWIQX::qxx ("rm -f $destination/config-cdroot.tgz");
	if (-f "$tree/image/config-cdroot.tgz") {
		KIWIQX::qxx ("mv $tree/image/config-cdroot.tgz $destination");
	}
	#==========================================
	# Check for optional config-cdroot.sh
	#------------------------------------------
	KIWIQX::qxx ("rm -f $destination/config-cdroot.sh");
	if (-f "$tree/image/config-cdroot.sh") {
		KIWIQX::qxx ("mv $tree/image/config-cdroot.sh $destination");
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
		my $query = '%{NAME}|%{EPOCH}|%{VERSION}|'
			. '%{RELEASE}|%{ARCH}|%{DISTURL}\n';
		my $name  = KIWIGlobals
			-> instance() -> generateBuildImageName($xml);
		my $path = File::Spec->rel2abs ($tree);
		KIWIQX::qxx (
			"rpm --root $path -qa --qf \"$query\" &> $idest/$name.packages"
		);
		my $result = $? >> 8;
		if ($result == 0) {
			KIWIQX::qxx (
				"rpm --root $path -Va &> $idest/$name.verified"
			);
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
	# Create build result information
	#------------------------------------------
	KIWIGlobals -> instance()
		-> generateBuildInformation($xml, $cmdL);
	#==========================================
	# Add system strip from bootincludes
	#------------------------------------------
	$this -> __addBootincludedToolsToKeep ($xml, $tree);
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
			my $status = KIWIQX::qxx (
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
		my $status = KIWIQX::qxx ("mv -f $buildResultDir/* $basedest 2>&1");
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
	if (! $this -> __isInstallBootImage($ird)) {
		$kiwi -> error  ("Given boot image has no install code");
		$kiwi -> failed ();
		return;
	}
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
	if (! $this -> __isInstallBootImage($ird)) {
		$kiwi -> error  ("Given boot image has no install code");
		$kiwi -> failed ();
		return;
	}
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
	if (! $this -> __isInstallBootImage($ird)) {
		$kiwi -> error  ("Given boot image has no install code");
		$kiwi -> failed ();
		return;
	}
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
	KIWIQX::qxx ( "file $sys | grep -q 'gzip compressed data'" );
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
sub __isInstallBootImage {
	# ...
	# Test a given boot image (cpio) if it contains the dump
	# file which is kiwi's code to install images. If yes the
	# boot image has install capabilities
	# ---
	my $this = shift;
	my $boot = shift;
	my $data = KIWIQX::qxx ("gzip -cd $boot | cpio -it | grep -q ^dump$ 2>&1");
	my $code = $? >> 8;
	if ($code != 0) {
		return;
	}
	return 1;
}

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
		my $data = KIWIQX::qxx ("cd $configDir && md5sum -c .checksum.md5 2>&1");
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
	my $type       = $xml -> getImageType() -> getTypeName();
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
	if ($type eq "cpio") {
		my $pref  = $xml -> getPreferences();
		my $splash_theme = $pref -> getBootSplashTheme();
		my $loader_theme = $pref -> getBootLoaderTheme();
		if ($splash_theme) {
			$kiwi -> info ("Using bootsplash theme: $splash_theme");
			$kiwi -> done ();
		}
		if ($loader_theme) {
			$kiwi -> info ("Using bootloader theme: $loader_theme");
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
sub __addPackagesToBootXML {
	# ...
	# add boot included packages/archives information
	# from the system XML data to the boot XML data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemXML = shift;
	my $bootXML   = shift;
	my $bootArchives = $systemXML -> getBootIncludeArchives();
	my $bootAddPacks = $systemXML -> getBootIncludePackages();
	my $bootDelPacks = $systemXML -> getBootDeletePackages();
	my @addPacks     = ();
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
			my $foundInDelPacks = 0;
			for my $package (@{$bootDelPacks}) {
				my $delName = $package -> getName();
				if ($delName eq $name) {
					$foundInDelPacks = 1;
					last;
				}
			}
			if (! $foundInDelPacks) {
				push @addPacks, $name;
			}
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
	my $deletePackages = $bootXML -> getPackagesToDelete();
	if (($deletePackages) && (@addPacks)) {
		my @resultDeletePackages;
		my @exceptionList = ();
		for my $package (@{$deletePackages}) {
			my $delName = $package -> getName();
			my $install = 0;
			foreach my $instpack (@addPacks) {
				if ($instpack eq $delName) {
					$install = 1;
					last;
				}
			}
			if ($install) {
				push @exceptionList,$delName
			} else {
				push @resultDeletePackages,$package;
			}
		}
		if ((@resultDeletePackages) && (@exceptionList)) {
			$kiwi -> info ("Packages protected from being deleted:\n");
			foreach my $exception (@exceptionList) {
				$kiwi -> warning (
					"--> $exception: explicitly boot included"
				);
				$kiwi -> skipped ();
			}
			$bootXML -> setPackagesToDelete (\@resultDeletePackages);
		}
	}
	return $this;
}
#==========================================
# __addPreferencesToBootXML
#------------------------------------------
sub __addPreferencesToBootXML {
	# ...
	# add additional preferences information from the
	# the system XML data to the boot XML data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemXML = shift;
	my $bootXML   = shift;
	my $syspref   = $systemXML -> getPreferences();
	my $bootpref  = $bootXML   -> getPreferences();
	#==========================================
	# package manager
	#------------------------------------------
	my $manager = $syspref -> getPackageManager();
	if ($manager) {
		$bootpref -> setPackageManager ($manager);
	}
	#==========================================
	# locale
	#------------------------------------------
	my $locale = $syspref -> getLocale();
	if ($locale) {
		$bootpref -> setLocale ($locale);
	}
	#==========================================
	# license
	#------------------------------------------
	my $license = $syspref -> getShowLic();
	if ($license) {
		$bootpref -> setShowLic ($license);
	}
	#==========================================
	# bootloader theme
	#------------------------------------------
	my $loadertheme = $syspref -> getBootLoaderTheme();
	if ($loadertheme) {
		$bootpref -> setBootLoaderTheme ($loadertheme);
	}
	#==========================================
	# bootsplash theme
	#------------------------------------------
	my $splashtheme = $syspref -> getBootSplashTheme();
	if ($splashtheme) {
		$bootpref -> setBootSplashTheme ($splashtheme);
	}
	#==========================================
	# rpm signature check
	#------------------------------------------
	my $checkSig = $syspref -> getRPMCheckSig();
	if ($checkSig) {
		$bootpref -> setRPMCheckSig ($checkSig);
	}
	#==========================================
	# KIWIXMLPreferenceData
	#------------------------------------------
	# getPreferences returns a new KIWIXMLPreferenceData object
	# containing combined information. Thus it's required to set
	# the changed object back into the KIWIXML space
	# ---
	$bootXML -> setPreferences ($bootpref);
	return $this;
}

#==========================================
# __addSystemDiskToBootXML
#------------------------------------------
sub __addSystemDiskToBootXML {
	# ...
	# add the systemdisk information from the system XML data to the
	# boot XML data by copying some data into a new SystemdiskData
	# object which is then stored in the boot XML object. kiwi's boot
	# image descriptions does not contain systemdisk section data
	# thus it's ok to to just add a copy of the system XML systemdisk
	# section. The data is only copied if a systemdisk sectiom
	# exists in the system XML data set
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemXML = shift;
	my $bootXML   = shift;
	my $systemdisk = $systemXML -> getSystemDiskConfig();
	if ($systemdisk) {
		my %lvmData;
		$kiwi -> info ("Updating SystemDisk section\n");
		#==========================================
		# volume group name
		#------------------------------------------
		my $lvmgroup = $systemdisk -> getVGName();
		if (! $lvmgroup) {
			$lvmgroup = 'kiwiVG';
		}
		$kiwi -> info ("--> Volume group name: $lvmgroup\n");
		$lvmData{name} = $lvmgroup;
		#==========================================
		# volumes
		#------------------------------------------
		my %volData;
		my $vcount = 1;
		my $volIDs = $systemdisk -> getVolumeIDs();
		my $default = $this->{gdata}->{VolumeFree};
		if ($volIDs) {
			foreach my $id (@{$volIDs}) {
				my %volInfo;
				$volInfo{name}      = $systemdisk -> getVolumeName ($id);
				$volInfo{mountpoint}= $systemdisk -> getVolumeMountPoint ($id);
				$volInfo{freespace} = $systemdisk -> getVolumeFreespace ($id);
				$volInfo{size}      = $systemdisk -> getVolumeSize ($id);
				$volData{$vcount} = \%volInfo;
				$vcount++;
				my $name = $volInfo{name};
				if ($volInfo{mountpoint}) {
					my $mount = $volInfo{mountpoint};
					$mount =~ s/^\///;
					$name = $volInfo{name}.'['.$mount.']';
				}
				if ($volInfo{freespace}) {
					my $free = $volInfo{freespace};
					if ($free eq 'all') {
						$kiwi -> info (
							"--> Volume $name: takes remaining free space\n"
						);
					} else {
						$kiwi -> info (
							"--> Volume $name: with $free MB free\n"
						);
					}
				} elsif ($volInfo{size}) {
					$kiwi -> info (
						"--> Volume $name: size: $volInfo{size} MB\n"
					);
				} else {
					$kiwi-> info (
						"--> Volume $name: with $default MB[default] free\n"
					);
				}
			}
		}
		$lvmData{volumes} = \%volData;
		my $sdk = KIWIXMLSystemdiskData -> new (\%lvmData);
		$bootXML -> addSystemDisk ($sdk);
	}
	return $this;
}

#==========================================
# __addTypeToBootXML
#------------------------------------------
sub __addTypeToBootXML {
	# ...
	# add additional type information from the system
	# XML data to the boot XML data
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $systemXML = shift;
	my $bootXML   = shift;
	my $systemType = $systemXML -> getImageType();
	my $bootType   = $bootXML   -> getImageType();
	$kiwi -> info ("Updating Type section\n");
	#==========================================
	# filesystem 
	#------------------------------------------
	my $fs = $systemType -> getFilesystem();
	if ($fs) {
		$kiwi -> info ("--> filesystem: $fs");
		$bootType -> setFilesystem ($fs);
		$kiwi -> done();
	}
	#==========================================
	# hybrid
	#------------------------------------------
	my $hybrid = $systemType -> getHybrid();
	if ($hybrid) {
		$kiwi -> info ("--> hybrid: $hybrid");
		$bootType -> setHybrid ($hybrid);
		$kiwi -> done();
	}
	#==========================================
	# hybridpersistent
	#------------------------------------------
	my $hybridpersistent = $systemType -> getHybridPersistent();
	if ($hybridpersistent) {
		$kiwi -> info ("--> hybridpersistent: $hybridpersistent");
		$bootType -> setHybridPersistent ($hybridpersistent);
		$kiwi -> done();
	}
	#==========================================
	# ramonly
	#------------------------------------------
	my $ramonly = $systemType -> getRAMOnly();
	if ($ramonly) {
		$kiwi -> info ("--> ramonly: $ramonly");
		$bootType -> setRAMOnly ($ramonly);
		$kiwi -> done();
	}
	#==========================================
	# kernelcmdline
	#------------------------------------------
	my $kernelcmdline = $systemType -> getKernelCmdOpts();
	if ($kernelcmdline) {
		$kiwi -> info ("--> kernelcmdline: $kernelcmdline");
		$bootType -> setKernelCmdOpts ($kernelcmdline);
		$kiwi -> done();
	}
	#==========================================
	# firmware
	#------------------------------------------
	my $firmware = $systemType -> getFirmwareType();
	if ($firmware) {
		$kiwi -> info ("--> firmware: $firmware");
		$bootType -> setFirmwareType ($firmware);
		$kiwi -> done();
	}
	#==========================================
	# bootloader
	#------------------------------------------
	my $bootloader = $systemType -> getBootLoader();
	if ($bootloader) {
		$kiwi -> info ("--> bootloader: $bootloader");
		$bootType -> setBootLoader ($bootloader);
		$kiwi -> done();
	}
	#==========================================
	# boottimeout
	#------------------------------------------
	my $boottimeout = $systemType -> getBootTimeout();
	if (defined $boottimeout) {
		$kiwi -> info ("--> boottimout: $boottimeout");
		$bootType -> setBootTimeout($boottimeout);
		$kiwi -> done();
	}
	#==========================================
	# devicepersistency
	#------------------------------------------
	my $devicepersistency = $systemType -> getDevicePersistent();
	if ($devicepersistency) {
		$kiwi -> info ("--> devicepersistency: $devicepersistency");
		$bootType -> setDevicePersistent ($devicepersistency);
		$kiwi -> done();
	}
	#==========================================
	# installboot
	#------------------------------------------
	my $installboot = $systemType -> getInstallBoot();
	if ($installboot) {
		$kiwi -> info ("--> installboot: $installboot");
		$bootType -> setInstallBoot ($installboot);
		$kiwi -> done();
	}
	#==========================================
	# installfailsafe
	#------------------------------------------
	my $installprovidefailsafe = $systemType -> getInstallProvideFailsafe();
	if ($installprovidefailsafe) {
		$kiwi -> info ("--> installprovidefailsafe: $installprovidefailsafe");
		$bootType -> setInstallProvideFailsafe ($installprovidefailsafe);
		$kiwi -> done();
	}
	#==========================================
	# bootkernel
	#------------------------------------------
	my $bootkernel = $systemType -> getBootKernel();
	if ($bootkernel) {
		$kiwi -> info ("--> bootkernel: $bootkernel");
		$bootType -> setBootKernel ($bootkernel);
		$kiwi -> done();
	}
	#==========================================
	# fsmountoptions
	#------------------------------------------
	my $fsmountoptions = $systemType -> getFSMountOptions();
	if ($fsmountoptions) {
		$kiwi -> info ("--> fsmountoptions: $fsmountoptions");
		$bootType -> setFSMountOptions ($fsmountoptions);
		$kiwi -> done();
	}
	#==========================================
	# bootprofile
	#------------------------------------------
	my $bootprofile = $systemType -> getBootProfile();
	if ($bootprofile) {
		$kiwi -> info ("--> bootprofile: $bootprofile");
		$bootType -> setBootProfile ($bootprofile);
		$kiwi -> done();
	}
	#==========================================
	# vga
	#------------------------------------------
	my $vga = $systemType -> getVGA();
	if ($vga) {
		$kiwi -> info ("--> vga: $vga");
		$bootType -> setVGA ($vga);
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# __addOEMConfigDataToBootXML
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
# __addDefaultStripData
#------------------------------------------
sub __addDefaultStripData {
	# ...
	# Add default strip data from KIWIConfig.txt
	# ---
	my $this = shift;
	my $xml  = shift;
	my $defStrip = KIWIXMLDefStripData -> new();
	$xml -> addFilesToDelete($defStrip -> getFilesToDelete());
	$xml -> addLibsToKeep($defStrip -> getLibsToKeep());
	$xml -> addToolsToKeep($defStrip -> getToolsToKeep());
	return $this;
}

#==========================================
# __getPackageFilelist
#------------------------------------------
sub __getPackageFilelist {
	# ...
	# return a list of files owned by a given package
	# ---
	my $this = shift;
	my $pack = shift;
	my $root = shift;
	my $kiwi = $this->{kiwi};
	my $data = KIWIQX::qxx (
		"rpm --root $root -ql \"$pack\" 2>&1"
	);
	my $code = $? >> 8;
	if ($code != 0) {
		return;
	}
	return [split(/\n/, $data)];
}

#==========================================
# __addBootincludedToolsToKeep
#------------------------------------------
sub __addBootincludedToolsToKeep {
	# ...
	# Keep all tools from explicitly bootincluded packages
	# by adding a strip section to the system XML data
	# which is then added to the boot image when we inherit
	# system XML data to the boot
	# ---
	my $this = shift;
	my $xml  = shift;
	my $root = shift;
	my $kiwi = $this->{kiwi};
	my @list;
	$kiwi -> info (
		"Reading contents of bootincluded packages/archives\n"
	);
	if (! -f "$root/var/lib/rpm/Packages") {
		# /.../
		# For the moment we can get the package file list only
		# from the rpm database inside of the unpacked root tree
		# If no such database exists, treat it as a warning and
		# return
		# ----
		$kiwi -> warning (
			"--> No rpm database found in $root"
		);
		$kiwi -> skipped();
		return $this;
	}
	my $bootAddPacks = $xml -> getBootIncludePackages();
	for my $pack (@$bootAddPacks) {
		my $pack_name = $pack -> getName();
		my $pkglist = $this -> __getPackageFilelist(
			$pack_name, $root
		);
		if ($pkglist) {
			$kiwi -> info (
				"--> got list from $pack_name\n"
			);
			push @list, @$pkglist;
		} else {
			$kiwi -> warning (
				"--> package $pack_name not installed\n"
			);
			$kiwi -> skipped();
		}
	}
	my $FILE = FileHandle -> new();
	if ($FILE -> open ("$root/bootincluded_archives.filelist")) {
		while (<$FILE>) {
			chomp;
			push @list, File::Spec->rel2abs( $_, '/' ) ;
		}
		$FILE -> close();
		$kiwi -> info (
			"--> got list from bootincluded_archives.filelist\n"
		);
	}
	$kiwi -> info (
		"Checking for tools in bootincluded contents to keep\n"
	);
	my @tool_list = ();
	for my $file (@list) {
		if ($file =~ /^(\/usr)?\/s?bin\/([^\/]*)$/) {
			my $tool = $2;
			push @tool_list, $tool
		}
	}
	my %hashTemp = map { $_ => 1 } @tool_list;
	@tool_list = sort keys %hashTemp;
	if (! @tool_list) {
		$kiwi -> info ("--> no tools to keep\n");
	} else {
		for my $tool (@tool_list) {
			$kiwi -> info ("--> Keep in boot image: $tool\n");
			my %stripData = (
				name => $tool
			);
			my $stripObj = KIWIXMLStripData -> new(\%stripData);
			if ($stripObj) {
				$xml -> addToolsToKeep ([$stripObj]);
			}
		}
	}
	return $this;
}

#==========================================
# __addStripDataToBootXML
#------------------------------------------
sub __addStripDataToBootXML {
	# ...
	# Add system XML strip data to the
	# boot image description.
	# ---
	my $this = shift;
	my $systemXML = shift;
	my $bootXML = shift;
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
# __updateProfileEnvironment
#------------------------------------------
sub __updateProfileEnvironment {
	# ...
	# update the contents of the .profile file due to
	# changes given on the command line e.g image type
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
	my $profile = KIWIProfileFile -> new();
	my $status;
	if (! $profile) {
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
		KIWIQX::qxx ("cp $tree/.profile $tree/image/.profile");
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# __printProfileInfo
#------------------------------------------
sub __printProfileInfo {
	my $this  = shift;
	my $xml   = shift;
	my $text  = shift;
	my $kiwi  = $this->{kiwi};
	if (! $text) {
		$text = 'Using profile(s):';
	}
	my $activeProfiles = $xml -> getActiveProfileNames();
	if (($activeProfiles) && (scalar @{$activeProfiles} > 0)) {
		my $info = join (",",@{$activeProfiles});
		$kiwi -> info ("$text\n");
		$kiwi -> info ("--> @{$activeProfiles}");
		$kiwi -> done ();
	}
	return $this;
}

1;

