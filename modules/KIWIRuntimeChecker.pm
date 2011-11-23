#================
# FILE          : KIWIRuntimeChecker.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
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
require Exporter;
use KIWILocator;
use KIWILog;
use KIWIQX;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT_OK = qw (createChecks prepareChecks);

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
	my $kiwi    = shift;
	my $cmdArgs = shift;
	my $xml     = shift;
	#==========================================
	# Check pre-conditions
	#------------------------------------------
	if (! $cmdArgs ) {
		my $msg = 'Expecting reference to KIWICommandLine object as second '
		. 'argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (! $xml ) {
		my $msg = 'Expecting reference to KIWIXML object as third argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = KIWILog -> new("tiny");
	}
	$this->{cmdArgs} = $cmdArgs;
	$this->{locator} = KIWILocator -> new($kiwi);
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
	if (! $this -> __checkRootRecycleCapability()) {
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
	my @list = $xml -> getArchiveList();
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
	for my $ar (@list) {
		if (! -f "$desc/$ar") {
			$kiwi -> warning ("specified archive $ar doesn't exist in $desc");
			$kiwi -> skipped ();
			next;
		}
		my $contents = qxx ("tar -tf $desc/$ar 2>&1");
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
		vmx xfs
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
	my %type = %{$xml->getImageTypeAndAttributes()};
	my $typeName = $type{type};
	my $flag     = $type{flags};
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
	} elsif ($typeName eq 'iso') {
		my $genTool = $this -> {locator} -> getExecPath('genisoimage');
		my $mkTool = $this -> {locator} -> getExecPath('mkisofs');
		if ((! $genTool) && (! $mkTool)) {
			$checkedFS = 'iso';
			$toolError = 1;
		}
		my $haveTool;
		if ($flag && $flag eq 'clic') {
			$haveTool = $this -> __isFsToolAvailable('clicfs');
			$checkedFS = 'clicfs';
		} elsif ($flag && $flag eq 'compressed') {
			$haveTool = $this -> __isFsToolAvailable('squashfs');
			$checkedFS = 'squashfs';
		} elsif ($flag && $flag eq 'unified') {
			$haveTool = $this -> __isFsToolAvailable('squashfs');
			$checkedFS = 'squashfs';
		}
		if (($flag) && (! $haveTool)) {
			$toolError = 1;
		}
	} else {
		my @fsType = ($type{filesystem});
		if ($type{filesystem} =~ /(.*),(.*)/) {
			@fsType = ($1,$2);
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
	my $pkgMgr = $this -> {xml} -> getPackageManager();
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
	my $buildProfiles = $this -> {cmdArgs} -> getBuildProfiles();
	# If no profiles are specified on the command line the static check is
	# sufficient
	if ( (ref $buildProfiles) ne 'ARRAY') {
		return 1;
	}
	my @buildProfiles = @{$buildProfiles};
	# If there is a "default" <packages> element, i.e. an element without the
	# profiles attribute the static check is sufficient
	if ($this -> {xml} -> hasDefaultPackages() ) {
		return 1;
	}
	# If there is only one profile to be built there is nothing to check
	my $numProfiles = @buildProfiles;
	if ($numProfiles == 1) {
		return 1;
	}
	my @pkgsNodes = @{$this -> {xml} -> getPackageNodeList()};
	my $reqPatternTypeVal;
	for my $pkgs (@pkgsNodes) {
		my $profiles = $pkgs -> getAttribute( 'profiles' );
		if (! $profiles) {
			next;
		}
		my @profNames = split /,/, $profiles;
		my $patternType = $pkgs -> getAttribute( 'patternType' );
		if (! $patternType) {
			$patternType = 'onlyRequired';
		}
		for my $profName (@profNames) {
			if (grep { /^$profName/ } @buildProfiles) {
				if (! $reqPatternTypeVal) {
					$reqPatternTypeVal = $patternType;
				} elsif ($reqPatternTypeVal ne $patternType) {
					my $kiwi = $this -> {kiwi};
					my $msg = 'Conflicting patternType attribute values for '
					. 'specified profiles "'
					. "@buildProfiles"
					. '" found';
					$kiwi -> error ( $msg );
					$kiwi -> failed ();
					return;
				}
			}
		}
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
	my $typeInfo = $xml -> getImageTypeAndAttributes();
	my $type = $typeInfo -> {type};
	if ($type ne 'vmx') {
		# Nothing to do
		return 1;
	}
	my %vmConfig = $xml -> getVMwareConfig();
	if (defined $vmConfig{vmware_disktype} ) {
		my $diskType = $vmConfig{vmware_disktype};
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
			if ($_ =~ /^scsi/) {
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
	}
	return;
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
