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
use KIWILocator;
use KIWILog;
use KIWIQX;

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
	$this->{imageTgtDir}        = '';
	$this->{kiwi}               = $kiwi;
	$this->{supportedRepoTypes} = \@supportedRepos;
	return $this;
}

#==========================================
# enableRootRecycle
#------------------------------------------
sub enableRootRecycle {
	# ...
	# Set the recycle root directory if root dir is set, else set a flag
	# for delayed setting.
	# ---
	my $this = shift;
	if ($this -> {rootTgtDir}) {
		$this -> {recycleRootDir} = $this -> {rootTgtDir};
	} else {
		$this -> {setRecycleRoot} = 1;
	}
	return 1;
}

#==========================================
# getAdditionalPackages
#------------------------------------------
sub getAdditionalPackages {
	# ...
	# Return information about additional packages set by the user
	# on the command line.
	# ---
	my $this = shift;
	return $this -> {addPackages};
}

#==========================================
# getAdditionalPatterns
#------------------------------------------
sub getAdditionalPatterns {
	# ...
	# Return information about additional patterns set by the user
	# on the command line.
	# ---
	my $this = shift;
	return $this->{addPatterns};
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
# getCacheDir
#------------------------------------------
sub getCacheDir {
	# ...
	# Return location of the directory containing the caches
	# ---
	my $this = shift;
	return $this -> {cacheDir};
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
# getImageArchitecture
#------------------------------------------
sub getImageArchitecture {
	# ...
	# Return the architecture for this image
	# ---
	my $this = shift;
	return $this -> {imageArch};
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
# getPackagesToRemove
#------------------------------------------
sub getPackagesToRemove {
	# ...
	# Return the list of packages to remove set on the command line as a ref
	# ---
	my $this = shift;
	return $this -> {removePackages};
}

#==========================================
# getRecycleRootDir
#------------------------------------------
sub getRecycleRootDir {
	# ...
	# Return the root target directory to be recycled
	# ---
	my $this = shift;
	return $this -> {recycleRootDir};
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
	# ...
	# Set package names for packages specified on the command line
	# ---
	my $this     = shift;
	my $packages = shift;
	my $kiwi = $this->{kiwi};
	if (! $packages) {
		my $msg = 'setAdditionalPackages method called without specifying '
		. 'packages';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! ref $packages) {
		my $msg = 'setAdditionalPackages method expecting ARRAY_REF as '
			. 'first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	$this -> {addPackages} = $packages;
	return 1;
}

#==========================================
# setAdditionalPatterns
#------------------------------------------
sub setAdditionalPatterns {
	# ...
	# Set pattern names for patterns specified on the command line
	# ---
	my $this     = shift;
	my $patterns = shift;
	my $kiwi = $this->{kiwi};
	if (! $patterns) {
		my $msg = 'setAdditionalPatterns method called without specifying '
		. 'packages';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! ref $patterns) {
		my $msg = 'setAdditionalPatterns method expecting ARRAY_REF as '
			. 'first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	$this->{addPatterns} = $patterns;
	return 1;
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
# setCacheDir
#------------------------------------------
sub setCacheDir {
	# ...
	# Set the location of the directory containing the caches
	# ---
	my $this = shift;
	my $dir  = shift;
	if (! $dir) {
		my $msg = 'setCacheDir method called without specifying a '
			. 'cache directory.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if ((-d $dir) && (! -w $dir)) {
		my $msg = 'No write access to specified cache directory "'
			. "$dir"
			. '".';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if ( $dir !~ /^\//) {
		my $locator = new KIWILocator($this -> {kiwi});
		$dir = $locator -> getDefaultCacheDir() . '/' . $dir;
		my $msg = 'Specified relative path as cache location; moving cache to '
		. "$dir\n";
		$this -> {kiwi} -> info ($msg);
	}
	$this -> {cacheDir} = $dir;
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
# setImageArchitecture
#------------------------------------------
sub setImageArchitecture {
	# ...
	# Set the architecture for this image
	# ---
	my $this = shift;
	my $arch = shift;
	my @supportedArch = qw (i586 ppc ppc64 s390  s390x  x86_64);
	if (! $arch) {
		my $msg = 'setImageArchitecture method called without specifying '
			. 'an architecture.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	if (! grep /^$arch/, @supportedArch) {
		my $msg = 'Improper architecture setting, expecting on of: '
			. "@supportedArch";
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return undef;
	}
	$this -> {imageArch} = $arch;
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
# getPackagesToRemove
#------------------------------------------
sub setPackagesToRemove {
	# ...
	# Set the list of packages to remove
	# ---
	my $this     = shift;
	my $packages = shift;
	my $kiwi = $this->{kiwi};
	if (! $packages) {
		my $msg = 'setPackagesToRemove method called without specifying '
		. 'packages';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if (! ref $packages) {
		my $msg = 'setPackagesToRemove method expecting ARRAY_REF as '
			. 'first argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	$this -> {removePackages} = $packages;
	return 1;
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
	my $this    = shift;
	my $rootTgt = shift;
	my $kiwi = $this -> {kiwi};
	if (! $rootTgt) {
		my $msg = 'setRootTargetDir method called without specifying '
			. 'a target directory';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return undef;
	}
	if ($rootTgt !~ /^\//) {
		my $workingDir = qxx ('pwd');
		chomp $workingDir;
		$rootTgt = $workingDir . '/' . $rootTgt;
		my $msg = 'Specified relative path for target directory; target is '
			. "$rootTgt\n";
		$kiwi -> info ($msg);
	}
	if ($this -> {setRecycleRoot}) {
		$this -> {recycleRootDir} = $rootTgt;
		$this -> {setRecycleRoot} = 0;
	}
	$this -> {rootTgtDir} = $rootTgt;
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
