#================
# FILE          : KIWIXMLPreferenceData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
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
require Exporter;

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
	my $init = shift;
	#==========================================
	# Argument checking and object data store
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	if ($init && ref($init) ne 'HASH') {
		my $msg = 'Expecting a hash ref as second argument if provided';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if ($init) {
		# Check for unsupported entries
		my %supported = map { ($_ => 1) } qw(
			bootloader_theme bootsplash_theme defaultdestination
			defaultprebuilt defaultroot hwclock keytable locale
			packagemanager rpm_check_signatures rpm_excludedocs rpm_force
			showlicense timezone version
		);
		for my $key (keys %{$init}) {
			if (! $supported{$key} ) {
				my $msg = 'Unsupported option in initialization structure '
					. "found '$key'";
				$kiwi -> error($msg);
				$kiwi -> failed();
				return;
			}
		}
		if (! $this -> __isValidInit($init)) {
			return;
		}
		$this->{bootloader_theme}     = $init->{bootloader_theme};
		$this->{bootsplash_theme}     = $init->{bootsplash_theme};
		$this->{defaultdestination}   = $init->{defaultdestination};
		$this->{defaultprebuilt}      = $init->{defaultprebuilt};
		$this->{defaultroot}          = $init->{defaultroot};
		$this->{hwclock}              = $init->{hwclock};
		$this->{keytable}             = $init->{keytable};
		$this->{locale}               = $init->{locale};
		$this->{packagemanager}       = $init->{packagemanager};
		$this->{rpm_check_signatures} = $init->{rpm_check_signatures};
		$this->{rpm_excludedocs}      = $init->{rpm_excludedocs};
		$this->{rpm_force}            = $init->{rpm_force};
		$this->{showlicense}          = $init->{showlicense};
		$this->{timezone}             = $init->{timezone};
		$this->{version}              = $init->{version};
	}
	# Set default values
	if (! $this->{packagemanager} ) {
		$this->{packagemanager}   = 'zypper';
	}
	return $this;
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
	return $this->{keytable};
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
	# Return the configured path for the license to be shown
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
	$this->{keytable} = $kmap;
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
	my %settings = ( attr   => 'rpm_check_signatures',
					value  => $cSig,
					caller => 'setRPMCheckSig'
				);
	if (! $this -> __setBoolean(\%settings) ) {
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
	my %settings = ( attr   => 'rpm_excludedocs',
					value  => $eDoc,
					caller => 'setRPMExcludeDoc'
				);
	if (! $this -> __setBoolean(\%settings) ) {
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
	my %settings = ( attr   => 'rpm_force',
					value  => $force,
					caller => 'setRPMForce'
				);
	if (! $this -> __setBoolean(\%settings) ) {
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
	$this->{showlicense} = $lic;
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
# __checkBools
#------------------------------------------
sub __checkBools {
	# ...
	# Check all the boolean values in the ctor initialization hash
	# to verify if the values are valid.
	# ---
	my $this = shift;
	my $init = shift;
	my @boolAttrs = qw(
		rpm_check_signatures rpm_excludedocs rpm_force
	);
	for my $attr (@boolAttrs) {
		if (! $this -> __isValidBool($init->{$attr}) ) {
			my $kiwi = $this->{kiwi};
			my $msg = "Unrecognized value for boolean '$attr' in "
				. 'initialization hash, expecting "true" or "false".';
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
	}
	return 1;
}

#==========================================
# __isValidBool
#------------------------------------------
sub __isValidBool {
	# ...
	# Verify that the given boolean is set with a recognized value
	# true, false, or undef (undef maps to false
	# ---
	my $this = shift;
	my $bVal = shift;
	if (! $bVal || $bVal eq 'false' || $bVal eq 'true') {
		return 1;
	}
	return;
}
#==========================================
# __isValidInit
#------------------------------------------
sub __isValidInit {
	# ...
	# Verify that the initialization hash is valid
	# ---
	my $this = shift;
	my $init = shift;
	if (! $this -> __checkBools($init) ) {
		return;
	}
	if ($init->{packagemanager}) {
		if (! $this->__isValidPckgMgr($init->{packagemanager},
										'object initialization')) {
			return;
		}
	}
	if ($init->{version}) {
		if (! $this->__isValidVersionFormat($init->{version},
										'object initialization')) {
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
	my %supported = map { ($_ => 1) } qw( smart ensconce yum zypper );
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

#==========================================
# __setBoolean
#------------------------------------------
sub __setBoolean {
	# ...
	# Generic code to set the given boolean attribute on the object
	# ---
	my $this     = shift;
	my $settings = shift;
	my $attr   = $settings->{attr};
	my $bVal   = $settings->{value};
	my $caller = $settings->{caller};
	my $kiwi   = $this->{kiwi};
	if (! $attr ) {
		my $msg = 'Internal error __setBoolean called without '
			. 'attribute to set.';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $caller ) {
		my $msg = 'Internal error __setBoolean called without '
			. 'call origin argument.';
		$kiwi -> info($msg);
		$kiwi -> oops();
	}
	if (! $this -> __isValidBool($bVal) ) {
		my $msg = "$caller: unrecognized argument expecting "
			. '"true" or "false".';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	if (! $bVal) {
		$this->{$attr} = 'false';
	} else {
		$this->{$attr} = $bVal;
	}
		
	return $this;
}

1;
