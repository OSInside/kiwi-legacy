#================
# FILE          : KIWIRuntimeChecker.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to check setup and other conditions
#               : that can only be verified when KIWI is running. An example
#               : is the check for required tools such as filesystem tools,
#               : where we only know at runtime what file system tool we
#               : actually need.
#               :
# STATUS        : Development
#----------------
package KIWIRuntimeChecker;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use base qw (Exporter);

#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIXML;
use KIWIXMLRepositoryData;
use KIWIXMLSystemdiskData;
use KIWIXMLTypeData;
use KIWIXMLVMachineData;
use Readonly;

#==========================================
# constants
#------------------------------------------
Readonly my $MEGABYTE => 1048576;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the RuntimChecker object
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
	my $cmdArgs = shift;
	my $xml     = shift;
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	if (! $cmdArgs ) {
		my $msg = 'Expecting reference to KIWICommandLine object as '
		. 'argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (! $xml ) {
		my $msg = 'Expecting reference to KIWIXML object as second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store module parameters
	#------------------------------------------
	$this->{cmdArgs} = $cmdArgs;
	$this->{locator} = KIWILocator -> instance();
	$this->{kiwi}    = $kiwi;
	$this->{xml}     = $xml;
	return $this;
}

#==========================================
# createChecks
#------------------------------------------
sub createChecks {
	# ...
	# Runtime checks specific to the create step
	# ---
	my $this = shift;
	if (! $this -> __checkContainerHasLXC()) {
		return;
	}
	if (! $this -> __checkProfileConsistent()) {
		return;
	}
	if (! $this -> __haveValidTypeString()) {
		return;
	}
	if (! $this -> __checkHaveTypeToBuild()) {
		return;
	}
	if (! $this -> __checkFilesystemTool()) {
		return;
	}
	if (! $this -> __checkOEMsizeSettingSufficient()) {
		return;
	}
	if (! $this -> __checkPackageManagerExists()) {
		return;
	}
	if (! $this -> __checkVMConverterExist()) {
		return;
	}
	if (! $this -> __checkVMControllerCapable()) {
		return;
	}
	if (! $this -> __checkVMdiskmodeCapable()) {
		return;
	}
	if (! $this -> __hasValidLVMName()) {
		return;
	}
	if (! $this -> __isoHybridCapable()) {
		return;
	}
	if (! $this -> __checkLVMoemSizeSettings()) {
		return;
	}
	if (! $this -> __checkSystemDiskData()) {
		return;
	}
	return 1;
}

#==========================================
# prepareChecks
#------------------------------------------
sub prepareChecks {
	# ...
	# Runtime checks specific to the prepare step
	# ---
	my $this = shift;
	if (! $this -> __haveValidTypeString()) {
		return;
	}
	if (! $this -> __checkProfileConsistent()) {
		return;
	}
	if (! $this -> __checkHaveTypeToBuild()) {
		return;
	}
	if (! $this -> __checkLVMoemSizeSettings()) {
		return;
	}
	if (! $this -> __checkPackageManagerExists()) {
		return;
	}
	if (! $this -> __checkPatternTypeAttrValueConsistent()) {
		return;
	}
	if (! $this -> __checkRepoAliasUnique()) {
		return;
	}
	if (! $this -> __checkRootRecycleCapability()) {
		return;
	}
	if (! $this -> __checkUsersConsistent()) {
		return;
	}
	if (! $this -> __hasValidArchives()) {
		return;
	}
	if (! $this -> __checkVMConverterExist()) {
		return;
	}
	if (! $this -> __checkVMControllerCapable()) {
		return;
	}
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __checkSwapRecommended
#------------------------------------------
sub __checkSwapRecommended {
	my $this    = shift;
	my $kiwi    = $this -> {kiwi};
	my $xml     = $this -> {xml};
	my $type    = $xml  -> getImageType();
	my $sysDisk = $xml  -> getSystemDiskConfig();
	my $oemConf = $xml  -> getOEMConfig();
	#==========================================
	# Variables
	#------------------------------------------
	my $volumeResizeRequest = 0;
	my $swapRequested = 0;
	my $systemSize = 0;
	my $systemSwap = 0;
	#==========================================
	# no type information
	#------------------------------------------
	if (! $type) {
		return 1;
	}
	#==========================================
	# Perform the test only for oem images
	#------------------------------------------
	my $imgType = $type -> getTypeName();
	if ($imgType ne "oem") {
		return 1;
	}
	#==========================================
	# Collect size values
	#------------------------------------------
	if ($sysDisk) {
		my $volIDs = $sysDisk -> getVolumeIDs();
		if ($volIDs) {
			foreach my $id (@{$volIDs}) {
				my $size = $sysDisk -> getVolumeSize ($id);
				if ($size) {
					$volumeResizeRequest = 1;
					last;
				} else {
					$size = $sysDisk -> getVolumeFreespace ($id);
					if ($size ne "all") {
						$volumeResizeRequest = 1;
						last;
					}
				}
			}
		}
	}
	if ($oemConf) {
		$swapRequested = $oemConf -> getSwap();
		$systemSize = $oemConf -> getSystemSize();
		$systemSwap = $oemConf -> getSwapSize();
	}
	#==========================================
	# Check if a swapsize should be specified
	#------------------------------------------
	if (($swapRequested) && (! $systemSwap)) {
		if (($volumeResizeRequest) || ($systemSize)) {
			$kiwi -> warning (
				"--> Got explicit sizes for system/volumes but not for swap"
			);
			$kiwi -> notset();
			# warning only, thus return success
			return 1;
		}
	}
	#==========================================
	# We got that far, nice
	#------------------------------------------
	return 1;
}

#==========================================
# __checkContainerHasLXC
#------------------------------------------
sub __checkContainerHasLXC {
	# ...
	# A container build must include the lxc package
	# ---
	my $this = shift;
	my $xml  = $this -> {xml};
	my $type = $xml  -> getImageType();
	if (! $type) {
		return 1;
	}
	my $name = $type -> getTypeName();
	if ($name =~ /^lxc/smx) {
		my $pckgs = $xml -> getPackages();
		push @{$pckgs}, @{$xml -> getBootstrapPackages()};
		for my $pckg (@{$pckgs}) {
			my $pname = $pckg -> getName();
			if ($pname =~ /^lxc/smx) {
				return 1;
			}
		}
		my $kiwi = $this->{kiwi};
		my $msg = 'Attempting to build container, but no lxc package included '
			. 'in image.';
		$kiwi -> error ( $msg );
		$kiwi -> failed ();
		return;
	}
	return 1;
}


#==========================================
# __checkLVMoemSizeSettings
#------------------------------------------
sub __checkLVMoemSizeSettings {
	# ...
	# Verify that the specified LVM size requirements do not
	# exceed the specified OEM system size if specified
	# ---
	my $this        = shift;
	my $kiwi        = $this -> {kiwi};
	my $xml         = $this -> {xml};
	my $type        = $xml  -> getImageType();
	my $oemConf     = $xml  -> getOEMConfig();
	my $volSizes    = 0;
	my $volAllCount = 0;
	#==========================================
	# No type information
	#------------------------------------------
	if (! $type) {
		return 1;
	}
	#==========================================
	# Perform the test only for oem images
	#------------------------------------------
	my $imgType     = $type -> getTypeName();
	if ($imgType ne "oem") {
		return 1;
	}
	#==========================================
	# Perform the test only with oemconfig
	#------------------------------------------
	if (! $oemConf) {
		return 1;
	}
	#==========================================
	# Collect volume size values and swap
	#------------------------------------------
	my $sysDisk = $xml  -> getSystemDiskConfig();
	if ($sysDisk) {
		my $volIDs = $sysDisk -> getVolumeIDs();
		if ($volIDs) {
			for my $id (@{$volIDs}) {
				my $size = $sysDisk -> getVolumeSize ($id);
				my $freeSpace = $sysDisk -> getVolumeFreespace ($id);
				if (($size) && ($freeSpace)) {
					my $msg;
					$msg = 'Found size and freespace specified for one volume';
					$kiwi -> error ($msg);
					$kiwi -> failed();
					return;
				}
				if (($size) && ($size ne 'all')) {
					$volSizes += $size;
				} elsif (($size) && ($size eq 'all')) {
					$volAllCount++;
				}
				# /.../
				# this is a fast check which also runs in
				# prepare. Thus we can't do a correct check for
				# the freespace size requests because we don't
				# know the real size prior to the installation
				# ----
				if (($freeSpace) && ($freeSpace ne 'all')) {
					$volSizes += $freeSpace;
				} elsif (($freeSpace) && ($freeSpace eq 'all')) {
					$volAllCount++;
				}
			}
		}
	}
	#==========================================
	# Check all size setup
	#------------------------------------------
	if ($volAllCount > 1) {
		my $msg;
        $msg = 'Multiple volumes flagged with the "all" size attribute';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	#==========================================
	# Check size values
	#------------------------------------------
	my $systemSize = $oemConf -> getSystemSize();
	if (($systemSize) && ($systemSize < $volSizes)) {
		my $msg;
		$msg = 'Specified system size is smaller than requested ';
		$msg.= 'volume sizes';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __checkFilesystemTool
#------------------------------------------
sub __checkFilesystemTool {
	# ...
	# Check that the build system has the necessary file
	# system tools installed for the requested build.
	# ---
	my $this = shift;
	my $cmdL = $this -> {cmdArgs};
	my $xml  = $this -> {xml};
	my $type = $xml -> getImageType();
	if (! $type) {
		return 1;
	}
	my $typeName = $type -> getTypeName();
	my $flag     = $type -> getFlags();
	my $toolError;
	my $checkedFS;
	my @knownFsTypes = qw (
		btrfs clicfs ext2 ext3 ext4 reiserfs squashfs xfs cpio zfs
	);
	if (grep { /^$typeName/x } @knownFsTypes) {
		my $haveTool = $this -> __isFsToolAvailable($typeName);
		$checkedFS = $typeName;
		if (! $haveTool) {
			$toolError = 1;
		}
	} elsif ($typeName eq 'tbz') {
		my $genTool = $this -> {locator} -> getExecPath('tar');
		if (! $genTool) {
			$checkedFS = 'tbz';
			$toolError = 1;
		}
	} elsif ($typeName eq 'iso') {
		my $genTool = $this -> {locator} -> getExecPath('genisoimage');
		my $mkTool = $this -> {locator} -> getExecPath('mkisofs');
		if ((! $genTool) && (! $mkTool)) {
			$checkedFS = 'iso';
			$toolError = 1;
		}
		my $haveTool;
		if ($flag && $flag =~ /clic|clic_udf/x) {
			$haveTool = $this -> __isFsToolAvailable('clicfs');
			$checkedFS = 'clicfs';
		} elsif ($flag && $flag eq 'seed') {
			$haveTool = $this -> __isFsToolAvailable('btrfs');
			$checkedFS = 'btrfs';
		} elsif ($flag && $flag =~ /compressed|overlay/) {
			$haveTool = $this -> __isFsToolAvailable('squashfs');
			$checkedFS = 'squashfs';
		}
		if (($flag) && (! $haveTool)) {
			$toolError = 1;
		}
	} else {
		my @fsType;
		my $fs = $type -> getFilesystem();
		my $roFS = $type -> getFSReadOnly();
		my $rwFS = $type -> getFSReadWrite();
		if ($fs) {
			push @fsType, $type -> getFilesystem();
		}
		if ($roFS) {
			push @fsType, $roFS;
		}

		if ($rwFS) {
			push @fsType, $rwFS;
		}
		foreach my $fs (@fsType) {
			my $haveTool = $this -> __isFsToolAvailable($fs);
			if (! $haveTool) {
				$checkedFS = $fs;
				$toolError = 1;
			}
		}
	}
	if ($toolError) {
		my $kiwi = $this -> {kiwi};
		my $msg = 'Requested image creation with filesystem "'
		. $checkedFS
		. '"; but tool to create the file system could not '
		. 'be found.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __checkHaveTypeToBuild
#------------------------------------------
sub __checkHaveTypeToBuild {
	# ...
	# Check that there is a type to build:
	# 1.) config file must have <preferences> without profile
	# or
	# 2.) one profile on a <preferences> element is marked as default
	# or
	# 3.) one profile on a <preferences> element specified on the command line
	# ---
	#TODO
	# implement when XML becomes a dumb container and looses notion of state
	return 1;
}

#==========================================
# __checkOEMsizeSettingSufficient
#------------------------------------------
sub __checkOEMsizeSettingSufficient {
	# ...
	# Verify that the image fits within the specified size
	# ---
	my $this    = shift;
	my $kiwi    = $this -> {kiwi};
	my $xml     = $this -> {xml};
	my $type    = $xml  -> getImageType();
	#==========================================
	# No type information
	#------------------------------------------
	if (! $type) {
		return 1;
	}
	#==========================================
	# Perform the test only for oem images
	#------------------------------------------
	my $imgType = $type -> getTypeName();
	if ($imgType ne "oem") {
		return 1;
	}
	#==========================================
	# Check calculated vs requested system size
	#------------------------------------------
	my $oemConf = $xml -> getOEMConfig();
	my $cmdL    = $this -> {cmdArgs};
	my $tree    = $cmdL -> getConfigDir();
	if ($oemConf) {
		my $systemSize = $oemConf -> getSystemSize();
		if ($systemSize) {
			my $rootsize = KIWIGlobals -> instance() -> dsize ($tree);
			$rootsize = sprintf ("%.f",$rootsize / $MEGABYTE);
			if ($rootsize > $systemSize) {
				my $msg;
				$msg = "System requires $rootsize MB, but size ";
				$msg.= "constraint set to $systemSize MB";
				$kiwi -> error ($msg);
				$kiwi -> failed();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __checkPackageManagerExists
#------------------------------------------
sub __checkPackageManagerExists {
	# ...
	# Check that the specified package manager exists
	# ---
	my $this = shift;
	my $prefObj = $this -> {xml} -> getPreferences();
	if (! $prefObj) {
		return;
	}
	my $pkgMgr = $prefObj -> getPackageManager();
	my $haveExec = $this -> {locator} -> getExecPath($pkgMgr);
	if (! $haveExec) {
		my $msg = "Executable for specified package manager, $pkgMgr, "
			. 'could not be found.';
		$this -> {kiwi} -> error($msg);
		$this -> {kiwi} -> failed();
		return;
	}
	return 1;
}

#==========================================
# __checkProfileConsistent
#------------------------------------------
sub __checkProfileConsistent {
	# ...
	# Check if the selected profiles exists
	# ---
	my $this = shift;
	my $xml  = $this->{xml};
	my $message;
	my $profiles = $xml -> getActiveProfileNames();
	$message  = 'Attempting to set active profile to "PROF_NAME", but ';
	$message .= 'this profile cannot be not found in the configuration.';
	if (! $xml -> __verifyProfNames ($profiles, $message)) {
        return;
    }
	return 1;
}

#==========================================
# __checkPatternTypeAttrValueConsistent
#------------------------------------------
sub __checkPatternTypeAttrValueConsistent {
	# ...
	# Check that the use of the patternType attribute for the <packages>
	# element is consistent. The static component of this is checked during
	# XML validation. If no profiles are specified on the command line
	# or if the configuration contains a <packages> element without a
	# profile attribute there is nothing to do.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $buildProfiles = $this -> {cmdArgs} -> getBuildProfiles();
	# If no profiles are specified on the command line the static check is
	# sufficient
	if ( (ref $buildProfiles) ne 'ARRAY') {
		return 1;
	}
	my @buildProfiles = @{$buildProfiles};
	# If there is only one profile to be built there is nothing to check
	my $numProfiles = @buildProfiles;
	if (!$numProfiles || $numProfiles == 1) {
		return 1;
	}
	my $xml = $this->{xml};
	my $curActiveProfiles = $xml -> getActiveProfileNames();
	# Set the profiles to the profiles given on the command line
	my $msg = 'Set profiles to command line provided profiles '
		. "for validation.\n";
	$kiwi->info($msg);
	my $res = $xml -> setSelectionProfileNames($buildProfiles);
	if (! $res) {
		return;
	}
	# XML returns undef if the type cannot be resolved because of a conflict
	my $installOpt = $xml -> getInstallOption();
	if (! $installOpt) {
		my $msg = 'Conflicting patternType attribute values for '
			. 'specified profiles "'
			. "@buildProfiles"
			. '" found';
		$kiwi -> error ( $msg );
		$kiwi -> failed ();
		return;
	}
	# Reset the profiles
	$msg = "Reset profiles to original values.\n";
	$kiwi->info($msg);
	$xml -> setSelectionProfileNames($curActiveProfiles);
	return 1;
}

#==========================================
# __checkRepoAliasUnique
#------------------------------------------
sub __checkRepoAliasUnique {
	# ...
	# Verify that the repo alias is unique across the currently active repos
	# ---
	my $this = shift;
	my $xml = $this -> {xml};
	my @repos = @{$xml -> getRepositories()};
	my %aliasUsed;
	for my $repo (@repos) {
		my $alias = $repo -> getAlias();
		if (! $alias) {
			next
		}
		if ($aliasUsed{$alias}) {
			my $kiwi = $this->{kiwi};
			my $msg = "Specified repo alias '$alias' not unique across "
				. 'active repositories';
			$kiwi -> error ( $msg );
			$kiwi -> failed ();
			return;
		}
		$aliasUsed{$alias} = 1;
	}
	return 1;
}

#==========================================
# __checkRootRecycleCapability
#------------------------------------------
sub __checkRootRecycleCapability {
	# ...
	# Check the root tree if --recycle-root is set. In that case
	# it's not allowed to use a root tree which is based on
	# an image cache
	# ---
	my $this = shift;
	my $cmdL = $this -> {cmdArgs};
	my $tree = $cmdL -> getRecycleRootDir();
	my $kiwi = $this -> {kiwi};
	if (($tree) && (! -d $tree)) {
		$kiwi -> error ("Specified recycle tree doesn't exist: $tree");
		$kiwi -> failed();
		return;
	}
	if (($tree) && (-f "$tree/image/kiwi-root.cache")) {
		$kiwi -> error ("Can't recycle cache based root tree");
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __checkSystemDiskData
#------------------------------------------
sub __checkSystemDiskData {
	my $this    = shift;
	my $kiwi    = $this -> {kiwi};
	my $cmdL    = $this -> {cmdArgs};
	my $xml     = $this -> {xml};
	my $type    = $xml  -> getImageType();
	my $oemConf = $xml  -> getOEMConfig();
	#==========================================
	# No type information
	#------------------------------------------
	if (! $type) {
		return 1;
	}
	#==========================================
	# Perform the test only for oem images
	#------------------------------------------
	my $imgType = $type -> getTypeName();
	if ($imgType ne "oem") {
		return 1;
	}
	#==========================================
	# Collect real/specified system sizes
	#------------------------------------------
	my $sysDisk  = $xml  -> getSystemDiskConfig();
	my $tree     = $cmdL -> getConfigDir();
	my $needFree = 0;
	my $rootsize = 0;
	my $lvsum    = 0;
	my $msg;
	if ($sysDisk) {
		my $volIDs = $sysDisk -> getVolumeIDs();
		if ($volIDs) {
			for my $id (@{$volIDs}) {
				my $name = $sysDisk -> getVolumeName ($id);
				my $size = $sysDisk -> getVolumeSize ($id);
				my $freeSpace = $sysDisk -> getVolumeFreespace ($id);
				my $lvsize = 0;
				my $lvpath;
				my $path = $name;
				$path =~ s/_/\//g;
				if ($name eq '@root') {
					$rootsize = KIWIGlobals -> instance() -> dsize ($tree);
					$rootsize = sprintf ("%.f",$rootsize / $MEGABYTE);
					next;
				}
				if (! -d "$tree/$path") {
					$msg = "Volume path $path does not exist ";
					$msg.= 'in unpacked tree';
					$kiwi -> error ($msg);
					$kiwi -> failed();
					return;
				}
				$lvpath = "$tree/$path";
				$lvsize = KIWIGlobals -> instance() -> dsize ($lvpath);
				$lvsize = sprintf ("%.f",$lvsize / $MEGABYTE);
				$lvsum += $lvsize;
				if (($size) && ($size ne 'all')) {
					if ($lvsize > $size) {
						$msg = "Required size for $name [ $lvsize MB ] ";
						$msg.= "is larger than specified size [ $size ] MB";
						$kiwi -> error ($msg);
						$kiwi -> failed();
						return;
					}
					$needFree += $size - $lvsize;
				}
				if (($freeSpace) && ($freeSpace ne 'all')) {
					$needFree += $freeSpace;
				}
			}
			if ($rootsize) {
				$rootsize -= $lvsum;
				$needFree += $rootsize;
			}
		}
	}
	#==========================================
	# Check integrity of overall size setup
	#------------------------------------------
	my $systemSize = 0;
	if ($oemConf) {
		$systemSize = $oemConf -> getSystemSize();
	}
	if (! $systemSize) {
		# No overall constraint, no additional checks required
		return 1;
	}
	if ($needFree) {
		my $rootsize = KIWIGlobals -> instance() -> dsize ($tree);
		$rootsize = sprintf ("%.f",$rootsize / $MEGABYTE);
		my $freesize = $systemSize - $rootsize;
		if ($freesize < $needFree) {
			$msg = "Calculated $freesize MB free, ";
			$msg.= "but require $needFree MB";
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkUsersConsistent
#------------------------------------------
sub __checkUsersConsistent {
	# ...
	# User definitions may conflict in different profiles in the
	# static definition. However, at build time only profiles with
	# non conflicting user definitions may be selected.
	# ---
	my $this = shift;
	my $xml = $this -> {xml};
	my $userData = $xml -> getUsers();
	if (! $userData) {
		return;
	}
	return 1;
}

#==========================================
# __checkVMConverterExist
#------------------------------------------
sub __checkVMConverterExist {
	# ...
	# Check that the required converter exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $bldType = $xml -> getImageType();
	if (! $bldType) {
		return 1;
	}
	my $format = $bldType -> getFormat();
	if ((! $format) || ($format ne 'ova')) {
		return 1;
	}
	my $converter = 'ovftool';
	my $convCmd = $this->{locator}->getExecPath($converter);
	if (! $convCmd) {
		my $msg = "$converter tool not found on system.";
		$kiwi -> error  ($msg);
		$kiwi -> failed ();
		return;
	}
	return 1;
}

#==========================================
# __checkVMControllerCapable
#------------------------------------------
sub __checkVMControllerCapable {
	# ...
	# If a VM image is being built and the specified vmdisk controller,
	# then the qemu-img command on the system must support this option.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $type = $xml->getImageType();
	if (! $type) {
		return 1;
	}
	my $imgtype = $type -> getTypeName();
	if (($imgtype ne 'vmx') && ($imgtype ne 'oem')) {
		# Nothing to do
		return 1;
	}
	my $vmConfig = $xml -> getVMachineConfig();
	if (! $vmConfig) {
		# no machine config requested, ok
		return 1;
	}
	my $diskCnt = $vmConfig -> getSystemDiskController();
	if (($diskCnt) && ($diskCnt ne 'ide')) {
		my $QEMU_IMG_CAP;
		my $msg;
		if (! open($QEMU_IMG_CAP, '-|', "qemu-img create -f vmdk foo -o '?'")) {
			$msg = 'Could not execute qemu-img command. ';
			$msg.= 'This precludes format conversion.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
		my $ok = 0;
		while (<$QEMU_IMG_CAP>) {
			if ($_ =~ /adapter_type/) {
				# newer version support adapter_type option, ok
				$ok = 1;
				last;
			}
		}
		if ($ok) {
			close $QEMU_IMG_CAP;
			return 1;
		}
		close $QEMU_IMG_CAP;
		# can't create image format for this adapter type
		$msg = "Configuration specifies $diskCnt vmdisk controller."."\n";
		$msg.= "This disk type cannot be created on this system."."\n";
		$msg.= "The qemu-img command must support the option:"."\n";
		$msg.= "\t\"-o adapter_type=$diskCnt\""."\n";
		$msg.= "Upgrade to a newer version of qemu-img"."\n";
		$msg.= "Alternatively change the controller type to ide"."\n";
		$kiwi -> error ($msg);
		return;
	}
	return 1;
}

#==========================================
# __checkVMdiskmodeCapable
#------------------------------------------
sub __checkVMdiskmodeCapable {
	# ...
	# qemu-img command must support specified diskmode
	# ---
	my $this = shift;
	my $xml = $this -> {xml};
	my $type = $xml -> getImageType();
	if (! $type) {
		return 1;
	}
	my $imgtype = $type -> getTypeName();
	if ($imgtype ne 'vmx') {
		# Nothing to do
		return 1;
	}
	my $vmConfig = $xml -> getVMachineConfig();
	if (! $vmConfig) {
		# no machine config requested, ok
		return 1;
	}
	my $converter = $vmConfig -> getSystemDiskConverter();
	if ($converter eq 'ovftool') {
		# no need in check
		return 1;
	}
	my $diskMode = $vmConfig -> getSystemDiskMode();
	if ($diskMode) {
		my $QEMU_IMG_CAP;
		if (! open($QEMU_IMG_CAP, '-|', "qemu-img create -f vmdk foo -o '?'")){
			my $msg = 'Could not execute qemu-img command. This precludes '
			. 'format conversion.';
			$this -> {kiwi} -> error ($msg);
			$this -> {kiwi} -> failed ();
			return;
		}
		while (<$QEMU_IMG_CAP>) {
			if ($_ =~ /$diskMode/x) {
				close $QEMU_IMG_CAP;
				return 1;
			}
		}
		# Not scsi capable
		close $QEMU_IMG_CAP;
		my $msg = "Configuration specifies diskmode $diskMode. This disk "
		. "mode cannot be\ncreated on this system. The qemu-img command "
		. 'must support the "-o subformat" option, but does not. Upgrade'
		. "\nto a newer version of qemu-img or keep default mode";
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed ();
		return;
	}
	return 1;
}
#==========================================
# __hasValidLVMName
#------------------------------------------
sub __hasValidLVMName {
	# ...
	# check if the optional LVM group name doesn't
	# exist on the build host
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $sysDisk = $xml -> getSystemDiskConfig();
	if (! $sysDisk ) {
		return 1;
	}
	my $vgroupName = $sysDisk -> getVGName();
	if (! $vgroupName) {
		return 1;
	}
	my $vgsCmd = $this->{locator}->getExecPath('vgs');
	if (! $vgsCmd) {
		my $msg = 'LVM definition in configuration being processed, but '
			. 'necessary tools not found on system.';
		$kiwi -> error  ($msg);
		$kiwi -> failed ();
		return;
	}
	my @hostGroups = qxx ("$vgsCmd --noheadings -o vg_name 2>/dev/null");
	chomp @hostGroups;
	foreach my $hostGroup (@hostGroups) {
		$hostGroup =~ s/^\s+//xg;
		$hostGroup =~ s/\s+$//xg;
		if ($hostGroup eq $vgroupName) {
			my $msg = "There is already a volume group ";
			$msg .= "named \"$vgroupName\" on this build host";
			$kiwi -> error  ($msg);
			$kiwi -> failed ();
			$msg = "Please choose another name in your image configuration";
			$kiwi -> error  ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	return 1;
}

#==========================================
# __hasValidArchives
#------------------------------------------
sub __hasValidArchives {
	# ...
	# check if the optional given archives doesn't
	# include bogus files
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $cmdL = $this->{cmdArgs};
	my $archives = $xml -> getArchives();
	my $desc = $cmdL-> getConfigDir();
	if (! $desc) {
		return 1;
	}
	my @nogo = ('^etc\/YaST2\/licenses\/.*');
	#==========================================
	# check for origin of image description
	#------------------------------------------
	if (open my $FD, '<', "$desc/image/main::Prepare") {
		$desc = <$FD>;
		close $FD;
	}
	#==========================================
	# check archive contents
	#------------------------------------------
	for my $ar (@{$archives}) {
		my $arName = $ar -> getName();
		if (! -f "$desc/$arName") {
			$kiwi -> error (
				"specified archive $arName doesn't exist in $desc"
			);
			$kiwi -> failed ();
			return;
		}
		my $contents = qxx ("tar -tf $desc/$arName 2>&1");
		for my $exp (@nogo) {
			if (grep { /$exp/x } $contents ) {
				$kiwi -> error  ("bogus archive contents in $ar");
				$kiwi -> failed ();
				$kiwi -> error  ("archive matches: $exp");
				$kiwi -> failed ();
				return;
			}
		}
	}
	return 1;
}

#==========================================
# __haveValidTypeString
#------------------------------------------
sub __haveValidTypeString {
	# ...
	# if the commandline data set contains buildtype
	# information, check if it contains a valid string
	# This check must be done for prepare and create in
	# order to early detect a broken commandline when
	# using prepare + create in one call by the --build
	# option
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $cmdL = $this->{cmdArgs};
	my $type = $cmdL -> getBuildType();
	my @allowedTypes = qw (
		btrfs
		clicfs
		cpio
		ext2
		ext3
		ext4
		iso
		lxc
		oem
		product
		pxe
		reiserfs
		split
		squashfs
		tbz
		vmx
		xfs
		zfs
	);
	if ($type) {
		if (! grep { /$type/x } @allowedTypes) {
			my $kiwi = $this -> {kiwi};
			my $msg = 'Specified value for "type" command line argument is '
				. 'not valid.';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
	}
	my $bldType = $xml -> getImageType();
	if (! $bldType) {
		my $msg = 'Cannot determine build type';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return 1;
}

#==========================================
# __isFsToolAvailable
#------------------------------------------
sub __isFsToolAvailable {
	# ...
	# Find the tool for a given filesystem name
	# ---
	my $this   = shift;
	my $fsType = shift;
	my $locator = $this -> {locator};
	if ($fsType eq 'btrfs' ) {
		return $locator -> getExecPath('mkfs.btrfs');
	}
	if ($fsType eq 'clicfs' ) {
		return $locator -> getExecPath('mkclicfs');
	}
	if ($fsType eq 'overlayfs' ) {
		return $locator -> getExecPath('mksquashfs');
	}
	if ($fsType eq 'cpio' ) {
		return $locator -> getExecPath('cpio');
	}
	if ($fsType eq 'ext2' ) {
		return $locator -> getExecPath('mkfs.ext2');
	}
	if ($fsType eq 'ext3' ) {
		return $locator -> getExecPath('mkfs.ext3');
	}
	if ($fsType eq 'ext4' ) {
		return $locator -> getExecPath('mkfs.ext4');
	}
	if ($fsType eq 'reiserfs' ) {
		return $locator -> getExecPath('mkreiserfs');
	}
	if ($fsType eq 'squashfs' ) {
		return $locator -> getExecPath('mksquashfs');
	}
	if ($fsType eq 'xfs' ) {
		return $locator -> getExecPath('mkfs.xfs');
	}
	if ($fsType eq 'zfs' ) {
		return $locator -> getExecPath('zpool');
	}
}

#==========================================
# __isoHybridCapable
#------------------------------------------
sub __isoHybridCapable {
	# ...
	# If an ISO image is being built check that if an iso hybrid is
	# requested, the platform is capable. Check if the uefi capability
	# exists if isohybrid is allowed on given platform.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $locator = $this->{locator};
	my $xml = $this->{xml};
	my $bldType = $xml -> getImageType();
	if (! $bldType) {
		return 1;
	}
	my $imgType = $bldType -> getTypeName();
	if ($imgType ne 'iso' && $imgType ne 'oem') {
		return 1;
	}
	my $instIso = $bldType -> getInstallIso();
	my $bootloader = $bldType -> getBootLoader();
	my $hybPersist = $bldType -> getHybridPersistent();
	my $arch = KIWIGlobals -> instance() -> getArch();

	if (
		( $instIso
		&& $instIso eq 'true'
		&& $bootloader
		&& $bootloader =~ /(sys|ext)linux/smx
		&& $imgType eq 'oem'
		)
		||
		( $hybPersist
		&& $hybPersist eq 'true'
		&& $imgType eq 'iso'
		)
	) {
		if ($arch ne 'i686' && $arch ne 'i586' && $arch ne 'x86_64') {
			my $msg = 'Attempting to create hybrid ISO image on a platform '
				. 'that does not support hybrid ISO creation.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
		my $isoHybrid = $locator -> getExecPath('isohybrid');
		if (! $isoHybrid) {
			my $msg = 'Attempting to create hybrid ISO image but cannot find '
				. 'isohybrid executable. Please install the binary.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
		my $firmware = $bldType -> getFirmwareType();
		if ($firmware ne 'efi' && $firmware ne 'uefi') {
			return 1;
		}
		my @opt = ('uefi');
		my %cmdOpt = %{$locator -> getExecArgsFormat ($isoHybrid, \@opt)};
		if (! $cmdOpt{'status'}) {
			my $msg = 'Attempting to build EFI capable hybrid ISO image, but '
				. 'installed isohybrid binary does not support this option.';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	return 1;
}

#==========================================
# __checkVMConverterExist
#------------------------------------------
sub __checkVMConverterExist {
	# ...
	# Check that the specified converter exists
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xml  = $this->{xml};
	my $sysDisk = $xml -> getSystemDiskConfig();
	if (! $sysDisk ) {
		return 1;
	}
	my $converter = $sysDisk -> getSystemDiskConverter();
	if (! $converter ) {
		# default converter
		$converter='qemu-img';
	}
	my $convCmd = $this->{locator}->getExecPath($converter);
	if (! $convCmd) {
		my $msg = "$converter tool not found on system.";
		$kiwi -> error  ($msg);
		$kiwi -> failed ();
		return;
	}
	return 1;	
}

1;
