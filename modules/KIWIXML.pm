#================
# FILE          : KIWIXML.pm
#----------------
# PROJECT       : openSUSE Build-Service
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
use File::Basename;
use File::Glob ':glob';
use File::Slurp;
use LWP;
use XML::LibXML;
#==========================================
# KIWI Modules
#------------------------------------------
use KIWIGlobals;
use KIWILocator;
use KIWILog;
use KIWIQX qw (qxx);
use KIWIURL;
use KIWIXMLDescriptionData;
use KIWIXMLDriverData;
use KIWIXMLEC2ConfigData;
use KIWIXMLInstRepositoryData;
use KIWIXMLOEMConfigData;
use KIWIXMLPackageData;
use KIWIXMLPackageArchiveData;
use KIWIXMLPackageCollectData;
use KIWIXMLPackageIgnoreData;
use KIWIXMLPackageProductData;
use KIWIXMLPreferenceData;
use KIWIXMLProductArchitectureData;
use KIWIXMLProductMetaChrootData;
use KIWIXMLProductMetaFileData;
use KIWIXMLProductOptionsData;
use KIWIXMLProductPackageData;
use KIWIXMLProfileData;
use KIWIXMLPXEDeployConfigData;
use KIWIXMLPXEDeployData;
use KIWIXMLRepositoryData;
use KIWIXMLSplitData;
use KIWIXMLStripData;
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
	getInstSourceFile_legacy
	getInstSourceSatSolvable
	getSingleInstSourceSatSolvable
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
	# internal data structure
	#
	# this = {
	#     availableProfiles = ('',....)
	#     defaultType = {
	#         ec2config  = KIWIXMLEC2ConfigData,
	#         machine    = KIWIXMLVMachineData,
	#         oemconfig  = KIWIXMLOEMConfigData,
	#         pxeconfig  = (KIWIXMLPXEDeployConfigData,...),
	#         pxedeploy  = KIWIXMLPXEDeployData,
	#         split      = KIWIXMLSplitData,
	#         systemdisk = KIWIXMLSystemdiskData
	#         type       = KIWIXMLTypeData
	#     },
	#     selectedProfiles = ('',....,'kiwi_default'),
	#     selectedType = {
	#         ec2config  = KIWIXMLEC2ConfigData,
	#         machine    = KIWIXMLVMachineData,
	#         oemconfig  = KIWIXMLOEMConfigData,
	#         pxeconfig  = (KIWIXMLPXEDeployConfigData,...),
	#         pxedeploy  = KIWIXMLPXEDeployData,
	#         split      = KIWIXMLSplitData,
	#         systemdisk = KIWIXMLSystemdiskData
	#         type       = KIWIXMLTypeData
	#     },
	#     imageConfig = {
	#         description = KIWIXMLDescriptionData,
	#         displayName = ''
	#         imageName   = ''
	#         productSettings = {
	#             dudArches      = ('',...)
	#             reqArches      = ('',...)
	#             options        = KIWIXMLProductOptionsData,
	#             architectures  = (KIWIXMLProductArchitectureData,... ),
	#             dudInstSysPkgs = (KIWIXMLProductPackageData,... ),
	#             dudModulePkgs  = (KIWIXMLProductPackageData,... ),
	#             dudPkgs        = (KIWIXMLProductPackageData,... ),
	#             instRepos      = (KIWIXMLInstRepositoryData,... ),
	#             metaChroots    = (KIWIXMLProductMetaChrootData,...),
	#             metaFiles      = (KIWIXMLProductMetaFileData,...),
	#             metaPkgs       = (KIWIXMLProductPackageData,... ),
	#             prodPkgs       = (KIWIXMLProductPackageData,...)
	#         }
	#         <profName>[+] = {
	#             installOpt      = '',
	#             archives        = (KIWIXMLPackageArchiveData,...),
	#             bootArchives    = (KIWIXMLPackageArchiveData,...),
	#             profInfo        = KIWIXMLProfileData
	#             repoData        = (KIWIXMLRepositoryData,...)
	#             bootDelPkgs     = (KIWIXMLPackageData, ...),
	#             bootPkgs        = (KIWIXMLPackageData, ...),
	#             bootPkgsCollect = (KIWIXMLPackageCollectData,...),
	#             bootStrapPckgs  = (KIWIXMLPackageData, ...),
	#             delPkgs         = (KIWIXMLPackageData, ...),
	#             drivers         = (KIWIXMLDriverData, ...),
	#             ignorePkgs      = (KIWIXMLPackageData, ...),
	#             keepLibs        = (KIWIXMLStripData,...),
	#             keepTools       = (KIWIXMLStripData,...),
	#             pkgs            = (KIWIXMLPackageData, ...),
	#             pkgsCollect     = (KIWIXMLPackageCollectData,...),
	#             products        = (KIWIXMLPackageProductData,...),
	#             stripDelete     = (KIWIXMLStripData,...),
	#             <archname>[+] {
	#                 archives        = (KIWIXMLPackageArchiveData,...),
	#                 bootArchives    = (KIWIXMLPackageArchiveData,...),
	#                 bootDelPkgs     = (KIWIXMLPackageData, ...),
	#                 bootPkgs        = (KIWIXMLPackageData, ...),
	#                 bootPkgsCollect = (KIWIXMLPackageCollectData,...),
	#                 bootStrapPckgs  = (KIWIXMLPackageData, ...),
	#                 delPkgs         = (KIWIXMLPackageData, ...),
	#                 drivers         = (KIWIXMLDriverData, ...),
	#                 ignorePkgs      = (KIWIXMLPackageData, ...),
	#                 keepLibs        = (KIWIXMLStripData,...),
	#                 keepTools       = (KIWIXMLStripData,...),
	#                 pkgs            = (KIWIXMLPackageData, ...),
	#                 pkgsCollect     = (KIWIXMLPackageCollectData,...),
	#                 products        = (KIWIXMLPackageProductData,...),
	#                 stripDelete     = (KIWIXMLStripData,...),
	#            }
	#            preferences = {
	#                bootloader_theme     = ''
	#                bootsplash_theme     = ''
	#                defaultdestination   = ''
	#                defaultprebuilt      = ''
	#                defaultroot          = ''
	#                hwclock              = ''
	#                keymap               = ''
	#                locale               = ''
	#                packagemanager       = ''
	#                rpm_check_signatures = ''
	#                rpm_excludedocs      = ''
	#                rpm_force            = ''
	#                showlicense          = ''
	#                timezone             = ''
	#                types                = ''
	#                version
	#                types {
	#                    defaultType = '',
	#                    <typename>[+] {
	#                        ec2config  = KIWIXMLEC2ConfigData,
	#                        machine    = KIWIXMLVMachineData,
	#                        oemconfig  = KIWIXMLOEMConfigData,
	#                        pxeconfig  = (KIWIXMLPXEDeployConfigData,...),
	#                        pxedeploy  = KIWIXMLPXEDeployData,
	#                        split      = KIWIXMLSplitData,
	#                        systemdisk = KIWIXMLSystemdiskData
	#                        type       = KIWIXMLTypeData
	#                    }
	#                }
	#            }
	#            <typename>[+] {
	#                archives = (KIWIXMLPackageArchiveData,....),
	#                <archname>[+] {
	#                    archives        = (KIWIXMLPackageArchiveData,...),
	#                    bootArchives    = (KIWIXMLPackageArchiveData,...),
	#                    bootDelPkgs     = (KIWIXMLPackageData,...),
	#                    bootPkgs        = (KIWIXMLPackageData,...),
	#                    bootPkgsCollect = (KIWIXMLPackageCollectData,...),
	#                    drivers         = (KIWIXMLDriverData),
	#                    ignorePkgs      = (KIWIXMLPackageData,...),
	#                    pkgs            = (KIWIXMLPackageData,...),
	#                    pkgsCollect     = (KIWIXMLPackageCollectData),
	#                    products        = (KIWIXMLPackageProductData,...),
	#                }
	#                bootArchives    = (KIWIXMLPackageArchiveData,...),
	#                bootDelPkgs     = (KIWIXMLPackageData,...),
	#                bootPkgs        = (KIWIXMLPackageData,...),
	#                bootPkgsCollect = (KIWIXMLPackageCollectData,...),
	#                drivers         = (KIWIXMLPackageCollectData,...),
	#                ignorePkgs      = (KIWIXMLPackageData,...),
	#                pkgs            = (KIWIXMLPackageData,...),
	#                pkgsCollect     = (KIWIXMLPackageCollectData,...),
	#                products        = (KIWIXMLPackageCollectData,...),
	#            }
	#            users = (KIWIXMLUserData,...)
	#         }
	#     }
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
	my $imageDesc   = shift;
	my $imageType   = shift;
	my $reqProfiles = shift;
	my $cmdL        = shift;
	my $changeset   = shift;
	#==========================================
	# Constructor setup
	#------------------------------------------
	my $arch = KIWIGlobals -> instance() -> getArch();
	my %supported = map { ($_ => 1) } qw(
		aarch64
		armv5el
		armv5tel
		armv6l
		armv7l
		ia64
		i586
		i686
		ppc
		ppc64
		s390
		s390x
		x86_64
	);
	$this->{supportedArch} = \%supported;
	my $kiwi = KIWILog -> instance();
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
	if (! $cmdL) {
		$kiwi -> error  ('No commandline reference specified');
		$kiwi -> failed ();
		return;
	}
	#==========================================
	# Store object data
	#------------------------------------------
	my $global = KIWIGlobals -> instance();
	$this->{kiwi} = $kiwi;
	$this->{arch} = $arch;
	$this->{gdata}= $global -> getKiwiConfig();
	$this->{cmdL} = $cmdL;
	#==========================================
	# Lookup XML configuration file
	#------------------------------------------
	my $locator = KIWILocator -> instance();
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
		$controlFile,
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
	$this->{stripNodeList}   = $stripNodeList;
	#==========================================
	# Data structure containing the XML file information
	#------------------------------------------
	$this->{imageConfig} = {};
	my @imageNodes = $systemTree -> getElementsByTagName("image");
	my $imgNd = $imageNodes[0]; # Only one <image> node
	my $imgName = $imgNd -> getAttribute('name');
	$this->{imageConfig}{imageName} = $imgName;
	$this->{imageConfig}{displayName} = $imgName;
	my $displayName = $imgNd -> getAttribute('displayname');
	if ($displayName) {
		$this->{imageConfig}{displayName} = $displayName;
	}
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
	# Populate imageConfig with product data from config tree
	#------------------------------------------
	$this -> __populateInstSource();
	#==========================================
	# Populate imageConfig with profile data from config tree
	#------------------------------------------
	$this -> __populateProfileInfo();
	#==========================================
	# Populate imageConfig with driver data from config tree
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
	#==========================================
	# Set build type given by constructor
	#------------------------------------------
	if ($imageType) {
		$this -> setBuildType ($imageType);
	}
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
	# Populate imageConfig with package collection data
	#------------------------------------------
	$this -> __populatePackageCollectionInfo();
	#==========================================
	# Populate imageConfig with product data from config tree
	#------------------------------------------
	$this -> __populatePackageProductInfo();
	#==========================================
	# Populate imageConfig with repository data from config tree
	#------------------------------------------
	$this -> __populateRepositoryInfo();
	#==========================================
	# Populate imageConfig with strip/keep datafrom config tree
	#------------------------------------------
	$this -> __populateStripInfo();
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
	# Store object data
	#------------------------------------------
	$this->{usrdataNodeList}    = $usrdataNodeList;
	$this->{controlFile}        = $controlFile;
	#==========================================
	# Store object data
	#------------------------------------------
	$this -> __updateXML_legacy();
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
	my %verifyData = (
		caller       => 'addDrivers',
		expectedType => 'KIWIXMLDriverData',
		itemName     => 'drivers',
		itemsToAdd   => $drivers,
		profNames    => $profNames
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my $kiwi = $this->{kiwi};
	#==========================================
	# Figure out what profiles to change
	#------------------------------------------
	my @profsToUse = $this -> __getProfsToModify($profNames, 'driver(s)');
	if (! @profsToUse) {
		return;
	}
	my @addedDrivers;
	for my $prof (@profsToUse) {
		for my $drvObj (@{$drivers}) {
			my $arch = $drvObj -> getArch();
			my %storeData = (
			    accessID => 'drivers',
				arch     => $arch,
				dataObj  => $drvObj,
				profName => $prof,
				type     => 'image'
			);
			my $stored = $this -> __storeInstallData(\%storeData);
			if (! $stored) {
				return;
			}
			if (ref $stored eq 'KIWIXMLDriverData') {
				push @addedDrivers, $stored -> getName();
			}
		}
	}
	if (@addedDrivers) {
		$kiwi -> info("Added following drivers:\n");
	}
	for my $name (@addedDrivers) {
		$kiwi -> info("  --> $name\n");
	}
	if (@addedDrivers) {
		$kiwi -> done();
	}
	return $this;
}

#==========================================
# addFilesToDelete
#------------------------------------------
sub addFilesToDelete {
	# ...
	# Add the given StripData objects to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this       = shift;
	my $stripFiles = shift;
	my $profNames  = shift;
	my %verifyData = (
		caller       => 'addFilesToDelete',
		expectedType => 'KIWIXMLStripData',
		itemName     => 'deletefiles',
		itemsToAdd   => $stripFiles,
		profNames    => $profNames
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my $kiwi = $this->{kiwi};
	#==========================================
	# Figure out what profiles to change
	#------------------------------------------
	my @profsToUse = $this -> __getProfsToModify($profNames, 'deletefiles');
	if (! @profsToUse) {
		return;
	}
	for my $prof (@profsToUse) {
		for my $stripObj (@{$stripFiles}) {
			my $arch = $stripObj -> getArch();
			my %storeData = (
			    accessID => 'stripDelete',
				arch     => $arch,
				dataObj  => $stripObj,
				profName => $prof,
				type     => 'image'
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
			}
		}
	}
	return $this;
}

#==========================================
# addLibsToKeep
#------------------------------------------
sub addLibsToKeep {
	# ...
	# Add the given StripData objects to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this       = shift;
	my $stripFiles = shift;
	my $profNames  = shift;
	my %verifyData = (
		caller       => 'addLibsToKeep',
		expectedType => 'KIWIXMLStripData',
		itemName     => 'keeplibs',
		itemsToAdd   => $stripFiles,
		profNames    => $profNames
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my $kiwi = $this->{kiwi};
	#==========================================
	# Figure out what profiles to change
	#------------------------------------------
	my @profsToUse = $this -> __getProfsToModify($profNames, 'keeplibs');
	if (! @profsToUse) {
		return;
	}
	for my $prof (@profsToUse) {
		for my $stripObj (@{$stripFiles}) {
			my $arch = $stripObj -> getArch();
			my %storeData = (
			    accessID => 'keepLibs',
				arch     => $arch,
				dataObj  => $stripObj,
				profName => $prof,
				type     => 'image'
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
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
			. 'KIWIXMLRepositoryData array as first argument';
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
	for my $prof (@profsToUse) {
		REPO:
		for my $repo (@reposToAdd) {
			my $alias                 = $repo -> getAlias();
			my $path                  = $repo -> getPath();
			my $preferlicense         = $repo -> getPreferLicense();
			my ($username, $password) = $repo -> getCredentials();
			my $confRepos = $this->{imageConfig}->{$prof}->{repoData};
			if ($confRepos) {
				# Verify uniqueness conditions
				for my $confRepo (@{$confRepos}) {
					my $confAlias = $confRepo -> getAlias();
					if ($alias && $confAlias && ($alias eq  $confAlias)) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with same alias already '
							. 'exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					my ($confUsr, $confPass) = $confRepo -> getCredentials();
					if ($password && $confPass && $password ne $confPass) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with a different password '
							.  'already exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($path eq $confRepo -> getPath() ) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with same path already '
							. 'exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($preferlicense && $confRepo -> getPreferLicense() ) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with license preference '
							. 'indicator set already exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
					if ($username && $confUsr && $username ne $confUsr) {
						my $msg = 'addRepositories: attempting to add '
							. 'repo, but a repo with a different username '
							. 'already exists';
						$kiwi -> info($msg);
						$kiwi -> skipped();
						next REPO;
					}
				}
				push @{$confRepos}, $repo;
			} else {
				$this->{imageConfig}->{$prof}->{repoData} = [$repo];
			}
		}
	}
	return $this;
}

#==========================================
# addSystemDisk
#------------------------------------------
sub addSystemDisk {
	# ...
	# Add a KIWIXMLSystemdiskData object to the type that is currently
	# the build type.
	# ---
	my $this    = shift;
	my $sysDisk = shift;
	my $kiwi = $this->{kiwi};
	if (! $sysDisk) {
		my $msg = 'addSystemDisk: no systemdisk argument given, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($sysDisk) ne 'KIWIXMLSystemdiskData') {
		my $msg = 'addSystemDisk: expecting KIWIXMLSystemdiskData object '
			. 'as argument, retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{selectedType}->{systemdisk}) {
		my $msg = 'addSystemDisk: overwriting existing system disk '
			. 'information.';
		$kiwi -> info($msg);
		$kiwi -> done();
	}
	$this->{selectedType}->{systemdisk} = $sysDisk;
	return $this;
}

#==========================================
# addToolsToKeep
#------------------------------------------
sub addToolsToKeep {
	# ...
	# Add the given StripData objects to
	#   - the currently active profiles (not default)
	#       ~ if the second argument is undefined
	#   - the default profile
	#       ~ if second argument is the keyword "default"
	#   - the specified profiles
	#       ~ if the second argument is a reference to an array
	# ---
	my $this       = shift;
	my $stripFiles = shift;
	my $profNames  = shift;
	my %verifyData = (
		caller       => 'addToolsToKeep',
		expectedType => 'KIWIXMLStripData',
		itemName     => 'tools',
		itemsToAdd   => $stripFiles,
		profNames    => $profNames
	);
	if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
		return;
	}
	my $kiwi = $this->{kiwi};
	#==========================================
	# Figure out what profiles to change
	#------------------------------------------
	my @profsToUse = $this -> __getProfsToModify($profNames, 'tools');
	if (! @profsToUse) {
		return;
	}
	for my $prof (@profsToUse) {
		for my $stripObj (@{$stripFiles}) {
			my $arch = $stripObj -> getArch();
			my %storeData = (
			    accessID => 'keepTools',
				arch     => $arch,
				dataObj  => $stripObj,
				profName => $prof,
				type     => 'image'
			);
			if (! $this -> __storeInstallData(\%storeData)) {
				return;
			}
		}
	}
	return $this;
}

#==========================================
# discardReplacableRepos
#------------------------------------------
sub discardReplacableRepos {
	# ...
	# Remove all repositories marked as replaceable
	# ---
	my $this = shift;
	my @allProfs;
	if ($this->{availableProfiles}) {
		@allProfs = @{$this->{availableProfiles}};
	}
	push @allProfs, 'kiwi_default';
	for my $profName (@allProfs) {
		my $repos = $this->{imageConfig}{$profName}{repoData};
		if ($repos) {
			my @reducedRepoSet;
			for my $repo (@{$repos}) {
				if ($repo -> getStatus() ne 'replaceable') {
					push @reducedRepoSet, $repo;
				}
			}
			$this->{imageConfig}{$profName}{repoData} = \@reducedRepoSet;
		}
	}
	return $this ;
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
	# /.../
	# Filter out any package which is marked to become
	# replaced by another package
	# ----
	for my $pckg (@{$bPckgs}) {
		my $toReplace = $pckg -> getPackageToReplace();
		if ($toReplace) {
			$pckgFilter{$toReplace} = 1;
		}
	}
	# /.../
	# Create list, filter out if marked in pckgFilter
	# ----
	my @bootInclPackages;
	for my $pckg (@{$bPckgs}) {
		my $name = $pckg -> getName();
		if ($pckgFilter{$name}) {
			next;
		}
		push @bootInclPackages, $pckg;
	}
	return \@bootInclPackages;
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
			my @names = keys %{
				$this->{imageConfig}->{$profName}->{preferences}->{types}
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
	return $this->{imageConfig}->{description};
}

#==========================================
# getDrivers
#------------------------------------------
sub getDrivers {
	# ...
	# Return an array ref containing DriverData objects for the current
	# selected build profile(s)
	# ---
	my $this = shift;
	return $this -> __getInstallData('drivers');
}

#==========================================
# getBootProfile
#------------------------------------------
sub getBootProfile {
	my $this = shift;
	my $type = $this->{selectedType}->{type};
	return $type -> getBootProfile();
}

#==========================================
# getBootKernel
#------------------------------------------
sub getBootKernel {
	my $this = shift;
	my $type = $this->{selectedType}->{type};
	return $type -> getBootKernel();
}

#==========================================
# getDUDArchitectures
#------------------------------------------
sub getDUDArchitectures {
	# ...
	# Return an array ref containing strings indicating the driver update
	# disk architectures.
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{dudArches};
	}
	return;
}

#==========================================
# getDUDInstallSystemPackages
#------------------------------------------
sub getDUDInstallSystemPackages {
	# ...
	# Return an array ref containing ProductPackageData objects
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{dudInstSysPkgs};
	}
	return;
}

#==========================================
# getDUDModulePackages
#------------------------------------------
sub getDUDModulePackages {
	# ...
	# Return an array ref containing ProductPackageData objects
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{dudModulePkgs};
	}
	return;
}

#==========================================
# getDUDPackages
#------------------------------------------
sub getDUDPackages {
	# ...
	# Return an array ref containing ProductPackageData objects
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{dudPkgs};
	}
	return;
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
	return $this->{selectedType}->{ec2config};
}

#==========================================
# getFilesToDelete
#------------------------------------------
sub getFilesToDelete {
	# ...
	# Return an array ref containing StripData objects for the current
	# selected build profile(s)
	# ---
	my $this = shift;
	return $this -> __getInstallData('stripDelete');
}

#==========================================
# getImageDisplayName
#------------------------------------------
sub getImageDisplayName {
	# ...
	# Get the display name of the logical extend
	# ---
	my $this = shift;
	return $this->{imageConfig}->{displayName};
}

#==========================================
# getImageName
#------------------------------------------
sub getImageName {
	# ...
	# Return the configured image name
	# ---
	my $this = shift;
	return $this->{imageConfig}->{imageName};
}

#==========================================
# getImageType
#------------------------------------------
sub getImageType {
	# ...
	# Return a TypeData object for the selected build type
	# ---
	my $this = shift;
	return $this->{selectedType}->{type};
}

#==========================================
# getInstallOption
#------------------------------------------
sub getInstallOption {
	# ...
	# Return the install option type setting. Returns undef if there is
	# a conflict and thus the settings are ambiguous.
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
# getLibsToKeep
#------------------------------------------
sub getLibsToKeep {
	# ...
	# Return an array ref containing StripData objects for the current
	# selected build profile(s)
	# ---
	my $this = shift;
	return $this -> __getInstallData('keepLibs');
}

#==========================================
# getOEMConfig
#------------------------------------------
sub getOEMConfig {
	# ...
	# Return a OEMConfigData object for the selected build type
	# ---
	my $this = shift;
	return $this->{selectedType}->{oemconfig};
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
	my $prefObj = KIWIXMLPreferenceData -> new($mergedPref);
	return $prefObj;
}

#==========================================
# getProductArchitectures
#------------------------------------------
sub getProductArchitectures {
	# ...
	# Return an array ref of ProductArchitectureData objects.
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{architectures};
	}
	return;
}

#==========================================
# getProductMetaChroots
#------------------------------------------
sub getProductMetaChroots {
	# ...
	# Return an array ref of ProductMetaChrootData objects specified as
	# metadata.
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{metaChroots};
	}
	return;
}

#==========================================
# getProductMetaFiles
#------------------------------------------
sub getProductMetaFiles {
	# ...
	# Return an array ref of ProductMetaFileData objects specified as
	# metadata.
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{metaFiles};
	}
	return;
}

#==========================================
# getProductMetaPackages
#------------------------------------------
sub getProductMetaPackages {
	# ...
	# Return an array ref of ProductPackageData objects specified as
	# metadata.
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{metaPkgs};
	}
	return;
}

#==========================================
# getProductOptions
#------------------------------------------
sub getProductOptions {
	# ...
	# Return a ProductOptionsData object providing all information from
	# <productinfo>, <productoption>, and <productvar> elements.
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{options};
	}
	return;
}

#==========================================
# getProductRepositories
#------------------------------------------
sub getProductRepositories {
	# ...
	# Return an array ref of InstRepositoryData objects
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{instRepos};
	}
	return;
}

#==========================================
# getProductRequiredArchitectures
#------------------------------------------
sub getProductRequiredArchitectures {
	# ...
	# Return an array ref of strings indicating the required architectures
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{reqArches};
	}
	return;
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
# getProductSourcePackages
#------------------------------------------
sub getProductSourcePackages  {
	# ...
	# Return an array ref of ProductPackageData objects
	# ---
	my $this = shift;
	if ($this->{imageConfig}->{productSettings}) {
		return $this->{imageConfig}->{productSettings}->{prodPkgs};
	}
	return;
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
	if (! $this->{availableProfiles}) {
		return \@result;
	}
	for my $prof (@{$this->{availableProfiles}}) {
		push @result, $this->{imageConfig}->{$prof}->{profInfo};
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
	return $this->{selectedType}->{pxedeploy};
}

#==========================================
# getPXEConfigData
#------------------------------------------
sub getPXEConfigData {
	# ...
	# Return an array ref containing PXEDeployConfigData objects for
	# current build type.
	# ---
	my $this = shift;
	return $this->{selectedType}->{pxeconfig};
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
		if ($this->{imageConfig}->{$prof}->{repoData}) {
			push @repoData, @{$this->{imageConfig}->{$prof}->{repoData}};
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
	return $this->{selectedType}->{split};
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
	return $this->{selectedType}->{systemdisk};
}

#==========================================
# getToolsToKeep
#------------------------------------------
sub getToolsToKeep {
	# ...
	# Return an array ref containing StripData objects for the current
	# selected build profile(s)
	# ---
	my $this = shift;
	return $this -> __getInstallData('keepTools');
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
				my $tObj = $types->{$tname}->{type};
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
	my %uAccounts;
	for my $pName (@{$this->{selectedProfiles}}) {
		next if ! $this->{imageConfig}{$pName}{users};
		my @profUsers = @{$this->{imageConfig}{$pName}{users}};
		for my $user (@profUsers) {
			my $name = $user -> getUserName();
			if ($uAccounts{$name}) {
				my $mergedUser =
					$this -> __mergeUsers($uAccounts{$name}, $user);
				if (! $mergedUser) {
					return;
				}
				$uAccounts{$name} = $mergedUser;
			} else {
				$uAccounts{$name} = $user
			}
		}
	}
	my @users;
	for my $user (values %uAccounts) {
		push @users, $user;
	}

	return \@users;
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
	return $this->{selectedType}->{machine};
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
	my @allProfs;
	$kiwi -> info ('Ignoring all repositories previously configured');
	if ($this->{availableProfiles}) {
		@allProfs = @{$this->{availableProfiles}};
	}
	push @allProfs, 'kiwi_default';
	for my $profName (@allProfs) {
		if ($this->{imageConfig}->{$profName}->{repoData}) {
			delete $this->{imageConfig}->{$profName}->{repoData}
		}
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
	$this->{imageConfig}{description} = $xmlDescripDataObj;
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
	# Overwrite the first repository marked as replaceable for the
	# currently active profiles, the search starts with the default
	# profile
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
	# The default profile needs to be the first to be searched
	my @profsToSearch = ('kiwi_default');
	for my $prof (@profsToUse) {
		if ($prof eq 'kiwi_default') {
			next;
		}
		push @profsToSearch, $prof;
	}
	my $foundReplacable;
	PROFILE:
	for my $prof (@profsToSearch) {
		my $repoRef = $this->{imageConfig}{$prof}->{repoData};
		if ($repoRef) {
			my $repoIdx = 0;
			my @confRepos = @{$repoRef};
			for my $cRepo (@confRepos) {
				my $repl = $cRepo -> getStatus();
				if ($repl eq 'replaceable') {
					my $replRepoPath = $cRepo -> getPath();
					$kiwi -> info ("Replacing repository $replRepoPath");
					$kiwi -> done();
					$confRepos[$repoIdx] = $repo;
					$this->{imageConfig}{$prof}->{repoData} = \@confRepos;
					$foundReplacable = 1;
					last PROFILE;
				}
				$repoIdx += 1;
			}
		}
	}
	if (!$foundReplacable) {
		my $path = $repo-> getPath();
		my $msg = 'No replaceable repository configured, not using repo with '
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
		delete $this->{availableProfiles}; # repopulated below
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
	if ($info) {
		$kiwi -> info ("Using profile(s): $info");
		$kiwi -> done ();
	}
	if (! $this->__hasDefaultProfName($profiles) ) {
		push @newProfs, 'kiwi_default';
	}
	$this->{selectedProfiles} = \@newProfs;
	return $this;
}

#==========================================
# updateType
#------------------------------------------
sub updateType {
	# ...
	# Modify the type that is currently the build type
	# ---
	my $this = shift;
	my $type = shift;
	my $kiwi = $this->{kiwi};
	if (! $type) {
		my $msg = 'updateType: no type argument given, retaining '
			. 'current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (ref($type) ne 'KIWIXMLTypeData') {
		my $msg = 'updateType: expecting KIWIXMLTypeData object as argument, '
			. 'retaining current data.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$this->{selectedType}->{type} = $type;
	return $this;;
}

#==========================================
# writeXML
#------------------------------------------
sub writeXML {
	# ...
	# Write the configuration to the given path
	# Writes the XML in formated format
	# ---
	my $this = shift;
	my $path = shift;
	my $kiwi = $this->{kiwi};
	if (! $path) {
		my $msg = 'writeXML expecting path as argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $imgName = $this -> getImageName();
	my $xml = '<?xml version="1.0" encoding="utf-8"?>'
		. '<image schemaversion="' . $this -> __getSchemaVersion()
		. '" name="' . $imgName . '"';
	my $displName = $this -> getImageDisplayName();
	if ($displName && $displName ne $imgName) {
		$xml .= ' displayname="' . $displName . '"';
	}
	$xml .= '>';
	#==========================================
	# Add description data
	#------------------------------------------
	$xml .= $this -> getDescriptionInfo() -> getXMLElement() -> toString();
	#==========================================
	# Add the <profiles> data if needed
	#------------------------------------------
	my @profiles = @{$this -> getProfiles()};
	my $numProfs = scalar @profiles;
	if ($numProfs) {
		$xml .= '<profiles>';
		for my $prof (@profiles) {
			$xml .= $prof -> getXMLElement() -> toString();
		}
		$xml .= '</profiles>';
	}
	my @profsToProc = ('kiwi_default');
	if ($this->{availableProfiles}) {
		push @profsToProc, @{$this->{availableProfiles}};
	}
	#==========================================
	# Add <preference> data
	#------------------------------------------
	for my $profName (@profsToProc) {
		my $prefElem = $this -> __getPreferencesXMLElement($profName);
		if ($prefElem) {
			if ($profName ne 'kiwi_default') {
				$prefElem -> setAttribute('profiles', $profName);
			}
			$xml .= $prefElem -> toString();
		}
	}
	#==========================================
	# Add <users>,<repository> data
	#------------------------------------------
	my @data = qw (users repoData);
	for my $dataName (@data) {
		for my $profName (@profsToProc) {
			my $entry = $this->{imageConfig}{$profName}{$dataName};
			if ($entry) {
				my @items = @{$entry};
				for my $item (@items) {
					my $elem = $item -> getXMLElement();
					if ($profName ne 'kiwi_default') {
						$elem -> setAttribute('profiles', $profName);
					}
					$xml .= $elem -> toString();
				}
			}
		}
	}
	#==========================================
	# Add <drivers>
	#------------------------------------------
	my $defDrivers = $this -> __collectDefaultData('drivers');
	if ($defDrivers) {
		$xml .= '<drivers>';
		for my $drvObj (@{$defDrivers}) {
			$xml .= $drvObj -> getXMLElement() -> toString();
		}
		$xml .= '</drivers>';
	}
	my $driverCollection = $this -> __collectDriverData();
	for my $profNames (keys %{$driverCollection}) {
		$xml .= '<drivers profiles="' . $profNames . '">';
		my $drivers = $driverCollection->{$profNames};
		for my $drvObj (@{$drivers}) {
			$xml .= $drvObj -> getXMLElement() -> toString();
		}
		$xml .= '</drivers>';
	}
	#==========================================
	# Add <packages>,<archives>,<products>
	#------------------------------------------
	my @pckgsItems;
	my @collectData = qw (
		archives
		bootArchives
		pkgsCollect
		bootPkgsCollect
		products
		pkgs
		bootPkgs
		bootDelPkgs
	);
	for my $collect (@collectData) {
		my $data = $this -> __collectDefaultData($collect);
		if ($data) {
			push @pckgsItems, @{$data};
		}
	}
	if (@pckgsItems) {
		$xml .= '<packages type="image"';
		my $instOpt = $this->{imageConfig}{kiwi_default}{installOpt};
		if ($instOpt) {
			$xml .= ' patternType="' . $instOpt . '"';
		}
		$xml .= '>';
		my %usedNames;
		for my $item (@pckgsItems) {
			my $name = $item -> getName();
			if (! $usedNames{$name}) {
				$usedNames{$name} = 1;
				$xml .= $item -> getXMLElement() -> toString();
			}
		}
		$xml .= '</packages>';
	}
	my $pkgsCollect = $this -> __collectPackagesData();
	$xml .= $this -> __createPackageCollectionDataXML($pkgsCollect, 'image');
	#==========================================
	# Add type=[type] specific packages
	#------------------------------------------
	my @imgTypes = qw (
		btrfs
		clicfs
		cpio
		ext2
		ext3
		ext4
		iso
		oem
		pxe
		reiserfs
		split
		squashfs
		tbz
		vmx
		xfs
		zfs
	);
	for my $imgType (@imgTypes) {
		my @typePckgItems;
		for my $collect (@collectData) {
			my $data = $this -> __collectDefaultData($collect, $imgType);
			if ($data) {
				push @typePckgItems, @{$data};
			}
		}
		if (@typePckgItems) {
			$xml .= '<packages type="' . $imgType . '">';
		}
		for my $item (@typePckgItems) {
			$xml .= $item -> getXMLElement() -> toString();
		}
		if (@typePckgItems) {
			$xml .= '</packages>';
		}
	}
	for my $imgType (@imgTypes) {
		my $pkgsCollect = $this -> __collectPackagesData($imgType);
		$xml .=
			$this -> __createPackageCollectionDataXML($pkgsCollect, $imgType);
	}
	#==========================================
	# Add type=delete packages
	#------------------------------------------
	my $defDelPckgs = $this -> __collectDefaultData('delPkgs');
	if ($defDelPckgs) {
		$xml .= '<packages type="delete">';
		for my $dPckg (@{$defDelPckgs}) {
			$xml .= $dPckg -> getXMLElement() -> toString();
		}
		$xml .= '</packages>';
	}
	my $delPkgsCollect = $this -> __collectDeletePackagesData();
	for my $profNames (keys %{$delPkgsCollect}) {
		$xml .= '<packages type="delete" profiles="' . $profNames . '">';
		my $pacObjs = $delPkgsCollect->{$profNames};
		for my $pacObj (@{$pacObjs}) {
			$xml .= $pacObj -> getXMLElement() -> toString();
		}
		$xml .= '</packages>';
	}
	#==========================================
	# Add bootstrap packages
	#------------------------------------------
	my $bootStrapPckgs = $this -> __collectDefaultData('bootStrapPckgs');
	if ($bootStrapPckgs) {
		$xml .= '<packages type="bootstrap">';
		for my $bPckg (@{$bootStrapPckgs}) {
			$xml .= $bPckg -> getXMLElement() -> toString();
		}
		$xml .= '</packages>';
	}
	my $bootPkgsCollect = $this -> __collectBootStrapPackagesData();
	for my $profNames (keys %{$bootPkgsCollect}) {
		$xml .= '<packages type="bootstrap" profiles="' . $profNames . '">';
		my $pacObjs = $bootPkgsCollect->{$profNames};
		for my $pacObj (@{$pacObjs}) {
			$xml .= $pacObj -> getXMLElement() -> toString();
		}
		$xml .= '</packages>';
	}
	#==========================================
	# Add <strip> data
	#------------------------------------------
	my %nameAccessMap = (
		delete => 'stripDelete',
		libs   => 'keepLibs',
		tools  => 'keepTools'
	);
	my @stripTypes = keys %nameAccessMap;
	@stripTypes = sort @stripTypes;
	for my $sType (@stripTypes) {
		my $access = $nameAccessMap{$sType};
		my $stripData = $this -> __collectDefaultData($access);
		if ($stripData) {
			$xml .= '<strip type="' . $sType . '">';
			for my $stripObj (@{$stripData}) {
				$xml .= $stripObj -> getXMLElement() -> toString();
			}
			$xml .= '</strip>';
		}
		my $stripDataCollect = $this -> __collectStripData($access);
		for my $profNames (keys %{$stripDataCollect}) {
			$xml .= '<strip type="' . $sType . '" '
				. 'profiles="' . $profNames . '">';
			my $stripObjs = $stripDataCollect->{$profNames};
			for my $stripObj (@{$stripObjs}) {
				$xml .= $stripObj -> getXMLElement() -> toString();
			}
			$xml .= '</strip>';
		}
	}
	$xml .= '</image>';
	#==========================================
	# Write the file
	#------------------------------------------
	my $status = open (my $XMLFL, '>', $path);
	if (! $status) {
		my $msg = "Could not open file '$path' for writing";
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	binmode($XMLFL, ":encoding(UTF-8)");
	print $XMLFL $xml;
	close $XMLFL;
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __collectBootStrapPackagesData
#------------------------------------------
sub __collectBootStrapPackagesData {
	# ...
	# Collect and coalesce data for the <packages type="bootstrap">
	# ---
	my $this = shift;
	return $this -> __collectXMLListData('bootStrapPckgs');
}

#==========================================
# __collectDefaultData
#------------------------------------------
sub __collectDefaultData {
	# ...
	# Collect data for the default profile for the given storage location
	# in the data strcuture
	# ---
	my $this    = shift;
	my $access  = shift;
	my $imgType = shift;
	if (! $access) {
		my $kiwi = $this->{kiwi};
		my $msg = 'KIWIXML:__collectDefaultData called without data access '
			. 'location. Internal error, please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @data;
	my $defData;
	if ($imgType) {
		$defData = $this->{imageConfig}{kiwi_default}{$imgType}{$access};
	} else {
		$defData = $this->{imageConfig}{kiwi_default}{$access};
	}
	if ($defData) {
		push @data, @{$defData};
	}
	for my $arch (keys %{$this->{supportedArch}}) {
		my $archEntry;
		if ($imgType) {
			$archEntry = $this->{imageConfig}{kiwi_default}{$imgType}{$arch};
		} else {
			$archEntry = $this->{imageConfig}{kiwi_default}{$arch};
		}
		if ($archEntry) {
			my $defArchdata = $archEntry->{$access};
			if ($defArchdata) {
				push @data, @{$defArchdata};
			}
		}
	}
	if (scalar @data > 0) {
		return \@data;
	}
	return;
}

#==========================================
# __collectDeletePackagesData
#------------------------------------------
sub __collectDeletePackagesData {
	# ...
	# Collect and coalesce data for the <packages type="delete">
	# ---
	my $this = shift;
	return $this -> __collectXMLListData('delPkgs');
}

#==========================================
# __collectDriverData
#------------------------------------------
sub __collectDriverData {
	# ...
	# Collect and coalesce data for the <drivers> list
	# ---
	my $this = shift;
	return $this -> __collectXMLListData('drivers');
}

#==========================================
# __collectPackagesData
#------------------------------------------
sub __collectPackagesData {
	# ...
	# Collect and coalesce data for the <packages type="image"> list
	# ---
	my $this = shift;
	my $imgT = shift;
	my $collection     =
		$this -> __collectXMLListData('archives', $imgT);
	my $bootArchives   =
		$this -> __collectXMLListData('bootArchives', $imgT);
	my $pkgCollect     =
		$this -> __collectXMLListData('pkgsCollect', $imgT);
	my $bootPkgCollect =
		$this -> __collectXMLListData('bootPkgsCollect', $imgT);
	my $products       =
		$this -> __collectXMLListData('products', $imgT);
	my $pkgs           =
		$this -> __collectXMLListData('pkgs', $imgT);
	my $bootPkgs       =
		$this -> __collectXMLListData('bootPkgs', $imgT);
	my $bootDelPkgs    =
		$this -> __collectXMLListData('bootDelPkgs', $imgT);
	my @mergeItems = (
		$bootArchives,
		$pkgCollect,
		$bootPkgCollect,
		$products,
		$pkgs,
		$bootPkgs,
		$bootDelPkgs
	);
	for my $mergeItem (@mergeItems) {
		for my $profName (keys %{$mergeItem}) {
			if ($collection->{$profName}) {
				push @{$collection->{$profName}}, @{$mergeItem->{$profName}};
			} else {
				$collection->{$profName} = $mergeItem->{$profName};
			}
		}
	}
	return $collection;
}

#==========================================
# __collectStripData
#------------------------------------------
sub __collectStripData {
	# ...
	# Collect strip data for the given access pattern
	# ---
	my $this   = shift;
	my $access = shift;
	if (! $access) {
		my $kiwi = $this->{kiwi};
		my $msg = 'KIWIXML:__collectStripData called with data access '
			. 'argument. Internal error please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	return $this -> __collectXMLListData($access);
}

#==========================================
# __collectXMLListData
#------------------------------------------
sub __collectXMLListData {
	# ...
	# Collect and coalesce data that is part of a list in XML
	# Items to be collected must have a getName method.
	# ---
	my $this    = shift;
	my $dataT   = shift;
	my $imgType = shift;
	if (! $dataT) {
		my $kiwi = $this->{kiwi};
		my $msg = 'KIWIXML:__collectXMLListData called with data access '
			. 'argument. Internal error please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my %dataMap;
	my %nameProfMap;
	if (! $this->{availableProfiles}) {
		return \%dataMap;
	}
	for my $profName (@{$this->{availableProfiles}}) {
		my @allData;
		my $items;
		if ($imgType) {
			$items = $this->{imageConfig}{$profName}{$imgType}{$dataT};
		} else {
			$items = $this->{imageConfig}{$profName}{$dataT};
		}
		if ($items) {
			push @allData, $items;
		}
		# Collect architecture specific data
		for my $arch (keys %{$this->{supportedArch}}) {
			my $archData;
			if ($imgType) {
				$archData = $this->{imageConfig}{$profName}{$imgType}{$arch};
			} else {
				$archData = $this->{imageConfig}{$profName}{$arch};
			}
			if ($archData) {
				my $archItems = $archData->{$dataT};
				if ($archItems) {
					push @allData, $archItems;
				}
			}
		}
		if (@allData) {
			for my $items (@allData) {
				for my $obj (@{$items}) {
					my $name = $obj -> getName();
					if ($nameProfMap{$name}) {
						push @{$nameProfMap{$name}{profs}}, $profName;
					} else {
						my @profNames = ($profName);
						my %entry = (
							obj   => $obj,
							profs => \@profNames
						);
						$nameProfMap{$name} = \%entry;
					}
				}
			}
		}
	}
	for my $name (keys %nameProfMap) {
		my $profNames = join ',', @{$nameProfMap{$name}{profs}};
		my $obj = $nameProfMap{$name}{obj};
		if ($dataMap{$profNames}) {
			push @{$dataMap{$profNames}}, $obj;
		} else {
			my @items = ($obj);
			$dataMap{$profNames} = \@items;
		}
	}
	return \%dataMap;
}

#==========================================
# __convertSizeStrToMBVal
#------------------------------------------
sub __convertSizeStrToMBVal {
	# ...
	# Convert a given size string that contains M or G into a value
	# that is a representation in MB.
	# ---
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
# __createEC2Config
#------------------------------------------
sub __createEC2Config {
	# ...
	# Return a ref to a hash that contains the EC2 configuration data for the
	# given XML:ELEMENT object. Build a data structure that matches the
	# structure defined in KIWIXMLEC2ConfigData
	# ---
	my $this = shift;
	my $node = shift;
	my $kiwi = $this->{kiwi};
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
	my $ec2Obj = KIWIXMLEC2ConfigData -> new(\%ec2ConfigData);
	return $ec2Obj;
}

#==========================================
# __createOEMConfig
#------------------------------------------
sub __createOEMConfig {
	# ...
	# Return a ref to a hash containing the configuration for <oemconfig>
	# of the given XML:ELEMENT object. Build a data structure that
	# matches the structure defined in
	# KIWIXMLOEMConfigData
	# ---
	my $this = shift;
	my $node = shift;
	my $kiwi = $this->{kiwi};
	my $oemConfNode = $node -> getChildrenByTagName('oemconfig');
	if (! $oemConfNode ) {
		return;
	}
	my $config = $oemConfNode -> get_node(1);
	my %oemConfig;
	$oemConfig{oem_align_partition}      =
		$this -> __getChildNodeTextValue($config, 'oem-align-partition');
	$oemConfig{oem_ataraid_scan}         =
		$this -> __getChildNodeTextValue($config, 'oem-ataraid-scan');
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
	$oemConfig{oem_silent_install}          =
		$this -> __getChildNodeTextValue($config, 'oem-silent-install');
	$oemConfig{oem_silent_verify}          =
		$this -> __getChildNodeTextValue($config, 'oem-silent-verify');
	$oemConfig{oem_skip_verify}          =
		$this -> __getChildNodeTextValue($config, 'oem-skip-verify');
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
	my $oemConfObj = KIWIXMLOEMConfigData -> new(\%oemConfig);
	return $oemConfObj;
}

#==========================================
# __createPackageCollectionDataXML
#------------------------------------------
sub __createPackageCollectionDataXML {
	# ...
	# Add data from a collection to the given string
	# ---
	my $this       = shift;
	my $pkgsCollect = shift;
	my $imgType    = shift;
	my $kiwi = $this->{kiwi};
	my $xml = q{};
	if (! $pkgsCollect) {
		my $msg = 'KIWIXML:__addCollectionDataToStr called without '
			. 'collection. Internal error please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $imgType) {
		my $msg = 'KIWIXML:__addCollectionDataToStr called without '
			. 'image type. Internal error please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my @writeSeparated;
	COLLECTION:
	for my $profNames (keys %{$pkgsCollect}) {
		# Verify that the patternType value matches
		my @names = split /,/msx, $profNames;
		my $instOpt;
		for my $pName (@names) {
			my $iOption = $this->{imageConfig}{$pName}{installOpt};
			if ($iOption && $instOpt && $iOption ne $instOpt) {
				# patternType does not match write as separate entries
				push @writeSeparated, $profNames;
				next COLLECTION;
			} elsif ($iOption) {
				$instOpt = $iOption;
			}
		}
		# Add the data to the XML
		$xml .= '<packages type="' . $imgType . '" '
		. 'profiles="' . $profNames . '"';
		if ($instOpt) {
			$xml .= ' patternType="' . $instOpt . '"';
		}
		$xml .= '>';
		my $pacObjs = $pkgsCollect->{$profNames};
		for my $pacObj (@{$pacObjs}) {
			$xml .= $pacObj -> getXMLElement() -> toString();
		}
		$xml .= '</packages>';
	}
	for my $profNames (@writeSeparated) {
		my @names = split /,/msx, $profNames;
		my $pacObjs = $pkgsCollect->{$profNames};
		for my $pName (@names) {
			my $iOption = $this->{imageConfig}{$pName}{installOpt};
			$xml .= '<packages type="' . $imgType . '" '
			. 'profiles="' . $pName . '" '
			. 'patternType="' . $iOption. '">';
			for my $pacObj (@{$pacObjs}) {
				$xml .= $pacObj -> getXMLElement() -> toString();
			}
			$xml .= '</packages>';
		}
	}
	return $xml;
}

#==========================================
# __createProductOptions
#------------------------------------------
sub __createProductOptions {
	# ...
	# Return a KIWIXMLProductOptionsData object created from the
	# <productoptions> data in the given <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @pOptParentNodes =
		$instSrcNode -> getElementsByTagName('productoptions');
	my $optNode = $pOptParentNodes[0]; #only 1 child
	my %prodinfo;
	my @prodInfoNodes = $optNode -> getElementsByTagName('productinfo');
	for my $infoN (@prodInfoNodes) {
		my $key = $infoN -> getAttribute('name');
		$prodinfo{$key} = $infoN -> textContent();
	}
	my %productoption;
	my @prodOptNodes = $optNode -> getElementsByTagName('productoption');
	for my $optN (@prodOptNodes) {
		my $key = $optN -> getAttribute('name');
		$productoption{$key} = $optN -> textContent();
	}
	my %productvar;
	my @prodVarNodes = $optNode -> getElementsByTagName('productvar');
	for my $varN (@prodVarNodes) {
		my $key = $varN -> getAttribute('name');
		$productvar{$key} = $varN -> textContent();
	}
	my %init = (
		productinfo   => \%prodinfo,
		productoption => \%productoption,
		productvar    => \%productvar
	);
	my $prodOptObj = KIWIXMLProductOptionsData -> new(\%init);
	if (! $prodOptObj) {
		$kiwi -> error('KIWIXMLProductOptionsData creation');
			$kiwi -> failed();
			return;
	}
	return $prodOptObj;
}

#==========================================
# __createPXEDeployConfig
#------------------------------------------
sub __createPXEDeployConfig {
	# ...
	# Return a KIWIXMLPXEDeployData object created from the information
	# in the <pxedeploy> element of the given XML:ELEMENT object.
	# ---
	my $this = shift;
	my $node = shift;
	my $kiwi = $this->{kiwi};
	my %pxeConfig;
	my $pxeDeployNode = $node -> getChildrenByTagName('pxedeploy');
	if (! $pxeDeployNode ) {
		return;
	}
	my $pxeNode = $pxeDeployNode -> get_node(1);
	$pxeConfig{blocksize} = $pxeNode -> getAttribute('blocksize');
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
	my $pxeConfObj = KIWIXMLPXEDeployData -> new(\%pxeConfig);
	return $pxeConfObj;
}

#==========================================
# __createPXEDeployConfigData
#------------------------------------------
sub __createPXEDeployConfigData {
	# ...
	# Return an array ref to an array containing KIWIXMLPXEDeployConfigData
	# objects. Created from the information
	# in the <pxedeploy> element of the given XML:ELEMENT object.
	# ---
	my $this = shift;
	my $node = shift;
	my $kiwi = $this->{kiwi};
	my %pxeConfigData;
	my $pxeDeployNode = $node -> getChildrenByTagName('pxedeploy');
	if (! $pxeDeployNode ) {
		return;
	}
	my @pxeConfigs;
	my $pxeNode = $pxeDeployNode -> get_node(1);
	my @configNodes = $pxeNode -> getChildrenByTagName('configuration');
	for my $confNd (@configNodes) {
		my $archDef = $confNd -> getAttribute('arch');
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
			$pxeConfigData{arch} = $archDef;
		}
		$pxeConfigData{dest}   = $confNd -> getAttribute('dest');
		$pxeConfigData{source} = $confNd -> getAttribute('source');
		push @pxeConfigs, KIWIXMLPXEDeployConfigData -> new(\%pxeConfigData);
	}
	return \@pxeConfigs
}

#==========================================
# __createSplitData
#------------------------------------------
sub __createSplitData {
	# ...
	# Return a ref to a hash containing the configuration for <split>
	# of the given XML:ELEMENT object. Build a data structure that
	# matches the structure defined in KIWIXMLSplitData
	# ---
	my $this = shift;
	my $node = shift;
	my $kiwi = $this->{kiwi};
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
	my $splitDataObj = KIWIXMLSplitData -> new(\%splitConf);
	return $splitDataObj;
}

#==========================================
# __createSystemDiskData
#------------------------------------------
sub __createSystemDiskData {
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
	my $sysDiskObj = KIWIXMLSystemdiskData -> new(\%lvmData);
	return $sysDiskObj;
}

#==========================================
# __createVMachineConfig
#------------------------------------------
sub __createVMachineConfig {
	# ...
	# Return a ref to a hash that contains the configuration data
	# for the <machine> element and it's children for the
	# given XML:ELEMENT object
	# ---
	my $this = shift;
	my $node = shift;
	my $kiwi = $this->{kiwi};
	my $vmConfig = $node -> getChildrenByTagName('machine') -> get_node(1);
	if (! $vmConfig ) {
		return;
	}
	my %vmConfigData;
	$vmConfigData{HWversion}  = $vmConfig -> getAttribute('HWversion');
	$vmConfigData{arch}       = $vmConfig -> getAttribute('arch');
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
	my $vmConfObj = KIWIXMLVMachineData -> new(\%vmConfigData);
	return $vmConfObj;
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
	$Data::Dumper::Terse  = 1;
	$Data::Dumper::Indent = 1;
	$Data::Dumper::Useqq  = 1;
	my $dd = Data::Dumper->new([ %{$this->{imageConfig}} ]);
	my $cd = $dd->Dump();
	return $cd;
}

#==========================================
# __genDUDInstSysPkgsArray
#------------------------------------------
sub __genDUDInstSysPkgsArray {
	# ...
	# Return a ref to an array containing ProductPackageData
	# objects created from the <repopackage> children of the <instsys> data
	# of the XML from the given <driverupdate> node.
	# ---
	my $this    = shift;
	my $dudNode = shift;
	my @instSysNodes = $dudNode -> getElementsByTagName('instsys');
	my @pkgs;
	if (@instSysNodes) {
		my $iSysPkgs = $this -> __genRepoPackagesArray($instSysNodes[0]);
		if (! $iSysPkgs) {
			return;
		}
		@pkgs = @{$iSysPkgs};
	}
	return \@pkgs;
}

#==========================================
# __genDUDModulePkgsArray
#------------------------------------------
sub __genDUDModulePkgsArray {
	# ...
	# Return a ref to an array containing ProductPackageData
	# objects created from the <repopackage> children of the <modules> data
	# of the XML from the given <driverupdate> node.
	# ---
	my $this    = shift;
	my $dudNode = shift;
	my @moduleNodes = $dudNode -> getElementsByTagName('modules');
	my @pkgs;
	if (@moduleNodes) {
		my $modPkgs = $this -> __genRepoPackagesArray($moduleNodes[0]);
		if (! $modPkgs) {
			return;
		}
		@pkgs = @{$modPkgs};
	}
	return \@pkgs;
}

#==========================================
# __genDUDPkgsArray
#------------------------------------------
sub __genDUDPkgsArray {
	# ...
	# Return a ref to an array containing ProductPackageData
	# objects created from the <repopackage> children of the <install> data
	# of the XML from the given <driverupdate> node.
	# ---
	my $this    = shift;
	my $dudNode = shift;
	my @installNodes = $dudNode -> getElementsByTagName('install');
	my @pkgs;
	if (@installNodes) {
		my $instPkgs = $this -> __genRepoPackagesArray($installNodes[0]);
		if (! $instPkgs) {
			return;
		}
		@pkgs = @{$instPkgs};
	}
	return \@pkgs;
}

#==========================================
# __genInstRepoArray
#------------------------------------------
sub __genInstRepoArray {
	# ...
	# Return a ref to an array containing InstRepositoryData objects
	# created from the <instrepo> data of the XML from the given
	# <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @repos;
	my @repoNodes = $instSrcNode -> getElementsByTagName('instrepo');
	for my $repo (@repoNodes) {
		my @sourceNodes = $repo -> getElementsByTagName('source');
		my $path = $sourceNodes[0] -> getAttribute('path'); # Only 1 child
		my %init = (
			local    => $repo -> getAttribute('local'),
			name     => $repo -> getAttribute('name'),
			password => $repo -> getAttribute('password'),
			path     => $path,
			priority => $repo -> getAttribute('priority'),
			username => $repo -> getAttribute('username')
		);
		my $instRepo = KIWIXMLInstRepositoryData -> new(\%init);
		if (! $instRepo) {
			$kiwi -> error('KIWIXMLInstRepositoryData creation');
			$kiwi -> failed();
			return;
		}
		push @repos, $instRepo;
	}
	return \@repos;
}

#==========================================
# __genMetadataChrootArray
#------------------------------------------
sub __genMetadataChrootArray {
	# ...
	# Return a ref to an array containing ProductMetaChrootData objects
	# created from the <chroot> data of the XML from the given
	# <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @cRoots;
	my @metaNodes = $instSrcNode -> getElementsByTagName('metadata');
	my @chrootNodes = $metaNodes[0] -> getElementsByTagName('chroot');
	for my $crNd (@chrootNodes) {
		my %cRinit = (
			requires => $crNd -> getAttribute('requires'),
			value    => $crNd -> textContent()
		);
		my $metaChroot = KIWIXMLProductMetaChrootData -> new(\%cRinit);
		if (! $metaChroot) {
			$kiwi -> error('KIWIXMLProductMetaChrootData creation');
			$kiwi -> failed();
			return;
		}
		push @cRoots, $metaChroot;
	}
	return \@cRoots;
}

#==========================================
# __genMetadataFileArray
#------------------------------------------
sub __genMetadataFileArray{
	# ...
	# Return a ref to an array containing ProductMetaFileData objects
	# created from the <metafile> data of the XML from the given
	# <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @fileData;
	my @metaNodes = $instSrcNode -> getElementsByTagName('metadata');
	my @fileNodes = $metaNodes[0] -> getElementsByTagName('metafile');
	for my $fileNd (@fileNodes) {
		my %mFinit = (
			script => $fileNd -> getAttribute('script'),
			target => $fileNd -> getAttribute('target'),
			url    => $fileNd -> getAttribute('url')
		);
		my $metaFile = KIWIXMLProductMetaFileData -> new(\%mFinit);
		if (! $metaFile) {
			$kiwi -> error('KIWIXMLProductMetaFileData creation');
			$kiwi -> failed();
			return;
		}
		push @fileData, $metaFile;
	}
	return \@fileData;
}

#==========================================
# __genMetadataPkgsArray
#------------------------------------------
sub __genMetadataPkgsArray {
	# ...
	# Return a ref to an array containing ProductPackageData objects
	# created from the <repopackage> data of the XML from the given
	# <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @pkgs;
	my @metaNodes = $instSrcNode -> getElementsByTagName('metadata');
	my @pkgNodes = $metaNodes[0] -> getElementsByTagName('repopackage');
	for my $pckgNd (@pkgNodes) {
		my %init = (
			arch       => $pckgNd -> getAttribute('arch'),
			addarch    => $pckgNd -> getAttribute('addarch'),
		    forcerepo  => $pckgNd -> getAttribute('forcerepo'),
		    medium     => $pckgNd -> getAttribute('medium'),
			name       => $pckgNd -> getAttribute('name'),
		    onlyarch   => $pckgNd -> getAttribute('onlyarch'),
		    removearch => $pckgNd -> getAttribute('removearch'),
		    script     => $pckgNd -> getAttribute('script'),
		    source     => $pckgNd -> getAttribute('source')
		);
		my $prodPkg = KIWIXMLProductPackageData -> new(\%init);
		if (! $prodPkg) {
			$kiwi -> error('KIWIXMLProductPackageData creation');
			$kiwi -> failed();
			return;
		}
		push @pkgs, $prodPkg;
	}
	return \@pkgs;
}

#==========================================
# __genProductArchitectureArray
#------------------------------------------
sub __genProductArchitectureArray {
	# ...
	# Return a ref to an array containing ProductArchitectureData
	# objects created from the <arch> data of the XML from the given
	# <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @archParentNodes =
		$instSrcNode -> getElementsByTagName('architectures');
	my @arches;
	if (@archParentNodes) {
		my @archNodes = $archParentNodes[0] -> getElementsByTagName('arch');
		for my $archN (@archNodes) {
			my %init = (
				fallback => $archN -> getAttribute('fallback'),
				id       => $archN -> getAttribute('id'),
				name     => $archN -> getAttribute('name')
			);
			my $archObj = KIWIXMLProductArchitectureData -> new(\%init);
			if (! $archObj) {
				$kiwi -> error('KIWIXMLProductArchitectureData creation');
				$kiwi -> failed();
				return;
			}
			push @arches, $archObj;
		}
	}
	return \@arches;
}

#==========================================
# __genProductPackagesArray
#------------------------------------------
sub __genProductPackagesArray {
	# ...
	# Return a ref to an array containing ProductPackageData
	# objects created from the <repopackage> data of the XML from the given
	# <instsource> node.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my @pkgsParentNodes =
		$instSrcNode -> getElementsByTagName('repopackages');
	my @pkgs;
	for my $pPNd (@pkgsParentNodes) {
		my $rPkgs = $this -> __genRepoPackagesArray($pPNd);
		push @pkgs, @{$rPkgs};
	}
	return \@pkgs;
}

#==========================================
# __genProductReqArchArray
#------------------------------------------
sub __genProductReqArchArray {
	# ...
	# Return a ref to an array containing strings identifying the required
	# architectures.
	# ---
	my $this        = shift;
	my $instSrcNode = shift;
	my $kiwi = $this -> {kiwi};
	my @archNodes = $instSrcNode -> getElementsByTagName('architectures');
	my @reqArches;
	if (@archNodes) {
		my @reqArchNodes = $archNodes[0]
			-> getElementsByTagName('requiredarch');
		for my $reqArchNd (@reqArchNodes) {
			push @reqArches, $reqArchNd -> getAttribute('ref');
		}
	}
	return \@reqArches;
}

#==========================================
# __genRepoPackagesArray
#------------------------------------------
sub __genRepoPackagesArray {
	# ...
	# Return a ref to an array containing ProductPackageData objects
	# created from the <repopackage> children of the given node.
	# ---
	my $this     = shift;
	my $parentNd = shift;
	my $kiwi = $this->{kiwi};
	my @pkgNodes = $parentNd -> getElementsByTagName('repopackage');
	my @pkgs;
	for my $pkgNd (@pkgNodes) {
		my %init = (
			arch       => $pkgNd -> getAttribute('arch'),
			addarch    => $pkgNd -> getAttribute('addarch'),
		    forcerepo  => $pkgNd -> getAttribute('forcerepo'),
		    medium     => $pkgNd -> getAttribute('medium'),
			name       => $pkgNd -> getAttribute('name'),
		    onlyarch   => $pkgNd -> getAttribute('onlyarch'),
		    removearch => $pkgNd -> getAttribute('removearch'),
		    script     => $pkgNd -> getAttribute('script'),
		    source     => $pkgNd -> getAttribute('source')
		);
		my $prodPkg = KIWIXMLProductPackageData -> new(\%init);
		if (! $prodPkg) {
			$kiwi -> error('KIWIXMLProductPackageData creation');
			$kiwi -> failed();
			return;
		}
		push @pkgs, $prodPkg;
	}
	return \@pkgs;
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
	my $kiwi = $this->{kiwi};
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
		'container',
		'devicepersistency',
		'editbootconfig',
		'editbootinstall',
		'filesystem',
		'firmware',
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
		'mdraid',
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
		my $typeName = $type -> getAttribute('image');
		#==========================================
		# store a value for the primary attribute
		#------------------------------------------
		my $prim = $type -> getAttribute('primary');
		if ($prim && $prim eq 'true') {
			$typeData{primary} = 'true';
			$defaultType = $typeName;
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
		my $ec2Config = $this -> __createEC2Config($type);
		#==========================================
		# store <machine> child
		#------------------------------------------
		my $vmConfig = $this -> __createVMachineConfig($type);
		#==========================================
		# store <oemconfig> child
		#------------------------------------------
		my $oemConfig = $this -> __createOEMConfig($type);
		#==========================================
		# store <size>...</size> text and attributes
		#------------------------------------------
		$typeData{size} = $this -> __getChildNodeTextValue($type, 'size');
		my @sizeNodes = $type -> getChildrenByTagName('size');
		if (@sizeNodes) {
			my $sizeNd = $sizeNodes[0];
			$typeData{sizeadd} = $sizeNd -> getAttribute('additive');
			$typeData{sizeunit} = $sizeNd -> getAttribute('unit');
		}
		#==========================================
		# store <pxeconfig> child
		#------------------------------------------
		my $pxeConfig = $this -> __createPXEDeployConfig($type);
		#==========================================
		# store <configuration>, child of <pxeconfig>
		#==========================================
		my $pxeConfigData = $this -> __createPXEDeployConfigData($type);
		if ($pxeConfigData && $pxeConfigData == -1) {
			return -1;
		}
		#==========================================
		# store <split> child
		#------------------------------------------
		my $splitData = $this -> __createSplitData($type);
		if ($splitData && $splitData == -1) {
			return -1;
		}
		#==========================================
		# store <systemdisk> child
		#------------------------------------------
		my $sysDisk = $this -> __createSystemDiskData($type);
		if ($sysDisk && $sysDisk == -1) {
			return -1;
		}
		#==========================================
		# store this type in %types
		#------------------------------------------
		my $typeObj = KIWIXMLTypeData -> new(\%typeData);
		my %curType = (
			ec2config  => $ec2Config,
			machine    => $vmConfig,
			oemconfig  => $oemConfig,
			pxeconfig  => $pxeConfigData,
			pxedeploy  => $pxeConfig,
			split      => $splitData,
			systemdisk => $sysDisk,
			type       => $typeObj
		);
		$types{$typeData{image}} = \%curType;
	}
	$types{defaultType} = $defaultType;
	return \%types;
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
	# Return the position in the imageConfig structure where
	# install data objects shold be stored. Install data objects
	# are children of the <packages> or <driver> elements
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
	my $type = $this->{selectedType}{type};
	my $typeName = $type -> getTypeName();
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
		my $typeInfo = $this->{imageConfig}{$prof}{$typeName};
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
# __getPreferencesXMLElement
#------------------------------------------
sub __getPreferencesXMLElement {
	# ...
	# Return a complete preferences element for the given profile name
	# ---
	my $this     = shift;
	my $profName = shift;
	if (! $profName) {
		my $kiwi = $this->{kiwi};
		my $msg = 'KIWIXML:__getPreferencesXMLElement internal error, called '
			. 'without profile name, please file a bug.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	my $prefs = $this->{imageConfig}{$profName}{preferences};
	my $prefElem;
	if ($prefs) {
		my $prefsObj = KIWIXMLPreferenceData -> new($prefs);
		$prefElem = $prefsObj -> getXMLElement();
		my $types = $this->{imageConfig}{$profName}{preferences}{types};
		if ($types) {
			# The default type needs to be first, create a type processing
			# array
			my $defType = $types->{defaultType};
			my @typeSpecs = keys %{$types};
			my @procTypes = ($defType);
			for my $t (@typeSpecs) {
				if ($t ne $defType && $t ne 'defaultType') {
					push @procTypes, $t;
				}
			}
			# Process all children of the <type> element
			my @typeChildren = qw (
				ec2config
				machine
				oemconfig
				split
				systemdisk
			);
			my $tElem;
			for my $typeName (@procTypes) {
				my $typE = $types->{$typeName};
				$tElem = $types->{$typeName}{type} -> getXMLElement();
				for my $child (@typeChildren) {
					if ($types->{$typeName}{$child}) {
						my $chObj = $types->{$typeName}{$child};
						my $cElement =
							$types->{$typeName}{$child} -> getXMLElement();
						$tElem  -> addChild($cElement);
					}
				}
				# PXE is special
				if ($types->{$typeName}{pxedeploy}) {
					my $pxeDElem =
						$types->{$typeName}{pxedeploy} -> getXMLElement();
					if ($types->{$typeName}{pxeconfig}) {
						my @pxeConfigs = @{$types->{$typeName}{pxeconfig}};
						for my $pxeC (@pxeConfigs) {
							my $pxeCElem = $pxeC -> getXMLElement();
							$pxeDElem  -> addChild($pxeCElem);
						}
					}
					$tElem -> addChild($pxeDElem);
				}
				$prefElem -> addChild($tElem);
			}
		}
	}
	return $prefElem;
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
		if (! @profsToUse) {
			# Only the default profile is affected by change
			@profsToUse = ('kiwi_default');
		}
	}
	return @profsToUse;
}

#==========================================
# __getSchemaVersion
#------------------------------------------
sub __getSchemaVersion {
	# ...
	# Return the schema version extracted from KIWISchema.rnc
	# ---
	my $this = shift;
	my $locator = KIWILocator -> instance();
	my $schema = $this->{gdata}->{Schema};
	my @lines = read_file($schema);
	my $useNextValue;
	my $version = q{};
	for my $ln (@lines) {
		if ($ln =~ /k.image.schemaversion.attribute/msg) {
			$useNextValue = 1;
		}
		if ($useNextValue && $ln =~ /<value>(\d+\.\d+)<\/value>/msx) {
			$version = $1;
			last;
		}
	}
	return $version;
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
# __mergeUsers
#------------------------------------------
sub __mergeUsers {
	# ...
	# Merge the given UserData objects. The data from the second user
	# passed is subsumed by the first user object.
	# ---
	my $this  = shift;
	my $user1 = shift;
	my $user2 = shift;
	my $kiwi = $this->{kiwi};
	my $name = $user1 -> getUserName();
	my $msg = "Merging data for user '$name'";
	$kiwi -> info($msg);
	my $mergedUser = $user1 -> merge($user2);
	if (! $mergedUser) {
		my $msg = 'User merge error';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	$kiwi -> done();
	return $mergedUser;
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
		my @profsToProcess = ('kiwi_default');
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
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
				my $archiveObj = KIWIXMLPackageArchiveData -> new(\%archData);
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
	my $kiwi = $this->{kiwi};
	my $descrNode = $this->{systemTree}
		-> getElementsByTagName ('description')
		-> get_node(1);
	my $author  = $this
		-> __getChildNodeTextValue ($descrNode, 'author');
	my @contactNodes = $descrNode -> getElementsByTagName ('contact');
	my @contacts;
	for my $contNd (@contactNodes) {
		push @contacts, $contNd -> textContent();
	}
	my $spec    = $this
		-> __getChildNodeTextValue($descrNode,'specification');
	my $type    = $descrNode
		-> getAttribute ('type');
	my %descript = (
		author        => $author,
		contact       => \@contacts,
		specification => $spec,
		type          => $type
	);
	my $descriptObj = KIWIXMLDescriptionData -> new (\%descript);
	$this->{imageConfig}{description} = $descriptObj;
	return $this;
}

#==========================================
# __populateInstsrc
#------------------------------------------
sub __populateInstSource {
	# ...
	# Populate the imageConfig member with the
	# product data provided with the <instsource> element and its children
	#  from the XML file.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @instNodes = $this->{systemTree} -> getElementsByTagName ('instsource');
	my $instSrc = $instNodes[0]; # Only 1 element allowed
	if ($instSrc) {
		my $arches = $this -> __genProductArchitectureArray($instSrc);
		if (! $arches) {
			return;
		}
		my @dudNodes = $instSrc -> getElementsByTagName('driverupdate');
		my @dudArches;
		my $dudInstSysPkgs;
		my $dudModulePkgs;
		my $dudPkgs;
		if (@dudNodes) {
			my @targetNodes = $dudNodes[0] -> getElementsByTagName('target');
			for my $tgt (@targetNodes) {
				push @dudArches, $tgt -> getAttribute('arch');
			}
			$dudInstSysPkgs = $this -> __genDUDInstSysPkgsArray($dudNodes[0]);
			if (! $dudInstSysPkgs) {
				return;
			}
			$dudModulePkgs = $this -> __genDUDModulePkgsArray($dudNodes[0]);
			if (! $dudModulePkgs) {
				return;
			}
			$dudPkgs = $this -> __genDUDPkgsArray($dudNodes[0]);
			if (! $dudPkgs) {
				return;
			}
		}
		my $instRepos = $this -> __genInstRepoArray($instSrc);
		if (! $instRepos) {
			return;
		}
		my @metaNodes = $instSrc -> getElementsByTagName('metadata');
		my $metaChroots;
		my $metaFiles;
		my $metaPkgs;
		if (@metaNodes) {
			$metaChroots = $this -> __genMetadataChrootArray($instSrc);
			if (! $metaChroots) {
				return;
			}
			$metaFiles = $this -> __genMetadataFileArray($instSrc);
			if (! $metaFiles) {
				return;
			}
			$metaPkgs  = $this -> __genMetadataPkgsArray($instSrc);
			if (! $metaPkgs) {
				return;
			}
		}
		my $prodOpts = $this -> __createProductOptions($instSrc);
		if (! $prodOpts) {
			return;
		}
		my $prodPkgs = $this -> __genProductPackagesArray($instSrc);
		if (! $prodPkgs) {
			return;
		}
		my $reqArches = $this -> __genProductReqArchArray($instSrc);
		if (! $reqArches) {
			return;
		}
		my %prodSettings = (
			architectures  => $arches,
			dudArches      => \@dudArches,
			dudInstSysPkgs => $dudInstSysPkgs,
			dudModulePkgs  => $dudModulePkgs,
			dudPkgs        => $dudPkgs,
			instRepos      => $instRepos,
			metaChroots    => $metaChroots,
			metaFiles      => $metaFiles,
			metaPkgs       => $metaPkgs,
			options        => $prodOpts,
			prodPkgs       => $prodPkgs,
			reqArches      => $reqArches
		);
		$this->{imageConfig}{productSettings} = \%prodSettings;
	}
	return 1;
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
	my $kiwi = $this->{kiwi};
	my @drvNodes = $this->{systemTree} -> getElementsByTagName ('drivers');
	for my $drvNd (@drvNodes) {
		my $profiles = $drvNd -> getAttribute('profiles');
		my @profsToProcess = ('default');
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		}
		my @driverNodes = $drvNd -> getElementsByTagName ('file');
		for my $prof (@profsToProcess) {
			if ($prof eq 'default') {
				$prof = 'kiwi_default';
			}
			for my $dNd (@driverNodes) {
				my $arch = $dNd -> getAttribute('arch');
				my $name = $dNd -> getAttribute('name');
				my %drvData = (
					arch => $arch,
					name => $name
				);
				my $drvObj = KIWIXMLDriverData -> new(\%drvData);
				my %storeData = (
					accessID => 'drivers',
					arch     => $arch,
					dataObj  => $drvObj,
					profName => $prof,
					type     => 'image'
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
		my @profsToProcess = ('kiwi_default');
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
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
				my $ignoreObj = KIWIXMLPackageIgnoreData -> new(\%ignoreData);
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
		my @profsToProcess = ('kiwi_default');
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
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
				my $pckgObj = KIWIXMLPackageData -> new(\%pckgData);
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
	# information from <namedCollection>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess = ('kiwi_default');
		if ($profiles) {
			@profsToProcess = split /,/smx, $profiles;
		}
		my $type = $pckgNd -> getAttribute('type');
		my @collectNodes = $pckgNd -> getElementsByTagName('namedCollection');
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
					-> new(\%collectData);
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
# __populatePackageProductInfo
#------------------------------------------
sub __populatePackageProductInfo {
	# ...
	# Populate the imageConfig member with the
	# information from <opensuseProduct>
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @pckgsNodes = $this->{systemTree} -> getElementsByTagName('packages');
	for my $pckgNd (@pckgsNodes) {
		my $profiles = $pckgNd -> getAttribute('profiles');
		my @profsToProcess = ('kiwi_default');
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
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
					\%productData
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
	my $kiwi = $this->{kiwi};
	my $reqp = $this->{reqProfiles};
	my @selectProfs = ('kiwi_default');
	my $reqp_count  = 0;
	#==========================================
	# add commandline selected profiles
	#------------------------------------------
	if ($reqp) {
		$reqp_count = @{$reqp};
		if ($reqp_count > 0) {
			push @selectProfs,@{$reqp};
		}
	}
	#==========================================
	# walk through profiles from XML
	#------------------------------------------
	my @profNodes = $this->{systemTree} -> getElementsByTagName ('profile');
	if (@profNodes ) {
		my @availableProfiles;
		for my $element (@profNodes) {
			#==========================================
			# extract attributes
			#------------------------------------------
			my $descript = $element -> getAttribute ('description');
			my $import   = $element -> getAttribute ('import');
			my $profName = $element -> getAttribute ('name');
			push @availableProfiles, $profName;
			#==========================================
			# insert into internal data structure
			#------------------------------------------
			my %profile = (
				description => $descript,
				import      => $import,
				name        => $profName
			);
			$this->{imageConfig}{$profName}{profInfo} =
				KIWIXMLProfileData -> new(\%profile);
			#==========================================
			# add import=true profiles to selected
			#------------------------------------------
			# add only if no profile was selected on the commandline
			if (($reqp_count == 0) && ($import && $import eq 'true')) {
				push @selectProfs,$profName;
			}
		}
		#==========================================
		# store available profile list from XML
		#------------------------------------------
		$this->{availableProfiles} = \@availableProfiles;
	}
	#==========================================
	# store selected profile list
	#------------------------------------------
	$this->{selectedProfiles} = \@selectProfs;
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
	my $kiwi = $this->{kiwi};
	my @repoNodes = $this->{systemTree}
		-> getElementsByTagName ('repository');
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
		$repoData{distribution}  = $repoNode
			-> getAttribute ('distribution');
		$repoData{components}    = $repoNode
			-> getAttribute ('components');
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
		my $repo = KIWIXMLRepositoryData -> new (\%repoData);
		for my $profName (@profNames) {
			my $repoRef = $this->{imageConfig}->{$profName}->{repoData};
			if (! $repoRef) {
				my @repos = ($repo);
				$this->{imageConfig}->{$profName}->{repoData} = \@repos;
			} else {
				push @{$repoRef}, $repo;
			}
		}
	}
	return $this;
}

#==========================================
# __populateStripInfo
#------------------------------------------
sub __populateStripInfo {
	# ...
	# Populate the imageConfig member with the strip data from the XML file.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @stripNodes = $this->{systemTree} -> getElementsByTagName ('strip');
	for my $stripNd (@stripNodes) {
		my $profiles = $stripNd -> getAttribute('profiles');
		my @profsToProcess = ('kiwi_default');
		if ($profiles) {
			@profsToProcess = split /,/, $profiles;
		}
		my $access;
		my $type = $stripNd -> getAttribute('type');
		if ($type eq 'delete') {
			$access = 'stripDelete';
		} elsif ($type eq 'libs') {
			$access = 'keepLibs';
		} elsif ($type eq 'tools') {
			$access = 'keepTools';
		} else {
			my $msg = '__populateStripInfo: internal error, found type other '
				. 'than "delete, libs, or tools". Please file a bug.';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		my @stripFiles = $stripNd -> getElementsByTagName ('file');
		for my $prof (@profsToProcess) {
			for my $sNd (@stripFiles) {
				my $arch = $sNd -> getAttribute('arch');
				my $name = $sNd -> getAttribute('name');
				my %stripData = (
					arch => $arch,
					name => $name
				);
				my $stripObj = KIWIXMLStripData -> new(\%stripData);
				my %storeData = (
					accessID => $access,
					arch     => $arch,
					dataObj  => $stripObj,
					profName => $prof,
					type     => 'image'
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
# __populateUserInfo
#------------------------------------------
sub __populateUserInfo {
	# ...
	# Populate the imageConfig member with the
	# user data from the XML file.
	# ---
	my $this = shift;
	my @userGrpNodes = $this->{systemTree} -> getElementsByTagName('users');
	for my $grpNode (@userGrpNodes) {
		my $profs = $grpNode -> getAttribute('profiles');
		my @profiles = ('kiwi_default');
		if ($profs) {
			@profiles = split /,/smx, $profs;
		}
		for my $pName (@profiles) {
			my %curUsers;
			if ($this->{imageConfig}{$pName}{users}) {
				my @prevDefUsers = @{$this->{imageConfig}{$pName}{users}};
				for my $user (@prevDefUsers) {
					my $name = $user -> getUserName();
					$curUsers{$name} = $user;
				}
			}
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
					passwd       => $userNode -> getAttribute('password'),
					passwdformat => $userNode -> getAttribute('pwdformat'),
					realname     => $userNode -> getAttribute('realname'),
					shell        => $userNode -> getAttribute('shell'),
					userid       => $userNode -> getAttribute('id')
			    );
				my $user = KIWIXMLUserData -> new(\%info);
				if ($curUsers{$name}) {
					my $mergedUser =
						$this -> __mergeUsers($curUsers{$name}, $user);
					if (! $mergedUser) {
						return;
					}
					$curUsers{$name} = $mergedUser;
				} else {
					$curUsers{$name} = $user;
				}
			}
			my @users;
			for my $user (values %curUsers) {
				push @users, $user;
			}
			$this->{imageConfig}{$pName}{users} = \@users;
		}
	}
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
		my $type = $defType->{type};
		my $prim = $type -> getPrimary();
		if ($prim && $prim eq 'true') {
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
		my $profDefType = $this->{imageConfig}
			->{$profName}->{preferences}->{types}
			->{$profDefTypeName};
		my $type = $profDefType->{type};
		if (! $type) {
			return;
		}
		my $profDefTypeIsPrim = $type -> getPrimary();
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
			$defType = $profDefType;
		}
		if (! $defType) {
			$defType = $profDefType;
		}
	}
	$this->{selectedType} = $defType;
	return $this;
}

#==========================================
# __storeInstallData
#------------------------------------------
sub __storeInstallData {
	# ...
	# Store the given install data object in the proper
	# location in the data structure. Install data objects
	# are objects of children of the <packages> or <driver>
	# elements. If the object was stored, return the object
	# If th object was already present return 1
	# ---
	my $this       = shift;
	my $storeInfo  = shift;
	my $accessID   = $storeInfo->{accessID};
	my $arch       = $storeInfo->{arch};
	my $objToStore = $storeInfo->{dataObj};
	my $profName   = $storeInfo->{profName};
	my $type       = $storeInfo->{type};
	my $kiwi       = $this->{kiwi};
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
	my $stored = 1;
	if ($entryPath->{$accessID}) {
		my %definedNames = map { ($_->getName() => 1) }
			@{$entryPath->{$accessID}};
		my $name = $objToStore -> getName();
		if (! $definedNames{$name}) {
			push @{$entryPath->{$accessID}}, $objToStore;
			$stored = $objToStore;
		}
	} else {
		my @data = ($objToStore);
		$entryPath->{$accessID} = \@data;
		$stored = $objToStore;
	}
	return $stored;
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
	if (! $this->{availableProfiles}) {
		return 1;
	}
	my %specProfs = map { ($_ => 1 ) } @{$this->{availableProfiles}};
	for my $name (@namesToCheck) {
		if ($name eq 'kiwi_default') {
			next;
		}
		if (! $specProfs{$name} ) {
			my $kiwi = $this->{kiwi};
			$msg =~ s/PROF_NAME/$name/;
			$kiwi -> error ($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
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
# setBootProfiles
#------------------------------------------
sub setBootProfiles {
	my $this = shift;
	my $bootprofile = shift;
	my $bootkernel  = shift;
	my $type = $this->{selectedType}->{type};
	my $name = $type->getTypeName();
	if ($name ne 'cpio') {
		return;
	}
	my @list = ('kiwi_default');
	if (($bootprofile) && ($bootprofile ne 'default')) {
		push @list, split (/,/,$bootprofile);
	}
	if ($bootkernel) {
		push @list, split (/,/,$bootkernel);
	} else {
		# apply 'std' kernel profile required for boot images
		push @list, "std";
	}
	$this->{selectedProfiles} = \@list;
	return $this;
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
	$this -> __updateXML_legacy();
	return $this;
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
# getInstSourceSatSolvable
#------------------------------------------
sub getInstSourceSatSolvable {
	# /.../
	# This function will return a hash containing the
	# solvable and repo url per repo
	# ----
	my $repos = shift;
	my %index = ();
	#==========================================
	# create solvable/repo index
	#------------------------------------------
	foreach my $repo (@{$repos}) {
		my $solvable = getSingleInstSourceSatSolvable ($repo);
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
	my $repo = shift;
	my $kiwi = KIWILog -> instance();
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
	$patterns{"/repodata/patterns.xml"}     = "projectxml";
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
		if (KIWIXML::getInstSourceFile_legacy ($repo.$md,$repoMD)) {
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
		if (KIWIXML::getInstSourceFile_legacy ($repo.$dist,$destfile)) {
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
		if ($patt =~ /\.gz$/) {
			$destfile = $sdir."/$name-".$count.".gz";
		} else {
			$destfile = $sdir."/$name-".$count;
		}
		my $ok = KIWIXML::getInstSourceFile_legacy ($repo.$patt,$destfile);
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
				if (! KIWIXML::getInstSourceFile_legacy($file,$destfile)) {
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
			qxx ("gzip -t $file &>/dev/null");
			my $code = $? >> 8;
			if ($code == 0) {
				$gzicmd .= $file." ";
			} else {
				$stdcmd .= $file." ";
			}
		}
		foreach my $file (glob ("$sdir/*.pat*")) {
			qxx ("gzip -t $file &>/dev/null");
			my $code = $? >> 8;
			if ($code == 0) {
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
	if (glob ("$sdir/projectxml-*")) {
		my $gzicmd = "gzip -cd ";
		my $stdcmd = "cat ";
		my $data;
		my $code;
		foreach my $file (glob ("$sdir/projectxml-*")) {
			$destfile = $sdir."/primary-".$count;
			if ($file =~ /\.gz$/) {
				$gzicmd .= $file." ";
				$data = qxx ("$gzicmd | rpmmd2solv > $destfile 2>&1");
			} else {
				$stdcmd .= $file." ";
				$data = qxx ("$stdcmd | rpmmd2solv > $destfile 2>&1");
			}
			$code = $? >> 8;
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
	} else {
		qxx ("rm -f $index*");
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
	$this -> __updateXML_legacy();
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
	$this -> __updateXML_legacy();
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
		my $addElement = XML::LibXML::Element -> new ("namedCollection");
		$addElement -> setAttribute("name",$pack);
		$nodes -> get_node($nodeNumber)
			-> appendChild ($addElement);
	}
	$this -> __updateXML_legacy();
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
	if (($splash) && ("$splash" ne "")) {
		$result[0] = $splash;
	}
	if (($loader) && ("$loader" ne "")) {
		$result[1] = $loader;
	}
	return @result;
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
	# bootincluded items (packs,archives)
	#------------------------------------------
	my @bincl = $this -> getBootIncludes_legacy();
	if (@bincl) {
		$result{kiwi_fixedpackbootincludes} = join(" ",@bincl);
	}
	#==========================================
	# strip section data (tools,libs,delete)
	#------------------------------------------
	my $s_delref = $this -> getFilesToDelete();
	if ($s_delref) {
		my @s_del;
		foreach my $stripdata (@{$s_delref}) {
			push @s_del,$stripdata->getName();
		}
		if (@s_del) {
			$result{kiwi_strip_delete} = join(" ",@s_del);
		}
	}
	my $s_toolref = $this -> getToolsToKeep();
	if ($s_toolref) {
		my @s_tool;
		foreach my $stripdata (@{$s_toolref}) {
			push @s_tool,$stripdata->getName();
		}
		if (@s_tool) {
			$result{kiwi_strip_tools} = join(" ",@s_tool);
		}
	}
	my $s_libref  = $this -> getLibsToKeep();
	if ($s_libref) {
		my @s_lib;
		foreach my $stripdata (@{$s_libref}) {
			push @s_lib,$stripdata->getName();
		}
		if (@s_lib) {
			$result{kiwi_strip_libs} = join(" ",@s_lib);
		}
	}
	#==========================================
	# preferences attributes and text elements
	#------------------------------------------
	my %type  = %{$this->getImageTypeAndAttributes_legacy()};
	my @delp  = $this -> getDeleteList_legacy();
	my $iver  = $this -> getPreferences() -> getVersion();
	my $size  = $this -> getImageSize_legacy();
	my $name  = $this -> getImageName();
	my $dname = $this -> getImageDisplayName ($this);
	my $lics  = $this -> getLicenseNames_legacy();
	my @tstp  = $this -> getTestingList();
	if ($lics) {
		$result{kiwi_showlicense} = join(" ",@{$lics});
	}
	if (@delp) {
		$result{kiwi_delete} = join(" ",@delp);
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
	if ((%type) && ($type{firmware})) {
		$result{kiwi_firmware} = $type{firmware};
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
	# drivers are handled in the new data structure
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
			if ($vol eq 'LV@root') {
				if ($attrval ne 'all') {
					$result{kiwi_LVM_LVRoot} = $attrname.":".$attrval;
				}
			} elsif ("$attrval" eq "all") {
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
		my $oemataraidscan = $node
			-> getElementsByTagName ("oem-ataraid-scan");
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
		my $oemshutdown= $node
			-> getElementsByTagName ("oem-shutdown");
		my $oemshutdowninter= $node
			-> getElementsByTagName ("oem-shutdown-interactive");
		my $oemsilentboot = $node
			-> getElementsByTagName ("oem-silent-boot");
		my $oemsilentinstall = $node
			-> getElementsByTagName ("oem-silent-install");
		my $oemsilentverify = $node
			-> getElementsByTagName ("oem-silent-verify");
		my $oemskipverify = $node
			-> getElementsByTagName ("oem-skip-verify");
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
		if ((defined $oemataraidscan) && ("$oemataraidscan" eq "false")) {
			$result{kiwi_oemataraid_scan} = $oemataraidscan;
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
		if ((defined $oemshutdown) && ("$oemshutdown" eq "true")) {
			$result{kiwi_oemshutdown} = $oemshutdown;
		}
		if ((defined $oemshutdowninter) && ("$oemshutdowninter" eq "true")) {
			$result{kiwi_oemshutdowninteractive} = $oemshutdowninter;
		}
		if ((defined $oemsilentboot) && ("$oemsilentboot" eq "true")) {
			$result{kiwi_oemsilentboot} = $oemsilentboot;
		}
		if ((defined $oemsilentinstall) && ("$oemsilentinstall" eq "true")) {
			$result{kiwi_oemsilentinstall} = $oemsilentinstall;
		}
		if ((defined $oemsilentverify) && ("$oemsilentverify" eq "true")) {
			$result{kiwi_oemsilentverify} = $oemsilentverify;
		}
		if ((defined $oemskipverify) && ("$oemskipverify" eq "true")) {
			$result{kiwi_oemskipverify} = $oemskipverify;
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
	if (! $dest) {
		return;
	}
	return "$dest";
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
	if (! $root) {
		return;
	}
	return "$root";
}

#==========================================
# getImageSize_legacy
#------------------------------------------
sub getImageSize_legacy {
	# ...
	# Get the predefined size of the logical extend
	# ---
	my $this = shift;
	my $node = $this->{typeNode};
	my $size = $node -> getElementsByTagName ("size");
	if ($size) {
		my $plus = $node -> getElementsByTagName ("size")
			-> get_node(1) -> getAttribute("additive");
		if ((! defined $plus) || ($plus eq "false")) {
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
# getImageSizeAdditiveBytes_legacy
#------------------------------------------
sub getImageSizeAdditiveBytes_legacy {
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
# getImageSizeBytes_legacy
#------------------------------------------
sub getImageSizeBytes_legacy {
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
# getInstallSize_legacy
#------------------------------------------
sub getInstallSize_legacy {
	my $this    = shift;
	my $kiwi    = $this->{kiwi};
	my $nodes   = $this->{packageNodeList};
	my $manager = $this->getPackageManager_legacy();
	my $urllist = $this -> __getURLList_legacy();
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
		my @slist = $node -> getElementsByTagName ("namedCollection");
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
			\@result,$urllist,"solve-patterns",
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
# getInstSourceArchList_legacy
#------------------------------------------
sub getInstSourceArchList_legacy {
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
# getInstSourceChrootList_legacy
#------------------------------------------
sub getInstSourceChrootList_legacy {
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
# getInstSourceDUDConfig_legacy
#------------------------------------------
sub getInstSourceDUDConfig_legacy {
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
# getInstSourceDUDInstall_legacy
#------------------------------------------
sub getInstSourceDUDInstall_legacy {
	my $this = shift;
	return $this->__getInstSourceDUDPackList_legacy('install');
}

#==========================================
# getInstSourceDUDInstsys_legacy
#------------------------------------------
sub getInstSourceDUDInstsys_legacy {
	my $this = shift;
	return $this->__getInstSourceDUDPackList_legacy('instsys');
}

#==========================================
# getInstSourceDUDModules_legacy
#------------------------------------------
sub getInstSourceDUDModules_legacy {
	my $this = shift;
	return $this->__getInstSourceDUDPackList_legacy('modules');
}

#==========================================
# getInstSourceDUDTargets_legacy
#------------------------------------------
sub getInstSourceDUDTargets_legacy {
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
# getInstSourceFile_legacy
#------------------------------------------
sub getInstSourceFile_legacy {
	# ...
	# download a file from a network or local location to
	# a given local path. It's possible to use regular expressions
	# in the source file specification
	# ---
	my $url     = shift;
	my $dest    = shift;
	my $dirname;
	my $basename;
	my $proxy;
	my $user;
	my $pass;
	my $lwp = "/dev/shm/lwp-download";
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
	if ($url =~ /^(.*)\?(.*)$/) {
		$url=$1;
		my $redirect=$2;
		if ($redirect =~ /(.*)\/(.*)?$/) {
			$redirect = $1;
			$url.=$2;
		}
		# get proxy url:
		# \bproxy makes sure it does not pick up "otherproxy=unrelated"
		# (?=&|$) makes sure the captured substring is followed by an
		# ampersand or the end-of-string
		# ----
		if ($redirect =~ /\bproxy=(.*?)(?=&|$)/) {
			$proxy = "$1";
		}
		# remove locator string e.g http://
		if ($proxy) {
			$proxy =~ s/^.*\/\///;
		}
		# extract credentials user and password
		if ($redirect =~ /proxyuser=(.*)\&proxypass=(.*)/) {
			$user=$1;
			$pass=$2;
		}
	}
	my $LWP = FileHandle -> new();
	if (! $LWP -> open (">$lwp")) {
		return;
	}
	if ($proxy) {
		print $LWP 'export PERL_LWP_ENV_PROXY=1'."\n";
		if (($user) && ($pass)) {
			print $LWP "export http_proxy=http://$user:$pass\@$proxy\n";
		} else {
			print $LWP "export http_proxy=http://$proxy\n";
		}
	}
	my $locator = KIWILocator -> instance();
	my $lwpload = $locator -> getExecPath ('lwp-download');
	if (! $lwpload) {
		return;
	}
	print $LWP $lwpload.' "$1" "$2"'."\n";
	$LWP -> close();
	# /.../
	# use lwp-download to manage the process.
	# if first download failed check the directory list with
	# a regular expression to find the file. After that repeat
	# the download
	# ----
	qxx ("chmod u+x $lwp 2>&1");
	$dest = $dirname."/".$basename;
	my $data = qxx ("$lwp $url $dest 2>&1");
	my $code = $? >> 8;
	if ($code == 0) {
		return $url;
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
				$data = qxx ("$lwp $url $dest 2>&1");
				$code = $? >> 8;
				if ($code == 0) {
					return $url;
				}
			}
		}
		return;
	} else {
		return;
	}
	return $url;
}

#==========================================
# getInstSourceMetaFiles_legacy
#------------------------------------------
sub getInstSourceMetaFiles_legacy {
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
# getInstSourceMetaPackageList_legacy
#------------------------------------------
sub getInstSourceMetaPackageList_legacy {
	# ...
	# Create base package list of the instsource
	# metadata package description
	# ---
	my $this = shift;
	my @list = getList_legacy ($this,"metapackages");
	my %data = ();
	foreach my $pack (@list) {
		my $attr = $this -> getInstSourcePackageAttributes_legacy (
			"metapackages",$pack
		);
		$data{$pack} = $attr;
	}
	return %data;
}

#==========================================
# getInstSourcePackageAttributes_legacy
#------------------------------------------
sub getInstSourcePackageAttributes_legacy {
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
# getInstSourcePackageList_legacy
#------------------------------------------
sub getInstSourcePackageList_legacy {
	# ...
	# Create base package list of the instsource
	# packages package description
	# ---
	my $this = shift;
	my @list = getList_legacy ($this,"instpackages");
	my %data = ();
	foreach my $pack (@list) {
		my $attr = $this -> getInstSourcePackageAttributes_legacy (
			"instpackages",$pack
		);
		$data{$pack} = $attr;
	}
	return %data;
}

#==========================================
# getInstSourceProductInfo_legacy
#------------------------------------------
sub getInstSourceProductInfo_legacy {
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
# getInstSourceProductOption_legacy
#------------------------------------------
sub getInstSourceProductOption_legacy {
	# ...
	# Get the shell variable values needed for
	# metadata creation
	# ---
	# return a hash with the following structure:
	# varname = value (quoted, may contain space etc.)
	# ---
	my $this = shift;
	return $this->getInstSourceProductStuff_legacy("productoption");
}

#==========================================
# getInstSourceProductStuff_legacy
#------------------------------------------
sub getInstSourceProductStuff_legacy {
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
# getInstSourceProductVar_legacy
#------------------------------------------
sub getInstSourceProductVar_legacy {
	# ...
	# Get the shell variable values needed for
	# metadata creation
	# ---
	# return a hash with the following structure:
	# varname = value (quoted, may contain space etc.)
	# ---
	my $this = shift;
	return $this->getInstSourceProductStuff_legacy("productvar");
}

#==========================================
# getInstSourceRepository_legacy
#------------------------------------------
sub getInstSourceRepository_legacy {
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
		my $pwd  = $element -> getAttribute("password");
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
	my $urllist = $this -> __getURLList_legacy();
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
			@slist = $node -> getElementsByTagName ('namedCollection');
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
						\@pattlist,$urllist,"solve-patterns",
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
# getLocale_legacy
#------------------------------------------
sub getLocale_legacy {
	# ...
	# Obtain the locale value or return undef
	# ---
	my $this = shift;
	my $node = $this -> __getPreferencesNodeByTagName ("locale");
	my $lang = $node -> getElementsByTagName ("locale");
	if ((! defined $lang) || ("$lang" eq "")) {
		return;
	}
	return "$lang";
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
	return "$align";
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
	return "$title";
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
	return "$wait";
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
	return "$kboot";
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
	return "$pinst";
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
	return "$boot";
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
	return "$boot";
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
	return "$reco";
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
	return "$reco";
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
	return "$inplace";
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
	return "$down";
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
	return "$down";
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
	return "$silent";
}

#==========================================
# getOEMSilentInstall_legacy
#------------------------------------------
sub getOEMSilentInstall_legacy {
	# ...
	# Obtain the oem-silent-install value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $silent = $node -> getElementsByTagName ("oem-silent-install");
	if ((! defined $silent) || ("$silent" eq "")) {
		return;
	}
	return "$silent";
}

#==========================================
# getOEMSilentVerify_legacy
#------------------------------------------
sub getOEMSilentVerify_legacy {
	# ...
	# Obtain the oem-silent-verify value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $silent = $node -> getElementsByTagName ("oem-silent-verify");
	if ((! defined $silent) || ("$silent" eq "")) {
		return;
	}
	return "$silent";
}

#==========================================
# getOEMSkipVerify_legacy
#------------------------------------------
sub getOEMSkipVerify_legacy {
	# ...
	# Obtain the oem-skip-verify value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $skip = $node -> getElementsByTagName ("oem-skip-verify");
	if ((! defined $skip) || ("$skip" eq "")) {
		return;
	}
	return "$skip";
}

#==========================================
# getOEMAtaRaidScan_legacy
#------------------------------------------
sub getOEMAtaRaidScan_legacy {
	# ...
	# Obtain the oem-ataraid-scan value or return undef
	# ---
	my $this = shift;
	my $tnode= $this->{typeNode};
	my $node = $tnode -> getElementsByTagName ("oemconfig") -> get_node(1);
	if (! defined $node) {
		return;
	}
	my $ataraidscan = $node -> getElementsByTagName ("oem-ataraid-scan");
	if ((! defined $ataraidscan) || ("$ataraidscan" eq "")) {
		return;
	}
	return "$ataraidscan";
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
	my @swap = $node -> getElementsByTagName ("oem-swap");
	if (! $swap[0]) {
		return;
	}
	my $swap = $swap[0]->textContent();
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
	return "$size";
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
	return "$size";
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
	my @unattended = $node -> getElementsByTagName ("oem-unattended");
	if (! $unattended[0]) {
		return;
	}
	my $unattended = $unattended[0]->textContent();
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
	return "$unattended_id";
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
# getStripNodeList_legacy
#------------------------------------------
sub getStripNodeList_legacy {
	# ...
	# Return a list of all <strip> nodes. Each list member
	# is an XML::LibXML::Element object pointer
	# ---
	my $this = shift;
	return $this->{stripNodeList};
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
# getURLHash_legacy
#------------------------------------------
sub getURLHash_legacy {
	my $this = shift;
	if (! $this->{urlhash}) {
		$this -> __createURLList_legacy();
	}
	return $this->{urlhash};
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
	$this -> __updateXML_legacy();
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
# writeXMLDescription_legacy
#------------------------------------------
sub writeXMLDescription_legacy {
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
		KIWIGlobals -> instance() -> setKiwiConfigData (
			"OverlayRootTree",0
		);
	}
	return $this;
}

#==========================================
# readDefaultStripNode
#------------------------------------------
sub readDefaultStripNode {
	# ...
	# read the default strip section data and return
	# KIWIXMLStripData objects in a hash for each
	# strip section type
	# ---
	my $this   = shift;
	my $kiwi   = $this->{kiwi};
	my %result;
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
		my @list = ();
		foreach my $node ($element -> getElementsByTagName ('file')) {
			my $name = $node -> getAttribute('name');
			my $arch = $node -> getAttribute('arch');
			my %stripData = (
				arch => $arch,
				name => $name
			);
			my $stripObj = KIWIXMLStripData -> new(\%stripData);
			push @list,$stripObj;
		}
		$result{$type} = \@list;
	}
	return %result;
}

#==========================================
# Private helper methods
#------------------------------------------
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
	$this -> __updateXML_legacy();
	return $this;
}

#==========================================
# __createURLList_legacy
#------------------------------------------
sub __createURLList_legacy {
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $cmdL = $this->{cmdL};
	my %repository  = ();
	my @urllist     = ();
	my %urlhash     = ();
	my @sourcelist  = ();
	# Hack my way out of a jam of different data handling between legacy and
	# new stuff. However this method will go away anyway ;)
	my $processed = 0;
	my $repos = $this->getRepositories();
	for my $repo (@{$repos}) {
		$processed = 1;
		my ($user, $pwd) = $repo -> getCredentials();
		my $source = $repo -> getPath();
		my $urlHandler  = KIWIURL -> new ($cmdL,undef,$user,$pwd);
		my $publics_url = $urlHandler -> normalizePath ($source);
		push (@urllist,$publics_url);
		$urlhash{$source} = $publics_url;
	}
	if (! $processed) {
		%repository = $this->getInstSourceRepository_legacy();
		foreach my $name (keys %repository) {
			push (@sourcelist,$repository{$name}{source});
		}
		foreach my $source (@sourcelist) {
			my $user = $repository{$source}[3];
			my $pwd  = $repository{$source}[4];
			my $urlHandler  = KIWIURL -> new ($cmdL,undef,$user,$pwd);
			my $publics_url = $urlHandler -> normalizePath ($source);
			push (@urllist,$publics_url);
			$urlhash{$source} = $publics_url;
		}
	}
	$this->{urllist} = \@urllist;
	$this->{urlhash} = \%urlhash;
	return $this;
}

#==========================================
# __getInstSourceDUDPackList_legacy
#------------------------------------------
sub __getInstSourceDUDPackList_legacy {
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
# __getURLList_legacy
#------------------------------------------
sub __getURLList_legacy {
	my $this = shift;
	if (! $this->{urllist}) {
		$this -> __createURLList_legacy();
	}
	return $this->{urllist};
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
	my $urlhd  = KIWIURL -> new ($cmdL);
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
			$record{firmware}      = $node
				-> getAttribute("firmware");
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
			$record{mdraid}        = $node
				-> getAttribute("mdraid");
			if ($record{type} eq "split") {
				my $filesystemRO = $node -> getAttribute("fsreadonly");
				my $filesystemRW = $node -> getAttribute("fsreadwrite");
				if ((defined $filesystemRO) && (defined $filesystemRW)) {
					$record{filesystem} = "$filesystemRW,$filesystemRO";
				}
			}
			if ($disk) {
				my $use_lvm = 1;
				if (($record{filesystem}) &&
					($record{filesystem}=~/zfs|btrfs/)
				) {
					$use_lvm = 0;
				} elsif (($record{type})  &&
					($record{type} =~ /zfs|btrfs/)
				) {
					$use_lvm = 0;
				}
				if ($use_lvm) {
					$record{lvm} = "true";
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
	# Repos are handled through the new data structure
	#==========================================
	# 2) merge/update drivers
	#------------------------------------------
	# Driver data is handled through the new data structure
	#==========================================
	# 3) merge/update strip
	#------------------------------------------
	# Strip data is handled through the new data structure
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
	if (defined $changeset->{"oem-ataraid-scan"}) {
		$this -> __setOEMOptionsElement ("oem-ataraid-scan",$changeset);
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
	if (defined $changeset->{"oem-silent-verify"}) {
		$this -> __setOEMOptionsElement ("oem-silent-verify",$changeset);
	}
	if (defined $changeset->{"oem-silent-install"}) {
		$this -> __setOEMOptionsElement ("oem-silent-install",$changeset);
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
	if (defined $changeset->{"firmware"}) {
		$this -> __setTypeAttribute (
			"firmware",$changeset->{"firmware"}
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
# __updateTypeList_legacy
#------------------------------------------
sub __updateTypeList_legacy {
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
# __updateXML_legacy
#------------------------------------------
sub __updateXML_legacy {
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
# End "old" methods section
#------------------------------------------

#==========================================
# Private helper methods
#------------------------------------------
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
	$this -> __updateXML_legacy();
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
	$this -> __updateXML_legacy();
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
	$this -> __updateXML_legacy();
	return $this;
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
	$this -> __updateTypeList_legacy();
	$this -> __updateXML_legacy();
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
	$this -> __updateTypeList_legacy();
	$this -> __updateXML_legacy();
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
		my $disk = XML::LibXML::Element -> new ("vmdisk");
		$disk -> setAttribute ("controller","scsi");
		$disk -> setAttribute ("id","0");
		$opts -> appendChild ($disk);
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
	$this -> __updateTypeList_legacy();
	$this -> __updateXML_legacy();
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
	$this -> __updateTypeList_legacy();
	$this -> __updateXML_legacy();
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
	$this -> __updateXML_legacy();
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
	my $first = 1;
	foreach my $record (@{$typeList}) {
		my $found = 0;

	PROFILESEARCH:
		foreach my $p (@{$record->{assigned}}) {
			if ($select{$p}) {
				$found = 1;
				last PROFILESEARCH;
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
