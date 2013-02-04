#================
# FILE          : kiwiXMLPreferenceData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the  KIWIXMLPreferenceData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLPreferenceData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLPreferenceData;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	return $this;
}

#==========================================
# test_addShowLic
#------------------------------------------
sub test_addShowLic {
	# ...
	# Test the addShowLic method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	$prefDataObj = $prefDataObj -> addShowLic('/tmp/lic.en.txt');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $lic = $prefDataObj -> getShowLic();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ( '/tmp/lic.en.txt', '/wrk/mylic.txt', '/wrk/prodlic.txt' );
	$this -> assert_array_equal(\@expected, $lic);
	return;
}

#==========================================
# test_addShowLicNoArg
#------------------------------------------
sub test_addShowLicNoArg {
	# ...
	# Test the setShowLic method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> addShowLic();
	my $msg = $kiwi -> getMessage();
	my $expected = 'addShowLic: no path for the license given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $lic = $prefDataObj -> getShowLic();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ('/wrk/mylic.txt', '/wrk/prodlic.txt');
	$this -> assert_array_equal(\@expected, $lic);
	return;
}

#==========================================
# test_ctor
#------------------------------------------
sub test_ctor {
	# ...
	# Test the PreferenceData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($prefDataObj);
	return;
}

#==========================================
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the PreferenceData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as first argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prefDataObj);
	return;
}

#==========================================
# test_ctor_initInvalidRPMCheckSigValue
#------------------------------------------
sub test_ctor_initInvalidRPMCheckSigValue {
	# ...
	# Test the PreferenceData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the checkprebuilt value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( rpm_check_signatures => 'foo' );
	 my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'KIWIXMLPreferenceData: Unrecognized value for '
		. "boolean 'rpm_check_signatures' in initialization structure.";
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($prefDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidRPMExclDocValue
#------------------------------------------
sub test_ctor_initInvalidRPMExclDocValue {
	# ...
	# Test the PreferenceData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the compressed value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( rpm_excludedocs => 'foo' );
	 my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'KIWIXMLPreferenceData: Unrecognized value for boolean '
		. "'rpm_excludedocs' in initialization structure.";
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($prefDataObj);
	 return;
}

#==========================================
# test_ctor_initInvalidRPMForceValue
#------------------------------------------
sub test_ctor_initInvalidRPMForceValue {
	# ...
	# Test the PreferenceData constructor with an initialization hash
	# that contains an unrecognized boolen initialization for
	# the fsnocheck value
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( rpm_force => 'foo' );
	 my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'KIWIXMLPreferenceData: Unrecognized value for boolean '
		. "'rpm_force' in initialization structure.";
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($prefDataObj);
	 return;
}


#==========================================
# test_ctor_initInvalidVersion
#------------------------------------------
sub test_ctor_initInvalidVersion {
	# ...
	# Test the PreferenceData constructor with an initialization hash
	# that contains an invalid version format
	# ----
	 my $this = shift;
	 my $kiwi = $this -> {kiwi};
	 my %init = ( version => '1.a' );
	 my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	 my $msg = $kiwi -> getMessage();
	 my $expected = 'object initialization: improper version format, '
		. "expecting 'd.d.d'.";
	 $this -> assert_str_equals($expected, $msg);
	 my $msgT = $kiwi -> getMessageType();
	 $this -> assert_str_equals('error', $msgT);
	 my $state = $kiwi -> getState();
	 $this -> assert_str_equals('failed', $state);
	 # Test this condition last to get potential error messages
	 $this -> assert_null($prefDataObj);
	 return;
}

#==========================================
# test_ctor_initUnsupportedData
#------------------------------------------
sub test_ctor_initUnsupportedData {
	# ...
	# Test the PreferenceData constructor with an initialization hash
	# that contains unsupported data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( zypperopt => '--capability' );
	my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPreferenceData: Unsupported keyword argument '
		. "'zypperopt' in initialization structure.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prefDataObj);
	return;
}

#==========================================
# test_ctor_initUnsupportedPckgMgr
#------------------------------------------
sub test_ctor_initUnsupportedPckgMgr {
	# ...
	# Test the PreferenceDataconstructor with an initialization hash
	# that contains unsupported data for the package manager
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( packagemanager => 'foo' );
	my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'object initialization: specified package manager '
		. "'foo' is not supported.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($prefDataObj);
	return;
}

#==========================================
# test_ctor_withInit
#------------------------------------------
sub test_ctor_withInit {
	# ...
	# Test the PreferenceData constructor with an initialization hash
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( bootloader_theme => 'openSUSE',
				hwclock          => 'utc',
				packagemanager   => 'yum',
				version          => '1.1.0'
			);
	my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($prefDataObj);
	return;
}

#==========================================
# test_getBootLoaderTheme
#------------------------------------------
sub test_getBootLoaderTheme {
	# ...
	# Test the getBootLoaderTheme method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $bLT = $prefDataObj -> getBootLoaderTheme();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('openSUSE', $bLT);
	return;
}

#==========================================
# test_getBootSplashTheme
#------------------------------------------
sub test_getBootSplashTheme {
	# ...
	# Test the getBootSplashTheme method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $bST = $prefDataObj -> getBootSplashTheme();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('openSUSE', $bST);
	return;
}

#==========================================
# test_getDefaultDest
#------------------------------------------
sub test_getDefaultDest {
	# ...
	# Test the getDefaultDest method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $defD = $prefDataObj -> getDefaultDest();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/wrk/images', $defD );
	return;
}

#==========================================
# test_getDefaultPreBuilt
#------------------------------------------
sub test_getDefaultPreBuilt {
	# ...
	# Test the getDefaultPreBuilt method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $defPB = $prefDataObj -> getDefaultPreBuilt();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/wrk/bootimgs', $defPB);
	return;
}

#==========================================
# test_getDefaultRoot
#------------------------------------------
sub test_getDefaultRoot {
	# ...
	# Test the getDefaultRoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $defR = $prefDataObj -> getDefaultRoot();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/wrk/myunpacked', $defR);
	return;
}

#==========================================
# test_getHWClock
#------------------------------------------
sub test_getHWClock {
	# ...
	# Test the getHWClock method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $hwc = $prefDataObj -> getHWClock();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('utc', $hwc);
	return;
}

#==========================================
# test_getKeymap
#------------------------------------------
sub test_getKeymap {
	# ...
	# Test the getKeymap method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $kMap = $prefDataObj -> getKeymap();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('us.map.gz', $kMap);
	return;
}

#==========================================
# test_getLocale
#------------------------------------------
sub test_getLocale {
	# ...
	# Test the getLocale method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $locale = $prefDataObj -> getLocale();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('en_us', $locale);
	return;
}

#==========================================
# test_getPackageManager
#------------------------------------------
sub test_getPackageManager{
	# ...
	# Test the getPackageManager method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $pkM = $prefDataObj -> getPackageManager();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('smart', $pkM);
	return;
}

#==========================================
# test_getPackageManagerDefault
#------------------------------------------
sub test_getPackageManagerDefault {
	# ...
	# Test the getPackageManager method, verify the default setting
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	my $pkM = $prefDataObj -> getPackageManager();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('zypper', $pkM);
	return;
}

#==========================================
# test_getRPMCheckSig
#------------------------------------------
sub test_getRPMCheckSig {
	# ...
	# Test the getRPMCheckSig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $rcs = $prefDataObj -> getRPMCheckSig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $rcs);
	return;
}

#==========================================
# test_getRPMExcludeDoc
#------------------------------------------
sub test_getRPMExcludeDoc {
	# ...
	# Test the getRPMExcludeDoc method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $red = $prefDataObj -> getRPMExcludeDoc();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $red);
	return;
}

#==========================================
# test_getRPMForce
#------------------------------------------
sub test_getRPMForce {
	# ...
	# Test the getRPMForce method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $rForce = $prefDataObj -> getRPMForce();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $rForce);
	return;
}

#==========================================
# test_getShowLic
#------------------------------------------
sub test_getShowLic {
	# ...
	# Test the getShowLic method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $lic = $prefDataObj -> getShowLic();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ('/wrk/mylic.txt', '/wrk/prodlic.txt');
	$this -> assert_array_equal(\@expected, $lic);
	return;
}

#==========================================
# test_getTimezone
#------------------------------------------
sub test_getTimezone {
	# ...
	# Test the getTimezone method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $tz = $prefDataObj -> getTimezone();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('America/NewYork', $tz);
	return;
}

#==========================================
# test_getVersion
#------------------------------------------
sub test_getVersion{
	# ...
	# Test the getVersion method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $ver = $prefDataObj -> getVersion();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1.1.1', $ver);
	return;
}

#==========================================
# test_getXMLElement
#------------------------------------------
sub test_getXMLElement {
	# ...
	# Verify that the getXMLElement method returns a node
	# with the proper data.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $elem = $prefDataObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<preferences>'
		. '<bootloader-theme>openSUSE</bootloader-theme>'
		. '<bootsplash-theme>openSUSE</bootsplash-theme>'
		. '<defaultdestination>/wrk/images</defaultdestination>'
		. '<defaultprebuilt>/wrk/bootimgs</defaultprebuilt>'
		. '<defaultroot>/wrk/myunpacked</defaultroot>'
		. '<hwclock>utc</hwclock>'
		. '<keytable>us.map.gz</keytable>'
		. '<locale>en_us</locale>'
		. '<packagemanager>smart</packagemanager>'
		. '<rpm-check-signatures>true</rpm-check-signatures>'
		. '<rpm-excludedocs>true</rpm-excludedocs>'
		. '<rpm-force>true</rpm-force>'
		. '<showlicense>/wrk/mylic.txt</showlicense>'
		. '<showlicense>/wrk/prodlic.txt</showlicense>'
		. '<timezone>America/NewYork</timezone>'
		. '<version>1.1.1</version>'
		. '</preferences>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setBootLoaderTheme
#------------------------------------------
sub test_setBootLoaderTheme {
	# ...
	# Test the setBootLoaderTheme method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setBootLoaderTheme('SLES');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $theme = $prefDataObj -> getBootLoaderTheme();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SLES', $theme);
	return;
}

#==========================================
# test_setBootLoaderThemeNoArg
#------------------------------------------
sub test_setBootLoaderThemeNoArg {
	# ...
	# Test the setBootLoaderTheme method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setBootLoaderTheme();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootLoaderTheme: no boot loader theme argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $theme = $prefDataObj -> getBootLoaderTheme();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('openSUSE', $theme);
	return;
}

#==========================================
# test_setBootSplashTheme
#------------------------------------------
sub test_setBootSplashTheme {
	# ...
	# Test the setBootSplashTheme method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setBootSplashTheme('SLES');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $theme = $prefDataObj -> getBootSplashTheme();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SLES', $theme);
	return;
}

#==========================================
# test_setBootSplashThemeNoArg
#------------------------------------------
sub test_setBootSplashThemeNoArg {
	# ...
	# Test the setBootSplashTheme method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setBootSplashTheme();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setBootSplashTheme: no boot splash theme argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $theme = $prefDataObj -> getBootSplashTheme();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('openSUSE', $theme);
	return;
}

#==========================================
# test_setDefaultDest
#------------------------------------------
sub test_setDefaultDest {
	# ...
	# Test the setDefaultDest method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setDefaultDest('/tmp/images');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $dest = $prefDataObj -> getDefaultDest();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/tmp/images', $dest);
	return;
}

#==========================================
# test_setDefaultDestNoArg
#------------------------------------------
sub test_setDefaultDestNoArg {
	# ...
	# Test the setDefaultDest method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setDefaultDest();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDefaultDest: no destination argument given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $dest = $prefDataObj -> getDefaultDest();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/wrk/images', $dest);
	return;
}

#==========================================
# test_setDefaultPreBuilt
#------------------------------------------
sub test_setDefaultPreBuilt {
	# ...
	# Test the setDefaultPreBuilt method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setDefaultPreBuilt('/tmp/images');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $src = $prefDataObj -> getDefaultPreBuilt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/tmp/images', $src);
	return;
}

#==========================================
# test_setDefaultPreBuiltNoArg
#------------------------------------------
sub test_setDefaultPreBuiltNoArg {
	# ...
	# Test the setDefaultPreBuilt method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setDefaultPreBuilt();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDefaultPreBuilt: no source for pre-built images given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $src = $prefDataObj -> getDefaultPreBuilt();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/wrk/bootimgs', $src);
	return;
}

#==========================================
# test_setDefaultRoot
#------------------------------------------
sub test_setDefaultRoot {
	# ...
	# Test the setDefaultRoot method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setDefaultRoot('/tmp/images');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $dest = $prefDataObj -> getDefaultRoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/tmp/images', $dest);
	return;
}

#==========================================
# test_setDefaultRootNoArg
#------------------------------------------
sub test_setDefaultRootNoArg {
	# ...
	# Test the setDefaultRoot method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setDefaultRoot();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDefaultRoot: no destination argument for default root '
		. 'tree given, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $dest = $prefDataObj -> getDefaultRoot();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/wrk/myunpacked', $dest);
	return;
}

#==========================================
# test_setHWClock
#------------------------------------------
sub test_setHWClock {
	# ...
	# Test the setHWClock method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setHWClock('America/NewYork');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $clock = $prefDataObj -> getHWClock();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('America/NewYork', $clock);
	return;
}

#==========================================
# test_setHWClockNoArg
#------------------------------------------
sub test_setHWClockNoArg {
	# ...
	# Test the setHWClock method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setHWClock();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setHWClock: no value for HW clock setting given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $clock = $prefDataObj -> getHWClock();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('utc', $clock);
	return;
}

#==========================================
# test_setKeymap
#------------------------------------------
sub test_setKeymap {
	# ...
	# Test the setKeymap method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setKeymap('de.map.gz');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $kmap = $prefDataObj -> getKeymap();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('de.map.gz', $kmap);
	return;
}

#==========================================
# test_setKeymapNoArg
#------------------------------------------
sub test_setKeymapNoArg {
	# ...
	# Test the setKeymap method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setKeymap();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setKeymap: no value for the keymap setting given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $kmap = $prefDataObj -> getKeymap();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('us.map.gz', $kmap);
	return;
}

#==========================================
# test_setLocale
#------------------------------------------
sub test_setLocale {
	# ...
	# Test the setLocale method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setLocale('cs_CZ');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $loc = $prefDataObj -> getLocale();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('cs_CZ', $loc);
	return;
}

#==========================================
# test_setLocaleNoArg
#------------------------------------------
sub test_setLocaleNoArg {
	# ...
	# Test the setLocale method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setLocale();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setLocale: no value for locale setting given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $loc = $prefDataObj -> getLocale();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('en_us', $loc);
	return;
}

#==========================================
# test_setPackageManager
#------------------------------------------
sub test_setPackageManager {
	# ...
	# Test the setPackageManager method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setPackageManager('yum');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $pMgr = $prefDataObj -> getPackageManager();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('yum', $pMgr);
	return;
}

#==========================================
# test_setPackageManagerInvalidArg
#------------------------------------------
sub test_setPackageManagerInvalidArg {
	# ...
	# Test the setPackageManager method with an unsupported manager arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	my $res = $prefDataObj -> setPackageManager('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = "setPackageManager: specified package manager 'foo' is not "
		. 'supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $pMgr = $prefDataObj -> getPackageManager();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('zypper', $pMgr);
	return;
}

#==========================================
# test_setPackageManagerNoArg
#------------------------------------------
sub test_setPackageManagerNoArg {
	# ...
	# Test the setPackageManager method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setPackageManager();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setPackageManager: no packagemanager argument specified, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $pMgr = $prefDataObj -> getPackageManager();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('smart', $pMgr);
	return;
}

#==========================================
# test_setRPMCheckSig
#------------------------------------------
sub test_setRPMCheckSig {
	# ...
	# Test the setRPMCheckSig method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setRPMCheckSig('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $cSig = $prefDataObj -> getRPMCheckSig();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $cSig);
	return;
}

#==========================================
# test_setRPMCheckSigNoArg
#------------------------------------------
sub test_setRPMCheckSigNoArg {
	# ...
	# Test the setRPMCheckSig method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	$prefDataObj = $prefDataObj -> setRPMCheckSig();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $cSig = $prefDataObj -> getRPMCheckSig();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $cSig);
	return;
}

#==========================================
# test_setRPMCheckSigUnknownArg
#------------------------------------------
sub test_setRPMCheckSigUnknownArg {
	# ...
	# Test the setRPMCheckSig method with an unsupported boolean
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setRPMCheckSig('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPreferenceData:setRPMCheckSig: unrecognized '
		. 'argument expecting "true" or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $cSig = $prefDataObj -> getRPMCheckSig();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $cSig);
	return;
}

#==========================================
# test_setRPMExcludeDoc
#------------------------------------------
sub test_setRPMExcludeDoc {
	# ...
	# Test the setRPMExcludeDoc method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setRPMExcludeDoc('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $eDoc = $prefDataObj -> getRPMExcludeDoc();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $eDoc);
	return;
}

#==========================================
# test_setRPMExcludeDocNoArg
#------------------------------------------
sub test_setRPMExcludeDocNoArg {
	# ...
	# Test the setRPMExcludeDoc method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	$prefDataObj = $prefDataObj -> setRPMExcludeDoc();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $eDoc = $prefDataObj -> getRPMExcludeDoc();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $eDoc);
	return;
}

#==========================================
# test_setRPMExcludeDocUnknownArg
#------------------------------------------
sub test_setRPMExcludeDocUnknownArg {
	# ...
	# Test the setRPMExcludeDoc method with an unsupported boolean
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setRPMExcludeDoc('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPreferenceData:setRPMExcludeDoc: unrecognized '
		. 'argument expecting "true" or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $eDoc = $prefDataObj -> getRPMExcludeDoc();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $eDoc);
	return;
}

#==========================================
# test_setRPMForce
#------------------------------------------
sub test_setRPMForce {
	# ...
	# Test the setRPMForce method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setRPMForce('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $force = $prefDataObj -> getRPMForce();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $force);
	return;
}

#==========================================
# test_setRPMForceNoArg
#------------------------------------------
sub test_setRPMForceNoArg {
	# ...
	# Test the setRPMForce method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	$prefDataObj = $prefDataObj -> setRPMForce();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $force = $prefDataObj -> getRPMForce();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $force);
	return;
}

#==========================================
# test_setRPMForceUnknownArg
#------------------------------------------
sub test_setRPMForceUnknownArg {
	# ...
	# Test the setRPMForce method with an unsupported boolean
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setRPMForce('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPreferenceData:setRPMForce: unrecognized argument '
		. 'expecting "true" or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $force = $prefDataObj -> getRPMForce();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $force);
	return;
}

#==========================================
# test_setShowLic
#------------------------------------------
sub test_setShowLic {
	# ...
	# Test the setShowLic method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setShowLic('/tmp/lic.en.txt');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $lic = $prefDataObj -> getShowLic();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ( '/tmp/lic.en.txt' );
	$this -> assert_array_equal(\@expected, $lic);
	return;
}

#==========================================
# test_setShowLicNoArg
#------------------------------------------
sub test_setShowLicNoArg {
	# ...
	# Test the setShowLic method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setShowLic();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setShowLic: no path for the license given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $lic = $prefDataObj -> getShowLic();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ('/wrk/mylic.txt', '/wrk/prodlic.txt');
	$this -> assert_array_equal(\@expected, $lic);
	return;
}

#==========================================
# test_setTimezone
#------------------------------------------
sub test_setTimezone {
	# ...
	# Test the setTimezone method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setTimezone('Germany/Berlin');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $tz = $prefDataObj -> getTimezone();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('Germany/Berlin', $tz);
	return;
}

#==========================================
# test_setTimezoneNoArg
#------------------------------------------
sub test_setTimezoneNoArg {
	# ...
	# Test the setTimezone method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setTimezone();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setTimezone: no timezone argument given, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $tz = $prefDataObj -> getTimezone();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('America/NewYork', $tz);
	return;
}

#==========================================
# test_setVersion
#------------------------------------------
sub test_setVersion {
	# ...
	# Test the setVersion method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLPreferenceData -> new();
	$prefDataObj = $prefDataObj -> setVersion('0.0.5');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($prefDataObj);
	my $ver = $prefDataObj -> getVersion();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('0.0.5', $ver);
	return;
}

#==========================================
# test_setVersionInvalidArg
#------------------------------------------
sub test_setVersionInvalidArg {
	# ...
	# Test the setVersion method with an unsupported manager arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setVersion('1');
	my $msg = $kiwi -> getMessage();
	my $expected = "setVersion: improper version format, expecting 'd.d.d'.";
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $ver = $prefDataObj -> getVersion();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1.1.1', $ver);
	return;
}

#==========================================
# test_setVersionNoArg
#------------------------------------------
sub test_setVersionNoArg {
	# ...
	# Test the setVersion method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = $this -> __getPrefObj();
	my $res = $prefDataObj -> setVersion();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setVersion: no version argument specified, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $ver = $prefDataObj -> getVersion();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('1.1.1', $ver);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getPrefObj
#------------------------------------------
sub __getPrefObj {
	# ...
	# Helper to construct a fully populated Preference object using
	# initialization
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @licenses = ('/wrk/mylic.txt', '/wrk/prodlic.txt');
	my %init = (
		bootloader_theme     => 'openSUSE',
		bootsplash_theme     => 'openSUSE',
		defaultdestination   => '/wrk/images',
		defaultprebuilt      => '/wrk/bootimgs',
		defaultroot          => '/wrk/myunpacked',
		hwclock              => 'utc',
		keymap               => 'us.map.gz',
		locale               => 'en_us',
		packagemanager       => 'smart',
		rpm_check_signatures => 'true',
		rpm_excludedocs      => 'true',
		rpm_force            => 'true',
		showlicense          => \@licenses,
		timezone             => 'America/NewYork',
		version              => '1.1.1'
	);
	my $prefDataObj = KIWIXMLPreferenceData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($prefDataObj);
	return $prefDataObj;
}

1;
