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
no warnings 'redefine'; ## no critic
use Carp qw (cluck);
use Data::Dumper;
use File::Basename;
use File::Glob ':glob';
use File::Slurp;
use XML::LibXML;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;

#==========================================
# KIWI Modules
#------------------------------------------
use KIWILocator;
use KIWILog;
use KIWIQX;
use KIWIURL;
use KIWIXMLDescriptionData;
use KIWIXMLDriverData;
use KIWIXMLInstRepositoryData;
use KIWIXMLVagrantConfigData;
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
    #         machine       = KIWIXMLVMachineData
    #         oemconfig     = KIWIXMLOEMConfigData
    #         vagrantconfig = (KIWIXMLVagrantConfigData,...)
    #         pxeconfig     = (KIWIXMLPXEDeployConfigData,...)
    #         pxedeploy     = KIWIXMLPXEDeployData
    #         split         = KIWIXMLSplitData
    #         systemdisk    = KIWIXMLSystemdiskData
    #         type          = KIWIXMLTypeData
    #     },
    #     selectedProfiles = ('',....,'kiwi_default')
    #     selectedType = {
    #         machine       = KIWIXMLVMachineData
    #         oemconfig     = KIWIXMLOEMConfigData
    #         vagrantconfig = (KIWIXMLVagrantConfigData,...)
    #         pxeconfig     = (KIWIXMLPXEDeployConfigData,...)
    #         pxedeploy     = KIWIXMLPXEDeployData
    #         split         = KIWIXMLSplitData
    #         systemdisk    = KIWIXMLSystemdiskData
    #         type          = KIWIXMLTypeData
    #     },
    #     imageConfig = {
    #         description  = KIWIXMLDescriptionData
    #         displayName = ''
    #         imageName   = ''
    #         productSettings = {
    #             dudArches      = ('',...)
    #             reqArches      = ('',...)
    #             options        = KIWIXMLProductOptionsData
    #             architectures  = (KIWIXMLProductArchitectureData,... )
    #             dudInstSysPkgs = (KIWIXMLProductPackageData,... )
    #             dudModulePkgs  = (KIWIXMLProductPackageData,... )
    #             dudPkgs        = (KIWIXMLProductPackageData,... )
    #             instRepos      = (KIWIXMLInstRepositoryData,... )
    #             metaChroots    = (KIWIXMLProductMetaChrootData,...)
    #             metaFiles      = (KIWIXMLProductMetaFileData,...)
    #             metaPkgs       = (KIWIXMLProductPackageData,... )
    #             prodPkgs       = (KIWIXMLProductPackageData,...)
    #         }
    #         <profName>[+] = {
    #             installOpt      = ''
    #             archives        = (KIWIXMLPackageArchiveData,...)
    #             bootArchives    = (KIWIXMLPackageArchiveData,...)
    #             profInfo        = KIWIXMLProfileData
    #             repoData        = (KIWIXMLRepositoryData,...)
    #             bootDelPkgs     = (KIWIXMLPackageData, ...)
    #             bootPkgs        = (KIWIXMLPackageData, ...)
    #             bootPkgsCollect = (KIWIXMLPackageCollectData,...)
    #             bootStrapPckgs  = (KIWIXMLPackageData, ...)
    #             TestSuitePckgs  = (KIWIXMLPackageData, ...)
    #             delPkgs         = (KIWIXMLPackageData, ...)
    #             drivers         = (KIWIXMLDriverData,  ...)
    #             ignorePkgs      = (KIWIXMLPackageData, ...)
    #             keepLibs        = (KIWIXMLStripData,...)
    #             keepTools       = (KIWIXMLStripData,...)
    #             pkgs            = (KIWIXMLPackageData, ...)
    #             pkgsCollect     = (KIWIXMLPackageCollectData,...)
    #             products        = (KIWIXMLPackageProductData,...)
    #             stripDelete     = (KIWIXMLStripData,...)
    #             <archname>[+] {
    #                 archives        = (KIWIXMLPackageArchiveData,...)
    #                 bootArchives    = (KIWIXMLPackageArchiveData,...)
    #                 bootDelPkgs     = (KIWIXMLPackageData, ...)
    #                 bootPkgs        = (KIWIXMLPackageData, ...)
    #                 bootPkgsCollect = (KIWIXMLPackageCollectData,...)
    #                 bootStrapPckgs  = (KIWIXMLPackageData, ...)
    #                 TestSuitePckgs  = (KIWIXMLPackageData, ...)
    #                 delPkgs         = (KIWIXMLPackageData, ...)
    #                 drivers         = (KIWIXMLDriverData,  ...)
    #                 ignorePkgs      = (KIWIXMLPackageData, ...)
    #                 keepLibs        = (KIWIXMLStripData,...)
    #                 keepTools       = (KIWIXMLStripData,...)
    #                 pkgs            = (KIWIXMLPackageData, ...)
    #                 pkgsCollect     = (KIWIXMLPackageCollectData,...)
    #                 products        = (KIWIXMLPackageProductData,...)
    #                 stripDelete     = (KIWIXMLStripData,...)
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
    #                partitioner          = ''
    #                packagemanager       = ''
    #                rpm_check_signatures = ''
    #                rpm_excludedocs      = ''
    #                rpm_force            = ''
    #                showlicense          = ''
    #                timezone             = ''
    #                types                = ''
    #                version
    #                types {
    #                    defaultType = ''
    #                    <typename>[+] {
    #                        machine       = KIWIXMLVMachineData
    #                        oemconfig     = KIWIXMLOEMConfigData
    #                        vagrantconfig = (KIWIXMLVagrantConfigData,...)
    #                        pxeconfig     = (KIWIXMLPXEDeployConfigData,...)
    #                        pxedeploy     = KIWIXMLPXEDeployData
    #                        split         = KIWIXMLSplitData
    #                        systemdisk    = KIWIXMLSystemdiskData
    #                        type          = KIWIXMLTypeData
    #                    }
    #                }
    #            }
    #            <typename>[+] {
    #                archives = (KIWIXMLPackageArchiveData,....)
    #                <archname>[+] {
    #                    archives        = (KIWIXMLPackageArchiveData,...)
    #                    bootArchives    = (KIWIXMLPackageArchiveData,...)
    #                    bootDelPkgs     = (KIWIXMLPackageData,...)
    #                    bootPkgs        = (KIWIXMLPackageData,...)
    #                    bootPkgsCollect = (KIWIXMLPackageCollectData,...)
    #                    drivers         = (KIWIXMLDriverData)
    #                    ignorePkgs      = (KIWIXMLPackageData,...)
    #                    pkgs            = (KIWIXMLPackageData,...)
    #                    pkgsCollect     = (KIWIXMLPackageCollectData)
    #                    products        = (KIWIXMLPackageProductData,...)
    #                }
    #                bootArchives    = (KIWIXMLPackageArchiveData,...)
    #                bootDelPkgs     = (KIWIXMLPackageData,...)
    #                bootPkgs        = (KIWIXMLPackageData,...)
    #                bootPkgsCollect = (KIWIXMLPackageCollectData,...)
    #                drivers         = (KIWIXMLPackageCollectData,...)
    #                ignorePkgs      = (KIWIXMLPackageData,...)
    #                pkgs            = (KIWIXMLPackageData,...)
    #                pkgsCollect     = (KIWIXMLPackageCollectData,...)
    #                products        = (KIWIXMLPackageCollectData,...)
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
    #==========================================
    # Constructor setup
    #------------------------------------------
    my $arch = KIWIGlobals -> instance() -> getArch();
    my %supported = map { ($_ => 1) } qw(
        aarch64
        armv5el
        armv5tel
        armv6l
        armv6hl
        armv7l
        armv7hl
        ia64
        i586
        i686
        m68k
        ppc
        ppc64
        ppc64le
        s390
        s390x
        x86_64
        noarch
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
    if (! $imageDesc) {
        # image description pointer not initialized
        return;
    }
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
    # Internal Data structure -> imageConfig 
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
    # Add default split section if not defined
    #------------------------------------------
    if (! $this -> __addDefaultSplitNode()) {
        return;
    }
    #==========================================
    # Populate description data from xml
    #------------------------------------------
    $this -> __populateDescriptionInfo();
    #==========================================
    # Populate product data from xml
    #------------------------------------------
    $this -> __populateInstSource();
    #==========================================
    # Populate profile data from xml
    #------------------------------------------
    $this -> __populateProfileInfo();
    #==========================================
    # Populate driver data from xml
    #------------------------------------------
    $this -> __populateDriverInfo();
    #==========================================
    # Populate preferences data from xml
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
    # Populate archive data from xml
    #------------------------------------------
    $this -> __populateArchiveInfo();
    #==========================================
    # Populate packages to ignore from xml data
    #------------------------------------------
    $this -> __populateIgnorePackageInfo();
    #==========================================
    # Populate package data from xml data
    #------------------------------------------
    $this -> __populatePackageInfo();
    #==========================================
    # Populate package collection data from xml
    #------------------------------------------
    $this -> __populatePackageCollectionInfo();
    #==========================================
    # Populate product data from xml
    #------------------------------------------
    $this -> __populatePackageProductInfo();
    #==========================================
    # Populate repository data from xml
    #------------------------------------------
    $this -> __populateRepositoryInfo();
    #==========================================
    # Populate strip/keep data from xml
    #------------------------------------------
    $this -> __populateStripInfo();
    #==========================================
    # Populate user data from xml
    #------------------------------------------
    $this -> __populateUserInfo();
    #==========================================
    # Store object data
    #------------------------------------------
    $this->{usrdataNodeList}    = $usrdataNodeList;
    $this->{controlFile}        = $controlFile;
    #==========================================
    # Dump imageConfig to log
    #------------------------------------------
    # print $this->__dumpInternalXMLDescription();
    return $this;
}

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
    my $this       = shift;
    my $archives   = shift;
    my $profNames  = shift;
    my $sectionType= shift;
    my %verifyData = (
        caller       => 'addArchives',
        expectedType => 'KIWIXMLPackageArchiveData',
        itemName     => 'archives',
        itemsToAdd   => $archives,
        profNames    => $profNames,
        type         => $sectionType
    );
    if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
        return;
    }
    my @profsToUse = $this -> __getProfsToModify($profNames, 'archive(s)');
    if (! $sectionType) {
        $sectionType = 'image';
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
                type     => $sectionType
            );
            if (! $this -> __storeInstallData(\%storeData)) {
                return;
            }
        }
    }
    return $this;
}

#==========================================
# addBootstrapArchives
#------------------------------------------
sub addBootstrapArchives {
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
    my $this       = shift;
    my $archives   = shift;
    my $profNames  = shift;
    my $sectionType= shift;
    my %verifyData = (
        caller       => 'addArchives',
        expectedType => 'KIWIXMLPackageArchiveData',
        itemName     => 'archives',
        itemsToAdd   => $archives,
        profNames    => $profNames,
    );
    if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
        return;
    }
    my @profsToUse = $this -> __getProfsToModify($profNames, 'archive(s)');
    if (! $sectionType) {
        $sectionType = 'image';
    }
    my $accessID;
    for my $prof (@profsToUse) {
        for my $archiveObj (@{$archives}) {
            my $arch      = $archiveObj -> getArch();
            my %storeData = (
                accessID => 'archives',
                arch     => $arch,
                dataObj  => $archiveObj,
                profName => $prof,
                type     => $sectionType
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
    my $sectionType= shift;
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
    if (! $sectionType) {
        $sectionType = 'bootstrap';
    }
    for my $prof (@profsToUse) {
        for my $pckgObj (@{$packages}) {
            my $arch = $pckgObj -> getArch();
            my %storeData = (
                accessID => 'bootStrapPckgs',
                arch     => $arch,
                dataObj  => $pckgObj,
                profName => $prof,
                type     => $sectionType
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
        $kiwi -> info ("Added following drivers:\n");
        for my $name (@addedDrivers) {
            $kiwi -> info ("  --> $name\n");
        }
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
    my $sectionType= shift;
    my %verifyData = (
        caller       => 'addPackages',
        expectedType => 'KIWIXMLPackageData',
        itemName     => 'packages',
        itemsToAdd   => $packages,
        profNames    => $profNames,
        type         => $sectionType
    );
    if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
        return;
    }
    my @profsToUse = $this -> __getProfsToModify($profNames, 'package(s)');
    if (! $sectionType) {
        $sectionType = 'image';
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
                    type     => $sectionType
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
    my $sectionType = shift;
    my %verifyData = (
        caller       => 'addPackageCollections',
        expectedType => 'KIWIXMLPackageCollectData',
        itemName     => 'collections',
        itemsToAdd   => $collections,
        profNames    => $profNames,
        type         => $sectionType
    );
    if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
        return;
    }
    my @profsToUse = $this -> __getProfsToModify($profNames, 'collection(s)');
    if (! $sectionType) {
        $sectionType = 'image';
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
                type     => $sectionType
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
    my $sectionType= shift;
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
    if (! $sectionType) {
        $sectionType = 'bootstrap';
    }
    for my $prof (@profsToUse) {
        for my $pckgObj (@{$packages}) {
            my $arch = $pckgObj -> getArch();
            my %storeData = (
                accessID => 'delPkgs',
                arch     => $arch,
                dataObj  => $pckgObj,
                profName => $prof,
                type     => $sectionType
            );
            if (! $this -> __storeInstallData(\%storeData)) {
                return;
            }
        }
    }
    return $this;
}

#==========================================
# addPackagesToIgnore
#------------------------------------------
sub addPackagesToIgnore {
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
    my $sectionType= shift;
    my %verifyData = (
        caller       => 'addPackagesToIgnore',
        expectedType => 'KIWIXMLPackageIgnoreData',
        itemName     => 'packages',
        itemsToAdd   => $packages,
        profNames    => $profNames
    );
    if (! $this -> __verifyAddInstallDataArgs(\%verifyData)) {
        return;
    }
    my @profsToUse = $this -> __getProfsToModify($profNames, 'package(s)');
    if (! $sectionType) {
        $sectionType = 'bootstrap';
    }
    for my $prof (@profsToUse) {
        for my $pckgObj (@{$packages}) {
            my $arch = $pckgObj -> getArch();
            my %storeData = (
                accessID => 'ignorePkgs',
                arch     => $arch,
                dataObj  => $pckgObj,
                profName => $prof,
                type     => $sectionType
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
# getImageArchives
#------------------------------------------
sub getImageArchives {
    # ...
    # Return an array ref containing ArchiveData objects
    # which contains all archives from the image typed packages sections
    # ---
    my $this = shift;
    return $this -> __getInstallData('archives');
}

#==========================================
# getBootStrapArchives
#------------------------------------------
sub getBootStrapArchives {
    # ...
    # Return an array ref containing ArchiveData objects
    # which contains all archives from the bootstrap packages section
    # ---
    my $this = shift;
    return $this -> __getInstallData('bootStrapArchives');
}

#==========================================
# getPackagesToIgnore
#------------------------------------------
sub getPackagesToIgnore {
    # ...
    # Return an array ref containing IgnorePackageData objects
    # The method is private as it is needed for filtering only. Clients
    # of the XML object should not do any filtering on the data received.
    # ---
    my $this = shift;
    return $this -> __getInstallData('ignorePkgs');
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
# getBootIncludeImageArchives
#------------------------------------------
sub getBootIncludeImageArchives {
    # ...
    # Return an array ref containing ArchiveData objects
    # which contains all archives from the image types packages section(s)
    # marked as bootinclude
    # ---
    my $this = shift;
    return $this -> __getInstallData('bootArchives');
}

#==========================================
# getBootIncludeBootStrapArchives
#------------------------------------------
sub getBootIncludeBootStrapArchives {
    # ...
    # Return an array ref containing ArchiveData objects
    # which contains all archives from the bootstrap packages section
    # marked as bootinclude
    # ---
    my $this = shift;
    return $this -> __getInstallData('bootStrapBootArchives');
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
    # /.../
    # Return sort uniq result
    # ----
    my %result;
    foreach my $pack (@bootInclPackages) {
        my $name = $pack -> getName();
        $result{$name} = $pack;
    }
    @bootInclPackages = ( map { $result{$_} } sort keys %result );
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
    # that should be used to bootstrap the image. The packages marked
    # to become bootincluded will also be handled in the bootstrap phase
    # ---
    my $this = shift;
    my $pckgs = $this -> __getInstallData('bootStrapPckgs');
    my $bPckgs = $this -> getBootIncludePackages();
    if ($bPckgs) {
        push @{$pckgs}, @{$bPckgs};
    }
    return $pckgs;
}

#==========================================
# getTestSuitePackages
#------------------------------------------
sub getTestSuitePackages {
    # ...
    # Return an array ref containing PackageData objects for the packages
    # that should be used in a testsuite run.
    # ---
    my $this = shift;
    return $this -> __getInstallData('testSuitePckgs');
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
    # Return a hash ref containing strings indicating the driver update
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
# setImageDisplayName
#------------------------------------------
sub setImageDisplayName {
    # ...
    # Set the display name used for the boot menu
    # ---
    my $this = shift;
    my $name = shift;
    $this->{imageConfig}->{displayName} = $name;
    return $this;
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
    # Return the install option type setting.
    # decides for plusRecommended if it was selected
    # by a profile even if the default setting is
    # at onlyRequired
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
            if (($opt ne $instOpt) && ($opt eq 'plusRecommended')) {
                $instOpt = $opt;
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
# getVagrantConfig
#------------------------------------------
sub getVagrantConfig {
    # ...
    # Return an array ref containing VagrantConfigData objects
    # for the selected build type
    # ---
    my $this = shift;
    return $this->{selectedType}->{vagrantconfig};
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
# setOEMConfig
#------------------------------------------
sub setOEMConfig {
    # ...
    # Store a new OEMConfigData object for the selected build type
    # ---
    my $this    = shift;
    my $oemconf = shift;
    my $oemref  = ref $oemconf;
    if (! $oemref) {
        return;
    }
    if ($oemref ne 'KIWIXMLOEMConfigData') {
        return;
    }
    $this->{selectedType}->{oemconfig} = $oemconf;
    return $this;
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
    my %pckgFilter;
    # Any packages that are marked to be replaced need to be removed
    for my $pckg (@{$pckgs}) {
        my $toReplace = $pckg -> getPackageToReplace();
        if ($toReplace) {
            $pckgFilter{$toReplace} = 1;
        }
    }
    # Any packages that are marked to be ignored need to be removed
    my $ignorePckgs = $this -> getPackagesToIgnore();
    for my $ignoreP (@{$ignorePckgs}) {
        my $name = $ignoreP -> getName();
        $pckgFilter{$name} = 1;
    }
    my @installPackages;
    # Create the list of packages
    for my $pckg (@{$pckgs}) {
        my $name = $pckg -> getName();
        if ($pckgFilter{$name}) {
            next;
        }
        my $added = 0;
        foreach my $item (@installPackages) {
            if ($item eq $pckg) {
                $added = 1;
                last;
            }
        }
        if (! $added) {
            push @installPackages, $pckg;
        }
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
    if ($bCollections) {
        push @{$collections}, @{$bCollections};
    }
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
# setPackagesToDelete
#------------------------------------------
sub setPackagesToDelete {
    # ...
    # set new list of PackageData objects for the packages
    # that should be deleted.
    # ---
    my $this       = shift;
    my $packages   = shift;
    my $profNames  = shift;
    my $sectionType= shift;
    my @profsToUse = $this -> __getProfsToModify($profNames, 'package(s)');
    if (! $sectionType) {
        $sectionType = 'image';
    }
    for my $prof (@profsToUse) {
        my %storeData = (
            accessID => 'delPkgs',
            profName => $prof,
            type     => $sectionType
        );
        $this -> __clearInstallData (\%storeData);
    }
    return $this -> addPackagesToDelete (
        $packages,$profNames,$sectionType
    );
}

#==========================================
# getPreferences
#------------------------------------------
sub getPreferences {
    # ...
    # Return a new KIWIXMLPreferenceData object which references
    # the sum of all default and currently selected build
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
    # Return a hash ref of strings indicating the required architectures
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
# setVMachineConfig
#------------------------------------------
sub setVMachineConfig {
    # ...
    # Store a new VMachineData object
    # ---
    my $this  = shift;
    my $vconf = shift;
    my $vcref = ref $vconf;
    if (! $vcref) {
        return;
    }
    if ($vcref ne 'KIWIXMLVMachineData') {
        return;
    }
    $this->{selectedType}->{machine} = $vconf;
    return $this;
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
        partitioner          => $prefObj -> getPartitioner(),
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
        bootStrapArchives
        bootStrapBootArchives
        pkgsCollect
        bootPkgsCollect
        products
        bootPkgs
        bootDelPkgs
    );
    for my $collect (@collectData) {
        my $data = $this -> __collectDefaultData($collect);
        if ($data) {
            push @pckgsItems, @{$data};
        }
    }
    my $packages = $this -> getPackages();
    if ($packages) {
        push @pckgsItems, @{$packages};
    }
    my $ignore_packages = $this -> getPackagesToIgnore();
    if ($ignore_packages) {
        push @pckgsItems, @{$ignore_packages};
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
        my %usedNames;
        for my $item (@typePckgItems) {
            my $name = $item -> getName();
            if (! $usedNames{$name}) {
                $usedNames{$name} = 1;
                $xml .= $item -> getXMLElement() -> toString();
            }
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
    my $bootStrapArchives =
        $this -> __collectXMLListData('bootStrapArchives', $imgT);
    my $bootStrapBootArchives =
        $this -> __collectXMLListData('bootStrapBootArchives', $imgT);
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
        $bootStrapArchives,
        $bootStrapBootArchives,
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
        my $index = 0;
        if (@allData) {
            for my $items (@allData) {
                for my $obj (@{$items}) {
                    my $name = $obj -> getName();
                    my $oref = ref $obj;
                    if ($oref eq 'KIWIXMLPackageData') {
                        if ($obj -> getPackageToReplace()) {
                            # allow duplicates if replace information exists
                            $name = $name.$index;
                            $index++;
                        }
                    }
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
# __createVagrantConfig
#------------------------------------------
sub __createVagrantConfig {
    # ...
    # Return a ref to a hash that contains the configuration data
    # for the <vagrantconfig> elements and it's children for the
    # given XML:ELEMENT object
    # ---
    my $this = shift;
    my $node = shift;
    my $kiwi = $this->{kiwi};
    my @vagrantConfigNodes = $node
        -> getChildrenByTagName('vagrantconfig');
    if (! @vagrantConfigNodes) {
        return;
    }
    my @vagrantConfigData;
    for my $vagrantConfig (@vagrantConfigNodes) {
        my %vagrantConfigSet;
        $vagrantConfigSet{boxname} =
            $vagrantConfig -> getAttribute('boxname');
        $vagrantConfigSet{provider} =
            $vagrantConfig -> getAttribute('provider');
        $vagrantConfigSet{virtual_size} =
            $vagrantConfig -> getAttribute('virtualsize');
        my $vagrantConfObj = KIWIXMLVagrantConfigData -> new(
            \%vagrantConfigSet
        );
        push @vagrantConfigData, $vagrantConfObj;
    }
    return \@vagrantConfigData;
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
    $oemConfig{oem_ataraid_scan}         =
        $this -> __getChildNodeTextValue($config, 'oem-ataraid-scan');
    $oemConfig{oem_vmcp_parmfile}        =
        $this -> __getChildNodeTextValue($config, 'oem-vmcp-parmfile');
    $oemConfig{oem_multipath_scan}         =
        $this -> __getChildNodeTextValue($config, 'oem-multipath-scan');
    $oemConfig{oem_boot_title}           =
        $this -> __getChildNodeTextValue($config, 'oem-boot-title');
    $oemConfig{oem_bootwait}             =
        $this -> __getChildNodeTextValue($config, 'oem-bootwait');
    $oemConfig{oem_device_filter}        =
        $this -> __getChildNodeTextValue($config, 'oem-device-filter');
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
    $oemConfig{oem_recoveryPartSize}=
        $this -> __getChildNodeTextValue($config, 'oem-recovery-part-size');
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
    $lvmData{preferlvm} = $lvmDataNode -> getAttribute('preferlvm');
    my @volumes = $lvmDataNode -> getChildrenByTagName('volume');
    my %volData;
    my $cntr = 1;
    for my $vol (@volumes) {
        my %volInfo;
        $volInfo{freespace} = $this->__convertSizeStrToMBVal(
            $vol -> getAttribute('freespace')
        );
        my $name = $vol -> getAttribute('name');
        my $mount= $vol -> getAttribute('mountpoint');
        my $msg = "Invalid name '$name' for LVM volume setup";
        $name =~ s/\s+//g;
        if ($name eq '/') {
            $kiwi -> error($msg);
            $kiwi -> failed();
            return -1;
        }
        $name =~ s/^\///;
        if ($name
         =~ /^(image|proc|sys|dev|boot|mnt|lib|bin|sbin|etc|lost\+found)$/sxm
        ) {
            $kiwi -> error($msg);
            $kiwi -> failed();
            return -1;
        }
        $volInfo{mountpoint} = $mount;
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
        $diskSet{diskmode}   = $disk -> getAttribute('diskmode');
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
# __genProductReqArchHash
#------------------------------------------
sub __genProductReqArchHash {
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
    my $this        = shift;
    my $instSrcNode = shift;
    my $elems = $instSrcNode -> getElementsByTagName("architectures");
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
    return \%result;
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
        'bootpartition',
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
        'formatoptions',
        'fsmountoptions',
        'gcelicense',
        'fsnocheck',
        'fsreadonly',
        'fsreadwrite',
        'hybrid',
        'hybridpersistent',
        'hybridpersistent_filesystem',
        'image',
        'installboot',
        'installiso',
        'installpxe',
        'installprovidefailsafe',
        'installstick',
        'kernelcmdline',
        'luks',
        'luksOS',
        'ramonly',
        'target_blocksize',
        'mdraid',
        'vga',
        'vhdfixedtag',
        'volid',
        'wwid_wait_timeout',
        'zfsoptions',
        'zipl_targettype'
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
        # store <vagrantconfig> child
        #------------------------------------------
        my $vagrantConfig = $this -> __createVagrantConfig($type);
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
            machine       => $vmConfig,
            vagrantconfig => $vagrantConfig,
            oemconfig     => $oemConfig,
            pxeconfig     => $pxeConfigData,
            pxedeploy     => $pxeConfig,
            split         => $splitData,
            systemdisk    => $sysDisk,
            type          => $typeObj
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
    # Return a ref to an array containing objects accumulated
    # across the image config data structure for the given
    # accessID.
    # ---
    my $this   = shift;
    my $access = shift;
    my $kiwi = $this->{kiwi};
    #==========================================
    # check for required section ID
    #------------------------------------------
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
    if (! $type) {
        return;
    }
    my $typeName = $type -> getTypeName();
    my @names;
    #==========================================
    # walk through all selected profiles
    #------------------------------------------
    for my $prof (@selected) {
        #==========================================
        # catch all standard sections
        #------------------------------------------
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
        #==========================================
        # catch all build type specific items
        #------------------------------------------
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
    # /.../
    # Return sort uniq result
    # ----
    my %result;
    foreach my $item (@names) {
        my $name = $item -> getName();
        $result{$name} = $item;
    }
    @names = ( map { $result{$_} } sort keys %result );
    return \@names;
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
                machine
                vagrantconfig
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
                        my $chObj_type = ref($chObj);
                        if ($chObj_type eq 'ARRAY') {
                            foreach my $object (@{$chObj}) {
                                my $cElement = $object -> getXMLElement();
                                $tElem  -> addChild($cElement);
                            }
                        } else {
                            my $cElement = $chObj -> getXMLElement();
                            $tElem  -> addChild($cElement);
                        }
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
        partitioner
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
                if ($type eq 'bootstrap') {
                    $accessID = 'bootStrapArchives';
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
                if ($bootIncl && $bootIncl eq 'true') {
                    my $bootArchiveObj = KIWIXMLPackageArchiveData -> new(
                        \%archData
                    );
                    if ($type eq 'bootstrap') {
                        $accessID = 'bootStrapBootArchives';
                    } else {
                        $accessID = 'bootArchives';
                    }
                    my %storeBootData = (
                        accessID => $accessID,
                        arch     => $arch,
                        dataObj  => $bootArchiveObj,
                        profName => $prof,
                        type     => $type
                    );
                    if (! $this -> __storeInstallData(\%storeBootData)) {
                        return;
                    }
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
    # product data provided with the <instsource> element and
    # its children from the XML file.
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
        my %dudArches;
        my $dudInstSysPkgs;
        my $dudModulePkgs;
        my $dudPkgs;
        if (@dudNodes) {
            my @targetNodes = $dudNodes[0] -> getElementsByTagName('target');
            for my $tgt (@targetNodes) {
                my $text = $tgt -> textContent();
                my $arch = $tgt -> getAttribute("arch");
                if (! $text) {
                    $text = $arch;
                }
                $dudArches{$text} = $arch;
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
        my $reqArches = $this -> __genProductReqArchHash($instSrc);
        if (! $reqArches) {
            return;
        }
        my %prodSettings = (
            architectures  => $arches,
            dudArches      => \%dudArches,
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
                if ((defined $replace) && ($replace eq '')) {
                    $replace = 'none';
                }
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
                if ($bootIncl && $bootIncl eq 'true') {
                    push @access, 'bootPkgs';
                }
                if ($type eq 'testsuite') {
                    # In a type='testsuite' section attributes are ignored
                    @access = ('TestSuitePckgs');
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
    # information from <product>
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
        my @productNodes = $pckgNd -> getElementsByTagName('product');
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
        my $partitioner     = $this -> __getChildNodeTextValue(
            $prefInfo, 'partitioner'
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
            partitioner          => $partitioner,
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
                    $this->{imageConfig}{$profName}{preferences},\%prefs
                );
                if (! $mergedPrefs ) {
                    return;
                }
                $this->{imageConfig}{$profName}{preferences} = $mergedPrefs;
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
        if ($type) {
            my $prim = $type -> getPrimary();
            if ($prim && $prim eq 'true') {
                $primaryCount++;
            }
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
# __clearInstallData
#------------------------------------------
sub __clearInstallData {
    # ...
    # Clear the given install data object in the proper
    # location in the data structure.
    # ---
    my $this       = shift;
    my $storeInfo  = shift;
    my $accessID   = $storeInfo->{accessID};
    my $arch       = $storeInfo->{arch};
    my $profName   = $storeInfo->{profName};
    my $type       = $storeInfo->{type};
    my $kiwi       = $this->{kiwi};
    if (! $accessID) {
        my $msg = 'Internal error: __clearInstallData called without '
            . 'accessID keyword argument.';
        $kiwi -> erro($msg);
        $kiwi -> failed();
        return;
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
    undef $entryPath->{$accessID};
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
    # If the object was already present return 1
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
        my %definedNames =
            map { ($_->getName() => 1) }  @{$entryPath->{$accessID}};
        my $name = $objToStore -> getName();
        my $oref = ref $objToStore;
        my $allowduplicates = 0;
        if ($oref eq 'KIWIXMLPackageData') {
            if ($objToStore -> getPackageToReplace()) {
                $allowduplicates = 1;
            }
        }
        if ($allowduplicates) {
            push @{$entryPath->{$accessID}}, $objToStore;
            $stored = $objToStore;
        } else {
            if (! $definedNames{$name}) {
                push @{$entryPath->{$accessID}}, $objToStore;
                $stored = $objToStore;
            }
        }
    } else {
        my $data = [$objToStore];
        $entryPath->{$accessID} = $data;
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
    if ($bootprofile) {
        $type -> setBootProfile ($bootprofile);
        push @list, split (/,/,$bootprofile);
    } else {
        $type -> setBootProfile ('default');
        push @list, 'default';
    }
    if ($bootkernel) {
        $type -> setBootKernel ($bootkernel);
        push @list, split (/,/,$bootkernel);
    } else {
        # apply 'std' kernel profile required for boot images
        $type -> setBootKernel ('std');
        push @list, 'std';
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
    my $arch     = KIWIQX::qxx ("uname -m"); chomp $arch;
    my $count    = 0;
    my $index    = 0;
    my @index    = ();
    my $error    = 0;
    my $satopt   = '';
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
    # check -X capability for sat tools
    #------------------------------------------
    KIWIQX::qxx ("mergesolv -X &>/dev/null");
    my $code = $? >> 8;
    if ($code == 0) {
        $satopt = '-X';
    }
    #==========================================
    # check/create cache directory
    #------------------------------------------
    my $sdir = "/var/tmp/kiwi/satsolver";
    my $sdir_orig = $sdir;
    if (! -d $sdir) {
        my $data = KIWIQX::qxx ("mkdir -m 777 -p $sdir 2>&1");
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
    $index = KIWIQX::qxx ("echo $index | md5sum | cut -f1 -d-");
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
    my $repoMD = $sdir."/repomd.xml-$$";
    foreach my $md (keys %repoxml) {
        if (KIWIGlobals->instance()->downloadFile ($repo.$md,$repoMD)) {
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
            if (($time) && ($curstamp eq $time)) {
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
        if ((! $time) || (! open ($RXML, '>', "$index.timestamp"))) {
            $kiwi -> failed ();
            $kiwi -> error ("--> Failed to create timestamp: $index.timestamp");
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
    # create tmp cache for repo data download
    #------------------------------------------
    $sdir = "/var/tmp/kiwi/satsolver/$$";
    my $data = KIWIQX::qxx ("mkdir -m 777 -p $sdir 2>&1");
    $code = $? >> 8;
    if ($code != 0) {
        $kiwi -> failed ();
        $kiwi -> error  ("--> Couldn't create tmp cache dir: $data");
        $kiwi -> failed ();
        return;
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
        if (KIWIGlobals->instance()->downloadFile ($repo.$dist,$destfile)) {
            $foundDist = 1;
        }
    }
    if (! $foundDist) {
        my $path = $repo; $path =~ s/dir:\/\///;
        my $data = KIWIQX::qxx (
            "rpms2solv $satopt $path/*.rpm > $sdir/primary-$count 2>&1"
        );
        my $code = $? >> 8;
        if ($code != 0) {
            $kiwi -> failed ();
            $kiwi -> error  (
                "--> Can't find/create a distribution solvable"
            );
            KIWIQX::qxx ("rm -f $sdir/primary-*");
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
        my $ok = KIWIGlobals->instance()->downloadFile ($repo.$patt,$destfile);
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
                if (! KIWIGlobals->instance()->downloadFile($file,$destfile)) {
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
            my $data = KIWIQX::qxx (
                "gzip -cd $file | rpmmd2solv > $destfile 2>&1"
            );
            my $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> failed ();
                $kiwi -> error  (
                    "--> Can't create SaT solvable file"
                );
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
            KIWIQX::qxx ("gzip -t $file &>/dev/null");
            my $code = $? >> 8;
            if ($code == 0) {
                $gzicmd .= $file." ";
            } else {
                $stdcmd .= $file." ";
            }
        }
        foreach my $file (glob ("$sdir/*.pat*")) {
            KIWIQX::qxx ("gzip -t $file &>/dev/null");
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
            my $data = KIWIQX::qxx (
                "$cmd | susetags2solv $satopt >> $destfile 2>/dev/null"
            );
            my $code = $? >> 8;
            if ($code != 0) {
                $kiwi -> failed ();
                $kiwi -> error  (
                    "--> Can't create SaT solvable file"
                );
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
                $data = KIWIQX::qxx ("$gzicmd | rpmmd2solv > $destfile 2>&1");
            } else {
                $stdcmd .= $file." ";
                $data = KIWIQX::qxx ("$stdcmd | rpmmd2solv > $destfile 2>&1");
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
            my $data = KIWIQX::qxx (
                "mergesolv $satopt $sdir/primary-* > $index"
            );
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
    KIWIQX::qxx ("rm -f $sdir_orig/repomd.xml-$$");
    KIWIQX::qxx ("rm -rf $sdir");
    if (! $error) {
        $kiwi -> done();
        return $index;
    } else {
        KIWIQX::qxx ("rm -f $index*");
    }
    return;
}

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
    return $this;
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
# __resolveLink
#------------------------------------------
sub __resolveLink {
    my $this = shift;
    my $arch = shift;
    my $data = $this -> __resolveArchitecture ($arch);
    my $cdir = KIWIQX::qxx ("pwd"); chomp $cdir;
    if (chdir $data) {
        my $pdir = KIWIQX::qxx ("pwd"); chomp $pdir;
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
