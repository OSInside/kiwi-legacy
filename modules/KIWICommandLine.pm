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
use File::Spec;
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
	my @supportedRepos = qw(
		apt-deb apt-rpm deb-dir mirrors red-carpet
		rpm-dir rpm-md slack-site up2date-mirrors
		urpmi yast2
	);
	#==========================================
	# Object initialize object member data
	#------------------------------------------
	$this->{addPackages}        = ''; # Holds array ref
	$this->{addPatterns}        = ''; # Holds array ref
	$this->{imageTgtDir}        = '';
	$this->{kiwi}               = $kiwi;
	$this->{rootTgtDir}         = '';
	$this->{supportedRepoTypes} = \@supportedRepos;
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
	# ...
	# Return the information about additional repositories set by the user
	# on the command line.
	# ---
	my $this = shift;
	return $this -> {additionalRepos};
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
# getIgnoreRepos
#------------------------------------------
sub getIgnoreRepos {
	# ...
	# Return the user requested state about ignoring configured repositories
	# ---
	my $this = shift;
	return $this -> {ignoreRepos};
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
# getLogFile
#------------------------------------------
sub getLogFile {
	# ...
	# Return the path of the logfile specified on the command line
	# ---
	my $this = shift;
	return $this -> {logFile};
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
# getReplacementRepo
#------------------------------------------
sub getReplacementRepo {
	# ...
	# Return the repository information for the repo specified by the user
	# to replace the first configured repository
	# ---
	my $this = shift;
	return $this -> {replacementRepo};
}

#==========================================
# getRootTargetDir
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
	# ...
	# Set repository information for added repositories specified on
	# the command line.
	# ---
	my $this      = shift;
	my $repos     = shift;
	my $repoAlias = shift;
	my $repoPrios = shift;
	my $repoTypes = shift;
	my $kiwi = $this->{kiwi};
	if (! $repos) {
		my $msg = 'setAdditionalRepos method called without specifying '
		. 'repositories';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! ref $repos) {
		my $msg = 'setAdditionalRepos method expecting ARRAY_REF as '
			. 'first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (($repoAlias) && (! ref $repoAlias)) {
		my $msg = 'setAdditionalRepos method expecting ARRAY_REF as '
			. 'second argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (($repoPrios) && (! ref $repoPrios)) {
		my $msg = 'setAdditionalRepos method expecting ARRAY_REF as '
			. 'third argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! $repoTypes) {
		my $msg = 'setAdditionalRepos method called without specifying '
		. 'repository types';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! ref $repoTypes) {
		my $msg = 'setAdditionalRepos method expecting ARRAY_REF as '
			. 'fourth argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	my @reposit = @{$repos};
	my $numRepos = @reposit;
	my @repositAlias;
	if ($repoAlias) {
		@repositAlias = @{$repoAlias};
		my $numAlias = @repositAlias;
		if (($numAlias > 0) && ($numRepos != $numAlias)) {
			my $msg = 'Number of specified repositories does not match number '
				. 'of provided alias, cannot form proper match.';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return undef;
		}
	}
	my @repositPrio;
	if ($repoPrios) {
		@repositPrio = @{$repoPrios};
		my $numPrios = @repositPrio;
		if (($numPrios > 0) && ($numRepos != $numPrios)) {
			my $msg = 'Number of specified repositories does not match number '
				. 'of provided priorities, cannot form proper match.';
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return undef;
		}
	}
	my @repositTypes = @{$repoTypes};
	my $numTypes = @repositTypes;
	if ($numRepos != $numTypes) {
		my $msg = 'Number of specified repositories does not match number '
		. 'of provided types, cannot form proper match.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	my @supportedTypes = @{$this->{supportedRepoTypes}};
	for my $type (@repositTypes) {
		if (! grep /$type/, @supportedTypes ) {
			my $msg = "Specified repository type $type not supported.";
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return undef;
		}
	}
	my %repoInfo;
	$repoInfo{repositories}         = $repos;
	$repoInfo{repositoryAlia}       = $repoAlias;
	$repoInfo{repositoryPriorities} = $repoPrios;
	$repoInfo{repositoryTypes}      = $repoTypes;
	$this -> {additionalRepos} = \%repoInfo;

	return 1;
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
	if (! $profRef) {
		my $msg = 'setBuildProfiles method called without specifying '
			. 'profiles in ARRAY_REF';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if (! ref $profRef) {
		my $msg = 'setBuildProfiles method expecting ARRAY_REF as argument';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
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
	my $dir  = shift;
	if (! $dir) {
		my $msg = 'setConfigDir method called without specifying a '
			. 'configuration directory.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if (! -d $dir) {
		my $msg = 'Specified configuration directory "'
			. "$dir"
			. '" could not be found.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if (! -r $dir) {
		my $msg = 'No read access to specified configuration directory "'
			. "$dir"
			. '".';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	$this -> {configDir} = $dir;
	return 1;
}

#==========================================
# setIgnoreRepos
#------------------------------------------
sub setIgnoreRepos {
	# ...
	# Set the state for ignoring configured repositories
	# ---
	my $this = shift;
	my $val = shift;
	if ($val && $this -> {replacementRepo}) {
		my $msg = 'Conflicting command line arguments; ignore repos and '
			. 'set repos';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed ();
		return undef;
	}
	$this -> {ignoreRepos} = $val;
	return 1;
}

#==========================================
# setImagetargetDir
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
# setLogFile
#------------------------------------------
sub setLogFile {
	# ...
	# Set the path of the logfile specified on the command line
	# ---
	my $this    = shift;
	my $logPath = shift;
	if (! $logPath) {
		my $msg = 'setLogFileName method called without specifying '
			. 'a log file path.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if ($logPath eq "terminal") {
		$this -> {logFile} = $logPath;
		return 1;
	}
	my $absPath = File::Spec->rel2abs($logPath);
	my ($volume, $path, $file) = File::Spec->splitpath($logPath);
	if ($path eq '') {
		$path = './';
	}
	if (! -w $path) {
		my $msg = "Unable to write to location $path, cannot create log file.";
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	$this -> {logFile} = $logPath;
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
# setReplacementRepo
#------------------------------------------
sub setReplacementRepo {
	# ...
	# Set the repository information for the repo
	# to replace the first configured repository
	# ---
	my $this      = shift;
	my $repo      = shift;
	my $repoAlias = shift;
	my $repoPrio  = shift;
	my $repoType  = shift;
	my $kiwi = $this -> {kiwi};
	my %replRepo;
	if ($this -> {ignoreRepos}){
		my $msg = 'Conflicting command line arguments; ignore repos and '
			. 'set repos';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed ();
		return undef;
	}
	if (! $repo) {
		my $msg = 'setReplacementRepo method called without specifying '
		. 'a repository.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! $repoAlias) {
		my $msg = "No repo alias defined, generating time based name.\n";
		$kiwi -> loginfo ($msg);
		my $curTime = time;
		$repoAlias = 'genName_' . "$curTime";
	}
	if (! $repoPrio) {
		my $msg = "No repo priority specified, using default value '10'\n";
		$kiwi -> loginfo ($msg);
		$repoPrio = 10;
	}
	if (($repoType) && (! grep /$repoType/, @{$this->{supportedRepoTypes}})) {
		my $msg = "Specified repository type $repoType not supported.";
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	$replRepo{repository}         = $repo;
	$replRepo{repositoryAlias}    = $repoAlias;
	$replRepo{repositoryPriority} = $repoPrio;
	$replRepo{repositoryType}     = $repoType;
	$this -> {replacementRepo} = \%replRepo;
	return 1;
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

#==========================================
# setArchiveImage
#------------------------------------------
sub setArchiveImage {
	my $this  = shift;
	my $value = shift;
	$this->{archiveimage} = $value;
	return 1;
}

#==========================================
# getArchiveImage
#------------------------------------------
sub getArchiveImage {
	my $this = shift;
	return $this->{archiveimage};
}

1;
