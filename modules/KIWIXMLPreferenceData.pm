#================
# FILE          : KIWIXMLPreferenceData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 20012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This module represents the data contained in the KIWI
#               : configuration file marked with the <preferences> element
#               : and simple type child elements. Complex child elements
#               : are implemented in their own type. The parent - child
#               : relationship is a construct at the XML data structure level.
#               : This design eliminates lengthy call chains such as
#               : XML -> type -> config -> getSomething
#               :
# STATUS        : Development
#----------------
package KIWIXMLPreferenceData;
#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;
use XML::LibXML;

#==========================================
# Base class
#------------------------------------------
use base qw /Exporter/;
use base qw /KIWIXMLDataBase/;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
  # ...
  # Create the KIWIXMLPreferenceData object
  #
  # Internal data structure
  #
  # this = {
  #     bootloader_theme     = ''
  #     bootsplash_theme     = ''
  #     defaultdestination   = ''
  #     defaultprebuilt      = ''
  #     defaultroot          = ''
  #     hwclock              = ''
  #     keymap               = ''
  #     locale               = ''
  #     packagemanager       = ''
  #     partitioner          = ''
  #     rpm_check_signatures = ''
  #     rpm_excludedocs      = ''
  #     rpm_force            = ''
  #     showlicense          = ''
  #     timezone             = ''
  #     types                = ''
  #     version              = ''
  # }
  # ---
  #==========================================
  # Object setup
  #------------------------------------------
  my $class = shift;
  my $this  = $class->SUPER::new(@_);
  #==========================================
  # Module Parameters
  #------------------------------------------
  my $init = shift;
  #==========================================
  # Argument checking and object data store
  #------------------------------------------
  # While <type> is a child of <preferences> the data is not in this class
  # the child relationship is enforced at the XML level.
  my %keywords = map { ($_ => 1) } qw(
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
  $this->{supportedKeywords} = \%keywords;
  my %boolKW = map { ($_ => 1) } qw(
    rpm_check_signatures
    rpm_excludedocs
    rpm_force
  );
  $this->{boolKeywords} = \%boolKW;
  if (! $this -> p_isInitHashRef($init) ) {
    return;
  }
  if (! $this -> p_areKeywordArgsValid($init) ) {
    return;
  }
  if ($init) {
    if (! $this -> __isInitConsistent($init)) {
      return;
    }
    $this -> p_initializeBoolMembers($init);
    $this->{bootloader_theme}     = $init->{bootloader_theme};
    $this->{bootsplash_theme}     = $init->{bootsplash_theme};
    $this->{defaultdestination}   = $init->{defaultdestination};
    $this->{defaultprebuilt}      = $init->{defaultprebuilt};
    $this->{defaultroot}          = $init->{defaultroot};
    $this->{hwclock}              = $init->{hwclock};
    $this->{keymap}               = $init->{keymap};
    $this->{locale}               = $init->{locale};
    $this->{packagemanager}       = $init->{packagemanager};
    $this->{partitioner}          = $init->{partitioner};
    $this->{showlicense}          = $init->{showlicense};
    $this->{timezone}             = $init->{timezone};
    $this->{version}              = $init->{version};
  }
  # Set default values
  my $global = KIWIGlobals -> instance();
  my $gdata = $global -> getKiwiConfig();
  if (! $init->{partitioner}) {
    $this->{partitioner} = $gdata->{Partitioner};
  }
  if (! $init->{packagemanager} ) {
    $this->{packagemanager} = $gdata->{PackageManager};
    $this->{defaultpackagemanager} = 1;
  }
  if (! $init->{bootloader_theme}) {
    $this->{bootloader_theme} = 'openSUSE';
  }
  if (! $init->{bootsplash_theme}) {
    $this->{bootsplash_theme} = 'openSUSE';
  }
  return $this;
}

#==========================================
# addShowLic
#------------------------------------------
sub addShowLic {
  # ...
  # Add a license to the configured licenses
  # ---
  my $this = shift;
  my $lic  = shift;
  if (! $lic ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'addShowLic: no path for the license given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  if (! $this->{showlicense} ) {
    my @licenses = ( $lic );
    $this->{showlicense} = \@licenses;
  } else {
    my @licenses = @{$this->{showlicense}};
    push @licenses, $lic;
    $this->{showlicense} = \@licenses;
  }
  return $this;
}

#==========================================
# getPartitioner
#------------------------------------------
sub getPartitioner {
  # ...
  # Return the configured partitioner
  # ---
  my $this = shift;
  return $this->{partitioner};
}

#==========================================
# getBootLoaderTheme
#------------------------------------------
sub getBootLoaderTheme {
  # ...
  # Return the configured boot loader theme
  # ---
  my $this = shift;
  return $this->{bootloader_theme};
}

#==========================================
# getBootSplashTheme
#------------------------------------------
sub getBootSplashTheme {
  # ...
  # Return the configured boot splash theme
  # ---
  my $this = shift;
  return $this->{bootsplash_theme};
}

#==========================================
# getDefaultDest
#------------------------------------------
sub getDefaultDest {
  # ...
  # Return the configured destination for the image
  # ---
  my $this = shift;
  return $this->{defaultdestination};
}

#==========================================
# getDefaultPreBuilt
#------------------------------------------
sub getDefaultPreBuilt {
  # ...
  # Return the configured location for pre built boot images
  # ---
  my $this = shift;
  return $this->{defaultprebuilt};
}

#==========================================
# getDefaultRoot
#------------------------------------------
sub getDefaultRoot {
  # ...
  # Return the configured default root location
  # ---
  my $this = shift;
  return $this->{defaultroot};
}

#==========================================
# getHWClock
#------------------------------------------
sub getHWClock {
  # ...
  # Return the configured timezone setting for the HW clock
  # ---
  my $this = shift;
  return $this->{hwclock};
}

#==========================================
# getKeymap
#------------------------------------------
sub getKeymap {
  # ...
  # Return the configured keyboard layout
  # ---
  my $this = shift;
  return $this->{keymap};
}

#==========================================
# getLocale
#------------------------------------------
sub getLocale {
  # ...
  # Return the configured localization setting
  # ---
  my $this = shift;
  return $this->{locale};
}

#==========================================
# getPackageManager
#------------------------------------------
sub getPackageManager {
  # ...
  # Return the configured package manager
  # ---
  my $this = shift;
  return $this->{packagemanager};
}

#==========================================
# getRPMCheckSig
#------------------------------------------
sub getRPMCheckSig {
  # ...
  # Return the configured flag for checking RPM signatures
  # ---
  my $this = shift;
  return $this->{rpm_check_signatures};
}

#==========================================
# getRPMExcludeDoc
#------------------------------------------
sub getRPMExcludeDoc {
  # ...
  # Return the configured flag for the RPM documentation exclusion setting
  # ---
  my $this = shift;
  return $this->{rpm_excludedocs};
}

#==========================================
# getRPMForce
#------------------------------------------
sub getRPMForce {
  # ...
  # Return the configured flag for forcing RPM installation
  # ---
  my $this = shift;
  return $this->{rpm_force};
}

#==========================================
# getShowLic
#------------------------------------------
sub getShowLic {
  # ...
  # Return an array ref containing the configured paths for the
  # license to be shown
  # ---
  my $this = shift;
  return $this->{showlicense};
}

#==========================================
# getTimezone
#------------------------------------------
sub getTimezone {
  # ...
  # Return the configured timezone
  # ---
  my $this = shift;
  return $this->{timezone};
}

#==========================================
# getVersion
#------------------------------------------
sub getVersion {
  # ...
  # Return the configured version for the configuration
  # ---
  my $this = shift;
  return $this->{version};
}

#==========================================
# getXMLElement
#------------------------------------------
sub getXMLElement {
  # ...
  # Return an XML Element representing the object's data
  # ---
  my $this = shift;
  my $element = XML::LibXML::Element -> new('preferences');
  my %initBLoadT = (
    parent    => $element,
    childName => 'bootloader-theme',
    text      => $this -> getBootLoaderTheme()
  );
  $element = $this -> p_addElement(\%initBLoadT);
  my %initBSplashT = (
    parent    => $element,
    childName => 'bootsplash-theme',
    text      => $this -> getBootSplashTheme()
  );
  $element = $this -> p_addElement(\%initBSplashT);
  my %initDefDest = (
    parent    => $element,
    childName => 'defaultdestination',
    text      => $this -> getDefaultDest()
  );
  $element = $this -> p_addElement(\%initDefDest);
  my %initDefPreB = (
    parent    => $element,
    childName => 'defaultprebuilt',
    text      => $this -> getDefaultPreBuilt()
  );
  $element = $this -> p_addElement(\%initDefPreB);
  my %initDefR = (
    parent    => $element,
    childName => 'defaultroot',
    text      => $this -> getDefaultRoot()
  );
  $element = $this -> p_addElement(\%initDefR);
  my %initClock = (
    parent    => $element,
    childName => 'hwclock',
    text      => $this -> getHWClock()
  );
  $element = $this -> p_addElement(\%initClock);
  my %initKeyB = (
    parent    => $element,
    childName => 'keytable',
    text      => $this -> getKeymap()
  );
  $element = $this -> p_addElement(\%initKeyB);
  my %initLoc = (
    parent    => $element,
    childName => 'locale',
    text      => $this -> getLocale()
  );
  $element = $this -> p_addElement(\%initLoc);
  if (! $this->{defaultpackagemanager}) {
    my %initPckgM = (
      parent    => $element,
      childName => 'packagemanager',
      text      => $this -> getPackageManager()
    );
    $element = $this -> p_addElement(\%initPckgM);
  }
  my %initRPMCSig = (
    parent    => $element,
    childName => 'rpm-check-signatures',
    text      => $this -> getRPMCheckSig()
  );
  $element = $this -> p_addElement(\%initRPMCSig);
  my %initRPMNDoc = (
    parent    => $element,
    childName => 'rpm-excludedocs',
    text      => $this -> getRPMExcludeDoc()
  );
  $element = $this -> p_addElement(\%initRPMNDoc);
  my %initRPMForce = (
    parent    => $element,
    childName => 'rpm-force',
    text      => $this -> getRPMForce()
  );
  $element = $this -> p_addElement(\%initRPMForce);
  my $license = $this -> getShowLic();
  for my $lic (@{$license}) {
    my %initShowLic = (
      parent    => $element,
      childName => 'showlicense',
      text      => $lic
    );
    $element = $this -> p_addElement(\%initShowLic);
  }
  my %initTimeZ = (
    parent    => $element,
    childName => 'timezone',
    text      => $this -> getTimezone()
  );
  $element = $this -> p_addElement(\%initTimeZ);
  my %initVer = (
    parent    => $element,
    childName => 'version',
    text      => $this -> getVersion()
  );
  $element = $this -> p_addElement(\%initVer);
  return $element;
}

#==========================================
# setPartitioner
#------------------------------------------
sub setPartitioner {
  # ...
  # Set the partitioner
  # ---
  my $this  = shift;
  my $pTool = shift;
  if (! $this -> __isValidPartitioner($pTool, 'setPartitioner') ) {
    return;
  }
  $this->{partitioner} = $pTool;
  return $this;
}

#==========================================
# setBootLoaderTheme
#------------------------------------------
sub setBootLoaderTheme {
  # ...
  # Set the boot loader theme configuration
  # ---
  my $this  = shift;
  my $theme = shift;
  if (! $theme ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setBootLoaderTheme: no boot loader theme argument given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{bootloader_theme} = $theme;
  return $this;
}

#==========================================
# setBootSplashTheme
#------------------------------------------
sub setBootSplashTheme {
  # ...
  # Set the boot splash theme
  # ---
  my $this = shift;
  my $theme = shift;
  if (! $theme ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setBootSplashTheme: no boot splash theme argument given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{bootsplash_theme} = $theme;
  return $this;
}

#==========================================
# setDefaultDest
#------------------------------------------
sub setDefaultDest {
  # ...
  # Set the destination for the image
  # ---
  my $this = shift;
  my $dest = shift;
  if (! $dest ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setDefaultDest: no destination argument given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{defaultdestination} = $dest;
  return $this;
}

#==========================================
# setDefaultPreBuilt
#------------------------------------------
sub setDefaultPreBuilt {
  # ...
  # Set the location for pre built boot images
  # ---
  my $this = shift;
  my $src  = shift;
  if (! $src ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setDefaultPreBuilt: no source for pre-built images given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{defaultprebuilt} = $src;
  return $this;
}

#==========================================
# setDefaultRoot
#------------------------------------------
sub setDefaultRoot {
  # ...
  # Set the default root location
  # ---
  my $this = shift;
  my $dest = shift;
  if (! $dest ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setDefaultRoot: no destination argument for default root '
      . 'tree given, retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{defaultroot} = $dest;
  return $this;
}

#==========================================
# setHWClock
#------------------------------------------
sub setHWClock {
  # ...
  # Set the timezone setting for the HW clock
  # ---
  my $this  = shift;
  my $clock = shift;
  if (! $clock ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setHWClock: no value for HW clock setting given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{hwclock} = $clock;
  return $this;
}

#==========================================
# setKeymap
#------------------------------------------
sub setKeymap {
  # ...
  # Set the keyboard layout
  # ---
  my $this = shift;
  my $kmap = shift;
  if (! $kmap ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setKeymap: no value for the keymap setting given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{keymap} = $kmap;
  return $this;
}

#==========================================
# setLocale
#------------------------------------------
sub setLocale {
  # ...
  # Set the localization setting
  # ---
  my $this = shift;
  my $loc  = shift;
  if (! $loc ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setLocale: no value for locale setting given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{locale} = $loc;
  return $this;
}

#==========================================
# setPackageManager
#------------------------------------------
sub setPackageManager {
  # ...
  # Set the package manager
  # ---
  my $this = shift;
  my $pMgr = shift;
  if (! $this -> __isValidPckgMgr($pMgr, 'setPackageManager') ) {
    return;
  }
  $this->{packagemanager} = $pMgr;
  return $this;
}

#==========================================
# setRPMCheckSig
#------------------------------------------
sub setRPMCheckSig {
  # ...
  # Set the flag for checking RPM signatures
  # ---
  my $this = shift;
  my $cSig = shift;
  my %settings = (
    attr   => 'rpm_check_signatures',
    value  => $cSig,
    caller => 'setRPMCheckSig'
  );
  if (! $this -> p_setBooleanValue(\%settings) ) {
    return;
  }
  return $this;
}

#==========================================
# setRPMExcludeDoc
#------------------------------------------
sub setRPMExcludeDoc {
  # ...
  # Set the flag for the RPM documentation exclusion setting
  # ---
  my $this = shift;
  my $eDoc = shift;
  my %settings = (
    attr   => 'rpm_excludedocs',
    value  => $eDoc,
    caller => 'setRPMExcludeDoc'
  );
  if (! $this -> p_setBooleanValue(\%settings) ) {
    return;
  }
  return $this;
}

#==========================================
# setRPMForce
#------------------------------------------
sub setRPMForce {
  # ...
  # Set the flag for forcing RPM installation
  # ---
  my $this  = shift;
  my $force = shift;
  my %settings = (
    attr   => 'rpm_force',
    value  => $force,
    caller => 'setRPMForce'
  );
  if (! $this -> p_setBooleanValue(\%settings) ) {
    return;
  }
  return $this;
}

#==========================================
# setShowLic
#------------------------------------------
sub setShowLic {
  # ...
  # Set the path for the license to be shown
  # ---
  my $this = shift;
  my $lic  = shift;
  if (! $lic ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setShowLic: no path for the license given, '
      . 'retaining current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  if (ref($lic) eq 'ARRAY') {
    $this->{showlicense} = $lic;
  } else {
    my @licenses = ( $lic );
    $this->{showlicense} = \@licenses;
  }
  return $this;
}

#==========================================
# setTimezone
#------------------------------------------
sub setTimezone {
  # ...
  # Set the timezone
  # ---
  my $this = shift;
  my $tz   = shift;
  if (! $tz ) {
    my $kiwi = $this->{kiwi};
    my $msg = 'setTimezone: no timezone argument given, retaining '
      . 'current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  $this->{timezone} = $tz;
  return $this;
}

#==========================================
# setVersion
#------------------------------------------
sub setVersion {
  # ...
  # Set the version for the configuration
  # ---
  my $this = shift;
  my $ver  = shift;
  if (! $this -> __isValidVersionFormat($ver, 'setVersion') ) {
    return;
  }
  $this->{version} = $ver;
  return $this;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __isInitConsistent
#------------------------------------------
sub __isInitConsistent {
  # ...
  # Verify that the initialization hash is valid
  # ---
  my $this = shift;
  my $init = shift;
  if (! $this -> p_areKeywordBooleanValuesValid($init) ) {
    return;
  }
  if ($init->{packagemanager}) {
    if (! $this->__isValidPckgMgr(
      $init->{packagemanager},'object initialization')) {
      return;
    }
  }
  if ($init->{partitioner}) {
    if (! $this->__isValidPartitioner(
      $init->{partitioner},'object initialization')) {
      return;
    }
  }
  if ($init->{showlicense}) {
    if (ref($init->{showlicense}) ne 'ARRAY') {
      my $kiwi = $this->{kiwi};
      my $msg = 'Expecting array ref as value of "showlicense" entry '
        . 'if defined.';
      $kiwi -> error($msg);
      $kiwi -> failed();
      return;
    }
  }
  if ($init->{version}) {
    if (! $this->__isValidVersionFormat(
      $init->{version},'object initialization')) {
      return;
    }
  }
  return 1;
}

#==========================================
# __isValidPckgMgr
#------------------------------------------
sub __isValidPckgMgr {
  # ...
  # Verify that the given package manager is supported
  # ---
  my $this   = shift;
  my $pMgr   = shift;
  my $caller = shift;
  my $kiwi = $this->{kiwi};
  if (! $caller ) {
    my $msg = 'Internal error __isValidPckgMgr called without '
      . 'call origin argument.';
    $kiwi -> info($msg);
    $kiwi -> oops();
  }
  if (! $pMgr ) {
    my $msg = "$caller: no packagemanager argument specified, retaining "
      . 'current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  my %supported = map { ($_ => 1) } qw( apt-get smart ensconce yum zypper );
  if (! $supported{$pMgr} ) {
    my $msg = "$caller: specified package manager '$pMgr' is not "
      . 'supported.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  return 1;
}

#==========================================
# __isValidPartitioner
#------------------------------------------
sub __isValidPartitioner {
  # ...
  # Verify that the given partitioner is supported
  # ---
  my $this   = shift;
  my $pTool  = shift;
  my $caller = shift;
  my $kiwi = $this->{kiwi};
  if (! $caller ) {
    my $msg = 'Internal error __isValidPartitioner called without '
      . 'call origin argument.';
    $kiwi -> info($msg);
    $kiwi -> oops();
  }
  if (! $pTool ) {
    my $msg = "$caller: no packagemanager argument specified, retaining "
      . 'current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  my %supported = map { ($_ => 1) } qw( parted fdasd );
  if (! $supported{$pTool} ) {
    my $msg = "$caller: specified partitioner '$pTool' is not supported.";
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  return 1;
}

#==========================================
# __isValidVersionFormat
#------------------------------------------
sub __isValidVersionFormat {
  # ...
  # Verify that the given version is in the expected format
  # ---
  my $this   = shift;
  my $ver    = shift;
  my $caller = shift;
  my $kiwi = $this->{kiwi};
  if (! $caller ) {
    my $msg = 'Internal error __isValidVersionFormat called without '
      . 'call origin argument.';
    $kiwi -> info($msg);
    $kiwi -> oops();
  }
  if (! $ver ) {
    my $msg = "$caller: no version argument specified, retaining "
      . 'current data.';
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  if ( $ver !~ /^\d+?\.\d+?\.\d+?$/smx ) {
    my $msg = "$caller: improper version format, expecting 'd.d.d'.";
    $kiwi -> error($msg);
    $kiwi -> failed();
    return;
  }
  return 1;
}

1;
