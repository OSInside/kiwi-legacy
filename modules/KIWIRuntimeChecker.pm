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
use KIWIXMLVMachineData;


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
	$this->{locator} = KIWILocator -> new();
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
	if (! $this -> __haveValidTypeString()) {
		return;
	}
	if (! $this -> __checkHaveTypeToBuild()) {
		return;
	}
	if (! $this -> __checkFilesystemTool()) {
		return;
	}
	if (! $this -> __checkPackageManagerExists()) {
		return;
	}
	if (! $this -> __checkVMscsiCapable()) {
		return;
	}
	if (! $this -> __hasValidLVMName()) {
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
	if (! $this -> __checkHaveTypeToBuild()) {
		return;
	}
	if (! $this -> __checkPackageManagerExists()) {
		return;
	}
	if (! $this -> __checkPatternTypeAttrrValueConsistent()) {
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
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
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
			$kiwi -> warning ("specified archive $ar doesn't exist in $desc");
			$kiwi -> skipped ();
			next;
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
	my $cmdL = $this -> {cmdArgs};
	my $type = $cmdL -> getBuildType();
	my @allowedTypes = qw (
		btrfs clicfs cpio ext2 ext3 ext4 iso
		oem product pxe reiserfs split squashfs
		tbz vmx xfs
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
	if (($tree) && (-f "$tree/kiwi-root.cache")) {
		$kiwi -> error ("Can't recycle cache based root tree");
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
	my $typeName = $type -> getImageType();
	my $flag     = $type -> getFlags;
	my $toolError;
	my $checkedFS;
	my @knownFsTypes = qw (
		btrfs clicfs ext2 ext3 ext4 reiserfs squashfs xfs cpio
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
		} elsif ($flag && $flag eq 'compressed') {
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
# __checkPatternTypeAttrValueConsistent
#------------------------------------------
sub __checkPatternTypeAttrrValueConsistent {
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
	$kiwi->done();
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
	$kiwi->done();
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
# __checkVMscsiCapable
#------------------------------------------
sub __checkVMscsiCapable {
	# ...
	# If a VM image is being built and the specified vmdisk controller is
	# scsi, then the qemu-img command on the system must support the scsi
	# option.
	# ---
	my $this = shift;
	my $xml = $this -> {xml};
	my $typeObj = $xml -> getImageType();
	my $type = $typeObj -> getImageType();
	if ($type ne 'vmx') {
		# Nothing to do
		return 1;
	}
	my $vmConfig = $xml -> getVMachineConfig();
	if (! $vmConfig) {
		return;
	}
	my $diskType = $vmConfig -> getSystemDiskType();
	if ($diskType) {
		if ($diskType ne 'scsi') {
			# Nothing to do
			return 1;
		}
		my $QEMU_IMG_CAP;
		if (! open($QEMU_IMG_CAP, '-|', "qemu-img create -f vmdk foo -o '?'")){
			my $msg = 'Could not execute qemu-img command. This precludes '
			. 'format conversion.';
			$this -> {kiwi} -> error ($msg);
			$this -> {kiwi} -> failed ();
			return;
		}
		while (<$QEMU_IMG_CAP>) {
			if ($_ =~ /^scsi/x) {
				close $QEMU_IMG_CAP;
				return 1;
			}
		}
		# Not scsi capable
		close $QEMU_IMG_CAP;
		my $msg = 'Configuration specifies scsi vmdisk controller. This disk '
		. "type cannot be\ncreated on this system. The qemu-img command "
		. 'must support the "-o scsi" option, but does not. Upgrade'
		. "\nto a newer version of qemu-img or change the controller to ide";
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed ();
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
}

1;
