#================
# FILE          : kiwiXMLPackageCollectData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIPackageCollectData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLPackageCollectData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLPackageCollectData;

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
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the PackageCollectData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $collectDataObj = KIWIXMLPackageCollectData -> new();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageCollectData: must be constructed with a '
		. 'keyword hash as argument';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($collectDataObj);
	return;
}

#==========================================
# test_ctor_unsuportedArch
#------------------------------------------
sub test_ctor_unsuportedArch {
	# ...
	# Test the PackageCollectData constructor with an unsupported architecture
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				arch => 'tegra',
				name => 'kde'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "Specified arch 'tegra' is not supported";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($collectDataObj);
	return;
}

#==========================================
# test_ctor_simple
#------------------------------------------
sub test_ctor_simple {
	# ...
	# Test proper construction with only the name argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( name => 'xfce' );
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	return;
}

#==========================================
# test_ctor_invalidBoolValIncl
#------------------------------------------
sub test_ctor_invalidBoolValIncl {
	# ...
	# Test the PackageData constructor with an invalid value for the
	# bootinclude keyword
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
	    bootinclude => 'yes',
		name        => 'python'
	);
	my $pckgDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageCollectData: Unrecognized value for '
		. "boolean 'bootinclude' in initialization structure.";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($pckgDataObj);
	return;
}

#==========================================
# test_ctor_unsupportedKW
#------------------------------------------
sub test_ctor_unsupportedKW {
	# ...
	# Test constructor with an unsupported keyword in the initialization data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
	    arch     => 'ppc64',
		filename => 'lamp'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageCollectData: Unsupported keyword '
		. "argument 'filename' in initialization structure.";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($collectDataObj);
	return;
}

#==========================================
# test_ctor_withArch
#------------------------------------------
sub test_ctor_withArch {
	# ...
	# Test proper construction with only the name argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				arch => 'ppc64',
				name => 'base'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	return;
}

#==========================================
# test_getArch
#------------------------------------------
sub test_getArch {
	# ...
	# Verify that the proper architecture value is returned.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				arch => 'i686',
				name => 'gnome'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $collectDataObj -> getArch();
	$this -> assert_str_equals('i686', $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	return;
}

#==========================================
# test_getBootInclude
#------------------------------------------
sub test_getBootInclude {
	# ...
	# Verify that the bootinclude setting is properly returned.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
	    arch        => 'i686',
		bootinclude => 'true',
		name        => 'base'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $incl = $collectDataObj -> getBootInclude();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $incl);
	return;
}

#==========================================
# test_getName
#------------------------------------------
sub test_getName {
	# ...
	# Verify that the proper name is returned.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( name => 'x11');
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $collectDataObj -> getName();
	$this -> assert_str_equals('x11', $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	return;
}

#==========================================
# test_getXMLElement
#------------------------------------------
sub test_getXMLElement{
	# ...
	# Verify that the getXMLElement method returns a node
	# with the proper data.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		arch        => 'ppc',
		bootinclude => 'true',
		name        => 'base'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $elem = $collectDataObj -> getXMLElement();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<namedCollection name="base" arch="ppc" '
		. 'bootinclude="true"/>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setArch
#------------------------------------------
sub test_setArch {
	# ...
	# Verify that the proper architecture value is set and returned.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( name => 'base');
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $collectDataObj -> setArch('x86_64');
	$this -> assert_equals(1, $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$value = $collectDataObj -> getArch();
	$this -> assert_str_equals('x86_64', $value);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	return;
}

#==========================================
# test_setArch_invalid
#------------------------------------------
sub test_setArch_invalid {
	# ...
	# Verify proper error condition handling for setArch().
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( name => 'lxde');
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $collectDataObj -> setArch('tegra');
	my $expectedMsg = "Specified arch 'tegra' is not supported";
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expectedMsg, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($value);
	$value = $collectDataObj -> getArch();
	$this -> assert_null($value);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	return;
}

#==========================================
# test_setBootInclude
#------------------------------------------
sub test_setBootInclude {
	# ...
	# Test the setBootInclude method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
	    arch        => 'i686',
		bootinclude => 'true',
		name        => 'base'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	$collectDataObj = $collectDataObj -> setBootInclude('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	my $bincl = $collectDataObj -> getBootInclude();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $bincl);
	return;
}

#==========================================
# test_setBootIncludeInvalidArg
#------------------------------------------
sub test_setBootIncludeInvalidArg {
	# ...
	# Test the setBootInclude method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
	    arch => 'i686',
		name => 'base'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	my $res = $collectDataObj -> setBootInclude(1);
	$msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPackageCollectData:setBootInclude: unrecognized '
		. 'argument expecting "true" or "false".';
	$this -> assert_str_equals($expected, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($res);
	return;
}

#==========================================
# test_setBootIncludeNoArg
#------------------------------------------
sub test_setBootIncludeNoArg {
	# ...
	# Test the setBootInclude method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
	    arch        => 'i686',
		bootinclude => 'true',
		name        => 'base'
	);
	my $collectDataObj = KIWIXMLPackageCollectData -> new(\%init);
	$collectDataObj = $collectDataObj -> setBootInclude();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($collectDataObj);
	my $bincl = $collectDataObj -> getBootInclude();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $bincl);
	return;
}

1;
