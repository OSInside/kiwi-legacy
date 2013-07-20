#================
# FILE          : kiwiXMLExceptData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIIgnorePackageData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLExceptData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLExceptData;

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
	# Test the IgnorePackageData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $exceptDataObj = KIWIXMLExceptData -> new();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLExceptData: must be constructed with a '
		. 'keyword hash as argument';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($exceptDataObj);
	return;
}

#==========================================
# test_ctor_unsuportedArch
#------------------------------------------
sub test_ctor_unsuportedArch {
	# ...
	# Test the IgnorePackageData constructor with an unsupported architecture
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				arch => 'tegra',
				name => '/tmp'
	);
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = "Specified arch 'tegra' is not supported";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($exceptDataObj);
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
	my %init = ( name => '/etc' );
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($exceptDataObj);
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
				filename => '/usr/bin'
	);
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLExceptData: Unsupported keyword argument '
		. "'filename' in initialization structure.";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($exceptDataObj);
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
				name => '/usr/sbin'
	);
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($exceptDataObj);
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
				name => '/usr/lib'
	);
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $exceptDataObj -> getArch();
	$this -> assert_str_equals('i686', $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($exceptDataObj);
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
	my %init = ( name => '/usr/lib64');
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $exceptDataObj -> getName();
	$this -> assert_str_equals('/usr/lib64', $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($exceptDataObj);
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
		arch => 'ppc',
		name => '/var/log'
	);
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $elem = $exceptDataObj -> getXMLElement();
	my $xmlstr = $elem -> toString();
	my $expected = '<except name="/var/log" arch="ppc"/>';
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
	my %init = ( name => '/var/run');
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $exceptDataObj -> setArch('x86_64');
	$this -> assert_equals(1, $value);
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$value = $exceptDataObj -> getArch();
	$this -> assert_str_equals('x86_64', $value);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($exceptDataObj);
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
	my %init = ( name => '/media');
	my $exceptDataObj = KIWIXMLExceptData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my $value = $exceptDataObj -> setArch('tegra');
	my $expectedMsg = "Specified arch 'tegra' is not supported";
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expectedMsg, $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($value);
	$value = $exceptDataObj -> getArch();
	$this -> assert_null($value);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($exceptDataObj);
	return;
}

1;
