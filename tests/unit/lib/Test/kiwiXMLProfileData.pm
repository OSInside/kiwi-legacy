#================
# FILE          : kiwiXMLProfileData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the  KIWIXMLProfileData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLProfileData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLProfileData;

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
	# Test the ProfileData constructor with an improper argument type
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLProfileData -> new('foo');
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
# test_ctor_incompleteDataNoDesc
#------------------------------------------
sub test_ctor_incompleteDataNoDesc {
	# ...
	# Test the ProfileData constructor with incomplete initialization data
	# missing description
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				import => 'true',
				name   => 'profT'
	);
	my $prefDataObj = KIWIXMLProfileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProfileData: no "description" specified in '
		. 'initialization structure.';
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
# test_ctor_incompleteDataNoName
#------------------------------------------
sub test_ctor_incompleteDataNoName {
	# ...
	# Test the ProfileData constructor with incomplete initialization data
	# missing name
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				description => 'a test',
				import      => 'true',
	);
	my $prefDataObj = KIWIXMLProfileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProfileData: no "name" specified in '
		. 'initialization structure.';
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
# test_ctor_invalidArgVal
#------------------------------------------
sub test_ctor_invalidArgVal {
	# ...
	# Test the ProfileData constructor with invalid initialization data
	# unrecognized value for import
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				description => 'a test',
				import      => 'ola',
				name        => 'profT'
	);
	my $prefDataObj = KIWIXMLProfileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProfileData: Unrecognized value for boolean '
		. "'import' in initialization structure.";
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
# test_ctor_noInit
#------------------------------------------
sub test_ctor_noInit {
	# ...
	# Test the ProfileData constructor with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $prefDataObj = KIWIXMLProfileData -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProfileData: must be constructed with a '
		. 'keyword hash as argument';
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
# test_ctor_wInit
#------------------------------------------
sub test_ctor_wInit {
	# ...
	# Test the ProfileData constructor with valid initialization data
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				description => 'a test',
				import      => 'true',
				name        => 'profT'
	);
	my $prefDataObj = KIWIXMLProfileData -> new(\%init);
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
# test_getDescription
#------------------------------------------
sub test_getDescription {
	# ...
	# Test the getDescription method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profObj = $this -> __getProfObj();
	my $desc = $profObj -> getDescription();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('a test', $desc);
	return;
}

#==========================================
# test_getImportStatus
#------------------------------------------
sub test_getImportStatus {
	# ...
	# Test the getImportStatus method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profObj = $this -> __getProfObj();
	my $status = $profObj -> getImportStatus();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $status);
	return;
}

#==========================================
# test_getName
#------------------------------------------
sub test_getName {
	# ...
	# Test the getName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profObj = $this -> __getProfObj();
	my $name = $profObj -> getName();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('profT', $name);
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
	my $profObj = $this -> __getProfObj();
	my $elem = $profObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<profile name="profT" description="a test" '
		. 'import="true"/>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setDescription
#------------------------------------------
sub test_setDescription {
	# ...
	# Test the setDescription method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	$profDataObj = $profDataObj -> setDescription('SLES');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($profDataObj);
	my $descr = $profDataObj -> getDescription();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SLES', $descr);
	return;
}

#==========================================
# test_setDescriptionNoArg
#------------------------------------------
sub test_setDescriptionNoArg {
	# ...
	# Test the setDescription method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	my $res = $profDataObj -> setDescription();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setDescription: no description given, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $descr = $profDataObj -> getDescription();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('a test', $descr);
	return;
}

#==========================================
# test_setImportStatus
#------------------------------------------
sub test_setImportStatus {
	# ...
	# Test the setImportStatus method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	$profDataObj = $profDataObj -> setImportStatus('false');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($profDataObj);
	my $status = $profDataObj -> getImportStatus();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $status);
	return;
}

#==========================================
# test_setImportStatusNoArg
#------------------------------------------
sub test_setImportStatusNoArg {
	# ...
	# Test the setImportStatus method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	$profDataObj = $profDataObj -> setImportStatus();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($profDataObj);
	my $status = $profDataObj -> getImportStatus();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('false', $status);
	return;
}

#==========================================
# test_setImportStatusUnknownArg
#------------------------------------------
sub test_setImportStatusUnknownArg {
	# ...
	# Test the setImportStatus method with an unsupported boolean
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	my $res = $profDataObj -> setImportStatus('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLProfileData:setImportStatus: unrecognized '
		. 'argument expecting "true" or "false".';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $status = $profDataObj -> getImportStatus();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('true', $status);
	return;
}

#==========================================
# test_setName
#------------------------------------------
sub test_setName {
	# ...
	# Test the setName method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	$profDataObj = $profDataObj -> setName('SLES');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($profDataObj);
	my $name = $profDataObj -> getName();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('SLES', $name);
	return;
}

#==========================================
# test_setNameNoArg
#------------------------------------------
sub test_setNameNoArg {
	# ...
	# Test the setName method with no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $profDataObj = $this -> __getProfObj();
	my $res = $profDataObj -> setName();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setName: no name given, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $name = $profDataObj -> getName();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('profT', $name);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getProfObj
#------------------------------------------
sub __getProfObj {
	# ...
	# Helper to construct a fully populated Profile object
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my %init = (
	    description => 'a test',
		import      => 'true',
		name        => 'profT'
	);
	my $profDataObj = KIWIXMLProfileData -> new(\%init);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	# Test this condition last to get potential error messages
	$this -> assert_not_null($profDataObj);
	return $profDataObj;
}

1;
