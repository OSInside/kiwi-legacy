#================
# FILE          : kiwiXMLProductMetaFileData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLProductMetaFileData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLProductMetaFileData;

use strict;
use warnings;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLProductMetaFileData;

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
# test_ctor_improperArg
#------------------------------------------
sub test_ctor_improperArg {
	# ...
	# Test the ProductMetaFileData constructor with an improper
	# argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = KIWIXMLProductMetaFileData -> new('foo');
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
# test_ctor_missingArgScript
#------------------------------------------
sub test_ctor_missingArgScript {
	# ...
	# Test the ProductMetaFileData constructor with a missing script KW arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		target => '/installroot',
		url    => 'iso:///media1'
	);
	my $fileDataObj = KIWIXMLProductMetaFileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaFileData: no "script" specified in '
		. 'initialization structure.';
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
# test_ctor_missingArgTarget
#------------------------------------------
sub test_ctor_missingArgTarget {
	# ...
	# Test the ProductMetaFileData constructor with a missing target KW arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		script => 'myFixup.sh',
		url    => 'iso:///media1'
	);
	my $fileDataObj = KIWIXMLProductMetaFileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaFileData: no "target" specified in '
		. 'initialization structure.';
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
# test_ctor_missingArgURL
#------------------------------------------
sub test_ctor_missingArgURL {
	# ...
	# Test the ProductMetaFileData constructor with a missing url KW arg
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
		script => 'myFixup.sh',
		target => '/installroot'
	);
	my $fileDataObj = KIWIXMLProductMetaFileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaFileData: no "url" specified in '
		. 'initialization structure.';
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
# test_ctor_noArg
#------------------------------------------
sub test_ctor_noArg {
	# ...
	# Test the ProductMetaFileData constructor
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = KIWIXMLProductMetaFileData -> new();
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaFileData: must be constructed with a '
		. 'keyword hash as argument';
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
	    arch   => 'ppc64',
		script => 'myFixup.sh',
		target => '/installroot',
		url    => 'iso:///media1'
	);
	my $fileDataObj = KIWIXMLProductMetaFileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expectedMsg = 'KIWIXMLProductMetaFileData: Unsupported keyword '
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
# test_getScript
#------------------------------------------
sub test_getScript {
	# ...
	# Test the getScript method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = $this -> __getProdMetaFileObj();
	my $script = $fileDataObj -> getScript();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('myFixup.sh', $script);
	return;
}

#==========================================
# test_getTarget
#------------------------------------------
sub test_getTarget {
	# ...
	# Test the getTarget method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = $this -> __getProdMetaFileObj();
	my $target = $fileDataObj -> getTarget();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('/installroot', $target);
	return;
}

#==========================================
# test_getURL
#------------------------------------------
sub test_getURL {
	# ...
	# Test the getURL method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $fileDataObj = $this -> __getProdMetaFileObj();
	my $url = $fileDataObj -> getURL();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('iso:///media1', $url);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getProdMetaFileObj
#------------------------------------------
sub __getProdMetaFileObj {
	# ...
	# Helper to construct a fully populated ProductMetaFileData object.
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
		script => 'myFixup.sh',
		target => '/installroot',
		url    => 'iso:///media1'
	);
	my $fileDataObj = KIWIXMLProductMetaFileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($fileDataObj);
	return $fileDataObj;
}


1;
