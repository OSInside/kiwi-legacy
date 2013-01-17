#================
# FILE          : kiwiXMLDescriptionData.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2012 SUSE LINUX Products GmbH, Germany
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : Unit test implementation for the KIWIXMLDescriptionData
#               : module.
#               :
# STATUS        : Development
#----------------
package Test::kiwiXMLDescriptionData;

use strict;
use warnings;
use XML::LibXML;

use Common::ktLog;
use Common::ktTestCase;
use base qw /Common::ktTestCase/;

use KIWIXMLDescriptionData;

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
# test_ctor_incompleteHashRefAuthor
#------------------------------------------
sub test_ctor_incompleteHashRefAuthor {
	# ...
	# Test the DescriptionData constructor with an incomplete hashRef
	# as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @contacts = ('me@suse.com');
	my %args = (
	    contact       => \@contacts,
		specification => 'test case',
		type          => 'system'
	);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%args);
	my $expected = 'KIWIXMLDescriptionData: no "author" specified in '
		. 'initialization structure.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_incompleteHashRefCont
#------------------------------------------
sub test_ctor_incompleteHashRefCont {
	# ...
	# Test the DescriptionData constructor with an incomplete hashRef
	# as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %args = (
	    author        => 'me',
		specification => 'test case',
		type          => 'system'
	);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%args);
	my $expected = 'KIWIXMLDescriptionData: no "contact" specified in '
		. 'initialization structure.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_incompleteHashRefSpec
#------------------------------------------
sub test_ctor_incompleteHashRefSpec {
	# ...
	# Test the DescriptionData constructor with an incomplete hashRef
	# as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @contacts = ('me@suse.com');
	my %args = (
	    author  => 'me',
		contact => \@contacts,
		type    => 'system'
	);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%args);
	my $expected = 'KIWIXMLDescriptionData: no "specification" given in '
		. 'initialization structure.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_incompleteHashRefType
#------------------------------------------
sub test_ctor_incompleteHashRefType {
	# ...
	# Test the DescriptionData constructor with an incomplete hashRef
	# as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @contacts = ('me@suse.com');
	my %args = (
		author        => 'me',
		contact       => \@contacts,
		specification => 'test case'
	);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%args);
	my $expected = 'KIWIXMLDescriptionData: no "type" specified in '
		. 'initialization structure.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_invalidHashRefContact
#------------------------------------------
sub test_ctor_invalidHashRefContact {
	# ...
	# Test the DescriptionData constructor with an invalid hashRef as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = ( author        => 'me',
				 contact       => 'me@suse.com',
				 specification => 'the test case',
				 type          => 'image',
			);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%init);
	my $expected = 'KIWIXMLDescriptionData: expecting array ref as value '
		. 'for "contact" argument.';
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_invalidHashRefType
#------------------------------------------
sub test_ctor_invalidHashRefType {
	# ...
	# Test the DescriptionData constructor with an invalid hashRef as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @contacts = ('me@suse.com');
	my %init = ( author        => 'me',
				 contact       => \@contacts,
				 specification => 'the test case',
				 type          => 'pablo',
			);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%init);
	my $expected = 'object initialization: specified description type '
		. "'pablo' is not supported.";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_noArgs
#------------------------------------------
sub test_ctor_noArgs {
	# ...
	# Test the DescriptionData constructor with no arguments
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = KIWIXMLDescriptionData -> new();
	my $msg = $kiwi -> getMessage();
	my $expected = 'KIWIXMLDescriptionData: must be constructed with '
		. 'a keyword hash as argument';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_unsupportedKW
#------------------------------------------
sub test_ctor_unsupportedKW {
	# ...
	# Test the DescriptionData constructor with an invalid init entry
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my %init = (
				name => 'me',
				type => 'boot'
	);
	my $descrpObj = KIWIXMLDescriptionData -> new(\%init);

	my $expected = 'KIWIXMLDescriptionData: Unsupported keyword argument '
		. "'name' in initialization structure.";
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($descrpObj);
	return;
}

#==========================================
# test_ctor_validHashRef
#------------------------------------------
sub test_ctor_validHashRef {
	# ...
	# Test the DescriptionData constructor with a valid hashRef as argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my @contacts = ('me@suse.com');
	my %args = (
		author        => 'me',
		contact       => \@contacts,
		specification => 'the test case',
		type          => 'boot',
	);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%args);
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($descrpObj);
	return;
}

#==========================================
# test_getAuthor
#------------------------------------------
sub test_getAuthor {
	# ...
	# Test the getAuthor method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $author = $descrpObj -> getAuthor();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('me', $author);
	return;
}

#==========================================
# test_getContactInfo
#------------------------------------------
sub test_getContactInfo {
	# ...
	# Test the getContactInfo method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $contact = $descrpObj -> getContactInfo();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ('me@suse.com', 'you@suse.com');
	$this -> assert_array_equal(\@expected, $contact);
	return;
}

#==========================================
# test_getSpecificationDescript
#------------------------------------------
sub test_getSpecificationDescript {
	# ...
	# Test the getSpecificationDescript method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $spec = $descrpObj -> getSpecificationDescript();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('the test case', $spec);
	return;
}

#==========================================
# test_getType
#------------------------------------------
sub test_getType {
	# ...
	# Test the getType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $type = $descrpObj -> getType();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('boot', $type);
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
	my $descrpObj = $this -> __getDescriptObj();
	my $elem = $descrpObj -> getXMLElement();
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($elem);
	my $xmlstr = $elem -> toString();
	my $expected = '<description type="boot">'
		. '<author>me</author>'
		. '<contact>me@suse.com</contact>'
		. '<contact>you@suse.com</contact>'
		. '<specification>the test case</specification>'
		. '</description>';
	$this -> assert_str_equals($expected, $xmlstr);
	return;
}

#==========================================
# test_setAuthor
#------------------------------------------
sub test_setAuthor {
	# ...
	# Test the setAuthor method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	$descrpObj = $descrpObj -> setAuthor('robert');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($descrpObj);
	my $author = $descrpObj -> getAuthor();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('robert', $author);
	return;
}

#==========================================
# test_setAuthorNoArg
#------------------------------------------
sub test_setAuthorNoArg {
	# ...
	# Test the setAuthor method withy no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $res = $descrpObj -> setAuthor();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setAuthor: no author given, retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $author = $descrpObj -> getAuthor();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('me', $author);
	return;
}

#==========================================
# test_setContactInfo
#------------------------------------------
sub test_setContactInfo {
	# ...
	# Test the setContactInfo method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	$descrpObj = $descrpObj -> setContactInfo('rjschwei@suse.com');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($descrpObj);
	my $info = $descrpObj -> getContactInfo();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ('rjschwei@suse.com');
	$this -> assert_array_equal(\@expected, $info);
	return;
}

#==========================================
# test_setContactInfoNoArg
#------------------------------------------
sub test_setContactInfoNoArg {
	# ...
	# Test the setContactInfo method withy no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $res = $descrpObj -> setContactInfo();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setContactInfo: no contact information given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $info = $descrpObj -> getContactInfo();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	my @expected = ('me@suse.com', 'you@suse.com');
	$this -> assert_array_equal(\@expected, $info);
	return;
}

#==========================================
# test_setSpecificationDescript
#------------------------------------------
sub test_setSpecificationDescript {
	# ...
	# Test the setSpecificationDescript method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	$descrpObj = $descrpObj -> setSpecificationDescript('try it');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($descrpObj);
	my $descrpt = $descrpObj -> getSpecificationDescript();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('try it', $descrpt);
	return;
}

#==========================================
# test_setSpecificationDescriptNoArg
#------------------------------------------
sub test_setSpecificationDescriptNoArg {
	# ...
	# Test the setSpecificationDescript method withy no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $res = $descrpObj -> setSpecificationDescript();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setSpecificationDescript: no discription given, '
		. 'retaining current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $descrpt = $descrpObj -> getSpecificationDescript();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('the test case', $descrpt);
	return;
}

#==========================================
# test_setType
#------------------------------------------
sub test_setType {
	# ...
	# Test the setType method
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	$descrpObj = $descrpObj -> setType('system');
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($descrpObj);
	my $type = $descrpObj -> getType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('system', $type);
	return;
}

#==========================================
# test_setTypeInvalidArg
#------------------------------------------
sub test_setTypeInvalidArg {
	# ...
	# Test the setType method withy no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $res = $descrpObj -> setType('foo');
	my $msg = $kiwi -> getMessage();
	my $expected = "setType: specified description type 'foo' is not "
			. 'supported.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $type = $descrpObj -> getType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('boot', $type);
	return;
}

#==========================================
# test_setTypeNoArg
#------------------------------------------
sub test_setTypeNoArg {
	# ...
	# Test the setType method withy no argument
	# ---
	my $this = shift;
	my $kiwi = $this -> {kiwi};
	my $descrpObj = $this -> __getDescriptObj();
	my $res = $descrpObj -> setType();
	my $msg = $kiwi -> getMessage();
	my $expected = 'setType: no description type given, retaining '
		. 'current data.';
	$this -> assert_str_equals($expected, $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('error', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('failed', $state);
	$this -> assert_null($res);
	my $type = $descrpObj -> getType();
	$msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	$msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	$state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_str_equals('boot', $type);
	return;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __getDescriptObj
#------------------------------------------
sub __getDescriptObj {
	# ...
	# Helper to construct a fully populated Description object
	# ---
	my $this = shift;
	my $kiwi = $this->{kiwi};
	my @contacts = ('me@suse.com', 'you@suse.com');
	my %args = (
		author        => 'me',
		contact       => \@contacts,
		specification => 'the test case',
		type          => 'boot',
	);
	# Test with a string arguments
	my $descrpObj = KIWIXMLDescriptionData -> new(\%args);
	$this -> assert_not_null($descrpObj);
	my $msg = $kiwi -> getMessage();
	$this -> assert_str_equals('No messages set', $msg);
	my $msgT = $kiwi -> getMessageType();
	$this -> assert_str_equals('none', $msgT);
	my $state = $kiwi -> getState();
	$this -> assert_str_equals('No state set', $state);
	$this -> assert_not_null($descrpObj);
	return $descrpObj;
}

1;
