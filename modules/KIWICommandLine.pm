#================
# FILE          : KIWICommandLine.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
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
use Digest::MD5 qw (md5_hex);
use File::Spec;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWIModules
#------------------------------------------
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX;

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
  # Create the CommandLine object
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $this  = {};
  my $class = shift;
  bless $this,$class;
  #==========================================
  # Store Object data
  #------------------------------------------
  $this->{imageTgtDir}             = '';
  $this->{imageIntermediateTgtDir} = '';
  $this->{kiwi}                    = KIWILog -> instance();
  #==========================================
  # Store Object data
  #------------------------------------------
  my $global = KIWIGlobals -> instance();
  $this->{gdata} = $global -> getKiwiConfig();
  return $this;
}

#==========================================
# setRootRecycle
#------------------------------------------
sub setRootRecycle {
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
  # Return an array ref containing XMLRepositoryData objects representing
  # the additional repositories set by the user on the command line.
  # ---
  my $this = shift;
  return $this -> {additionalRepos};
}

#==========================================
# getForceNewRoot
#------------------------------------------
sub getForceNewRoot {
  # ...
  # Return the bool value for the force-new-root option
  # ---
  my $this = shift;
  return $this -> {forceNewRoot};
}

#==========================================
# getForceBootstrap
#------------------------------------------
sub getForceBootstrap {
  # ...
  # Return the bool value for the force-bootstrap option
  # ---
  my $this = shift;
  return $this -> {forceBootstrap};
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
# getImageIntermediateTargetDir
#------------------------------------------
sub getImageIntermediateTargetDir {
  # ...
  # Return the location of the intermediate target directory for the image
  # ---
  my $this = shift;
  return $this -> {imageIntermediateTgtDir};
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
# unsetRecycleRootDir
#------------------------------------------
sub unsetRecycleRootDir {
  # ...
  # Turn off use of root target directory to be recycled
  # ---
  my $this = shift;
  undef $this -> {recycleRootDir};
  return;
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
# getInitrdRootTargetDir
#------------------------------------------
sub getInitrdRootTargetDir {
  # ...
  # Return the location for the unpacked initrd image directory
  # ---
  my $this = shift;
  return $this -> {rootInitrdTgtDir};
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
    return;
  }
  if (! ref $packages) {
    my $msg = 'setAdditionalPackages method expecting ARRAY_REF as '
      . 'first argument.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
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
    return;
  }
  if (! ref $patterns) {
    my $msg = 'setAdditionalPatterns method expecting ARRAY_REF as '
      . 'first argument.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
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
  my $kiwi = $this->{kiwi};
  if (! $repos) {
    my $msg = 'setAdditionalRepos method called without specifying '
      . 'repositories';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
  }
  if (ref($repos) ne 'ARRAY') {
    my $msg = 'setAdditionalRepos method expecting ARRAY_REF as '
      . 'argument.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
  }
  for my $repo (@{$repos}) {
    if (ref($repo) ne 'KIWIXMLRepositoryData') {
      my $msg = 'setAdditionalRepos method expecting ARRAY_REF of '
        . 'KIWIXMLRepositoryData objects.';
      $kiwi -> error ($msg);
      $kiwi -> failed();
      return;
    }
  }
  $this -> {additionalRepos} = $repos;
  return 1;
}

#==========================================
# setForceNewRoot
#------------------------------------------
sub setForceNewRoot {
  my $this = shift;
  my $fnr  = shift;
  if (! $this -> {setRecycleRoot}) {
    $this -> {forceNewRoot} = $fnr;
  }
  return 1;
}

#==========================================
# setForceBootstrap
#------------------------------------------
sub setForceBootstrap {
  my $this = shift;
  my $fbs  = shift;
  $this -> {forceBootstrap} = $fbs;
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
    return;
  }
  if (! ref $profRef) {
    my $msg = 'setBuildProfiles method expecting ARRAY_REF as argument';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
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
    return;
  }
  if ((-d $dir) && (! -w $dir)) {
    my $msg = 'No write access to specified cache directory "'
      . "$dir"
      . '".';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
  }
  if ( $dir !~ /^\//) {
    my $locator = KIWILocator -> instance();
    $dir = $locator -> getDefaultCacheDir() . '/' . $dir;
    my $msg = 'Specified relative path as cache location; moving cache to '
    . "$dir\n";
    $this -> {kiwi} -> info ($msg);
  }
  $this -> {cacheDir} = $dir;
  return 1;
}

#==========================================
# unsetCacheDir
#------------------------------------------
sub unsetCacheDir {
  my $this = shift;
  undef $this -> {cacheDir};
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
  my $boot = shift;
  if (! $dir) {
    my $msg = 'setConfigDir method called without specifying a '
      . 'configuration directory.';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
  }
  if (! -d $dir) {
    my $msg = 'Specified configuration directory "'
      . "$dir"
      . '" could not be found.';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
  }
  if (! -r $dir) {
    my $msg = 'No read access to specified configuration directory "'
      . "$dir"
      . '".';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
  }
  if ($boot) {
    $this -> {configInitrdDir} = $dir;
  } else {
    $this -> {configDir} = $dir;
  }
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
    return;
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
  my @supportedArch = qw (i586 x86_64);
  if (! $arch) {
    my $msg = 'setImageArchitecture method called without specifying '
      . 'an architecture.';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
  }
  if (! grep { /^$arch/x } @supportedArch) {
    my $msg = 'Improper architecture setting, expecting on of: '
      . "@supportedArch";
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed();
    return;
  }
  $this -> {imageArch} = $arch;
  return 1;
}

#==========================================
# setImageTargetDir
#------------------------------------------
sub setImageTargetDir {
  # ...
  # Set the destination directory for the completed image
  # ---
  my $this = shift;
  $this -> {imageTgtDir} = shift;
  return 1;
}

#==========================================
# setImageIntermediateTargetDir
#------------------------------------------
sub setImageIntermediateTargetDir {
  # ...
  # Based on the origin imageTgtDir this is a subdirectory
  # below the destination directory. The build data lives
  # there until the build finishes successfully
  # ---
  my $this = shift;
  $this -> {imageIntermediateTgtDir} = shift;
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
    return;
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
    return;
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
    return;
  }
  if (grep { /$pkgMgr/x } @supportedPkgMgrs) {
    $this -> {packageMgr} = $pkgMgr;
    return 1;
  }
  my $msg = "Unsupported package manager specified: $pkgMgr";
  $this -> {kiwi} -> error ($msg);
  $this -> {kiwi} -> failed();
  return;
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
    return;
  }
  if (! ref $packages) {
    my $msg = 'setPackagesToRemove method expecting ARRAY_REF as '
      . 'first argument.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
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
  my $kiwi = $this -> {kiwi};
  if ($this -> {ignoreRepos}){
    my $msg = 'Conflicting command line arguments; ignore repos and '
      . 'set repos';
    $this -> {kiwi} -> error ($msg);
    $this -> {kiwi} -> failed ();
    return;
  }
  if (! $repo) {
    my $msg = 'setReplacementRepo method called without specifying '
      . 'a repository.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
  }
  if (ref($repo) ne 'KIWIXMLRepositoryData') {
    my $msg = 'setReplacementRepo: expecting KIWIXMLRepositoryData '
      . 'object as argument.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
  }
  $this -> {replacementRepo} = $repo;
  return 1;
}

#==========================================
# setInitrdRootTargetDir
#------------------------------------------
sub setInitrdRootTargetDir {
  my $this = shift;
  my $dir  = shift;
  return $this -> setRootTargetDir ($dir,"initrd");
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
  my $boot    = shift;
  my $kiwi    = $this -> {kiwi};
  if (! $rootTgt) {
    my $msg = 'setRootTargetDir method called without specifying '
      . 'a target directory';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
  }
  if ($rootTgt !~ /^\//) {
    my $workingDir = KIWIQX::qxx ('pwd');
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
  if ($boot) {
    $this -> {rootInitrdTgtDir} = $rootTgt;
  } else {
    $this -> {rootTgtDir} = $rootTgt;
  }
  return 1;
}

#==========================================
# setInitrdFile
#------------------------------------------
sub setInitrdFile {
  # ...
  # Store the name of the initrd file
  # ---
  my $this = shift;
  my $file = shift;
  $this->{initrdFile} = $file;
  return 1;
}

#==========================================
# setBuildNumber
#------------------------------------------
sub setBuildNumber {
  # ...
  # Store the build number used to bundle this build
  # ---
  my $this  = shift;
  my $build = shift;
  $this->{buildNumber} = $build;
  return 1;
}

#==========================================
# getSplashFile
#------------------------------------------
sub getInitrdFile {
  my $this = shift;
  return $this->{initrdFile};
}

#==========================================
# getBuildNumber
#------------------------------------------
sub getBuildNumber {
  my $this = shift;
  return $this->{buildNumber};
}

#==========================================
# setSystemLocation
#------------------------------------------
sub setSystemLocation {
  # ...
  # Store the system image location which could either
  # be the system tree or an image file representing
  # the system tree
  # ---
  my $this   = shift;
  my $system = shift;
  $this->{systemLocation} = $system;
  return 1;
}

#==========================================
# getSystemLocation
#------------------------------------------
sub getSystemLocation {
  my $this = shift;
  return $this->{systemLocation};
}

#==========================================
# setImageDiskSize
#------------------------------------------
sub setImageDiskSize {
  # ...
  # Store the value for the bootvm-disksize option
  # ---
  my $this = shift;
  my $size = shift;
  $this->{diskSize} = $size;
  return 1;
}

#==========================================
# getImageDiskSize
#------------------------------------------
sub getImageDiskSize {
  my $this = shift;
  return $this->{diskSize};
}

#==========================================
# setImageTargetDevice
#------------------------------------------
sub setImageTargetDevice {
  # ...
  # Store the value for the targetdevice option
  # ---
  my $this   = shift;
  my $device = shift;
  $this->{targetDevice} = $device;
  return 1;
}

#==========================================
# getImageTargetDevice
#------------------------------------------
sub getImageTargetDevice {
  my $this = shift;
  return $this->{targetDevice};
}

#==========================================
# setImageFormat
#------------------------------------------
sub setImageFormat {
  # ...
  # Store the value of the format option
  # ---
  my $this   = shift;
  my $format = shift;
  $this->{format} = $format;
  return 1;
}

#==========================================
# getImageFormat
#------------------------------------------
sub getImageFormat {
  my $this = shift;
  return $this->{format};
}

#==========================================
# setDefaultAnswer
#------------------------------------------
sub setDefaultAnswer {
  # ...
  # Store the value of the format option
  # ---
  my $this   = shift;
  my $answer = shift;
  $this->{defaultAnswer} = $answer;
  return 1;
}

#==========================================
# getDefaultAnswer
#------------------------------------------
sub getDefaultAnswer {
  my $this = shift;
  return $this->{defaultAnswer};
}

#==========================================
# setFilesystemOptions
#------------------------------------------
sub setFilesystemOptions {
  # ...
  # Store the filesystem options object
  # ---
  my $this   = shift;
  my $fsOpts = shift;
  if (! $fsOpts || ref($fsOpts) ne 'KIWIFilesystemOptions') {
    my $kiwi = $this->{kiwi};
    my $msg = 'setFilesystemOptions: expecting KIWIFilesystemOptions '
      . 'object as argument.';
    $kiwi -> error ($msg);
    $kiwi -> failed();
    return;
  }
  $this->{fsoptions} = $fsOpts;
  return 1;
}

#==========================================
# getFilesystemOptions
#------------------------------------------
sub getFilesystemOptions {
  my $this = shift;
  return $this->{fsoptions};
}

#==========================================
# setMBRID
#------------------------------------------
sub setMBRID {
  my $this  = shift;
  my $mbrid = shift;
  $this->{mbrid} = $mbrid;
  return 1;
}

#==========================================
# getMBRID
#------------------------------------------
sub getMBRID {
  my $this = shift;
  return $this->{mbrid};
}

#==========================================
# setOperationMode
#------------------------------------------
sub setOperationMode {
  my $this = shift;
  my $mode = shift;
  my $value= shift;
  $this->{operation}{$mode} = $value;
  return 1;
}

#==========================================
# getOperationMode
#------------------------------------------
sub getOperationMode {
  my $this = shift;
  my $mode = shift;
  return $this->{operation}{$mode}
}

#==========================================
# setPartitioner
#------------------------------------------
sub setPartitioner {
  my $this = shift;
  my $tool = shift;
  $this->{partitioner} = $tool;
  return 1;
}

#==========================================
# getPartitioner
#------------------------------------------
sub getPartitioner {
  my $this = shift;
  return $this->{partitioner};
}

#==========================================
# setNoColor
#------------------------------------------
sub setNoColor {
  my $this = shift;
  my $value= shift;
  $this->{nocolor} = $value;
  return 1;
}

#==========================================
# getNoColor
#------------------------------------------
sub getNoColor {
  my $this = shift;
  return $this->{nocolor};
}

#==========================================
# setAnalyserOptions
#------------------------------------------
sub setAnalyserOptions {
  my $this    = shift;
  my $hashref = shift;
  if ($hashref) {
    $this->{analyserOptions} = $hashref;
  }
  return 1;
}

#==========================================
# getAnalyserOptions
#------------------------------------------
sub getAnalyserOptions {
  my $this = shift;
  return $this->{analyserOptions};
}

#==========================================
# setDebug
#------------------------------------------
sub setDebug {
  my $this = shift;
  my $value= shift;
  $this->{debug} = $value;
  return 1;
}

#==========================================
# getDebug
#------------------------------------------
sub getDebug {
  my $this = shift;
  return $this->{debug};
}

#==========================================
# setTestCase
#------------------------------------------
sub setTestCase {
  my $this = shift;
  my $value= shift;
  $this->{testcase} = $value;
  return 1;
}

#==========================================
# getTestCase
#------------------------------------------
sub getTestCase {
  my $this = shift;
  return $this->{testcase};
}

#==========================================
# setXMLInfoSelection
#------------------------------------------
sub setXMLInfoSelection {
  my $this = shift;
  my $list = shift;
  $this->{XMLInfoSelection} = $list;
  return 1;
}

#==========================================
# getXMLInfoSelection
#------------------------------------------
sub getXMLInfoSelection {
  my $this = shift;
  return $this->{XMLInfoSelection};
}

#==========================================
# setStripImage
#------------------------------------------
sub setStripImage {
  my $this  = shift;
  my $value = shift;
  $this->{stripImage} = $value;
  return 1;
}

#==========================================
# getStripImage
#------------------------------------------
sub getStripImage {
  my $this = shift;
  return $this->{stripImage};
}

#==========================================
# setPrebuiltBootImagePath
#------------------------------------------
sub setPrebuiltBootImagePath {
  my $this  = shift;
  my $value = shift;
  $this->{prebuiltBootPath} = $value;
  return 1;
}

#==========================================
# getPrebuiltBootImagePath
#------------------------------------------
sub getPrebuiltBootImagePath {
  my $this = shift;
  return $this->{prebuiltBootPath};
}

#==========================================
# setISOCheck
#------------------------------------------
sub setISOCheck {
  my $this  = shift;
  my $value = shift;
  $this->{isocheck} = $value;
  return 1;
}

#==========================================
# getISOCheck
#------------------------------------------
sub getISOCheck {
  my $this = shift;
  return $this->{isocheck};
}

#==========================================
# setCheckKernel
#------------------------------------------
sub setCheckKernel {
  my $this  = shift;
  my $value = shift;
  $this->{kernelcheck} = $value;
  return 1;
}

#==========================================
# getCheckKernel
#------------------------------------------
sub getCheckKernel {
  my $this = shift;
  return $this->{kernelcheck};
}


#==========================================
# setLVM
#------------------------------------------
sub setLVM {
  my $this  = shift;
  my $value = shift;
  $this->{lvm} = $value;
  return 1;
}

#==========================================
# getLVM
#------------------------------------------
sub getLVM {
  my $this = shift;
  return $this->{lvm};
}

#==========================================
# setGrubChainload
#------------------------------------------
sub setGrubChainload {
  my $this  = shift;
  my $value = shift;
  $this->{chainload} = $value;
  return 1;
}

#==========================================
# getGrubChainload
#------------------------------------------
sub getGrubChainload {
  my $this = shift;
  return $this->{chainload};
}

#==========================================
# setFatStorage
#------------------------------------------
sub setFatStorage {
  my $this  = shift;
  my $value = shift;
  $this->{fatsize} = $value;
  return 1;
}

#==========================================
# getFatStorage
#------------------------------------------
sub getFatStorage {
  my $this = shift;
  return $this->{fatsize};
}

#==========================================
# setDiskStartSector
#------------------------------------------
sub setDiskStartSector {
  my $this  = shift;
  my $value = shift;
  if (! defined $value) {
    $value = $this->{gdata}->{DiskStartSector};
  }
  $this->{startsector} = $value;
  return 1;
}

#==========================================
# getDiskStartSector
#------------------------------------------
sub getDiskStartSector {
  my $this = shift;
  return $this->{startsector};
}

#==========================================
# setDiskBIOSSectorSize
#------------------------------------------
sub setDiskBIOSSectorSize {
  my $this  = shift;
  my $value = shift;
  if (! defined $value) {
    $value = $this->{gdata}->{DiskSectorSize};
  }
  $this->{BIOSSectorSize} = $value;
  return 1;
}

#==========================================
# getDiskBIOSSectorSize
#------------------------------------------
sub getDiskBIOSSectorSize {
  my $this = shift;
  return $this->{BIOSSectorSize};
}

#==========================================
# setDiskAlignment
#------------------------------------------
sub setDiskAlignment {
  my $this  = shift;
  my $value = shift;
  if (! defined $value) {
    $value = $this->{gdata}->{DiskAlignment};
  }
  $this->{PTableAlignment} = $value;
  return 1;
}

#==========================================
# getDiskAlignment
#------------------------------------------
sub getDiskAlignment {
  my $this = shift;
  return $this->{PTableAlignment};
}

#==========================================
# setEditBootConfig
#------------------------------------------
sub setEditBootConfig {
  my $this  = shift;
  my $value = shift;
  $this->{editbootconfig} = File::Spec->rel2abs($value);
  return 1;
}

#==========================================
# getEditBootConfig
#------------------------------------------
sub getEditBootConfig {
  my $this = shift;
  return $this->{editbootconfig};
}

#==========================================
# setEditBootInstall
#------------------------------------------
sub setEditBootInstall {
  my $this  = shift;
  my $value = shift;
  $this->{editbootinstall} = File::Spec->rel2abs($value);
  return 1;
}

#==========================================
# getEditBootInstall
#------------------------------------------
sub getEditBootInstall {
  my $this = shift;
  return $this->{editbootinstall};
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
