#================
# FILE          : KIWIXML.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module is used for reading the control
#               : XML file, used for preparing an image
#               :
# STATUS        : Development
#----------------
package KIWIXML;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
require Exporter;
use Carp qw (cluck);
use Data::Dumper;
use File::Glob ':glob';
use File::Basename;
use LWP;
use XML::LibXML;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIURL;
use KIWIXMLDescriptionData;
use KIWIXMLDriverData;
use KIWIXMLEC2ConfigData;
use KIWIXMLOEMConfigData;
use KIWIXMLPackageData;
use KIWIXMLPackageArchiveData;
use KIWIXMLPackageCollectData;
use KIWIXMLPackageIgnoreData;
use KIWIXMLPackageProductData;
use KIWIXMLPreferenceData;
use KIWIXMLProfileData;
use KIWIXMLPXEDeployData;
use KIWIXMLRepositoryData;
use KIWIXMLSplitData;
use KIWIXMLSystemdiskData;
use KIWIXMLTypeData;
use KIWIXMLUserData;
use KIWIXMLValidator;
use KIWIXMLVMachineData;
use KIWISatSolver;

#==========================================
# Exports
#------------------------------------------
our @ISA    = qw (Exporter);
our @EXPORT_OK = qw (
	getInstSourceFile getInstSourceSatSolvable getSingleInstSourceSatSolvable
);

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# KIWI XML processor and data store
	#
	# The XML object processes the configuration file and
	# stores that data in the imageConfig hash. The hash is
	# layed out as a data structure that resembles the XML
	# file and allows easy access to the data for the use
	# by other objects.
	#
	# Other objects never get access to the internal structure
	# and can only manipulate data via set methods or retrieve
	# data via get methods. Wherever access to complex
	# information is required the XML object will provide a
	# specific object for this data. The provided object in
	# turn has get and set methods to access the data.
	#
	# imageConfig data structure
	#
	# imageConfig = {
	#	description = {
	#		author = '',
	#		contact = '',
	#		specification = '',
	#		type = ''
	#	}
	#   pckgInstallOpt = '',
	#	profName[+] = {
	#       archives        = (),
	#       bootArchives    = (),
	#		bootDelPkgs     = (),
	#		bootPkgs        = (),
	#		bootPkgsCollect = (),
	#       bootStrapPckgs  = (),
	#		delPkgs         = (),
	#		drivers         = (),
	#       ignorePkgs      = (),
	#       installOpt      = '',
	#		pkgs            = (),
	#       pkgsCollect     = (),
	#       products        = (),
	#		arch[+] = {
	#           archives        = (),
	#           bootArchives    = (),
	#			bootDelPkgs     = (),
	#			bootPkgs        = (),
	#	   	    bootPkgsCollect = (),
	#           bootStrapPckgs  = (),
	#			delPkgs         = (),
	#			drivers         = (),
	#           ignorePkgs      = (),
	#			pkgs            = (),
	#           pkgsCollect     = (),
	#           products        = (),
	#		}
	#       preferences = {
	#           bootloader_theme = '',
	#           bootsplash_theme = '',
	#           ........
	#           types = {
	#               type[+] = {
	#                   boot            = '',
	#                   bootkernel      = '',
	#                   .......
	#                   vga             = '',
	#                   volid           = ''
	#               }
	#           }
	#           version = ''
	#       }
	#		profInfo = {
	#			description = '',
	#			import      = ''
	#		}
	#		repoData = {
	#			ID[+] {
	#				alias    = '',
	#				path     = '',
	#				priority = '',
	#				status   = '',
	#				...
	#			}
	#		}
	#	    type[+] = {
	#           archives = (),
	#           arch[+]  = {
	#                       archives        = (),
	#                       bootArchives    = (),
	#			            bootDelPkgs     = (),
	#			            bootPkgs        = (),
	#	   	                bootPkgsCollect = (),
	#			            drivers         = (),
	#                       ignorePkgs      = (),
	#			            pkgs            = (),
	#                       pkgsCollect     = (),
	#                       products        = (),
	#		            }
	#           bootArchives    = (),
	#		    bootDelPkgs     = (),
	#           bootPkgs        = (),
	#		    bootPkgsCollect = (),
	#           drivers         = (),
	#           ignorePkgs      = (),
	#           pkgs            = (),
	#           pkgsCollect     = (),
	#           products        = (),
	#       }
	#   }
	#   users {
	#       NAME[+] {
	#           group
	#           groupid
	#           home
	#           passwd
	#           passwdformat
	#           realname
	#           shell
	#           userid
	#       }
	#    }
	# }
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
	my $kiwi        = shift;
	my $imageDesc   = shift;
	my $imageType   = shift;
	my $reqProfiles = shift;
	my $cmdL        = shift;
	my $changeset   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $arch = qxx ("uname -m"); chomp $arch;
	if ($arch =~ /i.86/) {
		$arch = "ix86";
	}
	my %supported = map { ($_ => 1) } qw(
		armv5tel armv7l ia64 ix86 ppc ppc64 s390 s390x x86_64
	);
	$this->{supportedArch} = \%supported;
	if (! $supported{$arch} ) {
		my $msg = "Attempt to run KIWI on unsupported architecture '$arch'";
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Check pre condition
	#------------------------------------------
	if (! -d $imageDesc) {
		$kiwi -> error ("Couldn't locate configuration directory $imageDesc");
		$kiwi -> failed ();
		return;
	}
	if (! $main::global) {
		$kiwi -> error  ('Globals object not found');
		$kiwi -> failed ();
		return;
	}
	if (! $cmdL) {
		$kiwi -> error  ('No commandline reference specified');
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	$this->{arch} = $arch;
	$this->{gdata}= $main::global -> getGlobals();
	$this->{cmdL} = $cmdL;
	$this->{buildType} = $imageType;
	my @selectProfs;
	if ($reqProfiles) {
		@selectProfs = @{$reqProfiles};
		push @selectProfs, 'kiwi_default';
	} else {
		@selectProfs = ('kiwi_default');
	}
	$this->{selectedProfiles} = \@selectProfs;
	#==========================================
	# Lookup XML configuration file
	#------------------------------------------
	my $locator = KIWILocator -> new ($kiwi);
	my $controlFile = $locator -> getControlFile ( $imageDesc );
	if (! $controlFile) {
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{xmlOrigFile} = $controlFile;
	#==========================================
	# Read and Validate XML information
	#------------------------------------------
	my $validator = KIWIXMLValidator -> new (
		$kiwi,$controlFile,
		$this->{gdata}->{Revision},
		$this->{gdata}->{Schema},
		$this->{gdata}->{SchemaCVT}
	);
	my $systemTree = $validator -> getDOM();
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{xmlOrigString} = $systemTree -> toString();
	$this->{systemTree}    = $systemTree;
	#==========================================
	# Read main XML sections
	#------------------------------------------
	my $imgnameNodeList = $systemTree -> getElementsByTagName ("image");
	my $optionsNodeList = $systemTree -> getElementsByTagName ("preferences");
	my $driversNodeList = $systemTree -> getElementsByTagName ("drivers");
	my $stripNodeList   = $systemTree -> getElementsByTagName ("strip");
	my $usrdataNodeList = $systemTree -> getElementsByTagName ("users");
	my $repositNodeList = $systemTree -> getElementsByTagName ("repository");
	my $packageNodeList = $systemTree -> getElementsByTagName ("packages");
	my $profilesNodeList= $systemTree -> getElementsByTagName ("profiles");
	my $instsrcNodeList = $systemTree -> getElementsByTagName ("instsource");
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{optionsNodeList} = $optionsNodeList;
	$this->{imgnameNodeList} = $imgnameNodeList;
	$this->{imageType}       = $imageType;
	$this->{reqProfiles}     = $reqProfiles;
	$this->{profilesNodeList}= $profilesNodeList;
	$this->{repositNodeList} = $repositNodeList;
	$this->{packageNodeList} = $packageNodeList;
	$this->{instsrcNodeList} = $instsrcNodeList;
	$this->{driversNodeList} = $driversNodeList;
	$this->{stripNodeList}   = $stripNodeList;
	#==========================================
	# Data structure containing the XML file information
	#------------------------------------------
	$this->{imageConfig} = {};
	my %kDefProfile = (
		'description' => 'KIWI default profile, store non qualified data',
		'import'      => 'true'
	);
	$this->{imageConfig}{kiwi_default}{profInfo} = \%kDefProfile;
	#==========================================
	# Populate imageConfig with description data from config tree
	#------------------------------------------
	$this -> __populateDescriptionInfo();
	#==========================================
	# Populate imageConfig with profile data from config tree
	#------------------------------------------
	$this -> __populateProfileInfo();
	#==========================================
	# Populate imageConfig with diver data from config tree
	#------------------------------------------
	$this -> __populateDriverInfo();
	#==========================================
	# Populate imageConfig with preferences data from config tree
	#------------------------------------------
	if (! $this -> __populatePreferenceInfo() ) {
		return;
	}
	#==========================================
	# Set the default build type
	#------------------------------------------
	if (! $this -> __setDefaultBuildType() ) {
		return;
	}
	$this->{selectedType} = $this->{defaultType};
	#==========================================
	# Populate imageConfig with archive data from config tree
	#------------------------------------------
	$this -> __populateArchiveInfo();
	#==========================================
	# Populate imageConfig with ignore data from config tree
	#------------------------------------------
	$this -> __populateIgnorePackageInfo();
	#==========================================
	# Populate imageConfig with package data from config tree
	#------------------------------------------
	$this -> __populatePackageInfo();
	#==========================================
	# Populate imageConfig with package collection
	# (opensusePattern, rhelGroup) data
	#------------------------------------------
	$this -> __populatePackageCollectionInfo();
	#==========================================
	# Populate imageConfig with product data from config tree
	#------------------------------------------
	$this -> __populateProductInfo();
	#==========================================
	# Populate imageConfig with repository data from config tree
	#------------------------------------------
	$this -> __populateRepositoryInfo();
	#==========================================
	# Populate imageConfig with user data from config tree
	#------------------------------------------
	$this -> __populateUserInfo();
	#==========================================
	# Read and create profile hash
	#------------------------------------------
	$this->{profileHash} = $this -> __populateProfiles_legacy();
	#==========================================
	# Read and create type hash
	#------------------------------------------
	$this->{typeList} = $this -> __populateTypeInfo_legacy();
	#==========================================
	# Update XML data from changeset if exists
	#------------------------------------------
	if (defined $changeset) {
		$this -> __populateImageTypeAndNode_legacy();
		$this -> __updateDescriptionFromChangeSet_legacy ($changeset);
	}
	#==========================================
	# Populate default profiles from XML if set
	#------------------------------------------
	$this -> __populateDefaultProfiles_legacy();
	#==========================================
	# Populate typeInfo hash
	#------------------------------------------
	$this -> __populateProfiledTypeInfo_legacy();
	#==========================================
	# Check profile names
	#------------------------------------------
	if (! $this -> __checkProfiles_legacy()) {
		return;
	}
	#==========================================
	# Select and initialize image type
	#------------------------------------------
	if (! $this -> __populateImageTypeAndNode_legacy()) {
		return;
	}
	#==========================================
	# Add default split section if not defined
	#------------------------------------------
	if (! $this -> __addDefaultSplitNode()) {
		return;
	}
	#==========================================
	# Add default strip section if not defined
	#------------------------------------------
	if (! $this -> __addDefaultStripNode()) {
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	$this->{usrdataNodeList}    = $usrdataNodeList;
	$this->{controlFile}        = $controlFile;
	#==========================================
	# Store object data
	#------------------------------------------
	$this -> updateXML();
	#==========================================
	# Dump imageConfig to log
	#------------------------------------------
	# print $this->__dumpInternalXMLDescription();
	return $this;
}

#==========================================
# Methods that use the "new" imageConfig data structure
# These are replcements for "old" methods and represent the
# eventual interface of this object
#------------------------------------------
#==========================================
# addArchives
#------------------------------------------
sub addArchives {
	# ...
	# Add the given archives to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	#   - the given image type of the profiles being processed
	# ---
	my $this      = shift;
	my $archives  = shift;
	my $profNames = shift;
	my $imageType = shift;
	my %verifyData = (
		caller       => 'addArchives',
		expectedType => 'KIWIXMLPackageArchiveData',
		itemName     => 'archives',
		itemsToAdd   => $archives,
		profNames    => $profNames,
		type         => $imageType
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my @profsToUse = $this -> __getProfsToModify($profNames, 'archive(s)');
	if (! $imageType) {
		$imageType = 'image';
	}
	my $accessID;
	for my $prof (@profsToUse) {
		for my $archiveObj (@{$archives}) {
			my $arch     = $archiveObj -> getArch();
			my $bootIncl = $archiveObj -> getBootInclude();
			if ($bootIncl && ($bootIncl eq 'true')) {
				$accessID = 'bootArchives';
			} else {
				$accessID = 'archives';
			}
			my %storeData = (
				accessID => $accessID,
				arch     => $arch,
				dataObj  => $archiveObj,
				profName => $prof,
				type     => $imageType
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
			}
		}
	}
	return $this;
}

#==========================================
# addBootstrapPackages
#------------------------------------------
sub addBootstrapPackages {
	# ...
	# Add the given packages to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this       = shift;
	my $packages   = shift;
	my $profNames  = shift;
	my $imageType  = shift;
	my %verifyData = (
		caller       => 'addBootstrapPackages',
		expectedType => 'KIWIXMLPackageData',
		itemName     => 'packages',
		itemsToAdd   => $packages,
		profNames    => $profNames
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my @profsToUse = $this -> __getProfsToModify($profNames, 'package(s)');
	$imageType = 'bootstrap';
	for my $prof (@profsToUse) {
		for my $pckgObj (@{$packages}) {
			my $arch = $pckgObj -> getArch();
			my %storeData = (
				accessID => 'bootStrapPckgs',
				arch     => $arch,
				dataObj  => $pckgObj,
				profName => $prof,
				type     => $imageType
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
			}
		}
	}
	return $this;
}

#==========================================
# addDrivers
#------------------------------------------
sub addDrivers {
	# ...
	# Add the given drivers to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this      = shift;
	my $drivers   = shift;
	my $profNames = shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# Verify arguments
	#------------------------------------------
	if (! $drivers) {
		$kiwi -> info ('addDrivers: no drivers specified, nothing to do');
		$kiwi -> skipped ();
		return $this;
	}
	if ( ref($drivers) ne 'ARRAY' ) {
		my $msg = 'addDrivers: expecting array ref for XMLDriverData array '
			. 'as first argument';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Verify array antries
	#------------------------------------------
	my @drvsToAdd = @{$drivers};
	for my $drv (@drvsToAdd) {
		if ( ref($drv) ne 'KIWIXMLDriverData' ) {
			my $msg = 'addDrivers: found array item not of type '
				. 'KIWIXMLDriverData in driver array';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# Figure out what profiles to change
	#------------------------------------------
	my @profsToUse = $this -> __getProfsToModify($profNames, 'driver(s)');
	if (! @profsToUse) {
		return;
	}
	for my $prof (@profsToUse) {
		for my $drvData (@drvsToAdd) {
			my $arch = $drvData -> getArch();
			my $name = $drvData -> getName();
			if ($arch) {
				if ($this->{imageConfig}->{$prof}->{$arch} &&
					$this->{imageConfig}->{$prof}->{$arch}{drivers}) {
					my @existDrv = 
						@{$this->{imageConfig}->{$prof}->{$arch}{drivers}};
					push @existDrv, $name;
					$this->{imageConfig}->{$prof}->{$arch}{drivers} =
						\@existDrv;
				} else {
					my @newDrv = ($name);
					$this->{imageConfig}->{$prof}->{$arch}{drivers} = \@newDrv;
				}
			} else {
				if ($this->{imageConfig}->{$prof}{drivers}) {
					my @existDrv = @{$this->{imageConfig}->{$prof}{drivers}};
					push @existDrv, $name;
					$this->{imageConfig}->{$prof}{drivers} =  \@existDrv;
				} else {
					my @newDrv = ($name);
					$this->{imageConfig}->{$prof}{drivers} = \@newDrv;
				}
			}
		}
	}
	return $this;
}

#==========================================
# addPackages
#------------------------------------------
sub addPackages {
	# ...
	# Add the given packages to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	#   - the given image type of the profiles being processed
	# ---
	my $this       = shift;
	my $packages   = shift;
	my $profNames  = shift;
	my $imageType  = shift;
	my %verifyData = (
		caller       => 'addPackages',
		expectedType => 'KIWIXMLPackageData',
		itemName     => 'packages',
		itemsToAdd   => $packages,
		profNames    => $profNames,
		type         => $imageType
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my @profsToUse = $this -> __getProfsToModify($profNames, 'package(s)');
	if (! $imageType) {
		$imageType = 'image';
	}
	for my $prof (@profsToUse) {
		for my $pckgObj (@{$packages}) {
			my @access;
			my $arch     = $pckgObj -> getArch();
			my $bootDel  = $pckgObj -> getBootDelete();
			my $bootIncl = $pckgObj -> getBootInclude();
			if ($bootDel && $bootDel eq 'true') {
				push @access, 'bootDelPkgs';
				if (! $bootIncl || $bootIncl eq 'false') {
					push @access, 'pkgs';
				}
			}
			if ($bootIncl && $bootIncl eq 'true') {
				push @access, 'bootPkgs';
			}
			if (! @access) {
				push @access, 'pkgs';
			}
			for my $accessID (@access) {
				my %storeData = (
					accessID => $accessID,
					arch     => $arch,
					dataObj  => $pckgObj,
					profName => $prof,
					type     => $imageType
				);
				if (! $this -> __storeInstallData(\%storeData)) {
					return;
				}
			}
		}
	}
	return $this;
}

#==========================================
# addPackageCollections
#------------------------------------------
sub addPackageCollections {
	# ...
	# Add the given package collections to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	#   - the given image type of the profiles being processed
	# ---
	my $this        = shift;
	my $collections = shift;
	my $profNames   = shift;
	my $imageType   = shift;
	my %verifyData = (
		caller       => 'addPackageCollections',
		expectedType => 'KIWIXMLPackageCollectData',
		itemName     => 'collections',
		itemsToAdd   => $collections,
		profNames    => $profNames,
		type         => $imageType
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my @profsToUse = $this -> __getProfsToModify($profNames, 'collection(s)');
	if (! $imageType) {
		$imageType = 'image';
	}
	my $accessID;
	for my $prof (@profsToUse) {
		for my $collectObj (@{$collections}) {
			my $arch     = $collectObj -> getArch();
			my $bootIncl = $collectObj -> getBootInclude();
			if ($bootIncl && ($bootIncl eq 'true')) {
				$accessID = 'bootPkgsCollect';
			} else {
				$accessID = 'pkgsCollect';
			}
			my %storeData = (
				accessID => $accessID,
				arch     => $arch,
				dataObj  => $collectObj,
				profName => $prof,
				type     => $imageType
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
			}
		}
	}
	return $this;
}

#==========================================
# addPackagesToDelete
#------------------------------------------
sub addPackagesToDelete {
	# ...
	# Add the given packages to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this       = shift;
	my $packages   = shift;
	my $profNames  = shift;
	my $imageType  = shift;
	my %verifyData = (
		caller       => 'addPackagesToDelete',
		expectedType => 'KIWIXMLPackageData',
		itemName     => 'packages',
		itemsToAdd   => $packages,
		profNames    => $profNames
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my @profsToUse = $this -> __getProfsToModify($profNames, 'package(s)');
	$imageType = 'bootstrap';
	for my $prof (@profsToUse) {
		for my $pckgObj (@{$packages}) {
			my $arch = $pckgObj -> getArch();
			my %storeData = (
				accessID => 'delPkgs',
				arch     => $arch,
				dataObj  => $pckgObj,
				profName => $prof,
				type     => $imageType
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
			}
		}
	}
	return $this;
}

#==========================================
# addRepositories
#------------------------------------------
sub addRepositories {
	# ...
	# Add the given repositories to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this      = shift;
	my $repos     = shift;
	my $profNames = shift;
	my $kiwi = $this->{kiwi};
	#==========================================
	# Verify arguments
	#------------------------------------------
	if (! $repos) {
		$kiwi -> info ('addRepositories: no repos specified, nothing to do');
		$kiwi -> skipped ();
		return $this;
	}
	if ( ref($repos) ne 'ARRAY' ) {
		my $msg = 'addRepositories: expecting array ref for '
			. 'XMLRepositoryData array as first argument';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Remeber repos to add + verify the type
	#------------------------------------------
	my @reposToAdd = @{$repos};
	for my $repo (@reposToAdd) {
		if (ref($repo) ne 'KIWIXMLRepositoryData' ) {
			my $msg = 'addRepositories: found array item not of type '
				. 'KIWIXMLRepositoryData in repository array';
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	my @profsToUse = $this -> __getProfsToModify($profNames, 'repositorie(s)');
	if (! @profsToUse) {
		return;
	}
	my $idCntr = $this -> {repoCounter};
	for my $prof (@profsToUse) {
		REPO:
		for my $repo (@reposToAdd) {
			my %repoData = %{$this->__convertRepoDataToHash($repo)};
			my $alias                 = $repo -> getAlias();
			my $path                  = $repo -> getPath();
			my $preferlicense         = $repo -> getPreferLicense();
			my ($username, $password) = $repo -> getCredentials();
			my $repoRef = $this->{imageConfig}->{$prof}{repoData};
			if ($repoRef) {
				my %repoInfo = %{$repoRef};
				# Verify uniqueness conditions
				for my $entry (values %repoInfo) {
					if ($entry->{alias}
						&& $alias
						&& $entry->{alias} eq $alias) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with same alias already '
							. 'exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($entry->{password}
						&& $password
						&& $entry->{password} ne $password) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with a different password '
							.  'already exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($entry->{path} eq $path) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with same path already '
							. 'exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($entry->{preferlicense} && $preferlicense) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with license preference '
							. 'indicator set already exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($entry->{username}
						&& $username
						&& $entry->{username} ne $username) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with a different username '
							. 'already exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
				}
				$repoInfo{$idCntr} = \%repoData;
				$this->{imageConfig}->{$prof}{repoData} = \%repoInfo;
			} else {
				my %repoInfo = ( $idCntr => \%repoData);
				$this->{imageConfig}->{$prof}{repoData} = \%repoInfo;
			}
			$idCntr += 1;
		}
	}
	# Store the next counter to be used as repo ID
	$this -> {repoCounter} = $idCntr;
	return $this;
}

#==========================================
# getActiveProfileNames
#------------------------------------------
sub getActiveProfileNames {
	# ...
	# Return an array ref containing the names of the active profiles;
	# this does not reveal the default (kiwi_default) name, as this is
	# always active
	# ---
	my $this = shift;
	my @selected = @{$this->{selectedProfiles}};
	my @active = ();
	for my $prof (@selected) {
		if ($prof eq 'kiwi_default') {
			next;
		}
		push @active, $prof;
	}
	return \@active;
}

#==========================================
# getArchives
#------------------------------------------
sub getArchives {
	# ...
	# Return an array ref containing ArchiveData objects
	# ---
	my $this = shift;
	my $archives = $this -> __getInstallData('archives');
	my $bInclArchives = $this -> getBootIncludeArchives();
	push @{$archives}, @{$bInclArchives};
	return $archives;
}

#==========================================
# getBootDeletePackages
#------------------------------------------
sub getBootDeletePackages {
	# ...
	# Return an array ref containing PackageData objects for the packages
	# that should be deleted.
	# ---
	my $this = shift;
	return $this -> __getInstallData('bootDelPkgs');
}

#==========================================
# getBootIncludeArchives
#------------------------------------------
sub getBootIncludeArchives {
	# ...
	# Return an array ref containing ArchiveData objects
	# ---
	my $this = shift;
	return $this -> __getInstallData('bootArchives');
}

#==========================================
# getBootIncludePackages
#------------------------------------------
sub getBootIncludePackages {
	# ...
	# Return an array ref containing PackageData objects
	# ---
	my $this = shift;
	my $bPckgs = $this -> __getInstallData('bootPkgs');
	my %pckgFilter;
	# Any packages that are marked to be replaced need to be removed
	for my $pckg (@{$bPckgs}) {
		my $toReplace = $pckg -> getPackageToReplace();
		if ($toReplace) {
			$pckgFilter{$toReplace} = 1;
		}
	}
	# Do not filter out the boot delete packages, packages marked with
	# bootinclude='true' must be installed even if bootdlete='true' is set
	# as well
	my @delPackages;
	# Create the list of packages
	for my $pckg (@{$bPckgs}) {
		my $name = $pckg -> getName();
		if ($pckgFilter{$name}) {
			next;
		}
		push @delPackages, $pckg;
	}
	return \@delPackages;
}

#==========================================
# getBootIncludePackageCollections
#------------------------------------------
sub getBootIncludePackageCollections {
	# ...
	# Return an array ref containing PackageCollectData objects
	# ---
	my $this = shift;
	return $this -> __getInstallData('bootPkgsCollect');
}

#==========================================
# getBootstrapPackages
#------------------------------------------
sub getBootstrapPackages {
	# ...
	# Return an array ref containing PackageData objects for the packages
	# that should be used to bootstrap the image.
	# ---
	my $this = shift;
	return $this -> __getInstallData('bootStrapPckgs');
}

#==========================================
# getConfiguredTypeNames
#------------------------------------------
sub getConfiguredTypeNames {
	# ...
	# Return an array ref of image type names avaliable across the
	# selected profiles.
	# ---
	my $this = shift;
	my @typeNames;
	for my $profName ( @{$this->{selectedProfiles}} ) {
		if ( $this->{imageConfig}{$profName}{preferences}{types} ) {
			my @names = keys %{ $this->{imageConfig}
									->{$profName}
									->{preferences}
									->{types}
								};
			for my $name (@names) {
				if ($name eq 'defaultType') {
					next;
				}
				push @typeNames, $name;
			}
		}
	}
	return \@typeNames;
}

#==========================================
# getDescriptionInfo
#------------------------------------------
sub getDescriptionInfo {
	# ...
	# Return an object that encapsulates the description information
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $descriptObj = KIWIXMLDescriptionData -> new (
		$kiwi,$this->{imageConfig}->{description}
	);
	return $descriptObj;
}

#==========================================
# getDrivers
#------------------------------------------
sub getDrivers {
	# ...
	# Return an array reference of KIWIXMLDriverData objects that are
	# specified to be part of the current profile(s) and architecture
	# ---
	my $this = shift;
	my $arch = $this->{arch};
	my $kiwi = $this->{kiwi};
	my @activeProfs = @{$this->{selectedProfiles}};
	my @drvs = ();
	for my $prof (@activeProfs) {
		if ($this->{imageConfig}->{$prof}{drivers}) {
			push @drvs, @{$this->{imageConfig}->{$prof}{drivers}};
		}
		if ($this->{imageConfig}{$prof}{$arch}{drivers}) {
			push @drvs, @{$this->{imageConfig}->{$prof}->{$arch}{drivers}};
		}
	}
	my @driverInfo = ();
	for my $drv (@drvs) {
		my %init = ( name => $drv );
		push @driverInfo, KIWIXMLDriverData -> new($kiwi, \%init);
	}
	return \@driverInfo;
}

#==========================================
# getEC2Config
#------------------------------------------
sub getEC2Config {
	# ...
	# Return an EC2ConfigData object for the EC2 configuration of the current
	# build type.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $ec2ConfObj = KIWIXMLEC2ConfigData -> new(
		$kiwi,$this->{selectedType}{ec2config}
	);
	return $ec2ConfObj;
}

#==========================================
# getImageType
#------------------------------------------
sub getImageType {
	# ...
	# Return a TypeData object for the selected build type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $typeObj = KIWIXMLTypeData -> new(
		$kiwi, $this->{selectedType}
	);
	return $typeObj;
}

#==========================================
# getInstallOption
#------------------------------------------
sub getInstallOption {
	# ...
	# Return the install option type setting. Returns undef if there is
	# a conflict and thus the settings ar ambiguous.
	# ---
	my $this     = shift;
	my $profName = shift;
	my @selected = @{$this->{selectedProfiles}};
	my $instOpt;
	for my $prof (@selected) {
		my $opt = $this->{imageConfig}{$prof}{installOpt};
		if ($opt && (! $instOpt)) {
			$instOpt = $opt;
			next;
		}
		if ($opt && $instOpt) {
			if ($opt ne $instOpt) {
				return;
			}
		}
	}
	if (! $instOpt) {
		return 'onlyRequired';
	}
	return $instOpt;
}

#==========================================
# getOEMConfig
#------------------------------------------
sub getOEMConfig {
	# ...
	# Return a OEMConfigData object for the selected build type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $oemConfObj = KIWIXMLOEMConfigData -> new(
		$kiwi,$this->{selectedType}{oemconfig}
	);
	return $oemConfObj;
}

#==========================================
# getPackages
#------------------------------------------
sub getPackages {
	# ...
	# Return an array ref containing PackageData objects
	# ---
	my $this = shift;
	my $pckgs = $this -> __getInstallData('pkgs');
	my $bPckgs = $this -> getBootIncludePackages();
	push @{$pckgs}, @{$bPckgs};
	my %pckgFilter;
	# Any packages that are marked to be replaced need to be removed
	for my $pckg (@{$pckgs}) {
		my $toReplace = $pckg -> getPackageToReplace();
		if ($toReplace) {
			$pckgFilter{$toReplace} = 1;
		}
	}
	# Any packages that are marked to be ignored need to be removed
	my $ignorePckgs = $this -> __getPackagesToIgnore();
	for my $ignoreP (@{$ignorePckgs}) {
		my $name = $ignoreP -> getName();
		$pckgFilter{$name} = 1;
	}
	# Filter any packages that are marked for deletion, this might save us
	# some work later
	my $delPckgs = $this -> __getInstallData('delPkgs');
	for my $delP (@{$delPckgs}) {
		my $name = $delP -> getName();
		$pckgFilter{$name} = 1;
	}
	my @installPackages;
	# Create the list of packages
	for my $pckg (@{$pckgs}) {
		my $name = $pckg -> getName();
		if ($pckgFilter{$name}) {
			next;
		}
		push @installPackages, $pckg;
	}
	return \@installPackages;
}

#==========================================
# getPackageCollections
#------------------------------------------
sub getPackageCollections {
	# ...
	# Return an array ref containing PackageCollectData objects
	# ---
	my $this = shift;
	my $collections = $this -> __getInstallData('pkgsCollect');
	my $bCollections = $this -> getBootIncludePackageCollections();
	push @{$collections}, @{$bCollections};
	return $collections;
}

#==========================================
# getPackagesToDelete
#------------------------------------------
sub getPackagesToDelete {
	# ...
	# Return an array ref containing PackageData objects for the packages
	# that should be deleted.
	# ---
	my $this = shift;
	return $this -> __getInstallData('delPkgs');
}

#==========================================
# getPreferences
#------------------------------------------
sub getPreferences {
	# ...
	# Return a PreferenceData object for the current selected build
	# profile(s)
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $mergedPref = $this->{imageConfig}{kiwi_default}{preferences};
	my @activeProfs = @{$this->{selectedProfiles}};
	for my $prof (@activeProfs) {
		if ($prof eq 'kiwi_default') {
			next;
		}
		$mergedPref = $this -> __mergePreferenceData(
			$mergedPref,$this->{imageConfig}{$prof}{preferences}
		);
		if (! $mergedPref ) {
			return;
		}
	}
	my $prefObj = KIWIXMLPreferenceData -> new(
		$kiwi, $mergedPref
	);
	return $prefObj;
}

#==========================================
# getProducts
#------------------------------------------
sub getProducts {
	# ...
	# Return an array ref containing ProductData objects
	# ---
	my $this = shift;
	return $this -> __getInstallData('products');
}

#==========================================
# getProfiles
#------------------------------------------
sub getProfiles {
	# ...
	# Return an array ref of ProfileData objects available for this image
	# ---
	my $this   = shift;
	my $kiwi = $this->{kiwi};
	my %imgConf = %{ $this->{imageConfig} };
	my @result;
	for my $prof (@{$this->{availableProfiles}}) {
		my %profile = ();
		$profile{name}        = $prof;
		$profile{description} = $imgConf{$prof}->{profInfo}->{description};
		$profile{import}      = $imgConf{$prof}->{profInfo}->{import};
		push @result, KIWIXMLProfileData -> new($kiwi, \%profile );
	}
	return \@result;
}

#==========================================
# getPXEConfig
#------------------------------------------
sub getPXEConfig {
	# ...
	# Return a PXEDeployData object for the PXE boot configuration of the
	# current build type.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $pxeDataObj = KIWIXMLPXEDeployData -> new(
		$kiwi,$this->{selectedType}{pxedeploy}
	);
	return $pxeDataObj;
}

#==========================================
# getRepositories
#------------------------------------------
sub getRepositories {
	# ...
	# Return an array reference of KIWIXMLRepositories objects that are
	# specified to be part of the current profile(s)
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @activeProfs = @{$this->{selectedProfiles}};
	my @repoData = ();
	for my $prof (@activeProfs) {
		if ($this->{imageConfig}->{$prof}{repoData}) {
			for my $key (keys %{$this->{imageConfig}->{$prof}{repoData}}) {
				push @repoData,
					KIWIXMLRepositoryData -> new (
						$kiwi,
						$this->{imageConfig}->{$prof}{repoData}->{$key}
					);
			}
		}
	}
	return \@repoData;
}

#==========================================
# getSplitConfig
#------------------------------------------
sub getSplitConfig {
	# ...
	# Return a SplitData object for the <split> configuration of
	# the current build type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $spltObj = KIWIXMLSplitData -> new(
		$kiwi, $this->{selectedType}{split}
	);
	return $spltObj;
}

#==========================================
# getSystemDiskConfig
#------------------------------------------
sub getSystemDiskConfig {
	# ...
	# Return a SystemdiskData object for the <systemdisk> configuration of
	# the current build type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $sysDiskObj = KIWIXMLSystemdiskData -> new(
		$kiwi,$this->{selectedType}{systemdisk}
	);
	return $sysDiskObj;
}

#==========================================
# getType
#------------------------------------------
sub getType {
	# ...
	# Return a TypeDataObject for the given type if found in the
	# active profiles.
	# ---
	my $this  = shift;
	my $tname = shift;
	my $kiwi = $this->{kiwi};
	if (! $tname) {
		my $msg = 'getType: no type name specified';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	for my $prof (@{$this->{selectedProfiles}}) {
		my $types = $this->{imageConfig}{$prof}{preferences}{types};
		if ($types) {
			if ($types->{$tname}) {
				my $tObj = KIWIXMLTypeData -> new ($kiwi, $types->{$tname});
				return $tObj;
			}
		}
	}
	my $msg = "getType: given type '$tname' not defined or available.";
	$kiwi -> error($msg);
	$kiwi -> failed();
	return;
}

#==========================================
# getUsers
#------------------------------------------
sub getUsers {
	# ...
	# Return a reference to an array holding UserData objects
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @userData;
	for my $uInfo (values %{$this->{imageConfig}{users}}) {
		my $uObj = KIWIXMLUserData -> new($kiwi, $uInfo);
		push @userData, $uObj;
	}
	return \@userData;
}

#==========================================
# getVMachineConfig
#------------------------------------------
sub getVMachineConfig {
	# ...
	# Return a VMachineData object for the virtual machine configuration of
	# the current build type
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $vmConfObj = KIWIXMLVMachineData -> new(
		$kiwi,$this->{selectedType}{machine}
	);
	return $vmConfObj;
}

#==========================================
# ignoreRepositories
#------------------------------------------
sub ignoreRepositories {
	# ...
	# Ignore all the repositories in the XML file.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	$kiwi -> info ('Ignoring all repositories previously configured');
	my @allProfs = @{$this->{availableProfiles}};
	push @allProfs, 'kiwi_default';
	for my $profName (@allProfs) {
		delete $this->{imageConfig}->{$profName}{repoData}
	}
	$kiwi -> done();
	return $this;
}

#==========================================
# setBuildType
#------------------------------------------
sub setBuildType {
	# ...
	# Set the type to be used as the build type
	# ---
	my $this     = shift;
	my $typeName = shift;
	my $kiwi = $this->{kiwi};
	if (! $typeName ) {
		my $msg = 'setBuildType: no type name given, retaining current '
			. 'build type setting.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %availTypes = map { ($_ => 1) } @{ $this->getConfiguredTypeNames() };
	if (! $availTypes{$typeName} ) {
		my $msg = 'setBuildType: no type configuration exists for the '
			. "given type '$typeName' in the current active profiles.";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	for my $profName ( @{$this->{selectedProfiles}} ) {
		if ( $this->{imageConfig}{$profName}{preferences}{types} ) {
			my $typeDef = $this->{imageConfig}
				->{$profName}
				->{preferences}
				->{types}
				->{$typeName};
			if ( $typeDef ) {
				$this->{selectedType} = $typeDef;
				last;
			}
		}
	}
	return $this;
}

#==========================================
# setDescriptionInfo
#------------------------------------------
sub setDescriptionInfo {
	# ...
	# Set the description information for this configuration
	# ---
	my $this = shift;
	my $xmlDescripDataObj = shift;
	my $kiwi = $this->{kiwi};
	if (! $xmlDescripDataObj ||
		ref($xmlDescripDataObj) ne 'KIWIXMLDescriptionData') {
		my $msg = 'setDescriptionInfo: Expecting KIWIXMLDescriptionData '
			. 'instance as argument.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my $author = $xmlDescripDataObj->getAuthor();
	if (! $author) {
		my $msg = 'setDescriptionInfo: Provided KIWIXMLDescriptionData '
			. 'instance is not valid.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my %descript = (
		author        => $author,
		contact       => $xmlDescripDataObj->getContactInfo(),
		specification => $xmlDescripDataObj->getSpecificationDescript(),
		type          => $xmlDescripDataObj->getType()
	);
	$this->{imageConfig}{description} = \%descript;
	return $this;
}

#==========================================
# setPreferences
#------------------------------------------
sub setPreferences {
	# ...
	# Set the preferences for the currently selected profiles. We divide
	# each setting to the profile where it is already defined. If a setting
	# is not defined we set the value on the default profile.
	#
	# If I build profiles A, B, and C and am given preferences to set this
	# method will set, for example the bootloader_theme in the profile where
	# the bootloader_theme is defined, A, B, or C or in the default profile
	# if not defined in any of the other profiles.
	# ---
	my $this    = shift;
	my $prefObj = shift;
	my $kiwi = $this->{kiwi};
	if (! $prefObj || ref($prefObj) ne 'KIWIXMLPreferenceData') {
		my $msg = 'setPreferences: expecting ref to KIWIXMLPreferenceData '
			. ' as first argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %attrSettings = (
		bootloader_theme     => $prefObj -> getBootLoaderTheme(),
		bootsplash_theme     => $prefObj -> getBootSplashTheme(),
		defaultdestination   => $prefObj -> getDefaultDest(),
		defaultprebuilt      => $prefObj -> getDefaultPreBuilt(),
		defaultroot          => $prefObj -> getDefaultRoot(),
		hwclock              => $prefObj -> getHWClock(),
		keymap               => $prefObj -> getKeymap(),
		locale               => $prefObj -> getLocale(),
		packagemanager       => $prefObj -> getPackageManager(),
		rpm_check_signatures => $prefObj -> getRPMCheckSig(),
		rpm_excludedocs      => $prefObj -> getRPMExcludeDoc(),
		rpm_force            => $prefObj -> getRPMForce(),
		showlicense          => $prefObj -> getShowLic(),
		timezone             => $prefObj -> getTimezone(),
		version              => $prefObj -> getVersion()
	);
	my @sProfs = @{$this->{selectedProfiles}};
	ATTR:
	for my $attr (keys %attrSettings) {
		my $appliedSet = undef;
		my $newSet = $attrSettings{$attr};
		for my $prof (@{$this->{selectedProfiles}}) {
			my $curSet = $this->{imageConfig}{$prof}{preferences}{$attr};
			if ($newSet && $curSet) {
				$this->{imageConfig}{$prof}{preferences}{$attr} = $newSet;
				my $appliedSet = 1;
				next ATTR;
			}
		}
		if ((! $appliedSet) && $newSet) {
			$this->{imageConfig}{kiwi_default}{preferences}{$attr} = $newSet;
		}
	}
	return 1;
}

#==========================================
# setRepository
#------------------------------------------
sub setRepository {
	# ...
	# Overwrite the first repository marked as replacable for the currently
	# active profiles, the search starts with the default profile
	# ---
	my $this = shift;
	my $repo = shift;
	my $kiwi = $this->{kiwi};
	if (! $repo || ref($repo) ne 'KIWIXMLRepositoryData') {
		my $msg = 'setRepository: expecting ref to KIWIXMLRepositoryData '
			. ' as first argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @profsToUse = @{$this->{selectedProfiles}};
	my %repoIDreverseMap;
	for my $prof (@profsToUse) {
		my $confRepos = $this->{imageConfig}{$prof}{repoData};
		if ($confRepos) {
			for my $id (keys %{$confRepos}) {
				$repoIDreverseMap{$id} = $prof;
			}
		}
	}
	my @orderedIDs = sort (keys %repoIDreverseMap);
	my $foundReplacable;
	for my $repoID (@orderedIDs) {
		my $profName = $repoIDreverseMap{$repoID};
		my $stat = $this->{imageConfig}{$profName}{repoData}{$repoID}{status};
		# Note treating the "replacable" status implicitely as default
		if (! $stat || ($stat eq 'replacable')) {
			my %repoData = %{$this->__convertRepoDataToHash($repo)};
			my $replRepoPath = $this->{imageConfig}
				->{$profName}
				->{repoData}
				->{$repoID}
				->{path};
			$kiwi -> info ("Replacing repository $replRepoPath");
			$kiwi -> done();
			$this->{imageConfig}{$profName}{repoData}{$repoID} = \%repoData;
			$foundReplacable = 1;
			last;
		}
	}
	if (!$foundReplacable) {
		my $path = $repo-> getPath();
		my $msg = 'No replacable repository configured, not using repo with '
			. "path: '$path'";
		$kiwi -> info($msg);
		$kiwi -> skipped();
	}
	return $this;
}

#==========================================
# setSelectionProfileNames
#------------------------------------------
sub setSelectionProfileNames {
	# ...
	# Set the information about which profiles to use for data access,
	# if no argument is given set to the default profile(s)
	# ---
	my $this     = shift;
	my $profiles = shift;
	my $kiwi = $this->{kiwi};
	if (! $profiles) {
		delete $this->{availableProfiles};
		my @def = ('kiwi_default');
		$this->{selectedProfiles} = \@def;
		$this->__populateProfileInfo();
		return $this;
	}
	if ( ref($profiles) ne 'ARRAY' ) {
		my $msg = 'setActiveProfiles, expecting array ref argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $msg = 'Attempting to set active profile to "PROF_NAME", but '
		. 'this profile is not specified in the configuration.';
	if (! $this -> __verifyProfNames($profiles, $msg)) {
		return;
	}
	my @newProfs = @{$profiles};
	my $info = join ', ', @newProfs;
	$kiwi -> info ("Using profile(s): $info");
	$kiwi -> done ();
	if (! $this->__hasDefaultProfName($profiles) ) {
		push @newProfs, 'kiwi_default';
	}
	$this->{selectedProfiles} = \@newProfs;
	return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __convertRepoDataToHash
#------------------------------------------
sub __convertRepoDataToHash {
	# ...
	# Convert a KIWIXMLRepositoryData object to a hash that fits the internal
	# data description of this object
	# ---
	my $this = shift;
	my $repo = shift;
	my %repoData;
	my $alias                 = $repo -> getAlias();
	my $imageinclude          = $repo -> getImageInclude();
	my $path                  = $repo -> getPath();
	my $preferlicense         = $repo -> getPreferLicense();
	my $priority              = $repo -> getPriority();
	my $status                = $repo -> getStatus();
	my $type                  = $repo -> getType();
	my ($username, $password) = $repo -> getCredentials();
	if ($alias) {
		$repoData{alias} = $alias;
	}
	if ($imageinclude) {
		$repoData{imageinclude} = $imageinclude;
	}
	if ($password) {
		$repoData{password} = $password;
	}
	if ($path) {
		$repoData{path} = $path;
	}
	if ($preferlicense) {
		$repoData{preferlicense} = $preferlicense;
	}
	if ($priority) {
		$repoData{priority} = $priority;
	}
	if ($status) {
		$repoData{status} = $status;
	}
	if ($type) {
		$repoData{type} = $type;
	}
	if ($username) {
		$repoData{username} = $username;
	}
	return \%repoData;
}

#==========================================
# __convertSizeStrToMBVal
#------------------------------------------
sub __convertSizeStrToMBVal {
	# ...
	# Convert a given size string that contains M or G into a value
	# that is a representation in MB.
	#
	my $this    = shift;
	my $sizeStr = shift;
	if (! $sizeStr ) {
		return;
	}
	my $size = $sizeStr;
	if ($sizeStr =~ /(\d+)([MG]*)/) {
		my $byte = int $1;
		my $unit = $2;
		if ($unit eq "G") {
			$size =  $byte * 1024;
		} else {
			$size =  $byte;
		}
	}
	return $size;
}

#==========================================
# __dumpInternalXMLDescription
#------------------------------------------
sub __dumpInternalXMLDescription {
	# ...
	# return the contents of the imageConfig data
	# structure in a readable format
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	$Data::Dumper::Terse  = 1;
	$Data::Dumper::Indent = 1;
	$Data::Dumper::Useqq  = 1;
	my $dd = Data::Dumper->new([ %{$this->{imageConfig}} ]);
	my $cd = $dd->Dump();
	return $cd;
}

#==========================================
# __genEC2ConfigHash
#------------------------------------------
sub __genEC2ConfigHash {
	# ...
	# Return a ref to a hash that contains the EC2 configuration data for the
	# given XML:ELEMENT object. Build a data structure that matches the
	# structure defined in KIWIXMLEC2ConfigData
	# ---
	my $this = shift;
	my $node = shift;
	my $ec2Config = $node -> getChildrenByTagName('ec2config') -> get_node(1);
	if (! $ec2Config ) {
		return;
	}
	my %ec2ConfigData;
	$ec2ConfigData{ec2accountnr} = $this -> __getChildNodeTextValue(
		$ec2Config, 'ec2accountnr'
	);
	$ec2ConfigData{ec2certfile}  = $this -> __getChildNodeTextValue(
		$ec2Config, 'ec2certfile'
	);
	$ec2ConfigData{ec2privatekeyfile} =	$this -> __getChildNodeTextValue(
		$ec2Config, 'ec2privatekeyfile'
	);
	my @ec2Regions = $ec2Config -> getChildrenByTagName('ec2region');
	my @regions;
	for my $regNode (@ec2Regions) {
		push @regions, $regNode -> textContent();
	}
	my $selectedRegions;
	if (@regions) {
		$selectedRegions = \@regions;
	}
	$ec2ConfigData{ec2region} = $selectedRegions;
	return \%ec2ConfigData;
}

#==========================================
# __genOEMConfigHash
#------------------------------------------
sub __genOEMConfigHash {
	# ...
	# Return a ref to a hash containing the configuration for <oemconfig>
	# of the given XML:ELEMENT object. Build a data structure that
	# matches the structure defined in
	# KIWIXMLOEMConfigData
	# ---
	my $this = shift;
	my $node = shift;
	my $oemConfNode = $node -> getChildrenByTagName('oemconfig');
	if (! $oemConfNode ) {
		return;
	}
	my $config = $oemConfNode -> get_node(1);
	my %oemConfig;
	$oemConfig{oem_align_partition}      =
		$this -> __getChildNodeTextValue($config, 'oem-align-partition');
	$oemConfig{oem_boot_title}           =
		$this -> __getChildNodeTextValue($config, 'oem-boot-title');
	$oemConfig{oem_bootwait}             =
		$this -> __getChildNodeTextValue($config, 'oem-bootwait');
	$oemConfig{oem_inplace_recovery}     =
		$this -> __getChildNodeTextValue($config, 'oem-inplace-recovery');
	$oemConfig{oem_kiwi_initrd}          =
		$this -> __getChildNodeTextValue($config, 'oem-kiwi-initrd');
	$oemConfig{oem_partition_install}    =
		$this -> __getChildNodeTextValue($config, 'oem-partition-install');
	$oemConfig{oem_reboot}               =
		$this -> __getChildNodeTextValue($config, 'oem-reboot');
	$oemConfig{oem_reboot_interactive}   =
		$this -> __getChildNodeTextValue($config, 'oem-reboot-interactive');
	$oemConfig{oem_recovery}             =
		$this -> __getChildNodeTextValue($config, 'oem-recovery');
	$oemConfig{oem_recoveryID}           =
		$this -> __getChildNodeTextValue($config, 'oem-recoveryID');
	$oemConfig{oem_shutdown}             =
		$this -> __getChildNodeTextValue($config, 'oem-shutdown');
	$oemConfig{oem_shutdown_interactive} =
		$this -> __getChildNodeTextValue($config, 'oem-shutdown-interactive');
	$oemConfig{oem_silent_boot}          =
		$this -> __getChildNodeTextValue($config, 'oem-silent-boot');
	$oemConfig{oem_swap}                 =
		$this -> __getChildNodeTextValue($config, 'oem-swap');
	$oemConfig{oem_swapsize}             =
		$this -> __getChildNodeTextValue($config, 'oem-swapsize');
	$oemConfig{oem_systemsize}           =
		$this -> __getChildNodeTextValue($config, 'oem-systemsize');
	$oemConfig{oem_unattended}           = 
	$this -> __getChildNodeTextValue($config, 'oem-unattended');
	$oemConfig{oem_unattended_id}        =
		$this -> __getChildNodeTextValue($config, 'oem-unattended-id');
	return \%oemConfig;
}

#==========================================
# __genPXEDeployHash
#------------------------------------------
sub __genPXEDeployHash {
	# ...
	# Return a ref to a hash containing the configuration for <pxedeploy>
	# of the given XML:ELEMENT object. Build a data structure that matches
	# the structure defined in KIWIXMLPXEDeployData
	# ---
	my $this = shift;
	my $node = shift;
	my %pxeConfig;
	my $pxeDeployNode = $node -> getChildrenByTagName('pxedeploy');
	if (! $pxeDeployNode ) {
		return;
	}
	my $pxeNode = $pxeDeployNode -> get_node(1);
	$pxeConfig{blocksize} = $pxeNode -> getAttribute('blocksize');
	#==========================================
	# Process <configuration>
	#------------------------------------------
	my $configNode = $pxeNode -> getChildrenByTagName('configuration');
	if ( $configNode ) {
		my $configSet = $configNode -> get_node(1);
		my $archDef = $configSet -> getAttribute('arch');
		if ($archDef) {
			my @arches = split /,/, $archDef;
			for my $arch (@arches) {
				if (! $this->{supportedArch}{$arch} ) {
					my $kiwi = $this->{kiwi};
					my $msg = "Unsupported arch '$arch' in PXE setup.";
					$kiwi -> error ($msg);
					$kiwi -> failed ();
					return -1;
				}
			}
			$pxeConfig{configArch}   = \@arches;
		}
		$pxeConfig{configDest}   = $configSet -> getAttribute('dest');
		$pxeConfig{configSource} = $configSet -> getAttribute('source');
	}
	$pxeConfig{initrd} = $this -> __getChildNodeTextValue($pxeNode, 'initrd');
	$pxeConfig{kernel} = $this -> __getChildNodeTextValue($pxeNode, 'kernel');
	#==========================================
	# Process <partitions>
	#------------------------------------------
	my $partNode = $pxeNode -> getChildrenByTagName('partitions');
	if ( $partNode ) {
		my $partData = $partNode -> get_node(1);
		$pxeConfig{device} = $partData -> getAttribute('device');
		my %partData;
		my @parts = $partData -> getChildrenByTagName('partition');
		for my $part (@parts) {
			my %partSet;
			$partSet{mountpoint} = $part -> getAttribute('mountpoint');
			my $id               = int $part -> getAttribute('number');
			$partSet{size}       = $part -> getAttribute('size');
			$partSet{target}     = $part -> getAttribute('target');
			$partSet{type}       = $part -> getAttribute('type');
			$partData{$id} = \%partSet;
		}
		$pxeConfig{partitions}   = \%partData
	}
	$pxeConfig{server}  = $pxeNode -> getAttribute('server');
	$pxeConfig{timeout} =$this -> __getChildNodeTextValue($pxeNode, 'timeout');
	#==========================================
	# Process <union>
	#------------------------------------------
	my $unionNode = $pxeNode -> getChildrenByTagName('union');
	if ( $unionNode ) {
		my $unionData = $unionNode -> get_node(1);
		$pxeConfig{unionRO}   = $unionData -> getAttribute('ro');
		$pxeConfig{unionRW}   = $unionData -> getAttribute('rw');
		$pxeConfig{unionType} = $unionData -> getAttribute('type');
	}
	return \%pxeConfig;
}

#==========================================
# __genSplitDataHash
#------------------------------------------
sub __genSplitDataHash {
	# ...
	# Return a ref to a hash containing the configuration for <split>
	# of the given XML:ELEMENT object. Build a data structure that
	# matches the structure defined in KIWIXMLSplitData
	# ---
	my $this = shift;
	my $node = shift;
	my $splitNode = $node -> getChildrenByTagName('split');
	if (! $splitNode ) {
		return;
	}
	my $splitData = $splitNode -> get_node(1);
	my %splitConf;
	my @children = qw /persistent temporary/;
	my @splitBehave = qw /file except/;
	for my $child (@children) {
		my $chldNodeLst = $splitData -> getChildrenByTagName($child);
		if (! $chldNodeLst ) {
			next;
		}
		my $chldNode = $chldNodeLst -> get_node(1);
		# Build the behavior layer of the structure i.e. file or exclusion
		# behaveData = {
		#                except = {...}
		#                files  = {...}
		#              }
		my %behaveData;
		for my $split (@splitBehave) {
			my @splitSet = $chldNode -> getChildrenByTagName($split);
			if (! @splitSet ) {
				next;
			}
			my $key;
			if ($split eq 'file') {
				$key = 'files';
			} else {
				$key = $split;
			}
			# Build inner most part of structure
			# dataCollect = {
			#                 all     = (),
			#                 arch[+] = ()
			#               }
			my %dataCollect;
			for my $entry (@splitSet) {
				my $arch = $entry -> getAttribute('arch');
				if (! $arch ) {
					$arch = 'all';
				} else {
					if (! $this->{supportedArch}{$arch} ) {
						my $kiwi = $this->{kiwi};
						my $msg = "Unsupported arch '$arch' in split setup";
						$kiwi -> error ($msg);
						$kiwi -> failed ();
						return -1;
					}
				}
				my $name = $entry -> getAttribute('name');
				if ( $dataCollect{$arch} ) {
					push @{$dataCollect{$arch}}, $name;
				} else {
					my @dataLst = ( $name );
					$dataCollect{$arch} = \@dataLst;
				}
			}
			$behaveData{$key} = \%dataCollect;
		}
		$splitConf{$child} = \%behaveData;
	}
	return \%splitConf;
}

#==========================================
# __genSystemDiskHash
#------------------------------------------
sub __genSystemDiskHash {
	# ...
	# Return a ref to a hash containing the configuration for <systemdisk>
	# of the given XML:ELEMENT object. Build a data structure that
	# matches the structure defined in KIWIXMLSystemdiskData
	# ---
	my $this = shift;
	my $node = shift;
	my $lvmNode = $node -> getChildrenByTagName('systemdisk');
	if (! $lvmNode ) {
		return;
	}
	my $kiwi = $this->{kiwi};
	my $lvmDataNode = $lvmNode -> get_node(1);
	my %lvmData;
	$lvmData{name} = $lvmDataNode -> getAttribute('name');
	my @volumes = $lvmDataNode -> getChildrenByTagName('volume');
	my %volData;
	my $cntr = 1;
	for my $vol (@volumes) {
		my %volInfo;
		$volInfo{freespace} = $this->__convertSizeStrToMBVal(
			$vol -> getAttribute('freespace')
		);
		my $name = $vol -> getAttribute('name');
		my $msg = "Invalid name '$name' for LVM volume setup";
		$name =~ s/\s+//g;
		if ($name eq '/') {
			$kiwi -> error($msg);
			$kiwi -> failed();
			return -1;
		}
		$name =~ s/^\///;
		if ($name
		 =~ /^(image|proc|sys|dev|boot|mnt|lib|bin|sbin|etc|lost\+found)/sxm
		) {
			$kiwi -> error($msg);
			$kiwi -> failed();
			return -1;
		}
		$volInfo{name} = $name;
		$volInfo{size} = $this->__convertSizeStrToMBVal(
			$vol -> getAttribute('size')
		);
		$volData{$cntr} = \%volInfo;
		$cntr += 1;
	}
	$lvmData{volumes} = \%volData;
	return \%lvmData;
}

#==========================================
# __genTypeHash
#------------------------------------------
sub __genTypeHash {
	# ...
	# Return a ref to a hash keyed by the image type values for all <type>
	# definitions that are children of the given XML:ELEMENT object
	# Build a data structure that matches the structure defined in
	# KIWIXMLTypeData
	# ---
	my $this = shift;
	my $node = shift;
	my @typeNodes = $node -> getChildrenByTagName('type');
	my %types = ();
	if (! @typeNodes) {
		# no types specified in this preferences section
		return;
	}
	#==========================================
	# list of type attributes to store
	#------------------------------------------
	my @attrlist = (
		'boot',
		'bootfilesystem',
		'bootkernel',
		'bootloader',
		'bootpartsize',
		'bootprofile',
		'boottimeout',
		'checkprebuilt',
		'compressed',
		'devicepersistency',
		'editbootconfig',
		'editbootinstall',
		'filesystem',
		'flags',
		'format',
		'fsmountoptions',
		'fsnocheck',
		'fsreadonly',
		'fsreadwrite',
		'hybrid',
		'hybridpersistent',
		'image',
		'installboot',
		'installiso',
		'installpxe',
		'installprovidefailsafe',
		'installstick',
		'kernelcmdline',
		'luks',
		'ramonly',
		'vga',
		'volid'
	);
	#==========================================
	# store a value for the default type
	#------------------------------------------
	my $defaultType = $typeNodes[0] -> getAttribute('image');
	#==========================================
	# walk through all types of this prefs
	#------------------------------------------
	foreach my $type (@typeNodes) {
		my %typeData;
		#==========================================
		# store a value for the primary attribute
		#------------------------------------------
		my $prim = $type -> getAttribute('primary');
		if ($prim && $prim eq 'true') {
			$typeData{primary} = 'true';
			$defaultType = $type -> getAttribute('image');
		} else {
			$typeData{primary} = 'false';
		}
		#==========================================
		# store attributes
		#------------------------------------------
		foreach my $attr (@attrlist) {
			$typeData{$attr} = $type -> getAttribute($attr);
		}
		#==========================================
		# store <ec2config> child
		#------------------------------------------
		$typeData{ec2config} = $this -> __genEC2ConfigHash($type);
		#==========================================
		# store <machine> child
		#------------------------------------------
		$typeData{machine}   = $this -> __genVMachineHash($type);
		#==========================================
		# store <oemconfig> child
		#------------------------------------------
		$typeData{oemconfig} = $this -> __genOEMConfigHash($type);
		#==========================================
		# store <size>...</size> text
		#------------------------------------------
		$typeData{size} = $this -> __getChildNodeTextValue($type, 'size');
		#==========================================
		# store <pxeconfig> child
		#------------------------------------------
		$typeData{pxedeploy} = $this -> __genPXEDeployHash($type);
		if ($typeData{pxedeploy} && $typeData{pxedeploy} == -1) {
			return -1;
		}
		#==========================================
		# store <split> child
		#------------------------------------------
		$typeData{split} = $this -> __genSplitDataHash($type);
		if ($typeData{split} && $typeData{split} == -1) {
			return -1;
		}
		#==========================================
		# store <systemdisk> child
		#------------------------------------------
		$typeData{systemdisk} = $this -> __genSystemDiskHash($type);
		if ($typeData{systemdisk} && $typeData{systemdisk} == -1) {
			return -1;
		}
		#==========================================
		# store this type in %types
		#------------------------------------------
		$types{$typeData{image}} = \%typeData;
	}
	$types{defaultType} = $defaultType;
	return \%types;
}

#==========================================
# __genVMachineHash
#------------------------------------------
sub __genVMachineHash {
	# ...
	# Return a ref to a hash that contains the configuration data
	# for the <machine> element and it's children for the
	# given XML:ELEMENT object
	# ---
	my $this = shift;
	my $node = shift;
	my $vmConfig = $node -> getChildrenByTagName('machine') -> get_node(1);
	if (! $vmConfig ) {
		return;
	}
	my %vmConfigData;
	$vmConfigData{HWversion}  = $vmConfig -> getAttribute('HWversion');
	$vmConfigData{arch}       = $vmConfig -> getAttribute('arch');
	$vmConfigData{des_cpu}    = $vmConfig -> getAttribute('des_cpu');
	$vmConfigData{des_memory} = $vmConfig -> getAttribute('des_memory');
	$vmConfigData{domain}     = $vmConfig -> getAttribute('domain');
	$vmConfigData{guestOS}    = $vmConfig -> getAttribute('guestOS');
	$vmConfigData{max_cpu}    = $vmConfig -> getAttribute('max_cpu');
	$vmConfigData{max_memory} = $vmConfig -> getAttribute('max_memory');
	$vmConfigData{memory}     = $vmConfig -> getAttribute('memory');
	$vmConfigData{min_cpu}    = $vmConfig -> getAttribute('min_cpu');
	$vmConfigData{min_memory} = $vmConfig -> getAttribute('min_memory');
	$vmConfigData{ncpus}      = $vmConfig -> getAttribute('ncpus');
	$vmConfigData{ovftype}    = $vmConfig -> getAttribute('ovftype');
	#==========================================
	# Configuration text
	#------------------------------------------
	my @confNodes = $vmConfig -> getChildrenByTagName('vmconfig-entry');
	my @confData;
	for my $conf (@confNodes) {
		push @confData, $conf -> textContent();
	}
	my $configSttings;
	if (@confData) {
		$configSttings = \@confData;
	}
	$vmConfigData{vmconfig_entries} = $configSttings;
	#==========================================
	# System Disk
	#------------------------------------------
	my @diskNodes = $vmConfig -> getChildrenByTagName('vmdisk');
	my %diskData;
	for my $disk (@diskNodes) {
		my %diskSet;
		$diskSet{controller} = $disk -> getAttribute('controller');
		$diskSet{device}     = $disk -> getAttribute('device');
		$diskSet{disktype}   = $disk -> getAttribute('disktype');
		$diskSet{id}         = $disk -> getAttribute('id');
		# Currently there is only one disk, the system disk
		$diskData{system} = \%diskSet;
	}
	$vmConfigData{vmdisks} = \%diskData;
	#==========================================
	# CD/DVD
	#------------------------------------------
	my $dvdNodes = $vmConfig -> getChildrenByTagName('vmdvd');
	if ($dvdNodes) {
		my $dvdNode = $dvdNodes -> get_node(1);
		my %dvdData;
		$dvdData{controller} = $dvdNode -> getAttribute('controller');
		$dvdData{id}         = $dvdNode -> getAttribute('id');
		$vmConfigData{vmdvd} = \%dvdData;
	}
	#==========================================
	# Network interfaces
	#------------------------------------------
	my @nicNodes = $vmConfig -> getChildrenByTagName('vmnic');
	my %nicData;
	my $cntr = 1;
	for my $nic (@nicNodes) {
		my %nicSet;
		$nicSet{driver}    = $nic -> getAttribute('driver');
		$nicSet{interface} = $nic -> getAttribute('interface');
		$nicSet{mac}       = $nic -> getAttribute('mac');
		$nicSet{mode}      = $nic -> getAttribute('mode');
		$nicData{$cntr} = \%nicSet;
		$cntr += 1;
	}
	$vmConfigData{vmnics} = \%nicData;
	return \%vmConfigData;
}

#==========================================
# __getChildNodeTextValue
#------------------------------------------
sub __getChildNodeTextValue {
	# ...
	# Return the value of the node identified by the
	# given name as text.
	# ---
	my $this = shift;
	my $node = shift;
	my $childName = shift;
	my $cNode = $node -> getChildrenByTagName($childName);
	if ($cNode) {
		return $cNode -> get_node(1) -> textContent();
	}
	return;
}

#==========================================
# __getEntryPath
#------------------------------------------
sub __getEntryPath {
	# ...
	# Return the position in the imageConfig structure where install data
	# objects shold be stored. Install data objects are children of the
	# <packages> element
	# ---
	my $this    = shift;
	my $locData = shift;
	my $arch     = $locData->{arch};
	my $profName = $locData->{profName};
	my $type     = $locData->{type};
	my $kiwi = $this->{kiwi};
	if (! $profName) {
		my $msg = 'Internal error: __getEntryPath called without profName '
			. 'keyword argument. Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $type) {
		my $msg = 'Internal error: __getEntryPath called without type '
			. 'keyword argument. Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $entryPath;
	my $basePath = $this ->{imageConfig}->{$profName};
	if ( $type eq 'delete' || $type eq 'bootstrap' || $type eq 'image' ) {
		if ($arch) {
			$entryPath = $basePath->{$arch};
			if (! $entryPath) {
				$basePath->{$arch} = {};
				$entryPath = $basePath->{$arch};
			}
		} else {
			$entryPath = $basePath;
		}
	} else { #one of the image types
		# Create the data structure entries as needed
		my $tPath = $basePath->{$type};
		if (! $tPath) {
			$basePath->{$type} = {};
			$tPath = $basePath->{$type};
		}
		if ($arch) {
			$entryPath = $tPath->{$arch};
			if (! $entryPath) {
				$tPath->{$arch} = {};
				$entryPath = $tPath->{$arch};
			}
		} else {
			$entryPath = $tPath;
		}
	}
	return $entryPath;
}

#==========================================
# __getInstallData
#------------------------------------------
sub __getInstallData {
	# ...
	# Return a ref to an array containing objects accumulated across the
	# image config data structure for the given accessID.
	# ---
	my $this   = shift;
	my $access = shift;
	my $kiwi = $this->{kiwi};
	if (! $access) {
		my $msg = 'Internal error: __getInstallDataNamescalled without '
			. 'access pattern argument. Please file a bug';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $arch = $this->{arch};
	my @selected = @{$this->{selectedProfiles}};
	my $type = $this->{selectedType}{image};
	my @names;
	for my $prof (@selected) {
		my $baseData = $this->{imageConfig}{$prof}{$access};
		if ($baseData) {
			push @names, @{$baseData};
		}
		if ($this->{imageConfig}{$prof}{$arch}) {
			my $archData = $this->{imageConfig}{$prof}{$arch}{$access};
			if ($archData) {
				push @names, @{$archData};
			}
		}
		my $typeInfo = $this->{imageConfig}{$prof}{$type};
		if ($typeInfo) {
			my $typeData = $typeInfo->{$access};
			if ($typeData) {
				push @names, @{$typeData};
			}
			my $typeArch = $typeInfo->{$arch};
			if ($typeArch) {
				my $typeArchData = $typeArch->{$access};
				if ($typeArchData) {
					push @names, @{$typeArchData};
				}
			}
		}
	}
	return \@names;
}

#==========================================
# __getPackagesToIgnore
#------------------------------------------
sub __getPackagesToIgnore {
	# ...
	# Return an array ref containing IgnorePackageData objects
	# The method is private as it is needed for filtering only. Clients
	# of the XML object should not do any filtering on the data received.
	# ---
	my $this = shift;
	return $this -> __getInstallData('ignorePkgs');
}

#==========================================
# __getProfsToModify
#------------------------------------------
sub __getProfsToModify {
	# ...
	# Given an array ref, the keyword "default", or no argument
	# generate an array of profile names
	# ---
	my $this      = shift;
	my $profNames = shift;
	my $msgData   = shift;
	my @profsToUse;
	if ($profNames) {
		# operate on value of profile argument
		if ( ref($profNames) eq 'ARRAY' ) {
			# Multiple profiles, verify that all names are valid
			my $msg = "Attempting to add $msgData to 'PROF_NAME', but "
				. 'this profile is not specified in the configuration.';
			if (! $this -> __verifyProfNames($profNames, $msg)) {
				return;
			}
			@profsToUse = @{$profNames};
		} elsif ($profNames eq 'default') {
			# Only the default profile is affected by change
			@profsToUse = ('kiwi_default');
		}
	} else {
		# No profile argument was given, operate on the currently
		# active profiles (minus kiwi_default)
		my @selected = @{$this->{selectedProfiles}};
		for my $prof (@selected) {
			if ($prof eq 'kiwi_default') {
				next;
			}
			push @profsToUse, $prof;
		}
	}
	return @profsToUse;
}


#==========================================
# __getTypeNamesForProfs
#------------------------------------------
sub __getTypeNamesForProfs {
	# ...
	# Retun an array ref containing names of the configured types for the
	# given profile names.
	# ---
	my $this      = shift;
	my $profNames = shift;
	my $kiwi = $this->{kiwi};
	if (! $profNames) {
		my $msg = 'Internal error: __getTypeNamesForProfs called without '
			. 'argument. Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($profNames) ne 'ARRAY') {
		my $msg = 'Internal error: __getTypeNamesForProfs expecting array '
			. 'ref as argument. Please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @names;
	for my $prof (@{$profNames}) {
		my $prefs = $this->{imageConfig}{$prof}{preferences};
		if (! $prefs) {
			next;
		}
		my $types = $prefs->{types};
		if (! $types) {
			next;
		}
		push @names, keys %{$types};
	}
	return \@names;
}

#==========================================
# __mergePreferenceData
#------------------------------------------
sub __mergePreferenceData {
	# ...
	# Merge two hashes that represent <preferences> data into one.
	# Expecting two hash refs as arguments and return a hashref to
	# the merged data. If both hashes have definitions for the
	# same data issues an error.
	# ---
	my $this = shift;
	my $base = shift;
	my $ext  = shift;
	my $kiwi = $this->{kiwi};
	my %merged;
	my @attrs = qw(
		bootloader_theme
		bootsplash_theme
		defaultdestination
		defaultprebuilt
		defaultroot
		hwclock
		keymap
		locale
		packagemanager
		rpm_check_signatures
		rpm_excludedocs
		rpm_force
		showlicense
		timezone
		types
		version
	);
	for my $attr (@attrs) {
		if ($attr eq 'types') {
			my %types;
			my $baseTypes = $base->{types};
			my $extTypes  = $ext->{types};
			if ($baseTypes && $extTypes) {
				my @defTypes = keys %{$baseTypes};
				for my $type (@defTypes) {
					# Ignore the internal indicator for the default built type
					if ($type eq 'defaultType') {
						next;
					}
					if ( $extTypes->{$type} ) {
						my $msg = 'Error merging preferences data, found '
							. "definition for type '$type' in both "
							. 'preference definitions, ambiguous operation.';
						$kiwi -> error($msg);
						$kiwi -> failed();
						return;
					}
				}
			}
			if ($baseTypes) {
				my @defTypes = keys %{$baseTypes};
				for my $type (@defTypes) {
					$types{$type} = $baseTypes->{$type};
				}
			}
			if ($extTypes) {
				my @defTypes = keys %{$extTypes};
				for my $type (@defTypes) {
					$types{$type} = $extTypes->{$type};
				}
			}
			next;
		}
		if ( $base->{$attr} && $ext->{$attr} ) {
			my $msg = 'Error merging preferences data, found data for '
				. "'$attr' in both preference definitions, ambiguous "
				. 'operation.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		if ($base->{$attr}) {
			$merged{$attr} = $base->{$attr};
		}
		if ($ext->{$attr}) {
			$merged{$attr} = $ext->{$attr};
		}
	}
	return \%merged;
}

#==========================================
# __populateArchiveInfo
#------------------------------------------
sub __populateArchiveInfo {
	# ...
	# Populate the imageConfig member with the
	# information from <archive> elements from <packages>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess;
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		} else {
			@profsToProcess = ('kiwi_default');
		}
		my $type = $pckgNd -> getAttribute('type');
		my @archiveNodes = $pckgNd -> getElementsByTagName('archive');
		for my $prof (@profsToProcess) {
			for my $archiveNd (@archiveNodes) {
				my $arch     = $archiveNd -> getAttribute('arch');
				my $bootIncl = $archiveNd -> getAttribute('bootinclude');
				my $name     = $archiveNd -> getAttribute('name');
				my %archData = (
					arch        => $arch,
					bootinclude => $bootIncl,
					name        => $name
				);
				my $archiveObj = KIWIXMLPackageArchiveData -> new (
					$kiwi, \%archData
				);
				my $accessID;
				if ($bootIncl && $bootIncl eq 'true') {
					$accessID = 'bootArchives';
				} else {
					$accessID = 'archives';
				}
				my %storeData = (
					accessID => $accessID,
					arch     => $arch,
					dataObj  => $archiveObj,
					profName => $prof,
					type     => $type
				);
				if (! $this -> __storeInstallData(\%storeData)) {
					return;
				}
			}
		}
	}
	return 1;
}

#==========================================
# __populateDescriptionInfo
#------------------------------------------
sub __populateDescriptionInfo {
	# ...
	# Populate the imageConfig member with the
	# description data from the XML file.
	# ---
	my $this = shift;
	my $descrNode = $this->{systemTree}
		-> getElementsByTagName ('description')
		-> get_node(1);
	my $author  = $this
		-> __getChildNodeTextValue ($descrNode, 'author');
	my $contact = $this
		-> __getChildNodeTextValue ($descrNode, 'contact');
	my $spec    = $this
		-> __getChildNodeTextValue($descrNode,'specification');
	my $type    = $descrNode
		-> getAttribute ('type');
	my %descript = (
		author        => $author,
		contact       => $contact,
		specification => $spec,
		type          => $type
	);
	$this->{imageConfig}{description} = \%descript;
	return $this;
}

#==========================================
# __populateDriverInfo
#------------------------------------------
sub __populateDriverInfo {
	# ...
	# Populate the imageConfig member with the
	# drivers data from the XML file.
	# ---
	my $this = shift;
	my @drvNodes = $this->{systemTree}
		-> getElementsByTagName ('drivers');
	for my $drvNode (@drvNodes) {
		my @drivers = $drvNode -> getElementsByTagName ('file');
		my %archDrvs;
		my @drvNames;
		for my $drv (@drivers) {
			my $name = $drv -> getAttribute('name');
			my $arch = $drv -> getAttribute('arch');
			if (! $arch) {
				push @drvNames, $name
			} else {
				if (defined $archDrvs{$arch}) {
					my @dLst = @{$archDrvs{$arch}};
					push @dLst, $name;
					$archDrvs{$arch} = \@dLst;
				} else {
					my @dLst = ($name, );
					$archDrvs{$arch} = \@dLst;
				}
			}
		}
		my @pNameLst = ('kiwi_default');
		my $profNames = $drvNode -> getAttribute('profiles');
		if ($profNames) {
			@pNameLst = split /,/, $profNames;
		}
		for my $profName (@pNameLst) {
			my $drivers = $this->{imageConfig}
				->{$profName}->{drivers};
			if (defined $drivers) {
				my @dLst = @{$this->{imageConfig}->{$profName}->{drivers}};
				push @dLst, @drvNames;
				$this->{imageConfig}->{$profName}->{drivers} = \@dLst;
			} else {
				$this->{imageConfig}->{$profName}->{drivers} = \@drvNames;
			}
			for my $arch (keys %archDrvs) {
				my $drivers = $this->{imageConfig}
					->{$profName}->{$arch}->{drivers};
				if (defined $drivers) {
					my @dLst = @{$this->{imageConfig}
						->{$profName}->{$arch}->{drivers}};
					my @archLst = @{$archDrvs{$arch}};
					push @dLst, @archLst;
					$this->{imageConfig}->{$profName}
						->{$arch}->{drivers} =	\@dLst;
				} else {
					$this->{imageConfig}->{$profName}
						->{$arch}->{drivers} =	$archDrvs{$arch};
				}
			}
		}
	}
	return $this;
}

#==========================================
# __populateIgnorePackageInfo
#------------------------------------------
sub __populateIgnorePackageInfo {
	# ...
	# Populate the imageConfig member with the
	# information from <ignore>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess;
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		} else {
			@profsToProcess = ('kiwi_default');
		}
		my $type = $pckgNd -> getAttribute('type');
		my @ignoreNodes = $pckgNd -> getElementsByTagName('ignore');
		for my $prof (@profsToProcess) {
			for my $ignoreNd (@ignoreNodes) {
				my $arch = $ignoreNd -> getAttribute('arch');
				my $name = $ignoreNd -> getAttribute('name');
				my %ignoreData = (
					arch => $arch,
					name => $name
				);
				my $ignoreObj = KIWIXMLPackageIgnoreData
					-> new($kiwi, \%ignoreData);
				my %storeData = (
					accessID => 'ignorePkgs',
					arch     => $arch,
					dataObj  => $ignoreObj,
					profName => $prof,
					type     => $type
				);
				if (! $this -> __storeInstallData(\%storeData)) {
					return;
				}
			}
		}
	}
	return 1;
}

#==========================================
# __populatePackageInfo
#------------------------------------------
sub __populatePackageInfo {
	# ...
	# Populate the imageConfig member with the
	# information from <package>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $installOptType = $pckgNd -> getAttribute('patternType');
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess;
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		} else {
			@profsToProcess = ('kiwi_default');
		}
		my $type = $pckgNd -> getAttribute('type');
		my @packagesNodes = $pckgNd -> getElementsByTagName('package');
		for my $prof (@profsToProcess) {
			if ($installOptType) {
				$this->{imageConfig}{$prof}{installOpt} = $installOptType;
			}
			for my $pNd (@packagesNodes) {
				my $arch     = $pNd -> getAttribute('arch');
				my $bootDel  = $pNd -> getAttribute('bootdelete');
				my $bootIncl = $pNd -> getAttribute('bootinclude');
				my $name     = $pNd -> getAttribute('name');
				my $replace  = $pNd -> getAttribute('replaces');
				my %pckgData = (
					arch        => $arch,
					bootdelete  => $bootDel,
					bootinclude => $bootIncl,
					name        => $name,
					replaces    => $replace
				);
				my $pckgObj = KIWIXMLPackageData -> new($kiwi, \%pckgData);
				my @access;
				if ($bootDel && $bootDel eq 'true') {
					push @access, 'bootDelPkgs';
					if (! $bootIncl || $bootIncl eq 'false') {
						push @access, 'pkgs';
					}
				}
				if ($bootIncl && $bootIncl eq 'true') {
					push @access, 'bootPkgs';
				}
				if (! @access) {
					push @access, 'pkgs';
				}
				if ($type eq 'delete') {
					# In a type='delete' section attributes are ignored
					@access = ('delPkgs');
				}
				if ($type eq 'bootstrap') {
					# In a type='bootstrap' section attributes are ignored
					@access = ('bootStrapPckgs');
				}
				for my $accessID (@access) {
					my %storeData = (
					    accessID => $accessID,
					    arch     => $arch,
					    dataObj  => $pckgObj,
					    profName => $prof,
					    type     => $type
				    );
					if (! $this -> __storeInstallData(\%storeData)) {
						return;
					}
				}
			}
		}
	}
	return 1;
}

#==========================================
# __populatePackageCollectionInfo
#------------------------------------------
sub __populatePackageCollectionInfo {
	# ...
	# Populate the imageConfig member with the
	# information from <opensusePattern> and <rhelGroup>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess;
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		} else {
			@profsToProcess = ('kiwi_default');
		}
		my $type = $pckgNd -> getAttribute('type');
		my @collectNodes = $pckgNd -> getElementsByTagName('opensusePattern');
		my @cNodes = $pckgNd -> getElementsByTagName('rhelGroup');
		push @collectNodes, @cNodes;
		for my $prof (@profsToProcess) {
			for my $collectNd (@collectNodes) {
				my $arch     = $collectNd -> getAttribute('arch');
				my $bootIncl = $collectNd -> getAttribute('bootinclude');
				my $name     = $collectNd -> getAttribute('name');
				my %collectData = (
					arch       => $arch,
					bootinclude => $bootIncl,
					name        => $name
				);
				my $collectObj = KIWIXMLPackageCollectData
					-> new($kiwi, \%collectData);
				my $accessID;
				if ($bootIncl && $bootIncl eq 'true') {
					$accessID = 'bootPkgsCollect';
				} else {
					$accessID = 'pkgsCollect';
				}
				my %storeData = (
					accessID => $accessID,
					arch     => $arch,
					dataObj  => $collectObj,
					profName => $prof,
					type     => $type
				);
				if (! $this -> __storeInstallData(\%storeData)) {
					return;
				}
			}
		}
	}
	return 1;
}

#==========================================
# __populateProductInfo
#------------------------------------------
sub __populateProductInfo {
	# ...
	# Populate the imageConfig member with the
	# information from <opensusePattern> and <rhelGroup>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess;
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		} else {
			@profsToProcess = ('kiwi_default');
		}
		my $type = $pckgNd -> getAttribute('type');
		my @productNodes = $pckgNd -> getElementsByTagName('opensuseProduct');
		for my $prof (@profsToProcess) {
			for my $prodNd (@productNodes) {
				my $arch     = $prodNd -> getAttribute('arch');
				my $name     = $prodNd -> getAttribute('name');
				my %productData = (
					arch       => $arch,
					name        => $name
				);
				my $prodObj = KIWIXMLPackageProductData -> new (
					$kiwi, \%productData
				);
				my %storeData = (
					accessID => 'products',
					arch     => $arch,
					dataObj  => $prodObj,
					profName => $prof,
					type     => $type
				);
				if (! $this -> __storeInstallData(\%storeData)) {
					return;
				}
			}
		}
	}
	return 1;
}

#==========================================
# __populatePreferenceInfo
#------------------------------------------
sub __populatePreferenceInfo {
	# ...
	# Populate the imageConfig member with the
	# preferences data from the XML file.
	# ---
	my $this = shift;
	my @prefNodes = $this->{systemTree} ->getElementsByTagName('preferences');
	if (! @prefNodes ) {
		my $kiwi = $this->{kiwi};
		my $msg = 'No <preference> element data found, cannot construct '
			. 'XML data object.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	for my $prefInfo (@prefNodes) {
		my $profNames = $prefInfo -> getAttribute ('profiles');
		my @pNameLst;
		if ($profNames) {
			@pNameLst = split /,/, $profNames;
		} else {
			@pNameLst = ('kiwi_default');
		}
		my $bootLoaderTheme = $this -> __getChildNodeTextValue(
			$prefInfo, 'bootloader-theme'
		);
		my $booSplashTheme  = $this -> __getChildNodeTextValue(
			$prefInfo, 'bootsplash-theme'
		);
		my $defaultDest     = $this -> __getChildNodeTextValue(
			$prefInfo, 'defaultdestination'
		);
		my $defaultPreBlt   = $this -> __getChildNodeTextValue(
			$prefInfo, 'defaultprebuilt'
		);
		my $defaultRoot     = $this -> __getChildNodeTextValue(
			$prefInfo, 'defaultroot'
		);
		my $hwclock         = $this -> __getChildNodeTextValue(
			$prefInfo, 'hwclock'
		);
		my $keymap          = $this -> __getChildNodeTextValue(
			$prefInfo, 'keytable'
		);
		my $locale          = $this -> __getChildNodeTextValue(
			$prefInfo, 'locale'
		);
		my $pckMgr          = $this -> __getChildNodeTextValue(
			$prefInfo, 'packagemanager'
		);
		my $rpmSigCheck     = $this -> __getChildNodeTextValue(
			$prefInfo, 'rpm-check-signatures'
		);
		my $rpmExclDoc      = $this -> __getChildNodeTextValue(
			$prefInfo, 'rpm-excludedocs'
		);
		my $rpmForce        = $this -> __getChildNodeTextValue(
			$prefInfo, 'rpm-force'
		);
		my @showLicNodes = $prefInfo -> getChildrenByTagName('showlicense');
		my @licensesToShow;
		for my $licNode (@showLicNodes) {
			push @licensesToShow, $licNode -> textContent();
		}
		my $showLic;
		if (@licensesToShow) {
			$showLic  = \@licensesToShow;
		}
		my $tz = $this -> __getChildNodeTextValue(
			$prefInfo, 'timezone'
		);
		my $types = $this -> __genTypeHash ($prefInfo);
		if ($types && $types == -1) {
			return;
		}
		my $vers  = $this -> __getChildNodeTextValue(
			$prefInfo, 'version'
		);
		my %prefs = (
			bootloader_theme     => $bootLoaderTheme,
			bootsplash_theme     => $booSplashTheme,
			defaultdestination   => $defaultDest,
			defaultprebuilt      => $defaultPreBlt,
			defaultroot          => $defaultRoot,
			hwclock              => $hwclock,
			keymap               => $keymap,
			locale               => $locale,
			packagemanager       => $pckMgr,
			rpm_check_signatures => $rpmSigCheck,
			rpm_excludedocs      => $rpmExclDoc,
			rpm_force            => $rpmForce,
			showlicense          => $showLic,
			timezone             => $tz,
			types                => $types,
			version              => $vers
		);
		for my $profName (@pNameLst) {
			if (! $this->{imageConfig}{$profName}{preferences} ) {
				$this->{imageConfig}{$profName}{preferences} = \%prefs;
			} else {
				my $mergedPrefs = $this -> __mergePreferenceData(
					$this->{imageConfig}{$profName}{preferences},
					\%prefs
				);
				if (! $mergedPrefs ) {
					return;
				}
				$this->{imageConfig}{$profName}{preferences} = $mergedPrefs
			}
		}
	}
	return $this;
}

#==========================================
# __populateProfileInfo
#------------------------------------------
sub __populateProfileInfo {
	# ...
	# Populate the imageConfig member with the
	# profile data from the XML file.
	# ---
	my $this = shift;
	my @profNodes = $this->{systemTree} -> getElementsByTagName ('profile');
	if (! @profNodes ) {
		return $this;
	}
	my @availableProfiles;
	for my $element (@profNodes) {
		# Extract attributes
		my $descript = $element -> getAttribute ('description');
		my $import = $element -> getAttribute ('import');
		if (! defined $import) {
			$import = 'false'
		}
		my $profName = $element -> getAttribute ('name');
		push @availableProfiles, $profName;
		# Insert into internal data structure
		my %profile = (
			'description' => $descript,
			'import'      => $import
		);
		$this->{imageConfig}{$profName}{profInfo} = \%profile;
		# Handle default profile setting
		if ( $import eq 'true') {
			my @profs = ('kiwi_default', $profName);
			$this->{selectedProfiles} = \@profs;
		}
	}
	$this->{availableProfiles} = \@availableProfiles;
	return $this;
}

#==========================================
# __populateRepositoryInfo
#------------------------------------------
sub __populateRepositoryInfo {
	# ...
	# Populate the imageConfig member with the
	# repository data from the XML file.
	# ---
	my $this = shift;
	my @repoNodes = $this->{systemTree}
		-> getElementsByTagName ('repository');
	my $idCntr = 1;
	for my $repoNode (@repoNodes) {
		my %repoData;
		$repoData{alias}         = $repoNode
			-> getAttribute ('alias');
		$repoData{imageinclude}  = $repoNode
			-> getAttribute ('imageinclude');
		$repoData{password}      = $repoNode
			-> getAttribute ('password');
		$repoData{path}          = $repoNode
			-> getChildrenByTagName('source')
			-> get_node(1) -> getAttribute ('path');
		$repoData{preferlicense} = $repoNode
			-> getAttribute ('prefer-license');
		$repoData{priority}      = $repoNode
			-> getAttribute ('priority');
		$repoData{status}        = $repoNode
			-> getAttribute ('status');
		$repoData{type}          = $repoNode
			-> getAttribute ('type');
		$repoData{username}      = $repoNode
			-> getAttribute ('username');
		my $profiles = $repoNode
			-> getAttribute ('profiles');
		if (! $profiles) {
			$profiles = 'kiwi_default';
		}
		my @profNames = split /,/, $profiles;
		for my $profName (@profNames) {
			my $repoRef = $this->{imageConfig}->{$profName}{repoData};
			if (! $repoRef) {
				my %repoInfo = ( $idCntr => \%repoData);
				$this->{imageConfig}->{$profName}{repoData} = \%repoInfo;
			} else {
				my %repoInfo = %{$repoRef};
				$repoInfo{$idCntr} = \%repoData;
				$this->{imageConfig}->{$profName}{repoData} = \%repoInfo;
			}
			$idCntr += 1;
		}
	}
	# Store the next counter to be used as repo ID
	$this -> {repoCounter} = $idCntr;
	return $this;
}

#==========================================
# __populateUserInfo
#------------------------------------------
sub __populateUserInfo {
	# ...
	# Populate the imageConfig member with the
	# user data from the XML file.
	# ---
	my $this = shift;
	my @userGrpNodes = $this->{systemTree} -> getElementsByTagName('users');
	my %userData;
	for my $grpNode (@userGrpNodes) {
		my $groupname = $grpNode -> getAttribute('group');
		my $groupid   = $grpNode -> getAttribute('id');
		my @userNodes = $grpNode -> getElementsByTagName('user');
		for my $userNode (@userNodes) {
			my $name = $userNode -> getAttribute('name');
			my %info = (
				group        => $groupname,
				groupid      => $groupid,
				home         => $userNode -> getAttribute('home'),
				name         => $name,
				passwd       => $userNode -> getAttribute('pwd'),
				passwdformat => $userNode -> getAttribute('pwdformat'),
				realname     => $userNode -> getAttribute('realname'),
				shell        => $userNode -> getAttribute('shell'),
				userid       => $userNode -> getAttribute('id')
			);
			if ($userData{$name}) {
				my $kiwi = $this->{kiwi};
				my $msg = "Merging data for user '$name'";
				#TODO: Enable message when we move to the new code
				#      with old code the message would be misleading as
				#      the old code actually overwrites data :(
				#$kiwi -> info($msg);
				my $grp = $userData{$name}{group} . ",$groupname";
				$userData{$name}{group} = $grp;
				if ($groupid && (! $userData{$name}{groupid})) {
					$userData{$name}{groupid} = $groupid;
				}
				if ($info{passwd} && (! $userData{$name}{passwd})) {
					$userData{$name}{passwd} = $info{passwd};
				}
				if ($info{passwdformat} && (! $userData{$name}{passwdformat})){
					$userData{$name}{passwdformat} = $info{passwdformat};
				}
				if ($info{realname} && (! $userData{$name}{realname})) {
					$userData{$name}{realname} = $info{realname};
				}
				if ($info{shell} && (! $userData{$name}{shell})) {
					$userData{$name}{shell} = $info{shell};
				}
				if ($info{userid} && (! $userData{$name}{userid})) {
					$userData{$name}{userid} = $info{userid};
				}
				#$kiwi -> done();
			} else {
				$userData{$name} = \%info;
			}
		}
	}
	$this->{imageConfig}{users} = \%userData;
	return $this;
}

#==========================================
# __setDefaultBuildType
#------------------------------------------
sub __setDefaultBuildType {
	# ...
	# Set the default built type, which upon object construction is also the
	# the selected built type. The default built type is the first <type>
	# specification processed or the one type marked with primary="true"
	# across all the selected profiles. Unless a type is marked primary,
	# the default type of the default profile always wins. The default
	# type is a ref to a hash that is set as the default type as
	# differentiation by name is not sufficient, as multiple profiles
	# my have the same image type definition, which is valid as long as
	# those profiles are not processed together.
	# ---
	my $this = shift;
	my $primaryCount = 0;
	# /.../
	# Assume the default type of the default preferences
	# section is the winner
	# ----
	my $defTypeName = $this->{imageConfig}
		->{kiwi_default}->{preferences}->{types}->{defaultType};
	my $defType;
	if ($defTypeName) {
		$defType = $this->{imageConfig}
			->{kiwi_default}->{preferences}->{types}->{$defTypeName};
		if ($defType->{primary} && $defType->{primary} eq 'true') {
			$primaryCount++;
		}
	}
	# /.../
	# Process the selected profiles to see if anything is
	# marked primary or find the default type if the default
	# profile had no specification
	# ----
	for my $profName (@{$this->{selectedProfiles}}) {
		if ($profName eq 'kiwi_default') {
			# Already processed
			next;
		}
		my $profDefTypeName = $this->{imageConfig}
			->{$profName}->{preferences}->{types}->{defaultType};
		if (! $profDefTypeName ) {
			# This preferences section has no type(s) defined
			next;
		}
		my $profDefTypeIsPrim = $this->{imageConfig}
			->{$profName}->{preferences}->{types}
			->{$profDefTypeName}->{primary};
		if ($profDefTypeIsPrim && $profDefTypeIsPrim eq 'true') {
			if ($primaryCount) {
				my $kiwi = $this->{kiwi};
				my $msg = 'Processing more than one type marked as '
					. '"primary", cannot resolve build type.';
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
			$primaryCount++;
			$defType = $this->{imageConfig}
				->{$profName}->{preferences}->{types}->{$profDefTypeName};
		}
		if (! $defType) {
			$defType = $this->{imageConfig}
				->{$profName}->{preferences}->{types}->{$profDefTypeName};
		}
	}
	$this->{defaultType} = $defType;
	return $this;
}

#==========================================
# __storeInstallData
#------------------------------------------
sub __storeInstallData {
	# ...
	# Store the given install data object in the proper location in the data
	# structure. Install data objects are objects of children of the
	# <packages> element
	# ---
	my $this      = shift;
	my $storeInfo = shift;
	my $accessID   = $storeInfo->{accessID};
	my $arch       = $storeInfo->{arch};
	my $objToStore = $storeInfo->{dataObj};
	my $profName   = $storeInfo->{profName};
	my $type       = $storeInfo->{type};
	my $kiwi = $this->{kiwi};
	if (! $accessID) {
		my $msg = 'Internal error: __storeInstallData called without '
			. 'accessID keyword argument.';
		$kiwi -> erro($msg);
		$kiwi -> failed();
		return;
	}
	if (! $objToStore) {
		# Nothing to store
		return 1;
	}
	my %entryData = (
		arch     => $arch,
		profName => $profName,
		type     => $type
	);
	my $entryPath = $this -> __getEntryPath(\%entryData);
	if (! $entryPath) {
		return;
	}
	if ($entryPath->{$accessID}) {
		push @{$entryPath->{$accessID}}, $objToStore;
	} else {
		my @data = ($objToStore);
		$entryPath->{$accessID} = \@data;
	}
	return 1;
}

#==========================================
# __verifyAddInstallDataArgs
#------------------------------------------
sub __verifyAddInstallDataArgs {
	# ...
	# Verify the arguments given to any of the add* methods that handle
	# image installation data.
	# ---
	my $this = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	if (! $data) {
		my $msg = 'Internal error: __verifyAddInstallDataArgs called without '
			. 'argument. Please file a bug.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	if (ref($data) ne 'HASH') {
		my $msg = 'Internal error: __verifyAddInstallDataArgs expecting hash '
			. 'ref as argument. Please file a bug.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my $caller = $data->{caller};
	if (! $caller) {
		my $msg = 'Internal error: __verifyAddInstallDataArgs no call origin '
			. 'given. Please file a bug.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my $expectedType = $data->{expectedType};
	if (! $expectedType) {
		my $msg = 'Internal error: __verifyAddInstallDataArgs no type to '
			. 'verify given. Please file a bug.';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	my $itemName = $data->{itemName};
	my $itemsToAdd = $data->{itemsToAdd};
	if (! $itemsToAdd) {
		my $msg = "$caller: no $itemName specified, nothing to do";
		$kiwi -> info($msg);
		$kiwi -> skipped ();
		return $this;
	}
	if (ref($itemsToAdd) ne 'ARRAY' ) {
		my $msg = "$caller: expecting array ref for $expectedType array "
			. 'as first argument';
		$kiwi -> error ($msg);
		$kiwi -> failed ();
		return;
	}
	for my $item (@{$itemsToAdd}) {
		if (ref($item) ne $expectedType ) {
			my $msg = "$caller: found array item not of type $expectedType "
				. "in $itemName array";
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	my $profNames = $data->{profNames};
	my @profsToUse = $this -> __getProfsToModify($profNames, $itemName);
	if (! @profsToUse) {
		return;
	}
	my $type = $data->{type};
	if ($type) {
		my $typeNames = $this -> __getTypeNamesForProfs(\@profsToUse);
		my %availTypes = map { $_ => 1 } @{$typeNames};
		if (! $availTypes{$type}) {
			my $msg = "$caller: could not find specified type '$type' "
				. "within the active profiles; $itemName not added.";
			$kiwi -> error ($msg);
			$kiwi -> failed ();
			return;
		}
	}
	return 1;
}

#==========================================
# __verifyProfNames
#------------------------------------------
sub __verifyProfNames {
	# ...
	# Verify that the profile names in the given array ref are available,
	# if not print the given msg substituting PROF_NAME in the message
	# with the name that is in violation.
	# ---
	my $this  = shift;
	my $names = shift;
	my $msg   = shift;
	my @namesToCheck = @{$names};
	my %specProfs = map { ($_ => 1 ) } @{$this->{availableProfiles}};
	for my $name (@namesToCheck) {
		if ($name eq 'kiwi_default') {
			next;
		}
		if (! $specProfs{$name} ) {
			my $kiwi = $this->{kiwi};
			$msg =~ s/PROF_NAME/$name/;
			$kiwi -> error($msg);
			$kiwi ->  failed();
			return;
		}
	}
	return 1;
}

#==========================================
# End "new" methods section
#------------------------------------------
#==========================================
# updateTypeList
#------------------------------------------
sub updateTypeList {
	# ...
	# if the XML tree has changed because of a function
	# changing the typenode, it's required to update the
	# internal typeInfo hash too
	# ---
	my $this = shift;
	$this->{typeList} = $this -> __populateTypeInfo_legacy();
	$this -> __populateProfiledTypeInfo_legacy();
	return;
}

#==========================================
# updateXML
#------------------------------------------
sub updateXML {
	# ...
	# Write back the current DOM tree into the file
	# referenced by getRootLog but with the suffix .xml
	# if there is no log file set the service is skipped
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $xmlu = $this->{systemTree}->toString();
	my $xmlf = $this->{xmlOrigFile};
	$kiwi -> storeXML ( $xmlu,$xmlf );
	return $this;
}

#==========================================
# writeXMLDescription
#------------------------------------------
sub writeXMLDescription {
	# ...
	# Write back the XML file into the prepare tree
	# below the image/ directory
	# ---
	my $this = shift;
	my $root = shift;
	my $gdata= $this->{gdata};
	my $xmlu = $this->{systemTree}->toString();
	my $file = $root."/image/config.xml";
	my $FD;
	if (! open ($FD, '>', $file)) {
		return;
	}
	print $FD $xmlu;
	close $FD;
	my $pretty = $gdata->{Pretty};
	qxx ("xsltproc -o $file.new $pretty $file");
	qxx ("mv $file.new $file");
	my $overlayTree = $gdata->{OverlayRootTree};
	if ($overlayTree) {
		qxx ("mkdir -p $overlayTree");
		qxx ("cp $file $overlayTree");
		$main::global -> setGlobals (
			"OverlayRootTree",0
		);
	}
	return $this;
}

#==========================================
# getConfigName
#------------------------------------------
sub getConfigName {
	my $this = shift;
	my $name = $this->{controlFile};
	return ($name);
}

#==========================================
# createURLList
#------------------------------------------
sub createURLList {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $cmdL = $this->{cmdL};
	my %repository  = ();
	my @urllist     = ();
	my %urlhash     = ();
	my @sourcelist  = ();
	%repository = $this->getRepositories_legacy();
	if (! %repository) {
		%repository = $this->getInstSourceRepository();
		foreach my $name (keys %repository) {
			push (@sourcelist,$repository{$name}{source});
		}
	} else {
		@sourcelist = keys %repository;
	}
	foreach my $source (@sourcelist) {
		my $user = $repository{$source}[3];
		my $pwd  = $repository{$source}[4];
		my $urlHandler  = KIWIURL -> new ($kiwi,$cmdL,undef,$user,$pwd);
		my $publics_url = $urlHandler -> normalizePath ($source);
		push (@urllist,$publics_url);
		$urlhash{$source} = $publics_url;
	}
	$this->{urllist} = \@urllist;
	$this->{urlhash} = \%urlhash;
	return $this;
}

#==========================================
# getURLHash
#------------------------------------------
sub getURLHash {
	my $this = shift;
	if (! $this->{urlhash}) {
		$this -> createURLList();
	}
	return $this->{urlhash};
}

#==========================================
# getURLList
#------------------------------------------
sub getURLList {
	my $this = shift;
	if (! $this->{urllist}) {
		$this -> createURLList();
	}
	return $this->{urllist};
}

#==========================================
# getImageName
#------------------------------------------
sub getImageName {
	# ...
	# Get the name of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $name = $node -> getAttribute ("name");
	return $name;
}

#==========================================
# getImageDisplayName
#------------------------------------------
sub getImageDisplayName {
	# ...
	# Get the display name of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $name = $node -> getAttribute ("displayname");
	if (! defined $name) {
		return $this->getImageName();
	}
	return $name;
}

#==========================================
# getImageID
#------------------------------------------
sub getImageID {
	my $this = shift;
	my $node = $this->{imgnameNodeList} -> get_node(1);
	my $code = $node -> getAttribute ("id");
	if (defined $code) {
		return $code;
	}
	return 0;
}

#==========================================
# getImageSize
#------------------------------------------
sub getImageSize {
	# ...
	# Get the predefined size of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false") || ($plus eq "0")) {
			my $unit = $node -> getElementsByTagName ("size")
				-> get_node(1) -> getAttribute("unit");
			if (! $unit) {
				# no unit specified assume MB...
				$unit = "M";
			}
			# /.../
			# the fixed size value was set, we will use this value
			# connected with the unit string
			# ----
			return $size.$unit;
		} else {
			# /.../
			# the size is setup as additive value to the required
			# size. The real size is calculated later and the additive
			# value is added at that point
			# ---
			return "auto";
		}
	} else {
		return "auto";
	}
}

#==========================================
# getImageSizeAdditiveBytes
#------------------------------------------
sub getImageSizeAdditiveBytes {
	# ...
	# Get the predefined size if the attribute additive
	# was set to true
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false")) {
			return 0;
		}
	}
	if ($size) {
		my $byte = int $size;
		my $unit = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("unit");
		if ((! $unit) || ($unit eq "M")) {
			# no unit or M specified, turn into Bytes...
			return $byte * 1024 * 1024;
		} elsif ($unit eq "G") {
			# unit G specified, turn into Bytes...
			return $byte * 1024 * 1024 * 1024;
		}
	} else {
		return 0;
	}
}

#==========================================
# getImageSizeBytes
#------------------------------------------
sub getImageSizeBytes {
	# ...
	# Get the predefined size of the logical extend
	# as byte value
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $byte = int $size;
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false") || ($plus eq "0")) {
			# /.../
			# the fixed size value was set, we will use this value
			# and return a byte number
			# ----
			my $unit = $node -> getElementsByTagName ("size")
				-> get_node(1) -> getAttribute("unit");
			if ((! $unit) || ($unit eq "M")) {
				# no unit or M specified, turn into Bytes...
				return $byte * 1024 * 1024;
			} elsif ($unit eq "G") {
				# unit G specified, turn into Bytes...
				return $byte * 1024 * 1024 * 1024;
			}
		} else {
			# /.../
			# the size is setup as additive value to the required
			# size. The real size is calculated later and the additive
			# value is added at that point
			# ---
			return "auto";
		}
	} else {
		return "auto";
	}
}

#==========================================
# getImageVersion
#------------------------------------------
sub getImageVersion {
	# ...
	# Get the version of the logical extend
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("version");
	my $version = $node -> getElementsByTagName ("version");
	return $version;
}


#==========================================
# getStripDelete
#------------------------------------------
sub getStripDelete {
	# ...
	# return the type="delete" files from the strip section
	# ---
	my $this   = shift;
	return $this -> __getStripFileList ("delete");
}

#==========================================
# getStripTools
#------------------------------------------
sub getStripTools {
	# ...
	# return the type="tools" files from the strip section
	# ---
	my $this   = shift;
	return $this -> __getStripFileList ("tools");
}

#==========================================
# getStripLibs
#------------------------------------------
sub getStripLibs {
	# ...
	# return the type="libs" files from the strip section
	# ---
	my $this   = shift;
	return $this -> __getStripFileList ("libs");
}

#==========================================
# setArch
#------------------------------------------
sub setArch {
	# ...
	# Set the architecture to use to retrieve information
	# ---
	my $this    = shift;
	my $newArch = shift;
	my %supported = %{ $this->{supportedArch} };
	if (! $supported{$newArch} ) {
		my $kiwi = $this->{kiwi};
		$kiwi -> error ("setArch: Specified arch '$newArch' is not supported");
		$kiwi -> failed ();
		return;
	}
	$this->{arch} = $newArch;
	return $this;
}

#==========================================
# getLocale
#------------------------------------------
sub getLocale {
	# ...
	# Obtain the locale value or return undef
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("locale");
	my $lang = $node -> getElementsByTagName ("locale");
	if ((! defined $lang) || ("$lang" eq "")) {
		return;
	}
	return $lang;
}


#==========================================
# getInstSourceRepository
#------------------------------------------
sub getInstSourceRepository {
	# ...
	# Get the repository path and priority used for building
	# up an installation source tree.
	# ---
	my $this = shift;
	my %result;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	if (! defined $base) {
		return %result;
	}
	my @node = $base -> getElementsByTagName ("instrepo");
	foreach my $element (@node) {
		my $prio = $element -> getAttribute("priority");
		my $name = $element -> getAttribute("name");
		my $user = $element -> getAttribute("username");
		my $pwd  = $element -> getAttribute("pwd");
		my $islocal  = $element -> getAttribute("local");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> __resolveLink ( $stag -> getAttribute ("path") );
		if (! defined $name) {
			$name = "noname";
		}
		$result{$name}{source}   = $source;
		$result{$name}{priority} = $prio;
		$result{$name}{islocal} = $islocal;
		if (defined $user) {
			$result{$name}{user} = $user.":".$pwd;
		}
	}
	return %result;
}

#==========================================
# getInstSourceArchList
#------------------------------------------
sub getInstSourceArchList {
	# ...
	# Get the architecture list used for building up
	# an installation source tree
	# ---
	# return a hash with the following structure:
	# name  = [ description, follower ]
	#   name is the key, given as "id" in the xml file
	#   description is the alternative name given as "name" in the xml file
	#   follower is the key value of the next arch in the fallback chain
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList}->get_node(1);
	my $elems = $base->getElementsByTagName("architectures");
	my %result;
	my @attr = ("id", "name", "fallback");
	for(my $i=1; $i<= $elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName("arch");
		my %rlist = map { $_->getAttribute("ref") => $_ }
			$node->getElementsByTagName("requiredarch");
		foreach my $element(@flist) {
			my $id = $element->getAttribute($attr[0]);
			next if (!$id);
			my $ra = 0;
			if($rlist{$id}) {
			  $ra = 1;
			}
			my ($d,$n) = (
				$element->getAttribute($attr[1]),
				$element->getAttribute($attr[2])
			);
			if($n) {
				$result{$id} = [ $d, $n, $ra ];
			} else {
				$result{$id} = [ $d, 0, $ra ];
			}
		}
	}
	return %result;
}

#==========================================
# getInstSourceProductVar
#------------------------------------------
sub getInstSourceProductVar {
	# ...
	# Get the shell variable values needed for
	# metadata creation
	# ---
	# return a hash with the following structure:
	# varname = value (quoted, may contain space etc.)
	# ---
	my $this = shift;
	return $this->getInstSourceProductStuff("productvar");
}

#==========================================
# getInstSourceProductOption
#------------------------------------------
sub getInstSourceProductOption {
	# ...
	# Get the shell variable values needed for
	# metadata creation
	# ---
	# return a hash with the following structure:
	# varname = value (quoted, may contain space etc.)
	# ---
	my $this = shift;
	return $this->getInstSourceProductStuff("productoption");
}

#==========================================
# getInstSourceProductStuff
#------------------------------------------
sub getInstSourceProductStuff {
	# ...
	# generic function returning indentical data
	# structures for different tags (of same type)
	# ---
	my $this = shift;
	my $what = shift;
	if (!$what) {
		return;
	}

	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $elems = $base->getElementsByTagName("productoptions");
	my %result;

	for(my $i=1; $i<=$elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName($what);
		foreach my $element(@flist) {
			my $name = $element->getAttribute("name");
			my $value = $element ->textContent("name");
			$result{$name} = $value;
		}
	}
	return %result;
}

#==========================================
# getInstSourceProductInfo
#------------------------------------------
sub getInstSourceProductInfo {
	# ...
	# Get the shell variable values needed for
	# content file generation
	# ---
	# return a hash with the following structure:
	# index = (name, value)
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $elems = $base->getElementsByTagName("productoptions");
	my %result;

	for(my $i=1; $i<=$elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName("productinfo");
		for(my $j=0; $j <= $#flist; $j++) {
		#foreach my $element(@flist) {
			my $name = $flist[$j]->getAttribute("name");
			my $value = $flist[$j]->textContent("name");
			$result{$j} = [$name, $value];
		}
	}
	return %result;
}

#==========================================
# getInstSourceChrootList
#------------------------------------------
sub getInstSourceChrootList {
	# ...
	# Get the list of packages necessary to
	# run metafile shell scripts in chroot jail
	# ---
	# return a list of packages
	# ---
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $elems = $base->getElementsByTagName("metadata");
	my @result;

	for(my $i=1; $i<=$elems->size(); $i++) {
		my $node  = $elems->get_node($i);
		my @flist = $node->getElementsByTagName("chroot");
		foreach my $element(@flist) {
			my $name = $element->getAttribute("requires");
			push @result, $name if $name;
		}
	}
	return @result;
}

#==========================================
# getInstSourceMetaFiles
#------------------------------------------
sub getInstSourceMetaFiles {
	# ...
	# Get the metafile data if any. The method is returning
	# a hash with key=metafile and a hashreference for the
	# attribute values url, target and script
	# ---
	my $this  = shift;
	my $base  = $this->{instsrcNodeList} -> get_node(1);
	my $nodes = $base -> getElementsByTagName ("metadata");
	my %result;
	my @attrib = (
		"target","script"
	);
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node  = $nodes -> get_node($i);
		my @flist = $node  -> getElementsByTagName ("metafile");
		foreach my $element (@flist) {
			my $file = $element -> getAttribute ("url");
			if (! defined $file) {
				next;
			}
			foreach my $key (@attrib) {
				my $value = $element -> getAttribute ($key);
				if (defined $value) {
					$result{$file}{$key} = $value;
				}
			}
		}
	}
	return %result;
}

#==========================================
# addStrip
#------------------------------------------
sub addStrip {
	# ...
	# Add the given strip list and type to the xml description
	# ----
	my @list  = @_;
	my $this  = shift @list;
	my $type  = shift @list;
	my $kiwi  = $this->{kiwi};
	my @supportedTypes = qw /delete libs tools/;
	if (! grep { /$type/ } @supportedTypes ) {
		my $msg = "Specified strip section type '$type' not supported.";
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	my $image = $this->{imgnameNodeList} -> get_node(1);
	my @stripNodes = $image -> getElementsByTagName ("strip");
	my $stripSection;
	for my $stripNode (@stripNodes) {
		my $sectionType = $stripNode -> getAttribute ("type");
		if ($type eq $sectionType) {
			$stripSection = $stripNode;
			last;
		}
	}
	if (! $stripSection ) {
		$stripSection = XML::LibXML::Element -> new ("strip");
		$stripSection -> setAttribute("type",$type);
		$image-> appendChild ($stripSection);
	}
	foreach my $name (@list) {
		my $fileSection = XML::LibXML::Element -> new ("file");
		$fileSection  -> setAttribute("name",$name);
		$stripSection -> appendChild ($fileSection);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addSimpleType
#------------------------------------------
sub addSimpleType {
	# ...
	# add simple filesystem type to the list of types
	# inside the preferences section
	# ---
	my $this  = shift;
	my $type  = shift;
	my $kiwi  = $this->{kiwi};
	my $nodes = $this->{optionsNodeList};
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $addElement = XML::LibXML::Element -> new ("type");
		$addElement -> setAttribute("image",$type);
		$nodes -> get_node($i) -> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# getInstSourcePackageAttributes
#------------------------------------------
sub getInstSourcePackageAttributes {
	# ...
	# Create an attribute hash for the given package
	# and package category.
	# ---
	my $this = shift;
	my $what = shift;
	my $pack = shift;
	my $nodes;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	if ($what eq "metapackages") {
		$nodes = $base -> getElementsByTagName ("metadata");
	} elsif ($what eq "instpackages") {
		$nodes = $base -> getElementsByTagName ("repopackages");
	} elsif ($what eq "DUDmodules") {
		$nodes = $base -> getElementsByTagName("driverupdate")
			-> get_node(1) -> getElementsByTagName('modules');
	} elsif ($what eq "DUDinstall") {
		$nodes = $base -> getElementsByTagName("driverupdate")
			-> get_node(1) -> getElementsByTagName('install');
	} elsif ($what eq "DUDinstsys") {
		$nodes = $base -> getElementsByTagName("driverupdate")
			-> get_node(1) -> getElementsByTagName('instsys');
	}
	my %result;
	my @attrib = (
		"forcerepo" ,"addarch", "removearch", "arch",
		"onlyarch", "source", "script", "medium"
	);
	if(not defined($this->{m_rpacks})) {
		my @nodes = ();
		for (my $i=1;$i<= $nodes->size();$i++) {
			my $node  = $nodes -> get_node($i);
			my @plist = $node  -> getElementsByTagName ("repopackage");
			push @nodes, @plist;
		}
		%{$this->{m_rpacks}} = map {$_->getAttribute("name") => $_} @nodes;
	}
	my $elem = $this->{m_rpacks}->{$pack};
	if(defined($elem)) {
		foreach my $key (@attrib) {
			my $value = $elem -> getAttribute ($key);
			if (defined $value) {
				$result{$key} = $value;
			}
		}
	}
	return \%result;
}

#==========================================
# clearPackageAttributes
#------------------------------------------
sub clearPackageAttributes {
	my $this = shift;
	$this->{m_rpacks} = undef;
	return;
}

#==========================================
# isArchAllowed
#------------------------------------------
sub isArchAllowed {
	my $this    = shift;
	my $element = shift;
	my $what    = shift;
	my $forarch = $element -> getAttribute ("arch");
	if (($what eq "metapackages") || ($what eq "instpackages")) {
		# /.../
		# arch setup is differently handled
		# in inst-source mode
		# ----
		return $this;
	}
	if (defined $forarch) {
		my @archlst = split (/,/,$forarch);
		my $foundit = 0;
		foreach my $archok (@archlst) {
			if ($archok eq $this->{arch}) {
				$foundit = 1; last;
			}
		}
		if (! $foundit) {
			return;
		}
	}
	return $this;
}

#==========================================
# isDriverUpdateDisk
#------------------------------------------
sub isDriverUpdateDisk {
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	return ref $dud_node;
}

#==========================================
# getInstSourceDUDTargets
#------------------------------------------
sub getInstSourceDUDTargets {
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	my %targets = ();
	foreach my $target ($dud_node->getElementsByTagName('target')) {
		$targets{$target->textContent()} = $target->getAttribute("arch");
	}
	return %targets;
}

#==========================================
# getInstSourceDUDConfig
#------------------------------------------
sub getInstSourceDUDConfig {
	my $this = shift;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	my @config = $dud_node->getElementsByTagName('config');
	my %data;
	foreach my $cfg (@config) {
		$data{$cfg->getAttribute("key")} = $cfg->getAttribute("value");
	}
	return \%data;
}

#==========================================
# getInstSourceDUDModules
#------------------------------------------
sub getInstSourceDUDModules {
	my $this = shift;
	return $this->getInstSourceDUDPackList('modules');
}

#==========================================
# getInstSourceDUDInstall
#------------------------------------------
sub getInstSourceDUDInstall {
	my $this = shift;
	return $this->getInstSourceDUDPackList('install');
}

#==========================================
# getInstSourceDUDInstsys
#------------------------------------------
sub getInstSourceDUDInstsys {
	my $this = shift;
	return $this->getInstSourceDUDPackList('instsys');
}

#==========================================
# getInstSourceDUDPackList
#------------------------------------------
sub getInstSourceDUDPackList {
	my $this = shift;
	my $what = shift;
	return unless $what;
	my $base = $this->{instsrcNodeList} -> get_node(1);
	my $dud_node = $base->getElementsByTagName("driverupdate")->get_node(1);
	my $modules_node = $dud_node->getElementsByTagName($what)->get_node(1);
	my @module_packs = $modules_node->getElementsByTagName('repopackage');
	my @modules;
	foreach my $mod (@module_packs) {
		push @modules, $mod->getAttribute("name");
	}
	return @modules;
}

#==========================================
# getInstallSize
#------------------------------------------
sub getInstallSize {
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $nodes   = $this->{packageNodeList};
	my $manager = $this->getPackageManager_legacy();
	my $urllist = $this -> getURLList();
	my @result  = ();
	my @delete  = ();
	my @packages= ();
	my %meta    = ();
	my $solf    = undef;
	my @solp    = ();
	my @rpat    = ();
	my $ptype;
	#==========================================
	# Handle package names to be included
	#------------------------------------------
	@packages = $this -> getBaseList_legacy();
	push @result,@packages;
	@packages = $this -> getInstallList_legacy();
	push @result,@packages;
	@packages = $this -> getTypeSpecificPackageList_legacy();
	push @result,@packages;
	#==========================================
	# Handle package names to be deleted later
	#------------------------------------------
	@delete = $this -> getDeleteList_legacy();
	#==========================================
	# Handle pattern names
	#------------------------------------------
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		my @pattlist = ();
		my @slist = $node -> getElementsByTagName ("opensusePattern");
		foreach my $element (@slist) {
			if (! $this -> isArchAllowed ($element,"packages")) {
				next;
			}
			my $pattern = $element -> getAttribute ("name");
			if ($pattern) {
				push @result,"pattern:".$pattern;
			}
		}
	}
	#==========================================
	# Add packagemanager in any case
	#------------------------------------------
	push @result, $manager;
	#==========================================
	# Run the solver...
	#------------------------------------------
	if (($manager) && ($manager eq "ensconce")) {
		my $list = qxx ("ensconce -d");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> error (
				"Error retrieving package metadata from ensconce."
			);
			return;
		}
		# Violates Expression form of "eval" FIXME
		%meta = eval($list); ## no critic
		@solp = keys(%meta);
		# Ensconce reports package sizes in bytes, fix that
		foreach my $pkg (keys(%meta)) {
			$meta{$pkg} =~ s#^(\d+)#int($1/1024)#e;
		}
	} else {
		my $psolve = KIWISatSolver -> new (
			$kiwi,\@result,$urllist,"solve-patterns",
			undef,undef,$ptype
		);
		if (! defined $psolve) {
			$kiwi -> error ("SaT solver setup failed");
			return;
		}
		if ($psolve -> getProblemsCount()) {
			$kiwi -> error ("SaT solver problems found !\n");
			return;
		}
		if (@{$psolve -> getFailedJobs()}) {
			$kiwi -> error ("SaT solver failed jobs found !");
			return;
		}
		%meta = $psolve -> getMetaData();
		$solf = $psolve -> getSolfile();
		@solp = $psolve -> getPackages();
		@rpat = qxx (
			"dumpsolv $solf|grep 'solvable:name: pattern:'|cut -f4 -d :"
		);
		chomp @rpat;
	}
	return (\%meta,\@delete,$solf,\@result,\@solp,\@rpat);
}

#==========================================
# getReplacePackageDelList
#------------------------------------------
sub getReplacePackageDelList {
	# ...
	# return the package names which are deleted in
	# a replace list setup
	# ---
	my $this = shift;
	my @pacs;
	if ($this->{replDelList}) {
		@pacs = @{$this->{replDelList}};
	}
	return @pacs;
}

#==========================================
# getReplacePackageAddList
#------------------------------------------
sub getReplacePackageAddList {
	# ...
	# return the package names which are added in
	# a replace list setup
	# ---
	my $this = shift;
	my @pacs;
	if ($this->{replAddList}) {
		@pacs = @{$this->{replAddList}};
	}
	return @pacs;
}

#==========================================
# getInstSourceMetaPackageList
#------------------------------------------
sub getInstSourceMetaPackageList {
	# ...
	# Create base package list of the instsource
	# metadata package description
	# ---
	my $this = shift;
	my @list = getList_legacy ($this,"metapackages");
	my %data = ();
	foreach my $pack (@list) {
		my $attr = $this -> getInstSourcePackageAttributes (
			"metapackages",$pack
		);
		$data{$pack} = $attr;
	}
	return %data;
}

#==========================================
# getInstSourcePackageList
#------------------------------------------
sub getInstSourcePackageList {
	# ...
	# Create base package list of the instsource
	# packages package description
	# ---
	my $this = shift;
	my @list = getList_legacy ($this,"instpackages");
	my %data = ();
	foreach my $pack (@list) {
		my $attr = $this -> getInstSourcePackageAttributes (
			"instpackages",$pack
		);
		$data{$pack} = $attr;
	}
	return %data;
}

#==========================================
# getTestingList
#------------------------------------------
sub getTestingList {
	# ...
	# Create package list with packages used for testing
	# the image integrity. The packages here are installed
	# temporary as long as the testsuite runs. After the
	# test runs they should be removed again
	# ---
	my $this = shift;
	return getList_legacy ($this,"testsuite");
}

#==========================================
# getArch
#------------------------------------------
sub getArch {
	# ...
	# Return the architecture currently used for data selection
	# ---
	my $this = shift;
	return $this->{arch};
}

#==========================================
# getStripNodeList
#------------------------------------------
sub getStripNodeList {
	# ...
	# Return a list of all <strip> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{stripNodeList};
}

#==========================================
# getInstSourceFile
#------------------------------------------
sub getInstSourceFile {
	# ...
	# download a file from a network or local location to
	# a given local path. It's possible to use regular expressions
	# in the source file specification
	# ---
	my $this    = shift;
	my $url     = shift;
	my $dest    = shift;
	my $dirname;
	my $basename;
	#==========================================
	# Check parameters
	#------------------------------------------
	if ((! defined $dest) || (! defined $url)) {
		return;
	}
	#==========================================
	# setup destination base and dir name
	#------------------------------------------
	if ($dest =~ /(^.*\/)(.*)/) {
		$dirname  = $1;
		$basename = $2;
		if (! $basename) {
			$url =~ /(^.*\/)(.*)/;
			$basename = $2;
		}
	} else {
		return;
	}
	#==========================================
	# check base and dir name
	#------------------------------------------
	if (! $basename) {
		return;
	}
	if (! -d $dirname) {
		return;
	}
	#==========================================
	# download file
	#------------------------------------------
	if ($url !~ /:\/\//) {
		# /.../
		# local files, make them a file:// url
		# ----
		$url = "file://".$url;
		$url =~ s{/{3,}}{//};
	}
	if ($url =~ /dir:\/\//) {
		# /.../
		# dir url, make them a file:// url
		# ----
		$url =~ s/^dir/file/;
	}
	# /.../
	# use lwp-download to manage the process.
	# if first download failed check the directory list with
	# a regular expression to find the file. After that repeat
	# the download
	# ----
	$dest = $dirname."/".$basename;
	my $data = qxx ("lwp-download $url $dest 2>&1");
	my $code = $? >> 8;
	if ($code == 0) {
		return $this;
	}
	if ($url =~ /(^.*\/)(.*)/) {
		my $location = $1;
		my $search   = $2;
		my $browser  = LWP::UserAgent -> new;
		my $request  = HTTP::Request  -> new (GET => $location);
		my $response;
		eval {
			$response = $browser  -> request ( $request );
		};
		if ($@) {
			return;
		}
		my $content  = $response -> content ();
		my @lines    = split (/\n/,$content);
		foreach my $line(@lines) {
			if ($line !~ /href=\"(.*)\"/) {
				next;
			}
			my $link = $1;
			if ($link =~ /$search/) {
				$url  = $location.$link;
				$data = qxx ("lwp-download $url $dest 2>&1");
				$code = $? >> 8;
				if ($code == 0) {
					return $this;
				}
			}
		}
		return;
	} else {
		return;
	}
	return $this;
}

#==========================================
# getInstSourceSatSolvable
#------------------------------------------
sub getInstSourceSatSolvable {
	# /.../
	# This function will return a hash containing the
	# solvable and repo url per repo
	# ----
	my $kiwi  = shift;
	my $repos = shift;
	my %index = ();
	#==========================================
	# create solvable/repo index
	#------------------------------------------
	foreach my $repo (@{$repos}) {
		my $solvable = getSingleInstSourceSatSolvable ($kiwi,$repo);
		if (! $solvable) {
			return;
		}
		# /.../
		# satsolver / or the perl binding truncates the name if
		# there is a ':' sign. No clue why so we replace : with
		# a space and replace it back in the KIWIXMLInfo module
		# when the information is printed on the screen
		# ----
		$repo =~ s/:/ /g;
		$index{$solvable} = $repo;
	}
	return \%index;
}

#==========================================
# getSingleInstSourceSatSolvable
#------------------------------------------
sub getSingleInstSourceSatSolvable {
	# /.../
	# This function will return an uncompressed solvable record
	# for the given URL. If it's required to create
	# this solvable because it doesn't exist on the repository
	# the satsolver toolkit is used and therefore required in
	# order to allow this function to work correctly
	# ----
	my $kiwi = shift;
	my $repo = shift;
	$kiwi -> info ("--> Loading $repo...");
	#==========================================
	# one of the following for repo metadata
	#------------------------------------------
	my %repoxml;
	$repoxml{"/suse/repodata/repomd.xml"} = "repoxml";
	$repoxml{"/repodata/repomd.xml"}      = "repoxml";
	#==========================================
	# one of the following for a base solvable
	#------------------------------------------
	my %distro;
	$distro{"/suse/setup/descr/packages.gz"} = "packages";
	$distro{"/suse/setup/descr/packages"}    = "packages";
	$distro{"/suse/repodata/primary.xml.gz"} = "distxml";
	$distro{"/repodata/primary.xml.gz"}      = "distxml";
	#==========================================
	# all existing pattern files
	#------------------------------------------
	my %patterns;
	$patterns{"/suse/setup/descr/patterns"} = "patterns";
	$patterns{"/repodata/patterns.xml.gz"}  = "projectxml";
	#==========================================
	# common data variables
	#------------------------------------------
	my $arch     = qxx ("uname -m"); chomp $arch;
	my $count    = 0;
	my $index    = 0;
	my @index    = ();
	my $error    = 0;
	#==========================================
	# allow arch overwrite
	#------------------------------------------
	if ($ENV{KIWI_REPO_INFO_ARCH}) {
		$arch = $ENV{KIWI_REPO_INFO_ARCH};
	}
	#==========================================
	# check for sat tools
	#------------------------------------------
	if ((! -x "/usr/bin/mergesolv") ||
		(! -x "/usr/bin/susetags2solv") ||
		(! -x "/usr/bin/rpmmd2solv") ||
		(! -x "/usr/bin/rpms2solv")
	) {
		$kiwi -> failed ();
		$kiwi -> error  ("--> Can't find satsolver tools");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# check/create cache directory
	#------------------------------------------
	my $sdir = "/var/cache/kiwi/satsolver";
	if (! -d $sdir) {
		my $data = qxx ("mkdir -p $sdir 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("--> Couldn't create cache dir: $data");
			$kiwi -> failed ();
			return;
		}
	}
	#==========================================
	# check/create solvable index file
	#------------------------------------------
	push (@index,$repo);
	push (@index,$arch);
	@index = sort (@index);
	$index = join (":",@index);
	$index = qxx ("echo $index | md5sum | cut -f1 -d-");
	$index = $sdir."/".$index; chomp $index;
	$index=~ s/ +$//;
	if ((-f $index) && (! -f "$index.timestamp")) {
		$kiwi -> done();
		return $index;
	}
	#==========================================
	# find system architecture
	#------------------------------------------
	if ($arch =~ /^i.86/) {
		$arch = 'i.86';
	}
	my $destfile;
	my $scommand;
	#==========================================
	# download repo XML metadata
	#------------------------------------------
	my $repoMD = $sdir."/repomd.xml"; unlink $repoMD;
	foreach my $md (keys %repoxml) {
		if (KIWIXML::getInstSourceFile ($kiwi,$repo.$md,$repoMD)) {
			last if -e $repoMD;
		}
	}
	if (-e $repoMD) {
		my $RXML = FileHandle -> new();
		if (! $RXML -> open ("cat $repoMD|")) {
			$kiwi -> failed ();
			$kiwi -> error ("--> Failed to open file $repoMD");
			$kiwi -> failed ();
			unlink $repoMD;
			return;
		}
		binmode $RXML;
		my $rxml = XML::LibXML -> new();
		my $tree = $rxml -> parse_fh ( $RXML );
		my $nodes= $tree -> getElementsByTagName ("data");
		my $primary;
		my $pattern;
		my $time;
		for (my $i=1;$i<= $nodes->size();$i++) {
			my $node = $nodes-> get_node($i);
			my $type = $node -> getAttribute ("type");
			if ($type eq "primary") {
				$primary = $node -> getElementsByTagName ("location")
					-> get_node(1) -> getAttribute ("href");
				$time = $node -> getElementsByTagName ("timestamp")
					-> get_node(1) -> string_value();
			}
			if ($type eq "patterns") {
				$pattern = $node -> getElementsByTagName ("location")
					-> get_node(1) -> getAttribute ("href");
			}
		}
		$RXML -> close();
		#==========================================
		# Compare the repo timestamp
		#------------------------------------------
		my $TFD = FileHandle -> new();
		if ($TFD -> open ("$index.timestamp")) {
			my $curstamp = <$TFD>; chomp $curstamp; $TFD -> close();
			if ($curstamp eq $time) {
				$kiwi -> done();
				unlink $repoMD;
				return $index;
			}
		}
		#==========================================
		# Store distro/pattern path
		#------------------------------------------
		my %newdistro   = ();
		my %newpatterns = ();
		if ($primary) {
			foreach my $key (keys %distro) {
				if ($distro{$key} ne "distxml") {
					$newdistro{$key} = $distro{$key};
				}
			}
			$newdistro{"/".$primary}      = "distxml";
			$newdistro{"/suse/".$primary} = "distxml";
		}
		if ($pattern) {
			foreach my $key (keys %patterns) {
				if ($patterns{$key} ne "projectxml") {
					$newpatterns{$key} = $patterns{$key};
				}
			}
			$newpatterns{"/".$pattern} = "projectxml";
		}
		if (%newdistro) {
			undef %distro;
			%distro = %newdistro;
		}
		if (%newpatterns) {
			undef %patterns;
			%patterns = %newpatterns;
		}
		#==========================================
		# Store new time stamp
		#------------------------------------------
		if (! open ($RXML, '>', "$index.timestamp")) {
			$kiwi -> failed ();
			$kiwi -> error ("--> Failed to create timestamp: $!");
			$kiwi -> failed ();
			unlink $repoMD;
			return;
		}
		print $RXML $time;
		close $RXML;
	}
	#==========================================
	# create repo info file
	#------------------------------------------
	if (open (my $FD, '>', "$index.info")) {
		print $FD $repo."\n";
		close $FD;
	}
	#==========================================
	# download distro solvable(s)
	#------------------------------------------
	my $foundDist = 0;
	$count++;
	foreach my $dist (keys %distro) {
		my $name = $distro{$dist};
		if ($dist =~ /\.gz$/) {
			$destfile = $sdir."/$name-".$count.".gz";
		} else {
			$destfile = $sdir."/$name-".$count;
		}
		if (KIWIXML::getInstSourceFile ($kiwi,$repo.$dist,$destfile)) {
			$foundDist = 1;
		}
	}
	if (! $foundDist) {
		my $path = $repo; $path =~ s/dir:\/\///;
		my $data = qxx ("rpms2solv $path/*.rpm > $sdir/primary-$count 2>&1");
		my $code = $? >> 8;
		if ($code != 0) {
			$kiwi -> failed ();
			$kiwi -> error  ("--> Can't find/create a distribution solvable");
			$kiwi -> failed ();
			return;
		}
		$foundDist = 1;
	}
	#==========================================
	# download pattern solvable(s)
	#------------------------------------------
	$count++;
	foreach my $patt (keys %patterns) {
		my $name = $patterns{$patt};
		$destfile = $sdir."/$name-".$count.".gz";
		my $ok = KIWIXML::getInstSourceFile ($kiwi,$repo.$patt,$destfile);
		if (($ok) && ($name eq "patterns")) {
			#==========================================
			# get files listed in patterns
			#------------------------------------------
			my $FD = FileHandle -> new();
			my $patfile = $destfile;
			if (! $FD -> open ($patfile)) {
				$kiwi -> warning ("--> Couldn't open patterns file: $!");
				$kiwi -> skipped ();
				unlink $patfile;
				next;
			}
			while (my $line = <$FD>) {
				chomp $line; $destfile = $sdir."/".$line;
				if ($line !~ /\.$arch\./) {
					next;
				}
				my $base = dirname $patt;
				my $file = $repo."/".$base."/".$line;
				if (! KIWIXML::getInstSourceFile($kiwi,$file,$destfile)) {
					$kiwi -> warning ("--> Pattern file $line not found");
					$kiwi -> skipped ();
					next;
				}
			}
			$FD -> close();
			unlink $patfile;
		}
	}
	$count++;
	#==========================================
	# create solvable from opensuse dist pat
	#------------------------------------------
	if (glob ("$sdir/distxml-*.gz")) {
		foreach my $file (glob ("$sdir/distxml-*.gz")) {
			$destfile = $sdir."/primary-".$count;
			my $data = qxx ("gzip -cd $file | rpmmd2solv > $destfile 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Can't create SaT solvable file");
				$kiwi -> failed ();
				$error = 1;
			}
			$count++;
		}
	}
	$count++;
	#==========================================
	# create solvable from suse tags data
	#------------------------------------------
	if (glob ("$sdir/packages-*")) {
		my $gzicmd = "gzip -cd ";
		my $stdcmd = "cat ";
		my @done   = ();
		$scommand = "";
		$destfile = $sdir."/primary-".$count;
		foreach my $file (glob ("$sdir/packages-*")) {
			if ($file =~ /\.gz$/) {
				$gzicmd .= $file." ";
			} else {
				$stdcmd .= $file." ";
			}
		}
		foreach my $file (glob ("$sdir/*.pat*")) {
			if ($file =~ /\.gz$/) {
				$gzicmd .= $file." ";
			} else {
				$stdcmd .= $file." ";
			}
		}
		if ($gzicmd ne "gzip -cd ") {
			push @done,$gzicmd;
		}
		if ($stdcmd ne "cat ") {
			push @done,$stdcmd;
		}
		foreach my $cmd (@done) {
			my $data = qxx ("$cmd | susetags2solv >> $destfile 2>/dev/null");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Can't create SaT solvable file");
				$kiwi -> failed ();
				$error = 1;
				last;
			}
		}
	}
	$count++;
	#==========================================
	# create solvable from opensuse xml pattern
	#------------------------------------------
	if (glob ("$sdir/projectxml-*.gz")) {
		foreach my $file (glob ("$sdir/projectxml-*.gz")) {
			$destfile = $sdir."/primary-".$count;
			my $data = qxx ("gzip -cd $file | rpmmd2solv > $destfile 2>&1");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Can't create SaT solvable file");
				$kiwi -> failed ();
				$error = 1;
			}
			$count++;
		}
	}
	#==========================================
	# merge all solvables into one
	#------------------------------------------
	if (! $error) {
		if (! glob ("$sdir/primary-*")) {
			$kiwi -> error  ("--> Couldn't find any SaT solvable file(s)");
			$kiwi -> failed ();
			$error = 1;
		} else {
			my $data = qxx ("mergesolv $sdir/primary-* > $index");
			my $code = $? >> 8;
			if ($code != 0) {
				$kiwi -> failed ();
				$kiwi -> error  ("--> Couldn't merge solve files");
				$kiwi -> failed ();
				$error = 1;
			}
		}
	}
	#==========================================
	# cleanup cache dir
	#------------------------------------------
	qxx ("rm -f $sdir/repomd.xml");
	qxx ("rm -f $sdir/primary-*");
	qxx ("rm -f $sdir/projectxml-*");
	qxx ("rm -f $sdir/distxml-*");
	qxx ("rm -f $sdir/packages-*");
	qxx ("rm -f $sdir/*.pat*");
	if (! $error) {
		$kiwi -> done();
		return $index;
	}
	return;
}

#==========================================
# Methods using the "old" data structure that are to be
# eliminated or replaced
#------------------------------------------
#==========================================
# addArchives_legacy
#------------------------------------------
sub addArchives_legacy {
	# ...
	# Add the given archive list to the specified packages
	# type section of the xml description parse tree as an.
	# archive element
	# ----
	my @tars  = @_;
	my $this  = shift @tars;
	my $ptype = shift @tars;
	my $bincl = shift @tars;
	my $nodes = shift @tars;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i; last;
		}
	}
	foreach my $tar (@tars) {
		my $addElement = XML::LibXML::Element -> new ("archive");
		$addElement -> setAttribute("name",$tar);
		if ($bincl) {
			$addElement -> setAttribute("bootinclude","true");
		}
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addDrivers_legacy
#------------------------------------------
sub addDrivers_legacy {
	# ...
	# Add the given driver list to the specified drivers
	# section of the xml description parse tree.
	# ----
	my @drvs  = @_;
	my $this  = shift @drvs;
	my $kiwi  = $this->{kiwi};
	my $nodes = $this->{driversNodeList};
	my $nodeNumber = -1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		$nodeNumber = $i;
	}
	if ($nodeNumber < 0) {
		$kiwi -> loginfo ("addDrivers: no drivers section found... skipped\n");
		return $this;
	}
	foreach my $driver (@drvs) {
		next if ($driver eq "");
		my $addElement = XML::LibXML::Element -> new ("file");
		$addElement -> setAttribute("name",$driver);
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addImagePackages_legacy
#------------------------------------------
sub addImagePackages_legacy {
	# ...
	# Add the given package list to the type=bootstrap packages
	# section of the xml description parse tree.
	# ----
	my @list = @_;
	my $this = shift @list;
	return $this -> addPackages_legacy ("image",undef,undef,@list);
}

#==========================================
# addImagePatterns_legacy
#------------------------------------------
sub addImagePatterns_legacy {
	# ...
	# Add the given pattern list to the type=bootstrap packages
	# section of the xml description parse tree.
	# ----
	my @list = @_;
	my $this = shift @list;
	return $this -> addPatterns_legacy("image",undef,@list);
}

#==========================================
# addPackages_legacy
#------------------------------------------
sub addPackages_legacy {
	# ...
	# Add the given package list to the specified packages
	# type section of the xml description parse tree.
	# ----
	my @packs = @_;
	my $this  = shift @packs;
	my $ptype = shift @packs;
	my $bincl = shift @packs;
	my $nodes = shift @packs;
	my $kiwi  = $this->{kiwi};
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = -1;
	my $nodeNumberBootStrap = -1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if ($type eq "bootstrap") {
			$nodeNumberBootStrap = $i;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i;
		}
	}
	if ($nodeNumberBootStrap < 0) {
		$kiwi -> warning (
			"Failed to add @packs, package(s), no bootstrap section found"
		);
		$kiwi -> skipped ();
		return $this;
	}
	if (($nodeNumber < 0) && ($ptype eq "image")) {
		$kiwi -> warning (
			"addPackages: no image section found, adding to bootstrap"
		);
		$kiwi -> done();
		$nodeNumber = $nodeNumberBootStrap;
	}
	if ($nodeNumber < 0) {
		$kiwi -> loginfo ("addPackages: no $ptype section found... skipped\n");
		return $this;
	}
	my $addToNode = $nodes -> get_node($nodeNumber);
	my @packnodes = $addToNode -> getElementsByTagName ("package");
	my %packhash  = ();
	foreach my $element (@packnodes) {
		my $package = $element -> getAttribute ("name");
		$packhash{$package} = $package;
	}
	foreach my $pack (@packs) {
		next if ($pack eq "");
		next if ($packhash{$pack});
		my $addElement = XML::LibXML::Element -> new ("package");
		$addElement -> setAttribute("name",$pack);
		if (($bincl) && ($bincl->{$pack}) && ($bincl->{$pack} == 1)) {
			$addElement -> setAttribute("bootinclude","true");
		}
		$addToNode -> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# addPatterns_legacy
#------------------------------------------
sub addPatterns_legacy {
	# ...
	# Add the given pattern list to the specified packages
	# type section of the xml description parse tree.
	# ----
	my @patts = @_;
	my $this  = shift @patts;
	my $ptype = shift @patts;
	my $nodes = shift @patts;
	if (! defined $nodes) {
		$nodes = $this->{packageNodeList};
	}
	my $nodeNumber = 1;
	for (my $i=1;$i<= $nodes->size();$i++) {
		my $node = $nodes -> get_node($i);
		my $type = $node  -> getAttribute ("type");
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		if ($type eq $ptype) {
			$nodeNumber = $i; last;
		}
	}
	foreach my $pack (@patts) {
		my $addElement = XML::LibXML::Element -> new ("opensusePattern");
		$addElement -> setAttribute("name",$pack);
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# getArchiveList_legacy
#------------------------------------------
sub getArchiveList_legacy {
	# ...
	# Create list of <archive> elements. These names
	# references tarballs which must exist in the image
	# description directory
	# ---
	my $this = shift;
	my @bootarchives = getList_legacy ($this,"bootstrap","archive");
	my @imagearchive = getList_legacy ($this,"image","archive");
	return (@bootarchives,@imagearchive);
}

#==========================================
# getBaseList_legacy
#------------------------------------------
sub getBaseList_legacy {
	# ...
	# Create base package list needed to start creating
	# the physical extend. The packages in this list are
	# installed manually
	# ---
	my $this = shift;
	return getList_legacy ($this,"bootstrap");
}

#==========================================
# getBootIncludes_legacy
#------------------------------------------
sub getBootIncludes_legacy {
	# ...
	# Collect all items marked as bootinclude="true"
	# and return them in a list of names
	# ----
	my $this = shift;
	my @node = $this->{packageNodeList} -> get_nodelist();
	my @result = ();
	foreach my $element (@node) {
		my $type = $element -> getAttribute ("type");
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		if (($type eq "image") || ($type eq "bootstrap")) {
			my @plist = $element->getElementsByTagName ("package");
			for my $element (@plist) {
				my $pckName = $element -> getAttribute ("name");
				my $bootinc = $element -> getAttribute ("bootinclude");
				if ((defined $bootinc) && ("$bootinc" eq "true")) {
					push (@result, $pckName);
				}
			}
		}
	}
	return @result;
}

#==========================================
# getBootTheme_legacy
#------------------------------------------
sub getBootTheme_legacy {
	# ...
	# Obtain the theme values for splash and bootloader
	# ---
	my $this   = shift;
	my $snode  = $this -> __getPreferencesNodeByTagName ("bootsplash-theme");
	my $lnode  = $this -> __getPreferencesNodeByTagName ("bootloader-theme");
	my $splash = $snode -> getElementsByTagName ("bootsplash-theme");
	my $loader = $lnode -> getElementsByTagName ("bootloader-theme");
	my @result = (
		"openSUSE","openSUSE"
	);
	if ((defined $splash) || ("$splash" ne "")) {
		$result[0] = $splash;
	}
	if ((defined $loader) || ("$loader" ne "")) {
		$result[1] = $loader;
	}
	return @result;
}

#==========================================
# getDefaultPrebuiltDir_legacy
#------------------------------------------
sub getDefaultPrebuiltDir_legacy {
	# ...
	# Return the path of the default location for pre-built boot images
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ('defaultprebuilt');
	my $imgDir = $node -> getElementsByTagName ('defaultprebuilt');
	return $imgDir;
}

#==========================================
# getDeleteList_legacy
#------------------------------------------
sub getDeleteList_legacy {
	# ...
	# Create delete package list which are packages
	# which have already been installed but could be
	# forced for deletion in images.sh. The KIWIConfig.sh
	# module provides a function to get the contents of
	# this list. KIWI will store the delete list as
	# .profile variable
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @inc  = $this -> getBootIncludes_legacy();
	my @del  = $this -> getList_legacy ("delete");
	my @ret  = ();
	#==========================================
	# check delete list for conflicts
	#------------------------------------------
	foreach my $del (@del) {
		my $found = 0;
		foreach my $include (@inc) {
			if ($include eq $del) {
				$kiwi -> loginfo (
					"WARNING: package $del also found in install list\n"
				);
				$kiwi -> loginfo (
					"WARNING: package $del ignored in delete list\n"
				);
				$found = 1;
				last;
			}
		}
		next if $found;
		push @ret,$del;
	}
	return @ret;
}

#==========================================
# getEc2Config_legacy
#------------------------------------------
sub getEc2Config_legacy {
	# ...
	# Create a hash for the <ec2config>
	# section if it exists
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("ec2config") -> get_node(1);
	my %result = ();
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# AWS account Nr
	#------------------------------------------
	my $awsacctno = $node -> getElementsByTagName ("ec2accountnr");
	if ($awsacctno) {
		$result{AWSAccountNr} = $awsacctno;
	}
	#==========================================
	# EC2 path to public key file
	#------------------------------------------
	my $certfile = $node -> getElementsByTagName ("ec2certfile");
	if ($certfile) {
		$result{EC2CertFile} = $certfile;
	}
	#==========================================
	# EC2 path to private key file
	#------------------------------------------
	my $privkeyfile = $node -> getElementsByTagName ("ec2privatekeyfile");
	if ($privkeyfile) {
		$result{EC2PrivateKeyFile} = $privkeyfile;
	}
	#==========================================
	# EC2 region
	#------------------------------------------
	my @regionNodes = $node -> getElementsByTagName ("ec2region");
	my @regions = ();
	for my $regNode (@regionNodes) {
		push @regions, $regNode -> textContent();
	}
	$result{EC2Regions} = \@regions;
	return %result;
}

#==========================================
# getEditBootConfig_legacy
#------------------------------------------
sub getEditBootConfig_legacy {
	# ...
	# Get the type specific editbootconfig value.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $editBoot = $tnode -> getAttribute ("editbootconfig");
	if ((! defined $editBoot) || ("$editBoot" eq "")) {
		return;
	}
	return $editBoot;
}

#==========================================
# getEditBootInstall_legacy
#------------------------------------------
sub getEditBootInstall_legacy {
	# ...
	# Get the type specific editbootinstall value.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $editBoot = $tnode -> getAttribute ("editbootinstall");
	if ((! defined $editBoot) || ("$editBoot" eq "")) {
		return;
	}
	return $editBoot;
}

#==========================================
# getHttpsRepositoryCredentials_legacy
#------------------------------------------
sub getHttpsRepositoryCredentials_legacy {
	# ...
	# If any repository is configered with credentials return the username
	# and password
	# ---
	my $this = shift;
	my @repoNodes = $this->{repositNodeList} -> get_nodelist();
	for my $repo (@repoNodes) {
		my $uname = $repo -> getAttribute('username');
		my $pass = $repo -> getAttribute('password');
		if ($uname) {
			my @sources = $repo -> getElementsByTagName ('source');
			my $path = $sources[0] -> getAttribute('path');
			if ( $path =~ /^https:/) {
				return ($uname, $pass);
			}
		}
	}
	return;
}

#==========================================
# getImageConfig_legacy
#------------------------------------------
sub getImageConfig_legacy {
	# ...
	# Evaluate the attributes of the drivers and preferences tags and
	# build a hash containing all the image parameters. This information
	# is used to create the .profile environment
	# ---
	my $this = shift;
	my %result;
	my @nodelist;
	#==========================================
	# revision information
	#------------------------------------------
	my $rev  = "unknown";
	if (open (my $FD, '<', $this->{gdata}->{Revision})) {
		$rev = <$FD>; close $FD;
		$rev =~ s/\n//g;
	}
	$result{kiwi_revision} = $rev;
	#==========================================
	# bootincluded items (packs,archives)
	#------------------------------------------
	my @bincl = $this -> getBootIncludes_legacy();
	if (@bincl) {
		$result{kiwi_fixedpackbootincludes} = join(" ",@bincl);
	}
	#==========================================
	# preferences attributes and text elements
	#------------------------------------------
	my %type  = %{$this->getImageTypeAndAttributes_legacy()};
	my @delp  = $this -> getDeleteList_legacy();
	my $iver  = $this -> getImageVersion();
	my $size  = $this -> getImageSize();
	my $name  = $this -> getImageName();
	my $dname = $this -> getImageDisplayName ($this);
	my $lics  = $this -> getLicenseNames_legacy();
	my @s_del = $this -> getStripDelete();
	my @s_tool= $this -> getStripTools();
	my @s_lib = $this -> getStripLibs();
	my @tstp  = $this -> getTestingList();
	if ($lics) {
		$result{kiwi_showlicense} = join(" ",@{$lics});
	}
	if (@delp) {
		$result{kiwi_delete} = join(" ",@delp);
	}
	if (@s_del) {
		$result{kiwi_strip_delete} = join(" ",@s_del);
	}
	if (@s_tool) {
		$result{kiwi_strip_tools} = join(" ",@s_tool);
	}
	if (@s_lib) {
		$result{kiwi_strip_libs} = join(" ",@s_lib);
	}
	if (@tstp) {
		$result{kiwi_testing} = join(" ",@tstp);
	}
	if ((%type)
		&& (defined $type{compressed})
		&& ($type{compressed} eq "true")) {
		$result{kiwi_compressed} = "yes";
	}
	if (%type) {
		$result{kiwi_type} = $type{type};
	}
	if ((%type) && ($type{cmdline})) {
		$result{kiwi_cmdline} = $type{cmdline};
	}
	if ((%type) && ($type{bootloader})) {
		$result{kiwi_bootloader} = $type{bootloader};
	}
	if ((%type) && ($type{devicepersistency})) {
		$result{kiwi_devicepersistency} = $type{devicepersistency};
	}
	if ((%type) && (defined $type{boottimeout})) {
		$result{KIWI_BOOT_TIMEOUT} = $type{boottimeout};
	}
	if ((%type) && ($type{installboot})) {
		$result{kiwi_installboot} = $type{installboot};
	}
	if ((%type) && ($type{fsmountoptions})) {
		$result{kiwi_fsmountoptions} = $type{fsmountoptions};
	}
	if ((%type)
		&& (defined $type{luks})
		&& ($type{luks} eq "true")) {
		$result{kiwi_luks} = "yes";
	}
	if ((%type)
		&& (defined $type{hybrid})
		&& ($type{hybrid} eq "true")) {
		$result{kiwi_hybrid} = "yes";
	}
	if ((%type)
		&& (defined $type{hybridpersistent})
		&& ($type{hybridpersistent} eq "true")) {
		$result{kiwi_hybridpersistent} = "yes";
	}
	if ((%type)
		&& (defined $type{ramonly})
		&& ($type{ramonly} eq "true")) {
		$result{kiwi_ramonly} = "yes";
	}
	if ((%type) && ($type{lvm})) {
		$result{kiwi_lvm} = $type{lvm};
	}
	if ($size) {
		$result{kiwi_size} = $size;
	}
	if ($name) {
		$result{kiwi_iname} = $name;
		if ($type{type} eq "cpio") {
			$result{kiwi_cpio_name} = $name;
		}
	}
	if ($dname) {
		$result{kiwi_displayname} = quotemeta $dname;
	}
	if ($iver) {
		$result{kiwi_iversion} = $iver;
	}
	@nodelist = $this->{optionsNodeList} -> get_nodelist();
	foreach my $element (@nodelist) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $keytable    = $element -> getElementsByTagName ("keytable");
		my $timezone    = $element -> getElementsByTagName ("timezone");
		my $hwclock     = $element -> getElementsByTagName ("hwclock");
		my $language    = $element -> getElementsByTagName ("locale");
		my $splashtheme = $element -> getElementsByTagName ("bootsplash-theme");
		my $loadertheme = $element -> getElementsByTagName ("bootloader-theme");
		if ((defined $keytable) && ("$keytable" ne "")) {
			$result{kiwi_keytable} = $keytable;
		}
		if ((defined $timezone) && ("$timezone" ne "")) {
			$result{kiwi_timezone} = $timezone;
		}
		if ((defined $hwclock) && ("$hwclock" ne "")) {
			$result{kiwi_hwclock} = $hwclock;
		}
		if ((defined $language) && ("$language" ne "")) {
			$result{kiwi_language} = $language;
		}
		if ((defined $splashtheme) && ("$splashtheme" ne "")) {
			$result{kiwi_splash_theme}= $splashtheme;
		}
		if ((defined $loadertheme) && ("$loadertheme" ne "")) {
			$result{kiwi_loader_theme}= $loadertheme;
		}
	}
	#==========================================
	# drivers
	#------------------------------------------
	@nodelist = $this->{driversNodeList} -> get_nodelist();
	foreach my $element (@nodelist) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my @ntag = $element -> getElementsByTagName ("file");
		my $type = "kiwi_drivers";
		my $data = "";
		foreach my $element (@ntag) {
			my $name =  $element -> getAttribute ("name");
			$data = $data.",".$name;
		}
		$data =~ s/^,+//;
		if (defined $result{$type}) {
			$result{$type} .= ",".$data;
		} else {
			$result{$type} = $data;
		}
	}
	#==========================================
	# machine
	#------------------------------------------
	my $xendomain;
	my $tnode= $this->{typeNode};
	my $xenNode = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	if ($xenNode) {
		$xendomain = $xenNode -> getAttribute ("domain");
		if (defined $xendomain) {
			$result{kiwi_xendomain} = $xendomain;
		}
	}
	#==========================================
	# systemdisk
	#------------------------------------------
	my %lvmparts = $this -> getLVMVolumes_legacy();
	if (%lvmparts) {
		foreach my $vol (keys %lvmparts) {
			if (! $lvmparts{$vol}) {
				next;
			}
			my $attrname = "size";
			my $attrval  = $lvmparts{$vol}->[0];
			my $absolute = $lvmparts{$vol}->[1];
			if (! $attrval) {
				next;
			}
			if (! $absolute) {
				$attrname = "freespace";
			}
			$vol =~ s/^\///;
			$vol =~ s/\//_/g;
			$vol = "LV".$vol;
			if ("$attrval" eq "all") {
				$result{kiwi_allFreeVolume} = $vol;
			} else {
				$result{"kiwi_LVM_$vol"} = $attrname.":".$attrval;
			}
		}
	}
	#==========================================
	# oemconfig
	#------------------------------------------
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (defined $node) {
		my $oemswapMB= $node
			-> getElementsByTagName ("oem-swapsize");
		my $oemrootMB= $node
			-> getElementsByTagName ("oem-systemsize");
		my $oemswap  = $node
			-> getElementsByTagName ("oem-swap");
		my $oemalign = $node
			-> getElementsByTagName ("oem-align-partition");
		my $oempinst = $node
			-> getElementsByTagName ("oem-partition-install");
		my $oemtitle = $node
			-> getElementsByTagName ("oem-boot-title");
		my $oemkboot = $node
			-> getElementsByTagName ("oem-kiwi-initrd");
		my $oemreboot= $node
			-> getElementsByTagName ("oem-reboot");
		my $oemrebootinter= $node
			-> getElementsByTagName ("oem-reboot-interactive");
		my $oemsilentboot = $node
			-> getElementsByTagName ("oem-silent-boot");
		my $oemshutdown= $node
			-> getElementsByTagName ("oem-shutdown");
		my $oemshutdowninter= $node
			-> getElementsByTagName ("oem-shutdown-interactive");
		my $oemwait  = $node
			-> getElementsByTagName ("oem-bootwait");
		my $oemnomsg = $node
			-> getElementsByTagName ("oem-unattended");
		my $oemdevid = $node
			-> getElementsByTagName ("oem-unattended-id");
		my $oemreco  = $node
			-> getElementsByTagName ("oem-recovery");
		my $oemrecoid= $node
			-> getElementsByTagName ("oem-recoveryID");
		my $inplace  = $node
			-> getElementsByTagName ("oem-inplace-recovery");
		if ((defined $oempinst) && ("$oempinst" eq "true")) {
			$result{kiwi_oempartition_install} = $oempinst;
		}
		if ("$oemswap" ne "false") {
			$result{kiwi_oemswap} = "true";
			if ((defined $oemswapMB) && 
				("$oemswapMB" ne "")   && 
				(int($oemswapMB) > 0)
			) {
				$result{kiwi_oemswapMB} = $oemswapMB;
			}
		}
		if ((defined $oemalign) && ("$oemalign" eq "true")) {
			$result{kiwi_oemalign} = $oemalign;
		}
		if ((defined $oemrootMB) && 
			("$oemrootMB" ne "")   && 
			(int($oemrootMB) > 0)
		) {
			$result{kiwi_oemrootMB} = $oemrootMB;
		}
		if ((defined $oemtitle) && ("$oemtitle" ne "")) {
			$result{kiwi_oemtitle} = $this -> __quote ($oemtitle);
		}
		if ((defined $oemkboot) && ("$oemkboot" ne "")) {
			$result{kiwi_oemkboot} = $oemkboot;
		}
		if ((defined $oemreboot) && ("$oemreboot" eq "true")) {
			$result{kiwi_oemreboot} = $oemreboot;
		}
		if ((defined $oemrebootinter) && ("$oemrebootinter" eq "true")) {
			$result{kiwi_oemrebootinteractive} = $oemrebootinter;
		}
		if ((defined $oemsilentboot) && ("$oemsilentboot" eq "true")) {
			$result{kiwi_oemsilentboot} = $oemsilentboot;
		}
		if ((defined $oemshutdown) && ("$oemshutdown" eq "true")) {
			$result{kiwi_oemshutdown} = $oemshutdown;
		}
		if ((defined $oemshutdowninter) && ("$oemshutdowninter" eq "true")) {
			$result{kiwi_oemshutdowninteractive} = $oemshutdowninter;
		}
		if ((defined $oemwait) && ("$oemwait" eq "true")) {
			$result{kiwi_oembootwait} = $oemwait;
		}
		if ((defined $oemnomsg) && ("$oemnomsg" eq "true")) {
			$result{kiwi_oemunattended} = $oemnomsg;
		}
		if ((defined $oemdevid) && ("$oemdevid" ne "")) {
			$result{kiwi_oemunattended_id} = $oemdevid;
		}
		if ((defined $oemreco) && ("$oemreco" eq "true")) {
			$result{kiwi_oemrecovery} = $oemreco;
		}
		if ((defined $oemrecoid) && ("$oemrecoid" ne "")) {
			$result{kiwi_oemrecoveryID} = $oemrecoid;
		}
		if ((defined $inplace) && ("$inplace" eq "true")) {
			$result{kiwi_oemrecoveryInPlace} = $inplace;
		}
	}
	#==========================================
	# profiles
	#------------------------------------------
	if (defined $this->{reqProfiles}) {
		$result{kiwi_profiles} = join ",", @{$this->{reqProfiles}};
	}
	return %result;
}

#==========================================
# getImageDefaultDestination_legacy
#------------------------------------------
sub getImageDefaultDestination_legacy {
	# ...
	# Get the default destination to store the images below
	# normally this is given by the --destination option but if
	# not and defaultdestination is specified in xml descr. we
	# will use this path as destination
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("defaultdestination");
	my $dest = $node -> getElementsByTagName ("defaultdestination");
	return $dest;
}

#==========================================
# getImageDefaultRoot_legacy
#------------------------------------------
sub getImageDefaultRoot_legacy {
	# ...
	# Get the default root directory name to build up a new image
	# normally this is given by the --root option but if
	# not and defaultroot is specified in xml descr. we
	# will use this path as root path.
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("defaultroot");
	my $root = $node -> getElementsByTagName ("defaultroot");
	return $root;
}

#==========================================
# getImageTypeAndAttributes_legacy
#------------------------------------------
sub getImageTypeAndAttributes_legacy {
	# ...
	# return typeinfo hash for selected build type
	# ---
	my $this     = shift;
	my $typeinfo = $this->{typeInfo};
	my $imageType= $this->{imageType};
	if (! $typeinfo) {
		return;
	}
	if (! $imageType) {
		return;
	}
	return $typeinfo->{$imageType};
}

#==========================================
# getInstallList_legacy
#------------------------------------------
sub getInstallList_legacy {
	# ...
	# Create install package list needed to blow up the
	# physical extend to what the image was designed for
	# ---
	my $this = shift;
	return getList_legacy ($this,"image");
}

#==========================================
# getLicenseNames_legacy
#------------------------------------------
sub getLicenseNames_legacy {
	# ...
	# Get the names of all showlicense elements and return
	# them as a list to the caller
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $node = $this -> __getPreferencesNodeByTagName ("showlicense");
	my @lics = $node -> getElementsByTagName ("showlicense");
	my @names = ();
	foreach my $node (@lics) {
		push (@names,$node -> textContent());
	}
	if (@names) {
		return \@names;
	}
	return;
}

#==========================================
# getList_legacy
#------------------------------------------
sub getList_legacy {
	# ...
	# Create a package list out of the given base xml
	# object list. The xml objects are searched for the
	# attribute "name" to build up the package list.
	# Each entry must be found on the source medium
	# ---
	my $this = shift;
	my $what = shift;
	my $nopac= shift;
	my $kiwi = $this->{kiwi};
	my $urllist = $this -> getURLList();
	my %pattr;
	my $nodes;
	if ($what ne "metapackages") {
		%pattr= $this -> getPackageAttributes_legacy( $what );
	}
	if ($what eq "metapackages") {
		my $base = $this->{instsrcNodeList} -> get_node(1);
		$nodes = $base -> getElementsByTagName ("metadata");
	} elsif ($what eq "instpackages") {
		my $base = $this->{instsrcNodeList} -> get_node(1);
		$nodes = $base -> getElementsByTagName ("repopackages");
	} else {
		$nodes = $this->{packageNodeList};
	}
	my @result;
	my $manager = $this -> getPackageManager_legacy();
	for (my $i=1;$i<= $nodes->size();$i++) {
		#==========================================
		# Get type and packages
		#------------------------------------------
		my $node  = $nodes -> get_node($i);
		my $ptype = $node -> getAttribute ("patternType");
		my $type  = "";
		if (($what ne "metapackages") && ($what ne "instpackages")) {
			$type = $node -> getAttribute ("type");
			if ($type ne $what) {
				next;
			}
		} else {
			$type = $what;
		}
		#============================================
		# Check to see if node is in included profile
		#--------------------------------------------
		if (! $this -> __requestedProfile ($node)) {
			next;
		}
		#==========================================
		# Check for package descriptions
		#------------------------------------------
		my @plist = ();
		if (($what ne "metapackages") && ($what ne "instpackages")) {
			if (defined $nopac) {
				@plist = $node -> getElementsByTagName ("archive");
			} else {
				@plist = $node -> getElementsByTagName ("package");
			}
		} else {
			@plist = $node -> getElementsByTagName ("repopackage");
		}
		foreach my $element (@plist) {
			my $package = $element -> getAttribute ("name");
			my $forarch = $element -> getAttribute ("arch");
			my $replaces= $element -> getAttribute ("replaces");
			if (! $this -> isArchAllowed ($element,$what)) {
				next;
			}
			if (! defined $package) {
				next;
			}
			if ($type ne "metapackages" && $type ne "instpackages") {
				if (($package =~ /@/) && $manager && ($manager eq "zypper")) {
					$package =~ s/@/\./;
				}
			}
			if (defined $replaces) {
				push @result,[$package,$replaces];
			}
			push @result,$package;
		}
		#==========================================
		# Check for pattern descriptions
		#------------------------------------------
		if (($type ne "metapackages") && (! defined $nopac)) {
			my @pattlist = ();
			my @slist = $node -> getElementsByTagName ("opensuseProduct");
			foreach my $element (@slist) {
				if (! $this -> isArchAllowed ($element,$type)) {
					next;
				}
				my $product = $element -> getAttribute ("name");
				if (! defined $product) {
					next;
				}
				push @pattlist,"product:".$product;
			}
			@slist = ();
			my @slist_suse = $node -> getElementsByTagName ("opensusePattern");
			my @slist_rhel = $node -> getElementsByTagName ("rhelGroup");
			if (@slist_suse) {
				push @slist,@slist_suse;
			}
			if (@slist_rhel) {
				push @slist,@slist_rhel;
			}
			foreach my $element (@slist) {
				if (! $this -> isArchAllowed ($element,$type)) {
					next;
				}
				my $pattern = $element -> getAttribute ("name");
				if (! defined $pattern) {
					next;
				}
				push @pattlist,"pattern:".$pattern;
			}
			if (@pattlist) {
				if (($manager eq "ensconce")) {
					# nothing to do for ensconce here...
				} elsif (($manager ne "zypper") && ($manager ne "yum")) {
					#==========================================
					# turn patterns into pacs for this manager
					#------------------------------------------
					# 1) try to use libsatsolver...
					my $psolve = KIWISatSolver -> new (
						$kiwi,\@pattlist,$urllist,"solve-patterns",
						undef,undef,$ptype
					);
					if (! defined $psolve) {
						$kiwi -> error (
							"SaT solver setup failed, patterns can't be solved"
						);
						$kiwi -> skipped ();
						return ();
					}
					if (! defined $psolve) {
						my $pp ="Pattern or product";
						my $e1 ="$pp match failed for arch: $this->{arch}";
						my $e2 ="Check if the $pp is written correctly?";
						my $e3 ="Check if the arch is provided by the repo(s)?";
						$kiwi -> warning ("$e1\n");
						$kiwi -> warning ("    a) $e2\n");
						$kiwi -> warning ("    b) $e3\n");
						return ();
					}
					my @packageList = $psolve -> getPackages();
					push @result,@packageList;
				} else {
					#==========================================
					# zypper/yum knows about patterns/groups
					#------------------------------------------
					foreach my $pname (@pattlist) {
						$kiwi -> info ("--> Requesting $pname");
						push @result,$pname;
						$kiwi -> done();
					}
				}
			}
		}
		#==========================================
		# Check for ignore list
		#------------------------------------------
		if (! defined $nopac) {
			my @ilist = $node -> getElementsByTagName ("ignore");
			my @ignorelist = ();
			foreach my $element (@ilist) {
				my $ignore = $element -> getAttribute ("name");
				if (! defined $ignore) {
					next;
				}
				if (($ignore =~ /@/) && ($manager eq "zypper")) {
					$ignore =~ s/@/\./;
				}
				push @ignorelist,$ignore;
			}
			if (@ignorelist) {
				my @newlist = ();
				foreach my $element (@result) {
					my $pass = 1;
					foreach my $ignore (@ignorelist) {
						if ($element eq $ignore) {
							$pass = 0; last;
						}
					}
					if (! $pass) {
						next;
					}
					push @newlist,$element;
				}
				@result = @newlist;
			}
		}
	}
	#==========================================
	# Create unique lists
	#------------------------------------------
	my %packHash = ();
	my @replAddList = ();
	my @replDelList = ();
	foreach my $package (@result) {
		if (ref $package) {
			push @replAddList,$package->[0];
			push @replDelList,$package->[1];
		} else {
			$packHash{$package} = $package;
		}
	}
	$this->{replDelList} = \@replDelList;
	$this->{replAddList} = \@replAddList;
	my @ordered = sort keys %packHash;
	return @ordered;
}

#==========================================
# getLVMGroupName_legacy
#------------------------------------------
sub getLVMGroupName_legacy {
	# ...
	# Return the name of the volume group if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $node) {
		return;
	}
	return $node -> getAttribute ("name");
}

#==========================================
# getLVMVolumes_legacy
#------------------------------------------
sub getLVMVolumes_legacy {
	# ...
	# Create list of LVM volume names for sub volume
	# setup. Each volume name will end up in an own
	# LVM volume when the LVM setup is requested
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	my %result = ();
	if (! defined $node) {
		return %result;
	}
	my @vollist = $node -> getElementsByTagName ("volume");
	foreach my $volume (@vollist) {
		my $name = $volume -> getAttribute ("name");
		my $free = $volume -> getAttribute ("freespace");
		my $size = $volume -> getAttribute ("size");
		my $haveAbsolute;
		my $usedValue;
		if ($size) {
			$haveAbsolute = 1;
			$usedValue = $size;
		} elsif ($free) {
			$usedValue = $free;
			$haveAbsolute = 0;
		}
		if (($usedValue) && ($usedValue =~ /(\d+)([MG]*)/)) {
			my $byte = int $1;
			my $unit = $2;
			if ($unit eq "G") {
				$usedValue = $byte * 1024;
			} else {
				# no or unknown unit, assume MB...
				$usedValue = $byte;
			}
		}
		$name =~ s/\s+//g;
		if ($name eq "/") {
			$kiwi -> warning ("LVM: Directory $name is not allowed");
			$kiwi -> skipped ();
			next;
		}
		$name =~ s/^\///;
		if ($name
			=~ /^(image|proc|sys|dev|boot|mnt|lib|bin|sbin|etc|lost\+found)/) {
			$kiwi -> warning ("LVM: Directory $name is not allowed");
			$kiwi -> skipped ();
			next;
		}
		$name =~ s/\//_/g;
		$result{$name} = [ $usedValue,$haveAbsolute ];
	}
	return %result;
}

#==========================================
# getOEMAlignPartition_legacy
#------------------------------------------
sub getOEMAlignPartition_legacy {
	# ...
	# Obtain the oem-align-partition value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $align = $node -> getElementsByTagName ("oem-align-partition");
	if ((! defined $align) || ("$align" eq "")) {
		return;
	}
	return $align;
}

#==========================================
# getOEMBootTitle_legacy
#------------------------------------------
sub getOEMBootTitle_legacy {
	# ...
	# Obtain the oem-boot-title value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $title= $node -> getElementsByTagName ("oem-boot-title");
	if ((! defined $title) || ("$title" eq "")) {
		$title = $this -> getImageDisplayName();
		if ((! defined $title) || ("$title" eq "")) {
			return;
		}
	}
	return $title;
}

#==========================================
# getOEMBootWait_legacy
#------------------------------------------
sub getOEMBootWait_legacy {
	# ...
	# Obtain the oem-bootwait value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $wait = $node -> getElementsByTagName ("oem-bootwait");
	if ((! defined $wait) || ("$wait" eq "")) {
		return;
	}
	return $wait;
}

#==========================================
# getOEMKiwiInitrd_legacy
#------------------------------------------
sub getOEMKiwiInitrd_legacy {
	# ...
	# Obtain the oem-kiwi-initrd value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $kboot= $node -> getElementsByTagName ("oem-kiwi-initrd");
	if ((! defined $kboot) || ("$kboot" eq "")) {
		return;
	}
	return $kboot;
}

#==========================================
# getOEMPartitionInstall_legacy
#------------------------------------------
sub getOEMPartitionInstall_legacy {
	# ...
	# Obtain the oem-partition-install value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $pinst = $node -> getElementsByTagName ("oem-partition-install");
	if ((! defined $pinst) || ("$pinst" eq "")) {
		return;
	}
	return $pinst;
}

#==========================================
# getOEMReboot_legacy
#------------------------------------------
sub getOEMReboot_legacy {
	# ...
	# Obtain the oem-reboot value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $boot = $node -> getElementsByTagName ("oem-reboot");
	if ((! defined $boot) || ("$boot" eq "")) {
		return;
	}
	return $boot;
}

#==========================================
# getOEMRebootInter_legacy
#------------------------------------------
sub getOEMRebootInter_legacy {
	# ...
	# Obtain the oem-reboot-interactive value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $boot = $node -> getElementsByTagName ("oem-reboot-interactive");
	if ((! defined $boot) || ("$boot" eq "")) {
		return;
	}
	return $boot;
}

#==========================================
# getOEMRecovery_legacy
#------------------------------------------
sub getOEMRecovery_legacy {
	# ...
	# Obtain the oem-recovery value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $reco = $node -> getElementsByTagName ("oem-recovery");
	if ((! defined $reco) || ("$reco" eq "")) {
		return;
	}
	return $reco;
}

#==========================================
# getOEMRecoveryID_legacy
#------------------------------------------
sub getOEMRecoveryID_legacy {
	# ...
	# Obtain the oem-recovery partition ID value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $reco = $node -> getElementsByTagName ("oem-recoveryID");
	if ((! defined $reco) || ("$reco" eq "")) {
		return;
	}
	return $reco;
}

#==========================================
# getOEMRecoveryInPlace_legacy
#------------------------------------------
sub getOEMRecoveryInPlace_legacy {
	# ...
	# Obtain the oem-inplace-recovery value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $inplace = $node -> getElementsByTagName ("oem-inplace-recovery");
	if ((! defined $inplace) || ("$inplace" eq "")) {
		return;
	}
	return $inplace;
}

#==========================================
# getOEMShutdown_legacy
#------------------------------------------
sub getOEMShutdown_legacy {
	# ...
	# Obtain the oem-shutdown value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $down = $node -> getElementsByTagName ("oem-shutdown");
	if ((! defined $down) || ("$down" eq "")) {
		return;
	}
	return $down;
}

#==========================================
# getOEMShutdownInter_legacy
#------------------------------------------
sub getOEMShutdownInter_legacy {
	# ...
	# Obtain the oem-shutdown-interactive value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $down = $node -> getElementsByTagName ("oem-shutdown-interactive");
	if ((! defined $down) || ("$down" eq "")) {
		return;
	}
	return $down;
}

#==========================================
# getOEMSilentBoot_legacy
#------------------------------------------
sub getOEMSilentBoot_legacy {
	# ...
	# Obtain the oem-silent-boot value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $silent = $node -> getElementsByTagName ("oem-silent-boot");
	if ((! defined $silent) || ("$silent" eq "")) {
		return;
	}
	return $silent;
}

#==========================================
# getOEMSwap_legacy
#------------------------------------------
sub getOEMSwap_legacy {
	# ...
	# Obtain the oem-swap value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $swap = $node -> getElementsByTagName ("oem-swap");
	if ((! defined $swap) || ("$swap" eq "")) {
		return;
	}
	return $swap;
}

#==========================================
# getOEMSwapSize_legacy
#------------------------------------------
sub getOEMSwapSize_legacy {
	# ...
	# Obtain the oem-swapsize value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $size = $node -> getElementsByTagName ("oem-swapsize");
	if ((! defined $size) || ("$size" eq "")) {
		return;
	}
	return $size;
}

#==========================================
# getOEMSystemSize_legacy
#------------------------------------------
sub getOEMSystemSize_legacy {
	# ...
	# Obtain the oem-systemsize value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $size = $node -> getElementsByTagName ("oem-systemsize");
	if ((! defined $size) || ("$size" eq "")) {
		return;
	}
	return $size;
}

#==========================================
# getOEMUnattended_legacy
#------------------------------------------
sub getOEMUnattended_legacy {
	# ...
	# Obtain the oem-unattended value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $unattended = $node -> getElementsByTagName ("oem-unattended");
	if ((! defined $unattended) || ("$unattended" eq "")) {
		return;
	}
	return $unattended;
}

#==========================================
# getOEMUnattendedID_legacy
#------------------------------------------
sub getOEMUnattendedID_legacy {
	# ...
	# Obtain the oem-unattended-id value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $unattended_id = $node -> getElementsByTagName ("oem-unattended-id");
	if ((! defined $unattended_id) || ("$unattended_id" eq "")) {
		return;
	}
	return $unattended_id;
}

#==========================================
# getOVFConfig_legacy
#------------------------------------------
sub getOVFConfig_legacy {
	# ...
	# Create an Attribute hash from the <machine>
	# section if it exists suitable for the OVM
	# configuration
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	my %result = ();
	my $device;
	my $disktype;
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $minmemory = $node -> getAttribute ("min_memory");
	my $desmemory = $node -> getAttribute ("des_memory");
	my $maxmemory = $node -> getAttribute ("max_memory");
	my $memory    = $node -> getAttribute ("memory");
	my $ncpus     = $node -> getAttribute ("ncpus");
	my $mincpu    = $node -> getAttribute ("min_cpu");
	my $descpu    = $node -> getAttribute ("des_cpu");
	my $maxcpu    = $node -> getAttribute ("max_cpu");
	my $type      = $node -> getAttribute ("ovftype");
	#==========================================
	# storage setup
	#------------------------------------------
	my $disk = $node -> getElementsByTagName ("vmdisk");
	if ($disk) {
		my $node  = $disk -> get_node(1);
		$device = $node -> getAttribute ("device");
		$disktype = $node -> getAttribute ("disktype");
	}
	#==========================================
	# network setup
	#------------------------------------------
	my $bridges = $node -> getElementsByTagName ("vmnic");
	my %vifs = ();
	for (my $i=1;$i<= $bridges->size();$i++) {
		my $bridge = $bridges -> get_node($i);
		if ($bridge) {
			my $bname = $bridge -> getAttribute ("interface");
			if (! $bname) {
				$bname = "undef";
			}
			$vifs{$bname} = $i;
		}
	}
	#==========================================
	# save hash
	#------------------------------------------
	$result{ovf_minmemory} = $minmemory;
	$result{ovf_desmemory} = $desmemory;
	$result{ovf_maxmemory} = $maxmemory;
	$result{ovf_memory}    = $memory;
	$result{ovf_ncpus}     = $ncpus;
	$result{ovf_mincpu}    = $mincpu;
	$result{ovf_descpu}    = $descpu;
	$result{ovf_maxcpu}    = $maxcpu;
	$result{ovf_type}      = $type;
	if ($disk) {
		$result{ovf_disk}    = $device;
		$result{ovf_disktype}= $disktype;
	}
	foreach my $bname (keys %vifs) {
		$result{ovf_bridge}{$bname} = $vifs{$bname};
	}
	return %result;
}

#==========================================
# getPackageAttributes_legacy
#------------------------------------------
sub getPackageAttributes_legacy {
	# ...
	# Create an attribute hash from the given
	# package category.
	# ---
	my $this = shift;
	my $what = shift;
	my $kiwi = $this->{kiwi};
	my @node = $this->{packageNodeList} -> get_nodelist();
	my %result;
	$result{patternType} = "onlyRequired";
	$result{type} = $what;
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $type = $element -> getAttribute ("type");
		if ($type ne $what) {
			next;
		}
		my $ptype = $element -> getAttribute ("patternType");
		if ($ptype) {
			$result{patternType} = $ptype;
			$result{type} = $type;
		}
	}
	return %result;
}

#==========================================
# getPackageManager_legacy
#------------------------------------------
sub getPackageManager_legacy {
	# ...
	# Get the name of the package manager if set.
	# if not set return the default package
	# manager name
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $node = $this -> __getPreferencesNodeByTagName ("packagemanager");
	my @packMgrs = $node -> getElementsByTagName ("packagemanager");
	my $pmgr = $packMgrs[0];
	if (! $pmgr) {
		return 'zypper';
	}
	return $pmgr -> textContent();
}

#==========================================
# getPackageNodeList_legacy
#------------------------------------------
sub getPackageNodeList_legacy {
	# ...
	# Return a list of all <packages> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{packageNodeList};
}

#==========================================
# getProfiles_legacy
#------------------------------------------
sub getProfiles_legacy {
	# ...
	# Return a list of profiles available for this image
	# ---
	my $this   = shift;
	my @result = ();
	if (! defined $this->{profilesNodeList}) {
		return @result;
	}
	my $base = $this->{profilesNodeList} -> get_node(1);
	if (! defined $base) {
		return @result;
	}
	my @node = $base -> getElementsByTagName ("profile");
	foreach my $element (@node) {
		my $name = $element -> getAttribute ("name");
		my $desc = $element -> getAttribute ("description");
		my $incl = $element -> getAttribute ("import");
		my %profile = ();
		$profile{name} = $name;
		$profile{description} = $desc;
		$profile{include} = $incl;
		push @result, { %profile };
	}
	return @result;
}

#==========================================
# getPXEDeployInitrd_legacy
#------------------------------------------
sub getPXEDeployInitrd_legacy {
	# ...
	# Get the deploy initrd, if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	my $initrd = $node -> getElementsByTagName ("initrd");
	if ((defined $initrd) && ! ("$initrd" eq "")) {
		return $initrd;
	} else {
		return;
	}
}

#==========================================
# getPXEDeployUnionConfig_legacy
#------------------------------------------
sub getPXEDeployUnionConfig_legacy {
	# ...
	# Get the union file system configuration, if any
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("union") -> get_node(1);
	my %config = ();
	if (! $node) {
		return %config;
	}
	$config{ro}   = $node -> getAttribute ("ro");
	$config{rw}   = $node -> getAttribute ("rw");
	$config{type} = $node -> getAttribute ("type");
	return %config;
}

#==========================================
# getPXEDeployImageDevice_legacy
#------------------------------------------
sub getPXEDeployImageDevice_legacy {
	# ...
	# Get the device the image will be installed to
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("partitions") -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("device");
	} else {
		return;
	}
}

#==========================================
# getPXEDeployServer_legacy
#------------------------------------------
sub getPXEDeployServer_legacy {
	# ...
	# Get the server the config data is obtained from
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("server");
	} else {
		return "192.168.1.1";
	}
}

#==========================================
# getPXEDeployBlockSize_legacy
#------------------------------------------
sub getPXEDeployBlockSize_legacy {
	# ...
	# Get the block size the deploy server should use
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	if (defined $node) {
		return $node -> getAttribute ("blocksize");
	} else {
		return "4096";
	}
}

#==========================================
# getPXEDeployPartitions_legacy
#------------------------------------------
sub getPXEDeployPartitions_legacy {
	# ...
	# Get the partition configuration for this image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $partitions = $tnode 
		-> getElementsByTagName ("partitions") -> get_node(1);
	my @result = ();
	if (! $partitions) {
		return @result;
	}
	my $partitionNodes = $partitions -> getElementsByTagName ("partition");
	for (my $i=1;$i<= $partitionNodes->size();$i++) {
		my $node = $partitionNodes -> get_node($i);
		my $number = $node -> getAttribute ("number");
		my $type = $node -> getAttribute ("type");
		if (! defined $type) {
			$type = "L";
		}
		my $size = $node -> getAttribute ("size");
		if (! defined $size) {
			$size = "x";
		}
		my $mountpoint = $node -> getAttribute ("mountpoint");
		if (! defined $mountpoint) {
			$mountpoint = "x";
		}
		my $target = $node -> getAttribute ("target");
		if ((! $target) || ($target eq "false") || ($target eq "0")) {
			$target = 0;
		} else {
			$target = 1
		}
		my %part = ();
		$part{number} = $number;
		$part{type} = $type;
		$part{size} = $size;
		$part{mountpoint} = $mountpoint;
		$part{target} = $target;
		push @result, { %part };
	}
	my @ordered = sort { $a->{number} cmp $b->{number} } @result;
	return @ordered;
}

#==========================================
# getPXEDeployConfiguration_legacy
#------------------------------------------
sub getPXEDeployConfiguration_legacy {
	# ...
	# Get the configuration file information for this image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my @node = $tnode -> getElementsByTagName ("configuration");
	my %result;
	foreach my $element (@node) {
		my $source = $element -> getAttribute("source");
		my $dest   = $element -> getAttribute("dest");
		my $forarch= $element -> getAttribute("arch");
		my $allowed= 1;
		if (defined $forarch) {
			my @archlst = split (/,/,$forarch);
			my $foundit = 0;
			foreach my $archok (@archlst) {
				if ($archok eq $this->{arch}) {
					$foundit = 1; last;
				}
			}
			if (! $foundit) {
				$allowed = 0;
			}
		}
		if ($allowed) {
			$result{$source} = $dest;
		}
	}
	return %result;
}

#==========================================
# getPXEDeployTimeout_legacy
#------------------------------------------
sub getPXEDeployTimeout_legacy {
	# ...
	# Get the boot timeout, if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	my $timeout = $node -> getElementsByTagName ("timeout");
	if ((defined $timeout) && ! ("$timeout" eq "")) {
		return $timeout;
	} else {
		return;
	}
}

#==========================================
# getPXEDeployKernel_legacy
#------------------------------------------
sub getPXEDeployKernel_legacy {
	# ...
	# Get the deploy kernel, if specified
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("pxedeploy") -> get_node(1);
	my $kernel = $node -> getElementsByTagName ("kernel");
	if ((defined $kernel) && ! ("$kernel" eq "")) {
		return $kernel;
	} else {
		return;
	}
}

#==========================================
# getRPMCheckSignatures_legacy
#------------------------------------------
sub getRPMCheckSignatures_legacy {
	# ...
	# Check if the package manager should check for
	# RPM signatures or not
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("rpm-check-signatures");
	my $sigs = $node -> getElementsByTagName ("rpm-check-signatures");
	if ((! defined $sigs) || ("$sigs" eq "") || ("$sigs" eq "false")) {
		return;
	}
	return $sigs;
}

#==========================================
# getRPMExcludeDocs_legacy
#------------------------------------------
sub getRPMExcludeDocs_legacy {
	# ...
	# Check if the package manager should exclude docs
	# from installed files or not
	# ---
	my $this = shift;
	my $node = $this-> __getPreferencesNodeByTagName ("rpm-excludedocs");
	my $xdoc = $node -> getElementsByTagName ("rpm-excludedocs");
	if ((! defined $xdoc) || ("$xdoc" eq "")) {
		return;
	}
	return $xdoc;
}

#==========================================
# getRPMForce_legacy
#------------------------------------------
sub getRPMForce_legacy {
	# ...
	# Check if the package manager should force
	# installing packages
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("rpm-force");
	my $frpm = $node -> getElementsByTagName ("rpm-force");
	if ((! defined $frpm) || ("$frpm" eq "") || ("$frpm" eq "false")) {
		return;
	}
	return $frpm;
}

#==========================================
# getRepositories_legacy
#------------------------------------------
sub getRepositories_legacy {
	# ...
	# Get the repository type used for building
	# up the physical extend. For information on the available
	# types refer to the package manager documentation
	# ---
	my $this = shift;
	my @node = $this->{repositNodeList} -> get_nodelist();
	my %result;
	foreach my $element (@node) {
		#============================================
		# Check to see if node is in included profile
		#--------------------------------------------
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		#============================================
		# Store repo information in hash
		#--------------------------------------------
		my $type = $element -> getAttribute("type");
		my $alias= $element -> getAttribute("alias");
		my $imgincl = $element -> getAttribute("imageinclude");
		my $prio = $element -> getAttribute("priority");
		my $user = $element -> getAttribute("username");
		my $pwd  = $element -> getAttribute("password");
		my $plic = $element -> getAttribute("prefer-license");
		my $stag = $element -> getElementsByTagName ("source") -> get_node(1);
		my $source = $this -> __resolveLink ( $stag -> getAttribute ("path") );
		$result{$source} = [$type,$alias,$prio,$user,$pwd,$plic,$imgincl];
	}
	return %result;
}

#==========================================
# getSplitPersistentFiles_legacy
#------------------------------------------
sub getSplitPersistentFiles_legacy {
	# ...
	# Get the persistent files/directories for split image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $persistNode = $node -> getElementsByTagName ("persistent")
		-> get_node(1);
	if (! defined $persistNode) {
		return @result;
	}
	my @fileNodeList = $persistNode -> getElementsByTagName ("file");
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		$name =~ s/\/$//;
		push @result, $name;
	}
	return @result;
}

#==========================================
# getSplitTempFiles_legacy
#------------------------------------------
sub getSplitTempFiles_legacy {
	# ...
	# Get the persistent files/directories for split image
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $tempNode = $node -> getElementsByTagName ("temporary") -> get_node(1);
	if (! defined $tempNode) {
		return @result;
	}
	my @fileNodeList = $tempNode -> getElementsByTagName ("file");
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		$name =~ s/\/$//;
		push @result, $name;
	}
	return @result;
}

#==========================================
# getSplitTempExceptions_legacy
#------------------------------------------
sub getSplitTempExceptions_legacy {
	# ...
	# Get the exceptions defined for temporary
	# split portions. If there are no exceptions defined
	# return an empty list
	# ----
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $tempNode = $node -> getElementsByTagName ("temporary") -> get_node(1);
	if (! defined $tempNode) {
		return @result;
	}
	my @fileNodeList = $tempNode -> getElementsByTagName ("except");
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	return @result;
}

#==========================================
# getSplitPersistentExceptions_legacy
#------------------------------------------
sub getSplitPersistentExceptions_legacy {
	# ...
	# Get the exceptions defined for persistent
	# split portions. If there are no exceptions defined
	# return an empty list
	# ----
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("split") -> get_node(1);
	my @result = ();
	if (! defined $node) {
		return @result;
	}
	my $persistNode = $node -> getElementsByTagName ("persistent")
		-> get_node(1);
	if (! defined $persistNode) {
		return @result;
	}
	my @fileNodeList = $persistNode -> getElementsByTagName ("except");
	foreach my $fileNode (@fileNodeList) {
		push @result, $fileNode -> getAttribute ("name");
	}
	return @result;
}

#==========================================
# getTypes_legacy
#------------------------------------------
sub getTypes_legacy {
	# ...
	# Receive a list of types available for this image
	# ---
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $cmdL    = $this->{cmdL};
	my @result  = ();
	my @tnodes  = ();
	my $gotprim = 0;
	my @node    = $this->{optionsNodeList} -> get_nodelist();
	my $urlhd   = KIWIURL -> new ($kiwi,$cmdL);
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my @types = $element -> getElementsByTagName ("type");
		push (@tnodes,@types);
	}
	foreach my $node (@tnodes) {
		my %record  = ();
		$record{type} = $node -> getAttribute("image");
		my $bootSpec = $node -> getAttribute("boot");
		if ($bootSpec) {
			$record{boot} = $bootSpec;
			my $bootpath = $urlhd -> normalizeBootPath ($bootSpec);
			if (defined $bootpath) {
				$record{boot} = $bootpath;
			}
		}
		my $primary = $node -> getAttribute("primary");
		if ((defined $primary) && ("$primary" eq "true")) {
			$record{primary} = "true";
			$gotprim = 1;
		} else {
			$record{primary} = "false";
		}
		push (@result,\%record);
	}
	if (! $gotprim) {
		$result[0]->{primary} = "true";
	}
	return @result;
}

#==========================================
# getTypeSpecificPackageList_legacy
#------------------------------------------
sub getTypeSpecificPackageList_legacy {
	# ...
	# Create package list according to the selected
	# image type
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $type = $node -> getAttribute("image");
	return getList_legacy ($this,$type);
}

#==========================================
# getUsers_legacy
#------------------------------------------
sub getUsers_legacy {
	# ...
	# Receive a list of users to be added into the image
	# the user specification contains an optional password
	# and group. If the group doesn't exist it will be created
	# ---
	my $this   = shift;
	my %result = ();
	my @node   = $this->{usrdataNodeList} -> get_nodelist();
	foreach my $element (@node) {
		my $group = $element -> getAttribute("group");
		my $gid   = $element -> getAttribute("id");
		my @ntag  = $element -> getElementsByTagName ("user");
		foreach my $element (@ntag) {
			my $name = $element -> getAttribute ("name");
			my $uid  = $element -> getAttribute ("id");
			my $pwd  = $element -> getAttribute ("pwd");
			my $pwdformat = $element -> getAttribute ("pwdformat");
			my $home = $element -> getAttribute ("home");
			my $realname = $element -> getAttribute ("realname");
			my $shell = $element -> getAttribute ("shell");
			if (defined $name) {
				$result{$name}{group} = $group;
				$result{$name}{gid}   = $gid;
				$result{$name}{uid}   = $uid;
				$result{$name}{home}  = $home;
				$result{$name}{pwd}   = $pwd;
				$result{$name}{pwdformat}= $pwdformat;
				$result{$name}{realname} = $realname;
				$result{$name}{shell} = $shell;
			}
		}
	}
	return %result;
}

#==========================================
# getVMwareConfig_legacy
#------------------------------------------
sub getVMwareConfig_legacy {
	# ...
	# Create an Attribute hash from the <machine>
	# section if it exists suitable for the VMware configuration
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	my %result = ();
	my %guestos= ();
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $arch = $node -> getAttribute ("arch");
	if (! defined $arch) {
		$arch = "ix86";
	} elsif ($arch eq "%arch") {
		my $sysarch = qxx ("uname -m"); chomp $sysarch;
		if ($sysarch =~ /i.86/) {
			$arch = "ix86";
		} else {
			$arch = $sysarch;
		}
	}
	my $hwver= $node -> getAttribute ("HWversion");
	if (! defined $hwver) {
		$hwver = 4;
	}
	$guestos{suse}{ix86}     = "suse";
	$guestos{suse}{x86_64}   = "suse-64";
	$guestos{sles}{ix86}     = "sles";
	$guestos{sles}{x86_64}   = "sles-64";
	$guestos{rhel6}{x86_64}  = "rhel6-64";
	$guestos{rhel6}{ix86}    = "rhel6";
	$guestos{rhel5}{x86_64}  = "rhel5-64";
	$guestos{rhel5}{ix86}    = "rhel5";
	$guestos{centos}{ix86}   = "centos";
	$guestos{centos}{x86_64} = "centos-64";
	my $guest= $node -> getAttribute ("guestOS");
	if ((!defined $guest) || (! defined $guestos{$guest}{$arch})) {
		if ($arch eq "ix86") {
			$guest = "suse";
		} else {
			$guest = "suse-64";
		}
	} else {
		$guest = $guestos{$guest}{$arch};
	}
	my $memory = $node -> getAttribute ("memory");
	my $ncpus  = $node -> getAttribute ("ncpus");
	#==========================================
	# storage setup disk
	#------------------------------------------
	my $disk = $node -> getElementsByTagName ("vmdisk");
	my ($type,$id);
	if ($disk) {
		my $node = $disk -> get_node(1);
		$type = $node -> getAttribute ("controller");
		$id   = $node -> getAttribute ("id");
	}
	#==========================================
	# storage setup CD rom
	#------------------------------------------
	my $cd = $node -> getElementsByTagName ("vmdvd");
	my ($cdtype,$cdid);
	if ($cd) {
		my $node = $cd -> get_node(1);
		$cdtype = $node -> getAttribute ("controller");
		$cdid   = $node -> getAttribute ("id");
	}
	#==========================================
	# network setup
	#------------------------------------------
	my $nic  = $node -> getElementsByTagName ("vmnic");
	my %vmnics;
	for (my $i=1; $i<= $nic->size(); $i++) {
		my $node = $nic  -> get_node($i);
		$vmnics{$node -> getAttribute ("interface")} =
		{
			drv  => $node -> getAttribute ("driver"),
			mode => $node -> getAttribute ("mode")
		};
	}
	#==========================================
	# configuration file settings
	#------------------------------------------
	my @vmConfigOpts = $this -> __getVMConfigOpts();
	#==========================================
	# save hash
	#------------------------------------------
	$result{vmware_arch}  = $arch;
	if (@vmConfigOpts) {
		$result{vmware_config} = \@vmConfigOpts;
	}
	$result{vmware_hwver} = $hwver;
	$result{vmware_guest} = $guest;
	$result{vmware_memory}= $memory;
	$result{vmware_ncpus} = $ncpus;
	if ($disk) {
		$result{vmware_disktype} = $type;
		$result{vmware_diskid}   = $id;
	}
	if ($cd) {
		$result{vmware_cdtype} = $cdtype;
		$result{vmware_cdid}   = $cdid;
	}
	if (%vmnics) {
		$result{vmware_nic}= \%vmnics;
	}
	return %result;
}

#==========================================
# getXenConfig_legacy
#------------------------------------------
sub getXenConfig_legacy {
	# ...
	# Create an Attribute hash from the <machine>
	# section if it exists suitable for the xen domU configuration
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	my %result = ();
	if (! defined $node) {
		return %result;
	}
	#==========================================
	# global setup
	#------------------------------------------
	my $memory = $node -> getAttribute ("memory");
	my $ncpus  = $node -> getAttribute ("ncpus");
	my $domain = $node -> getAttribute ("domain");
	#==========================================
	# storage setup
	#------------------------------------------
	my $disk = $node -> getElementsByTagName ("vmdisk");
	my $device;
	if ($disk) {
		my $node  = $disk -> get_node(1);
		$device= $node -> getAttribute ("device");
	}
	#==========================================
	# network setup (bridge)
	#------------------------------------------
	my $bridges = $node -> getElementsByTagName ("vmnic");
	my %vifs = ();
	for (my $i=1;$i<= $bridges->size();$i++) {
		my $bridge = $bridges -> get_node($i);
		if ($bridge) {
			my $mac   = $bridge -> getAttribute ("mac");
			my $bname = $bridge -> getAttribute ("interface");
			if (! $bname) {
				$bname = "undef";
			}
			$vifs{$bname} = $mac;
		}
	}
	#==========================================
	# configuration file settings
	#------------------------------------------
	my @vmConfigOpts = $this -> __getVMConfigOpts();
	#==========================================
	# save hash
	#------------------------------------------
	if (@vmConfigOpts) {
		$result{xen_config} = \@vmConfigOpts
	}
	$result{xen_memory}= $memory;
	$result{xen_ncpus} = $ncpus;
	$result{xen_domain}= $domain;
	if ($disk) {
		$result{xen_diskdevice} = $device;
	}
	foreach my $bname (keys %vifs) {
		$result{xen_bridge}{$bname} = $vifs{$bname};
	}
	return %result;
}

#==========================================
# ignoreRepositories_legacy
#------------------------------------------
sub ignoreRepositories_legacy {
	# ...
	# Ignore all the repositories in the XML file.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	$kiwi -> info ('Ignoring all repositories previously configured');
	$kiwi -> done();
	my @node = $this->{repositNodeList} -> get_nodelist();
	foreach my $element (@node) {
		$this->{imgnameNodeList}->get_node(1)->removeChild ($element);
	}
	$this->{repositNodeList} = 
		$this->{systemTree}->getElementsByTagName ("repository");
	$this-> updateXML();
	return $this;
}

#==========================================
# setPackageManager_legacy
#------------------------------------------
sub setPackageManager_legacy {
	# ...
	# set packagemanager to use for this image
	# ---
	my $this  = shift;
	my $value = shift;
	if (! $value) {
		my $msg = 'setPackageManager method called without specifying '
		. 'package manager value.';
		$this -> {kiwi} -> error ($msg);
		$this -> {kiwi} -> failed();
		return;
	}
	my $opts = $this -> __getPreferencesNodeByTagName ("packagemanager");
	my $pmgr = $opts -> getElementsByTagName ("packagemanager");
	if (($pmgr) && ("$pmgr" eq "$value")) {
		return $this;
	}
	my $addElement = XML::LibXML::Element -> new ("packagemanager");
	# Also update the ned data structure to ensure the runtime checker works
	# properly
	my $prefObj = $this -> getPreferences();
	$prefObj -> setPackageManager($value);
	$this -> setPreferences($prefObj);
	$addElement -> appendText ($value);
	my $node = $opts -> getElementsByTagName ("packagemanager") -> get_node(1);
	if ($node) {
		$opts -> removeChild ($node);
	}
	$opts -> appendChild ($addElement);
	$this -> updateXML();
	return $this;
}

#==========================================
# setRepository_legacy
#------------------------------------------
sub setRepository_legacy {
	# ...
	# Overwerite the first repository that does not have the status
	# sttribute set to fixed.
	# ---
	my $this = shift;
	my $type = shift;
	my $path = shift;
	my $alias= shift;
	my $prio = shift;
	my $user = shift;
	my $pass = shift;
	my @node = $this->{repositNodeList} -> get_nodelist();
	foreach my $element (@node) {
		my $status = $element -> getAttribute("status");
		if ((defined $status) && ($status eq "fixed")) {
			next;
		}
		my $kiwi = $this->{kiwi};
		my $replRepo = $element -> getElementsByTagName ("source")
			-> get_node(1) -> getAttribute ("path");
		$kiwi -> info ("Replacing repository $replRepo");
		$kiwi -> done();
		if (defined $type) {
			$element -> setAttribute ("type",$type);
		}
		if (defined $path) {
			$element -> getElementsByTagName ("source")
				-> get_node (1) -> setAttribute ("path",$path);
		}
		if (defined $alias) {
			$element -> setAttribute ("alias",$alias);
		}
		if ((defined $prio) && ($prio != 0)) {
			$element -> setAttribute ("priority",$prio);
		}
		if ((defined $user) && (defined $pass)) {
			$element -> setAttribute ("username",$user);
			$element -> setAttribute ("password",$pass);
		}
		last;
	}
	$this -> createURLList();
	$this -> updateXML();
	return $this;
}

#==========================================
# addRemovePackages_legacy
#------------------------------------------
sub addRemovePackages_legacy {
	# ...
	# Add the given package list to the type=delete packages
	# section of the xml description parse tree.
	# ----
	my @list = @_;
	my $this = shift @list;
	return $this -> addPackages_legacy ("delete",undef,undef,@list);
}

#==========================================
# addRepositories_legacy
#------------------------------------------
sub addRepositories_legacy {
	# ...
	# Add a repository section to the current list of
	# repos and update repositNodeList accordingly.
	# ---
	my $this = shift;
	my $type = shift;
	my $path = shift;
	my $alias= shift;
	my $prio = shift;
	my $user = shift;
	my $pass = shift;
	my @type = @{$type};
	my @path = @{$path};
	my $kiwi = $this->{kiwi};
	my @alias;
	my @prio;
	my @user;
	my @pass;
	if ($alias) {
		@alias= @{$alias};
	}
	if ($prio) {
		@prio = @{$prio};
	}
	if ($user) {
		@user = @{$user};
	}
	if ($pass) {
		@pass = @{$pass};
	}
	my @supportedTypes = (
		'rpm-dir','rpm-md', 'yast2',
		'apt-deb','apt-rpm','deb-dir',
		'mirrors','red-carpet','slack-site',
		'up2date-mirrors','urpmi'
	);
	foreach my $path (@path) {
		my $type = shift @type;
		my $alias= shift @alias;
		my $prio = shift @prio;
		my $user = shift @user;
		my $pass = shift @pass;
		if (! defined $type) {
			$kiwi -> error   ("No type for repo [$path] specified");
			$kiwi -> skipped ();
			next;
		}
		if (! grep { /$type/x } @supportedTypes ) {
			my $msg = "Addition of requested repo type [$type] not supported";
			$kiwi -> error ($msg);
			$kiwi -> skipped ();
			next;
		}
		my $addrepo = XML::LibXML::Element -> new ("repository");
		$addrepo -> setAttribute ("type",$type);
		$addrepo -> setAttribute ("status","fixed");
		if (defined $alias) {
			$addrepo -> setAttribute ("alias",$alias);
		}
		if ((defined $prio) && ($prio != 0)) {
			$addrepo -> setAttribute ("priority",$prio);
		}
		if ((defined $user) && (defined $pass)) {
			$addrepo -> setAttribute ("username",$user);
			$addrepo -> setAttribute ("password",$pass);
		}
		my $addsrc  = XML::LibXML::Element -> new ("source");
		$addsrc -> setAttribute ("path",$path);
		$addrepo -> appendChild ($addsrc);
		$this->{imgnameNodeList}->get_node(1)->appendChild ($addrepo);
	}
	$this->{repositNodeList} =
		$this->{systemTree}->getElementsByTagName ("repository");
	$this -> createURLList();
	$this -> updateXML();
	return $this;
}

#==========================================
# getRepoNodeList_legacy
#------------------------------------------
sub getRepoNodeList_legacy {
	# ...
	# Return the current <repository> list which consists
	# of XML::LibXML::Element object pointers
	# ---
	my $this = shift;
	return $this->{repositNodeList};
}

#==========================================
# getDriversNodeList_legacy
#------------------------------------------
sub getDriversNodeList_legacy {
	# ...
	# Return a list of all <drivers> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{driversNodeList};
}

#==========================================
# __addVolume_legacy
#------------------------------------------
sub __addVolume_legacy {
	# ...
	# Add the given volume to the systemdisk section
	# ---
	my $this  = shift;
	my $volume= shift;
	my $aname = shift;
	my $aval  = shift;
	my $kiwi  = $this->{kiwi};
	my $tnode = $this->{typeNode};
	my $disk  = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $disk) {
		return $this;
	}
	my $addElement = XML::LibXML::Element -> new ("volume");
	$addElement -> setAttribute("name",$volume);
	$addElement -> setAttribute($aname,$aval);
	$disk -> appendChild ($addElement);
	$this -> updateXML();
	return $this;
}

#==========================================
# __populateProfiles_legacy
#------------------------------------------
sub __populateProfiles_legacy {
	# ...
	# import profiles section if specified
	# ---
	my $this     = shift;
	my %result   = ();
	my @profiles = $this -> getProfiles_legacy();
	foreach my $profile (@profiles) {
		if ($profile->{include}) {
			$result{$profile->{name}} = "$profile->{include}";
		} else {
			$result{$profile->{name}} = "false";
		}
	}
	return \%result;
}

#==========================================
# __populateTypeInfo_legacy
#------------------------------------------
sub __populateTypeInfo_legacy {
	# ...
	# Extract the information contained in the <type> elements
	# and store the type descriptions in a list of hash references
	# ---
	# list = (
	#   {
	#      'key' => 'value'
	#      'key' => 'value'
	#   },
	#   {
	#      'key' => 'value'
	#      'key' => 'value'
	#   }
	# )
	# ---
	#
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $cmdL   = $this->{cmdL};
	my $urlhd  = KIWIURL -> new ($kiwi,$cmdL);
	my @node   = $this->{optionsNodeList} -> get_nodelist();
	my @result = ();
	my $first  = 1;
	#==========================================
	# select types
	#------------------------------------------
	foreach my $element (@node) {
		my @types    = $element -> getElementsByTagName ("type");
		my $profiles = $element -> getAttribute("profiles");
		my @assigned = ("all");
		if ($profiles) {
			@assigned = split (/,/,$profiles);
		}
		foreach my $node (@types) {
			my %record = ();
			my $prim   = $node -> getAttribute("primary");
			if (! defined $prim) {
				$record{primary} = "false";
			} else {
				$record{primary} = $prim;
			}
			my $disk = $node->getElementsByTagName("systemdisk")->get_node(1);
			#==========================================
			# meta data
			#------------------------------------------
			$record{first}    = $first;
			$record{node}     = $node;
			$record{assigned} = \@assigned;
			$first = 0;
			#==========================================
			# type attributes
			#------------------------------------------
			$record{type}          = $node
				-> getAttribute("image");
			$record{fsmountoptions}= $node
				-> getAttribute("fsmountoptions");
			$record{luks}          = $node
				-> getAttribute("luks");
			$record{cmdline}       = $node
				-> getAttribute("kernelcmdline");
			$record{compressed}    = $node
				-> getAttribute("compressed");
			$record{boot}          = $node
				-> getAttribute("boot");
			$record{bootfilesystem}= $node
				-> getAttribute("bootfilesystem");
			$record{bootpartsize}  = $node
				-> getAttribute("bootpartsize");
			$record{volid}         = $node
				-> getAttribute("volid");
			$record{flags}         = $node
				-> getAttribute("flags");
			$record{hybrid}        = $node
				-> getAttribute("hybrid");
			$record{format}        = $node
				-> getAttribute("format");
			$record{installiso}    = $node
				-> getAttribute("installiso");
			$record{installstick}  = $node
				-> getAttribute("installstick");
			$record{installpxe}    = $node
				-> getAttribute("installpxe");
			$record{vga}           = $node
				-> getAttribute("vga");
			$record{bootloader}    = $node
				-> getAttribute("bootloader");
			$record{devicepersistency} = $node
				-> getAttribute("devicepersistency");
			$record{boottimeout}   = $node
				-> getAttribute("boottimeout");
			$record{installboot}   = $node
				-> getAttribute("installboot");
			$record{installprovidefailsafe} = $node
				-> getAttribute("installprovidefailsafe");
			$record{checkprebuilt} = $node
				-> getAttribute("checkprebuilt");
			$record{bootprofile}   = $node
				-> getAttribute("bootprofile");
			$record{bootkernel}    = $node
				-> getAttribute("bootkernel");
			$record{filesystem}    = $node
				-> getAttribute("filesystem");
			$record{fsnocheck}     = $node
				-> getAttribute("fsnocheck");
			$record{hybridpersistent}  = $node
				-> getAttribute("hybridpersistent");
			$record{ramonly}       = $node
				-> getAttribute("ramonly");
			if (defined $disk) {
				$record{lvm} = "true";
			}
			if ($record{type} eq "split") {
				my $filesystemRO = $node -> getAttribute("fsreadonly");
				my $filesystemRW = $node -> getAttribute("fsreadwrite");
				if ((defined $filesystemRO) && (defined $filesystemRW)) {
					$record{filesystem} = "$filesystemRW,$filesystemRO";
				}
			}
			my $bootpath = $urlhd -> normalizeBootPath ($record{boot});
			if (defined $bootpath) {
				$record{boot} = $bootpath;
			}
			#==========================================
			# push to list
			#------------------------------------------
			push @result,\%record;
		}
	}
	return \@result;
}

#==========================================
# __populateDefaultProfiles_legacy
#------------------------------------------
sub __populateDefaultProfiles_legacy {
	# ...
	# import default profiles if no other profiles
	# were set on the commandline
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my $profiles = $this->{profileHash};
	my @list     = ();
	#==========================================
	# check for profiles already processed
	#------------------------------------------
	if ((defined $this->{reqProfiles}) && (@{$this->{reqProfiles}})) {
		my $info = join (",",@{$this->{reqProfiles}});
		$kiwi -> info ("Using profile(s): $info");
		$kiwi -> done ();
		return $this;
	}
	#==========================================
	# select profiles marked to become included
	#------------------------------------------
	foreach my $name (keys %{$profiles}) {
		if ($profiles->{$name} eq "true") {
			push @list,$name;
		}
	}
	#==========================================
	# read default type: bootprofile,bootkernel
	#------------------------------------------
	# /.../
	# read the first <type> element which is always the one and only
	# type element in a boot image description. The check made here
	# applies only to boot image descriptions:
	# ----
	my $node = $this->{optionsNodeList}
		-> get_node(1) -> getElementsByTagName ("type") -> get_node(1);
	if (defined $node) {
		my $type = $node -> getAttribute("image");
		if ((defined $type) && ($type eq "cpio")) {
			my $bootprofile = $node -> getAttribute("bootprofile");
			my $bootkernel  = $node -> getAttribute("bootkernel");
			if ($bootprofile) {
				push @list, split (/,/,$bootprofile);
			} else {
				# apply 'default' profile required for boot images
				push @list, "default";
			}
			if ($bootkernel) {
				push @list, split (/,/,$bootkernel);
			} else {
				# apply 'std' kernel profile required for boot images
				push @list, "std";
			}
		}
	}
	#==========================================
	# store list of requested profiles
	#------------------------------------------
	if (@list) {
		my $info = join (",",@list);
		$kiwi -> info ("Using profile(s): $info");
		$this -> {reqProfiles} = \@list;
		$kiwi -> done ();
	}
	return $this;
}

#==========================================
# __checkProfiles_legacy
#------------------------------------------
sub __checkProfiles_legacy {
	# ...
	# validate profile names. Wrong profile names are treated
	# as fatal error because you can't know what the result of
	# your image would be without the requested profile
	# ---
	my $this = shift;
	my $pref = shift;
	my $kiwi = $this->{kiwi};
	my $rref = $this->{reqProfiles};
	my @prequest;
	my @profiles = $this -> getProfiles_legacy();
	if (defined $pref) {
		@prequest = @{$pref};
	} elsif (defined $rref) {
		@prequest = @{$rref};
	}
	if (@prequest) {
		foreach my $requested (@prequest) {
			my $ok = 0;
			foreach my $profile (@profiles) {
				if ($profile->{name} eq $requested) {
					$ok=1; last;
				}
			}
			if (! $ok) {
				$kiwi -> error  ("Profile $requested: not found");
				$kiwi -> failed ();
				return;
			}
		}
	}
	return $this;
}

#==========================================
# __populateImageTypeAndNode_legacy
#------------------------------------------
sub __populateImageTypeAndNode_legacy {
	# ...
	# initialize imageType and typeNode according to the
	# requested type or by the type specified as primary
	# or by the first type node found
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my $typeinfo = $this->{typeInfo};
	my $select;
	#==========================================
	# check if there is a preferences section
	#------------------------------------------
	if (! $this->{optionsNodeList}) {
		return;
	}
	#==========================================
	# check if typeinfo hash exists
	#------------------------------------------
	if (! $typeinfo) {
		# /.../
		# if no typeinfo hash was populated we use the first type
		# node listed in the description as the used type.
		# ----
		$this->{typeNode} = $this->{optionsNodeList}
			-> get_node(1) -> getElementsByTagName ("type") -> get_node(1);
		return $this;
	}
	#==========================================
	# select type and type node
	#------------------------------------------
	if (! defined $this->{imageType}) {
		# /.../
		# no type was requested: select primary type or if
		# not set in the XML description select the first one
		# in the list
		# ----
		my @types = keys %{$typeinfo};
		my $first;
		foreach my $type (@types) {
			if ($typeinfo->{$type}{primary} eq "true") {
				$select = $type; last;
			}
			if ($typeinfo->{$type}{first} == 1) {
				$first = $type;
			}
		}
		if (! $select) {
			$select = $first;
		}
	} else {
		# /.../
		# a specific type was requested, select this type
		# ----
		$select = $this->{imageType};
	}
	#==========================================
	# check selection
	#------------------------------------------
	if (! $select) {
		$kiwi -> error  ('Cannot determine build type');
		$kiwi -> failed ();
		return;
	}
	if (! $typeinfo->{$select}) {
		$kiwi -> error  ("Can't find requested image type: $select");
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# store object data
	#------------------------------------------
	$this->{imageType} = $typeinfo->{$select}{type};
	$this->{typeNode}  = $typeinfo->{$select}{node};
	return $this;
}

#==========================================
# __updateDescriptionFromChangeSet_legacy
#------------------------------------------
sub __updateDescriptionFromChangeSet_legacy {
	# ...
	# Write given changes into the previosly read in XML tree
	# This function is used to incorporate repository, packages
	# and other changes into the current XML description. Most
	# often required in order to build the boot image to fit
	# together with the system image
	# ---
	my $this      = shift;
	my $changeset = shift;
	my $kiwi      = $this->{kiwi};
	my $repositNodeList = $this->{repositNodeList};
	my $packageNodeList = $this->{packageNodeList};
	my $reqProfiles;
	#==========================================
	# check changeset...
	#------------------------------------------
	if (! defined $changeset) {
		return;
	}
	#==========================================
	# check profiles in changeset...
	#------------------------------------------
	if ($changeset->{profiles}) {
		$reqProfiles = $this->{reqProfiles};
		$this->{reqProfiles} = $changeset->{profiles};
	}
	#==========================================
	# 1) merge/update repositories
	#------------------------------------------
	if ($changeset->{repositories}) {
		$this -> ignoreRepositories_legacy();
		$kiwi -> info ("Updating repository node(s):");
		# 1) add those repos which are marked as fixed in the boot xml
		my @node = $repositNodeList -> get_nodelist();
		foreach my $element (@node) {
			if (! $this -> __requestedProfile ($element)) {
				next;
			}
			my $status = $element -> getAttribute("status");
			if ((! defined $status) || ($status eq "fixed")) {
				my $type  = $element -> getAttribute("type");
				my $source= $element -> getElementsByTagName("source")
					-> get_node(1) -> getAttribute ("path");
				my $alias = $element -> getAttribute("alias");
				my $prio = $element -> getAttribute("priority");
				$this -> addRepositories_legacy (
					[$type],[$source],[$alias],[$prio]
				);
			}
		}
		# 2) add those repos which are part of the changeset
		foreach my $source (keys %{$changeset->{repositories}}) {
			my $props = $changeset->{repositories}->{$source};
			my $type  = $props->[0];
			my $alias = $props->[1];
			my $prio  = $props->[2];
			my $user  = $props->[3];
			my $pass  = $props->[4];
			$this -> addRepositories_legacy (
				[$type],[$source],[$alias],[$prio],[$user],[$pass]
			);
		}
		$kiwi -> done ();
	}
	#==========================================
	# 2) merge/update drivers
	#------------------------------------------
	if (@{$changeset->{driverList}}) {
		$kiwi -> info ("Updating driver section(s):\n");
		my @drivers = @{$changeset->{driverList}};
		foreach my $d (@drivers) {
			$kiwi -> info ("--> $d\n");
		}
		$this -> addDrivers_legacy (@drivers);
	}
	#==========================================
	# 3) merge/update strip
	#------------------------------------------
	if ($changeset->{strip}) {
		foreach my $type (keys %{$changeset->{strip}}) {
			$kiwi -> info ("Updating $type strip section:\n");
			foreach my $item (@{$changeset->{strip}{$type}}) {
				$kiwi -> info ("--> $item\n");
			}
			$this -> addStrip ($type,@{$changeset->{strip}{$type}});
		}
	}
	#==========================================
	# 4) merge/update packages
	#------------------------------------------
	foreach my $section (("image","bootstrap")) {
		if (@{$changeset->{$section."_fplistImage"}}) {
			$kiwi -> info ("Updating package(s) [$section]:\n");
			my $fixedBootInclude = $changeset->{fixedBootInclude};
			my @fplistImage = @{$changeset->{$section."_fplistImage"}};
			my @fplistDelete = @{$changeset->{$section."_fplistDelete"}};
			foreach my $p (@fplistImage) {
				$kiwi -> info ("--> $p\n");
			}
			$this -> addPackages_legacy (
				$section,$fixedBootInclude,$packageNodeList,@fplistImage
			);
			if (@fplistDelete) {
				$this -> addPackages_legacy (
					"delete",undef,$packageNodeList,@fplistDelete
				);
			}
		}
	}
	#==========================================
	# 5) merge/update archives
	#------------------------------------------
	foreach my $section (("image","bootstrap")) {
		if (@{$changeset->{$section."_falistImage"}}) {
			$kiwi -> info ("Updating archive(s) [$section]:\n");
			my @falistImage = @{$changeset->{$section."_falistImage"}};
			foreach my $p (@falistImage) {
				$kiwi -> info ("--> $p\n");
			}
			$this -> addArchives_legacy (
				$section,"bootinclude",$packageNodeList,@falistImage
			);
		}
	}
	#==========================================
	# 6) merge/update machine attribs in type
	#------------------------------------------
	if (defined $changeset->{"domain"}) {
		$this -> __setMachineAttribute ("domain",$changeset);
	}
	#==========================================
	# 7) merge/update preferences and type
	#------------------------------------------
	if (defined $changeset->{"locale"}) {
		$this -> __setOptionsElement ("locale",$changeset);
	}
	if (defined $changeset->{"bootloader-theme"}) {
		$this -> __setOptionsElement ("bootloader-theme",$changeset);
	}
	if (defined $changeset->{"bootsplash-theme"}) {
		$this -> __setOptionsElement ("bootsplash-theme",$changeset);
	}
	if (defined $changeset->{"packagemanager"}) {
		$this -> __setOptionsElement ("packagemanager",$changeset);
	}
	if (defined $changeset->{"showlicense"}) {
		$this -> __addOptionsElement ("showlicense",$changeset);
	}
	if (defined $changeset->{"oem-swap"}) {
		$this -> __setOEMOptionsElement ("oem-swap",$changeset);
	}
	if (defined $changeset->{"oem-align-partition"}) {
		$this -> __setOEMOptionsElement ("oem-align-partition",$changeset);
	}
	if (defined $changeset->{"oem-partition-install"}) {
		$this -> __setOEMOptionsElement ("oem-partition-install",$changeset);
	}
	if (defined $changeset->{"oem-swapsize"}) {
		$this -> __setOEMOptionsElement ("oem-swapsize",$changeset);
	}
	if (defined $changeset->{"oem-systemsize"}) {
		$this -> __setOEMOptionsElement ("oem-systemsize",$changeset);
	}
	if (defined $changeset->{"oem-boot-title"}) {
		$this -> __setOEMOptionsElement ("oem-boot-title",$changeset);
	}
	if (defined $changeset->{"oem-kiwi-initrd"}) {
		$this -> __setOEMOptionsElement ("oem-kiwi-initrd",$changeset);
	}
	if (defined $changeset->{"oem-reboot"}) {
		$this -> __setOEMOptionsElement ("oem-reboot",$changeset);
	}
	if (defined $changeset->{"oem-reboot-interactive"}) {
		$this -> __setOEMOptionsElement ("oem-reboot-interactive",$changeset);
	}
	if (defined $changeset->{"oem-silent-boot"}) {
		$this -> __setOEMOptionsElement ("oem-silent-boot",$changeset);
	}
	if (defined $changeset->{"oem-shutdown"}) {
		$this -> __setOEMOptionsElement ("oem-shutdown",$changeset);
	}
	if (defined $changeset->{"oem-shutdown-interactive"}) {
		$this -> __setOEMOptionsElement ("oem-shutdown-interactive",$changeset);
	}
	if (defined $changeset->{"oem-bootwait"}) {
		$this -> __setOEMOptionsElement ("oem-bootwait",$changeset);
	}
	if (defined $changeset->{"oem-unattended"}) {
		$this -> __setOEMOptionsElement ("oem-unattended",$changeset);
	}
	if (defined $changeset->{"oem-unattended-id"}) {
		$this -> __setOEMOptionsElement ("oem-unattended-id",$changeset);
	}
	if (defined $changeset->{"oem-recovery"}) {
		$this -> __setOEMOptionsElement ("oem-recovery",$changeset);
	}
	if (defined $changeset->{"oem-recoveryID"}) {
		$this -> __setOEMOptionsElement ("oem-recoveryID",$changeset);
	}
	if (defined $changeset->{"oem-inplace-recovery"}) {
		$this -> __setOEMOptionsElement ("oem-inplace-recovery",$changeset);
	}
	if (defined $changeset->{"lvm"}) {
		$this -> __setSystemDiskElement (undef,$changeset);
	}
	#==========================================
	# 8) merge/update type attributes
	#------------------------------------------
	if (defined $changeset->{"hybrid"}) {
		$this -> __setTypeAttribute (
			"hybrid",$changeset->{"hybrid"}
		);
	}
	if (defined $changeset->{"hybridpersistent"}) {
		$this -> __setTypeAttribute (
			"hybridpersistent",$changeset->{"hybridpersistent"}
		);
	}
	if (defined $changeset->{"ramonly"}) {
		$this -> __setTypeAttribute (
			"ramonly",$changeset->{"ramonly"}
		);
	}
	if (defined $changeset->{"kernelcmdline"}) {
		$this -> __setTypeAttribute (
			"kernelcmdline",$changeset->{"kernelcmdline"}
		);
	}
	if (defined $changeset->{"bootloader"}) {
		$this -> __setTypeAttribute (
			"bootloader",$changeset->{"bootloader"}
		);
	}
	if (defined $changeset->{"devicepersistency"}) {
		$this -> __setTypeAttribute (
			"devicepersistency",$changeset->{"devicepersistency"}
		);
	}
	if (defined $changeset->{"installboot"}) {
		$this -> __setTypeAttribute (
			"installboot",$changeset->{"installboot"}
		);
	}
	if (defined $changeset->{"bootkernel"}) {
		$this -> __setTypeAttribute (
			"bootkernel",$changeset->{"bootkernel"}
		);
	}
	if (defined $changeset->{"fsmountoptions"}) {
		$this -> __setTypeAttribute (
			"fsmountoptions",$changeset->{"fsmountoptions"}
		);
	}
	if (defined $changeset->{"bootprofile"}) {
		$this -> __setTypeAttribute (
			"bootprofile",$changeset->{"bootprofile"}
		);
	}
	#==========================================
	# 9) merge/update image attribs, toplevel
	#------------------------------------------
	if (defined $changeset->{"displayname"}) {
		$this -> __setImageAttribute (
			"displayname",$changeset->{"displayname"}
		);
	}
	#==========================================
	# 10) merge/update volumes with size info
	#------------------------------------------
	if (defined $changeset->{"lvmparts"}) {
		my %lvmparts = %{$changeset->{"lvmparts"}};
		foreach my $vol (keys %lvmparts) {
			if (! $lvmparts{$vol}) {
				next;
			}
			my $attrname = "size";
			my $attrval  = $lvmparts{$vol}->[0];
			my $absolute = $lvmparts{$vol}->[1];
			if (! $attrval) {
				next;
			}
			if (! $absolute) {
				$attrname = "freespace";
			}
			$this -> __addVolume_legacy ($vol,$attrname,$attrval);
		}
	}
	#==========================================
	# 12) cleanup reqProfiles
	#------------------------------------------
	$this->{reqProfiles} = $reqProfiles;
	return;
}

#==========================================
# End "old" methods section
#------------------------------------------

#==========================================
# Private helper methods
#------------------------------------------
sub __addDefaultStripNode {
	# ...
	# if no strip section is setup we add the default
	# section(s) from KIWIConfig.txt
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my $image  = $this->{imgnameNodeList} -> get_node(1);
	my @snodes = $image -> getElementsByTagName ("strip");
	my %attr   = %{$this->getImageTypeAndAttributes_legacy()};
	my $haveDelete = 0;
	my $haveTools  = 0;
	my $haveLibs   = 0;
	#==========================================
	# check if type is boot image
	#------------------------------------------
	if ($attr{"type"} ne "cpio") {
		return $this;
	}
	#==========================================
	# check if there are strip nodes
	#------------------------------------------
	if (@snodes) {
		foreach my $node (@snodes) {
			my $type = $node -> getAttribute("type");
			if ($type eq "delete") {
				$haveDelete = 1;
			} elsif ($type eq "tools") {
				$haveTools = 1;
			} elsif ($type eq "libs") {
				$haveLibs = 1;
			}
		}
	}
	#==========================================
	# read in default strip section
	#------------------------------------------
	my $stripTree;
	my $stripXML = XML::LibXML -> new();
	eval {
		$stripTree = $stripXML
			-> parse_file ( $this->{gdata}->{KStrip} );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  (
			"Problem reading strip file: $this->{gdata}->{KStrip}"
		);
		$kiwi -> failed ();
		$kiwi -> error  ("$evaldata\n");
		return;
	}
	#==========================================
	# append default sections
	#------------------------------------------
	my @defaultStrip = $stripTree
		-> getElementsByTagName ("initrd") -> get_node (1)
		-> getElementsByTagName ("strip");
	foreach my $element (@defaultStrip) {
		my $type = $element -> getAttribute("type");
		if ((! $haveDelete) && ($type eq "delete")) {
			$kiwi -> loginfo ("STRIP: Adding default delete section\n");
			$image -> addChild ($element -> cloneNode (1));
		} elsif ((! $haveLibs) && ($type eq "libs")) {
			$kiwi -> loginfo ("STRIP: Adding default libs section\n");
			$image -> addChild ($element -> cloneNode (1));
		} elsif ((! $haveTools) && ($type eq "tools")) {
			$kiwi -> loginfo ("STRIP: Adding default tools section\n");
			$image -> addChild ($element -> cloneNode (1));
		}
	}
	$this -> updateXML();
	return $this;
}
#==========================================
# __addDefaultSplitNode
#------------------------------------------
sub __addDefaultSplitNode {
	# ...
	# if no split section is setup we add a default section
	# from the contents of the KIWISplit.txt file and apply
	# it to the split types
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my @node   = $this->{optionsNodeList} -> get_nodelist();
	my @tnodes = ();
	my @snodes = ();
	#==========================================
	# store list of all types
	#------------------------------------------
	foreach my $element (@node) {
		my @types = $element -> getElementsByTagName ("type");
		push (@tnodes,@types);
	}
	#==========================================
	# select relevant types w.o. split section
	#------------------------------------------
	foreach my $element (@tnodes) {
		my $image = $element -> getAttribute("image");
		my $flags = $element -> getAttribute("flags");
		if (($image eq "split") || 
			(($image eq "iso") && ($flags) && ($flags eq "compressed"))
		) {
			my @splitsections = $element -> getElementsByTagName ("split");
			if (! @splitsections) {
				push (@snodes,$element);
			}
		}
	}
	#==========================================
	# return if no split types are found
	#------------------------------------------
	if (! @snodes) {
		return $this;
	}
	#==========================================
	# read in default split section
	#------------------------------------------
	my $splitTree;
	my $splitXML = XML::LibXML -> new();
	eval {
		$splitTree = $splitXML
			-> parse_file ( $this->{gdata}->{KSplit} );
	};
	if ($@) {
		my $evaldata=$@;
		$kiwi -> error  (
			"Problem reading split file: $this->{gdata}->{KSplit}"
		);
		$kiwi -> failed ();
		$kiwi -> error  ("$evaldata\n");
		return;
	}
	#==========================================
	# append default section to selected nodes
	#------------------------------------------
	my $defaultSplit = $splitTree
		-> getElementsByTagName ("split") -> get_node(1);
	foreach my $element (@snodes) {
		$element -> addChild (
			$defaultSplit -> cloneNode (1)
		);
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# __getPreferencesNodeByTagName
#------------------------------------------
sub __getPreferencesNodeByTagName {
	# ...
	# Searches in all nodes of the preferences sections
	# and returns the first occurenc of the specified
	# tag name. If the tag can't be found the function
	# returns the first node reference
	# ---
	my $this = shift;
	my $name = shift;
	my @node = $this->{optionsNodeList} -> get_nodelist();
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $tag = $element -> getElementsByTagName ("$name");
		if ($tag) {
			return $element;
		}
	}
	return $node[0];
}

#==========================================
# __getVMConfigOpts
#------------------------------------------
sub __getVMConfigOpts {
	# ...
	# Extract the <vmconfig-entry> information from the
	# XML and return all options in a list
	# ---
	my $this = shift;
	my @configOpts;
	my @configNodes = $this->{systemTree}
		->getElementsByTagName ("vmconfig-entry");
	for my $node (@configNodes) {
		my $value = $node->textContent();
		push @configOpts, $node->textContent();
	}
	return @configOpts;
}

#==========================================
# __hasDefaultProfName
#------------------------------------------
sub __hasDefaultProfName {
	# ...
	# Check whether the default profile name "kiwi_default" is in the
	# provided array ref of strings
	# ---
	my $this      = shift;
	my $profNames = shift;
	my @names = @{$profNames};
	for my $name (@names) {
		if ($name =~ /^kiwi_default$/x) {
			return 1;
		}
	}
	return;
}

#==========================================
# __setOptionsElement
#------------------------------------------
sub __setOptionsElement {
	# ...
	# If given element exists in the data hash, set this
	# element into the current preferences (options) XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $value = $data->{$item};
	$kiwi -> info ("Updating element $item: $value");
	my $addElement = XML::LibXML::Element -> new ("$item");
	$addElement -> appendText ($value);
	my $opts = $this -> __getPreferencesNodeByTagName ("$item");
	my $node = $opts -> getElementsByTagName ("$item");
	if ($node) {
		if ("$node" eq "$value") {
			$kiwi -> done ();
			return $this;
		}
		$node = $node -> get_node(1);
		$opts -> removeChild ($node);
	}
	$opts -> appendChild ($addElement);
	$kiwi -> done ();
	$this -> updateXML();
	return $this;
}

#==========================================
# __addOptionsElement
#------------------------------------------
sub __addOptionsElement {
	# ...
	# add a new element into the current preferences XML tree
	# the data reference must be an array. Each element of the
	# array is processed as new XML element
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $value= $data->{$item};
	if (! $value) {
		return $this;
	}
	foreach my $text (@{$value}) {
		$kiwi -> info ("Adding element $item: $text");
		my $addElement = XML::LibXML::Element -> new ("$item");
		$addElement -> appendText ($text);
		my $opts = $this -> __getPreferencesNodeByTagName ("$item");
		$opts -> appendChild ($addElement);
		$kiwi -> done ();
	}
	$this -> updateXML();
	return $this;
}

#==========================================
# __getStripFileList
#------------------------------------------
sub __getStripFileList {
	# ...
	# return filelist from the strip section referencing $ftype
	# ---
	my $this   = shift;
	my $ftype  = shift;
	my $inode  = $this->{imgnameNodeList} -> get_node(1);
	my @nodes  = $inode -> getElementsByTagName ("strip");
	my @result = ();
	my $tnode;
	if (! @nodes) {
		return @result;
	}
	foreach my $node (@nodes) {
		my $type = $node -> getAttribute ("type");
		if ($type eq $ftype) {
			$tnode = $node; last
		}
	}
	if (! $tnode) {
		return @result;
	}
	my @fileNodeList = $tnode -> getElementsByTagName ("file");
	foreach my $fileNode (@fileNodeList) {
		my $name = $fileNode -> getAttribute ("name");
		push @result, $name;
	}
	return @result;
}

#==========================================
# __setOEMOptionsElement
#------------------------------------------
sub __setOEMOptionsElement {
	# ...
	# If given element exists in the data hash, set this
	# element into the current oemconfig (options) XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $value = $data->{$item};
	my $newconfig = 0;
	$kiwi -> info ("Updating OEM element $item: $value");
	my $addElement = XML::LibXML::Element -> new ("$item");
	$addElement -> appendText ($value);
	my $opts = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $opts) {
		$opts = XML::LibXML::Element -> new ("oemconfig");
		$newconfig = 1;
	}
	my $node = $opts -> getElementsByTagName ("$item");
	if ($node) {
		$node = $node -> get_node(1);
		$opts -> removeChild ($node);
	}
	$opts -> appendChild ($addElement);
	if ($newconfig) {
		$this->{typeNode} -> appendChild ($opts);
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setSystemDiskElement
#------------------------------------------
sub __setSystemDiskElement {
	# ...
	# If given element exists in the data hash, set this
	# element into the current systemdisk XML tree
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $value;
	if (($data) && ($item)) {
		$value = $data->{$item};
	}
	my $newconfig = 0;
	my $addElement;
	if ($item) {
		$kiwi -> info ("Updating SystemDisk element $item: $value");
		$addElement = XML::LibXML::Element -> new ("$item");
		$addElement -> appendText ($value);
	} else {
		$kiwi -> info ("Updating SystemDisk element");
	}
	my $disk = $tnode -> getElementsByTagName ("systemdisk") -> get_node(1);
	if (! defined $disk) {
		$disk = XML::LibXML::Element -> new ("systemdisk");
		$newconfig = 1;
	}
	if ($item) {
		my $node = $disk -> getElementsByTagName ("$item");
		if ($node) {
			$node = $node -> get_node(1);
			$disk -> removeChild ($node);
		}
		$disk -> appendChild ($addElement);
	}
	if ($newconfig) {
		$this->{typeNode} -> appendChild ($disk);
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setMachineAttribute
#------------------------------------------
sub __setMachineAttribute {
	# ...
	# If given element exists in the data hash, set this
	# attribute into the current machine (options) XML tree
	# if no machine section exists create a new one
	# ---
	my $this = shift;
	my $item = shift;
	my $data = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	my $value = $data->{$item};
	my $newconfig = 0;
	$kiwi -> info ("Updating machine attribute $item: $value");
	my $opts = $tnode -> getElementsByTagName ("machine") -> get_node(1);
	if (! defined $opts) {
		$opts = XML::LibXML::Element -> new ("machine");
		$newconfig = 1;
	}
	my $node = $opts -> getElementsByTagName ("$item");
	if ($node) {
		$node = $node -> get_node(1);
		$opts -> removeChild ($node);
	}
	if ($value) {
		$opts-> setAttribute ("$item","$value");
	} else {
		$opts-> setAttribute ("$item","true");
	}
	if ($newconfig) {
		$this->{typeNode} -> appendChild ($opts);
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setTypeAttribute
#------------------------------------------
sub __setTypeAttribute {
	# ...
	# set given attribute to selected type in the
	# xml preferences node
	# ---
	my $this = shift;
	my $attr = shift;
	my $val  = shift;
	my $kiwi = $this->{kiwi};
	my $tnode= $this->{typeNode};
	if ($val) {
		$kiwi -> info ("Updating type attribute: $attr : $val");
		$tnode-> setAttribute ("$attr","$val");
	} else {
		$kiwi -> info ("Updating type attribute: $attr");
		$tnode-> setAttribute ("$attr","true");
	}
	$kiwi -> done ();
	$this -> updateTypeList();
	$this -> updateXML();
	return $this;
}

#==========================================
# __setImageAttribute
#------------------------------------------
sub __setImageAttribute {
	# ...
	# set given attribute to the image section
	# ---
	my $this = shift;
	my $attr = shift;
	my $val  = shift;
	my $kiwi = $this->{kiwi};
	my $inode= $this->{imgnameNodeList} -> get_node(1);
	$kiwi -> info ("Updating image attribute: $attr");
	if ($val) {
		$inode -> setAttribute ("$attr","$val");
	} else {
		$inode -> setAttribute ("$attr","true");
	}
	$kiwi -> done ();
	$this -> updateXML();
	return $this;
}

#==========================================
# __requestedProfile
#------------------------------------------
sub __requestedProfile {
	# ...
	# Return a boolean representing whether or not
	# a given element is requested to be included
	# in this image.
	# ---
	my $this      = shift;
	my $element   = shift;

	if (! defined $element) {
		# print "Element not defined\n";
		return 1;
	}
	#my $nodeName  = $element->nodeName();
	my $profiles = $element -> getAttribute ("profiles");
	if (! defined $profiles) {
		# If no profile is specified, then it is assumed to be in all profiles.
		# print "Section $nodeName always used\n";
		return 1;
	}
	if ((! $this->{reqProfiles}) || ((scalar @{$this->{reqProfiles}}) == 0)) {
		# element has a profile, but no profiles requested so exclude it.
		# print "Section $nodeName profiled, but no profiles requested\n";
		return 0;
	}
	my @splitProfiles = split(/,/, $profiles);
	my %profileHash = ();
	foreach my $profile (@splitProfiles) {
		$profileHash{$profile} = 1;
	}
	if (defined $this->{reqProfiles}) {
		foreach my $reqprof (@{$this->{reqProfiles}}) {
			# strip whitespace
			$reqprof =~ s/^\s+//s;
			$reqprof =~ s/\s+$//s;
			if (defined $profileHash{$reqprof}) {
				# print "Section $nodeName selected\n";
				return 1;
			}
		}
	}
	# print "Section $nodeName not selected\n";
	return 0;
}

#==========================================
# __populateProfiledTypeInfo_legacy
#------------------------------------------
sub __populateProfiledTypeInfo_legacy {
	# ...
	# Store those types from the typeList which are selected
	# by the profiles or the internal 'all' profile and store
	# them in the object internal typeInfo hash:
	# ---
	# typeInfo{imagetype}{attr} = value
	# ---
	my $this     = shift;
	my $kiwi     = $this->{kiwi};
	my %result   = ();
	my %select   = ();
	my $typeList = $this->{typeList};
	my @node     = $this->{optionsNodeList} -> get_nodelist();
	#==========================================
	# create selection according to profiles
	#------------------------------------------
	foreach my $element (@node) {
		if (! $this -> __requestedProfile ($element)) {
			next;
		}
		my $profiles = $element -> getAttribute("profiles");
		my @assigned = ("all");
		if ($profiles) {
			@assigned = split (/,/,$profiles);
		}
		foreach my $p (@assigned) {
			$select{$p} = $p;
		}
	}
	#==========================================
	# select record(s) according to selection
	#------------------------------------------
	foreach my $record (@{$typeList}) {
		my $found = 0;
		my $first = 1;
		foreach my $p (@{$record->{assigned}}) {
			if ($select{$p}) {
				$found = 1; last;
			}
		}
		next if ! $found;
		$record->{first} = $first;
		$result{$record->{type}} = $record;
		$first = 0;
	}
	#==========================================
	# store types in typeInfo hash
	#------------------------------------------
	$this->{typeInfo} = \%result;
	return $this;
}

#==========================================
# __quote
#------------------------------------------
sub __quote {
	my $this = shift;
	my $line = shift;
	$line =~ s/([\"\$\`\\])/\\$1/g;
	return $line;
}

#==========================================
# __resolveLink
#------------------------------------------
sub __resolveLink {
	my $this = shift;
	my $arch = shift;
	my $data = $this -> __resolveArchitecture ($arch);
	my $cdir = qxx ("pwd"); chomp $cdir;
	if (chdir $data) {
		my $pdir = qxx ("pwd"); chomp $pdir;
		chdir $cdir;
		return $pdir
	}
	return $data;
}

#==========================================
# __resolveArchitecture
#------------------------------------------
sub __resolveArchitecture {
	my $this = shift;
	my $path = shift;
	my $arch = $this->{arch};
	if ($arch =~ /i.86/) {
		$arch = "i386";
	}
	$path =~ s/\%arch/$arch/;
	return $path;
}

1;

# vim: set noexpandtab:
