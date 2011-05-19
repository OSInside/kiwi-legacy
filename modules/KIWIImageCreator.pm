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
	$this->{kiwi}  = $kiwi;
	$this->{cmdL}  = $cmdL;
	$this->{gdata} = $main::global -> getGlobals();
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
	$this->{imageTgtDir}      = $cmdL -> getImageTargetDir();
	$this->{imageInitrdTgtDir}= $cmdL -> getInitrdImageTargetDir();
	$this->{rootInitrdTgtDir} = $cmdL -> getInitrdRootTargetDir();
	$this->{initrd}           = $cmdL -> getInitrdFile();
	$this->{sysloc}           = $cmdL -> getSystemLocation();
	$this->{disksize}         = $cmdL -> getImageDiskSize();
	$this->{targetdevice}     = $cmdL -> getImageTargetDevice();
	$this->{format}           = $cmdL -> getImageFormat();
	$this->{configDir}        = $cmdL -> getConfigDir();
	$this->{configInitrdDir}  = $cmdL -> getInitrdConfigDir();
	$this->{buildType}        = $cmdL -> getBuildType();
	return 1;
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
	my $ignore     = $this->{ignoreRepos};
	my $pkgMgr     = $this->{packageManager};
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
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
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
	my $rootTgtDir= $this -> {rootTgtDir};
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
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
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
	if (! $rootTgtDir) {
		$kiwi -> info ("Checking for default root in XML data...");
		my $rootTgt =  $xml -> getImageDefaultRoot();
		if ($rootTgt) {
			$this -> {cmdL} -> setRootTargetDir($rootTgt);
			$this -> {rootTgtDir} = $rootTgt;
			$rootTgtDir = $rootTgt;
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
	my $configDir    = $this->{configInitrdDir};
	my $destination  = $this->{imageInitrdTgtDir};
	my $kiwi         = $this->{kiwi};
	my $pkgMgr       = $this->{packageManager};
	my $ignore       = $this->{ignoreRepos};
	my $cmdL         = $this->{cmdL};
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	my $locator = new KIWILocator($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);;
	if (! $controlFile) {
		return undef;
	}
	my $validator = new KIWIXMLValidator (
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return undef;
	}
	$kiwi -> info ("Create boot image (initrd)...\n");
	my $xml = new KIWIXML (
		$kiwi,$configDir,"cpio",undef
	);
	if (! defined $xml) {
		return undef;
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
	if ($this -> {addlRepos}) {
		my %addlRepos = %{$this -> {addlRepos}};
		$xml -> addRepository (
			$addlRepos{repositoryTypes},
			$addlRepos{repositories},
			$addlRepos{repositoryAlia},
			$addlRepos{repositoryPriorities}
		);
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
	#==========================================
	# Create destdir if needed
	#------------------------------------------
	my $dirCreated = $main::global -> createDirInteractive(
		$destination,$cmdL -> getDefaultAnswer()
	);
	if (! defined $dirCreated) {
		return undef;
	}
	#==========================================
	# Create KIWIImage object
	#------------------------------------------
	my $image = new KIWIImage (
		$kiwi,$xml,$configDir,$destination,undef,
		"/base-system",$configDir,undef,$cmdL
	);
	if (! defined $image) {
		return undef;
	}
	$this->{image} = $image;
	#==========================================
	# Create cpio image
	#------------------------------------------
	if (! $image -> createImageCPIO()) {
		undef $image;
		return undef;
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
	my $type         = $this -> {buildType};
	my $kiwi         = $this -> {kiwi};
	my $pkgMgr       = $this -> {packageManager};
	my $ignore       = $this -> {ignoreRepos};
	my $target       = $this -> {imageTgtDir};
	my $cmdL         = $this -> {cmdL};
	my $targetDevice = $this -> {targetdevice};
	#==========================================
	# Check the tree first...
	#------------------------------------------
	if (-f "$configDir/.broken") {
		$kiwi -> error  ("Image root tree $configDir is broken");
		$kiwi -> failed ();
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
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return undef;
	}
	$kiwi -> info ("Reading image description [Create]...\n");
	my $xml = new KIWIXML (
		$kiwi,$configDir,$type,$buildProfs
	);
	if (! defined $xml) {
		return undef;
	}
	my %attr = %{$xml->getImageTypeAndAttributes()};
	my $krc = new KIWIRuntimeChecker (
		$kiwi,$cmdL,$xml
	);
	#==========================================
	# Check for default destination in XML
	#------------------------------------------
	if (! $target) {
		$kiwi -> info ("Checking for defaultdestination in XML data...");
		my $defaultDestination = $xml -> getImageDefaultDestination();
		if (! $defaultDestination) {
			$kiwi -> failed ();
			$kiwi -> info   ("No destination directory specified");
			$kiwi -> failed ();
			return undef;
		}
		$this -> {imageTgtDir} = $defaultDestination;
		$cmdL -> setImagetargetDir ($defaultDestination);
		$kiwi -> done();
	}
	my $destination = $this -> {imageTgtDir};
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
	if (! $krc -> createChecks()) {
		return undef;
	}
	#==========================================
	# Create destdir if needed
	#------------------------------------------
	my $dirCreated = $main::global -> createDirInteractive(
		$destination,$cmdL -> getDefaultAnswer()
	);
	if (! defined $dirCreated) {
		return undef;
	}
	#==========================================
	# Check tool set
	#------------------------------------------
	my $para = $this -> checkType (
		$xml,\%attr,$configDir
	);
	if (! defined $para) {
		return undef;
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
		my $kic  = new KIWIImageCreator ($kiwi, $cmdL);
		if (! $kic) {
			return undef;
		}
		if (! $kic -> upgradeImage()) {
			return undef;
		}
		$cmdL -> setAdditionalPackages ([]);
		$cmdL -> setPackagesToRemove ([]);
	}
	#==========================================
	# Create KIWIImage object
	#------------------------------------------
	my $image = new KIWIImage (
		$kiwi,$xml,$configDir,$destination,$main::StripImage,
		"/base-system",$configDir,undef,$cmdL
	);
	if (! defined $image) {
		return undef;
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
	# Update .profile env, current type
	#------------------------------------------
	$kiwi -> info ("Updating type in .profile environment");
	qxx (
		"sed -i -e 's#kiwi_type=.*#kiwi_type=\"$type\"#' $tree/.profile"
	);
	$kiwi -> done();
	#==========================================
	# Create recovery archive if specified
	#------------------------------------------
	if ($type eq "oem") {
		my $configure = new KIWIConfigure (
			$kiwi,$xml,$tree,$tree."/image",$destination
		);
		if (! defined $configure) {
			return undef;
		}
		if (! $configure -> setupRecoveryArchive($attr{filesystem})) {
			return undef;
		}
	}
	#==========================================
	# Initialize logical image extend
	#------------------------------------------
	my $ok;
	my $checkFormat = 0;
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
		return undef;
	}
	if ($ok) {
		if (($checkFormat) && ($attr{format})) {
			my $haveFormat = $attr{format};
			my $imgfile= $destination."/".$image -> buildImageName();
			my $format = new KIWIImageFormat (
				$kiwi,$imgfile,$cmdL,$haveFormat
			);
			if (! $format) {
				return undef;
			}
			if (! $format -> createFormat()) {
				return undef;
			}
		}
		undef $image;
		return 1;
	} else {
		undef $image;
		return undef;
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
	my $boot = new KIWIBoot ($kiwi,$ird,$cmdL);
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
	my $cmdL = $this->{cmdL};
	$kiwi -> info ("Creating boot USB stick from: $ird...\n");
	my $boot = new KIWIBoot ($kiwi,$ird,$cmdL);
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
	my $cmdL = $this->{cmdL};
	$kiwi -> info ("Creating boot ISO from: $ird...\n");
	my $boot = new KIWIBoot ($kiwi,$ird,$cmdL);
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
	my $cmdL = $this->{cmdL};
	$kiwi -> info ("Creating install ISO from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return undef;
	}
	my $boot = new KIWIBoot ($kiwi,$ird,$cmdL,$sys);
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
	my $cmdL = $this->{cmdL};
	$kiwi -> info ("Creating install Stick from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return undef;
	}
	my $boot = new KIWIBoot ($kiwi,$ird,$cmdL,$sys);
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
	my $cmdL = $this->{cmdL};
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
		$kiwi,$ird,$cmdL,$sys,$size,undef,$prof
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
	my $cmdL   = $this->{cmdL};
	$kiwi -> info ("--> Starting image format conversion...\n");
	my $imageformat = new KIWIImageFormat (
		$kiwi,$sys,$cmdL,$format
	);
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
		$kiwi,$xml,$this->{cacheDir},$this->{gdata}->{BasePath},
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
# checkType
#------------------------------------------
sub checkType {
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $xml    = $_[0];
	my (%type) = %{$_[1]};
	my $root   = $_[2];
	my $para   = "ok";
	my $type   = $type{type};
	my $flags  = $type{flags};
	my $fs     = $type{filesystem};
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
			my %result = $main::global -> checkFileSystem ($fs);
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
			my $msg = "--> squashfs tool/driver mismatch";
			if (($error == 2) && ($mktool_vs ne $module_vs)) {
				$kiwi -> error (
					"$msg: $mktool_vs vs $module_vs"
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
	if ($image) {
		$image -> cleanMount ();
		$image -> restoreCDRootData ();
		$image -> restoreSplitExtend ();
	}
	if ($boot) {
		undef $boot;
	}
}

1;

