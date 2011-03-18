#================
# FILE          : KIWICommandLine.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2011 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rschweikert@novell.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used to store command line arguments
#               : provided to the kiwi driver.
#               :
# STATUS        : Development
#----------------
package KIWICommandLine;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;
use KIWILog;

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
	# Create the CommandLine object
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
	#==========================================
	# Constructor setup
	#------------------------------------------
	if (! defined $kiwi) {
		$kiwi = new KIWILog("tiny");
	}
	#==========================================
	# Object initialize object member data
	#------------------------------------------
	$this->{addPackages}   = ''; # Holds array ref
	$this->{addPatterns}   = ''; # Holds array ref
	$this->{addRepos}      = ''; # Holds array ref
	$this->{buildType}     = '';
	$this->{buildProfiles} = ''; # Holds array ref
	$this->{configDir}     = '';
	$this->{imageTgtDir}   = '';
	$this->{kiwi}          = $kiwi;
	$this->{packageMgr}    = '';
	$this->{rootTgtDir}    = '';

	return $this;
}

#==========================================
# getAdditionalPackages
#------------------------------------------
sub getAdditionalPackages {
}

#==========================================
# getAdditionalPatterns
#------------------------------------------
sub getAdditionalPatterns {
}

#==========================================
# getAdditionalRepos
#------------------------------------------
sub getAdditionalRepos {
}

#==========================================
# getBuildType
#------------------------------------------
sub getBuildType {
	# ...
	# Return the build type specified
	# ---
	my $this = shift;
	return $this -> {buildType};
}

#==========================================
# getBuildProfiles
#------------------------------------------
sub getBuildProfiles {
	# ...
	# Return the list of specified build profiles
	# ---
	my $this = shift;
	return $this -> {buildProfiles};
}

#==========================================
# getConfigDir
#------------------------------------------
sub getConfigDir {
	# ...
	# Return location of the configuration tree
	# ---
	my $this = shift;
	return $this -> {configDir};
}

#==========================================
# getImageTargetDir
#------------------------------------------
sub getImageTargetDir {
	# ...
	# Return the location of the target directory for the image
	# ---
	my $this = shift;
	return $this -> {imageTgtDir};
}

#==========================================
# getPackageManager
#------------------------------------------
sub getPackageManager {
	# ...
	# Return the package manager for this build if set as command line option
	# ---
	my $this = shift;
	return $this -> {packageMgr};
}

#==========================================
# getPrepTargetDir
#------------------------------------------
sub getRootTargetDir {
	# ...
	# Return the location for the unpacked image directory
	# ---
	my $this = shift;
	return $this -> {rootTgtDir};
}

#==========================================
# setAdditionalPackages
#------------------------------------------
sub setAdditionalPackages {
}

#==========================================
# setAdditionalPatterns
#------------------------------------------
sub setAdditionalPatterns {
}

#==========================================
# setAdditionalRepos
#------------------------------------------
sub setAdditionalRepos {
}

#==========================================
# setBuildType
#------------------------------------------
sub setBuildType {
	# ...
	# Set the specified build type (string)
	# ---
	my $this = shift;
	my $type = shift;
	$this -> {buildType} = $type;
	return 1;
}

#==========================================
# setBuildProfiles
#------------------------------------------
sub setBuildProfiles {
	# ...
	# Set the build profile list
	# ---
	my $this    = shift;
	my $profRef = shift;
	$this -> {buildProfiles} = $profRef;
	return 1;
}

#==========================================
# setConfigDir
#------------------------------------------
sub setConfigDir {
	# ...
	# Set the location of the configuration directory
	# ---
	my $this = shift;
	$this -> {configDir} = shift;
	return 1;
}

#==========================================
# setImasetarsetDir
#------------------------------------------
sub setImagetargetDir {
	# ...
	# Set the destination directory for the completed image
	# ---
	my $this = shift;
	$this -> {imageTgtDir} = shift;
	return 1;
}

#==========================================
# setPackageManager
#------------------------------------------
sub setPackageManager {
	# ...
	# Set the package manager for this build as defined on the command line
	# ---
	my $this   = shift;
	my $pkgMgr = shift;
	my @supportedPkgMgrs = qw (ensconce smart yum zypper);
	if (! $pkgMgr) {
		my $msg = 'setPackageManager method called without specifying '
		. 'package manager value.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if (grep /$pkgMgr/, @supportedPkgMgrs) {
		$this -> {packageMgr} = $pkgMgr;
		return 1;
	}
	my $msg = "Unsupported package manager specified: $pkgMgr";
	$this -> {kiwi} -> error ($msg);
	$this -> {kiwi} -> failed();
	return undef;
}

#==========================================
# setRootTargetDir
#------------------------------------------
sub setRootTargetDir {
	# ...
	# Set the target directory for the unpacked root tree
	# ---
	my $this = shift;
	$this -> {rootTgtDir} = shift;
	return 1;
}

#==========================================
# setTargetDirsForBuild
#------------------------------------------
sub setTargetDirsForBuild {
	# ...
	# Setup the target dirs for a combined (prepare & create) image build.
	# ---
	my $this = shift;
	$this->{prepTgtDir} = $this->{imageTgtDir};
	$this->{imageTgtDir} = $this->{prepTgtDir} . '/build';
	return 1;
}

1;
