#================
# FILE          : kiwiXMLProductMetaChrootData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLProductMetaChrootData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLProductMetaChrootData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLProductMetaChrootData;

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
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the ProductMetaChrootData constructor with an improper
	# argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = KIWIXMLProductMetaChrootData -> new($kiwi, 'foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'Expecting a hash ref as second argument if provided';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($fileDataObj);
	return;
}

#==========================================
# test_ctor_invalidValue
#------------------------------------------
sub test_ctor_invalidValue {
	# ...
	# Test the ProductMetaChrootData constructor with a an invalid value
	# for the value KW arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		requires => 'myFixup.sh',
		value => 'foo'
	);
	my $chrootDataObj = KIWIXMLProductMetaChrootData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaChrootData: Unrecognized value '
		. "for boolean 'value' in initialization structure.";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($chrootDataObj);
	return;
}

#==========================================
# test_ctor_missingArgRequires
#------------------------------------------
sub test_ctor_missingArgRequires {
	# ...
	# Test the ProductMetaChrootData constructor with a missing
	# requires KW arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		value => 'false'
	);
	my $chrootDataObj = KIWIXMLProductMetaChrootData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaChrootData: no "requires" '
		. 'specified in initialization structure.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($chrootDataObj);
	return;
}

#==========================================
# test_ctor_missingArgValue
#------------------------------------------
sub test_ctor_missingArgValue {
	# ...
	# Test the ProductMetaChrootData constructor with a missing value KW arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		requires => 'myFixup.sh',
	);
	my $chrootDataObj = KIWIXMLProductMetaChrootData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaChrootData: no "value" specified in '
		. 'initialization structure.';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($chrootDataObj);
	return;
}

#==========================================
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the ProductMetaChrootData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = KIWIXMLProductMetaChrootData -> new($kiwi);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaChrootData: must be constructed '
		. 'with a keyword hash as argument';
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	# Test this condition last to get potential error messages
	$this -> assert_null($fileDataObj);
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
		requires => 'myFixup.sh',
		value    => 'true',
	);
	my $fileDataObj = KIWIXMLProductMetaChrootData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaChrootData: Unsupported keyword '
		. "argument 'arch' in initialization structure.";
	$this -> assert_str_equals($expectedMsg, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($fileDataObj);
	return;
}

#==========================================
# test_chrootNeeded
#------------------------------------------
sub test_chrootNeeded {
	# ...
	# Test the chrootNeeded method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $chrootDataObj = $this -> __getProdMetaChrootObj();
	my $chroot = $chrootDataObj -> chrootNeeded();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $chroot);
	return;
}

#==========================================
# test_getRequires
#------------------------------------------
sub test_getRequires {
	# ...
	# Test the getRequires method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $chrootDataObj = $this -> __getProdMetaChrootObj();
	my $req = $chrootDataObj -> getRequires();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myFixup.sh', $req);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getProdMetaChrootObj
#------------------------------------------
sub __getProdMetaChrootObj {
	# ...
	# Helper to construct a fully populated ProductMetaChrootData object.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		requires => 'myFixup.sh',
		value    => 'true'
	);
	my $chrootDataObj = KIWIXMLProductMetaChrootData -> new($kiwi, \%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($chrootDataObj);
	return $chrootDataObj;
}


1;
