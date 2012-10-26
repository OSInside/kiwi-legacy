#================
# FILE          : KIWIImageCreator.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use File::Basename;
use KIWICommandLine;
use KIWIImageFormat;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIRoot;
use KIWIRuntimeChecker;
use KIWIXML;
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
	my $kiwi = shift;
	my $cmdL = shift;
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if (! defined $cmdL) {
		my $msg = 'KIWIImageCreator: expecting KIWICommandLine object as '
			. 'second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! $main::global) {
		$kiwi -> error  ("Globals object not found");
		$kiwi -> failed ();
		return;
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
# prepareBootImage
#------------------------------------------
sub prepareBootImage {
	# ...
	# Prepare the boot image
	# ---
	my $this       = shift;
	my $configDir  = shift;
	my $rootTgtDir = shift;
	my $systemTree = shift;
	my $changeset  = shift;
	my $cmdL       = $this->{cmdL};
	my $kiwi       = $this->{kiwi};
	if (! $configDir) {
		$kiwi -> error ('prepareBootImage: no configuration directory defined');
		$kiwi -> failed ();
		return;
	}
	if (! -d $configDir) {
		my $msg = 'prepareBootImage: config dir "'
			. $configDir
			. '" does not exist';
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
	$kiwi -> info ("--> Prepare boot image (initrd)...\n");
	my $xml = KIWIXML -> new(
		$kiwi,$configDir,undef,undef,$cmdL,$changeset
	);
	if (! defined $xml) {
		return;
	}
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$xml = $this -> __applyBaseXMLOverrides($xml);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	return $this -> __prepareTree (
		$xml,$configDir,$rootTgtDir,$systemTree
	);
}

#==========================================
# upgradeImage
#------------------------------------------
sub upgradeImage {
	my $this      = shift;
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
	my $locator = KIWILocator -> new($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	$kiwi -> info ("Reading image description [Upgrade]...\n");
	my $buildProfs = $this -> {buildProfiles};
	my $xml = KIWIXML -> new(
		$kiwi, $configDir, undef, $buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	my $krc = KIWIRuntimeChecker -> new(
		$kiwi, $this -> {cmdL}, $xml
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
	my $locator = KIWILocator -> new($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);;
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	$kiwi -> info ("Reading image description [Prepare]...\n");
	my $buildProfs = $this -> {buildProfiles};
	my $xml = KIWIXML -> new(
		$kiwi, $configDir, $this->{buildType}, $buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	my $krc = KIWIRuntimeChecker -> new(
		$kiwi, $this -> {cmdL}, $xml
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
	my $configDir    = shift;
	my $destination  = shift;
	my $kiwi         = $this->{kiwi};
	my $pkgMgr       = $this->{packageManager};
	my $ignore       = $this->{ignoreRepos};
	my $cmdL         = $this->{cmdL};
	#==========================================
	# Setup the image XML description
	#------------------------------------------
	my $locator = KIWILocator -> new($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);;
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $isValid = $validator ? $validator -> validate() : undef;
	if (! $isValid) {
		return;
	}
	if (! $this -> __checkImageIntegrity() ) {
		return;
	}
	$kiwi -> info ("--> Create boot image (initrd)...\n");
	my $xml = KIWIXML -> new(
		$kiwi,$configDir,"cpio",undef,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	#==========================================
	# Apply XML over rides from command line
	#------------------------------------------
	$xml = $this -> __applyBaseXMLOverrides($xml);
	$kiwi -> writeXMLDiff ($this->{gdata}->{Pretty});
	#==========================================
	# Create destdir if needed
	#------------------------------------------
	my $dirCreated = $main::global -> createDirInteractive(
		$destination,$cmdL -> getDefaultAnswer()
	);
	if (! defined $dirCreated) {
		return;
	}
	#==========================================
	# Create KIWIImage object
	#------------------------------------------
	my $image = KIWIImage -> new(
		$kiwi,$xml,$configDir,$destination,undef,
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
	my $target       = $this -> {imageTgtDir};
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
	my $locator = KIWILocator -> new($kiwi);
	my $controlFile = $locator -> getControlFile ($configDir);;
	if (! $controlFile) {
		return;
	}
	my $validator = KIWIXMLValidator -> new(
		$kiwi,$controlFile,
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
		$kiwi,$configDir,$this->{buildType},
		$buildProfs,$cmdL
	);
	if (! defined $xml) {
		return;
	}
	my %attr = %{$xml->getImageTypeAndAttributes_legacy()};
	my $krc = KIWIRuntimeChecker -> new(
		$kiwi,$cmdL,$xml
	);
	#==========================================
	# Check for default destination in XML
	#------------------------------------------
	if (! $target) {
		$kiwi -> info ("Checking for defaultdestination in XML data...");
		my $defaultDestination = $xml -> getImageDefaultDestination_legacy();
		if (! $defaultDestination) {
			$kiwi -> failed ();
			$kiwi -> info   ("No destination directory specified");
			$kiwi -> failed ();
			return;
		}
		$this -> {imageTgtDir} = $defaultDestination;
		$cmdL -> setImagetargetDir ($defaultDestination);
		$kiwi -> done();
	}
	my $destination = $this -> {imageTgtDir};
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
	my $dirCreated = $main::global -> createDirInteractive(
		$destination,$cmdL -> getDefaultAnswer()
	);
	if (! defined $dirCreated) {
		return;
	}
	my $profileNames = join ("-",@{$xml->{reqProfiles}});
	if ($profileNames) {
		$destination.="/".$attr{type}."-".$profileNames;
	} else {
		$destination.="/".$attr{type};
	}
	if ((! -d $destination) && (! mkdir $destination)) {
		$kiwi -> error  ("Failed to create destination subdir: $!");
		$kiwi -> failed ();
		return;
	}
	$this -> {imageTgtDir} = $destination;
	$cmdL -> setImagetargetDir ($destination);
	#==========================================
	# Check tool set
	#------------------------------------------
	my $para = $this -> checkType (
		$xml,\%attr,$configDir
	);
	if (! defined $para) {
		return;
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
	$xml -> getTypeSpecificPackageList();
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
		my $kic  = KIWIImageCreator -> new($kiwi, $cmdL);
		if (! $kic) {
			return;
		}
		if (! $kic -> upgradeImage()) {
			return;
		}
		$cmdL -> setAdditionalPackages ([]);
		$cmdL -> setPackagesToRemove ([]);
	}
	#==========================================
	# Create KIWIImage object
	#------------------------------------------
	my $image = KIWIImage -> new(
		$kiwi,$xml,$configDir,$destination,$cmdL->getStripImage(),
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
	# Update .profile env, current type
	#------------------------------------------
	$kiwi -> info ("Updating type in .profile environment");
	qxx (
		"sed -i -e 's#kiwi_type=.*#kiwi_type=\"$attr{type}\"#' $tree/.profile"
	);
	$kiwi -> done();
	#==========================================
	# Create recovery archive if specified
	#------------------------------------------
	if ($attr{type} eq "oem") {
		my $configure = KIWIConfigure -> new(
			$kiwi,$xml,$tree,$tree."/image",$destination
		);
		if (! defined $configure) {
			return;
		}
		if (! $configure -> setupRecoveryArchive($attr{filesystem})) {
			return;
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
		/^tbz/      && do {
			$ok = $image -> createImageTar ();
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
			$ok = $image -> createImageXFS ( $targetDevice );
			$checkFormat = 1;
			last SWITCH;
		};
		$kiwi -> error  ("Unsupported type: $attr{type}");
		$kiwi -> failed ();
		undef $image;
		return;
	}
	if ($ok) {
		my $imgName = $main::global -> generateBuildImageName ($xml);
		if (($checkFormat) && ($attr{format})) {
			my $haveFormat = $attr{format};
			my $imgfile= $destination."/".$imgName;
			my $format = KIWIImageFormat -> new(
				$kiwi,$imgfile,$cmdL,$haveFormat,$xml,$image->{targetDevice}
			);
			if (! $format) {
				return;
			}
			if (! $format -> createFormat()) {
				return;
			}
			$format -> createMaschineConfiguration();
		}
		undef $image;
		#==========================================
		# Package build result into an archive
		#------------------------------------------
		my $basedest = dirname  $destination;
		my $basesubd = basename $destination;
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
		my $status = qxx ("mv -f $destination/* $basedest 2>&1");
		my $result = $? >> 8;
		if ($result != 0) {
			$kiwi -> error (
				"Failed to move result image file(s) to destination: $status"
			);
			$kiwi -> failed ();
			return;
		}
		rmdir $destination;
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
	my $boot = KIWIBoot -> new($kiwi,$ird,$cmdL);
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
	$kiwi -> info ("Creating boot USB stick from: $ird...\n");
	my $boot = KIWIBoot -> new($kiwi,$ird,$cmdL);
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
	$kiwi -> info ("Creating boot ISO from: $ird...\n");
	my $boot = KIWIBoot -> new($kiwi,$ird,$cmdL);
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
	$kiwi -> info ("Creating install ISO from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new($kiwi,$ird,$cmdL,$sys);
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
	$kiwi -> info ("Creating install Stick from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new($kiwi,$ird,$cmdL,$sys);
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
	$kiwi -> info ("Creating install PXE data set from: $ird...\n");
	if (! defined $sys) {
		$kiwi -> error  ("No Install system image specified");
		$kiwi -> failed ();
		return;
	}
	my $boot = KIWIBoot -> new($kiwi,$ird,$cmdL,$sys);
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
		$kiwi,$ird,$cmdL,$sys,$size,undef,$prof
	);
	if (! defined $boot) {
		return;
	}
	$this->{boot} = $boot;
	if (! $boot -> setupBootDisk($tdev)) {
		return;
	}
	$boot -> cleanLoop ();
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
		$kiwi,$sys,$cmdL,$format,$xml,$this->{targetdevice}
	);
	if (! $imageformat) {
		return;
	}
	if (! $imageformat -> createFormat()) {
		return;
	}
	$imageformat -> createMaschineConfiguration();
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
	if ($this -> {addlPackages}) {
		$xml -> addImagePackages (@{$this -> {addlPackages}});
	}
	if ($this -> {addlPatterns}) {
		$xml -> addImagePatterns (@{$this -> {addlPatterns}});
	}
	if ($this -> {removePackages}) {
		$xml -> addRemovePackages (@{$this -> {removePackages}});
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
		$xml -> setPackageManager_legacy($this -> {packageManager});
	}
	if ($this -> {ignoreRepos}) {
		$xml -> ignoreRepositories_legacy ();
	}
	if ($this -> {addlRepos}) {
		my %addlRepos = %{$this -> {addlRepos}};
		$xml -> addRepositories_legacy (
			$addlRepos{repositoryTypes},
			$addlRepos{repositories},
			$addlRepos{repositoryAlia},
			$addlRepos{repositoryPriorities}
		);
	}
	if ($this -> {replRepo}) {
		my %replRepo = %{$this -> {replRepo}};
		$xml -> setRepository_legacy (
			$replRepo{repositoryType},
			$replRepo{repository},
			$replRepo{repositoryAlias},
			$replRepo{respositoryPriority}
		);
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
		$kiwi,$xml,$configDir,undef,'/base-system',
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
	if (! $root -> upgrade ()) {
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
	my $kiwi = $this -> {kiwi};
	my $cmdL = $this -> {cmdL};
	if ( ! $this -> {cacheDir}) {
		return;
	}
	if (($cacheMode eq "remount") && (! -f "$configDir/kiwi-root.cache")) {
		return;
	}
	my $icache = KIWICache -> new(
		$kiwi,$xml,$this->{cacheDir},$this->{gdata}->{BasePath},
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
		my @initPacs = $xml -> getBaseList();
		if (@initPacs) {
			$xml -> addImagePackages (@initPacs);
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
		$kiwi,$xml,$configDir,$rootTgtDir,'/base-system',
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
	if (! $xml -> writeXMLDescription ($root->getRootPath())) {
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
# checkType
#------------------------------------------
sub checkType {
	my ($this, $xml, $typeInfo, $root) = @_;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my (%type) = %{$typeInfo};
	my $para   = "ok";
	my $type   = $type{type};
	my $flags  = $type{flags};
	my $fs     = $type{filesystem};
	#==========================================
	# check for required image attributes
	#------------------------------------------
	if ($cmdL->getFatStorage()) {
		# /.../
		# if the option --fat-storage is set, we set syslinux
		# as bootloader because it works better on USB sticks.
		# Additionally we use LVM because it allows to better
		# resize the stick
		# ----
		$xml -> __setTypeAttribute ("bootloader","syslinux");
		$xml -> __setSystemDiskElement ();
		$xml -> writeXMLDescription ($root);
	} elsif ($cmdL->getLVM()) {
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
	if ($type{type} eq "squashfs") {
		$check_mksquashfs = 1;
	}
	if (($type{installiso}) || ($type{installstick})) {
		$check_mksquashfs = 1;
	}
	if (($fs) && ($fs =~ /squashfs/)) {
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
	SWITCH: for ($type{type}) {
		/^iso/ && do {
			if (! defined $type{boot}) {
				$kiwi -> error ("$type{type}: No boot image specified");
				$kiwi -> failed ();
				return;
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
				return;
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
				return;
			}
			if (! defined $type{boot}) {
				$kiwi -> error ("$type{type}: No boot image specified");
				$kiwi -> failed ();
				return;
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
	if ($boot) {
		$boot -> cleanLoop ();
		undef $boot;
	}
	if ($image) {
		$image -> cleanMount ();
	}
	return;
}

1;

