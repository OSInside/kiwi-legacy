#================
# FILE          : kiwiXMLPackageData.pm
#----------------
# PROJECT       : OpenSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIDriverData module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLPackageData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLPackageData;

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Construct new test case
	# ---
	my $this = shift -> SUPER::new(@_);
	$this -> {kiwi} = Common::ktLog -> new();

	return $this;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the PackageData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageData: must be constructed with a '
		. 'keyword hash as argument';
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
# test_ctor_simple
#------------------------------------------
sub test_ctor_simple {
	# ...
	# Test proper construction with only the name argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( name => 'libtiff' );
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	return;
}

#==========================================
# test_ctor_invalidBoolValDelete
#------------------------------------------
sub test_ctor_invalidBoolValDelete {
	# ...
	# Test the PackageData constructor with an invalid value for the
	# bootdelete keyword
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				bootdelete => 'yes',
				name       => 'python'
	);
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageData: Unrecognized value for boolean '
		. "'bootdelete' in initialization structure.";
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
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageData: Unrecognized value for boolean '
		. "'bootinclude' in initialization structure.";
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
# test_ctor_unsuportedArch
#------------------------------------------
sub test_ctor_unsuportedArch {
	# ...
	# Test the PackageData constructor with an unsupported architecture
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				arch => 'tegra',
				name => 'dia'
	);
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "Specified arch 'tegra' is not supported";
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
				filename => 'zypper'
	);
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLPackageData: Unsupported keyword argument '
		. "'filename' in initialization structure.";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($pckgDataObj);
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
				name => 'libpng'
	);
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	return;
}

#==========================================
# test_getBootDelete
#------------------------------------------
sub test_getBootDelete {
	# ...
	# Verify that the bootdelete setting is properly returned.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $pckgDataObj = $this -> __getPckgDataObj();
	my $del = $pckgDataObj -> getBootDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $del);
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
	my $pckgDataObj = $this -> __getPckgDataObj();
	my $incl = $pckgDataObj -> getBootInclude();
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
	my $pckgDataObj = $this -> __getPckgDataObj();
	my $name = $pckgDataObj -> getName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('python', $name);
	return;
}

#==========================================
# test_getPackageToReplace
#------------------------------------------
sub test_getPackageToReplace {
	# ...
	# Verify that the proper package to replace is returned.
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $pckgDataObj = $this -> __getPckgDataObj();
	my $repl = $pckgDataObj -> getPackageToReplace();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('ruby', $repl);
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
	my $pckgDataObj = $this -> __getPckgDataObj();
	my $elem = $pckgDataObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<package name="python" arch="x86_64" bootdelete="true" '
		. 'bootinclude="true" replaces="ruby"/>';
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
	my %init = ( name => 'libzypp');
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $pckgDataObj -> setArch('x86_64');
	$this -> assert_equals(1, $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$value = $pckgDataObj -> getArch();
	$this -> assert_str_equals('x86_64', $value);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
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
	my %init = ( name => 'snapper');
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $pckgDataObj -> setArch('tegra');
	my $expectedMsg = "Specified arch 'tegra' is not supported";
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expectedMsg, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($value);
	$value = $pckgDataObj -> getArch();
	$this -> assert_null($value);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	return;
}

#==========================================
# test_setBootDelete
#------------------------------------------
sub test_setBootDelete {
	# ...
	# Test the setBootDelete method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = ( name => 'vi');
	my $pckgDataObj = $this -> __getPckgDataObj();
	$pckgDataObj = $pckgDataObj -> setBootDelete('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $bdel = $pckgDataObj -> getBootDelete();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $bdel);
	return;
}

#==========================================
# test_setBootDeleteInvalidArg
#------------------------------------------
sub test_setBootDeleteInvalidArg {
	# ...
	# Test the setBootDelete method with an unrecognized bool value
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = ( name => 'gfxboot');
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $res = $pckgDataObj -> setBootDelete(1);
	$msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPackageData:setBootDelete: unrecognized '
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
# test_setBootDeleteNoArg
#------------------------------------------
sub test_setBootDeleteNoArg {
	# ...
	# Test the setBootDelete method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $pckgDataObj = $this -> __getPckgDataObj();
	$pckgDataObj = $pckgDataObj -> setBootDelete();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $bdel = $pckgDataObj -> getBootDelete();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $bdel);
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
	my %init = ( name => 'vi');
	my $pckgDataObj = $this -> __getPckgDataObj();
	$pckgDataObj = $pckgDataObj -> setBootInclude('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $bincl = $pckgDataObj -> getBootInclude();
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
	my %init = ( name => 'gfxboot');
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $res = $pckgDataObj -> setBootInclude(1);
	$msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLPackageData:setBootInclude: unrecognized '
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
	my $pckgDataObj = $this -> __getPckgDataObj();
	$pckgDataObj = $pckgDataObj -> setBootInclude();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $bincl = $pckgDataObj -> getBootInclude();
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
# test_setPackageToReplace
#------------------------------------------
sub test_setPackageToReplace {
	# ...
	# Test the test_setPackageToReplace method
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = ( name => 'kernel-desktop');
	my $pckgDataObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	$pckgDataObj = $pckgDataObj -> setPackageToReplace('kernel-default');
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $repl = $pckgDataObj -> getPackageToReplace();
	$this -> assert_str_equals('kernel-default', $repl);
	return;
}

#==========================================
# test_setPackageToReplace_NoArg
#------------------------------------------
sub test_setPackageToReplace_NoArg {
	# ...
	# Test the test_setPackageToReplace method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my $pckgDataObj = $this -> __getPckgDataObj();
	$pckgDataObj = $pckgDataObj -> setPackageToReplace();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgDataObj);
	my $repl = $pckgDataObj -> getPackageToReplace();
	$this -> assert_null($repl);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getPckgDataObj
#------------------------------------------
sub __getPckgDataObj {
	# ...
	# Helper to construct a fully populated PackageData object.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		arch        => 'x86_64',
		bootdelete  => 'true',
		bootinclude => 'true',
		name        => 'python',
		replaces    => 'ruby'
	);
	my $pckgObj = KIWIXMLPackageData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($pckgObj);
	return $pckgObj;
}

1;
